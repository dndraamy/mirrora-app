import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/store_model.dart';

/// Service untuk mengambil data toko kosmetik terdekat secara langsung (Live API)
/// dari OpenStreetMap menggunakan Overpass API dan Nominatim Search API.
class OsmStoreService {
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const String _userAgent = 'MirroraBeautyApp/1.0 (contact@mirrora.id)';

  /// Mengambil toko kosmetik & skincare di sekitar titik koordinat [latitude], [longitude]
  /// dalam radius [radiusMeters] (default 15 km).
  Future<List<BeautyStore>> fetchNearbyCosmeticStores({
    required double latitude,
    required double longitude,
    double radiusMeters = 15000,
  }) async {
    final List<BeautyStore> results = [];

    // 1. Coba ambil dari Overpass API (paling akurat untuk POI shop=cosmetics/beauty)
    try {
      final overpassStores = await _fetchFromOverpass(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      results.addAll(overpassStores);
    } catch (e) {
      debugPrint('Overpass API error/timeout: $e');
    }

    // 2. Jika Overpass sedikit hasilnya, coba Nominatim Search API sebagai pelengkap
    if (results.length < 5) {
      try {
        final nominatimStores = await _fetchFromNominatim(
          latitude: latitude,
          longitude: longitude,
        );
        for (final store in nominatimStores) {
          // Hindari duplikasi jika toko sudah ada
          final exists = results.any(
            (s) =>
                s.name.toLowerCase() == store.name.toLowerCase() ||
                ((s.latitude - store.latitude).abs() < 0.001 &&
                    (s.longitude - store.longitude).abs() < 0.001),
          );
          if (!exists) {
            results.add(store);
          }
        }
      } catch (e) {
        debugPrint('Nominatim API error/timeout: $e');
      }
    }

    return results;
  }

  /// Query ke Overpass API OpenStreetMap dengan fallback endpoint
  Future<List<BeautyStore>> _fetchFromOverpass({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final query = '''
[out:json][timeout:12];
(
  node["shop"="cosmetics"](around:$radiusMeters,$latitude,$longitude);
  way["shop"="cosmetics"](around:$radiusMeters,$latitude,$longitude);
  node["shop"="beauty"](around:$radiusMeters,$latitude,$longitude);
  way["shop"="beauty"](around:$radiusMeters,$latitude,$longitude);
  node["shop"="chemist"](around:$radiusMeters,$latitude,$longitude);
);
out center 40;
''';

    Exception? lastException;
    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'User-Agent': _userAgent,
                'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final elements = data['elements'] as List<dynamic>? ?? [];
          return _parseOverpassElements(elements);
        } else {
          lastException = Exception('$endpoint status ${response.statusCode}');
        }
      } catch (e) {
        lastException = Exception('$endpoint error: $e');
      }
    }

    throw lastException ?? Exception('Semua Overpass endpoint gagal');
  }

  List<BeautyStore> _parseOverpassElements(List<dynamic> elements) {
    final List<BeautyStore> stores = [];
    for (final el in elements) {
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};

      // Nama toko
      String? name = tags['name'] ?? tags['operator'] ?? tags['brand'];
      if (name == null || name.trim().isEmpty) {
        // Jika tidak ada nama spesifik, beri nama berdasarkan tipe
        if (tags['shop'] == 'cosmetics') {
          name = 'Toko Kosmetik';
        } else {
          continue; // Lewati jika tanpa nama & bukan kosmetik
        }
      }

      // Filter nama yang tidak relevan (misal panti pijat biasa)
      final lowerName = name.toLowerCase();
      if (lowerName == 'massage' || lowerName == 'spa' && !lowerName.contains('beauty')) {
        continue;
      }

      // Koordinat (untuk way gunakan 'center')
      double? lat = el['lat'] != null ? (el['lat'] as num).toDouble() : null;
      double? lon = el['lon'] != null ? (el['lon'] as num).toDouble() : null;

      if (lat == null || lon == null) {
        final center = el['center'] as Map<String, dynamic>?;
        if (center != null) {
          lat = (center['lat'] as num).toDouble();
          lon = (center['lon'] as num).toDouble();
        }
      }

      if (lat == null || lon == null) continue;

      // Alamat
      final street = tags['addr:street'] ?? tags['addr:full'] ?? '';
      final city = tags['addr:city'] ?? tags['addr:subdistrict'] ?? '';
      final address = [street, city].where((s) => s.toString().trim().isNotEmpty).join(', ');

      // Kategori
      String category = 'Kosmetik';
      if (tags['shop'] == 'beauty') category = 'Beauty Store';
      if (tags['shop'] == 'chemist') category = 'Skincare';

      final phone = tags['phone'] ?? tags['contact:phone'];
      final openingHours = tags['opening_hours'];

      final store = BeautyStore(
        id: 'osm_${el['type']}_${el['id']}',
        name: name,
        address: address.isNotEmpty ? address : 'Sekitar lokasi GPS Anda',
        category: category,
        latitude: lat,
        longitude: lon,
        phone: phone,
        openHours: openingHours ?? '09:00 - 21:00',
        rating: 4.6,
        isOpen: true,
        isLocalStore: true,
        storeType: 'Toko Lokal & Grosir',
        city: city.isNotEmpty ? city : 'Sekitar Anda',
        priceLevel: 'Lokal / Terjangkau',
      );

      stores.add(store);
    }

    return stores;
  }

  /// Query cadangan ke Nominatim Search API
  Future<List<BeautyStore>> _fetchFromNominatim({
    required double latitude,
    required double longitude,
  }) async {
    // Kotak pencarian ~15km
    final minLon = longitude - 0.12;
    final maxLon = longitude + 0.12;
    final minLat = latitude - 0.12;
    final maxLat = latitude + 0.12;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=kosmetik&format=json&viewbox=$minLon,$maxLat,$maxLon,$minLat&bounded=1&limit=20',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final list = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    final List<BeautyStore> stores = [];

    for (final item in list) {
      final name = item['name'] ?? item['display_name']?.toString().split(',').first ?? 'Toko Kosmetik';
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      final displayName = item['display_name']?.toString() ?? '';

      if (lat == null || lon == null) continue;

      stores.add(
        BeautyStore(
          id: 'osm_nom_${item['place_id']}',
          name: name.toString(),
          address: displayName,
          category: 'Kosmetik',
          latitude: lat,
          longitude: lon,
          openHours: '09:00 - 21:00',
          rating: 4.6,
          isOpen: true,
          isLocalStore: true,
          storeType: 'Toko Lokal & Grosir',
          city: 'Lokal',
          priceLevel: 'Terjangkau',
        ),
      );
    }

    return stores;
  }
}

