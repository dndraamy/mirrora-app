// Edge Function: ai-chat
// Menjadi perantara antara aplikasi Mirrora dan Gemini.
// API key Gemini hanya ada di Supabase Secrets (GEMINI_API_KEY), tidak di aplikasi.

import { createClient } from "npm:@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Urutan model: yang pertama dicoba dulu, sisanya cadangan.
// Pastikan nama-nama ini valid di dokumentasi Gemini.
const MODELS = [
  "gemini-flash-lite-latest",
  "gemini-3.1-flash-lite",
  "gemini-flash-latest",
];

const DAILY_LIMIT = 30; // maksimal pesan per user per hari
const MAX_PROMPT = 2000;
const MAX_HISTORY = 10;
const MAX_TEXT = 4000;
const MAX_IMAGE_B64 = 2_000_000; // ~1.5 MB gambar
const IMAGE_MIME = ["image/jpeg", "image/png", "image/webp"];

const SYSTEM_INSTRUCTION = `
Kamu adalah "Mirrora AI Beauty Assistant", konsultan kecantikan, skincare, dan self-care personal dalam aplikasi Mirrora.
Tujuanmu adalah memberikan saran yang hangat, empatik, edukatif, dan praktis seputar perawatan kulit (skincare routine, bahan aktif/ingredients, mengatasi masalah kulit seperti jerawat, kusam, kering) serta gaya hidup sehat & self-care.

PANDUAN KOMUNIKASI & FORMAT PESAN (SANGAT PENTING):
1. Bersikap ramah, suportif, dan gunakan gaya bahasa seperti beauty bestie yang berwawasan ilmiah dasar.
2. JANGAN PERNAH gunakan tanda pagar Markdown (seperti #, ##, ###, ####) untuk membuat judul atau header. Jika ingin membuat judul, gunakan huruf kapital biasa (contoh: REKOMENDASI PRODUK atau 1. Pilihan Terjangkau:).
3. JANGAN gunakan garis pemisah (seperti --- atau ***).
4. JANGAN gunakan tanda bintang untuk menebalkan atau memiringkan kata (hindari **kata** atau *kata*). Tuliskan teks secara bersih tanpa tanda bintang agar enak dibaca di aplikasi chat.
5. Gunakan penomoran jelas (1., 2., 3.) atau simbol titik bulat (•) untuk daftar rekomendasi produk atau langkah skincare.
6. Berikan edukasi tentang layering bahan aktif yang aman (misalnya: tidak menggabungkan konsentrasi tinggi AHA/BHA bersamaan dengan Retinol, pentingnya pelembap dan sunscreen setiap pagi).
7. Jika pengguna mengunggah foto produk atau foto kulit, jelaskan fungsi bahan yang terlihat dan berikan saran umum perawatan.
8. Selalu ingatkan pengguna untuk melakukan patch test pada produk baru, serta konsultasi langsung dengan dokter spesialis kulit (dermatologist) jika mengalami reaksi alergi atau masalah kulit berat.
9. Jawab dalam Bahasa Indonesia yang bersih, rapi, natural, dan mudah dibaca di layar HP.
`;

type Role = "user" | "model";
interface Turn {
  role: Role;
  text: string;
}
interface Content {
  role: Role;
  parts: Record<string, unknown>[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Gemini mewajibkan giliran berselang-seling dan diawali user.
// Fungsi ini menggabungkan giliran berurutan dengan peran sama dan
// membuang model di awal, supaya riwayat yang "kotor" tidak bikin error.
function buildContents(
  history: Turn[],
  prompt: string,
  image?: { mime_type: string; data: string },
): Content[] {
  const contents: Content[] = [];
  const push = (role: Role, part: Record<string, unknown>) => {
    const last = contents[contents.length - 1];
    if (last && last.role === role) last.parts.push(part);
    else contents.push({ role, parts: [part] });
  };

  for (const t of history) {
    if (contents.length === 0 && t.role !== "user") continue;
    push(t.role, { text: t.text });
  }
  push("user", { text: prompt });
  if (image) push("user", { inline_data: image });
  return contents;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY belum diset di Supabase Secrets");
    return json({ error: "Layanan AI belum dikonfigurasi" }, 500);
  }

  // 1. Pastikan pemanggil adalah user yang sudah login
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "Silakan login terlebih dahulu" }, 401);
  }
  const user = userData.user;

  // 2. Validasi input
  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body bukan JSON yang valid" }, 400);
  }

  const prompt = typeof body?.prompt === "string" ? body.prompt.trim() : "";
  if (!prompt || prompt.length > MAX_PROMPT) {
    return json({ error: "Pesan kosong atau terlalu panjang" }, 400);
  }

  // deno-lint-ignore no-explicit-any
  const history: Turn[] = (Array.isArray(body?.history) ? body.history : [])
    .slice(-MAX_HISTORY)
    // deno-lint-ignore no-explicit-any
    .filter((h: any) =>
      (h?.role === "user" || h?.role === "model") &&
      typeof h?.text === "string" && h.text.trim().length > 0
    )
    // deno-lint-ignore no-explicit-any
    .map((h: any) => ({
      role: h.role as Role,
      text: (h.text as string).slice(0, MAX_TEXT),
    }));

  let image: { mime_type: string; data: string } | undefined;
  if (body?.image) {
    const mime = body.image.mime_type;
    const data = body.image.data;
    if (
      typeof mime !== "string" || !IMAGE_MIME.includes(mime) ||
      typeof data !== "string" || data.length === 0 ||
      data.length > MAX_IMAGE_B64
    ) {
      return json({ error: "Gambar tidak valid atau terlalu besar" }, 400);
    }
    image = { mime_type: mime, data };
  }

  // 3. Batasi pemakaian per user per hari
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: allowed, error: limitErr } = await admin.rpc("ai_hit", {
    p_user: user.id,
    p_limit: DAILY_LIMIT,
  });
  if (limitErr) {
    console.error("ai_hit gagal:", limitErr.message);
    return json({ error: "Gagal memeriksa batas pemakaian" }, 500);
  }
  if (!allowed) {
    return json({ error: "Batas pemakaian harian tercapai" }, 429);
  }

  // 4. Panggil Gemini, dengan model cadangan hanya untuk error sementara
  const contents = buildContents(history, prompt, image);
  let lastStatus = 503;

  for (const model of MODELS) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": GEMINI_API_KEY,
          },
          body: JSON.stringify({
            system_instruction: { parts: [{ text: SYSTEM_INSTRUCTION }] },
            contents,
          }),
          signal: AbortSignal.timeout(25_000),
        },
      );

      if (res.ok) {
        const data = await res.json();
        const text = (data?.candidates?.[0]?.content?.parts ?? [])
          .map((p: { text?: string }) => p.text ?? "")
          .join("")
          .trim();
        return json({ text, model });
      }

      lastStatus = res.status;
      // Detail error hanya di log server, tidak dikirim ke aplikasi
      console.error(model, res.status, (await res.text()).slice(0, 300));
      if (![404, 429, 500, 503].includes(res.status)) break;
    } catch (e) {
      lastStatus = 503;
      console.error(model, "fetch gagal:", String(e));
    }
  }

  return json(
    { error: "Layanan AI sedang sibuk, coba lagi nanti" },
    lastStatus === 429 ? 429 : 503,
  );
});