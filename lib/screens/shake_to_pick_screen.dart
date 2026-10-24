import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/giveaway_service.dart';
import '../theme/mirrora_theme.dart';

// ─── Kunci Hive (per pengguna, diberi awalan user ID) ───────────────────────
// Dibuat dalam bentuk fungsi supaya setiap akun punya slot batas shake
// sendiri-sendiri, walaupun dipakai di perangkat yang sama.
String _kWindowStartMs(String uid) => 'shake_window_start_ms_$uid';
String _kCountInWindow(String uid) => 'shake_count_in_window_$uid';

// ─── Batas penggunaan (rate limit) ──────────────────────────────────────────
const int _maxShakesPerWindow = 10;
const Duration _windowDuration = Duration(hours: 24);

// ─── Parameter guncangan ────────────────────────────────────────────────────
const double _shakeThreshold =
    12.0; // percepatan minimum (m/s²) agar dianggap guncangan
const double _energyPerShake =
    0.25; // energi yang bertambah per guncangan (butuh sekitar 5 guncangan)
const double _energyDecayRate =
    0.09; // energi yang berkurang per detik jika tidak digoyang

// ─── Peluang dapat tiket undian (gacha berimbang: ~48% dapat tiket, ~52% zonk) ───
const double _ticketWinRate = 0.48;

// ─── Warna kelopak bunga ────────────────────────────────────────────────────
const _petalColors = [
  Color(0xFFFFD6E0),
  Color(0xFFF8B8CC),
  Color(0xFFEFA0B8),
  Color(0xFFE08AA8),
  Color(0xFFFFF0F4),
  Color(0xFFEFD0DC),
];

final _rng = Random();

// =========================================================================
// DATA: PARTIKEL KELOPAK BUNGA
// =========================================================================

class _Petal {
  _Petal({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
    required this.lifetime,
  });

  double x, y, vx, vy;
  double rotation, rotationSpeed;
  Color color;
  double size;
  double lifetime;
  double age = 0.0;

  // Transparansi kelopak: muncul perlahan di awal, penuh di tengah,
  // lalu memudar di akhir masa hidupnya.
  double get opacity {
    final t = age / lifetime;
    if (t < 0.1) return t / 0.1;
    if (t > 0.65) return 1.0 - (t - 0.65) / 0.35;
    return 1.0;
  }

  bool get isDead => age >= lifetime;
}

// =========================================================================
// PAINTER: POHON SAKURA + KELOPAK
// =========================================================================

class _BlossomTreePainter extends CustomPainter {
  _BlossomTreePainter({
    required this.treeAngle,
    required this.shakeEnergy,
    required this.petals,
  });

  final double treeAngle;
  final double shakeEnergy;
  final List<_Petal> petals;

  // Tinggi asli pohon dalam koordinat lokal (dari pangkal batang sampai puncak bunga)
  static const double _naturalTreeH = 185.0;

  // ── Konfigurasi warna ranting ─────────────────────────────────────────────
  static const _trunkColor = Color(0xFF8B6043);
  static const _branchColor = Color(0xFF9A7050);
  static const _thinBranchColor = Color(0xFFB08865);

  static const _blossomDeep = Color(0xFFC98C9C); // dustyRose
  static const _blossomMid = Color(0xFFE5AABF);
  static const _blossomLight = Color(0xFFF8D8E8);
  static const _blossomPale = Color(0xFFFFF2F6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height;

    // Skala pohon agar memenuhi ±80% tinggi kanvas supaya terlihat jelas
    final treeScale = ((size.height * 0.80) / _naturalTreeH).clamp(0.8, 2.8);

    // ── Gambar pohon (diskalakan + diputar dengan poros di pangkal batang) ──
    canvas.save();
    canvas.translate(cx, base);
    canvas.scale(treeScale);
    canvas.rotate(treeAngle);

    _drawTrunk(canvas);
    _drawBranches(canvas);
    _drawBlossoms(canvas);

    canvas.restore();

    // ── Gambar kelopak yang berjatuhan (koordinat kanvas asli, tidak diskalakan) ──
    for (final p in petals) {
      _drawPetal(canvas, p);
    }
  }

  // ── Batang pohon ──────────────────────────────────────────────────────────
  void _drawTrunk(Canvas canvas) {
    final path = Path();
    // Bentuk batang meruncing (lebar di pangkal, menyempit ke atas)
    path.moveTo(-9, 0);
    path.cubicTo(-10, -40, -7, -80, -5, -118);
    path.lineTo(5, -118);
    path.cubicTo(7, -80, 10, -40, 9, 0);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _trunkColor
        ..style = PaintingStyle.fill,
    );

    // Garis tekstur kulit kayu
    final barkPaint = Paint()
      ..color = _trunkColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-3, -20), const Offset(-4, -70), barkPaint);
    canvas.drawLine(const Offset(3, -30), const Offset(4, -85), barkPaint);
  }

  // ── Dahan dan ranting ─────────────────────────────────────────────────────
  void _drawBranches(Canvas canvas) {
    _branch(canvas, Offset.zero, const Offset(-80, -148), _branchColor, 7.5);
    _branch(canvas, Offset.zero, const Offset(80, -148), _branchColor, 7.5);
    _branch(
      canvas,
      const Offset(0, -118),
      const Offset(0, -158),
      _branchColor,
      6,
    );
    _branch(
      canvas,
      const Offset(-30, -100),
      const Offset(-62, -155),
      _thinBranchColor,
      4.5,
    );
    _branch(
      canvas,
      const Offset(30, -100),
      const Offset(62, -155),
      _thinBranchColor,
      4.5,
    );
    _branch(
      canvas,
      const Offset(-50, -120),
      const Offset(-92, -152),
      _thinBranchColor,
      3,
    );
    _branch(
      canvas,
      const Offset(50, -120),
      const Offset(92, -152),
      _thinBranchColor,
      3,
    );
    _branch(
      canvas,
      const Offset(-20, -108),
      const Offset(-40, -160),
      _thinBranchColor,
      3,
    );
    _branch(
      canvas,
      const Offset(20, -108),
      const Offset(40, -160),
      _thinBranchColor,
      3,
    );
    _branch(
      canvas,
      const Offset(0, -118),
      const Offset(-22, -165),
      _thinBranchColor,
      2.5,
    );
    _branch(
      canvas,
      const Offset(0, -118),
      const Offset(22, -165),
      _thinBranchColor,
      2.5,
    );
  }

  void _branch(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Ranting dibuat melengkung memakai kurva bezier kuadratik
    final ctrl = Offset(
      (from.dx + to.dx) / 2 + (to.dy - from.dy) * 0.05,
      (from.dy + to.dy) / 2,
    );
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  // ── Gumpalan bunga (kanopi) ───────────────────────────────────────────────
  void _drawBlossoms(Canvas canvas) {
    // Gumpalan bunga diletakkan di ujung ranting dan beberapa titik di antaranya
    final clusters = <_ClusterSpec>[
      _ClusterSpec(const Offset(-82, -152), 36),
      _ClusterSpec(const Offset(82, -152), 36),
      _ClusterSpec(const Offset(0, -162), 40),
      _ClusterSpec(const Offset(-42, -164), 28),
      _ClusterSpec(const Offset(42, -164), 28),
      _ClusterSpec(const Offset(-24, -170), 22),
      _ClusterSpec(const Offset(24, -170), 22),
      _ClusterSpec(const Offset(-65, -160), 24),
      _ClusterSpec(const Offset(65, -160), 24),
      _ClusterSpec(const Offset(-95, -150), 18),
      _ClusterSpec(const Offset(95, -150), 18),
    ];

    for (final c in clusters) {
      _drawBlossomCluster(canvas, c.center, c.radius);
    }
  }

  void _drawBlossomCluster(Canvas canvas, Offset center, double r) {
    // Lingkaran bertumpuk: dari lapisan luar yang pucat ke lapisan dalam yang lebih pekat
    final layers = [
      (r * 1.0, _blossomPale.withValues(alpha: 0.6)),
      (r * 0.85, _blossomLight.withValues(alpha: 0.75)),
      (r * 0.68, _blossomMid.withValues(alpha: 0.82)),
      (r * 0.48, _blossomDeep.withValues(alpha: 0.70)),
    ];

    // Lingkaran-lingkaran kecil yang digeser agar siluetnya mirip awan
    final offsets = [
      Offset.zero,
      Offset(r * 0.38, -r * 0.18),
      Offset(-r * 0.35, -r * 0.20),
      Offset(r * 0.15, r * 0.32),
      Offset(-r * 0.20, r * 0.28),
      Offset(r * 0.45, r * 0.15),
      Offset(-r * 0.42, r * 0.12),
    ];

    for (final (radius, color) in layers) {
      final paint = Paint()..color = color;
      for (final off in offsets) {
        // Geseran disesuaikan dengan faktor ukuran tiap lapisan
        final scaledOff = off * (radius / r);
        canvas.drawCircle(center + scaledOff, radius * 0.62, paint);
      }
      canvas.drawCircle(center, radius * 0.72, paint);
    }

    // Titik-titik kecil sebagai detail bunga di bagian atas
    final dotPaint = Paint()..color = _blossomDeep.withValues(alpha: 0.5);
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final dx = cos(angle) * r * 0.55;
      final dy = sin(angle) * r * 0.55;
      canvas.drawCircle(center + Offset(dx, dy), 2.5, dotPaint);
    }
  }

  // ── Kelopak yang berjatuhan ───────────────────────────────────────────────
  void _drawPetal(Canvas canvas, _Petal p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);

    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;

    // Bentuk kelopak oval
    final path = Path();
    final w = p.size * 0.45;
    final h = p.size * 0.9;
    path.moveTo(0, -h);
    path.cubicTo(w, -h * 0.5, w * 0.8, h * 0.3, 0, h);
    path.cubicTo(-w * 0.8, h * 0.3, -w, -h * 0.5, 0, -h);

    canvas.drawPath(path, paint);

    // Garis tengah kelopak
    final veinPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.4)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -h * 0.7), Offset(0, h * 0.7), veinPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlossomTreePainter old) => true;
}

class _ClusterSpec {
  const _ClusterSpec(this.center, this.radius);
  final Offset center;
  final double radius;
}

// =========================================================================
// LAYAR SHAKE TO PICK
// =========================================================================

class ShakeToPickScreen extends StatefulWidget {
  const ShakeToPickScreen({super.key});

  @override
  State<ShakeToPickScreen> createState() => _ShakeToPickScreenState();
}

enum _PickState { idle, result }

class _ShakeToPickScreenState extends State<ShakeToPickScreen>
    with TickerProviderStateMixin {
  // ── User ID Supabase (batas shake dipisah per akun) ───────────────────────
  String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  // ── Ticker game (loop 60fps) ──────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // ── Fisika pegas untuk goyangan pohon ─────────────────────────────────────
  double _treeAngle = 0.0;
  double _treeAngVelocity = 0.0;
  double _idleTime = 0.0; // waktu untuk gerakan sinus ayunan pelan saat diam

  // ── Energi guncangan ──────────────────────────────────────────────────────
  /// 0.0 → 1.0 — harus penuh untuk memunculkan hasil
  double _shakeEnergy = 0.0;
  bool _isBursting =
      false; // true sementara animasi ledakan kelopak saat energi penuh

  // ── Kelopak ───────────────────────────────────────────────────────────────
  final List<_Petal> _petals = [];
  double _petalSpawnAccum = 0.0;

  // ── Jeda antar guncangan (debounce) ───────────────────────────────────────
  DateTime _lastShakeEvent = DateTime.fromMillisecondsSinceEpoch(0);
  double _latestX =
      0.0; // bacaan percepatan sumbu X terakhir (untuk arah dorongan)

  // ── State layar ───────────────────────────────────────────────────────────
  _PickState _state = _PickState.idle;
  String? _wonTicket;
  bool _isWin = false;
  bool _isSubmittingTicket = false;
  bool _isTicketSubmitted = false;

  // ── Batas penggunaan harian ───────────────────────────────────────────────
  int _usedCount = 0;
  bool _onCooldown = false;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _countdownTimer;

  // ── Sensor ────────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // ── Ukuran kanvas pohon (diperbarui dari LayoutBuilder, dipakai _spawnPetal) ──
  Size _treeCanvasSize = const Size(400, 380);

  // ── Animasi denyut untuk pil petunjuk ─────────────────────────────────────
  late final AnimationController _pulseCtrl;

  // ── Animasi tampilan hasil ────────────────────────────────────────────────
  late final AnimationController _resultCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.22),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _resultCtrl,
    curve: Curves.easeOut,
  );

  // ═══════════════════════════════════════════════════════════════
  // SIKLUS HIDUP (LIFECYCLE)
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _ticker = createTicker(_onTick)..start();
    _loadRateLimit();
    _startAccelerometer();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulseCtrl.dispose();
    _accelSub?.cancel();
    _countdownTimer?.cancel();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LOOP GAME (60fps)
  // ═══════════════════════════════════════════════════════════════

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    _idleTime += dt;

    // ── Fisika pegas ────────────────────────────────────────────
    const spring = 5.5; // makin lembut → ayunan makin lebar
    const damping = 2.8; // redaman lebih kecil → osilasi lebih lama
    // Ayunan pelan saat diam (hanya terlihat ketika energi rendah)
    final idleTarget = (_shakeEnergy < 0.08)
        ? 0.04 * sin(_idleTime * 0.45)
        : 0.0;
    final springForce = -spring * (_treeAngle - idleTarget);
    final dampForce = -damping * _treeAngVelocity;
    _treeAngVelocity += (springForce + dampForce) * dt;
    _treeAngle += _treeAngVelocity * dt;

    // ── Energi berkurang perlahan ────────────────────────────────
    if (_state == _PickState.idle && !_onCooldown && !_isBursting) {
      _shakeEnergy = max(0, _shakeEnergy - _energyDecayRate * dt);
    }

    // ── Memunculkan kelopak ──────────────────────────────────────
    if (_shakeEnergy > 0.08 && _petals.length < 60) {
      _petalSpawnAccum += _shakeEnergy * 6.0 * dt;
      while (_petalSpawnAccum >= 1.0 && _petals.length < 60) {
        _petalSpawnAccum -= 1.0;
        _spawnPetal(isBurst: false);
      }
    }

    // ── Memperbarui posisi kelopak ───────────────────────────────
    _updatePetals(dt);

    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════
  // FISIKA & PARTIKEL
  // ═══════════════════════════════════════════════════════════════

  void _applyShakeImpulse(double xAccel) {
    // Dorongan besar agar pohon terlihat jelas ikut bergoyang saat device digoyang
    _treeAngVelocity += xAccel * 0.032;
    _treeAngVelocity = _treeAngVelocity.clamp(-5.0, 5.0);
  }

  void _spawnPetal({required bool isBurst}) {
    final w = _treeCanvasSize.width;
    final h = _treeCanvasSize.height;

    // Perhitungan skala ini sama dengan yang ada di _BlossomTreePainter.paint
    const naturalTreeH = 185.0;
    final treeScale = ((h * 0.80) / naturalTreeH).clamp(0.8, 2.8);

    // Area bunga dalam koordinat layar:
    // Di koordinat lokal pohon, bunga berada di y ≈ -120 sampai -175 dari pangkal batang.
    // Pangkal batang = bagian bawah kanvas (h). Jadi di koordinat layar:
    //   blossomTop  = h - treeScale * 175
    //   blossomBot  = h - treeScale * 115
    final blossomTop = h - treeScale * 175;
    final blossomBot = h - treeScale * 115;
    final blossomY = blossomTop + _rng.nextDouble() * (blossomBot - blossomTop);
    final blossomX = w / 2 + (_rng.nextDouble() - 0.5) * (treeScale * 145);

    final speed = isBurst
        ? (80 + _rng.nextDouble() * 140)
        : (20 + _rng.nextDouble() * 60);
    final angle =
        -pi / 2 + (_rng.nextDouble() - 0.5) * (isBurst ? pi : pi * 0.5);

    _petals.add(
      _Petal(
        x: blossomX,
        y: blossomY,
        vx: cos(angle) * speed + _latestX * 1.5,
        vy: sin(angle) * speed,
        rotation: _rng.nextDouble() * 2 * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 5,
        color: _petalColors[_rng.nextInt(_petalColors.length)],
        size: isBurst
            ? (8 + _rng.nextDouble() * 8)
            : (6 + _rng.nextDouble() * 7),
        lifetime: isBurst
            ? (2.0 + _rng.nextDouble() * 1.5)
            : (1.5 + _rng.nextDouble() * 1.2),
      ),
    );
  }

  void _updatePetals(double dt) {
    const gravity = 130.0;
    for (final p in _petals) {
      p.age += dt;
      p.x += p.vx * dt;
      p.vy += gravity * dt;
      p.y += p.vy * dt;
      p.vx *= pow(0.985, dt * 60).toDouble(); // hambatan udara
      p.rotation += p.rotationSpeed * dt;
      // Kelopak terbawa angin sesuai kecepatan goyangan pohon
      p.vx += _treeAngVelocity * 8 * dt;
    }
    _petals.removeWhere((p) => p.isDead);
  }

  // ═══════════════════════════════════════════════════════════════
  // AKSELEROMETER
  // ═══════════════════════════════════════════════════════════════

  void _startAccelerometer() {
    _accelSub = accelerometerEventStream().listen((event) {
      if (_state != _PickState.idle) return;
      if (_onCooldown || _isBursting) return;

      _latestX = event.x;

      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // Pohon ikut bergoyang bahkan pada guncangan sedang (ambang 7.0 → responsif)
      if (magnitude > 7.0) {
        _applyShakeImpulse(event.x);
      }

      // Energi hanya bertambah untuk guncangan kuat, dengan jeda (debounce)
      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeEvent) <
            const Duration(milliseconds: 550)) {
          return;
        }
        _lastShakeEvent = now;
        _shakeEnergy = (_shakeEnergy + _energyPerShake).clamp(0.0, 1.0);

        if (_shakeEnergy >= 1.0) {
          _triggerResult();
        }
      }
    }, onError: (_) {});
  }

  // ═══════════════════════════════════════════════════════════════
  // MEMUNCULKAN HASIL
  // ═══════════════════════════════════════════════════════════════

  Future<void> _triggerResult() async {
    if (_isBursting) return;
    _isBursting = true;

    // Ledakan kelopak dalam jumlah banyak
    for (int i = 0; i < 30; i++) {
      _spawnPetal(isBurst: true);
    }
    // Dorongan kuat pada pohon
    _treeAngVelocity += (_rng.nextDouble() - 0.5) * 4;

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // Peluang gacha: ~48% dapat tiket undian, ~52% zonk
    final isWin = _rng.nextDouble() < _ticketWinRate;
    String? wonTicket;
    if (isWin) {
      wonTicket = await GiveawayService().addVoucherFromShake(_uid);
    }

    await _recordShake();
    if (!mounted) return;

    setState(() {
      _state = _PickState.result;
      _isWin = isWin;
      _wonTicket = wonTicket;
      _isSubmittingTicket = false;
      _isTicketSubmitted = false;
      _isBursting = false;
    });
    _resultCtrl.forward(from: 0);
  }

  void _resetToIdle() {
    _resultCtrl.reset();
    _shakeEnergy = 0.0;
    setState(() {
      _state = _PickState.idle;
      _wonTicket = null;
      _isWin = false;
      _isSubmittingTicket = false;
      _isTicketSubmitted = false;
    });
  }

  Future<void> _submitWonTicketDirectly() async {
    if (_wonTicket == null || _isTicketSubmitted || _isSubmittingTicket) return;
    setState(() => _isSubmittingTicket = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email ?? 'user@mirrora.app';
      final name =
          user?.userMetadata?['name'] as String? ??
          user?.userMetadata?['full_name'] as String? ??
          (email.contains('@') ? email.split('@')[0] : 'Peserta');

      await GiveawayService().submitVoucherToCampaign(
        userId: _uid,
        userName: name,
        userEmail: email,
        ticket: _wonTicket!,
      );

      if (!mounted) return;
      setState(() {
        _isTicketSubmitted = true;
        _isSubmittingTicket = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Tiket $_wonTicket berhasil dimasukkan ke Undian!'),
          backgroundColor: MirroraTheme.dustyRose,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingTicket = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: MirroraTheme.charcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BATAS PENGGUNAAN HARIAN (RATE LIMIT)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadRateLimit() async {
    final box = Hive.box('settingsBox');
    final uid = _uid;
    final windowStartMs = box.get(_kWindowStartMs(uid), defaultValue: 0) as int;
    final count = box.get(_kCountInWindow(uid), defaultValue: 0) as int;
    final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
    final elapsed = DateTime.now().difference(windowStart);

    if (elapsed >= _windowDuration) {
      await box.put(
        _kWindowStartMs(uid),
        DateTime.now().millisecondsSinceEpoch,
      );
      await box.put(_kCountInWindow(uid), 0);
      if (mounted) {
        setState(() {
          _usedCount = 0;
          _onCooldown = false;
        });
      }
    } else {
      final onCooldown = count >= _maxShakesPerWindow;
      if (onCooldown) {
        final remaining = windowStart
            .add(_windowDuration)
            .difference(DateTime.now());
        if (mounted) {
          setState(() {
            _usedCount = count;
            _onCooldown = true;
            _cooldownRemaining = remaining;
          });
          _startCountdown(remaining);
        }
      } else {
        if (mounted) {
          setState(() {
            _usedCount = count;
            _onCooldown = false;
          });
        }
      }
    }
  }

  Future<void> _recordShake() async {
    final box = Hive.box('settingsBox');
    final uid = _uid;
    var count = box.get(_kCountInWindow(uid), defaultValue: 0) as int;
    var windowStartMs = box.get(_kWindowStartMs(uid), defaultValue: 0) as int;

    final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
    if (DateTime.now().difference(windowStart) >= _windowDuration) {
      windowStartMs = DateTime.now().millisecondsSinceEpoch;
      count = 0;
      await box.put(_kWindowStartMs(uid), windowStartMs);
    }
    count++;
    await box.put(_kCountInWindow(uid), count);
    setState(() => _usedCount = count);

    if (count >= _maxShakesPerWindow) {
      final remaining = DateTime.fromMillisecondsSinceEpoch(windowStartMs)
          .add(_windowDuration)
          .difference(DateTime.now());
      setState(() {
        _onCooldown = true;
        _cooldownRemaining = remaining;
      });
      _startCountdown(remaining);
    }
  }

  void _startCountdown(Duration initial) {
    _countdownTimer?.cancel();
    setState(() => _cooldownRemaining = initial);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _cooldownRemaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        t.cancel();
        _loadRateLimit();
      } else {
        setState(() => _cooldownRemaining = next);
      }
    });
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h}j ${m}m ${s}d' : '${m}m ${s}d';
  }

  // ═══════════════════════════════════════════════════════════════
  // TAMPILAN (BUILD)
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        title: const Text(
          'Shake to Pick ✨',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      body: SafeArea(
        child: _state == _PickState.result
            ? _buildResultView()
            : _buildIdleView(),
      ),
    );
  }

  // ─── TAMPILAN AWAL (IDLE) ─────────────────────────────────────────────────
  Widget _buildIdleView() {
    final energyPct = (_shakeEnergy * 100).toInt();
    final isShaking = _shakeEnergy > 0.05;

    return Column(
      children: [
        // ── Kanvas pohon: memenuhi sebagian besar layar ──────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Simpan ukuran kanvas yang sebenarnya agar _spawnPetal memakai koordinat yang tepat
              _treeCanvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return Stack(
                children: [
                  // Latar gradasi lembut: pink → blush → krem
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFBEEF3), // pink pucat di atas
                            Color(0xFFF8E4EC), // blush di tengah
                            Color(0xFFFFF9F5), // krem di bawah
                          ],
                          stops: [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Lingkaran dekoratif buram sebagai hiasan latar
                  const Positioned(
                    top: -45,
                    right: -45,
                    child: _AmbientCircle(
                      size: 150,
                      color: Color(0xFFEFB8CC),
                      opacity: 0.20,
                    ),
                  ),
                  const Positioned(
                    top: 55,
                    left: -35,
                    child: _AmbientCircle(
                      size: 95,
                      color: Color(0xFFC98C9C),
                      opacity: 0.08,
                    ),
                  ),
                  const Positioned(
                    bottom: 80,
                    right: -20,
                    child: _AmbientCircle(
                      size: 70,
                      color: Color(0xFFE5AABF),
                      opacity: 0.10,
                    ),
                  ),

                  // Pohon + kelopak (LayoutBuilder sudah memberi ukuran yang benar)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: GestureDetector(
                        onTap: _onCooldown ? null : _onTap,
                        child: CustomPaint(
                          painter: _BlossomTreePainter(
                            treeAngle: _treeAngle,
                            shakeEnergy: _shakeEnergy,
                            petals: _petals,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),

                  // ── Baris atas: pil judul + indikator jatah shake ────────
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _buildTopRow(),
                  ),

                  // ── Bagian bawah: pil petunjuk shake yang berdenyut ──────
                  Positioned(
                    bottom: 18,
                    left: 28,
                    right: 28,
                    child: _buildShakeHint(isShaking),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Panel bawah: bar energi + sisa jatah shake ───────────────────────
        Container(
          decoration: BoxDecoration(
            color: MirroraTheme.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.dustyRose.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEnergyMeter(energyPct),
              const SizedBox(height: 10),
              _onCooldown ? _buildCooldownBanner() : _buildUsageRow(),
            ],
          ),
        ),
      ],
    );
  }

  // Baris atas di atas kanvas pohon: judul + indikator jatah shake
  Widget _buildTopRow() {
    return Row(
      children: [
        // Pil judul
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.dustyRose.withValues(alpha: 0.14),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌸', style: TextStyle(fontSize: 14)),
              SizedBox(width: 5),
              Text(
                'Shake to Pick',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Indikator jumlah shake yang sudah dipakai, berbentuk titik-titik pil
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.dustyRose.withValues(alpha: 0.14),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_maxShakesPerWindow, (i) {
              final used = i < _usedCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: used ? 18 : 10,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: used
                        ? MirroraTheme.dustyRose
                        : MirroraTheme.blushPink,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // Pil petunjuk beranimasi di bagian bawah kanvas pohon
  Widget _buildShakeHint(bool isShaking) {
    if (_onCooldown) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: MirroraTheme.blushPink, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.blushPink.withValues(alpha: 0.55),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pohon sedang beristirahat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  Text(
                    'Buka lagi dalam ${_formatCountdown(_cooldownRemaining)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final t = _pulseCtrl.value;
        final pulse = sin(t * 2 * pi);
        final scl = 1.0 + pulse * (isShaking ? 0.032 : 0.018);
        final glowAlpha = 0.10 + (pulse + 1) / 2 * (isShaking ? 0.30 : 0.14);
        return Center(
          child: Transform.scale(
            scale: scl,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                gradient: isShaking
                    ? const LinearGradient(
                        colors: [Color(0xFFAA7080), Color(0xFFC98C9C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isShaking
                    ? null
                    : MirroraTheme.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isShaking
                      ? Colors.transparent
                      : MirroraTheme.dustyRose.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MirroraTheme.dustyRose.withValues(alpha: glowAlpha),
                    blurRadius: isShaking ? 24 : 14,
                    spreadRadius: isShaking ? 2 : 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isShaking ? '🌸' : '📱',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isShaking
                            ? 'Terus goyangkan! 💪'
                            : 'Goyangkan device-mu!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isShaking
                              ? Colors.white
                              : MirroraTheme.charcoal,
                        ),
                      ),
                      if (!isShaking)
                        const Text(
                          'Butuh ~5 goyangan kuat',
                          style: TextStyle(
                            fontSize: 10,
                            color: MirroraTheme.warmGray,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnergyMeter(int pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🌸 Energi Guncangan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: pct >= 80 ? 15 : 12,
                fontWeight: FontWeight.w800,
                color: pct >= 80
                    ? MirroraTheme.dustyRose
                    : MirroraTheme.warmGray,
              ),
              child: Text(pct >= 100 ? '🎉 PENUH!' : '$pct%'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Latar bar (jalur kosong)
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Isi bar sesuai energi
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 120),
              widthFactor: _shakeEnergy.clamp(0.0, 1.0),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _shakeEnergy > 0.7
                        ? [const Color(0xFFC98C9C), const Color(0xFFE8A0B8)]
                        : [const Color(0xFFD4A0B0), const Color(0xFFC98C9C)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _shakeEnergy > 0.3
                      ? [
                          BoxShadow(
                            color: MirroraTheme.dustyRose.withValues(
                              alpha: _shakeEnergy * 0.5,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            // Garis penanda pembagi bar (tiap kelipatan satu guncangan)
            Row(
              children: List.generate(5, (_) {
                return Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 1.5,
                      height: 14,
                      color: MirroraTheme.white.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _onCooldown
              ? ''
              : _shakeEnergy >= 1.0
              ? 'Mencari tiket undian...'
              : _shakeEnergy > 0.6
              ? 'Hampir! Goyangkan lebih kencang! 💪'
              : _shakeEnergy > 0.2
              ? 'Goyangkan terus sampai penuh!'
              : 'Butuh ~5 goyangan kuat untuk mengguncang tiket',
          style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
        ),
      ],
    );
  }

  Widget _buildUsageRow() {
    final remaining = _maxShakesPerWindow - _usedCount;
    return Row(
      children: [
        const Icon(
          Icons.refresh_rounded,
          size: 14,
          color: MirroraTheme.warmGray,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$remaining kali shake tersisa hari ini · reset tiap 24 jam',
            style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
          ),
        ),
      ],
    );
  }

  Widget _buildCooldownBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MirroraTheme.blushPink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MirroraTheme.dustyRose.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pohon sakura sedang beristirahat',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                Text(
                  'Bisa shake lagi dalam ${_formatCountdown(_cooldownRemaining)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Alternatif jika device tidak bisa digoyang: tiap ketukan menambah sedikit energi
  // (~0.05 per ketukan → butuh sekitar 20 ketukan)
  void _onTap() {
    _shakeEnergy = (_shakeEnergy + 0.05).clamp(0.0, 1.0);
    _treeAngVelocity += (_rng.nextDouble() - 0.5) * 0.5;
    if (_shakeEnergy >= 1.0) _triggerResult();
  }

  // ─── TAMPILAN HASIL ───────────────────────────────────────────────────────
  Widget _buildResultView() {
    return Stack(
      children: [
        // Kelopak masih berjatuhan di latar belakang
        RepaintBoundary(
          child: CustomPaint(
            painter: _BlossomTreePainter(
              treeAngle: _treeAngle,
              shakeEnergy: 0,
              petals: _petals,
            ),
            child: const SizedBox.expand(),
          ),
        ),

        // Kartu hasil
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isWin && _wonTicket != null)
                    _buildWinTicketCard()
                  else
                    _buildZonkCard(),

                  const SizedBox(height: 16),

                  // Tombol aksi
                  if (!_onCooldown)
                    ElevatedButton.icon(
                      onPressed: _resetToIdle,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Shake Lagi (${_maxShakesPerWindow - _usedCount}x tersisa)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MirroraTheme.dustyRose,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: MirroraTheme.dustyRose,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bisa shake lagi dalam ${_formatCountdown(_cooldownRemaining)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      foregroundColor: MirroraTheme.warmGray,
                      side: const BorderSide(color: MirroraTheme.blushPink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Kembali ke Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── KARTU DAPAT TIKET ────────────────────────────────────────────────────
  Widget _buildWinTicketCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC5A880), Color(0xFFE8C97A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MirroraTheme.softGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              '🎉 HORE! DAPAT TIKET UNDIAN!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFC5A880), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.softGold.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bagian atas kartu: ilustrasi tiket
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF9EE), Color(0xFFFFF0D0)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Text('🎟️✨', style: TextStyle(fontSize: 56)),
                    SizedBox(height: 8),
                    Text(
                      '1 Tiket Giveaway Berhasil Diguncang!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B6B38),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Nomor Tiket Kamu:',
                      style: TextStyle(
                        fontSize: 12,
                        color: MirroraTheme.warmGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: MirroraTheme.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC5A880).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _wonTicket!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tiket ini sudah otomatis tersimpan di dompet tiketmu. Masukkan ke undian sekarang untuk melipatgandakan peluang menang!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol untuk langsung memasukkan tiket ke undian
                    if (_isTicketSubmitted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tiket Sudah Masuk ke Undian! ✓',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmittingTicket
                              ? null
                              : _submitWonTicketDirectly,
                          icon: _isSubmittingTicket
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.how_to_reg_rounded, size: 18),
                          label: Text(
                            _isSubmittingTicket
                                ? 'Memasukkan Tiket...'
                                : 'Masukkan Tiket ke Undian Sekarang',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC5A880),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── KARTU ZONK ───────────────────────────────────────────────────────────
  Widget _buildZonkCard() {
    final remaining = _maxShakesPerWindow - _usedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: MirroraTheme.blushPink,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MirroraTheme.dustyRose.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              '🌸 Belum Beruntung Kali Ini',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.dustyRose,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: MirroraTheme.blushPink, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MirroraTheme.dustyRose.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bagian atas kartu zonk
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF5F7), Color(0xFFFBECEF)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Text('🍃❌', style: TextStyle(fontSize: 54)),
                    SizedBox(height: 8),
                    Text(
                      'ZONK! Bunga Sakura Berguguran',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    const Text(
                      'Hanya kelopak sakura yang jatuh dari dahan. Tiket undian belum berhasil kamu goyangkan kali ini!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: MirroraTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MirroraTheme.cream,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: MirroraTheme.dustyRose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              remaining > 0
                                  ? 'Masih ada $remaining kali kesempatan lagi hari ini! Coba goyang lebih bertenaga!'
                                  : 'Kesempatan harianmu sudah habis. Kembali lagi besok untuk berburu tiket!',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: MirroraTheme.warmGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// DIALOG AJAKAN HARIAN
// =========================================================================

class ShakeToPickPromptDialog extends StatelessWidget {
  const ShakeToPickPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: MirroraTheme.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: MirroraTheme.dustyRose.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bagian kepala dialog
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFAA7080),
                    Color(0xFFC98C9C),
                    Color(0xFFEFBEC9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: const Column(
                children: [
                  Text('🌸🎟️', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 10),
                  Text(
                    'Berburu Tiket Undian! ✨',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Guncang pohon sakura dan temukan tiket\nAnniversary Giveaway berhadiah spesial!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFFFFE8EE),
                    ),
                  ),
                ],
              ),
            ),

            // Bagian isi dialog
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: Column(
                children: [
                  _row(
                    Icons.park_rounded,
                    'Guncang Pohon Sakura',
                    'Goyang device-mu kuat-kuat agar tiket jatuh!',
                  ),
                  const SizedBox(height: 10),
                  _row(
                    Icons.confirmation_number_outlined,
                    'Peluang Gacha Berimbang',
                    'Bisa dapat tiket undian atau kelopak zonk 🍃',
                  ),
                  const SizedBox(height: 10),
                  _row(
                    Icons.timer_outlined,
                    'Maksimal 3x per Hari',
                    'Tiap hari ada 3x goyang. Kumpulkan tiket sebanyaknya!',
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShakeToPickScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Mulai Guncang Pohon! 🌸',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Mungkin Nanti',
                      style: TextStyle(
                        color: MirroraTheme.warmGray,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: MirroraTheme.blushPink,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: MirroraTheme.dustyRose),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: MirroraTheme.warmGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// AMBIENT CIRCLE — lingkaran dekoratif untuk latar (bisa dibuat const)
// =========================================================================

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }
}
