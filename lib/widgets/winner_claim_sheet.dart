import 'package:flutter/material.dart';

import '../models/giveaway_model.dart';
import '../services/giveaway_service.dart';
import '../theme/mirrora_theme.dart';

/// Modal bottom sheet untuk pemenang mengisi / mengubah data diri pengiriman hadiah giveaway
class WinnerClaimSheet {
  static void show(
    BuildContext context, {
    GiveawayCampaign? campaign,
    required BlockchainBlock winnerBlock,
  }) {
    final activeCampaign = campaign ?? GiveawayService().currentCampaign;
    final existingClaim = activeCampaign.winnerClaimData;
    final nameCtrl = TextEditingController(
      text: existingClaim?.fullName ?? winnerBlock.winnerName,
    );
    final phoneCtrl = TextEditingController(
      text: existingClaim?.phoneNumber ?? '',
    );
    final addressCtrl = TextEditingController(
      text: existingClaim?.shippingAddress ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existingClaim?.notes ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: MirroraTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MirroraTheme.blushPink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('🎁', style: TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Klaim Hadiah Giveaway',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.charcoal,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            winnerBlock.prize,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MirroraTheme.blushPink),
                  ),
                  child: Text(
                    'Mohon isi alamat lengkap pengiriman dan nomor WhatsApp aktif agar paket hadiah ${winnerBlock.prize} dapat segera kami kirimkan ke rumahmu.',
                    style: const TextStyle(fontSize: 11.5, height: 1.45, color: MirroraTheme.charcoal),
                  ),
                ),
                const SizedBox(height: 16),

                // Field 1: Nama Penerima
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap Penerima',
                    labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    filled: true,
                    fillColor: MirroraTheme.cream,
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: MirroraTheme.dustyRose),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Field 2: No WhatsApp / HP
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor WhatsApp / HP Aktif',
                    hintText: '08123456789',
                    labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    filled: true,
                    fillColor: MirroraTheme.cream,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: MirroraTheme.dustyRose),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Field 3: Alamat Pengiriman
                TextField(
                  controller: addressCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Alamat Lengkap Pengiriman',
                    hintText: 'Nama Jalan, No. Rumah, RT/RW, Kelurahan, Kecamatan, Kota/Kabupaten, Kode Pos',
                    hintStyle: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                    labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    filled: true,
                    fillColor: MirroraTheme.cream,
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: MirroraTheme.dustyRose),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Field 4: Catatan Khusus
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Catatan untuk Kurir (Opsional)',
                    hintText: 'Contoh: Titipkan di pos satpam jika tidak ada orang',
                    hintStyle: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                    labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    filled: true,
                    fillColor: MirroraTheme.cream,
                    prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: MirroraTheme.dustyRose),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final address = addressCtrl.text.trim();

                      if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Harap lengkapi nama, nomor telepon, dan alamat!'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      final claimData = WinnerClaimData(
                        winnerId: winnerBlock.winnerId,
                        fullName: name,
                        phoneNumber: phone,
                        shippingAddress: address,
                        notes: notesCtrl.text.trim(),
                        claimedAt: DateTime.now(),
                      );

                      await GiveawayService().saveWinnerClaimData(claimData);

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data pengiriman berhasil disimpan! Tim kami akan segera memproses hadiahmu.'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MirroraTheme.dustyRose,
                      foregroundColor: MirroraTheme.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Kirim Data Pengiriman Hadiah',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
