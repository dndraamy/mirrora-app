import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/giveaway_model.dart';
import '../services/giveaway_service.dart';
import '../theme/mirrora_theme.dart';

class GiveawayHomeBanner extends StatefulWidget {
  const GiveawayHomeBanner({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  State<GiveawayHomeBanner> createState() => _GiveawayHomeBannerState();
}

class _GiveawayHomeBannerState extends State<GiveawayHomeBanner> {
  final GiveawayService _service = GiveawayService();
  bool _isRegistering = false;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  String? get _currentUserEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  String _formatDateRange(DateTime start, DateTime end) {
    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  bool _isCurrentUserWinner(GiveawayCampaign campaign) {
    final block = campaign.winnerBlock;
    if (block == null) return false;

    final uid = _currentUserId;
    final email = _currentUserEmail;
    if (_service.isUserWinner(uid, email)) return true;

    // Cek juga berdasarkan nama profil yang sedang aktif di Home
    if (block.winnerName.trim().toLowerCase() == widget.userName.trim().toLowerCase()) {
      return true;
    }

    return false;
  }

  Future<void> _handleParticipate(GiveawayCampaign campaign) async {
    final uid = _currentUserId ?? 'user_${widget.userName.toLowerCase()}';
    final email = _currentUserEmail ?? '${widget.userName.toLowerCase()}@mirrora.user';

    setState(() => _isRegistering = true);

    try {
      final participant = await _service.registerParticipant(
        userId: uid,
        userName: widget.userName,
        userEmail: email,
      );

      if (!mounted) return;
      _showRegistrationSuccessDialog(participant.entryTicket, campaign.prize);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: MirroraTheme.charcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showRegistrationSuccessDialog(String ticket, String prize) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: MirroraTheme.blushPink),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Berhasil Terdaftar! 🎟️',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nomor tiket undian sah kamu:',
              style: TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MirroraTheme.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MirroraTheme.dustyRose.withValues(alpha: 0.4)),
              ),
              child: Text(
                ticket,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: MirroraTheme.dustyRose,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Hasil pengundian otomatis diundi secara adil & dikunci transparan ke dalam blockchain lokal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.45, color: MirroraTheme.warmGray),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.dustyRose,
                foregroundColor: MirroraTheme.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka form klaim hadiah untuk pemenang
  void _openClaimFormSheet(GiveawayCampaign campaign, BlockchainBlock winnerBlock) {
    final existingClaim = campaign.winnerClaimData;
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
                  child: const Text(
                    'Mohon isi alamat lengkap pengiriman dan nomor WhatsApp aktif agar paket hadiah 1 Set Skincare COSRX original dapat segera kami kirimkan ke rumahmu.',
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: MirroraTheme.charcoal),
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

                      await _service.saveWinnerClaimData(claimData);

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GiveawayCampaign>(
      valueListenable: _service.campaignNotifier,
      builder: (context, campaign, _) {
        // Jika kampanye ditutup (closed), sembunyikan banner sepenuhnya dari Home
        if (campaign.isClosed) {
          return const SizedBox.shrink();
        }

        // Jika kampanye sudah diundi (drawn)
        if (campaign.isDrawn && campaign.winnerBlock != null) {
          final isWinner = _isCurrentUserWinner(campaign);
          if (isWinner) {
            return _buildWinnerPersonalBanner(campaign, campaign.winnerBlock!);
          } else {
            return _buildWinnerPublicAnnouncement(campaign, campaign.winnerBlock!);
          }
        }

        // Fase pendaftaran dibuka (open)
        return _buildOpenBanner(campaign);
      },
    );
  }

  // --------------------------------------------------------------------------
  // BANNER FASE PENDAFTARAN (OPEN)
  // --------------------------------------------------------------------------
  Widget _buildOpenBanner(GiveawayCampaign campaign) {
    final uid = _currentUserId ?? 'user_${widget.userName.toLowerCase()}';
    final email = _currentUserEmail ?? '${widget.userName.toLowerCase()}@mirrora.user';
    final isRegistered = _service.isUserRegistered(uid, email);
    final userTicket = _service.getUserTicket(uid, email);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.dustyRose.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: MirroraTheme.dustyRose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.celebration_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Anniversary Giveaway',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MirroraTheme.blushPink),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 12, color: MirroraTheme.dustyRose),
                      const SizedBox(width: 4),
                      Text(
                        '${campaign.participants.length} Peserta',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: MirroraTheme.charcoal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              campaign.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MirroraTheme.charcoal,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Prize
            Row(
              children: [
                const Text('Hadiah: ', style: TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray)),
                Expanded(
                  child: Text(
                    campaign.prize,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.dustyRose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Periode
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: MirroraTheme.warmGray),
                const SizedBox(width: 5),
                Text(
                  'Periode: ${_formatDateRange(campaign.startDate, campaign.endDate)}',
                  style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Button Action
            if (isRegistered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(
                      'Terdaftar ✓  $userTicket',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isRegistering ? null : () => _handleParticipate(campaign),
                  icon: _isRegistering
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard_rounded, size: 16),
                  label: Text(
                    _isRegistering ? 'Mendaftarkan...' : 'Ikuti Undian',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MirroraTheme.dustyRose,
                    foregroundColor: MirroraTheme.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BANNER KHUSUS PEMENANG (DASHBOARD SI A) DENGAN FORM KLAIM PENGIRIMAN
  // --------------------------------------------------------------------------
  Widget _buildWinnerPersonalBanner(GiveawayCampaign campaign, BlockchainBlock winnerBlock) {
    final hasClaimed = campaign.winnerClaimData != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MirroraTheme.softGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.softGold.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: MirroraTheme.softGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 4),
                      Text(
                        'Kamu Pemenangnya!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MirroraTheme.softGold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    winnerBlock.entryTicket,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Greeting
            Text(
              '🎉 Selamat ${winnerBlock.winnerName}, Kamu Menang!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MirroraTheme.charcoal,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                children: [
                  const TextSpan(text: 'Kamu berhasil memenangkan hadiah '),
                  TextSpan(
                    text: winnerBlock.prize,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.dustyRose),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Box Informasi Instruksi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MirroraTheme.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MirroraTheme.blushPink),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasClaimed
                          ? 'Data pengiriman kamu telah tersimpan. Tim kami akan segera mengirimkan nomor resi kurir ke WhatsApp kamu.'
                          : 'Silakan isi data diri (nama, no. telepon/WhatsApp, dan alamat pengiriman) untuk menerima hadiahnya.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tombol Klaim / Ubah Data
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _openClaimFormSheet(campaign, winnerBlock),
                icon: Icon(
                  hasClaimed ? Icons.edit_note_rounded : Icons.local_shipping_outlined,
                  size: 17,
                ),
                label: Text(
                  hasClaimed ? 'Lihat / Ubah Data Pengiriman ✓' : 'Isi Data Pengiriman Hadiah',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasClaimed ? const Color(0xFF2E7D32) : MirroraTheme.dustyRose,
                  foregroundColor: MirroraTheme.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BANNER PUBLIK (PENGGUNA SELAIN SI A): HANYA PENGUMUMAN BIASA TANPA BUTTON
  // --------------------------------------------------------------------------
  Widget _buildWinnerPublicAnnouncement(GiveawayCampaign campaign, BlockchainBlock winnerBlock) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: MirroraTheme.dustyRose.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag Pengumuman
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: MirroraTheme.blushPink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, color: MirroraTheme.dustyRose, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Pengumuman Pemenang Giveaway',
                        style: TextStyle(
                          color: MirroraTheme.dustyRose,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Judul Pemenang
            Text(
              '🎉 Selamat kepada ${winnerBlock.winnerName}!',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: MirroraTheme.charcoal,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Rincian Pemenang & Hadiah
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: MirroraTheme.charcoal, height: 1.45),
                children: [
                  const TextSpan(text: 'Nomor Tiket: '),
                  TextSpan(
                    text: winnerBlock.entryTicket,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.dustyRose),
                  ),
                  const TextSpan(text: ' • Memenangkan: '),
                  TextSpan(
                    text: winnerBlock.prize,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.dustyRose),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Pesan Apresiasi (Sesuai instruksi: TIDAK ADA BUTTON APAPUN)
            Text(
              'Terima kasih kepada seluruh peserta yang telah berpartisipasi dalam Anniversary Giveaway kali ini. Nantikan event menarik Mirrora berikutnya!',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: MirroraTheme.warmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
