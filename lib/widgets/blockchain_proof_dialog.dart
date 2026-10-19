import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/giveaway_model.dart';
import '../services/giveaway_service.dart';
import '../theme/mirrora_theme.dart';

class BlockchainProofDialog extends StatelessWidget {
  const BlockchainProofDialog({
    super.key,
    required this.block,
  });

  final BlockchainBlock block;

  static void show(BuildContext context, BlockchainBlock block) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlockchainProofDialog(block: block),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: MirroraTheme.charcoal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}*@$domain';
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final isValid = block.isValid();
    final isChainValid = GiveawayService().blockchain.verifyIntegrity();
    final date = DateTime.fromMillisecondsSinceEpoch(block.timestamp);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';

    return Dialog(
      backgroundColor: MirroraTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sertifikat Blockchain',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verifikasi Hasil Undian Anti-Manipulasi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: MirroraTheme.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Integritas Rantai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (isValid && isChainValid)
                      ? const Color(0xFFF1F8F5)
                      : const Color(0xFFFDF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isValid && isChainValid)
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                        : Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (isValid && isChainValid)
                          ? Icons.lock_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: (isValid && isChainValid)
                          ? const Color(0xFF2E7D32)
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (isValid && isChainValid)
                            ? 'Rantai Blok Valid & Terkunci Permanen'
                            : 'Peringatan: Hash Blok Tidak Cocok!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (isValid && isChainValid)
                              ? const Color(0xFF1B5E20)
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Detail Pemenang Terkunci
              _buildSectionTitle('Data Pemenang Sah'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MirroraTheme.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MirroraTheme.blushPink),
                ),
                child: Column(
                  children: [
                    _buildRowItem('Nama Pemenang', block.winnerName, isBold: true),
                    const Divider(height: 16, color: MirroraTheme.blushPink),
                    _buildRowItem('Nomor Tiket', block.entryTicket, isBold: true),
                    const Divider(height: 16, color: MirroraTheme.blushPink),
                    _buildRowItem('Email Peserta', _maskEmail(block.winnerEmail)),
                    const Divider(height: 16, color: MirroraTheme.blushPink),
                    _buildRowItem('Hadiah', block.prize),
                    const Divider(height: 16, color: MirroraTheme.blushPink),
                    _buildRowItem('Total Peserta', '${block.totalParticipants} Akun'),
                    const Divider(height: 16, color: MirroraTheme.blushPink),
                    _buildRowItem('Waktu Eksekusi', dateStr),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Kriptografi Hash SHA-256
              _buildSectionTitle('Kriptografi SHA-256 (Hash Blok)'),
              const SizedBox(height: 8),
              _buildHashBox(
                context,
                title: 'Current Block Hash (Blok #${block.index})',
                hash: block.hash,
              ),
              const SizedBox(height: 10),
              _buildHashBox(
                context,
                title: 'Previous Hash (Rantai Sebelumnya)',
                hash: block.previousHash,
              ),
              const SizedBox(height: 14),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MirroraTheme.blushPink.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: MirroraTheme.dustyRose),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setiap karakter pemenang dirantai dengan algoritma SHA-256. Jika data diubah 1 huruf saja, seluruh hash rantai akan rusak dan terdeteksi curang.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color: Color(0xFF4A4543),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Tutup
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MirroraTheme.dustyRose,
                    foregroundColor: MirroraTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text(
                    'Tutup Verifikasi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: MirroraTheme.charcoal,
      ),
    );
  }

  Widget _buildRowItem(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: MirroraTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildHashBox(BuildContext context, {required String title, required String hash}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A5568),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _copyToClipboard(context, hash, title),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: MirroraTheme.dustyRose),
                      SizedBox(width: 4),
                      Text(
                        'Salin',
                        style: TextStyle(fontSize: 10.5, color: MirroraTheme.dustyRose, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hash,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }
}
