/// Kumpulan data produk beauty untuk fitur Shake to Pick.
/// Setiap produk memiliki kategori, nama, deskripsi singkat, emoji, dan tip pemakaian.
library;

class BeautyProduct {
  const BeautyProduct({
    required this.name,
    required this.brand,
    required this.category,
    required this.emoji,
    required this.description,
    required this.tip,
    this.isRareDrop = false,
  });

  final String name;
  final String brand;
  final String category;
  final String emoji;
  final String description;
  final String tip;

  /// Produk langka — ada chance kecil muncul (bonus / "lucky drop")
  final bool isRareDrop;
}

const List<BeautyProduct> beautyProducts = [
  // ── SKINCARE ──────────────────────────────────────────────────
  BeautyProduct(
    name: 'Facial Wash Gentle Foam',
    brand: 'Mirrora Picks',
    category: 'Skincare • Cleanser',
    emoji: '🫧',
    description:
        'Sabun cuci muka berbusa lembut yang membersihkan kotoran dan minyak tanpa membuat kulit kering.',
    tip: 'Gunakan pagi dan malam. Pijat lembut selama 30 detik lalu bilas dengan air dingin.',
  ),
  BeautyProduct(
    name: 'Hyaluronic Acid Serum',
    brand: 'Mirrora Picks',
    category: 'Skincare • Serum',
    emoji: '💧',
    description:
        'Serum hidrasi intens dengan kandungan Hyaluronic Acid yang menarik kelembapan ke dalam kulit.',
    tip:
        'Aplikasikan ke wajah yang masih sedikit lembap (setelah toner) untuk hasil hidrasi maksimal.',
  ),
  BeautyProduct(
    name: 'Niacinamide 10% + Zinc',
    brand: 'Mirrora Picks',
    category: 'Skincare • Serum',
    emoji: '✨',
    description:
        'Serum pencerah pori-pori dengan Niacinamide 10% efektif menyamarkan bekas jerawat dan mengontrol minyak.',
    tip:
        'Gunakan pagi dan malam setelah toner. Hindari dipakai bersamaan dengan Vitamin C di waktu yang sama.',
  ),
  BeautyProduct(
    name: 'SPF 50 Sunscreen Gel',
    brand: 'Mirrora Picks',
    category: 'Skincare • Sunscreen',
    emoji: '☀️',
    description:
        'Tabir surya gel ringan non-greasy dengan perlindungan SPF 50+ PA++++ untuk kulit berminyak.',
    tip: 'Aplikasikan sebagai langkah terakhir skincare pagi. Reapply setiap 2 jam di luar ruangan.',
  ),
  BeautyProduct(
    name: 'Retinol Night Cream',
    brand: 'Mirrora Picks',
    category: 'Skincare • Moisturizer',
    emoji: '🌙',
    description:
        'Krim malam dengan Retinol 0.3% untuk regenerasi sel kulit dan mengurangi tanda penuaan.',
    tip:
        'Hanya gunakan malam hari. Mulai 2x seminggu, lalu tingkatkan secara bertahap. Selalu pakai sunscreen keesokan harinya.',
  ),
  BeautyProduct(
    name: 'Vitamin C Brightening Toner',
    brand: 'Mirrora Picks',
    category: 'Skincare • Toner',
    emoji: '🍋',
    description:
        'Toner pencerah dengan Vitamin C dan ekstrak lemon yang menyegarkan dan menyamarkan noda gelap.',
    tip: 'Gunakan kapas atau tepuk-tepuk langsung ke wajah setelah cuci muka di pagi hari.',
  ),
  BeautyProduct(
    name: 'Calming Aloe Gel Moisturizer',
    brand: 'Mirrora Picks',
    category: 'Skincare • Moisturizer',
    emoji: '🌿',
    description:
        'Gel pelembap ringan berbahan dasar Aloe Vera yang menenangkan kulit iritasi dan kemerahan.',
    tip: 'Cocok untuk kulit sensitif dan setelah berjemur. Simpan di kulkas untuk sensasi ekstra segar.',
  ),
  BeautyProduct(
    name: 'Clay Mask Detox',
    brand: 'Mirrora Picks',
    category: 'Skincare • Masker',
    emoji: '🏺',
    description:
        'Masker tanah liat dengan Kaolin dan Bentonite untuk membersihkan pori-pori secara mendalam.',
    tip:
        'Gunakan 1-2x seminggu. Biarkan 10-15 menit lalu bilas. Jangan dibiarkan sampai terlalu kering.',
  ),
  BeautyProduct(
    name: 'Eye Cream Caffeine Fix',
    brand: 'Mirrora Picks',
    category: 'Skincare • Eye Care',
    emoji: '👁️',
    description:
        'Krim mata dengan kafein dan peptida untuk mengurangi bengkak, lingkaran hitam, dan garis halus.',
    tip:
        'Tepuk-tepuk lembut dengan jari manis di area bawah mata. Gunakan pagi dan malam sebelum moisturizer.',
  ),

  // ── MAKEUP ────────────────────────────────────────────────────
  BeautyProduct(
    name: 'Cushion Foundation Dewy Finish',
    brand: 'Mirrora Picks',
    category: 'Makeup • Foundation',
    emoji: '🪞',
    description:
        'Cushion foundation dengan finish dewy yang memberikan tampilan kulit glowing alami dan coverage medium.',
    tip:
        'Tekan perlahan puff ke kulit, jangan digosok. Lapisi tipis-tipis untuk coverage yang lebih natural.',
  ),
  BeautyProduct(
    name: 'Loose Setting Powder',
    brand: 'Mirrora Picks',
    category: 'Makeup • Powder',
    emoji: '🌸',
    description:
        'Bedak tabur translucent yang mengurangi kilap dan memperpanjang ketahanan makeup hingga 12 jam.',
    tip: 'Gunakan kuas fluffy dan sapukan dengan gerakan memutar. Fokus di T-zone yang berminyak.',
  ),
  BeautyProduct(
    name: 'Lip Tint Velvet Matte',
    brand: 'Mirrora Picks',
    category: 'Makeup • Lip',
    emoji: '💄',
    description:
        'Lip tint formula velvet matte yang tahan lama, tidak kering, dan tersedia dalam berbagai shade Korea.',
    tip:
        'Aplikasikan dari tengah ke luar bibir untuk tampilan ombre natural, atau full coverage untuk bold look.',
  ),
  BeautyProduct(
    name: 'Blush On Cream Blusher',
    brand: 'Mirrora Picks',
    category: 'Makeup • Blush',
    emoji: '🌷',
    description:
        'Cream blush yang mudah diblending untuk pipi merona natural ala Korean style.',
    tip: 'Ketuk langsung ke pipi dengan jari lalu blend ke atas ke arah pelipis untuk tampilan segar.',
  ),
  BeautyProduct(
    name: 'Eyebrow Pencil Ultra Slim',
    brand: 'Mirrora Picks',
    category: 'Makeup • Eyebrow',
    emoji: '✏️',
    description:
        'Pensil alis ultra tipis untuk membentuk alis natural hair-stroke yang tahan air dan tahan panas.',
    tip:
        'Gambar stroke kecil searah tumbuhnya rambut alis. Gunakan ujung spoolie untuk menyisir ke atas.',
  ),
  BeautyProduct(
    name: 'Highlighter Glitter Stick',
    brand: 'Mirrora Picks',
    category: 'Makeup • Highlight',
    emoji: '⭐',
    description:
        'Highlighter stick dengan shimmer halus untuk tampilan glowing di tulang pipi, hidung, dan inner corner.',
    tip: 'Sapukan langsung ke area yang ingin ditonjolkan lalu tap dengan jari untuk menciptakan glow natural.',
  ),

  // ── HAIR CARE ─────────────────────────────────────────────────
  BeautyProduct(
    name: 'Keratin Hair Mask',
    brand: 'Mirrora Picks',
    category: 'Hair Care • Treatment',
    emoji: '💆',
    description:
        'Masker rambut dengan protein keratin untuk melembutkan, mengurangi frizz, dan mengembalikan kilap rambut.',
    tip:
        'Aplikasikan ke rambut yang sudah dicuci, biarkan 15-20 menit dengan shower cap, lalu bilas bersih.',
  ),
  BeautyProduct(
    name: 'Scalp Serum Anti Dandruff',
    brand: 'Mirrora Picks',
    category: 'Hair Care • Scalp',
    emoji: '🧴',
    description:
        'Serum kulit kepala dengan Salicylic Acid dan Tea Tree Oil untuk mengatasi ketombe dan gatal.',
    tip:
        'Teteskan langsung ke kulit kepala dan pijat dengan ujung jari. Tidak perlu dibilas. Gunakan 3x seminggu.',
  ),
  BeautyProduct(
    name: 'Hair Oil Argan Shine',
    brand: 'Mirrora Picks',
    category: 'Hair Care • Oil',
    emoji: '🌻',
    description:
        'Minyak rambut berbasis Argan Oil yang ringan untuk memberikan kilap, mengurangi frizz, dan melindungi panas.',
    tip:
        'Aplikasikan 2-3 tetes ke telapak tangan, gosok, lalu sapukan ke batang rambut — hindari akar rambut.',
  ),

  // ── BODY CARE ─────────────────────────────────────────────────
  BeautyProduct(
    name: 'Body Butter Shea & Vanilla',
    brand: 'Mirrora Picks',
    category: 'Body Care • Moisturizer',
    emoji: '🧈',
    description:
        'Body butter kaya dengan Shea Butter dan aroma vanilla yang melembapkan kulit kering secara intensif.',
    tip:
        'Oleskan ke seluruh tubuh setelah mandi saat kulit masih sedikit lembap untuk hidrasi yang lebih baik.',
  ),
  BeautyProduct(
    name: 'Sugar Body Scrub Rose',
    brand: 'Mirrora Picks',
    category: 'Body Care • Scrub',
    emoji: '🌹',
    description:
        'Scrub gula dengan ekstrak mawar dan Vitamin E untuk mengeksfoliasi kulit mati dan mencerahkan kulit.',
    tip:
        'Gunakan 2-3x seminggu saat mandi. Pijat melingkar lembut lalu bilas. Kulit akan langsung terasa halus.',
  ),

  // ── FRAGRANCE ─────────────────────────────────────────────────
  BeautyProduct(
    name: 'Eau de Parfum Rose Oud',
    brand: 'Mirrora Picks',
    category: 'Fragrance • Parfum',
    emoji: '🌺',
    description:
        'Parfum dengan perpaduan rose, oud, dan musk yang tahan lama untuk kesan elegan dan feminin.',
    tip:
        'Semprotkan ke titik nadi (pergelangan, leher, belakang telinga) dari jarak 15-20cm untuk daya tahan lebih lama.',
  ),

  // ── RARE DROPS ────────────────────────────────────────────────
  BeautyProduct(
    name: '24K Gold Ampoule Serum',
    brand: 'Mirrora Premium',
    category: 'Skincare • Premium Serum',
    emoji: '✨🏅',
    description:
        'Serum premium dengan partikel 24K Gold dan Peptida eksklusif untuk kulit tampak mewah, kencang, dan bercahaya.',
    tip:
        'Gunakan 3-4 tetes sebelum moisturizer. Produk langka ini adalah hasil dari keberuntunganmu hari ini!',
    isRareDrop: true,
  ),
  BeautyProduct(
    name: 'Miracle Overnight Sleeping Mask',
    brand: 'Mirrora Premium',
    category: 'Skincare • Premium Mask',
    emoji: '🌙✨',
    description:
        'Sleeping mask premium dengan kolagen, ceramide, dan ekstrak truffle putih untuk transformasi kulit semalaman.',
    tip:
        'Aplikasikan sebagai langkah terakhir skincare malam. Biarkan semalam penuh. Selamat, kamu beruntung!',
    isRareDrop: true,
  ),
  BeautyProduct(
    name: 'Crystal Glow Essence',
    brand: 'Mirrora Premium',
    category: 'Skincare • Premium Essence',
    emoji: '💎',
    description:
        'Essence eksklusif dengan Crystal Collagen dan Hyaluronic Acid triple-weight untuk kulit sepermukaan kristal.',
    tip:
        'Tepuk-tepuk ke seluruh wajah setelah toner. Produk premium ini adalah hadiah dari Shake to Pick-mu!',
    isRareDrop: true,
  ),
];
