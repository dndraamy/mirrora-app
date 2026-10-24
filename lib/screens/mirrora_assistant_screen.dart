import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../theme/mirrora_theme.dart';
import 'ai_product_scanner_screen.dart';

/// Halaman Fitur Menu "Mirrora Assistant" (LLM Chatbot)
/// Berfungsi sebagai asisten cerdas interaktif bagi pengguna aplikasi Mirrora.
/// Memiliki guardrails ketat: HANYA melayani topik seputar Beauty, Self-Care, Skincare, dan Makeup.
class MirroraAssistantScreen extends StatefulWidget {
  const MirroraAssistantScreen({super.key, this.userName = 'Sarah'});

  final String userName;

  @override
  State<MirroraAssistantScreen> createState() => _MirroraAssistantScreenState();
}

class _MirroraAssistantScreenState extends State<MirroraAssistantScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    '🌸 Urutan skincare pagi & malam untuk kulit kusam',
    '✨ Tips makeup tahan lama untuk kulit berminyak',
    '💧 Cara memperbaiki skin barrier yang rusak',
    '🌿 Rekomendasi self-care untuk meredakan stres',
    '☀️ Kapan waktu yang tepat reapply sunscreen?',
    '💄 Cara memilih shade foundation sesuai undertone kulit',
  ];

  @override
  void initState() {
    super.initState();
    _loadPersistedChat();
  }

  @override
  void didUpdateWidget(covariant MirroraAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _loadPersistedChat();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Membersihkan simbol Markdown kasar (#, *, ---) agar tampilan bersih seperti chat biasa
  String _cleanText(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '• ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  /// Memuat riwayat chat dari Hive saat pertama kali dibuka
  Future<void> _loadPersistedChat() async {
    final history = await _aiService.loadChatHistory(widget.userName);
    if (!mounted) return;
    if (history.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });
    } else {
      _initWelcomeMessage();
    }
    _scrollToBottom();
  }

  void _initWelcomeMessage() {
    _messages.clear();
    _messages.add(
      AiChatMessage(
        id: 'welcome',
        text:
            'Hai, ${widget.userName}!\n\n'
            'Aku Mirrora Assistant.\n'
            'Kamu bisa berkonsultasi seputar skincare, makeup, self-care, dan tips-tips lainnya denganku\n\n'
            'Ada yang ingin kamu tanyakan hari ini?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _sendMessage({String? customText}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      if (customText == null) _textController.clear();
    });

    _scrollToBottom();

    try {
      final rawResponse = await _aiService.askAssistant(
        userQuery: text,
        existingHistory: _messages,
      );

      final cleanedResponse = _cleanText(rawResponse);

      final aiMessage = AiChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: cleanedResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      await _aiService.saveChatHistory(_messages, widget.userName);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final rawErr = e.toString().replaceFirst('Exception: ', '').trim();
      String humanError;

      if (rawErr.startsWith('429')) {
        humanError = 'Batas penggunaan harian tercapai. Silakan coba lagi besok ya! ✨';
      } else if (rawErr.startsWith('401')) {
        humanError = 'Sesi kamu telah berakhir. Silakan login kembali.';
      } else if (rawErr.startsWith('503')) {
        humanError = 'Layanan asisten sedang sibuk, silakan tunggu sebentar dan coba lagi.';
      } else {
        humanError = 'Gagal menghubungi asisten. Pastikan koneksi internet stabil.';
      }

      setState(() {
        _messages.add(
          AiChatMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            text: humanError,
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mulai Chat Baru?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Semua pesan dalam percakapan ini akan dibersihkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MirroraTheme.dustyRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await _aiService.clearChatHistory(widget.userName);
    setState(() => _initWelcomeMessage());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: MirroraTheme.dustyRose,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mirrora Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan Foto Produk (Menu AI)',
            icon: const Icon(Icons.photo_camera_rounded, color: MirroraTheme.dustyRose),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiProductScannerScreen(userName: widget.userName),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Mulai Chat Baru',
            icon: const Icon(Icons.refresh_rounded, color: MirroraTheme.charcoal),
            onPressed: _clearChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Banner Guardrail Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: MirroraTheme.blushPink.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: MirroraTheme.dustyRose,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Asisten ini khusus melayani konsultasi beauty, self-care, skincare, dan makeup.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),

          // Quick Prompt Recommendations
          if (_messages.length <= 2 && !_isLoading) _buildQuickPromptsBar(),

          // Typing Loading Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: MirroraTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MirroraTheme.blushPink),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(MirroraTheme.dustyRose),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mirrora Assistant sedang mengetik...',
                        style: TextStyle(
                          fontSize: 12,
                          color: MirroraTheme.warmGray,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(AiChatMessage message) {
    final isUser = message.isUser;
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent.withValues(alpha: 0.15) : MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.smart_toy_rounded,
                size: 16,
                color: isError ? Colors.redAccent : MirroraTheme.dustyRose,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? MirroraTheme.dustyRose
                    : isError
                        ? const Color(0xFFFFEBEE)
                        : MirroraTheme.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isError
                            ? Colors.redAccent.withValues(alpha: 0.3)
                            : MirroraTheme.blushPink,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isUser
                      ? Colors.white
                      : isError
                          ? Colors.redAccent
                          : MirroraTheme.charcoal,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: MirroraTheme.charcoal,
              ),
            ),
            backgroundColor: MirroraTheme.white,
            side: const BorderSide(color: MirroraTheme.blushPink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _sendMessage(customText: prompt),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: MirroraTheme.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MirroraTheme.cream,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MirroraTheme.blushPink),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Tanya seputar beauty, skincare, makeup...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13.5, color: MirroraTheme.charcoal),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: MirroraTheme.dustyRose,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                onPressed: _isLoading ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

