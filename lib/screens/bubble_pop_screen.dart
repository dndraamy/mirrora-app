import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/mirrora_theme.dart';

// ============================================================ WARNA & DATA

const _deepPink = Color(0xFFE0457B);
const _hotPink = Color(0xFFFF7BA9);
const _lavender = Color(0xFFB794F6);
const _bubbleTints = [
  Color(0xFFFFB3CF),
  Color(0xFFD7B8FF),
  Color(0xFFB8F0D8),
  Color(0xFFFFD6A5),
  Color(0xFFB5DEFF),
];

/// Data produk dari Makeup API.
class _Product {
  const _Product({required this.name, this.brand, this.imageUrl, this.emoji});

  final String name;
  final String? brand;
  final String? imageUrl;
  final String? emoji;

  factory _Product.fromJson(Map<String, dynamic> json) {
    var url = (json['image_link'] as String?)?.trim();
    if (url != null && url.isEmpty) url = null;
    if (url != null && url.startsWith('//')) url = 'https:$url';
    if (url != null && url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    return _Product(
      name: (json['name'] as String?)?.trim() ?? 'Produk',
      brand: (json['brand'] as String?)?.trim(),
      imageUrl: url,
    );
  }
}

class _Bubble {
  _Bubble({
    required this.product,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.tint,
    required this.phase,
    required this.freq,
  });

  final _Product product;
  final double x;
  double y;
  final double size;
  final double speed;
  final int tint;
  final double phase;
  final double freq;
  double? poppedAt;
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.emoji,
    required this.size,
  }) : maxLife = life;

  double x, y, vx, vy, life;
  final double maxLife;
  final String emoji;
  final double size;
}

class _FloatText {
  _FloatText(this.x, this.y, this.text);

  final double x;
  double y;
  final String text;
  double life = 0.9;
}

enum _GameState { idle, countdown, playing, finished }

// ================================================================== SCREEN

/// Minigame "Bubble Pop Skincare".
/// Sensor: mikrofon (level desibel). Suara tidak direkam.
class BubblePopScreen extends StatefulWidget {
  const BubblePopScreen({super.key});

  @override
  State<BubblePopScreen> createState() => _BubblePopScreenState();
}

class _BubblePopScreenState extends State<BubblePopScreen>
    with TickerProviderStateMixin {
  static const int _durationSec = 30;
  static const int _maxBubbles = 5;
  static const double _popAnimSec = 0.3;
  static const _fallbackEmojis = ['🧴', '☀️', '💧', '🧼', '✨', '🌸'];

  final _random = Random();
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _idleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  Timer? _timer;

  // Produk dari API
  List<_Product> _products = [];
  bool _loadingProducts = true;
  bool _usingFallback = false;

  // State game
  _GameState _state = _GameState.idle;
  int _score = 0;
  int _timeLeft = _durationSec;
  int _countdown = 3;
  int _combo = 0;
  int _highScore = 0;
  bool _newRecord = false;
  double _currentDb = 0;
  double _threshold = 70;
  DateTime _lastPop = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastPopped = '';

  // Animasi
  final List<_Bubble> _bubbles = [];
  final List<_Particle> _particles = [];
  final List<_FloatText> _floatTexts = [];
  Duration _lastTick = Duration.zero;
  double _clock = 0;
  double _spawnIn = 0;
  double _lastPopClock = -10;
  double _areaW = 0;
  double _areaH = 0;

  int get _stars => _score >= 30
      ? 3
      : _score >= 20
          ? 2
          : _score >= 10
              ? 1
              : 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _loadProducts();
  }

  // ---------------------------------------------------------- HIGH SCORE
  void _loadHighScore() {
    try {
      _highScore =
          Hive.box('settingsBox').get('bubbleHighScore', defaultValue: 0) as int;
    } catch (_) {
      _highScore = 0;
    }
  }

  void _saveHighScore() {
    try {
      Hive.box('settingsBox').put('bubbleHighScore', _highScore);
    } catch (_) {}
  }

  // ----------------------------------------------------------------- API
  Future<void> _loadProducts() async {
    const types = [
      'lipstick',
      'foundation',
      'blush',
      'mascara',
      'nail_polish',
      'eyeshadow',
    ];

    final results = await Future.wait(types.map((type) async {
      try {
        final res = await http
            .get(Uri.parse(
              'https://makeup-api.herokuapp.com/api/v1/products.json'
              '?product_type=$type',
            ))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) return <_Product>[];
        final list = (jsonDecode(res.body) as List)..shuffle(_random);
        return list
            .map((e) => _Product.fromJson(e as Map<String, dynamic>))
            .where((p) => p.imageUrl != null)
            .take(6)
            .toList();
      } catch (_) {
        return <_Product>[];
      }
    }));

    final all = results.expand((e) => e).toList()..shuffle(_random);
    if (!mounted) return;
    setState(() {
      _products = all.take(15).toList();
      _usingFallback = _products.isEmpty;
      _loadingProducts = false;
    });
  }

  _Product _randomProduct() {
    if (_products.isEmpty) {
      return _Product(
        name: 'Skincare',
        emoji: _fallbackEmojis[_random.nextInt(_fallbackEmojis.length)],
      );
    }
    return _products[_random.nextInt(_products.length)];
  }

  // ------------------------------------------------------------ GAME LOGIC
  Future<void> _startGame() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showMessage(
        status.isPermanentlyDenied
            ? 'Izin mikrofon ditolak. Aktifkan lewat pengaturan HP.'
            : 'Izin mikrofon dibutuhkan untuk bermain.',
      );
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    setState(() {
      _state = _GameState.countdown;
      _countdown = 3;
      _score = 0;
      _combo = 0;
      _newRecord = false;
      _lastPopped = '';
      _timeLeft = _durationSec;
      _bubbles.clear();
      _particles.clear();
      _floatTexts.clear();
    });

    _startListening();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _beginPlaying();
      }
    });
  }

  void _beginPlaying() {
    setState(() {
      _state = _GameState.playing;
      _clock = 0;
      _spawnIn = 0;
      _lastPopClock = -10;
    });
    _lastTick = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        _finishGame();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _startListening() {
    try {
      _noiseMeter ??= NoiseMeter();
      _noiseSub?.cancel();
      _noiseSub = _noiseMeter!.noise.listen(
        _onNoise,
        onError: (Object e) => _showMessage('Mikrofon tidak bisa dibaca.'),
      );
    } catch (_) {
      _showMessage('Gagal mengakses mikrofon.');
    }
  }

  void _onNoise(NoiseReading reading) {
    if (_state == _GameState.idle || _state == _GameState.finished) return;
    final db = reading.meanDecibel;
    setState(() => _currentDb = db.isFinite ? db : 0);

    if (_state != _GameState.playing) return;
    // Jeda 400 ms supaya satu tepukan tidak memecahkan banyak gelembung.
    final now = DateTime.now();
    if (db >= _threshold && now.difference(_lastPop).inMilliseconds > 400) {
      _lastPop = now;
      _popBubble();
    }
  }

  double _sway(_Bubble b) => sin(_clock * b.freq + b.phase) * 10;

  double _bubbleLeft(_Bubble b, double w) =>
      (b.x * (w - b.size) + _sway(b)).clamp(0.0, max(0.0, w - b.size));

  /// Pecahkan gelembung yang paling atas di layar.
  void _popBubble() {
    _Bubble? target;
    for (final b in _bubbles) {
      if (b.poppedAt != null || b.y < 0) continue;
      if (target == null || b.y < target.y) target = b;
    }
    final chosen = target;
    if (chosen == null) return;

    HapticFeedback.lightImpact();
    final gap = _clock - _lastPopClock;
    _combo = (gap < 1.5 && _combo > 0) ? _combo + 1 : 1;
    _lastPopClock = _clock;
    final points = _combo >= 3 ? 2 : 1;

    final cx = _bubbleLeft(chosen, _areaW) + chosen.size / 2;
    final cy = chosen.y * _areaH + chosen.size / 2;
    _spawnBurst(cx, cy);

    setState(() {
      chosen.poppedAt = _clock;
      _score += points;
      _lastPopped = chosen.product.name;
      _floatTexts.add(_FloatText(cx - 12, cy - 20, '+$points'));
    });
  }

  void _spawnBurst(double cx, double cy) {
    const emojis = ['✨', '💖', '⭐', '💗', '🫧'];
    for (var i = 0; i < 12; i++) {
      final a = _random.nextDouble() * 2 * pi;
      final s = 90 + _random.nextDouble() * 160;
      _particles.add(_Particle(
        x: cx,
        y: cy,
        vx: cos(a) * s,
        vy: sin(a) * s - 80,
        life: 0.7 + _random.nextDouble() * 0.3,
        emoji: emojis[_random.nextInt(emojis.length)],
        size: 12 + _random.nextDouble() * 10,
      ));
    }
  }

  /// Dipanggil tiap frame untuk menggerakkan semua elemen game.
  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _clock += dt;

    _spawnIn -= dt;
    final active = _bubbles.where((b) => b.poppedAt == null).length;
    if (_spawnIn <= 0 && active < _maxBubbles) {
      _bubbles.add(_Bubble(
        product: _randomProduct(),
        x: _random.nextDouble(),
        y: 1.0,
        size: 84 + _random.nextDouble() * 32,
        speed: 0.10 + _random.nextDouble() * 0.10,
        tint: _random.nextInt(_bubbleTints.length),
        phase: _random.nextDouble() * 2 * pi,
        freq: 1.5 + _random.nextDouble() * 1.5,
      ));
      _spawnIn = 0.5 + _random.nextDouble() * 0.7;
    }

    for (final b in _bubbles) {
      b.y -= b.speed * dt;
    }
    _bubbles.removeWhere(
      (b) =>
          b.y < -0.35 ||
          (b.poppedAt != null && _clock - b.poppedAt! > _popAnimSec),
    );

    for (final p in _particles) {
      p.vy += 600 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final f in _floatTexts) {
      f.y -= 60 * dt;
      f.life -= dt;
    }
    _floatTexts.removeWhere((f) => f.life <= 0);

    if (mounted) setState(() {});
  }

  void _finishGame() {
    _timer?.cancel();
    _noiseSub?.cancel();
    _ticker.stop();
    if (!mounted) return;
    setState(() {
      if (_score > _highScore) {
        _highScore = _score;
        _newRecord = _score > 0;
        _saveHighScore();
      }
      _state = _GameState.finished;
      _timeLeft = 0;
      _currentDb = 0;
      _bubbles.clear();
      _particles.clear();
      _floatTexts.clear();
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noiseSub?.cancel();
    _ticker.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD1E3), Color(0xFFEBD8FF), Color(0xFFFFF0F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 10),
                _buildHud(),
                const SizedBox(height: 10),
                Expanded(child: _buildPanel()),
                const SizedBox(height: 12),
                _buildMeter(),
                _buildSensitivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _roundButton(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
        const Expanded(
          child: Center(
            child: _OutlinedText('Bubble Pop', size: 24),
          ),
        ),
        _pill(
          shadow: const Color(0xFFE5B800),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '$_highScore',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _hotPink.withValues(alpha: 0.6), offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: _deepPink),
      ),
    );
  }

  Widget _pill({required Widget child, required Color shadow}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildHud() {
    final urgent = _timeLeft <= 5 && _state == _GameState.playing;
    final ratio = _timeLeft / _durationSec;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _pill(
                shadow: _hotPink,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Text(
                        '$_score',
                        key: ValueKey(_score),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _deepPink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pill(
                shadow: urgent ? Colors.redAccent : _lavender,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: urgent ? Colors.redAccent : _lavender,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_timeLeft}s',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: urgent ? Colors.redAccent : MirroraTheme.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            color: Color.lerp(Colors.redAccent, _hotPink, ratio),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- PANEL
  Widget _buildPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _lavender.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            _buildDecor(),
            switch (_state) {
              _GameState.idle => _buildIdle(),
              _GameState.countdown => _buildCountdown(),
              _GameState.playing => _buildPlayArea(),
              _GameState.finished => _buildFinished(),
            },
          ],
        ),
      ),
    );
  }

  /// Hiasan latar yang berkelip.
  Widget _buildDecor() {
    return AnimatedBuilder(
      animation: _idleCtrl,
      builder: (context, _) {
        final t = _idleCtrl.value;
        Widget deco(String e, Alignment a, double size, double phase) {
          final o = 0.35 + 0.45 * ((t + phase) % 1.0);
          return Align(
            alignment: a,
            child: Opacity(
              opacity: o,
              child: Text(e, style: TextStyle(fontSize: size)),
            ),
          );
        }

        return Stack(
          children: [
            deco('✨', const Alignment(-0.85, -0.85), 22, 0.0),
            deco('☁️', const Alignment(0.8, -0.7), 34, 0.3),
            deco('💗', const Alignment(-0.8, 0.1), 18, 0.6),
            deco('⭐', const Alignment(0.85, 0.35), 20, 0.15),
            deco('✨', const Alignment(0.6, 0.9), 22, 0.75),
            deco('☁️', const Alignment(-0.7, 0.85), 30, 0.45),
          ],
        );
      },
    );
  }

  Widget _buildIdle() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _idleCtrl,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  -12 * Curves.easeInOut.transform(_idleCtrl.value),
                ),
                child: child,
              ),
              child: _mascot(),
            ),
            const SizedBox(height: 14),
            const _OutlinedText('Bubble Pop', size: 34),
            const SizedBox(height: 4),
            const _OutlinedText('Skincare', size: 26, fill: Color(0xFFFFF3B0)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Tepuk tangan atau bersuara keras\nuntuk memecahkan gelembung!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _GameButton(
              label: _loadingProducts ? 'Memuat produk...' : '▶  MULAI',
              onPressed: _loadingProducts ? null : _startGame,
            ),
            if (_usingFallback) ...[
              const SizedBox(height: 10),
              const Text(
                'Produk gagal dimuat, memakai ikon cadangan.',
                style: TextStyle(fontSize: 11, color: MirroraTheme.warmGray),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mascot() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white, _bubbleTints[0].withValues(alpha: 0.8)],
          stops: const [0.3, 1],
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: _hotPink.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(child: Text('🧴', style: TextStyle(fontSize: 56))),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_countdown),
        tween: Tween(begin: 1.7, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: _OutlinedText('$_countdown', size: 110),
      ),
    );
  }

  Widget _buildPlayArea() {
    return LayoutBuilder(
      builder: (context, c) {
        _areaW = c.maxWidth;
        _areaH = c.maxHeight;
        final showCombo = _combo >= 2 && _clock - _lastPopClock < 1.5;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final b in _bubbles) _positionedBubble(b, _areaW, _areaH),
            for (final p in _particles)
              Positioned(
                left: p.x,
                top: p.y,
                child: Opacity(
                  opacity: (p.life / p.maxLife).clamp(0.0, 1.0),
                  child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
                ),
              ),
            for (final f in _floatTexts)
              Positioned(
                left: f.x,
                top: f.y,
                child: Opacity(
                  opacity: (f.life / 0.9).clamp(0.0, 1.0),
                  child: _OutlinedText(f.text, size: 26, fill: const Color(0xFFFFF3B0)),
                ),
              ),
            if (showCombo)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: _OutlinedText(
                    'COMBO x$_combo 🔥',
                    size: 22,
                    fill: const Color(0xFFFFE066),
                  ),
                ),
              ),
            if (_lastPopped.isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Text(
                  'Pecah: $_lastPopped',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positionedBubble(_Bubble b, double w, double h) {
    double scale = 1;
    double opacity = 1;
    if (b.poppedAt != null) {
      final t = ((_clock - b.poppedAt!) / _popAnimSec).clamp(0.0, 1.0);
      scale = 1 + 0.35 * t;
      opacity = 1 - t;
    }
    return Positioned(
      left: _bubbleLeft(b, w),
      top: b.y * h,
      width: b.size,
      height: b.size,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: _bubbleWidget(b)),
      ),
    );
  }

  Widget _bubbleWidget(_Bubble b) {
    final p = b.product;
    final tint = _bubbleTints[b.tint];
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(b.size * 0.18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              colors: [
                Colors.white.withValues(alpha: 0.95),
                tint.withValues(alpha: 0.75),
              ],
              stops: const [0.35, 1],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.7),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: p.imageUrl != null
                ? Image.network(
                    p.imageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                    errorBuilder: (_, __, ___) => _emojiFallback(
                      _fallbackEmojis[p.name.length % _fallbackEmojis.length],
                    ),
                  )
                : _emojiFallback(p.emoji ?? '🧴'),
          ),
        ),
        // Kilau bubble
        Positioned(
          left: b.size * 0.2,
          top: b.size * 0.13,
          child: Transform.rotate(
            angle: -0.6,
            child: Container(
              width: b.size * 0.22,
              height: b.size * 0.1,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emojiFallback(String emoji) =>
      Center(child: Text(emoji, style: const TextStyle(fontSize: 32)));

  Widget _buildFinished() {
    final msg = switch (_stars) {
      3 => 'Luar biasa!',
      2 => 'Keren banget!',
      1 => 'Lumayan!',
      _ => 'Coba lagi yuk!',
    };
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OutlinedText('Waktu Habis!', size: 30),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 3; i++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 400 + i * 250),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Icon(
                      Icons.star_rounded,
                      size: i == 1 ? 78 : 58,
                      color: i < _stars
                          ? const Color(0xFFFFC107)
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _deepPink,
              ),
            ),
            const SizedBox(height: 10),
            _pill(
              shadow: _hotPink,
              child: Text(
                'Skor: $_score',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MirroraTheme.charcoal,
                ),
              ),
            ),
            if (_newRecord) ...[
              const SizedBox(height: 10),
              const _OutlinedText('🏆 Rekor Baru!', size: 20, fill: Color(0xFFFFE066)),
            ],
            const SizedBox(height: 18),
            _GameButton(label: '🔄  MAIN LAGI', onPressed: _startGame),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- METER
  Widget _buildMeter() {
    final progress = (_currentDb / 100).clamp(0.0, 1.0);
    final threshold = (_threshold / 100).clamp(0.0, 1.0);
    final passed = _currentDb >= _threshold;
    return Row(
      children: [
        AnimatedScale(
          scale: 1 + progress * 0.4,
          duration: const Duration(milliseconds: 100),
          child: const Text('🎤', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return SizedBox(
                height: 26,
                child: Stack(
                  children: [
                    Container(
                      height: 16,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Container(
                      width: w * progress,
                      height: 16,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: passed
                              ? const [Color(0xFF7ED957), Color(0xFF4E8F5E)]
                              : const [Color(0xFFFFB3CF), _hotPink],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Positioned(
                      left: w * threshold - 1.5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: MirroraTheme.charcoal.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            '${_currentDb.round()} dB',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: MirroraTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSensitivity() {
    return Row(
      children: [
        Text(
          'Ambang ${_threshold.round()} dB',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MirroraTheme.charcoal,
          ),
        ),
        Expanded(
          child: Slider(
            value: _threshold,
            min: 50,
            max: 90,
            divisions: 40,
            activeColor: _deepPink,
            inactiveColor: Colors.white,
            onChanged: (v) => setState(() => _threshold = v),
          ),
        ),
      ],
    );
  }
}

// ============================================================ WIDGET BANTU

/// Teks bergaya game: isi berwarna dengan garis tepi tebal.
class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    this.size = 28,
    this.fill = Colors.white,
    this.stroke = _deepPink,
  });

  final String text;
  final double size;
  final Color fill;
  final Color stroke;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 5
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: fill,
          ),
        ),
      ],
    );
  }
}

/// Tombol tebal ala game yang "tertekan" saat disentuh.
class _GameButton extends StatefulWidget {
  const _GameButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final top = enabled ? _hotPink : Colors.grey.shade400;
    final shadow = enabled ? _deepPink : Colors.grey.shade600;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 5 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          color: top,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: shadow,
              offset: Offset(0, _pressed ? 1 : 6),
            ),
          ],
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}