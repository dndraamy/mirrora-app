import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageBytes,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Uint8List? imageBytes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AiChatMessage.fromMap(Map<dynamic, dynamic> map) => AiChatMessage(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        isUser: map['isUser'] as bool? ?? false,
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class AiService {
  static const String _settingsBoxName = 'settingsBox';
  static const String _apiKeyStorageKey = 'mirrora_gemini_api_key';
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const List<String> _candidateModels = [
    'gemini-flash-lite-latest',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
  ];

  int _currentModelIndex = 0;
  GenerativeModel? _model;
  ChatSession? _chatSession;

  static const String _systemInstruction = '''
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
''';

  Box get _settings => Hive.box(_settingsBoxName);

  /// Mengecek apakah API key sudah tersedia
  bool get hasApiKey => getApiKey().isNotEmpty;

  /// Mengambil API key yang aktif
  String getApiKey() {
    final dynamic key = _settings.get(_apiKeyStorageKey);
    if (key is String && key.trim().isNotEmpty) {
      return key.trim();
    }
    return _defaultApiKey;
  }

  /// Menyimpan API key ke Hive
  Future<void> saveApiKey(String apiKey) async {
    await _settings.put(_apiKeyStorageKey, apiKey.trim());
    _resetModel();
  }

  /// Menghapus API key
  Future<void> removeApiKey() async {
    await _settings.delete(_apiKeyStorageKey);
    _resetModel();
  }

  void _resetModel() {
    _model = null;
    _chatSession = null;
  }

  /// Inisialisasi model Generative AI
  GenerativeModel _getModel() {
    final apiKey = getApiKey();
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'Gemini API Key belum dipasang. Jalankan aplikasi dengan --dart-define-from-file=env.json.',
      );
    }

    final modelName = _candidateModels[_currentModelIndex];
    _model ??= GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
    );

    return _model!;
  }

  String? _lastSessionUserId;

  /// Menghasilkan storage key unik berdasarkan akun pengguna yang sedang login
  String _getUserStorageKey([String? fallbackIdentifier]) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return 'mirrora_chat_uid_${user.id}';
      }
      if (user?.email != null && user!.email!.isNotEmpty) {
        return 'mirrora_chat_email_${user.email!.toLowerCase().trim()}';
      }
    } catch (_) {}

    final id = (fallbackIdentifier ?? 'default').toLowerCase().trim();
    return 'mirrora_chat_user_$id';
  }

  void _checkUserSession() {
    final currentKey = _getUserStorageKey();
    if (_lastSessionUserId != null && _lastSessionUserId != currentKey) {
      _resetModel();
    }
    _lastSessionUserId = currentKey;
  }

  /// Mengambil riwayat percakapan yang tersimpan di Hive untuk user aktif
  Future<List<AiChatMessage>> loadChatHistory([String? fallbackIdentifier]) async {
    _checkUserSession();
    final key = _getUserStorageKey(fallbackIdentifier);
    final dynamic raw = _settings.get(key);
    if (raw is List) {
      final list = <AiChatMessage>[];
      for (final item in raw) {
        if (item is Map) {
          list.add(AiChatMessage.fromMap(item));
        }
      }
      return list;
    }
    return [];
  }

  /// Menyimpan riwayat percakapan ke Hive untuk user aktif
  Future<void> saveChatHistory(
    List<AiChatMessage> messages, [
    String? fallbackIdentifier,
  ]) async {
    final key = _getUserStorageKey(fallbackIdentifier);
    final serialized = messages
        .where((m) => m.id != 'welcome')
        .map((m) => m.toMap())
        .toList();
    await _settings.put(key, serialized);
  }

  /// Menghapus riwayat percakapan dari Hive untuk user aktif
  Future<void> clearChatHistory([String? fallbackIdentifier]) async {
    final key = _getUserStorageKey(fallbackIdentifier);
    await _settings.delete(key);
    clearChatSession();
  }

  /// Mengirim pesan ke AI, mendukung multimodal (teks + gambar) dan otomatis fallback jika model sibuk
  Future<String> sendMessage({
    required String prompt,
    Uint8List? imageBytes,
    List<AiChatMessage>? existingHistory,
  }) async {
    _checkUserSession();
    Object? lastError;

    for (int attempt = 0; attempt < _candidateModels.length; attempt++) {
      try {
        final model = _getModel();

        // Jika ada lampiran gambar, kirim sebagai multi-part generateContent
        if (imageBytes != null) {
          final content = [
            Content.multi([
              TextPart(
                prompt.isEmpty
                    ? 'Jelaskan foto produk atau kulit ini dan berikan saran yang sesuai.'
                    : prompt,
              ),
              DataPart('image/jpeg', imageBytes),
            ]),
          ];
          final response = await model.generateContent(content);
          return response.text ??
              'Maaf, aku belum bisa menganalisis foto ini saat ini.';
        }

        // Jika session belum ada, mulai chat dengan riwayat jika tersedia
        if (_chatSession == null) {
          final historyContents = <Content>[];
          if (existingHistory != null) {
            // Ambil maksimal 10 riwayat percakapan terakhir agar konteks tetap nyambung
            final nonWelcome = existingHistory.where((m) => m.id != 'welcome').toList();
            final recent = nonWelcome.length > 10
                ? nonWelcome.sublist(nonWelcome.length - 10)
                : nonWelcome;

            for (final msg in recent) {
              if (msg.isUser) {
                historyContents.add(Content.text(msg.text));
              } else {
                historyContents.add(Content.model([TextPart(msg.text)]));
              }
            }
          }
          _chatSession = model.startChat(
            history: historyContents.isNotEmpty ? historyContents : null,
          );
        }

        final response = await _chatSession!.sendMessage(Content.text(prompt));
        return response.text ?? 'Maaf, tidak ada tanggapan yang diterima.';
      } catch (e) {
        lastError = e;
        // Beralih ke model cadangan berikutnya jika model saat ini bermasalah
        _currentModelIndex =
            (_currentModelIndex + 1) % _candidateModels.length;
        _resetModel();
      }
    }

    throw lastError ?? Exception('Gagal menghubungi layanan AI');
  }

  /// Menghapus sesi chat yang aktif
  void clearChatSession() {
    _chatSession = null;
  }
}