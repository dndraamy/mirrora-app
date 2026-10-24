import 'package:flutter/material.dart';

import '../models/routine_model.dart';
import '../services/notification_service.dart';
import '../services/routine_service.dart';
import '../theme/mirrora_theme.dart';

/// Halaman Pengelolaan Daily Routine (Rutinitas Skincare Harian)
class DailyRoutineScreen extends StatefulWidget {
  const DailyRoutineScreen({super.key});

  @override
  State<DailyRoutineScreen> createState() => _DailyRoutineScreenState();
}

class _DailyRoutineScreenState extends State<DailyRoutineScreen> {
  final RoutineService _routineService = RoutineService();
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Pagi',
    'Malam',
  ];

  @override
  void initState() {
    super.initState();
    _routineService.addListener(_onRoutineUpdated);
  }

  @override
  void dispose() {
    _routineService.removeListener(_onRoutineUpdated);
    super.dispose();
  }

  void _onRoutineUpdated() {
    if (mounted) setState(() {});
  }

  List<DailyRoutine> get _filteredRoutines {
    final all = _routineService.routines;
    if (_selectedCategory == 'Semua') return all;
    return all.where((r) => r.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_selectedCategory == 'Semua') {
      _routineService.reorderRoutines(oldIndex, newIndex);
    } else {
      final currentList = List<DailyRoutine>.from(_filteredRoutines);
      if (oldIndex < 0 || oldIndex >= currentList.length) return;
      if (newIndex < 0 || newIndex > currentList.length) return;
      final movedItem = currentList.removeAt(oldIndex);
      currentList.insert(newIndex, movedItem);
      _routineService.reorderFilteredRoutines(currentList);
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog: Tambah / Edit Rutinitas
  // ---------------------------------------------------------------------------
  Future<void> _showRoutineFormDialog({DailyRoutine? routineToEdit}) async {
    final isEditing = routineToEdit != null;
    final titleController = TextEditingController(text: routineToEdit?.title ?? '');
    final noteController = TextEditingController(text: routineToEdit?.note ?? '');
    final timeController = TextEditingController(text: routineToEdit?.time ?? '');
    String category = routineToEdit?.category ?? 'Pagi';
    if (category != 'Pagi' && category != 'Malam') {
      category = 'Pagi';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: MirroraTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: MirroraTheme.blushPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'Edit Rutinitas Skincare' : 'Tambah Rutinitas Baru',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tentukan langkah dan waktu rutinitas skincare-mu',
                      style: TextStyle(fontSize: 12.5, color: MirroraTheme.warmGray),
                    ),
                    const SizedBox(height: 20),

                    // Input Nama Rutinitas
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Nama Rutinitas / Produk *',
                        hintText: 'Misal: Sunscreen SPF 50',
                        filled: true,
                        fillColor: MirroraTheme.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MirroraTheme.blushPink),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MirroraTheme.blushPink),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: MirroraTheme.dustyRose, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pilihan Kategori Waktu
                    const Text(
                      'Waktu Rutinitas:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: MirroraTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Pagi', 'Malam'].map((cat) {
                        final isSelected = category == cat;
                        final iconStr = cat == 'Pagi' ? '☀️' : '🌙';

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text('$iconStr $cat'),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : MirroraTheme.charcoal,
                              ),
                              selected: isSelected,
                              selectedColor: MirroraTheme.dustyRose,
                              backgroundColor: MirroraTheme.cream,
                              side: BorderSide(
                                color: isSelected ? MirroraTheme.dustyRose : MirroraTheme.blushPink,
                              ),
                              onSelected: (_) {
                                setSheetState(() => category = cat);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Input Jam & Catatan
                    Builder(
                      builder: (builderCtx) {
                        Future<void> pickTime() async {
                          TimeOfDay initial = const TimeOfDay(hour: 7, minute: 0);
                          if (timeController.text.isNotEmpty) {
                            final parts = timeController.text
                                .replaceAll('.', ':')
                                .split(':');
                            if (parts.length >= 2) {
                              final h = int.tryParse(parts[0]);
                              final m = int.tryParse(parts[1]);
                              if (h != null && m != null) {
                                initial = TimeOfDay(hour: h, minute: m);
                              }
                            }
                          }
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: initial,
                            builder: (pickerCtx, child) => Theme(
                              data: Theme.of(pickerCtx).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: MirroraTheme.dustyRose,
                                  onPrimary: Colors.white,
                                  surface: MirroraTheme.white,
                                  onSurface: MirroraTheme.charcoal,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            final hh = picked.hour.toString().padLeft(2, '0');
                            final mm = picked.minute.toString().padLeft(2, '0');
                            timeController.text = '$hh:$mm';
                            setSheetState(() {});
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: pickTime,
                                    borderRadius: BorderRadius.circular(14),
                                    child: IgnorePointer(
                                      child: TextField(
                                        controller: timeController,
                                        decoration: InputDecoration(
                                          labelText: 'Jam Notifikasi',
                                          hintText: '07:00',
                                          prefixIcon: const Icon(
                                            Icons.access_time_rounded,
                                            size: 18,
                                            color: MirroraTheme.dustyRose,
                                          ),
                                          filled: true,
                                          fillColor: MirroraTheme.cream,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: const BorderSide(
                                              color: MirroraTheme.blushPink,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 6,
                                  child: TextField(
                                    controller: noteController,
                                    decoration: InputDecoration(
                                      labelText: 'Catatan / Tips (Opsional)',
                                      hintText: 'Tepuk lembut',
                                      filled: true,
                                      fillColor: MirroraTheme.cream,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: MirroraTheme.blushPink,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (timeController.text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_active_rounded,
                                    size: 13,
                                    color: MirroraTheme.dustyRose,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Pengingat berbunyi tiap jam ${timeController.text} 🔔',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: MirroraTheme.dustyRose,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      timeController.clear();
                                      setSheetState(() {});
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'Hapus Jam',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nama rutinitas tidak boleh kosong')),
                            );
                            return;
                          }

                          if (isEditing) {
                            await _routineService.updateRoutine(
                              routineToEdit.copyWith(
                                title: title,
                                category: category,
                                time: timeController.text.trim().isEmpty ? null : timeController.text.trim(),
                                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                              ),
                            );
                          } else {
                            final newRoutine = DailyRoutine(
                              id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
                              title: title,
                              category: category,
                              time: timeController.text.trim().isEmpty ? null : timeController.text.trim(),
                              note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                            );
                            await _routineService.addRoutine(newRoutine);
                          }

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MirroraTheme.dustyRose,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Simpan Perubahan' : 'Tambahkan Rutinitas',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Konfirmasi Hapus
  // ---------------------------------------------------------------------------
  Future<void> _confirmDelete(DailyRoutine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Rutinitas?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Yakin ingin menghapus "${routine.title}" dari rutinitasmu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _routineService.deleteRoutine(routine.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Dialog: Opsi Menu Atas (Reset Checklist / Muat Template)
  // ---------------------------------------------------------------------------
  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: MirroraTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: MirroraTheme.blushPink,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: MirroraTheme.dustyRose),
              title: const Text('Pengingat Skincare', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Sinkronkan jadwal alarm pengingat di perangkat'),
              onTap: () async {
                Navigator.pop(ctx);
                await NotificationService().syncAllRoutineNotifications(_routineService.routines);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Jadwal pengingat skincare berhasil disinkronkan!')),
                );
              },
            ),
            const Divider(color: MirroraTheme.blushPink),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded, color: MirroraTheme.dustyRose),
              title: const Text('Mulai Ulang Checklist Hari Ini', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Kosongkan semua tanda centang untuk memulai hari'),
              onTap: () {
                Navigator.pop(ctx);
                _routineService.resetAllForToday();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checklist harian berhasil di-reset.')),
                );
              },
            ),
            const Divider(color: MirroraTheme.blushPink),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              title: const Text('Hapus Semua Rutinitas', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent)),
              subtitle: const Text('Kosongkan semua daftar rutinitas yang telah dibuat'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: MirroraTheme.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Hapus Semua Rutinitas?', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('Semua langkah skincare yang sudah kamu buat akan dihapus dan kembali kosong.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Hapus Semua', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _routineService.clearAllRoutines();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semua rutinitas telah dihapus.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Daily Routine',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: MirroraTheme.charcoal,
          ),
        ),
        elevation: 0,
        backgroundColor: MirroraTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: MirroraTheme.charcoal),
            tooltip: 'Opsi Rutinitas',
            onPressed: _showOptionsSheet,
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _routineService,
        builder: (context, _) {
          if (_routineService.totalCount == 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showRoutineFormDialog(),
            backgroundColor: MirroraTheme.dustyRose,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Tambah Rutinitas',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: _routineService,
        builder: (context, _) {
          final routines = _filteredRoutines;
          final total = _routineService.totalCount;
          final done = _routineService.completedCount;
          final progress = _routineService.progress;

          if (total == 0) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // 1. Progress Banner Card
              Container(
                color: MirroraTheme.white,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kemajuan Hari Ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: progress == 1.0
                              ? const Color(0xFFEAF5EE)
                              : MirroraTheme.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$done/$total Selesai (${(progress * 100).round()}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: progress == 1.0 ? const Color(0xFF2E6F3E) : MirroraTheme.dustyRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: MirroraTheme.white,
                      valueColor: const AlwaysStoppedAnimation(MirroraTheme.dustyRose),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    progress == 1.0
                        ? '🎉 Luar biasa! Seluruh rutinitas skincare hari ini sudah selesai.'
                        : 'Konsistensi adalah kunci kulit sehat & glowing ✨',
                    style: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                  ),
                ],
              ),
            ),
          ),

          // 2. Filter Kategori Chips
          Container(
            color: MirroraTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  String emoji = '';
                  if (cat == 'Pagi') emoji = '☀️ ';
                  if (cat == 'Malam') emoji = '🌙 ';

                  return ChoiceChip(
                    label: Text('$emoji$cat'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : MirroraTheme.charcoal,
                    ),
                    selected: isSelected,
                    selectedColor: MirroraTheme.dustyRose,
                    backgroundColor: MirroraTheme.cream,
                    side: BorderSide(
                      color: isSelected ? MirroraTheme.dustyRose : MirroraTheme.blushPink,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),
          ),

          // 3. Hint Drag to Reorder
          if (routines.length > 1)
            Container(
              color: MirroraTheme.white,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MirroraTheme.cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MirroraTheme.blushPink),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: MirroraTheme.dustyRose,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tahan & geser ikon ⠿ untuk menyesuaikan urutan langkah',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                    ),
                    Text(
                      '${routines.length} Langkah',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.dustyRose,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Daftar Rutinitas Skincare (Dapat Diatur Urutannya)
          Expanded(
            child: routines.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: routines.length,
                    onReorderItem: _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final animValue = Curves.easeInOut.transform(animation.value);
                          final elevation = animValue * 8.0;
                          return Material(
                            elevation: elevation,
                            color: Colors.transparent,
                            shadowColor: MirroraTheme.dustyRose.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(18),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = routines[index];
                      return _buildRoutineItemCard(item, index);
                    },
                  ),
          ),
        ],
      );
    },
  ),
);
}

  // ---------------------------------------------------------------------------
  // Kartu Masing-masing Rutinitas
  // ---------------------------------------------------------------------------
  Widget _buildRoutineItemCard(DailyRoutine item, int index) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isCompleted ? const Color(0xFFC6F6D5) : MirroraTheme.blushPink,
          width: item.isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _routineService.toggleRoutine(item.id),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Nomor Urut Langkah (Step Sequence)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.isCompleted
                        ? MirroraTheme.dustyRose.withValues(alpha: 0.12)
                        : MirroraTheme.cream,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isCompleted
                          ? MirroraTheme.dustyRose.withValues(alpha: 0.3)
                          : MirroraTheme.blushPink,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.isCompleted ? MirroraTheme.dustyRose : MirroraTheme.charcoal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Checkbox Bulat Estetik
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _routineService.toggleRoutine(item.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: item.isCompleted ? MirroraTheme.dustyRose : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.isCompleted ? MirroraTheme.dustyRose : MirroraTheme.warmGray,
                        width: 1.8,
                      ),
                    ),
                    child: item.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Judul & Detail Rutinitas
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: item.isCompleted ? MirroraTheme.warmGray : MirroraTheme.charcoal,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          // Badge Kategori (Pagi / Malam)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.category == 'Pagi'
                                  ? const Color(0xFFFFF7EB)
                                  : const Color(0xFFEDF2F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category == 'Pagi'
                                  ? '☀️ Pagi'
                                  : '🌙 Malam',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.category == 'Pagi'
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF512DA8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((item.time != null && item.time!.isNotEmpty) ||
                          (item.note != null && item.note!.isNotEmpty)) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (item.time != null && item.time!.isNotEmpty) ...[
                              Icon(Icons.access_time_rounded, size: 12, color: MirroraTheme.warmGray),
                              const SizedBox(width: 3),
                              Text(
                                item.time!,
                                style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (item.note != null && item.note!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  item.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Popup Menu Edit / Hapus
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: MirroraTheme.warmGray),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showRoutineFormDialog(routineToEdit: item);
                    } else if (val == 'delete') {
                      _confirmDelete(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: MirroraTheme.charcoal),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 2),

                // Drag Handle
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Tooltip(
                      message: 'Tahan & geser untuk mengubah urutan',
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 22,
                        color: MirroraTheme.warmGray,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 34,
                color: MirroraTheme.dustyRose,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tambahkan rutinitas harianmu',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kamu belum menambahkan rutinitas skincare.\nMulai susun langkah rutinitas pagi atau malammu sendiri!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: MirroraTheme.warmGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _showRoutineFormDialog(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Tambahkan Rutinitas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.dustyRose,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

