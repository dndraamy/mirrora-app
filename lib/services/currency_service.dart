import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

/// Service untuk menangani nilai tukar mata uang & deteksi lokasi user
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const String _savedCurrencyKey = 'selected_currency_code';

  /// Kurs per 1 unit mata uang asing ke IDR (Rupiah)
  /// Nilai estimasi kurs pasar riil
  static const Map<AppCurrency, double> ratesToIdr = {
    AppCurrency.idr: 1.0,
    AppCurrency.usd: 16200.0, // 1 USD ≈ Rp 16.200
    AppCurrency.jpy: 108.0,   // 1 JPY ≈ Rp 108
    AppCurrency.eur: 17600.0, // 1 EUR ≈ Rp 17.600
    AppCurrency.krw: 11.8,    // 1 KRW ≈ Rp 11,8
  };

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
      // Seringkali HP di Indonesia diatur sistem bahasanya ke English (United States),
      // sehingga locale.countryCode menjadi 'US'. Namun zona waktu HP tetap WIB/WITA/WIT (+7/+8/+9).
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

      // Deteksi Amerika Serikat:
      // HANYA jika country == 'US' DAN zona waktu benar-benar di benua Amerika (UTC-4 s.d UTC-11).
      // Jangan pernah default ke USD jika zona waktu user berada di Asia/Indonesia (+7/+8/+9).
      if (country == 'US' && (offsetHours <= -4 && offsetHours >= -11)) {
        return AppCurrency.usd;
      }
    } catch (_) {
      // Abaikan error dan gunakan default IDR
    }

    // Default mutlak aplikasi Mirrora adalah Rupiah (Indonesia)
    return AppCurrency.idr;
  }

  /// Simpan preferensi mata uang yang dipilih user
  Future<void> saveUserCurrency(AppCurrency currency) async {
    try {
      if (Hive.isBoxOpen('settingsBox')) {
        await Hive.box('settingsBox').put(_savedCurrencyKey, currency.code);
      }
    } catch (_) {}
  }

  /// Mengonversi nilai dari IDR ke mata uang target
  double convertFromIdr(double amountIdr, AppCurrency target) {
    if (target == AppCurrency.idr) return amountIdr;
    final rate = ratesToIdr[target] ?? 1.0;
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

  /// Format kurs tukar untuk teks info (cth: "1 USD ≈ Rp 16.200")
  String getExchangeRateInfo(AppCurrency currency) {
    if (currency == AppCurrency.idr) return 'Mata uang dasar (Indonesia)';
    final rate = ratesToIdr[currency] ?? 1.0;
    final formattedRate = _formatWithSeparator(rate.round(), '.');
    return '1 ${currency.code} ≈ Rp $formattedRate';
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
