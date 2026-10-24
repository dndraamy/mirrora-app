import 'package:flutter/material.dart';

import '../models/giveaway_model.dart';
import '../theme/mirrora_theme.dart';
import 'blockchain_proof_dialog.dart';
import 'winner_claim_sheet.dart';

class WinnerCelebrationDialog extends StatelessWidget {
  const WinnerCelebrationDialog({
    super.key,
    required this.block,
  });

  final BlockchainBlock block;

  static void show(BuildContext context, BlockchainBlock block) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WinnerCelebrationDialog(block: block),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MirroraTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Piala Berkilau
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MirroraTheme.softGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'SELAMAT! KAMU MENANG! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),

            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: MirroraTheme.warmGray,
                ),
                children: [
                  const TextSpan(text: 'Tiket kamu '),
                  TextSpan(
                    text: block.entryTicket,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.dustyRose,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' terpilih secara acak dan sah sebagai pemenang resmi:\n',
                  ),
                  TextSpan(
                    text: block.prize,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Petunjuk Klaim Data Diri
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MirroraTheme.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MirroraTheme.blushPink),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: MirroraTheme.dustyRose, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Silakan isi data diri kamu untuk klaim hadiah agar paket dapat segera kami kirimkan ke alamatmu.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF4A4543), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Tombol Utama: Isi Data Diri Sekarang
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  WinnerClaimSheet.show(context, winnerBlock: block);
                },
                icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                label: const Text('Isi Data Diri Sekarang 🎁', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MirroraTheme.dustyRose,
                  foregroundColor: MirroraTheme.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Lihat Sertifikat Resmi (Outlined)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  BlockchainProofDialog.show(context, block);
                },
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Lihat Sertifikat Resmi 📜', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MirroraTheme.dustyRose,
                  side: const BorderSide(color: MirroraTheme.blushPink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Tombol Nanti Saja (TextButton)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: MirroraTheme.warmGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Nanti Saja', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
