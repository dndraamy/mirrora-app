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
      };

  factory AiChatMessage.fromMap(Map<dynamic, dynamic> map) => AiChatMessage(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        isUser: map['isUser'] as bool? ?? false,
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Chat AI lewat Supabase Edge Function `ai-chat`.
/// API key Gemini TIDAK ada di aplikasi, hanya di Supabase Secrets.
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

  /// Kompatibilitas: sekarang server yang mengatur sesi, jadi tidak ada
  /// state sesi di aplikasi. Dibiarkan agar pemanggil lama tidak error.
  void clearChatSession() {}

  /// Kirim pesan (teks, atau teks + gambar) dan kembalikan jawaban AI.
  /// [existingHistory] boleh sudah memuat pesan yang sedang dikirim,
  /// pesan terakhir user akan dibuang supaya tidak terkirim dua kali.
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
      // Kode status disertakan agar layar bisa memetakan 429 / 503
      throw Exception('${e.status} ${message ?? ''}'.trim());
    }
  }
}