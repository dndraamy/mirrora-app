import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageBytes,
    this.isError = false,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  /// Pesan error hanya untuk tampilan: tidak disimpan dan tidak dikirim ke AI.
  final bool isError;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        if (imageBytes != null) 'imageB64': base64Encode(imageBytes!),
      };

  factory AiChatMessage.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? bytes;
    final b64 = map['imageB64']?.toString();
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }
    return AiChatMessage(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      isUser: map['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      imageBytes: bytes,
    );
  }
}

/// Model riwayat pemindaian produk pada fitur AI Product Scanner
class AiProductScan {
  AiProductScan({
    required this.id,
    required this.productName,
    required this.category,
    required this.analysisResult,
    required this.timestamp,
    this.imageBytes,
  });

  final String id;
  final String productName;
  final String category;
  final String analysisResult;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'productName': productName,
        'category': category,
        'analysisResult': analysisResult,
        'timestamp': timestamp.toIso8601String(),
        if (imageBytes != null) 'imageB64': base64Encode(imageBytes!),
      };

  factory AiProductScan.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? bytes;
    final b64 = map['imageB64']?.toString();
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }
    return AiProductScan(
      id: map['id']?.toString() ?? '',
      productName: map['productName']?.toString() ?? 'Produk Skincare/Makeup',
      category: map['category']?.toString() ?? 'Skincare',
      analysisResult: map['analysisResult']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      imageBytes: bytes,
    );
  }
}

/// Service untuk memfasilitasi dua fitur utama:
/// 1. Menu AI: Product Scanner (Vision/Pengenalan Produk via Kamera/Galeri)
/// 2. Menu Mirrora Assistant: LLM Chatbot Asisten Beauty, Self-Care, Skincare, & Makeup
class AiService {
  AiService._();
  static final AiService _instance = AiService._();

  /// Singleton: semua `AiService()` di aplikasi memakai instance yang sama.
  factory AiService() => _instance;

  static const String _settingsBoxName = 'settingsBox';
  static const String _functionName = 'ai-chat';
  static const int _maxHistory = 10;

  Box get _settings => Hive.box(_settingsBoxName);

  /// Kunci penyimpanan riwayat chat per akun yang sedang login
  String _getUserStorageKey([String? fallbackIdentifier]) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id.isNotEmpty) {
      return 'mirrora_chat_uid_${user.id}';
    }
    final id = (fallbackIdentifier ?? 'default').toLowerCase().trim();
    return 'mirrora_chat_user_$id';
  }

  /// Kunci penyimpanan riwayat scan produk AI per akun yang sedang login
  String _getUserScanStorageKey([String? fallbackIdentifier]) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id.isNotEmpty) {
      return 'mirrora_scans_uid_${user.id}';
    }
    final id = (fallbackIdentifier ?? 'default').toLowerCase().trim();
    return 'mirrora_scans_user_$id';
  }

  // ------------------------------------------------------------- CHAT ASSISTANT
  Future<List<AiChatMessage>> loadChatHistory([
    String? fallbackIdentifier,
  ]) async {
    final key = _getUserStorageKey(fallbackIdentifier);
    final dynamic raw = _settings.get(key);
    final list = <AiChatMessage>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) list.add(AiChatMessage.fromMap(item));
      }
    }
    return list;
  }

  Future<void> saveChatHistory(
    List<AiChatMessage> messages, [
    String? fallbackIdentifier,
  ]) async {
    final key = _getUserStorageKey(fallbackIdentifier);
    final serialized = messages
        .where((m) => m.id != 'welcome' && !m.isError)
        .map((m) => m.toMap())
        .toList();
    await _settings.put(key, serialized);
  }

  Future<void> clearChatHistory([String? fallbackIdentifier]) async {
    final key = _getUserStorageKey(fallbackIdentifier);
    await _settings.delete(key);
  }

  void clearChatSession() {}

  // -------------------------------------------------------- PRODUCT SCAN HISTORY
  Future<List<AiProductScan>> loadProductScans([
    String? fallbackIdentifier,
  ]) async {
    final key = _getUserScanStorageKey(fallbackIdentifier);
    final dynamic raw = _settings.get(key);
    final list = <AiProductScan>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) list.add(AiProductScan.fromMap(item));
      }
    }
    // Urutkan dari yang paling baru
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> saveProductScan(
    AiProductScan scan, [
    String? fallbackIdentifier,
  ]) async {
    final existing = await loadProductScans(fallbackIdentifier);
    existing.insert(0, scan);
    // Simpan maksimal 30 scan terakhir
    final trimmed = existing.take(30).map((s) => s.toMap()).toList();
    final key = _getUserScanStorageKey(fallbackIdentifier);
    await _settings.put(key, trimmed);
  }

  Future<void> deleteProductScan(
    String scanId, [
    String? fallbackIdentifier,
  ]) async {
    final existing = await loadProductScans(fallbackIdentifier);
    existing.removeWhere((s) => s.id == scanId);
    final key = _getUserScanStorageKey(fallbackIdentifier);
    await _settings.put(key, existing.map((s) => s.toMap()).toList());
  }

  Future<void> clearProductScans([String? fallbackIdentifier]) async {
    final key = _getUserScanStorageKey(fallbackIdentifier);
    await _settings.delete(key);
  }

  // ------------------------------------------------------------- AI CALLS
  /// 1. Fitur AI: Scan & Identifikasi Produk dari Foto
  Future<String> scanProduct({
    required Uint8List imageBytes,
    String? additionalNotes,
  }) async {
    final queryText = additionalNotes != null && additionalNotes.trim().isNotEmpty
        ? '\nCatatan/Pertanyaan tambahan dari pengguna: "${additionalNotes.trim()}"'
        : '';

    final prompt =
        'Kamu adalah AI Beauty & Skincare Product Scanner dalam aplikasi Mirrora.\n'
        'Tugasmu adalah menganalisis foto kemasan atau produk skincare/makeup ini secara detail, akurat, dan terstruktur.\n'
        '$queryText\n\n'
        'Berikan rincian penjelasan lengkap dengan urutan berikut:\n'
        '1. NAMA & MEREK PRODUK: (Sebutkan nama produk dan brand yang terlihat jelas di kemasan)\n'
        '2. KATEGORI & FUNGSI UTAMA: (Misal: Gentle Cleanser, Hydrating Toner, Brightening Serum, Physical Sunscreen, Cushion, dll.)\n'
        '3. MANFAAT PRODUK: (Manfaat utama produk bagi kesehatan kulit atau tampilan wajah)\n'
        '4. KANDUNGAN KUNCI (KEY INGREDIENTS): (Bahan aktif utama seperti Niacinamide, Salicylic Acid, Ceramide, Hyaluronic Acid, dll. beserta fungsinya)\n'
        '5. CARA & WAKTU PAKAI: (Pagi atau malam hari, urutan pemakaian sebelum/setelah produk apa, serta cara pengaplikasian yang tepat)\n'
        '6. KECOCOKAN TIPE KULIT: (Sesuai untuk kulit berminyak, kering, kombinasi, sensitif, atau berjerawat)\n'
        '7. CATATAN & PERHATIAN: (Peringatan pemakaian, alcohol/fragrance note jika ada, dan anjuran patch test)\n\n'
        'PANDUAN FORMAT:\n'
        '- Gunakan Bahasa Indonesia yang ramah, bersih, dan jelas.\n'
        '- JANGAN gunakan tanda pagar Markdown (#, ##) untuk header.\n'
        '- JANGAN gunakan tanda bintang (* atau **) untuk menebalkan kata.\n'
        '- Gunakan penomoran dan bullet (•) yang rapi agar nyaman dibaca di layar HP.';

    return sendMessage(
      prompt: prompt,
      imageBytes: imageBytes,
      existingHistory: const [],
    );
  }

  /// 2. Fitur LLM: Mirrora Assistant dengan Guardrails Ketat
  /// Hanya boleh menjawab topik Beauty, Self-Care, Skincare, dan Makeup.
  Future<String> askAssistant({
    required String userQuery,
    List<AiChatMessage>? existingHistory,
  }) async {
    // Sisipkan pengarah guardrails agar LLM menolak pertanyaan di luar 4 pilar
    final promptWithGuardrail =
        '[INSTRUKSI SISTEM MIRRORA ASSISTANT: Kamu adalah "Mirrora Assistant", asisten konsultasi yang KHUSUS berfokus pada Beauty, Self-Care, Skincare, dan Makeup. '
        'Jika pertanyaan pengguna berkaitan dengan salah satu dari 4 topik tersebut, jawablah dengan ramah, edukatif, dan praktis seperti beauty bestie. '
        'Namun, JIKA pengguna bertanya tentang hal DI LUAR 4 tema tersebut (seperti coding/programming, rumus matematika, fisika, politik, berita umum, sejarah non-beauty, resep masakan umum, otomotif, tugas sekolah, dll.), '
        'kamu HARUS MENOLAK dengan ramah dan sopan bahwa kamu adalah Mirrora Assistant dan hal tersebut di luar kapasitasmu, '
        'kemudian ajak pengguna untuk kembali membahas perawatan kecantikan, skincare, atau self-care.]\n\n'
        'Pertanyaan Pengguna: ${userQuery.trim()}';

    return sendMessage(
      prompt: promptWithGuardrail,
      existingHistory: existingHistory,
    );
  }

  /// Mengirim pesan (teks atau teks + gambar) ke Edge Function `ai-chat`
  Future<String> sendMessage({
    required String prompt,
    Uint8List? imageBytes,
    List<AiChatMessage>? existingHistory,
  }) async {
    final past = (existingHistory ?? const <AiChatMessage>[])
        .where((m) => m.id != 'welcome' && !m.isError)
        .toList();
    if (past.isNotEmpty && past.last.isUser) past.removeLast();

    final recent = past.length > _maxHistory
        ? past.sublist(past.length - _maxHistory)
        : past;

    final body = <String, dynamic>{
      'prompt': prompt.trim().isEmpty
          ? 'Jelaskan foto produk atau kulit ini dan berikan saran yang sesuai.'
          : prompt.trim(),
      'history': recent
          .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
          .toList(),
      if (imageBytes != null)
        'image': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
    };

    try {
      final res = await Supabase.instance.client.functions.invoke(
        _functionName,
        body: body,
      );
      final data = res.data;
      final text = data is Map ? data['text'] : null;
      if (text is String && text.trim().isNotEmpty) return text;
      return 'Maaf, tidak ada tanggapan yang diterima.';
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map
          ? details['error']?.toString()
          : details?.toString();
      throw Exception('${e.status} ${message ?? ''}'.trim());
    }
  }
}
