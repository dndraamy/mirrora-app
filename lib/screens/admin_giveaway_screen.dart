import 'dart:async';
import 'package:flutter/material.dart';

import '../models/giveaway_model.dart';
import '../services/admin_auth_service.dart';
import '../services/giveaway_service.dart';
import '../theme/mirrora_theme.dart';
import '../widgets/blockchain_proof_dialog.dart';

class AdminGiveawayScreen extends StatefulWidget {
  const AdminGiveawayScreen({super.key});

  @override
  State<AdminGiveawayScreen> createState() => _AdminGiveawayScreenState();
}

class _AdminGiveawayScreenState extends State<AdminGiveawayScreen> {
  final GiveawayService _service = GiveawayService();

  late TextEditingController _titleController;
  late TextEditingController _prizeController;

  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    final c = _service.currentCampaign;
    _titleController = TextEditingController(text: c.title);
    _prizeController = TextEditingController(text: c.prize);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: MirroraTheme.charcoal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final c = _service.currentCampaign;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: c.startDate, end: c.endDate),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: MirroraTheme.dustyRose,
              onPrimary: Colors.white,
              surface: MirroraTheme.white,
              onSurface: MirroraTheme.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _service.updateCampaignSettings(
        startDate: picked.start,
        endDate: picked.end,
      );
      setState(() {});
      _showMessage('Rentang tanggal undian berhasil diperbarui!');
    }
  }

  Future<void> _changeStatus(GiveawayStatus newStatus) async {
    await _service.updateCampaignSettings(status: newStatus);
    setState(() {});
    String label = 'Buka (Open)';
    if (newStatus == GiveawayStatus.closed) {
      label = 'Tutup (Closed) - Iklan disembunyikan dari Home';
    } else if (newStatus == GiveawayStatus.drawn) {
      label = 'Diundi (Drawn) - Pemenang tampil di Home';
    }
    _showMessage('Status undian diubah menjadi: $label');
  }

  Future<void> _saveDetails() async {
    final title = _titleController.text.trim();
    final prize = _prizeController.text.trim();

    if (title.isEmpty || prize.isEmpty) {
      _showMessage('Judul dan Hadiah tidak boleh kosong!');
      return;
    }

    await _service.updateCampaignSettings(title: title, prize: prize);
    setState(() {});
    _showMessage('Detail giveaway berhasil disimpan!');
  }

  Future<void> _startDrawWinner() async {
    final c = _service.currentCampaign;
    if (c.participants.isEmpty) {
      _showMessage('Belum ada peserta yang mendaftar undian!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: MirroraTheme.blushPink),
        ),
        title: const Text(
          'Tarik Pemenang?',
          style: TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
        ),
        content: Text(
          'Sistem akan memilih 1 pemenang acak secara kriptografis dari ${c.participants.length} peserta, '
          'lalu menguncinya ke dalam Blockchain lokal (SHA-256).',
          style: const TextStyle(fontSize: 13, height: 1.45, color: MirroraTheme.warmGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MirroraTheme.dustyRose,
              foregroundColor: MirroraTheme.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Tarik Sekarang'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDrawing = true);

    // Tampilkan modal sedang mengundi
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: MirroraTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: MirroraTheme.blushPink),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: MirroraTheme.dustyRose,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Sedang Mengundi Pemenang...',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Algoritma acak sedang memilih 1 peserta secara adil & mengunci hasil ke blockchain...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.45, color: MirroraTheme.warmGray),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Beri jeda 1.8 detik agar proses acak terasa natural
    await Future.delayed(const Duration(milliseconds: 1800));

    try {
      final block = await _service.drawWinner();
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog loading

      setState(() => _isDrawing = false);

      // Tampilkan popup bukti blockchain pemenang
      BlockchainProofDialog.show(context, block);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isDrawing = false);
      _showMessage('Gagal menarik pemenang: $e');
    }
  }

  void _addDemoParticipant() {
    final demoNames = ['Bella Safira', 'Clarissa Tan', 'Jessica Mila', 'Rania Zulaikha', 'Fitriani Dewi'];
    final existing = _service.currentCampaign.participants.length;
    final name = demoNames[existing % demoNames.length];
    final uid = 'demo_user_${DateTime.now().millisecondsSinceEpoch % 1000}';
    final email = '${name.toLowerCase().replaceAll(' ', '.')}@email.com';

    _service.registerParticipant(userId: uid, userName: name, userEmail: email);
    setState(() {});
    _showMessage('Peserta demo "$name" berhasil ditambahkan!');
  }

  Future<void> _resetCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: MirroraTheme.blushPink),
        ),
        title: const Text('Reset Undian?'),
        content: const Text(
          'Seluruh status pemenang dan blockchain lokal akan dikembalikan ke kondisi awal (Genesis).',
          style: TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetCampaignForTesting();
      final c = _service.currentCampaign;
      _titleController.text = c.title;
      _prizeController.text = c.prize;
      setState(() {});
      _showMessage('Giveaway berhasil direset!');
    }
  }

  Future<void> _toggleStealthMode(bool val) async {
    await AdminAuthService().setStealthMode(val);
    setState(() {});
    _showMessage(
      val
          ? 'Mode Stealth Aktif: Tombol disembunyikan dari menu Settings.'
          : 'Mode Stealth Nonaktif: Tombol ditampilkan di menu Settings.',
    );
  }

  Future<void> _showChangeMasterKeyDialog() async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: MirroraTheme.blushPink),
        ),
        title: const Text(
          'Ganti Master Passphrase Owner',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan kombinasi kata sandi minimal 6 karakter.',
              style: TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pass1,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Passphrase Baru',
                filled: true,
                fillColor: MirroraTheme.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass2,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Passphrase',
                filled: true,
                fillColor: MirroraTheme.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final p1 = pass1.text.trim();
              final p2 = pass2.text.trim();
              if (p1.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passphrase minimal 6 karakter!')),
                );
                return;
              }
              if (p1 != p2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Konfirmasi Passphrase tidak cocok!')),
                );
                return;
              }
              await AdminAuthService().changeMasterKey(p1);
              if (ctx.mounted) Navigator.pop(ctx);
              _showMessage('Master Passphrase berhasil diganti!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MirroraTheme.dustyRose,
              foregroundColor: MirroraTheme.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
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
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: MirroraTheme.charcoal),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Portal Undian Owner',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<GiveawayCampaign>(
          valueListenable: _service.campaignNotifier,
          builder: (context, campaign, _) {
            final isChainValid = _service.blockchain.verifyIntegrity();
            final blocksCount = _service.blockchain.chain.length;
            final claim = campaign.winnerClaimData;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // STATUS KAMPANYE
                  // ==========================================
                  _buildCard(
                    title: 'Status Undian Saat Ini',
                    icon: Icons.toggle_on_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusPill(
                              label: 'Buka (Open)',
                              active: campaign.isOpen,
                              color: const Color(0xFF2E7D32),
                              onTap: () => _changeStatus(GiveawayStatus.open),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusPill(
                              label: 'Tutup (Closed)',
                              active: campaign.isClosed,
                              color: MirroraTheme.warmGray,
                              onTap: () => _changeStatus(GiveawayStatus.closed),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusPill(
                              label: 'Diundi (Drawn)',
                              active: campaign.isDrawn,
                              color: MirroraTheme.softGold,
                              onTap: () => _changeStatus(GiveawayStatus.drawn),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          campaign.isOpen
                              ? 'Iklan pendaftaran sedang tayang di Home.'
                              : campaign.isClosed
                                  ? 'Iklan disembunyikan sepenuhnya dari Home.'
                                  : 'Pengumuman pemenang sedang tayang di Home.',
                          style: const TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // DETAIL PENGATURAN & TANGGAL
                  // ==========================================
                  _buildCard(
                    title: 'Jadwal & Pengaturan Kampanye',
                    icon: Icons.tune_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tanggal
                        InkWell(
                          onTap: _pickDateRange,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: MirroraTheme.cream,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MirroraTheme.blushPink),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 18, color: MirroraTheme.dustyRose),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Periode Tanggal Undian',
                                        style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${campaign.startDate.day}/${campaign.startDate.month}/${campaign.startDate.year} s/d ${campaign.endDate.day}/${campaign.endDate.month}/${campaign.endDate.year}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: MirroraTheme.charcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_calendar_rounded, size: 16, color: MirroraTheme.dustyRose),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Form Judul
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Judul Undian',
                            labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                            filled: true,
                            fillColor: MirroraTheme.cream,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.title_rounded, size: 18, color: MirroraTheme.dustyRose),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Form Hadiah
                        TextField(
                          controller: _prizeController,
                          decoration: InputDecoration(
                            labelText: 'Hadiah',
                            labelStyle: const TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                            filled: true,
                            fillColor: MirroraTheme.cream,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: MirroraTheme.dustyRose),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton(
                            onPressed: _saveDetails,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MirroraTheme.dustyRose,
                              side: const BorderSide(color: MirroraTheme.dustyRose),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Simpan Perubahan Jadwal & Hadiah', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // PENARIKAN PEMENANG & DATA KLAIM
                  // ==========================================
                  _buildCard(
                    title: 'Penarikan Pemenang (Blockchain)',
                    icon: Icons.auto_awesome_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sistem memilih 1 peserta secara acak menggunakan CSPRNG dan merantainya ke dalam Blockchain lokal (SHA-256).',
                          style: TextStyle(fontSize: 12, height: 1.45, color: MirroraTheme.warmGray),
                        ),
                        const SizedBox(height: 14),

                        // State saat sedang mengundi
                        if (_isDrawing) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              color: MirroraTheme.cream,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: MirroraTheme.dustyRose.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: MirroraTheme.dustyRose),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Sedang mengundi pemenang...',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: MirroraTheme.dustyRose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (campaign.isDrawn && campaign.winnerBlock != null) ...[
                          // Kartu Pemenang Terpilih
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: MirroraTheme.cream,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: MirroraTheme.softGold, width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🏆', style: TextStyle(fontSize: 24)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            campaign.winnerBlock!.winnerName,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MirroraTheme.charcoal),
                                          ),
                                          Text(
                                            '${campaign.winnerBlock!.entryTicket} • ${campaign.winnerBlock!.winnerEmail}',
                                            style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => BlockchainProofDialog.show(context, campaign.winnerBlock!),
                                      child: const Text('Bukti Blockchain ⛓️', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: MirroraTheme.dustyRose)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Kartu Data Pengiriman Hadiah yang diisi Pemenang
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: claim != null ? const Color(0xFFF1F8F3) : MirroraTheme.cream,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: claim != null ? const Color(0xFFA5D6A7) : MirroraTheme.blushPink,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      claim != null ? Icons.mark_email_read_rounded : Icons.pending_actions_rounded,
                                      size: 18,
                                      color: claim != null ? const Color(0xFF2E7D32) : MirroraTheme.warmGray,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      claim != null ? 'Data Pengiriman Pemenang (Sudah Diisi)' : 'Data Pengiriman Pemenang (Belum Diisi)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: claim != null ? const Color(0xFF1B5E20) : MirroraTheme.charcoal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (claim != null) ...[
                                  Text('Nama: ${claim.fullName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('WhatsApp / HP: ${claim.phoneNumber}', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('Alamat: ${claim.shippingAddress}', style: const TextStyle(fontSize: 12)),
                                  if (claim.notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('Catatan: ${claim.notes}', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: MirroraTheme.warmGray)),
                                  ],
                                ] else ...[
                                  const Text(
                                    'Pemenang belum mengisi formulir data pengiriman di halaman Home akunnya.',
                                    style: TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Tombol Tarik Pemenang
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _isDrawing ? null : _startDrawWinner,
                            icon: const Icon(Icons.casino_rounded, size: 18),
                            label: Text(
                              campaign.isDrawn ? 'Tarik Ulang Pemenang 🎲' : 'Tarik Pemenang Sekarang 🎲',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MirroraTheme.dustyRose,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // DAFTAR PESERTA
                  // ==========================================
                  _buildCard(
                    title: 'Daftar Peserta (${campaign.participants.length})',
                    icon: Icons.people_rounded,
                    action: TextButton.icon(
                      onPressed: _addDemoParticipant,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                      label: const Text('+ Demo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: MirroraTheme.dustyRose),
                    ),
                    child: Column(
                      children: [
                        if (campaign.participants.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Belum ada peserta yang mendaftar.',
                              style: TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: campaign.participants.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: MirroraTheme.blushPink),
                            itemBuilder: (context, index) {
                              final p = campaign.participants[index];
                              final isThisWinner = campaign.winnerBlock != null &&
                                  campaign.winnerBlock!.winnerId == p.userId;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: isThisWinner
                                      ? MirroraTheme.softGold
                                      : MirroraTheme.blushPink,
                                  foregroundColor: isThisWinner
                                      ? Colors.white
                                      : MirroraTheme.dustyRose,
                                  radius: 16,
                                  child: Text(
                                    isThisWinner ? '🏆' : '${index + 1}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(
                                  p.userName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isThisWinner ? FontWeight.w800 : FontWeight.w600,
                                    color: isThisWinner ? MirroraTheme.dustyRose : MirroraTheme.charcoal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${p.entryTicket} • ${p.userEmail}',
                                  style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                                ),
                                trailing: isThisWinner
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: MirroraTheme.cream,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: MirroraTheme.softGold),
                                        ),
                                        child: const Text(
                                          'PEMENANG',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: MirroraTheme.charcoal),
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // PUSAT KEAMANAN OWNER / ADMIN (BERSIH & ELEGAN)
                  // ==========================================
                  _buildCard(
                    title: 'Pusat Keamanan Owner',
                    icon: Icons.shield_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Switch Stealth Mode
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Mode Stealth (Sembunyikan Tombol)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Sembunyikan tombol admin dari menu Settings. Owner membuka portal dengan mengetuk versi 5x di Tentang Aplikasi.',
                            style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                          ),
                          value: AdminAuthService().isStealthMode(),
                          activeTrackColor: MirroraTheme.dustyRose,
                          onChanged: _toggleStealthMode,
                        ),
                        const Divider(height: 18, color: MirroraTheme.blushPink),

                        // Tombol Ganti Master Passphrase
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: MirroraTheme.dustyRose.withValues(alpha: 0.12),
                            child: const Icon(Icons.key_rounded, size: 17, color: MirroraTheme.dustyRose),
                          ),
                          title: const Text(
                            'Ganti Master Passphrase',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Perbarui kunci rahasia owner dengan hash SHA-256 tersalt.',
                            style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: MirroraTheme.warmGray),
                          onTap: _showChangeMasterKeyDialog,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // BLOCKCHAIN LEDGER STATS
                  // ==========================================
                  _buildCard(
                    title: 'Blockchain Ledger ($blocksCount Blok)',
                    icon: Icons.link_rounded,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_outlined, size: 16, color: MirroraTheme.dustyRose),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isChainValid
                                    ? 'Integritas Rantai: 100% Sah & Terverifikasi'
                                    : 'Integritas Rantai: Terdeteksi Mutasi Data!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isChainValid ? const Color(0xFF2E7D32) : Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _resetCampaign,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset Undian (Testing Mode)', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MirroraTheme.dustyRose),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : MirroraTheme.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : MirroraTheme.blushPink,
              width: active ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? color : MirroraTheme.warmGray,
            ),
          ),
        ),
      ),
    );
  }
}
