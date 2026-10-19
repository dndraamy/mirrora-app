/// Model data untuk Rutinitas Skincare Harian (Daily Routine).
library;

class DailyRoutine {
  final String id;
  final String title;
  final String category; // 'Pagi', 'Malam', 'Mingguan', 'Lainnya'
  final String? note;
  final String? time; // Format '07:00' dsb.
  final bool isCompleted;
  final String? lastCompletedDate; // 'yyyy-MM-dd' untuk reset harian
  final int orderIndex;

  const DailyRoutine({
    required this.id,
    required this.title,
    this.category = 'Pagi',
    this.note,
    this.time,
    this.isCompleted = false,
    this.lastCompletedDate,
    this.orderIndex = 0,
  });

  DailyRoutine copyWith({
    String? id,
    String? title,
    String? category,
    String? note,
    String? time,
    bool? isCompleted,
    String? lastCompletedDate,
    int? orderIndex,
  }) {
    return DailyRoutine(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      note: note ?? this.note,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'note': note,
      'time': time,
      'isCompleted': isCompleted,
      'lastCompletedDate': lastCompletedDate,
      'orderIndex': orderIndex,
    };
  }

  factory DailyRoutine.fromMap(Map<String, dynamic> map) {
    return DailyRoutine(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Pagi',
      note: map['note'] as String?,
      time: map['time'] as String?,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      lastCompletedDate: map['lastCompletedDate'] as String?,
      orderIndex: (map['orderIndex'] as int?) ?? 0,
    );
  }

  /// Template rutinitas awal bagi pengguna baru
  static List<DailyRoutine> defaultStarterRoutines() {
    return [
      const DailyRoutine(
        id: 'routine_default_1',
        title: 'Gentle Facial Wash',
        category: 'Pagi',
        note: 'Pembersih wajah lembut tanpa busa berlebih',
        time: '07:00',
        orderIndex: 0,
      ),
      const DailyRoutine(
        id: 'routine_default_2',
        title: 'Hydrating Toner / Essence',
        category: 'Pagi',
        note: 'Tepuk-tepuk lembut sampai meresap ke kulit',
        time: '07:05',
        orderIndex: 1,
      ),
      const DailyRoutine(
        id: 'routine_default_3',
        title: 'Sunscreen SPF 50+ PA++++',
        category: 'Pagi',
        note: 'Gunakan sebanyak 2 ruas jari sebelum aktivitas',
        time: '07:15',
        orderIndex: 2,
      ),
      const DailyRoutine(
        id: 'routine_default_4',
        title: 'Double Cleansing (Micellar / Cleansing Oil)',
        category: 'Malam',
        note: 'Hapus sisa makeup dan sunscreen seharian',
        time: '20:30',
        orderIndex: 3,
      ),
      const DailyRoutine(
        id: 'routine_default_5',
        title: 'Moisturizer / Night Cream',
        category: 'Malam',
        note: 'Mengunci kelembapan kulit saat istirahat malam',
        time: '21:00',
        orderIndex: 4,
      ),
    ];
  }
}

