import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/store_model.dart';
import '../services/location_service.dart';
import '../services/osm_store_service.dart';
import '../theme/mirrora_theme.dart';

/// Halaman Pencarian Toko Kosmetik & Skincare Terdekat (Location-Based Service)
/// Mendukung deteksi toko kosmetik lokal (Mutiara, Jelita, CF Beauty, dll.) dan live OpenStreetMap
class NearbyStoresScreen extends StatefulWidget {
  const NearbyStoresScreen({super.key});

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _StoreWithDistance {
  final BeautyStore store;
  final double distanceKm;

  const _StoreWithDistance({
    required this.store,
    required this.distanceKm,
  });
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> {
  final LocationService _locationService = LocationService();
  final OsmStoreService _osmStoreService = OsmStoreService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Koordinat acuan default (Yogyakarta)
  static const LatLng _coordJogja = LatLng(-7.7925, 110.3658);

  LatLng? _userLocation;
  LatLng _activeReferenceLocation = _coordJogja;
  bool _isUsingGps = false;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _isPermissionDeniedForever = false;

  // OpenStreetMap Live State
  bool _isFetchingOsm = false;
  List<BeautyStore> _liveOsmStores = [];

  // Filter & Search states
  String _selectedStoreType = 'Semua'; // 'Semua', 'Lokal', 'Mall'
  String _selectedCategory = 'Semua'; // 'Semua', 'Kosmetik', 'Skincare', 'Beauty Store'
  double? _maxDistanceKm; // null = Semua Jarak, 3.0, 5.0, 10.0, 25.0
  String _selectedSort = 'Terdekat'; // 'Terdekat', 'Rating', 'Lokal Dulu'
  String _searchQuery = '';
  BeautyStore? _selectedStore;
  bool _isMapView = true; // Toggle Mode Peta vs Daftar Penuh

  List<_StoreWithDistance> _sortedStores = [];

  final List<String> _categories = [
    'Semua',
    'Kosmetik',
    'Skincare',
    'Beauty Store',
  ];

  @override
  void initState() {
    super.initState();
    _recalculateDistances();
    _getUserLocation();
    _fetchLiveOsmStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Menghitung ulang jarak toko berdasarkan titik acuan aktif (_activeReferenceLocation)
  /// Menggabungkan toko kurasi lokal dengan toko live yang didapat dari OpenStreetMap
  void _recalculateDistances() {
    final baseStores = BeautyStore.sampleStores();
    final center = _activeReferenceLocation;

    final allStores = List<BeautyStore>.from(baseStores);

    // Gabungkan hasil live dari OpenStreetMap, hindari duplikasi jika toko sudah ada
    for (final liveStore in _liveOsmStores) {
      final isDuplicate = allStores.any((s) {
        final dist = _locationService.calculateDistance(
          s.latitude,
          s.longitude,
          liveStore.latitude,
          liveStore.longitude,
        );
        return dist < 0.12 ||
            s.name.toLowerCase().contains(liveStore.name.toLowerCase()) ||
            liveStore.name.toLowerCase().contains(s.name.toLowerCase());
      });

      if (!isDuplicate) {
        allStores.add(liveStore);
      }
    }

    _sortedStores = allStores.map((store) {
      final dist = _locationService.calculateDistance(
        center.latitude,
        center.longitude,
        store.latitude,
        store.longitude,
      );
      return _StoreWithDistance(store: store, distanceKm: dist);
    }).toList();

    _applySorting();
  }

  /// Mengambil data toko kosmetik langsung dari OpenStreetMap secara live
  Future<void> _fetchLiveOsmStores() async {
    if (_isFetchingOsm) return;
    setState(() => _isFetchingOsm = true);

    try {
      final osmStores = await _osmStoreService.fetchNearbyCosmeticStores(
        latitude: _activeReferenceLocation.latitude,
        longitude: _activeReferenceLocation.longitude,
        radiusMeters: 15000,
      );

      if (!mounted) return;
      setState(() {
        _isFetchingOsm = false;
        _liveOsmStores = osmStores;
        _recalculateDistances();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFetchingOsm = false);
    }
  }

  void _applySorting() {
    if (_selectedSort == 'Rating') {
      _sortedStores.sort((a, b) => b.store.rating.compareTo(a.store.rating));
    } else if (_selectedSort == 'Lokal Dulu') {
      _sortedStores.sort((a, b) {
        if (a.store.isLocalStore && !b.store.isLocalStore) return -1;
        if (!a.store.isLocalStore && b.store.isLocalStore) return 1;
        return a.distanceKm.compareTo(b.distanceKm);
      });
    } else {
      // Default: Urutkan jarak paling dekat
      _sortedStores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _isPermissionDeniedForever = false;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      final userLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _userLocation = userLatLng;
        _activeReferenceLocation = userLatLng;
        _isUsingGps = true;
        _isLoadingLocation = false;
        _recalculateDistances();
      });

      _mapController.move(userLatLng, 14.0);
      _fetchLiveOsmStores();
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      final isPerm = errorMsg.contains('permanen') ||
          errorMsg.contains('pengaturan aplikasi');

      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _isUsingGps = false;
        _locationError = errorMsg;
        _isPermissionDeniedForever = isPerm;
      });

      // Tampilkan notifikasi penjelasan
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'GPS tidak aktif: Menampilkan toko terdekat di Yogyakarta.',
            style: TextStyle(fontSize: 12.5),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: MirroraTheme.charcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Filter hasil toko sesuai kriteria pencarian, jenis toko, jarak, dan kategori
  List<_StoreWithDistance> get _filteredStores {
    return _sortedStores.where((item) {
      // 1. Filter Kategori
      final matchesCategory = _selectedCategory == 'Semua' ||
          item.store.category.toLowerCase() == _selectedCategory.toLowerCase();

      // 2. Filter Jenis Toko (Lokal vs Mall)
      bool matchesType = true;
      if (_selectedStoreType == 'Lokal') {
        matchesType = item.store.isLocalStore;
      } else if (_selectedStoreType == 'Mall') {
        matchesType = !item.store.isLocalStore;
      }

      // 3. Filter Jarak Maksimal
      bool matchesDistance = true;
      if (_maxDistanceKm != null) {
        matchesDistance = item.distanceKm <= _maxDistanceKm!;
      }

      // 4. Pencarian Teks
      final matchesSearch = _searchQuery.isEmpty ||
          item.store.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.store.address.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesType && matchesDistance && matchesSearch;
    }).toList();
  }

  /// Buka petunjuk arah di Google Maps
  Future<void> _openNavigation(BeautyStore store) async {
    // Gunakan posisi GPS pengguna saat ini atau titik referensi aktif
    final originLat = _userLocation?.latitude ?? _activeReferenceLocation.latitude;
    final originLng = _userLocation?.longitude ?? _activeReferenceLocation.longitude;

    // Rute Google Maps dengan titik asal (origin) otomatis terisi dan tujuan akurat
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=${store.latitude},${store.longitude}&travelmode=driving',
    );

    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka Google Maps: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Panggil nomor telepon toko
  Future<void> _callStore(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Fokuskan peta ke toko yang diketuk
  void _focusStore(BeautyStore store) {
    setState(() {
      _selectedStore = store;
      if (!_isMapView) _isMapView = true;
    });

    _mapController.move(
      LatLng(store.latitude, store.longitude),
      16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = _filteredStores;
    final mapCenter = _activeReferenceLocation;

    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Toko Kosmetik Terdekat',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: MirroraTheme.charcoal,
          ),
        ),
        elevation: 0,
        backgroundColor: MirroraTheme.white,
        actions: [
          // Tombol Buka Filter Lengkap
          IconButton(
            tooltip: 'Filter & Urutan',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded, color: MirroraTheme.dustyRose),
                if (_maxDistanceKm != null || _selectedStoreType != 'Semua' || _selectedSort != 'Terdekat')
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
          ),
          // Toggle View (Peta vs List Penuh)
          IconButton(
            tooltip: _isMapView ? 'Mode Daftar' : 'Mode Peta',
            icon: Icon(
              _isMapView ? Icons.view_list_rounded : Icons.map_rounded,
              color: MirroraTheme.dustyRose,
            ),
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          // Refresh GPS
          IconButton(
            tooltip: 'Perbarui Lokasi GPS',
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MirroraTheme.dustyRose,
                    ),
                  )
                : Icon(
                    _isUsingGps ? Icons.my_location_rounded : Icons.location_searching_rounded,
                    color: _isUsingGps ? const Color(0xFF2E6F3E) : MirroraTheme.dustyRose,
                  ),
            onPressed: _isLoadingLocation ? null : _getUserLocation,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Banner GPS jika bermasalah
          if (_locationError != null) _buildLocationWarningBanner(),

          // Search Bar
          _buildSearchBar(),

          // Filter Bar Cepat (Jenis Toko & Jarak)
          _buildQuickFilterBar(),

          // Body: Mode Peta (Split) atau Mode List Penuh
          Expanded(
            child: _isMapView
                ? _buildMapWithCardsView(mapCenter, stores)
                : _buildFullListView(stores),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Banner Peringatan Lokasi
  // ---------------------------------------------------------------------------
  Widget _buildLocationWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF1F0),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _locationError ?? 'GPS belum aktif.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF822A26),
                height: 1.25,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_isPermissionDeniedForever) {
                _locationService.openAppSettings();
              } else {
                _locationService.openLocationSettings();
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isPermissionDeniedForever ? 'Pengaturan' : 'Aktifkan',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: MirroraTheme.dustyRose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Search Bar
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      color: MirroraTheme.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: MirroraTheme.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MirroraTheme.blushPink),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Cari toko...',
            hintStyle: const TextStyle(
              fontSize: 12,
              color: MirroraTheme.warmGray,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: MirroraTheme.dustyRose,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Bar Filter Cepat (Jenis Toko, Jarak & Wilayah)
  // ---------------------------------------------------------------------------
  Widget _buildQuickFilterBar() {
    return Container(
      color: MirroraTheme.white,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Column(
        children: [
          // Baris 1: Filter Jenis Toko (Lokal vs Mall)
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: 'Semua Toko',
                  isSelected: _selectedStoreType == 'Semua',
                  onTap: () => setState(() => _selectedStoreType = 'Semua'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Toko Lokal & Grosir',
                  isSelected: _selectedStoreType == 'Lokal',
                  activeColor: const Color(0xFFC05621),
                  onTap: () => setState(() => _selectedStoreType = 'Lokal'),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Brand Resmi & Mall',
                  isSelected: _selectedStoreType == 'Mall',
                  onTap: () => setState(() => _selectedStoreType = 'Mall'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Baris 2: Filter Jarak Terdekat (< 3km, < 5km, < 10km)
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDistanceChip(label: 'Semua Jarak', distance: null),
                const SizedBox(width: 6),
                _buildDistanceChip(label: '< 3 km', distance: 3.0),
                const SizedBox(width: 6),
                _buildDistanceChip(label: '< 5 km', distance: 5.0),
                const SizedBox(width: 6),
                _buildDistanceChip(label: '< 10 km', distance: 10.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = MirroraTheme.dustyRose,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : MirroraTheme.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : MirroraTheme.blushPink,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : MirroraTheme.charcoal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceChip({required String label, required double? distance}) {
    final isSelected = _maxDistanceKm == distance;
    return GestureDetector(
      onTap: () => setState(() => _maxDistanceKm = distance),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? MirroraTheme.charcoal : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? MirroraTheme.charcoal : MirroraTheme.blushPink,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : MirroraTheme.warmGray,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Mode Peta + Carousel Toko
  // ---------------------------------------------------------------------------
  Widget _buildMapWithCardsView(
    LatLng mapCenter,
    List<_StoreWithDistance> stores,
  ) {
    return Stack(
      children: [
        // 1. FlutterMap (OpenStreetMap)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 14.0,
            minZoom: 5.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mirrora_app',
            ),

            MarkerLayer(
              markers: [
                // Marker Posisi Referensi / Lokasi Pengguna
                Marker(
                  point: _activeReferenceLocation,
                  width: 44,
                  height: 44,
                  child: _buildUserLocationMarker(),
                ),

                // Marker untuk Setiap Toko
                ...stores.map((item) {
                  final store = item.store;
                  final isSelected = _selectedStore?.id == store.id;
                  return Marker(
                    point: LatLng(store.latitude, store.longitude),
                    width: isSelected ? 48 : 38,
                    height: isSelected ? 48 : 38,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedStore = store);
                      },
                      child: _buildStoreMarker(store, isSelected),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // 2. Info Bar Jumlah Toko & Status OpenStreetMap Live
        Positioned(
          top: 10,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 14,
                  color: MirroraTheme.dustyRose,
                ),
                const SizedBox(width: 5),
                Text(
                  '${stores.length} toko ditemukan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Kontrol Zoom, Refresh OSM Live & My Location
        Positioned(
          top: 10,
          right: 14,
          child: Column(
            children: [
              _buildMapControlBtn(
                icon: Icons.add_rounded,
                tooltip: 'Perbesar',
                onTap: () {
                  final cur = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, cur + 1);
                },
              ),
              const SizedBox(height: 6),
              _buildMapControlBtn(
                icon: Icons.remove_rounded,
                tooltip: 'Perkecil',
                onTap: () {
                  final cur = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, cur - 1);
                },
              ),
              const SizedBox(height: 6),
              _buildMapControlBtn(
                icon: _isFetchingOsm ? Icons.hourglass_top_rounded : Icons.sync_rounded,
                tooltip: 'Perbarui OpenStreetMap Live',
                color: const Color(0xFFEAF5EE),
                iconColor: const Color(0xFF2E6F3E),
                onTap: _isFetchingOsm ? () {} : () => _fetchLiveOsmStores(),
              ),
              const SizedBox(height: 6),
              _buildMapControlBtn(
                icon: Icons.gps_fixed_rounded,
                tooltip: 'Pusatkan Lokasi',
                color: MirroraTheme.dustyRose,
                iconColor: Colors.white,
                onTap: () {
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 15.0);
                  } else {
                    _getUserLocation();
                  }
                },
              ),
            ],
          ),
        ),

        // 4. Carousel Toko di Bagian Bawah
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: stores.isEmpty
              ? _buildEmptyState()
              : SizedBox(
                  height: 180,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: stores.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = stores[index];
                      final isSelected = _selectedStore?.id == item.store.id;
                      return SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85,
                        child: _buildStoreCard(
                          item,
                          isSelected: isSelected,
                          onCardTap: () => _focusStore(item.store),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Mode Daftar Penuh (Full List View)
  // ---------------------------------------------------------------------------
  Widget _buildFullListView(List<_StoreWithDistance> stores) {
    if (stores.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = stores[index];
        final isSelected = _selectedStore?.id == item.store.id;
        return _buildStoreCard(
          item,
          isSelected: isSelected,
          onCardTap: () => _focusStore(item.store),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Komponen Marker
  // ---------------------------------------------------------------------------
  Widget _buildUserLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2E6F3E).withValues(alpha: 0.2),
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2E6F3E),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreMarker(BeautyStore store, bool isSelected) {
    // Bedakan warna marker antara toko lokal (amber/orange) dan brand mall (dusty rose)
    final mainColor = store.isLocalStore
        ? const Color(0xFFDD6B20) // Orange/Amber untuk Toko Kosmetik Lokal
        : MirroraTheme.dustyRose; // Dusty Rose untuk Brand Resmi/Mall

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? mainColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : mainColor,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? mainColor : Colors.black).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          store.isLocalStore ? Icons.store_rounded : Icons.storefront_rounded,
          color: isSelected ? Colors.white : mainColor,
          size: isSelected ? 22 : 17,
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = MirroraTheme.charcoal,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Komponen Kartu Toko (Store Card)
  // ---------------------------------------------------------------------------
  Widget _buildStoreCard(
    _StoreWithDistance item, {
    required bool isSelected,
    required VoidCallback onCardTap,
  }) {
    final store = item.store;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? (store.isLocalStore ? const Color(0xFFDD6B20) : MirroraTheme.dustyRose)
                  : MirroraTheme.blushPink,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? (store.isLocalStore ? const Color(0xFFDD6B20) : MirroraTheme.dustyRose)
                        .withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Toko: Badge Jarak + Rating
              Row(
                children: [

                  // Badge Jarak
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.distanceKm <= 3.0
                          ? const Color(0xFFEAF5EE)
                          : const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.distanceKm <= 3.0
                            ? const Color(0xFFC6F6D5)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.near_me_rounded,
                          size: 11,
                          color: item.distanceKm <= 3.0
                              ? const Color(0xFF2E6F3E)
                              : MirroraTheme.warmGray,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          BeautyStore.distanceText(item.distanceKm),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: item.distanceKm <= 3.0
                                ? const Color(0xFF2E6F3E)
                                : MirroraTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rating
                  if (store.rating > 0) ...[
                    const SizedBox(width: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB800),
                        ),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Nama Toko & Alamat
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    store.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: MirroraTheme.warmGray,
                    ),
                  ),
                ],
              ),

              // Footer: Jam Buka + Level Harga + Tombol Rute
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: store.isOpen
                                  ? const Color(0xFF2E6F3E)
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store.isOpen ? (store.openHours ?? 'Buka') : 'Tutup',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: store.isOpen
                                    ? const Color(0xFF2E6F3E)
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          store.city,
                          style: const TextStyle(
                            fontSize: 10,
                            color: MirroraTheme.warmGray,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Telepon
                  if (store.phone != null) ...[
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, size: 17),
                      color: MirroraTheme.dustyRose,
                      tooltip: 'Hubungi Toko',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => _callStore(store.phone!),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Tombol Rute Google Maps
                  ElevatedButton.icon(
                    onPressed: () => _openNavigation(store),
                    icon: const Icon(
                      Icons.directions_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Rute',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: store.isLocalStore
                          ? const Color(0xFFDD6B20)
                          : MirroraTheme.dustyRose,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BottomSheet Filter & Urutan
  // ---------------------------------------------------------------------------
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter & Urutkan Toko',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedStoreType = 'Semua';
                            _selectedCategory = 'Semua';
                            _maxDistanceKm = null;
                            _selectedSort = 'Terdekat';
                            _applySorting();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset', style: TextStyle(color: MirroraTheme.dustyRose)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Urutkan
                  const Text('Urutkan Berdasarkan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildModalChoiceChip('Paling Dekat', 'Terdekat', _selectedSort, (val) {
                        setModalState(() => _selectedSort = val);
                        setState(() {
                          _selectedSort = val;
                          _applySorting();
                        });
                      }),
                      _buildModalChoiceChip('Toko Lokal Dulu', 'Lokal Dulu', _selectedSort, (val) {
                        setModalState(() => _selectedSort = val);
                        setState(() {
                          _selectedSort = val;
                          _applySorting();
                        });
                      }),
                      _buildModalChoiceChip('Rating Tertinggi', 'Rating', _selectedSort, (val) {
                        setModalState(() => _selectedSort = val);
                        setState(() {
                          _selectedSort = val;
                          _applySorting();
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Batas Jarak Maksimal
                  const Text('Batas Jarak', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildModalChoiceChip('Semua Jarak', null, _maxDistanceKm, (val) {
                        setModalState(() => _maxDistanceKm = val);
                        setState(() => _maxDistanceKm = val);
                      }),
                      _buildModalChoiceChip('< 3 km', 3.0, _maxDistanceKm, (val) {
                        setModalState(() => _maxDistanceKm = val);
                        setState(() => _maxDistanceKm = val);
                      }),
                      _buildModalChoiceChip('< 5 km', 5.0, _maxDistanceKm, (val) {
                        setModalState(() => _maxDistanceKm = val);
                        setState(() => _maxDistanceKm = val);
                      }),
                      _buildModalChoiceChip('< 10 km', 10.0, _maxDistanceKm, (val) {
                        setModalState(() => _maxDistanceKm = val);
                        setState(() => _maxDistanceKm = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Kategori Toko
                  const Text('Kategori Toko', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((cat) {
                      return _buildModalChoiceChip(cat, cat, _selectedCategory, (val) {
                        setModalState(() => _selectedCategory = val);
                        setState(() => _selectedCategory = val);
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MirroraTheme.dustyRose,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChoiceChip<T>(
    String label,
    T value,
    T currentValue,
    Function(T) onSelected,
  ) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : MirroraTheme.charcoal,
        ),
      ),
      selected: isSelected,
      selectedColor: MirroraTheme.dustyRose,
      backgroundColor: MirroraTheme.cream,
      side: BorderSide(
        color: isSelected ? MirroraTheme.dustyRose : MirroraTheme.blushPink,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Empty State
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_mall_directory_outlined,
              size: 48,
              color: MirroraTheme.dustyRose,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada toko yang sesuai filter',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba perlebar batas jarak atau pilih "Semua Toko" untuk melihat toko kosmetik lainnya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _maxDistanceKm = null;
                  _selectedStoreType = 'Semua';
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.dustyRose,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset Filter', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
