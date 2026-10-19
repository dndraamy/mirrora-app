import 'package:geolocator/geolocator.dart';

/// Service untuk mengelola lokasi pengguna.
///
/// Menyediakan fungsi untuk mendapatkan posisi saat ini,
/// menghitung jarak, dan mengelola izin lokasi.
class LocationService {
  /// Mendapatkan posisi lokasi pengguna saat ini.
  ///
  /// Akan memeriksa apakah layanan lokasi aktif dan
  /// izin lokasi telah diberikan sebelum mengambil posisi.
  ///
  /// Melempar [Exception] jika layanan lokasi tidak aktif
  /// atau izin lokasi ditolak.
  Future<Position> getCurrentLocation() async {
    // Periksa apakah layanan lokasi aktif
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Layanan lokasi tidak aktif. Silakan aktifkan layanan lokasi di pengaturan perangkat Anda.',
      );
    }

    // Periksa izin lokasi
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Minta izin lokasi jika belum diberikan
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Izin lokasi ditolak. Aplikasi membutuhkan izin lokasi untuk melanjutkan.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak secara permanen. Silakan buka pengaturan aplikasi untuk mengaktifkan izin lokasi.',
      );
    }

    // Ambil posisi saat ini dengan akurasi tinggi
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Menghitung jarak antara dua titik koordinat dalam kilometer.
  ///
  /// [startLat] dan [startLng] adalah koordinat titik awal.
  /// [endLat] dan [endLng] adalah koordinat titik tujuan.
  ///
  /// Mengembalikan jarak dalam satuan kilometer (km).
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Geolocator.distanceBetween mengembalikan jarak dalam meter,
    // sehingga perlu dibagi 1000 untuk mendapatkan kilometer
    final double distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );

    return distanceInMeters / 1000;
  }

  /// Memeriksa apakah izin lokasi telah diberikan.
  ///
  /// Mengembalikan `true` jika izin lokasi telah diberikan
  /// (baik saat aplikasi digunakan maupun selalu aktif).
  Future<bool> checkPermission() async {
    final LocationPermission permission = await Geolocator.checkPermission();

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Membuka pengaturan lokasi perangkat.
  ///
  /// Berguna ketika layanan lokasi tidak aktif dan pengguna
  /// perlu mengaktifkannya melalui pengaturan perangkat.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Membuka pengaturan aplikasi di perangkat.
  ///
  /// Berguna ketika izin lokasi ditolak secara permanen dan
  /// pengguna perlu mengubahnya melalui pengaturan aplikasi.
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
