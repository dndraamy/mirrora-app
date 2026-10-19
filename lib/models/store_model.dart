/// Model data untuk toko kecantikan (beauty store).
///
/// Mendukung toko retail modern (Sociolla, Sephora, dll.) dan toko kosmetik lokal/grosir
/// (Mutiara Cosmetics, Jelita Cosmetics, CF Beauty, Puspa Indah, Toko Mahmod, dll.)
library;

class BeautyStore {
  /// ID unik toko
  final String id;

  /// Nama toko
  final String name;

  /// Alamat lengkap toko
  final String address;

  /// Kategori toko — misalnya 'Kosmetik', 'Skincare', 'Parfum', 'Beauty Store'
  final String category;

  /// Koordinat lintang (latitude)
  final double latitude;

  /// Koordinat bujur (longitude)
  final double longitude;

  /// Nomor telepon toko (opsional)
  final String? phone;

  /// URL gambar/foto toko (opsional)
  final String? imageUrl;

  /// Rating toko (0.0 – 5.0)
  final double rating;

  /// Jam operasional, contoh: '09:00 - 21:00' (opsional)
  final String? openHours;

  /// Status buka/tutup toko
  final bool isOpen;

  /// Menandai apakah ini toko kosmetik lokal / grosir terjangkau (misal: Mutiara, Jelita, CF Beauty)
  final bool isLocalStore;

  /// Jenis toko: 'Toko Lokal & Grosir' atau 'Brand Resmi & Mall'
  final String storeType;

  /// Kota tempat toko berada (misal: 'Yogyakarta', 'Jakarta', 'Bandung', dll.)
  final String city;

  /// Perkiraan level harga (misal: 'Grosir / Terjangkau', 'Standar', 'Premium')
  final String priceLevel;

  /// Membuat instance [BeautyStore].
  const BeautyStore({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.imageUrl,
    this.rating = 0.0,
    this.openHours,
    this.isOpen = true,
    this.isLocalStore = false,
    this.storeType = 'Brand Resmi & Mall',
    this.city = 'Indonesia',
    this.priceLevel = 'Standar',
  });

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------

  /// Memformat jarak dalam satuan yang mudah dibaca.
  ///
  /// Jika [distanceInKm] < 1 km, tampilkan dalam meter (misal '500 m').
  /// Jika >= 1 km, tampilkan dalam kilometer (misal '1.2 km').
  static String distanceText(double distanceInKm) {
    if (distanceInKm < 1.0) {
      final meters = (distanceInKm * 1000).round();
      return '$meters m';
    }
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  // ---------------------------------------------------------------------------
  // Data sampel toko kosmetik & skincare di Indonesia
  // Termasuk toko lokal terkenal (Mutiara, Jelita, CF Beauty di Jogja, Mahmod di Bandung, dll.)
  // ---------------------------------------------------------------------------
  static List<BeautyStore> sampleStores() {
    return const [
      // ═══════════════════════════════════════════════════════════════════════
      // ── YOGYAKARTA (Toko Kosmetik Lokal Favorit & Mall) ───────────────────
      // ═══════════════════════════════════════════════════════════════════════
      BeautyStore(
        id: 'jogja_mutiara_01',
        name: 'Mutiara Kosmetik Pusat (Dr. Sutomo)',
        address: 'Jl. Dr. Sutomo No. 64A, Baciro, Kec. Gondokusuman, Kota Yogyakarta',
        category: 'Kosmetik',
        latitude: -7.7946,
        longitude: 110.3804,
        phone: '(0274) 589712',
        rating: 4.8,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Murah',
      ),
      BeautyStore(
        id: 'jogja_mutiara_02',
        name: 'Mutiara Kosmetik Jakal (Kaliurang KM 5)',
        address: 'Jl. Kaliurang KM 5 No. 23, Caturtunggal, Depok, Sleman',
        category: 'Kosmetik',
        latitude: -7.7601,
        longitude: 110.3806,
        phone: '(0274) 554321',
        rating: 4.8,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Murah',
      ),
      BeautyStore(
        id: 'jogja_mutiara_03',
        name: 'Mutiara Kosmetik Gejayan (Affandi)',
        address: 'Jl. Affandi (Gejayan) No. 43, Caturtunggal, Depok, Sleman',
        category: 'Kosmetik',
        latitude: -7.7695,
        longitude: 110.3887,
        phone: '(0274) 545678',
        rating: 4.8,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Murah',
      ),
      BeautyStore(
        id: 'jogja_mutiara_04',
        name: 'Mutiara Kosmetik Babarsari',
        address: 'Jl. Babarsari No. 7B, Caturtunggal, Depok, Sleman',
        category: 'Kosmetik',
        latitude: -7.7808,
        longitude: 110.4135,
        phone: '(0274) 488921',
        rating: 4.8,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Murah',
      ),
      BeautyStore(
        id: 'jogja_jelita_01',
        name: 'Jelita Cosmetic Jakal (Kaliurang KM 5)',
        address: 'Jl. Kaliurang KM 5, Caturtunggal, Depok, Sleman',
        category: 'Kosmetik',
        latitude: -7.7615,
        longitude: 110.3809,
        phone: '0882-0051-90033',
        rating: 4.7,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Harga Grosir',
      ),
      BeautyStore(
        id: 'jogja_jelita_02',
        name: 'Jelita Cosmetic Taman Siswa',
        address: 'Jl. Taman Siswa No. 151, Wirogunan, Kec. Mergangsan, Kota Yogyakarta',
        category: 'Kosmetik',
        latitude: -7.8130,
        longitude: 110.3752,
        phone: '0877-6763-4393',
        rating: 4.7,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Harga Grosir',
      ),
      BeautyStore(
        id: 'jogja_cfbeauty_01',
        name: 'CF Beauty Babarsari',
        address: 'Ruko Rafflesia Babarsari Square 2, Jl. Babarsari No. 105, Caturtunggal, Sleman',
        category: 'Skincare',
        latitude: -7.7801,
        longitude: 110.4132,
        phone: '0812-2567-8910',
        rating: 4.7,
        openHours: '09:00 - 22:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Terjangkau',
      ),
      BeautyStore(
        id: 'jogja_cfbeauty_02',
        name: 'CF Beauty Gejayan',
        address: 'Jl. Affandi No. 9 CT X/09 (Gejayan), Caturtunggal, Depok, Sleman',
        category: 'Skincare',
        latitude: -7.7715,
        longitude: 110.3888,
        phone: '0813-9876-5432',
        rating: 4.7,
        openHours: '09:00 - 22:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Terjangkau',
      ),
      BeautyStore(
        id: 'jogja_cfbeauty_03',
        name: 'CF Beauty Kusumanegara',
        address: 'Jl. Kusumanegara No. 174, Muja Muju, Kec. Umbulharjo, Kota Yogyakarta',
        category: 'Kosmetik',
        latitude: -7.8035,
        longitude: 110.3920,
        phone: '0819-0123-4567',
        rating: 4.7,
        openHours: '09:00 - 22:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir / Terjangkau',
      ),
      BeautyStore(
        id: 'jogja_puspa_01',
        name: 'Puspa Indah Kosmetik Jakal',
        address: 'Jl. Kaliurang KM 6.5 No. 56, Kentungan, Condongcatur, Sleman',
        category: 'Kosmetik',
        latitude: -7.7512,
        longitude: 110.3855,
        phone: '(0274) 887654',
        rating: 4.6,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Terjangkau',
      ),
      BeautyStore(
        id: 'jogja_chandra_01',
        name: 'Chandra Cosmetics Suryotomo',
        address: 'Jl. Suryotomo No. 19, Ngupasan, Gondomanan, Kota Yogyakarta',
        category: 'Kosmetik',
        latitude: -7.7981,
        longitude: 110.3705,
        phone: '(0274) 512345',
        rating: 4.5,
        openHours: '08:30 - 20:30',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Grosir & Eceran',
      ),
      BeautyStore(
        id: 'jogja_gardena_01',
        name: 'Gardena Cosmetics Urip Sumoharjo',
        address: 'Gardena Dept. Store Lt. 1, Jl. Urip Sumoharjo No. 40, Yogyakarta',
        category: 'Beauty Store',
        latitude: -7.7828,
        longitude: 110.3819,
        phone: '(0274) 514161',
        rating: 4.6,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Yogyakarta',
        priceLevel: 'Lengkap / Promo',
      ),
      BeautyStore(
        id: 'jogja_sociolla_01',
        name: 'Sociolla Store Pakuwon Mall Jogja',
        address: 'Pakuwon Mall Jogja Lt. 1, Jl. Ring Road Utara, Condongcatur, Sleman',
        category: 'Beauty Store',
        latitude: -7.7587,
        longitude: 110.3992,
        phone: '(0274) 6411888',
        rating: 4.7,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Yogyakarta',
        priceLevel: 'Standar / Mall',
      ),
      BeautyStore(
        id: 'jogja_guardian_01',
        name: 'Guardian Plaza Ambarrukmo',
        address: 'Plaza Ambarrukmo LG Floor, Jl. Laksda Adisucipto No. 80, Caturtunggal, Sleman',
        category: 'Skincare',
        latitude: -7.7828,
        longitude: 110.4012,
        phone: '(0274) 4331000',
        rating: 4.4,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Yogyakarta',
        priceLevel: 'Standar / Mall',
      ),
      BeautyStore(
        id: 'jogja_sephora_01',
        name: 'SEPHORA Pakuwon Mall Jogja',
        address: 'Pakuwon Mall Jogja Ground Floor, Jl. Ring Road Utara, Condongcatur, Sleman',
        category: 'Kosmetik',
        latitude: -7.7587,
        longitude: 110.3992,
        phone: '(0274) 2921000',
        rating: 4.8,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Yogyakarta',
        priceLevel: 'Premium',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ── BANDUNG (Toko Kosmetik Lokal & Mall) ──────────────────────────────
      // ═══════════════════════════════════════════════════════════════════════
      BeautyStore(
        id: 'bdg_mahmod_01',
        name: 'Toko Kosmetik Mahmod Bandung',
        address: 'Jl. Pasirkaliki No. 8, Kebon Jeruk, Andir, Kota Bandung',
        category: 'Kosmetik',
        latitude: -6.9125,
        longitude: 107.6015,
        phone: '(022) 4205566',
        rating: 4.8,
        openHours: '09:00 - 20:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Bandung',
        priceLevel: 'Grosir Legendaris',
      ),
      BeautyStore(
        id: 'bdg_ires_01',
        name: 'Toko Kosmetik Ires Buah Batu',
        address: 'Jl. Buah Batu No. 142, Cijagra, Lengkong, Kota Bandung',
        category: 'Kosmetik',
        latitude: -6.9382,
        longitude: 107.6251,
        phone: '(022) 7304567',
        rating: 4.6,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Bandung',
        priceLevel: 'Terjangkau',
      ),
      BeautyStore(
        id: 'bdg_sociolla_01',
        name: 'Sociolla Store Paris Van Java',
        address: 'Paris Van Java Mall Resort Level, Jl. Sukajadi No. 137, Bandung',
        category: 'Beauty Store',
        latitude: -6.8875,
        longitude: 107.5943,
        phone: '(022) 82063000',
        rating: 4.6,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Bandung',
        priceLevel: 'Standar / Mall',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ── JAKARTA (Toko Grosir Lokal & Brand Mall) ──────────────────────────
      // ═══════════════════════════════════════════════════════════════════════
      BeautyStore(
        id: 'jkt_pasarbaru_01',
        name: 'Toko Kosmetik Pasar Baru (Pusat Grosir)',
        address: 'Jl. Pasar Baru No. 68, Pasar Baru, Sawah Besar, Jakarta Pusat',
        category: 'Kosmetik',
        latitude: -6.1662,
        longitude: 106.8335,
        phone: '(021) 3845566',
        rating: 4.7,
        openHours: '09:00 - 19:30',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Jakarta',
        priceLevel: 'Grosir / Eceran',
      ),
      BeautyStore(
        id: 'jkt_sociolla_01',
        name: 'Sociolla Store Grand Indonesia',
        address: 'Grand Indonesia Mall East Mall Lt. 3, Jl. MH Thamrin, Jakarta Pusat',
        category: 'Beauty Store',
        latitude: -6.1952,
        longitude: 106.8211,
        phone: '(021) 23456789',
        rating: 4.7,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Jakarta',
        priceLevel: 'Standar / Mall',
      ),
      BeautyStore(
        id: 'jkt_sephora_01',
        name: 'SEPHORA Plaza Indonesia',
        address: 'Plaza Indonesia Lt. 1, Jl. MH Thamrin No. 28-30, Jakarta Pusat',
        category: 'Kosmetik',
        latitude: -6.1930,
        longitude: 106.8230,
        phone: '(021) 29923000',
        rating: 4.8,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Jakarta',
        priceLevel: 'Premium',
      ),
      BeautyStore(
        id: 'jkt_guardian_01',
        name: 'Guardian Pondok Indah Mall',
        address: 'Pondok Indah Mall 2 Lt. 1, Jl. Metro Pondok Indah, Jakarta Selatan',
        category: 'Skincare',
        latitude: -6.2660,
        longitude: 106.7836,
        phone: '(021) 75920888',
        rating: 4.4,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Jakarta',
        priceLevel: 'Standar',
      ),
      BeautyStore(
        id: 'jkt_watsons_01',
        name: 'Watsons Central Park',
        address: 'Central Park Mall LG Floor, Jl. Letjen S. Parman, Jakarta Barat',
        category: 'Skincare',
        latitude: -6.1764,
        longitude: 106.7906,
        phone: '(021) 56985555',
        rating: 4.3,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Jakarta',
        priceLevel: 'Standar',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ── SURABAYA (Toko Lokal & Mall) ──────────────────────────────────────
      // ═══════════════════════════════════════════════════════════════════════
      BeautyStore(
        id: 'sby_cantik_01',
        name: 'Toko Cantik Kosmetik Surabaya',
        address: 'Jl. Pengampon No. 45, Bongkaran, Pabean Cantian, Surabaya',
        category: 'Kosmetik',
        latitude: -7.2415,
        longitude: 112.7420,
        phone: '(031) 3524567',
        rating: 4.7,
        openHours: '09:00 - 20:30',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Surabaya',
        priceLevel: 'Grosir / Murah',
      ),
      BeautyStore(
        id: 'sby_sephora_01',
        name: 'SEPHORA Tunjungan Plaza 6',
        address: 'Tunjungan Plaza 6 Lt. 1, Jl. Embong Malang, Surabaya',
        category: 'Kosmetik',
        latitude: -7.2619,
        longitude: 112.7381,
        phone: '(031) 5468888',
        rating: 4.7,
        openHours: '10:00 - 22:00',
        isOpen: true,
        isLocalStore: false,
        storeType: 'Brand Resmi & Mall',
        city: 'Surabaya',
        priceLevel: 'Premium',
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ── SEMARANG & SOLO (Toko Lokal Legendaris) ───────────────────────────
      // ═══════════════════════════════════════════════════════════════════════
      BeautyStore(
        id: 'smg_sinar_01',
        name: 'Sinar Terang Kosmetik Semarang',
        address: 'Jl. Kranggan No. 34, Kauman, Semarang Tengah, Kota Semarang',
        category: 'Kosmetik',
        latitude: -6.9754,
        longitude: 110.4265,
        phone: '(024) 3546789',
        rating: 4.7,
        openHours: '09:00 - 20:30',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Semarang',
        priceLevel: 'Grosir / Terjangkau',
      ),
      BeautyStore(
        id: 'solo_candi_01',
        name: 'Candi Kosmetik Solo',
        address: 'Jl. Yos Sudarso No. 88, Jayengan, Serengan, Kota Surakarta',
        category: 'Kosmetik',
        latitude: -7.5750,
        longitude: 110.8245,
        phone: '(0271) 645123',
        rating: 4.7,
        openHours: '09:00 - 21:00',
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: 'Surakarta (Solo)',
        priceLevel: 'Grosir / Terjangkau',
      ),
    ];
  }

  @override
  String toString() =>
      'BeautyStore(id: $id, name: $name, category: $category, isLocalStore: $isLocalStore)';
}
