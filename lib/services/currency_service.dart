import 'dart:ui';
import 'package:flutter/foundation.dart';

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
    try {
      final locale = PlatformDispatcher.instance.locale;
      final country = locale.countryCode?.toUpperCase() ?? '';
      final language = locale.languageCode.toLowerCase();

      // Cek berdasarkan negara
      if (country == 'ID' || language == 'id') {
        return AppCurrency.idr;
      } else if (country == 'US') {
        return AppCurrency.usd;
      } else if (country == 'JP' || language == 'ja') {
        return AppCurrency.jpy;
      } else if (country == 'KR' || language == 'ko') {
        return AppCurrency.krw;
      } else if (['DE', 'FR', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'IE', 'FI', 'GR'].contains(country)) {
        return AppCurrency.eur;
      }

      // Deteksi tambahan berdasarkan zona waktu jika country code tidak tersedia
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      if (offsetHours == 7 || offsetHours == 8 || offsetHours == 9) {
        // WIB (GMT+7), WITA (GMT+8), WIT (GMT+9)
        return AppCurrency.idr;
      }
    } catch (_) {
      // Abaikan error dan gunakan default IDR
    }

    return AppCurrency.idr;
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
