import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Status fase giveaway
enum GiveawayStatus {
  open,   // Pendaftaran dibuka, iklan tampil di Home
  closed, // Pendaftaran ditutup, iklan disembunyikan dari Home
  drawn,  // Pengundian selesai, iklan pemenang & blockchain tampil di Home
}

/// Model peserta giveaway
class GiveawayParticipant {
  const GiveawayParticipant({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.entryTicket,
    required this.registeredAt,
  });

  final String userId;
  final String userName;
  final String userEmail;
  final String entryTicket; // Cth: #MIR-1049
  final DateTime registeredAt;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'entryTicket': entryTicket,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory GiveawayParticipant.fromJson(Map<String, dynamic> json) {
    return GiveawayParticipant(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Peserta',
      userEmail: json['userEmail'] as String? ?? '',
      entryTicket: json['entryTicket'] as String? ?? '#MIR-0000',
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Blok Blockchain lokal untuk mengunci data pemenang secara permanen
class BlockchainBlock {
  const BlockchainBlock({
    required this.index,
    required this.timestamp,
    required this.campaignId,
    required this.winnerId,
    required this.winnerName,
    required this.winnerEmail,
    required this.entryTicket,
    required this.prize,
    required this.totalParticipants,
    required this.nonce,
    required this.previousHash,
    required this.hash,
  });

  final int index;
  final int timestamp;
  final String campaignId;
  final String winnerId;
  final String winnerName;
  final String winnerEmail;
  final String entryTicket;
  final String prize;
  final int totalParticipants;
  final int nonce;
  final String previousHash;
  final String hash;

  /// Menghitung hash kriptografis SHA-256 berdasarkan seluruh isi blok
  static String calculateHashString({
    required int index,
    required int timestamp,
    required String campaignId,
    required String winnerId,
    required String winnerName,
    required String winnerEmail,
    required String entryTicket,
    required String prize,
    required int totalParticipants,
    required int nonce,
    required String previousHash,
  }) {
    final rawData = '$index|$timestamp|$campaignId|$winnerId|$winnerName|'
        '$winnerEmail|$entryTicket|$prize|$totalParticipants|$nonce|$previousHash';
    return sha256.convert(utf8.encode(rawData)).toString();
  }

  /// Memverifikasi apakah hash blok saat ini cocok dengan datanya (tidak termanipulasi)
  bool isValid() {
    final calculated = calculateHashString(
      index: index,
      timestamp: timestamp,
      campaignId: campaignId,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerEmail: winnerEmail,
      entryTicket: entryTicket,
      prize: prize,
      totalParticipants: totalParticipants,
      nonce: nonce,
      previousHash: previousHash,
    );
    return calculated == hash;
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp,
        'campaignId': campaignId,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'winnerEmail': winnerEmail,
        'entryTicket': entryTicket,
        'prize': prize,
        'totalParticipants': totalParticipants,
        'nonce': nonce,
        'previousHash': previousHash,
        'hash': hash,
      };

  factory BlockchainBlock.fromJson(Map<String, dynamic> json) {
    return BlockchainBlock(
      index: json['index'] as int? ?? 0,
      timestamp: json['timestamp'] as int? ?? 0,
      campaignId: json['campaignId'] as String? ?? '',
      winnerId: json['winnerId'] as String? ?? '',
      winnerName: json['winnerName'] as String? ?? '',
      winnerEmail: json['winnerEmail'] as String? ?? '',
      entryTicket: json['entryTicket'] as String? ?? '',
      prize: json['prize'] as String? ?? '',
      totalParticipants: json['totalParticipants'] as int? ?? 0,
      nonce: json['nonce'] as int? ?? 0,
      previousHash: json['previousHash'] as String? ?? '0',
      hash: json['hash'] as String? ?? '',
    );
  }
}

/// Rantai Blok (Blockchain) lokal untuk mencatat histori pengundian yang transparan
class SimpleBlockchain {
  SimpleBlockchain({List<BlockchainBlock>? chain}) {
    if (chain != null && chain.isNotEmpty) {
      _chain = List<BlockchainBlock>.from(chain);
    } else {
      _chain = [_createGenesisBlock()];
    }
  }

  late final List<BlockchainBlock> _chain;
  List<BlockchainBlock> get chain => List.unmodifiable(_chain);

  BlockchainBlock get latestBlock => _chain.last;

  /// Membuat Genesis Block (Blok Awal Rantai)
  static BlockchainBlock _createGenesisBlock() {
    const index = 0;
    const timestamp = 1713500000000;
    const campaignId = 'GENESIS_MIRRORA';
    const winnerId = '0000-GENESIS';
    const winnerName = 'Mirrora Official Ledger';
    const winnerEmail = 'system@mirrora.local';
    const entryTicket = '#GENESIS';
    const prize = 'Genesis Root';
    const totalParticipants = 0;
    const nonce = 2026;
    const previousHash = '0000000000000000000000000000000000000000000000000000000000000000';

    final hash = BlockchainBlock.calculateHashString(
      index: index,
      timestamp: timestamp,
      campaignId: campaignId,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerEmail: winnerEmail,
      entryTicket: entryTicket,
      prize: prize,
      totalParticipants: totalParticipants,
      nonce: nonce,
      previousHash: previousHash,
    );

    return BlockchainBlock(
      index: index,
      timestamp: timestamp,
      campaignId: campaignId,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerEmail: winnerEmail,
      entryTicket: entryTicket,
      prize: prize,
      totalParticipants: totalParticipants,
      nonce: nonce,
      previousHash: previousHash,
      hash: hash,
    );
  }

  /// Menambahkan blok pemenang baru yang terikat secara kriptografis ke blok sebelumnya
  BlockchainBlock addWinnerBlock({
    required String campaignId,
    required String winnerId,
    required String winnerName,
    required String winnerEmail,
    required String entryTicket,
    required String prize,
    required int totalParticipants,
    required int nonce,
  }) {
    final prevBlock = latestBlock;
    final newIndex = prevBlock.index + 1;
    final newTimestamp = DateTime.now().millisecondsSinceEpoch;
    final prevHash = prevBlock.hash;

    final newHash = BlockchainBlock.calculateHashString(
      index: newIndex,
      timestamp: newTimestamp,
      campaignId: campaignId,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerEmail: winnerEmail,
      entryTicket: entryTicket,
      prize: prize,
      totalParticipants: totalParticipants,
      nonce: nonce,
      previousHash: prevHash,
    );

    final newBlock = BlockchainBlock(
      index: newIndex,
      timestamp: newTimestamp,
      campaignId: campaignId,
      winnerId: winnerId,
      winnerName: winnerName,
      winnerEmail: winnerEmail,
      entryTicket: entryTicket,
      prize: prize,
      totalParticipants: totalParticipants,
      nonce: nonce,
      previousHash: prevHash,
      hash: newHash,
    );

    _chain.add(newBlock);
    return newBlock;
  }

  /// Memverifikasi seluruh rantai: menjamin data tidak pernah diubah
  bool verifyIntegrity() {
    for (int i = 1; i < _chain.length; i++) {
      final current = _chain[i];
      final previous = _chain[i - 1];

      // Cek validitas hash blok saat ini
      if (!current.isValid()) return false;

      // Cek apakah previousHash blok saat ini sama persis dengan hash blok sebelumnya
      if (current.previousHash != previous.hash) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> toJsonList() =>
      _chain.map((b) => b.toJson()).toList();

  factory SimpleBlockchain.fromJsonList(List<dynamic> jsonList) {
    final blocks = jsonList
        .map((item) => BlockchainBlock.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return SimpleBlockchain(chain: blocks);
  }
}

/// Model utama kampanye Anniversary Giveaway
/// Model data klaim pengiriman hadiah oleh pemenang
class WinnerClaimData {
  WinnerClaimData({
    required this.winnerId,
    required this.fullName,
    required this.phoneNumber,
    required this.shippingAddress,
    this.notes = '',
    required this.claimedAt,
  });

  final String winnerId;
  final String fullName;
  final String phoneNumber;
  final String shippingAddress;
  final String notes;
  final DateTime claimedAt;

  Map<String, dynamic> toJson() => {
        'winnerId': winnerId,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'shippingAddress': shippingAddress,
        'notes': notes,
        'claimedAt': claimedAt.toIso8601String(),
      };

  factory WinnerClaimData.fromJson(Map<String, dynamic> json) {
    return WinnerClaimData(
      winnerId: json['winnerId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      claimedAt: json['claimedAt'] != null
          ? DateTime.parse(json['claimedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Model data kampanye giveaway
class GiveawayCampaign {
  GiveawayCampaign({
    required this.id,
    required this.title,
    required this.prize,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.participants,
    this.winnerBlock,
    this.winnerClaimData,
  });

  final String id;
  String title;
  String prize;
  String description;
  DateTime startDate;
  DateTime endDate;
  GiveawayStatus status;
  List<GiveawayParticipant> participants;
  BlockchainBlock? winnerBlock;
  WinnerClaimData? winnerClaimData;

  bool get isOpen => status == GiveawayStatus.open;
  bool get isClosed => status == GiveawayStatus.closed;
  bool get isDrawn => status == GiveawayStatus.drawn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'prize': prize,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': status.name,
        'participants': participants.map((p) => p.toJson()).toList(),
        'winnerBlock': winnerBlock?.toJson(),
        'winnerClaimData': winnerClaimData?.toJson(),
      };

  factory GiveawayCampaign.fromJson(Map<String, dynamic> json) {
    GiveawayStatus parsedStatus = GiveawayStatus.closed;
    final statusStr = json['status'] as String?;
    if (statusStr == 'open') {
      parsedStatus = GiveawayStatus.open;
    } else if (statusStr == 'drawn') {
      parsedStatus = GiveawayStatus.drawn;
    } else {
      parsedStatus = GiveawayStatus.closed;
    }

    final participantsJson = json['participants'] as List<dynamic>? ?? [];
    final participantsList = participantsJson
        .map((p) => GiveawayParticipant.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    BlockchainBlock? block;
    if (json['winnerBlock'] != null) {
      block = BlockchainBlock.fromJson(
        Map<String, dynamic>.from(json['winnerBlock'] as Map),
      );
    }

    WinnerClaimData? claimData;
    if (json['winnerClaimData'] != null) {
      claimData = WinnerClaimData.fromJson(
        Map<String, dynamic>.from(json['winnerClaimData'] as Map),
      );
    }

    return GiveawayCampaign(
      id: json['id'] as String? ?? 'mirrora_2nd_anniversary',
      title: json['title'] as String? ?? '🎉 Mirrora 2nd Anniversary Giveaway!',
      prize: json['prize'] as String? ?? '1 Set Skincare COSRX!',
      description: json['description'] as String? ??
          'Ikuti undian berhadiah spesial ulang tahun ke-2. Pemenang dipilih acak dan diverifikasi transparan di blockchain!',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now().subtract(const Duration(days: 2)),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      status: parsedStatus,
      participants: participantsList,
      winnerBlock: block,
      winnerClaimData: claimData,
    );
  }

  /// Template default bawaan saat aplikasi pertama kali dijalankan
  factory GiveawayCampaign.defaultCampaign() {
    final now = DateTime.now();
    return GiveawayCampaign(
      id: 'mirrora_2nd_anniversary',
      title: '🎉 Mirrora 2nd Anniversary Giveaway!',
      prize: '1 Set Skincare COSRX!',
      description:
          'Rayakan 2 tahun perjalanan self-care bersama kami! Dapatkan kesempatan memenangkan 1 Set Skincare COSRX original gratis.',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 7)),
      status: GiveawayStatus.open,
      participants: [],
      winnerBlock: null,
    );
  }
}