import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/giveaway_model.dart';

/// Service untuk mengelola siklus giveaway, integrasi database gratis (Supabase + Hive),
/// dan blockchain lokal anti-manipulasi.
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
        final bool statusExplicitlySet =
            _box.get('giveaway_status_explicitly_set', defaultValue: false) as bool;
        if (!statusExplicitlySet && campaign.winnerBlock == null) {
          campaign.status = GiveawayStatus.closed;
          await _box.put(_campaignKey, campaign.toJson());
        }
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

    // 3. Sinkronisasi latar belakang dengan Supabase (pull peserta & status terkini)
    unawaited(_syncFromSupabase());
  }

  /// Tarik data peserta & status kampanye terbaru dari Supabase ke lokal.
  Future<void> _syncFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;

      // --- Sync peserta (hanya peserta periode aktif saat ini) ---
      final participantsRaw = await supabase
          .from('giveaway_participants')
          .select()
          .gte('registered_at', currentCampaign.startDate.toIso8601String())
          .order('registered_at', ascending: true)
          .limit(500);

      final List<dynamic> rows = participantsRaw as List<dynamic>;
      if (rows.isNotEmpty) {
        final existingTickets =
            currentCampaign.participants.map((p) => p.entryTicket).toSet();
        bool hasNew = false;

        for (final row in rows) {
          final ticket = row['entry_ticket'] as String? ?? '';
          if (ticket.isNotEmpty && !existingTickets.contains(ticket)) {
            currentCampaign.participants.add(
              GiveawayParticipant(
                userId: row['user_id'] as String? ?? '',
                userName: row['user_name'] as String? ?? 'Peserta',
                userEmail: row['user_email'] as String? ?? '',
                entryTicket: ticket,
                registeredAt: row['registered_at'] != null
                    ? DateTime.parse(row['registered_at'] as String)
                    : DateTime.now(),
              ),
            );
            hasNew = true;
          }
        }
        if (hasNew) await _saveCampaign(currentCampaign);
      }

      // --- Sync status & pemenang dari tabel giveaway_campaigns ---
      final campaignsRaw = await supabase
          .from('giveaway_campaigns')
          .select()
          .eq('id', currentCampaign.id)
          .maybeSingle();

      if (campaignsRaw != null) {
        final row = campaignsRaw;
        final statusStr = row['status'] as String? ?? 'closed';
        GiveawayStatus remoteStatus = GiveawayStatus.closed;
        if (statusStr == 'open') remoteStatus = GiveawayStatus.open;
        if (statusStr == 'drawn') remoteStatus = GiveawayStatus.drawn;

        // Terapkan status remote jika kampanye sudah diundi (drawn)
        // Periksa jika winnerBlock belum ada atau sebelumnya berupa fakeBlock (tidak valid)
        final needsWinnerBlock = remoteStatus == GiveawayStatus.drawn &&
            (currentCampaign.winnerBlock == null || !currentCampaign.winnerBlock!.isValid());

        if (needsWinnerBlock) {
          final winnerId = row['winner_id'] as String? ?? '';
          final winnerName = row['winner_name'] as String? ?? '';
          final winnerTicket = row['winner_ticket'] as String? ?? '';
          final winnerEmail = row['winner_email'] as String? ?? '';
          final drawnAt = row['drawn_at'] != null
              ? DateTime.parse(row['drawn_at'] as String)
              : DateTime.now();

          BlockchainBlock? winnerBlock;

          // 1. Prioritaskan memuat winner_block JSONB lengkap dari Supabase
          if (row['winner_block'] != null) {
            try {
              final blockJson = Map<String, dynamic>.from(row['winner_block'] as Map);
              winnerBlock = BlockchainBlock.fromJson(blockJson);
            } catch (e) {
              debugPrint('⚠️ Error parsing winner_block dari Supabase: $e');
            }
          }

          // 2. Fallback jika Supabase belum memiliki kolom winner_block
          if (winnerBlock == null && winnerId.isNotEmpty && winnerTicket.isNotEmpty) {
            winnerBlock = BlockchainBlock(
              index: 1,
              timestamp: drawnAt.millisecondsSinceEpoch,
              campaignId: currentCampaign.id,
              winnerId: winnerId,
              winnerName: winnerName,
              winnerEmail: winnerEmail,
              entryTicket: winnerTicket,
              prize: row['prize'] as String? ?? currentCampaign.prize,
              totalParticipants: currentCampaign.participants.length,
              nonce: 0,
              hash: '',
              previousHash: '',
            );
          }

          if (winnerBlock != null) {
            currentCampaign.winnerBlock = winnerBlock;
            currentCampaign.status = GiveawayStatus.drawn;

            // Jika blok valid dan belum ada di rantai lokal, masukkan ke rantai lokal
            if (winnerBlock.isValid()) {
              final alreadyInChain = _blockchain.chain.any((b) => b.hash == winnerBlock!.hash);
              if (!alreadyInChain) {
                _blockchain = SimpleBlockchain(chain: [..._blockchain.chain, winnerBlock]);
                await _box.put(_blockchainKey, _blockchain.toJsonList());
              }
            }

            // Sinkronkan data klaim jika sudah ada di Supabase
            if (row['winner_claim_name'] != null &&
                row['winner_claim_name'].toString().isNotEmpty) {
              currentCampaign.winnerClaimData = WinnerClaimData(
                winnerId: winnerBlock.winnerId,
                fullName: row['winner_claim_name'] as String? ?? '',
                phoneNumber: row['winner_claim_phone'] as String? ?? '',
                shippingAddress: row['winner_claim_address'] as String? ?? '',
                notes: row['winner_claim_notes'] as String? ?? '',
                claimedAt: row['winner_claimed_at'] != null
                    ? DateTime.parse(row['winner_claimed_at'] as String)
                    : DateTime.now(),
              );
            }

            await _box.put('giveaway_status_explicitly_set', true);
            await _saveCampaign(currentCampaign);
          }
        } else if (currentCampaign.status != remoteStatus &&
            currentCampaign.winnerBlock == null) {
          currentCampaign.status = remoteStatus;
          await _box.put('giveaway_status_explicitly_set', true);
          await _saveCampaign(currentCampaign);
        }
      }
    } catch (_) {
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
    if (list != null && list.isNotEmpty) {
      return list.map((e) => e.toString()).toList();
    }
    // Fallback: cek apakah tiket tersimpan di 'anonymous' (misal sebelum login)
    if (uid != 'anonymous') {
      final anonList = _box.get('user_available_vouchers_anonymous') as List<dynamic>?;
      if (anonList != null && anonList.isNotEmpty) {
        final result = anonList.map((e) => e.toString()).toList();
        _box.put('user_available_vouchers_$uid', result);
        _box.delete('user_available_vouchers_anonymous');
        return result;
      }
    }
    return [];
  }

  /// Tambah voucher tiket baru hasil menang Shake to Pick
  Future<String> addVoucherFromShake(String uid) async {
    final randNum = 1000 + Random().nextInt(9000);
    final ticket = '#MIR-$randNum';
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

    _trySaveParticipantToSupabase(participant).then((err) {
      if (err != null) debugPrint('⚠️ [submitVoucher] Supabase error: $err');
    });
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
    final ticket = '#MIR-$ticketNumber';

    final participant = GiveawayParticipant(
      userId: userId,
      userName: userName.trim().isNotEmpty ? userName.trim() : 'Peserta Cantik',
      userEmail: userEmail.trim(),
      entryTicket: ticket,
      registeredAt: DateTime.now(),
    );

    campaign.participants.add(participant);
    await _saveCampaign(campaign);

    _trySaveParticipantToSupabase(participant).then((err) {
      if (err != null) debugPrint('⚠️ [registerParticipant] Supabase error: $err');
    });

    return participant;
  }

  /// Simpan peserta ke Supabase. Return error message jika gagal, null jika sukses.
  Future<String?> _trySaveParticipantToSupabase(GiveawayParticipant p) async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint('📤 [Supabase] Menyimpan peserta: ${p.userName} | ticket: ${p.entryTicket} | userId: ${p.userId}');
      await supabase.from('giveaway_participants').insert({
        'user_id': p.userId,
        'user_name': p.userName,
        'user_email': p.userEmail,
        'entry_ticket': p.entryTicket,
        'registered_at': p.registeredAt.toIso8601String(),
      });
      debugPrint('✅ [Supabase] Berhasil simpan peserta: ${p.userName}');
      return null; // sukses
    } catch (e) {
      debugPrint('❌ [Supabase] GAGAL simpan peserta: $e');
      return e.toString(); // kembalikan error
    }
  }

  /// Sinkronkan seluruh data peserta lokal dan data kampanye saat ini ke Supabase
  Future<int> syncLocalToSupabase() async {
    final campaign = currentCampaign;
    int syncedCount = 0;

    for (final p in campaign.participants) {
      final err = await _trySaveParticipantToSupabase(p);
      if (err == null) syncedCount++;
    }

    await _upsertCampaignToSupabase(campaign);
    return syncedCount;
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

    // 5. Pastikan semua peserta undian lokal juga terunggah ke Supabase
    for (final p in campaign.participants) {
      await _trySaveParticipantToSupabase(p);
    }

    // 6. Simpan hasil undian ke Supabase (tabel giveaway_campaigns)
    await _upsertCampaignToSupabase(campaign);

    return newBlock;
  }

  /// Menyimpan data klaim pengiriman hadiah oleh pemenang
  Future<void> saveWinnerClaimData(WinnerClaimData data) async {
    final campaign = currentCampaign;
    campaign.winnerClaimData = data;
    await _saveCampaign(campaign);
    // Simpan data klaim ke Supabase
    unawaited(_upsertCampaignToSupabase(campaign));
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
    if (status != null) {
      campaign.status = status;
      await _box.put('giveaway_status_explicitly_set', true);
    }
    if (title != null && title.trim().isNotEmpty) campaign.title = title.trim();
    if (prize != null && prize.trim().isNotEmpty) campaign.prize = prize.trim();
    if (description != null) campaign.description = description.trim();

    await _saveCampaign(campaign);
    // Sync perubahan status ke Supabase
    unawaited(_upsertCampaignToSupabase(campaign));
  }

  /// Simpan / perbarui data kampanye (status, pemenang, klaim) ke tabel giveaway_campaigns Supabase
  Future<void> _upsertCampaignToSupabase(GiveawayCampaign campaign) async {
    try {
      final supabase = Supabase.instance.client;
      final block = campaign.winnerBlock;
      final claim = campaign.winnerClaimData;

      debugPrint('📤 [Supabase] Upsert campaign: id=${campaign.id}, status=${campaign.status.name}, winner=${block?.winnerName}');

      final Map<String, dynamic> data = {
        'id': campaign.id,
        'title': campaign.title,
        'prize': campaign.prize,
        'status': campaign.status.name,
        'winner_id': block?.winnerId,
        'winner_name': block?.winnerName,
        'winner_ticket': block?.entryTicket,
        'winner_email': block?.winnerEmail,
        'drawn_at': block != null
            ? DateTime.fromMillisecondsSinceEpoch(block.timestamp).toIso8601String()
            : null,
        'winner_claim_name': claim?.fullName,
        'winner_claim_phone': claim?.phoneNumber,
        'winner_claim_address': claim?.shippingAddress,
        'winner_claim_notes': claim?.notes,
        'winner_claimed_at': claim?.claimedAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (block != null) {
        data['winner_block'] = block.toJson();
      }

      await supabase.from('giveaway_campaigns').upsert(data, onConflict: 'id');
      debugPrint('✅ [Supabase] Berhasil simpan hasil undian ke giveaway_campaigns!');
    } catch (e) {
      debugPrint('❌ [Supabase] GAGAL upsert giveaway_campaigns: $e');

      // Jika gagal karena kolom winner_block belum dibuat di Supabase, coba simpan kolom dasar
      if (e.toString().contains('winner_block')) {
        try {
          final supabase = Supabase.instance.client;
          final block = campaign.winnerBlock;
          final claim = campaign.winnerClaimData;
          await supabase.from('giveaway_campaigns').upsert({
            'id': campaign.id,
            'title': campaign.title,
            'prize': campaign.prize,
            'status': campaign.status.name,
            'winner_id': block?.winnerId,
            'winner_name': block?.winnerName,
            'winner_ticket': block?.entryTicket,
            'winner_email': block?.winnerEmail,
            'drawn_at': block != null
                ? DateTime.fromMillisecondsSinceEpoch(block.timestamp).toIso8601String()
                : null,
            'winner_claim_name': claim?.fullName,
            'winner_claim_phone': claim?.phoneNumber,
            'winner_claim_address': claim?.shippingAddress,
            'winner_claim_notes': claim?.notes,
            'winner_claimed_at': claim?.claimedAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
          debugPrint('⚠️ [Supabase] Berhasil simpan hasil undian (fallback tanpa kolom winner_block)');
        } catch (inner) {
          debugPrint('❌ [Supabase] Fallback juga gagal: $inner');
        }
      }
    }
  }

  /// Mengecek apakah user saat ini adalah pemenang undian
  bool isUserWinner(String? userId, String? userEmail, [String? userName]) {
    final block = currentCampaign.winnerBlock;
    if (block == null) return false;

    final uid = userId?.trim();
    final email = userEmail?.trim().toLowerCase();
    final name = userName?.trim().toLowerCase();

    final matchUid = uid != null && uid.isNotEmpty && block.winnerId == uid;
    final matchEmail = email != null && email.isNotEmpty && block.winnerEmail.toLowerCase() == email;
    final matchName = name != null && name.isNotEmpty && block.winnerName.trim().toLowerCase() == name;

    return matchUid || matchEmail || matchName;
  }

  /// Memulai periode undian baru (Soft Reset - menjaga riwayat Blockchain & Supabase tanpa boros kuota)
  Future<void> startNewCampaignPeriod({
    String? newTitle,
    String? newPrize,
    Duration duration = const Duration(days: 7),
  }) async {
    final now = DateTime.now();
    final oldCampaign = currentCampaign;

    // 1. Jika periode sebelumnya sudah diundi, arsipkan riwayat pemenang ke Supabase
    if (oldCampaign.winnerBlock != null) {
      try {
        final supabase = Supabase.instance.client;
        final archiveId = '${oldCampaign.id}_history_${oldCampaign.winnerBlock!.timestamp}';
        await supabase.from('giveaway_campaigns').upsert({
          'id': archiveId,
          'title': oldCampaign.title,
          'prize': oldCampaign.prize,
          'status': 'drawn',
          'winner_id': oldCampaign.winnerBlock?.winnerId,
          'winner_name': oldCampaign.winnerBlock?.winnerName,
          'winner_ticket': oldCampaign.winnerBlock?.entryTicket,
          'winner_email': oldCampaign.winnerBlock?.winnerEmail,
          'winner_block': oldCampaign.winnerBlock?.toJson(),
          'drawn_at': DateTime.fromMillisecondsSinceEpoch(oldCampaign.winnerBlock!.timestamp).toIso8601String(),
          'winner_claim_name': oldCampaign.winnerClaimData?.fullName,
          'winner_claim_phone': oldCampaign.winnerClaimData?.phoneNumber,
          'winner_claim_address': oldCampaign.winnerClaimData?.shippingAddress,
          'winner_claim_notes': oldCampaign.winnerClaimData?.notes,
          'winner_claimed_at': oldCampaign.winnerClaimData?.claimedAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }, onConflict: 'id');
        debugPrint('📜 [Supabase] Riwayat periode lama berhasil diarsipkan: $archiveId');
      } catch (e) {
        debugPrint('⚠️ Gagal arsipkan riwayat lama ke Supabase: $e');
      }
    }

    // 2. Buat kampanye periode baru yang bersih (status Open, kosongkan peserta aktif)
    final newCampaign = GiveawayCampaign(
      id: oldCampaign.id,
      title: newTitle ?? oldCampaign.title,
      prize: newPrize ?? oldCampaign.prize,
      description: oldCampaign.description,
      startDate: now,
      endDate: now.add(duration),
      status: GiveawayStatus.open,
      participants: [],
      winnerBlock: null,
      winnerClaimData: null,
    );

    // 3. PENTING: Blockchain TIDAK DI-RESET!
    // Catatan blok pemenang periode sebelumnya tetap abadi di rantai lokal.

    await _saveCampaign(newCampaign);
    await _box.put('giveaway_status_explicitly_set', true);

    // 4. Perbarui baris aktif di Supabase ke status periode baru yang siap menerima peserta
    await _upsertCampaignToSupabase(newCampaign);
    debugPrint('🎉 Periode undian baru berhasil dibuka tanpa menghapus riwayat lama!');
  }

  /// Alias kompatibilitas
  Future<void> resetCampaignForTesting() => startNewCampaignPeriod();

  Future<void> _saveCampaign(GiveawayCampaign campaign) async {
    await _box.put(_campaignKey, campaign.toJson());
    campaignNotifier.value = campaign;
    // Pemicu listener untuk UI
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    campaignNotifier.notifyListeners();
  }
}
