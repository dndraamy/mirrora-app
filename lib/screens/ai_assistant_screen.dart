import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_service.dart';
import '../theme/mirrora_theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, this.userName = 'Sarah'});

  final String userName;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  final List<String> _quickPrompts = [
    '🌸 Rutinitas skincare pagi untuk kulit kusam',
    '✨ Apakah Retinol aman digabung Niacinamide?',
    '💧 Cara memperbaiki skin barrier yang rusak',
    '🌿 Rekomendasi self-care untuk meredakan stres',
    '☀️ Kapan waktu yang tepat reapply sunscreen?',
  ];

  @override
  void initState() {
    super.initState();
    _loadPersistedChat();
  }

  @override
  void didUpdateWidget(covariant AiAssistantScreen oldWidget) {
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
    // 1. Hapus tanda pagar heading (#, ##, ###, ####)
    cleaned = cleaned.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    // 2. Hapus garis pemisah (---, ***, ___)
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');
    // 3. Hapus tanda bintang tebal (**kata**) dan miring (*kata*)
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    // 4. Ubah tanda dash (- ) di awal baris menjadi bullet point rapi (• )
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '• ');
    // 5. Rapikan baris kosong berlebih
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
            'Hai, ${widget.userName}! ✨\n\n'
            'Aku Mirrora AI Beauty Assistant. Kamu bisa berkonsultasi mengenai urutan skincare, '
            'kandungan bahan aktif, mengatasi masalah kulit, ataupun tips self-care harian.\n\n'
            'Kamu juga bisa mengunggah foto produk atau kondisi kulit untuk dianalisis lho!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      _showToast('Gagal memilih gambar: $e');
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _handleSendMessage([String? predefinedText]) async {
    final text = (predefinedText ?? _textController.text).trim();
    final imageBytes = _selectedImageBytes;

    if (text.isEmpty && imageBytes == null) return;

    _textController.clear();
    _clearSelectedImage();

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.isEmpty ? 'Menganalisis gambar...' : text,
      isUser: true,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();
    await _aiService.saveChatHistory(_messages, widget.userName);

    try {
      final aiResponse = await _aiService.sendMessage(
        prompt: text,
        imageBytes: imageBytes,
        existingHistory: _messages,
      );

      final cleanResponse = _cleanText(aiResponse);

      final assistantMsg = AiChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: cleanResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(assistantMsg);
        _isLoading = false;
      });
      _scrollToBottom();
      await _aiService.saveChatHistory(_messages, widget.userName);
    } catch (e) {
      setState(() => _isLoading = false);

      String friendlyError =
          'Maaf, terjadi kendala saat menghubungkan ke AI. Silakan coba kirim ulang pesanmu ya.';
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('503') ||
          errorString.contains('high demand') ||
          errorString.contains('unavailable')) {
        friendlyError =
            'Server AI sedang sangat ramai pengguna saat ini. Mohon tunggu beberapa saat dan coba kirim kembali pertanyaanmu ya.';
      } else if (errorString.contains('429') ||
          errorString.contains('quota')) {
        friendlyError =
            'Batas kuota AI tercapai sementara. Silakan coba kembali beberapa saat lagi.';
      }

      _showToast(friendlyError);

      final errorMsg = AiChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: friendlyError,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() => _messages.add(errorMsg));
      _scrollToBottom();
      await _aiService.saveChatHistory(_messages, widget.userName);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetChat() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Percakapan?'),
        content: const Text(
          'Semua riwayat obrolan akan dihapus dan percakapan dimulai kembali dari awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _aiService.clearChatHistory(widget.userName);
              setState(() {
                _initWelcomeMessage();
                _clearSelectedImage();
              });
              _showToast('Percakapan di-reset');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MirroraTheme.dustyRose,
              foregroundColor: MirroraTheme.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: MirroraTheme.dustyRose,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mirrora AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                Text(
                  'Beauty & Self-Care Consultant',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mulai Ulang Percakapan',
            onPressed: _resetChat,
            icon: const Icon(Icons.refresh_rounded, color: MirroraTheme.charcoal),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildChatList()),
            if (_quickPrompts.isNotEmpty && _messages.length <= 2)
              _buildQuickPromptsBar(),
            if (_selectedImageBytes != null) _buildSelectedImagePreview(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(
                fontSize: 12,
                color: MirroraTheme.charcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: MirroraTheme.white,
            side: const BorderSide(color: MirroraTheme.blushPink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _handleSendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingBubble();
        }
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser = msg.isUser;
    final displayText = _cleanText(msg.text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                color: MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: MirroraTheme.dustyRose,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? MirroraTheme.dustyRose : MirroraTheme.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser ? null : Border.all(color: MirroraTheme.blushPink),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        msg.imageBytes!,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SelectableText(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser ? MirroraTheme.white : MirroraTheme.charcoal,
                    ),
                  ),
                  if (!isUser && msg.id != 'welcome') ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: displayText));
                            _showToast('Teks disalin ke clipboard');
                          },
                          child: const Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: MirroraTheme.warmGray,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: MirroraTheme.warmGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: MirroraTheme.blushPink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: MirroraTheme.dustyRose,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MirroraTheme.white,
              borderRadius: BorderRadius.circular(18),
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
                    color: MirroraTheme.dustyRose,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Mirrora sedang meracik saran...',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MirroraTheme.white,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedImageName ?? 'Foto dipilih',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                const Text(
                  'Siap dikirim untuk dianalisis oleh AI',
                  style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: MirroraTheme.warmGray),
            onPressed: _clearSelectedImage,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Lampirkan Foto Produk/Kulit',
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              color: MirroraTheme.dustyRose,
            ),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: MirroraTheme.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_outlined),
                        title: const Text('Ambil dari Kamera'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Pilih dari Galeri'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendMessage(),
              decoration: InputDecoration(
                hintText: 'Tanyakan seputar skincare & self-care...',
                filled: true,
                fillColor: MirroraTheme.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: MirroraTheme.blushPink),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: MirroraTheme.blushPink),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: MirroraTheme.dustyRose,
                    width: 1.5,
                  ),
                ),
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
              icon: const Icon(Icons.arrow_upward_rounded, color: MirroraTheme.white),
              onPressed: _isLoading ? null : () => _handleSendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
