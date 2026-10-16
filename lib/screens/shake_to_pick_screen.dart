import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/beauty_products.dart';
import '../theme/mirrora_theme.dart';

// ─── Hive keys (per-user, prefix dengan user ID) ────────────────────────────
// Menggunakan fungsi agar tiap akun memiliki slot rate-limit sendiri
// di perangkat yang sama.
String _kWindowStartMs(String uid) => 'shake_window_start_ms_$uid';
String _kCountInWindow(String uid)  => 'shake_count_in_window_$uid';

// ─── Rate limit ─────────────────────────────────────────────────────────────
const int _maxShakesPerWindow = 3;
const Duration _windowDuration = Duration(hours: 4);

// ─── Shake parameters ───────────────────────────────────────────────────────
const double _shakeThreshold = 16.0; // m/s² minimum untuk register shake
const double _energyPerShake = 0.145; // energi per shake event (butuh ~7 shake kuat)
const double _energyDecayRate = 0.09; // energi hilang per detik jika tidak shake

// ─── Rare drop ──────────────────────────────────────────────────────────────
const double _rareProbability = 0.08;

// ─── Warna petal ────────────────────────────────────────────────────────────
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
// DATA: PETAL PARTICLE
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

  double get opacity {
    final t = age / lifetime;
    if (t < 0.1) return t / 0.1;
    if (t > 0.65) return 1.0 - (t - 0.65) / 0.35;
    return 1.0;
  }

  bool get isDead => age >= lifetime;
}

// =========================================================================
// PAINTER: POHON SAKURA + PETALS
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

  // Natural height of tree in local coords (trunk base → blossom top)
  static const double _naturalTreeH = 185.0;

  // ── Branch config ─────────────────────────────────────────────────────────
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

    // Scale tree to fill ~80% of canvas height — much more visible
    final treeScale = ((size.height * 0.80) / _naturalTreeH).clamp(0.8, 2.8);

    // ── Draw tree (scaled + rotated around trunk base) ─────────────────────
    canvas.save();
    canvas.translate(cx, base);
    canvas.scale(treeScale);
    canvas.rotate(treeAngle);

    _drawTrunk(canvas);
    _drawBranches(canvas);
    _drawBlossoms(canvas);

    canvas.restore();

    // ── Draw falling petals (absolute canvas coords, not scaled) ───────────
    for (final p in petals) {
      _drawPetal(canvas, p);
    }
  }

  // ── Trunk ─────────────────────────────────────────────────────────────────
  void _drawTrunk(Canvas canvas) {
    final path = Path();
    // Tapered trunk shape (wide at base, narrower at top)
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

    // Bark texture lines
    final barkPaint = Paint()
      ..color = _trunkColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-3, -20), const Offset(-4, -70), barkPaint);
    canvas.drawLine(const Offset(3, -30), const Offset(4, -85), barkPaint);
  }

  // ── Branches ──────────────────────────────────────────────────────────────
  void _drawBranches(Canvas canvas) {
    _branch(canvas, Offset.zero, const Offset(-80, -148), _branchColor, 7.5);
    _branch(canvas, Offset.zero, const Offset(80, -148), _branchColor, 7.5);
    _branch(canvas, const Offset(0, -118), const Offset(0, -158), _branchColor, 6);
    _branch(canvas, const Offset(-30, -100), const Offset(-62, -155), _thinBranchColor, 4.5);
    _branch(canvas, const Offset(30, -100), const Offset(62, -155), _thinBranchColor, 4.5);
    _branch(canvas, const Offset(-50, -120), const Offset(-92, -152), _thinBranchColor, 3);
    _branch(canvas, const Offset(50, -120), const Offset(92, -152), _thinBranchColor, 3);
    _branch(canvas, const Offset(-20, -108), const Offset(-40, -160), _thinBranchColor, 3);
    _branch(canvas, const Offset(20, -108), const Offset(40, -160), _thinBranchColor, 3);
    _branch(canvas, const Offset(0, -118), const Offset(-22, -165), _thinBranchColor, 2.5);
    _branch(canvas, const Offset(0, -118), const Offset(22, -165), _thinBranchColor, 2.5);
  }

  void _branch(Canvas canvas, Offset from, Offset to, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Curved branch using quadratic bezier
    final ctrl = Offset(
      (from.dx + to.dx) / 2 + (to.dy - from.dy) * 0.05,
      (from.dy + to.dy) / 2,
    );
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  // ── Blossom clouds ────────────────────────────────────────────────────────
  void _drawBlossoms(Canvas canvas) {
    // Clusters centered at branch tips + intermediate positions
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
    // Layered circles — pale outer → deeper inner
    final layers = [
      (r * 1.0, _blossomPale.withValues(alpha: 0.6)),
      (r * 0.85, _blossomLight.withValues(alpha: 0.75)),
      (r * 0.68, _blossomMid.withValues(alpha: 0.82)),
      (r * 0.48, _blossomDeep.withValues(alpha: 0.70)),
    ];

    // Offset sub-circles to give a cloud silhouette
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
        // Scale offset by layer factor
        final scaledOff = off * (radius / r);
        canvas.drawCircle(center + scaledOff, radius * 0.62, paint);
      }
      canvas.drawCircle(center, radius * 0.72, paint);
    }

    // Tiny flower dot details on top
    final dotPaint = Paint()..color = _blossomDeep.withValues(alpha: 0.5);
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final dx = cos(angle) * r * 0.55;
      final dy = sin(angle) * r * 0.55;
      canvas.drawCircle(center + Offset(dx, dy), 2.5, dotPaint);
    }
  }

  // ── Falling petal ─────────────────────────────────────────────────────────
  void _drawPetal(Canvas canvas, _Petal p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);

    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;

    // Oval petal shape
    final path = Path();
    final w = p.size * 0.45;
    final h = p.size * 0.9;
    path.moveTo(0, -h);
    path.cubicTo(w, -h * 0.5, w * 0.8, h * 0.3, 0, h);
    path.cubicTo(-w * 0.8, h * 0.3, -w, -h * 0.5, 0, -h);

    canvas.drawPath(path, paint);

    // Center vein
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
// SHAKE TO PICK SCREEN
// =========================================================================

class ShakeToPickScreen extends StatefulWidget {
  const ShakeToPickScreen({super.key});

  @override
  State<ShakeToPickScreen> createState() => _ShakeToPickScreenState();
}

enum _PickState { idle, result }

class _ShakeToPickScreenState extends State<ShakeToPickScreen>
    with TickerProviderStateMixin {
  // ── Supabase user ID (rate limit di-isolasi per akun) ─────────────────────
  String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  // ── Game ticker (60fps loop) ───────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // ── Tree spring physics ───────────────────────────────────────────────────
  double _treeAngle = 0.0;
  double _treeAngVelocity = 0.0;
  double _idleTime = 0.0; // for idle sway sine

  // ── Shake energy ──────────────────────────────────────────────────────────
  /// 0.0 → 1.0 — harus penuh untuk trigger hasil
  double _shakeEnergy = 0.0;
  bool _isBursting = false; // sementara animasi burst saat energy penuh

  // ── Petals ────────────────────────────────────────────────────────────────
  final List<_Petal> _petals = [];
  double _petalSpawnAccum = 0.0;

  // ── Shake debounce ────────────────────────────────────────────────────────
  DateTime _lastShakeEvent = DateTime.fromMillisecondsSinceEpoch(0);
  double _latestX = 0.0; // last X accel reading (for impulse direction)

  // ── Screen state ──────────────────────────────────────────────────────────
  _PickState _state = _PickState.idle;
  BeautyProduct? _pickedProduct;
  bool _isRare = false;

  // ── Rate limit ────────────────────────────────────────────────────────────
  int _usedCount = 0;
  bool _onCooldown = false;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _countdownTimer;

  // ── Sensor ────────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // ── Tree canvas size (updated from LayoutBuilder, used by _spawnPetal) ────
  Size _treeCanvasSize = const Size(400, 380);

  // ── Pulse animation for hint pill ─────────────────────────────────────────
  late final AnimationController _pulseCtrl;

  // ── Result animation ──────────────────────────────────────────────────────
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
  // LIFECYCLE
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
  // GAME LOOP (60fps)
  // ═══════════════════════════════════════════════════════════════

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    _idleTime += dt;

    // ── Spring physics ──────────────────────────────────────────
    const spring = 5.5;   // softer → more swing
    const damping = 2.8;  // less damped → more oscillation
    // Idle gentle sway (more visible at low energy)
    final idleTarget = (_shakeEnergy < 0.08)
        ? 0.04 * sin(_idleTime * 0.45)
        : 0.0;
    final springForce = -spring * (_treeAngle - idleTarget);
    final dampForce = -damping * _treeAngVelocity;
    _treeAngVelocity += (springForce + dampForce) * dt;
    _treeAngle += _treeAngVelocity * dt;

    // ── Energy decay ─────────────────────────────────────────────
    if (_state == _PickState.idle && !_onCooldown && !_isBursting) {
      _shakeEnergy = max(0, _shakeEnergy - _energyDecayRate * dt);
    }

    // ── Petal spawning ───────────────────────────────────────────
    if (_shakeEnergy > 0.08 && _petals.length < 60) {
      _petalSpawnAccum += _shakeEnergy * 6.0 * dt;
      while (_petalSpawnAccum >= 1.0 && _petals.length < 60) {
        _petalSpawnAccum -= 1.0;
        _spawnPetal(isBurst: false);
      }
    }

    // ── Update petals ─────────────────────────────────────────────
    _updatePetals(dt);

    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════
  // PHYSICS & PARTICLES
  // ═══════════════════════════════════════════════════════════════

  void _applyShakeImpulse(double xAccel) {
    // Large impulse — makes tree visibly swing with the shake
    _treeAngVelocity += xAccel * 0.032;
    _treeAngVelocity = _treeAngVelocity.clamp(-5.0, 5.0);
  }

  void _spawnPetal({required bool isBurst}) {
    final w = _treeCanvasSize.width;
    final h = _treeCanvasSize.height;

    // Mirror the scale calculation from _BlossomTreePainter.paint
    const naturalTreeH = 185.0;
    final treeScale = ((h * 0.80) / naturalTreeH).clamp(0.8, 2.8);

    // Blossom zone in screen coords:
    // In local tree coords blossoms sit at y ≈ -120 to -175 from trunk base.
    // Trunk base = canvas bottom (h). So in screen coords:
    //   blossomTop  = h - treeScale * 175
    //   blossomBot  = h - treeScale * 115
    final blossomTop = h - treeScale * 175;
    final blossomBot = h - treeScale * 115;
    final blossomY   = blossomTop + _rng.nextDouble() * (blossomBot - blossomTop);
    final blossomX   = w / 2 + (_rng.nextDouble() - 0.5) * (treeScale * 145);

    final speed = isBurst ? (80 + _rng.nextDouble() * 140) : (20 + _rng.nextDouble() * 60);
    final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * (isBurst ? pi : pi * 0.5);

    _petals.add(
      _Petal(
        x: blossomX,
        y: blossomY,
        vx: cos(angle) * speed + _latestX * 1.5,
        vy: sin(angle) * speed,
        rotation: _rng.nextDouble() * 2 * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 5,
        color: _petalColors[_rng.nextInt(_petalColors.length)],
        size: isBurst ? (8 + _rng.nextDouble() * 8) : (6 + _rng.nextDouble() * 7),
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
      p.vx *= pow(0.985, dt * 60).toDouble(); // air resistance
      p.rotation += p.rotationSpeed * dt;
      // Wind drift proportional to tree angle
      p.vx += _treeAngVelocity * 8 * dt;
    }
    _petals.removeWhere((p) => p.isDead);
  }

  // ═══════════════════════════════════════════════════════════════
  // ACCELEROMETER
  // ═══════════════════════════════════════════════════════════════

  void _startAccelerometer() {
    _accelSub = accelerometerEventStream().listen(
      (event) {
        if (_state != _PickState.idle) return;
        if (_onCooldown || _isBursting) return;

        _latestX = event.x;

        final magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        // Apply tree impulse even at moderate shakes (threshold 7.0 → responsive)
        if (magnitude > 7.0) {
          _applyShakeImpulse(event.x);
        }

        // Energy accumulation — only for strong shakes, with debounce
        if (magnitude > _shakeThreshold) {
          final now = DateTime.now();
          if (now.difference(_lastShakeEvent) < const Duration(milliseconds: 550)) {
            return;
          }
          _lastShakeEvent = now;
          _shakeEnergy = (_shakeEnergy + _energyPerShake).clamp(0.0, 1.0);

          if (_shakeEnergy >= 1.0) {
            _triggerResult();
          }
        }
      },
      onError: (_) {},
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TRIGGER RESULT
  // ═══════════════════════════════════════════════════════════════

  Future<void> _triggerResult() async {
    if (_isBursting) return;
    _isBursting = true;

    // Big burst of petals
    for (int i = 0; i < 30; i++) {
      _spawnPetal(isBurst: true);
    }
    // Strong tree shake impulse
    _treeAngVelocity += (_rng.nextDouble() - 0.5) * 4;

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final List<BeautyProduct> pool;
    if (_rng.nextDouble() < _rareProbability) {
      pool = beautyProducts.where((p) => p.isRareDrop).toList();
    } else {
      pool = beautyProducts.where((p) => !p.isRareDrop).toList();
    }
    final product = pool[_rng.nextInt(pool.length)];

    await _recordShake();
    if (!mounted) return;

    setState(() {
      _state = _PickState.result;
      _pickedProduct = product;
      _isRare = product.isRareDrop;
      _isBursting = false;
    });
    _resultCtrl.forward(from: 0);
  }

  void _resetToIdle() {
    _resultCtrl.reset();
    _shakeEnergy = 0.0;
    setState(() {
      _state = _PickState.idle;
      _pickedProduct = null;
      _isRare = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // RATE LIMIT
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadRateLimit() async {
    final box = Hive.box('settingsBox');
    final uid = _uid;
    final windowStartMs = box.get(_kWindowStartMs(uid), defaultValue: 0) as int;
    final count = box.get(_kCountInWindow(uid), defaultValue: 0) as int;
    final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
    final elapsed = DateTime.now().difference(windowStart);

    if (elapsed >= _windowDuration) {
      await box.put(_kWindowStartMs(uid), DateTime.now().millisecondsSinceEpoch);
      await box.put(_kCountInWindow(uid), 0);
      if (mounted) setState(() { _usedCount = 0; _onCooldown = false; });
    } else {
      final onCooldown = count >= _maxShakesPerWindow;
      if (onCooldown) {
        final remaining =
            windowStart.add(_windowDuration).difference(DateTime.now());
        if (mounted) {
          setState(() { _usedCount = count; _onCooldown = true; _cooldownRemaining = remaining; });
          _startCountdown(remaining);
        }
      } else {
        if (mounted) setState(() { _usedCount = count; _onCooldown = false; });
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
      setState(() { _onCooldown = true; _cooldownRemaining = remaining; });
      _startCountdown(remaining);
    }
  }

  void _startCountdown(Duration initial) {
    _countdownTimer?.cancel();
    setState(() => _cooldownRemaining = initial);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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
  // BUILD
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

  // ─── IDLE VIEW ────────────────────────────────────────────────────────────
  Widget _buildIdleView() {
    final energyPct = (_shakeEnergy * 100).toInt();
    final isShaking = _shakeEnergy > 0.05;

    return Column(
      children: [
        // ── Tree canvas: fills most of screen ────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Track real canvas size so _spawnPetal uses correct coordinates
              _treeCanvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  // Gradient background — soft pink→blush→cream
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFBEEF3), // pale pink top
                            Color(0xFFF8E4EC), // blush mid
                            Color(0xFFFFF9F5), // cream bottom
                          ],
                          stops: [0.0, 0.52, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Soft decorative blur circles
                  const Positioned(
                    top: -45, right: -45,
                    child: _AmbientCircle(
                        size: 150, color: Color(0xFFEFB8CC), opacity: 0.20),
                  ),
                  const Positioned(
                    top: 55, left: -35,
                    child: _AmbientCircle(
                        size: 95, color: Color(0xFFC98C9C), opacity: 0.08),
                  ),
                  const Positioned(
                    bottom: 80, right: -20,
                    child: _AmbientCircle(
                        size: 70, color: Color(0xFFE5AABF), opacity: 0.10),
                  ),

                  // Tree + petals (LayoutBuilder already gives us correct size)
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

                  // ── Top row: title pill + session dots ───────────────────
                  Positioned(
                    top: 12, left: 16, right: 16,
                    child: _buildTopRow(),
                  ),

                  // ── Bottom: pulsing shake hint pill ──────────────────────
                  Positioned(
                    bottom: 18, left: 28, right: 28,
                    child: _buildShakeHint(isShaking),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Bottom panel: energy bar + usage ─────────────────────────────────
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

  // Top row overlaid on tree canvas: title + session counter dots
  Widget _buildTopRow() {
    return Row(
      children: [
        // Title pill
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
        // Session counter as pill-shaped dots
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

  // Animated hint pill overlaid at the bottom of the tree canvas
  Widget _buildShakeHint(bool isShaking) {
    if (_onCooldown) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: MirroraTheme.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(30),
            border:
                Border.all(color: MirroraTheme.blushPink, width: 1.5),
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
                        fontSize: 10, color: MirroraTheme.warmGray),
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
      builder: (_, __) {
        final t = _pulseCtrl.value;
        final pulse = sin(t * 2 * pi);
        final scl = 1.0 + pulse * (isShaking ? 0.032 : 0.018);
        final glowAlpha =
            0.10 + (pulse + 1) / 2 * (isShaking ? 0.30 : 0.14);
        return Center(
          child: Transform.scale(
            scale: scl,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
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
                    color:
                        MirroraTheme.dustyRose.withValues(alpha: glowAlpha),
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
                          'Butuh ~7 goyangan kuat',
                          style: TextStyle(
                              fontSize: 10, color: MirroraTheme.warmGray),
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
              child: Text(
                pct >= 100 ? '🎉 PENUH!' : '$pct%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background track
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Fill
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 120),
              widthFactor: _shakeEnergy.clamp(0.0, 1.0),
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _shakeEnergy > 0.7
                        ? [
                            const Color(0xFFC98C9C),
                            const Color(0xFFE8A0B8),
                          ]
                        : [
                            const Color(0xFFD4A0B0),
                            const Color(0xFFC98C9C),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _shakeEnergy > 0.3
                      ? [
                          BoxShadow(
                            color: MirroraTheme.dustyRose
                                .withValues(alpha: _shakeEnergy * 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            // Petal markers
            Row(
              children: List.generate(7, (_) {
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
              ? 'Memilih produk...'
              : _shakeEnergy > 0.6
              ? 'Hampir! Goyangkan lebih kencang! 💪'
              : _shakeEnergy > 0.2
              ? 'Goyangkan terus sampai penuh!'
              : 'Butuh ~7 goyangan kuat untuk membuka produk',
          style: const TextStyle(
            fontSize: 11,
            color: MirroraTheme.warmGray,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageRow() {
    final remaining = _maxShakesPerWindow - _usedCount;
    return Row(
      children: [
        const Icon(Icons.refresh_rounded, size: 14, color: MirroraTheme.warmGray),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$remaining sesi tersisa · reset tiap 4 jam',
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

  // Tap fallback (adds tiny energy, ~0.05 per tap → ~20 taps needed)
  void _onTap() {
    _shakeEnergy = (_shakeEnergy + 0.05).clamp(0.0, 1.0);
    _treeAngVelocity += (_rng.nextDouble() - 0.5) * 0.5;
    if (_shakeEnergy >= 1.0) _triggerResult();
  }

  // ─── RESULT VIEW ──────────────────────────────────────────────────────────
  Widget _buildResultView() {
    final p = _pickedProduct!;
    return Stack(
      children: [
        // Petals still falling in background
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

        // Result card
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: _isRare
                            ? const LinearGradient(
                                colors: [Color(0xFFC5A880), Color(0xFFE8C97A)],
                              )
                            : null,
                        color: _isRare ? null : MirroraTheme.blushPink,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRare
                                    ? MirroraTheme.softGold
                                    : MirroraTheme.dustyRose)
                                .withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _isRare ? '🏅 Lucky Drop! Kamu beruntung!' : '🌸 Beauty Pick Hari Ini',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isRare ? Colors.white : MirroraTheme.dustyRose,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product card
                  Container(
                    decoration: BoxDecoration(
                      color: MirroraTheme.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _isRare
                            ? const Color(0xFFC5A880)
                            : MirroraTheme.blushPink,
                        width: _isRare ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRare
                                  ? MirroraTheme.softGold
                                  : MirroraTheme.dustyRose)
                              .withValues(alpha: 0.20),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Emoji area
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            gradient: _isRare
                                ? const LinearGradient(
                                    colors: [Color(0xFFFFF8EC), Color(0xFFFFF3D0)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFFFF5F7), Color(0xFFF8E8EC)],
                                  ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(27),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              p.emoji,
                              style: const TextStyle(fontSize: 66),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isRare
                                      ? const Color(0xFFFFF3D0)
                                      : MirroraTheme.blushPink,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  p.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isRare
                                        ? MirroraTheme.softGold
                                        : MirroraTheme.dustyRose,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: MirroraTheme.charcoal,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.brand,
                                style: const TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: MirroraTheme.cream,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: MirroraTheme.charcoal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: MirroraTheme.blushPink,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 14,
                                      color: MirroraTheme.dustyRose,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.tip,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: MirroraTheme.warmGray,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  if (!_onCooldown)
                    ElevatedButton.icon(
                      onPressed: _resetToIdle,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Shake Lagi (${_maxShakesPerWindow - _usedCount}x tersisa)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
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
                          const Icon(Icons.timer_outlined, size: 16, color: MirroraTheme.dustyRose),
                          const SizedBox(width: 8),
                          Text(
                            'Shake lagi dalam ${_formatCountdown(_cooldownRemaining)}',
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
}

// =========================================================================
// DAILY PROMPT DIALOG
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
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFAA7080), Color(0xFFC98C9C), Color(0xFFEFBEC9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: const Column(
                children: [
                  Text('🌸📱', style: TextStyle(fontSize: 44)),
                  SizedBox(height: 10),
                  Text(
                    'Shake to Pick!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Guncang pohon sakura dan dapatkan\nrekomendasi beauty hari ini!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFFFE8EE)),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: Column(
                children: [
                  _row(Icons.park_rounded, 'Guncang Pohon Sakura',
                      'Goyang device-mu — kelopak bunga berterbangan!'),
                  const SizedBox(height: 10),
                  _row(Icons.auto_awesome, 'Lucky Drop Spesial',
                      '8% chance dapat produk premium eksklusif 🏅'),
                  const SizedBox(height: 10),
                  _row(Icons.timer_outlined, '3x per 4 Jam',
                      'Terbatas — perlu goyangan ~7 kali yang kuat'),
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
                        'Coba Sekarang! 🎉',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Mungkin Nanti',
                      style: TextStyle(color: MirroraTheme.warmGray, fontSize: 13),
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
              Text(title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  )),
              Text(sub,
                  style: const TextStyle(fontSize: 11, color: MirroraTheme.warmGray)),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// AMBIENT CIRCLE — decorative background blob (const-constructible)
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
