import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Mata uang yang didukung untuk konversi di katalog Mirrora
enum AppCurrency {
  idr(code: 'IDR', symbol: 'Rp', name: 'Rupiah', flag: '🇮🇩', country: 'Indonesia'),
  usd(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸', country: 'Amerika Serikat'),
  jpy(code: 'JPY', symbol: '¥', name: 'Yen', flag: '🇯🇵', country: 'Jepang'),
  eur(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺', country: 'Uni Eropa'),
  krw(code: 'KRW', symbol: '₩', name: 'Won', flag: '🇰🇷', country: 'Korea Selatan');

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
    required this.country,
  });

  final String code;
  final String symbol;
  final String name;
  final String flag;
  final String country;
}

/// Service untuk menangani nilai tukar mata uang secara real-time & deteksi lokasi user
class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const String _savedCurrencyKey = 'selected_currency_code';
  static const String _cachedRatesKey = 'cached_exchange_rates_to_idr';
  static const String _lastFetchedTimeKey = 'last_rates_fetched_time_ms';

  /// Fallback kurs per 1 unit mata uang asing ke IDR (Rupiah) jika offline
  static const Map<AppCurrency, double> _fallbackRatesToIdr = {
    AppCurrency.idr: 1.0,
    AppCurrency.usd: 16000.0, // 1 USD ≈ Rp 16.000
    AppCurrency.jpy: 114.0,   // 1 JPY ≈ Rp 114
    AppCurrency.eur: 20200.0, // 1 EUR ≈ Rp 20.200
    AppCurrency.krw: 13.6,    // 1 KRW ≈ Rp 13,6
  };

  /// Kurs aktif saat ini (didapat dari API / cache Hive / fallback)
  final Map<AppCurrency, double> _activeRatesToIdr = Map.from(_fallbackRatesToIdr);

  bool _isFetching = false;
  DateTime? _lastUpdated;

  Map<AppCurrency, double> get ratesToIdr => Map.unmodifiable(_activeRatesToIdr);
  DateTime? get lastUpdated => _lastUpdated;
  bool get isFetching => _isFetching;

  /// Inisialisasi service: muat cache lokal lalu fetch kurs terbaru di background
  Future<void> init() async {
    _loadFromCache();
    // Fetch kurs real-time terbaru secara asynchronous di background
    fetchLiveRates();
  }

  /// Memuat kurs tersimpan dari Hive jika ada
  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        final box = Hive.box('settingsBox');
        final cached = box.get(_cachedRatesKey);
        final lastMs = box.get(_lastFetchedTimeKey) as int?;

        if (lastMs != null) {
          _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastMs);
        }

        if (cached is Map) {
          for (final c in AppCurrency.values) {
            final val = cached[c.code];
            if (val != null) {
              final doubleRate = (val as num).toDouble();
              if (doubleRate > 0) {
                _activeRatesToIdr[c] = doubleRate;
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Mengambil data kurs mata uang real-time dari Public Exchange Rate API
  /// (open.er-api.com)
  Future<bool> fetchLiveRates() async {
    if (_isFetching) return false;
    _isFetching = true;

    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;

        if (rates != null && rates.containsKey('IDR')) {
          final usdToIdr = (rates['IDR'] as num).toDouble();
          final usdToEur = (rates['EUR'] as num?)?.toDouble() ?? 1.0;
          final usdToJpy = (rates['JPY'] as num?)?.toDouble() ?? 1.0;
          final usdToKrw = (rates['KRW'] as num?)?.toDouble() ?? 1.0;

          _activeRatesToIdr[AppCurrency.idr] = 1.0;
          _activeRatesToIdr[AppCurrency.usd] = usdToIdr;
          _activeRatesToIdr[AppCurrency.eur] = usdToEur > 0 ? (usdToIdr / usdToEur) : _fallbackRatesToIdr[AppCurrency.eur]!;
          _activeRatesToIdr[AppCurrency.jpy] = usdToJpy > 0 ? (usdToIdr / usdToJpy) : _fallbackRatesToIdr[AppCurrency.jpy]!;
          _activeRatesToIdr[AppCurrency.krw] = usdToKrw > 0 ? (usdToIdr / usdToKrw) : _fallbackRatesToIdr[AppCurrency.krw]!;

          _lastUpdated = DateTime.now();

          // Simpan ke Hive cache agar offline tetap akurat
          if (Hive.isBoxOpen('settingsBox')) {
            final box = Hive.box('settingsBox');
            final cacheMap = <String, double>{};
            _activeRatesToIdr.forEach((k, v) => cacheMap[k.code] = v);
            await box.put(_cachedRatesKey, cacheMap);
            await box.put(_lastFetchedTimeKey, _lastUpdated!.millisecondsSinceEpoch);
          }

          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('CurrencyService live fetch failed: $e. Using cached/fallback rates.');
    } finally {
      _isFetching = false;
    }
    return false;
  }

  /// Mendeteksi mata uang default secara otomatis berdasarkan wilayah/perangkat user
  AppCurrency detectUserCurrency() {
    // 1. Cek apakah user pernah secara manual memilih mata uang di settings/explore
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        final savedCode = Hive.box('settingsBox').get(_savedCurrencyKey) as String?;
        if (savedCode != null) {
          for (final c in AppCurrency.values) {
            if (c.code == savedCode) return c;
          }
        }
      }
    } catch (_) {}

    // 2. Deteksi otomatis berdasarkan zona waktu & locale
    try {
      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inHours;
      final tzName = now.timeZoneName.toLowerCase();

      final locale = PlatformDispatcher.instance.locale;
      final country = locale.countryCode?.toUpperCase() ?? '';
      final language = locale.languageCode.toLowerCase();

      // PRIORITAS UTAMA: Wilayah Indonesia
      final isIndonesianTz = offsetHours == 7 ||
          offsetHours == 8 ||
          offsetHours == 9 ||
          tzName.contains('wib') ||
          tzName.contains('wita') ||
          tzName.contains('wit') ||
          tzName.contains('jakarta') ||
          tzName.contains('se asia') ||
          tzName.contains('ict');

      if (isIndonesianTz || country == 'ID' || language == 'id') {
        return AppCurrency.idr;
      }

      // Deteksi Jepang (JST UTC+9 dan bahasa ja/JP)
      if (country == 'JP' || language == 'ja' || (offsetHours == 9 && tzName.contains('jst'))) {
        return AppCurrency.jpy;
      }

      // Deteksi Korea (KST UTC+9 dan bahasa ko/KR)
      if (country == 'KR' || language == 'ko' || (offsetHours == 9 && tzName.contains('kst'))) {
        return AppCurrency.krw;
      }

      // Deteksi Uni Eropa
      if (['DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'GR'].contains(country)) {
        return AppCurrency.eur;
      }

      // Deteksi Amerika Serikat
      if (country == 'US' && (offsetHours <= -4 && offsetHours >= -11)) {
        return AppCurrency.usd;
      }
    } catch (_) {}

    // Default mutlak aplikasi Mirrora adalah Rupiah (Indonesia)
    return AppCurrency.idr;
  }

  /// Simpan preferensi mata uang yang dipilih user
  Future<void> saveUserCurrency(AppCurrency currency) async {
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        await Hive.box('settingsBox').put(_savedCurrencyKey, currency.code);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Mengonversi nilai dari IDR ke mata uang target
  double convertFromIdr(double amountIdr, AppCurrency target) {
    if (target == AppCurrency.idr) return amountIdr;
    final rate = _activeRatesToIdr[target] ?? _fallbackRatesToIdr[target] ?? 1.0;
    return amountIdr / rate;
  }

  /// Format angka dengan separator yang rapi sesuai konvensi mata uang
  String formatPrice(double amountIdr, AppCurrency currency) {
    final converted = convertFromIdr(amountIdr, currency);

    switch (currency) {
      case AppCurrency.idr:
        final intVal = converted.round();
        return 'Rp ${_formatWithSeparator(intVal, '.')}';

      case AppCurrency.usd:
        return '\$${converted.toStringAsFixed(2)}';

      case AppCurrency.eur:
        return '€${converted.toStringAsFixed(2)}';

      case AppCurrency.jpy:
        final intVal = converted.round();
        return '¥${_formatWithSeparator(intVal, ',')}';

      case AppCurrency.krw:
        final intVal = converted.round();
        return '₩${_formatWithSeparator(intVal, ',')}';
    }
  }

  /// Menghitung kurs nilai tukar antara dua mata uang apa pun (from -> to).
  /// 1 unit [from] = X unit [to].
  double getRate(AppCurrency from, AppCurrency to) {
    if (from == to) return 1.0;
    final fromToIdr = _activeRatesToIdr[from] ?? _fallbackRatesToIdr[from] ?? 1.0;
    final toToIdr = _activeRatesToIdr[to] ?? _fallbackRatesToIdr[to] ?? 1.0;
    return fromToIdr / toToIdr;
  }

  /// Format kurs tukar dua arah yang dinamis antara mata uang asal (base) dan target.
  String getExchangeRateBetween(AppCurrency base, AppCurrency target) {
    if (base == target) {
      return 'Mata uang default wilayahmu (${base.name})';
    }

    // A. Jika salah satunya adalah IDR
    if (base == AppCurrency.idr) {
      final rate = _activeRatesToIdr[target] ?? _fallbackRatesToIdr[target] ?? 1.0;
      final rateStr = _formatWithSeparator(rate.round(), '.');
      final tenThousandVal = (10000.0 / rate);
      final tenThousandStr = tenThousandVal >= 1
          ? tenThousandVal.toStringAsFixed(1)
          : tenThousandVal.toStringAsFixed(2);
      return '1 ${target.code} ≈ Rp $rateStr • Rp 10.000 ≈ ${target.symbol}$tenThousandStr ${target.code}';
    }

    if (target == AppCurrency.idr) {
      final rate = _activeRatesToIdr[base] ?? _fallbackRatesToIdr[base] ?? 1.0;
      final rateStr = _formatWithSeparator(rate.round(), '.');
      final tenThousandVal = (10000.0 / rate);
      final tenThousandStr = tenThousandVal >= 1
          ? tenThousandVal.toStringAsFixed(1)
          : tenThousandVal.toStringAsFixed(2);
      return '1 ${base.code} ≈ Rp $rateStr • Rp 10.000 ≈ ${base.symbol}$tenThousandStr ${base.code}';
    }

    // B. Antar mata uang non-IDR (contoh: USD ke JPY, USD ke EUR, dsb.)
    final rateBaseToTarget = getRate(base, target);
    final rateTargetToBase = getRate(target, base);

    final strBaseToTarget = _formatRatePair(1.0, base, rateBaseToTarget, target);
    final strTargetToBase = _formatRatePair(1.0, target, rateTargetToBase, base);

    return '$strBaseToTarget • $strTargetToBase';
  }

  String _formatRatePair(double unitFrom, AppCurrency from, double rateTo, AppCurrency to) {
    String formattedTo;
    if (rateTo >= 100) {
      formattedTo = _formatWithSeparator(rateTo.round(), to == AppCurrency.idr ? '.' : ',');
    } else if (rateTo >= 1) {
      formattedTo = rateTo.toStringAsFixed(2);
    } else if (rateTo >= 0.01) {
      formattedTo = rateTo.toStringAsFixed(3);
    } else {
      formattedTo = rateTo.toStringAsFixed(4);
    }
    return '${unitFrom.round()} ${from.code} ≈ ${to.symbol}$formattedTo ${to.code}';
  }

  /// Format kurs tukar untuk teks info (cth: "1 USD ≈ Rp 18.000")
  String getExchangeRateInfo(AppCurrency currency) {
    return getExchangeRateBetween(AppCurrency.idr, currency);
  }

  static String _formatWithSeparator(int number, String separator) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(separator);
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}