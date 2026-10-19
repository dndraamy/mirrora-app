import 'package:flutter/material.dart';

import '../models/giveaway_model.dart';
import '../theme/mirrora_theme.dart';
import 'blockchain_proof_dialog.dart';

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
                        ' terpilih secara acak dan sah melalui verifikasi Blockchain untuk memenangkan:\n',
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

            // Petunjuk Klaim
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MirroraTheme.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MirroraTheme.blushPink),
              ),
              child: const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: MirroraTheme.dustyRose, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tim Mirrora akan menghubungi email akunmu untuk konfirmasi pengiriman paket hadiah.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF4A4543), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Tombol Lihat Bukti Blockchain
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  BlockchainProofDialog.show(context, block);
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Cek Bukti Blockchain ⛓️'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MirroraTheme.dustyRose,
                  side: const BorderSide(color: MirroraTheme.dustyRose),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Tutup
            SizedBox(
              width: double.infinity,
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
                child: const Text('Terima Kasih! ✨', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
