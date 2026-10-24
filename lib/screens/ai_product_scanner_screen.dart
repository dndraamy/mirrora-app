
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_service.dart';
import '../theme/mirrora_theme.dart';
import 'mirrora_assistant_screen.dart';

/// Halaman Fitur Menu "AI" (Product Identifier & Detail Scanner)
/// Memfasilitasi pengguna untuk memotret atau mengunggah foto kemasan/produk skincare & makeup
/// guna mengetahui detail produk, manfaat, kandungan kunci, urutan pemakaian, dan kecocokan kulit.
class AiProductScannerScreen extends StatefulWidget {
  const AiProductScannerScreen({super.key, this.userName = 'Sarah'});

  final String userName;

  @override
  State<AiProductScannerScreen> createState() => _AiProductScannerScreenState();
}

class _AiProductScannerScreenState extends State<AiProductScannerScreen> {
  final AiService _aiService = AiService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isAnalyzing = false;
  String? _analysisResult;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Membersihkan teks hasil analisis dari Markdown kasar (#, *, ---) agar enak dibaca
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _errorMessage = null;
        _analysisResult = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil gambar: $e')),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _analysisResult = null;
      _errorMessage = null;
    });
  }

  Future<void> _startScan() async {
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan ambil foto atau pilih gambar produk terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      final rawResult = await _aiService.scanProduct(
        imageBytes: _selectedImageBytes!,
        additionalNotes: _notesController.text,
      );

      final cleaned = _cleanText(rawResult);

      // Ekstrak nama produk secara cerdas dari baris pertama hasil
      var detectedName = 'Produk Terdeteksi';
      final match = RegExp(r'(?:NAMA|PRODUK|MEREK)[^:\n]*:\s*([^\n]+)', caseSensitive: false)
          .firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        detectedName = match.group(1)!.trim();
      }

      // Simpan ke riwayat scan lokal
      final scanRecord = AiProductScan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productName: detectedName,
        category: 'Skincare/Beauty',
        analysisResult: cleaned,
        timestamp: DateTime.now(),
        imageBytes: _selectedImageBytes,
      );
      await _aiService.saveProductScan(scanRecord, widget.userName);

      if (!mounted) return;
      setState(() {
        _analysisResult = cleaned;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Gagal menganalisis produk: $e. Pastikan koneksi internet stabil.';
      });
    }
  }

  void _openHistorySheet() async {
    final history = await _aiService.loadProductScans(widget.userName);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MirroraTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MirroraTheme.blushPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Riwayat Scan Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        if (history.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await _aiService.clearProductScans(widget.userName);
                              setSheetState(() => history.clear());
                            },
                            child: const Text(
                              'Hapus Semua',
                              style: TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Belum ada riwayat scan produk.\nFoto produk skincare pertamamu sekarang! ✨',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: MirroraTheme.warmGray, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: history.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final item = history[idx];
                            return Container(
                              decoration: BoxDecoration(
                                color: MirroraTheme.cream,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: MirroraTheme.blushPink),
                              ),
                              child: ListTile(
                                leading: item.imageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          item.imageBytes!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: MirroraTheme.blushPink,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.photo_camera_rounded,
                                          color: MirroraTheme.dustyRose,
                                        ),
                                      ),
                                title: Text(
                                  item.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: MirroraTheme.charcoal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year} • ${item.category}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MirroraTheme.warmGray,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: MirroraTheme.dustyRose,
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _selectedImageBytes = item.imageBytes;
                                    _analysisResult = item.analysisResult;
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                Icons.center_focus_strong_rounded,
                color: MirroraTheme.dustyRose,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mirrora AI',
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
            tooltip: 'Riwayat Scan',
            icon: const Icon(Icons.history_rounded, color: MirroraTheme.charcoal),
            onPressed: _openHistorySheet,
          ),
          IconButton(
            tooltip: 'Buka Mirrora Assistant',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: MirroraTheme.dustyRose),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MirroraAssistantScreen(userName: widget.userName),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. BANNER PENGANTAR MENU AI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MirroraTheme.blushPink,
                    MirroraTheme.cream,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MirroraTheme.dustyRose.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MirroraTheme.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: MirroraTheme.dustyRose.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: MirroraTheme.dustyRose,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deteksi & Pelajari Produkmu ✨',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Foto kemasan atau label produk skincare/makeup untuk mengetahui detail fungsi, kandungan bahan, cara pakai, dan kecocokan kulitmu.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: MirroraTheme.warmGray,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. KOTAK UPLOAD / PREVIEW FOTO
            Container(
              decoration: BoxDecoration(
                color: MirroraTheme.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _selectedImageBytes != null
                      ? MirroraTheme.dustyRose
                      : MirroraTheme.blushPink,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _selectedImageBytes == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: MirroraTheme.blushPink.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 42,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Pilih atau Ambil Foto Produk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pastikan label merek dan nama produk terlihat terang & jelas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: MirroraTheme.warmGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                label: const Text('Kamera'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: MirroraTheme.dustyRose,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded, size: 18),
                                label: const Text('Galeri'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: MirroraTheme.dustyRose,
                                  side: const BorderSide(color: MirroraTheme.dustyRose, width: 1.4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: Stack(
                            children: [
                              Image.memory(
                                _selectedImageBytes!,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: InkWell(
                                  onTap: _clearImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedImageName ?? 'Foto Produk Dipilih',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: MirroraTheme.charcoal,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Ganti Foto', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: MirroraTheme.dustyRose,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // 3. INPUT CATATAN / PERTANYAAN TAMBAHAN (OPSIONAL)
            if (_selectedImageBytes != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: MirroraTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MirroraTheme.blushPink),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ingin tanya hal khusus tentang produk ini? (opsional)',
                    hintStyle: TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    icon: Icon(Icons.help_outline_rounded, color: MirroraTheme.dustyRose, size: 20),
                  ),
                  style: const TextStyle(fontSize: 13, color: MirroraTheme.charcoal),
                ),
              ),
              const SizedBox(height: 16),

              // TOMBOL ANALISIS DENGAN AI
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _startScan,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: Text(
                    _isAnalyzing ? 'Sedang Menganalisis Foto...' : 'Analisis Produk Ini',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MirroraTheme.dustyRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. PESAN ERROR JIKA GAGAL
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),

            // 5. KARTU HASIL ANALISIS PRODUK
            if (_analysisResult != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MirroraTheme.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: MirroraTheme.blushPink),
                  boxShadow: [
                    BoxShadow(
                      color: MirroraTheme.dustyRose.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MirroraTheme.blushPink,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: MirroraTheme.dustyRose,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Hasil Analisis AI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MirroraTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Salin Teks',
                          icon: const Icon(Icons.copy_rounded, size: 20, color: MirroraTheme.warmGray),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _analysisResult!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hasil analisis berhasil disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(color: MirroraTheme.blushPink, height: 24),
                    SelectableText(
                      _analysisResult!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: MirroraTheme.charcoal,
                        height: 1.6,
                        letterSpacing: 0.15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action: Tanya ke Mirrora Assistant
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MirroraTheme.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MirroraTheme.blushPink),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.smart_toy_rounded,
                            color: MirroraTheme.dustyRose,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Masih ragu atau ada pertanyaan?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: MirroraTheme.charcoal,
                                  ),
                                ),
                                Text(
                                  'Konsultasikan langsung dengan Mirrora Assistant',
                                  style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MirroraAssistantScreen(userName: widget.userName),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MirroraTheme.dustyRose,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Tanya', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

