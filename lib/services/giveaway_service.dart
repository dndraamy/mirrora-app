import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/giveaway_model.dart';

/// Service untuk mengelola siklus giveaway, integrasi database gratis (Supabase + Hive),
/// dan blockchain lokal anti-manipulasi.
///
/// NOTE UNTUK SUPABASE (OPSIONAL):
/// Jika ingin menyimpan peserta di Supabase secara cloud, buat tabel berikut di SQL Editor:
/// ```sql
/// CREATE TABLE IF NOT EXISTS giveaway_participants (
///   id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
///   user_id TEXT NOT NULL,
///   user_name TEXT NOT NULL,
///   user_email TEXT NOT NULL,
///   entry_ticket TEXT NOT NULL,
///   registered_at TIMESTAMPTZ DEFAULT NOW()
/// );
/// ```
/// Jika tabel belum dibuat, sistem secara cerdas & otomatis menggunakan Hive lokal
/// tanpa error, sehingga 100% aman untuk kuota gratisan!
class GiveawayService {
  static final GiveawayService _instance = GiveawayService._internal();
  factory GiveawayService() => _instance;
  GiveawayService._internal();

  static const String _boxName = 'giveawayBox';
  static const String _campaignKey = 'current_giveaway_campaign';
  static const String _blockchainKey = 'local_giveaway_blockchain';

  late Box _box;
  late SimpleBlockchain _blockchain;
  late ValueNotifier<GiveawayCampaign> campaignNotifier;
  late ValueNotifier<int> voucherCountNotifier;

  bool _initialized = false;

  SimpleBlockchain get blockchain => _blockchain;

  GiveawayCampaign get currentCampaign => campaignNotifier.value;

  /// Inisialisasi awal storage Hive & Blockchain
  Future<void> init() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }

    // 1. Muat atau inisialisasi Blockchain Lokal
    final chainList = _box.get(_blockchainKey) as List<dynamic>?;
    if (chainList != null && chainList.isNotEmpty) {
      _blockchain = SimpleBlockchain.fromJsonList(chainList);
    } else {
      _blockchain = SimpleBlockchain();
      await _box.put(_blockchainKey, _blockchain.toJsonList());
    }

    // 2. Muat atau buat Kampanye Default
    final campaignData = _box.get(_campaignKey);
    GiveawayCampaign campaign;
    if (campaignData != null) {
      try {
        campaign = GiveawayCampaign.fromJson(
          Map<String, dynamic>.from(campaignData as Map),
        );
      } catch (_) {
        campaign = GiveawayCampaign.defaultCampaign();
      }
    } else {
      campaign = GiveawayCampaign.defaultCampaign();
      await _box.put(_campaignKey, campaign.toJson());
    }

    campaignNotifier = ValueNotifier<GiveawayCampaign>(campaign);
    voucherCountNotifier = ValueNotifier<int>(0);
    _initialized = true;

    // 3. Sinkronisasi latar belakang hemat kuota (Background Sync)
    _syncWithSupabaseInBackground();
  }

  /// Sinkronisasi ringan dengan Supabase (free-tier friendly)
  Future<void> _syncWithSupabaseInBackground() async {
    try {
      final supabase = Supabase.instance.client;
      // Coba fetch peserta dari Supabase jika tabel ada
      final response = await supabase
          .from('giveaway_participants')
          .select()
          .order('registered_at', ascending: true)
          .limit(200);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        final existingIds = currentCampaign.participants.map((p) => p.userId).toSet();
        bool hasNew = false;

        for (final row in data) {
          final uid = row['user_id'] as String? ?? '';
          if (uid.isNotEmpty && !existingIds.contains(uid)) {
            currentCampaign.participants.add(
              GiveawayParticipant(
                userId: uid,
                userName: row['user_name'] as String? ?? 'Peserta',
                userEmail: row['user_email'] as String? ?? '',
                entryTicket: row['entry_ticket'] as String? ?? '#GLOW-0000',
                registeredAt: row['registered_at'] != null
                    ? DateTime.parse(row['registered_at'] as String)
                    : DateTime.now(),
              ),
            );
            hasNew = true;
          }
        }

        if (hasNew) {
          await _saveCampaign(currentCampaign);
        }
      }
    } catch (_) {
      // Abaikan jika tabel Supabase belum ada atau rate-limit tercapai.
      // Data lokal Hive tetap 100% berfungsi normal.
    }
  }

  /// Refresh voucher count notifier for current user
  void refreshVoucherCount(String? uid) {
    if (uid == null || uid.isEmpty) {
      voucherCountNotifier.value = 0;
      return;
    }
    final vouchers = getAvailableVouchers(uid);
    voucherCountNotifier.value = vouchers.length;
  }

  /// Ambil daftar voucher tiket yang dimenangkan user dari Shake to Pick tapi belum dimasukkan ke undian
  List<String> getAvailableVouchers(String uid) {
    final list = _box.get('user_available_vouchers_$uid') as List<dynamic>?;
    return list != null ? list.map((e) => e.toString()).toList() : [];
  }

  /// Tambah voucher tiket baru hasil menang Shake to Pick
  Future<String> addVoucherFromShake(String uid) async {
    final randNum = 1000 + Random().nextInt(9000);
    final ticket = '#GLOW-$randNum';
    final current = getAvailableVouchers(uid);
    current.add(ticket);
    await _box.put('user_available_vouchers_$uid', current);
    voucherCountNotifier.value = current.length;
    return ticket;
  }

  /// Memasukkan 1 voucher tiket tertentu ke dalam undian
  Future<GiveawayParticipant> submitVoucherToCampaign({
    required String userId,
    required String userName,
    required String userEmail,
    required String ticket,
  }) async {
    final campaign = currentCampaign;
    if (!campaign.isOpen) {
      throw Exception('Pendaftaran giveaway saat ini sedang ditutup.');
    }

    final participant = GiveawayParticipant(
      userId: userId,
      userName: userName.trim().isNotEmpty ? userName.trim() : 'Peserta Cantik',
      userEmail: userEmail.trim(),
      entryTicket: ticket,
      registeredAt: DateTime.now(),
    );

    campaign.participants.add(participant);
    await _saveCampaign(campaign);

    // Hapus dari voucher yang belum terpakai
    final current = getAvailableVouchers(userId);
    current.remove(ticket);
    await _box.put('user_available_vouchers_$userId', current);
    voucherCountNotifier.value = current.length;

    _trySaveParticipantToSupabase(participant);
    return participant;
  }

  /// Memasukkan semua voucher yang dimiliki user sekaligus ke undian
  Future<int> submitAllVouchersToCampaign({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final vouchers = getAvailableVouchers(userId);
    if (vouchers.isEmpty) return 0;

    final count = vouchers.length;
    for (final ticket in List<String>.from(vouchers)) {
      await submitVoucherToCampaign(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        ticket: ticket,
      );
    }
    return count;
  }

  /// Mengambil seluruh tiket yang sudah terdaftar milik user di kampanye saat ini
  List<String> getUserRegisteredTickets(String? userId, String? userEmail) {
    if (userId == null && userEmail == null) return [];
    final uid = userId?.trim();
    final email = userEmail?.trim().toLowerCase();

    final result = <String>[];
    for (final p in currentCampaign.participants) {
      final matchUid = uid != null && uid.isNotEmpty && p.userId == uid;
      final matchEmail = email != null && email.isNotEmpty && p.userEmail.toLowerCase() == email;
      if (matchUid || matchEmail) {
        result.add(p.entryTicket);
      }
    }
    return result;
  }

  /// Mengecek apakah user saat ini sudah memiliki tiket terdaftar di giveaway
  bool isUserRegistered(String? userId, String? userEmail) {
    return getUserRegisteredTickets(userId, userEmail).isNotEmpty;
  }

  /// Mendapatkan tiket undian milik user (tiket pertama atau terbaru)
  String? getUserTicket(String? userId, String? userEmail) {
    final tickets = getUserRegisteredTickets(userId, userEmail);
    return tickets.isNotEmpty ? tickets.first : null;
  }

  /// Pendaftaran peserta baru ke dalam undian (bisa berkali-kali)
  Future<GiveawayParticipant> registerParticipant({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final campaign = currentCampaign;

    if (!campaign.isOpen) {
      throw Exception('Pendaftaran giveaway saat ini sedang ditutup.');
    }

    final ticketNumber = 1000 + campaign.participants.length + 1;
    final ticket = '#GLOW-$ticketNumber';

    final participant = GiveawayParticipant(
      userId: userId,
      userName: userName.trim().isNotEmpty ? userName.trim() : 'Peserta Cantik',
      userEmail: userEmail.trim(),
      entryTicket: ticket,
      registeredAt: DateTime.now(),
    );

    campaign.participants.add(participant);
    await _saveCampaign(campaign);

    _trySaveParticipantToSupabase(participant);

    return participant;
  }

  Future<void> _trySaveParticipantToSupabase(GiveawayParticipant p) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('giveaway_participants').insert({
        'user_id': p.userId,
        'user_name': p.userName,
        'user_email': p.userEmail,
        'entry_ticket': p.entryTicket,
        'registered_at': p.registeredAt.toIso8601String(),
      });
    } catch (_) {
      // Abaikan jika Supabase offline atau belum ada tabel
    }
  }

  /// Pengundian Otomatis menggunakan Algoritma Acak Kriptografis (Random.secure)
  /// dan Mengunci Hasil ke dalam Blockchain Lokal.
  Future<BlockchainBlock> drawWinner() async {
    final campaign = currentCampaign;

    if (campaign.participants.isEmpty) {
      throw Exception('Belum ada peserta yang mendaftar undian!');
    }

    // 1. Algoritma acak kriptografis (CSPRNG)
    final secureRandom = Random.secure();
    final winningIndex = secureRandom.nextInt(campaign.participants.length);
    final winner = campaign.participants[winningIndex];

    // Nonce acak untuk bukti pengundian (Proof of Drawing)
    final nonce = secureRandom.nextInt(900000) + 100000;

    // 2. Buat blok baru di Blockchain lokal
    final newBlock = _blockchain.addWinnerBlock(
      campaignId: campaign.id,
      winnerId: winner.userId,
      winnerName: winner.userName,
      winnerEmail: winner.userEmail,
      entryTicket: winner.entryTicket,
      prize: campaign.prize,
      totalParticipants: campaign.participants.length,
      nonce: nonce,
    );

    // 3. Simpan blockchain
    await _box.put(_blockchainKey, _blockchain.toJsonList());

    // 4. Perbarui status kampanye menjadi DRAWN dan reset data klaim pemenang baru
    campaign.winnerBlock = newBlock;
    campaign.winnerClaimData = null;
    campaign.status = GiveawayStatus.drawn;
    await _saveCampaign(campaign);

    return newBlock;
  }

  /// Menyimpan data klaim pengiriman hadiah oleh pemenang
  Future<void> saveWinnerClaimData(WinnerClaimData data) async {
    final campaign = currentCampaign;
    campaign.winnerClaimData = data;
    await _saveCampaign(campaign);
  }

  /// Update pengaturan kampanye oleh Admin (Tanggal, Status, Hadiah, Judul)
  Future<void> updateCampaignSettings({
    DateTime? startDate,
    DateTime? endDate,
    GiveawayStatus? status,
    String? title,
    String? prize,
    String? description,
  }) async {
    final campaign = currentCampaign;

    if (startDate != null) campaign.startDate = startDate;
    if (endDate != null) campaign.endDate = endDate;
    if (status != null) campaign.status = status;
    if (title != null && title.trim().isNotEmpty) campaign.title = title.trim();
    if (prize != null && prize.trim().isNotEmpty) campaign.prize = prize.trim();
    if (description != null) campaign.description = description.trim();

    await _saveCampaign(campaign);
  }

  /// Mengecek apakah user saat ini adalah pemenang undian
  bool isUserWinner(String? userId, String? userEmail) {
    final block = currentCampaign.winnerBlock;
    if (block == null) return false;

    final uid = userId?.trim();
    final email = userEmail?.trim().toLowerCase();

    final matchUid = uid != null && uid.isNotEmpty && block.winnerId == uid;
    final matchEmail = email != null && email.isNotEmpty && block.winnerEmail.toLowerCase() == email;

    return matchUid || matchEmail;
  }

  /// Reset undian untuk kebutuhan testing ulang oleh Owner/Admin
  Future<void> resetCampaignForTesting() async {
    final now = DateTime.now();
    final newCampaign = GiveawayCampaign(
      id: 'glowmate_2nd_anniversary',
      title: '🎉 GlowMate 2nd Anniversary Giveaway!',
      prize: '1 Set Skincare COSRX!',
      description:
          'Rayakan 2 tahun perjalanan self-care bersama kami! Dapatkan kesempatan memenangkan 1 Set Skincare COSRX original gratis.',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 7)),
      status: GiveawayStatus.open,
      participants: [
        GiveawayParticipant(
          userId: 'demo_user_01',
          userName: 'Nadia Putri',
          userEmail: 'nadia.putri@email.com',
          entryTicket: '#GLOW-1001',
          registeredAt: now.subtract(const Duration(hours: 18)),
        ),
        GiveawayParticipant(
          userId: 'demo_user_02',
          userName: 'Dian Sastro',
          userEmail: 'dian.s@email.com',
          entryTicket: '#GLOW-1002',
          registeredAt: now.subtract(const Duration(hours: 12)),
        ),
        GiveawayParticipant(
          userId: 'demo_user_03',
          userName: 'Alya Rahma',
          userEmail: 'alya.rahma@email.com',
          entryTicket: '#GLOW-1003',
          registeredAt: now.subtract(const Duration(hours: 4)),
        ),
      ],
      winnerBlock: null,
    );

    // Reset blockchain ke genesis
    _blockchain = SimpleBlockchain();
    await _box.put(_blockchainKey, _blockchain.toJsonList());

    await _saveCampaign(newCampaign);
  }

  Future<void> _saveCampaign(GiveawayCampaign campaign) async {
    await _box.put(_campaignKey, campaign.toJson());
    campaignNotifier.value = campaign;
    // Pemicu listener untuk UI
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    campaignNotifier.notifyListeners();
  }
}
