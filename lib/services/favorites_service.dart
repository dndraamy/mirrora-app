import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

/// Service terpusat untuk menyimpan & mengelola Produk Favorit pengguna.
/// Tersimpan di memori lokal (Hive) dan terisolasi per akun Supabase.
class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal() {
    _loadFromStorage();
  }

  static const String _boxName = 'settingsBox';
  static const String _keyPrefix = 'mirrora_fav_products_';

  List<CatalogProduct> _favorites = [];
  Set<String> _favoriteIds = {};
  bool _isLoaded = false;

  /// Daftar produk favorit pengguna (terbaru di urutan teratas)
  List<CatalogProduct> get favorites {
    if (!_isLoaded) {
      _loadFromStorage();
    }
    return List.unmodifiable(_favorites);
  }

  /// Jumlah produk favorit
  int get count {
    if (!_isLoaded) {
      _loadFromStorage();
    }
    return _favorites.length;
  }

  /// Mengecek apakah produk tertentu sudah difavoritkan
  bool isFavorite(String productId) {
    if (!_isLoaded) {
      _loadFromStorage();
    }
    return _favoriteIds.contains(productId);
  }

  /// Menghasilkan key unik di Hive berdasarkan ID akun Supabase saat ini
  String _getUserStorageKey() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return '${_keyPrefix}uid_${user.id}';
      }
      if (user?.email != null && user!.email!.isNotEmpty) {
        return '${_keyPrefix}email_${user.email!.toLowerCase().trim()}';
      }
    } catch (_) {}
    return '${_keyPrefix}guest';
  }

  /// Memuat data favorit dari Hive
  void _loadFromStorage() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final key = _getUserStorageKey();
      final dynamic raw = Hive.box(_boxName).get(key);

      if (raw is List) {
        final List<CatalogProduct> loaded = [];
        final Set<String> loadedIds = {};

        for (final item in raw) {
          if (item is Map) {
            try {
              final product = CatalogProduct.fromMap(
                Map<String, dynamic>.from(item),
              );
              loaded.add(product);
              loadedIds.add(product.id);
            } catch (_) {}
          } else if (item is String) {
            try {
              final decoded = json.decode(item) as Map<String, dynamic>;
              final product = CatalogProduct.fromMap(decoded);
              loaded.add(product);
              loadedIds.add(product.id);
            } catch (_) {}
          }
        }

        _favorites = loaded;
        _favoriteIds = loadedIds;
        _isLoaded = true;
      } else {
        _favorites = [];
        _favoriteIds = {};
        _isLoaded = true;
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = [];
      _favoriteIds = {};
      _isLoaded = true;
    }
  }

  /// Muat ulang favorit saat akun berganti atau login/logout
  Future<void> reload() async {
    _loadFromStorage();
    notifyListeners();
  }

  /// Menambah atau menghapus produk dari favorit (toggle)
  /// Mengembalikan `true` jika produk sekarang menjadi favorit, atau `false` jika dihapus
  Future<bool> toggleFavorite(CatalogProduct product) async {
    _loadFromStorage();
    final isFav = _favoriteIds.contains(product.id);

    if (isFav) {
      _favorites.removeWhere((p) => p.id == product.id);
      _favoriteIds.remove(product.id);
    } else {
      _favorites.insert(0, product);
      _favoriteIds.add(product.id);
    }

    await _saveToStorage();
    notifyListeners();
    return !isFav;
  }

  /// Menambahkan produk ke favorit
  Future<void> addFavorite(CatalogProduct product) async {
    _loadFromStorage();
    if (!_favoriteIds.contains(product.id)) {
      _favorites.insert(0, product);
      _favoriteIds.add(product.id);
      await _saveToStorage();
      notifyListeners();
    }
  }

  /// Menghapus produk dari favorit berdasarkan ID
  Future<void> removeFavorite(String productId) async {
    _loadFromStorage();
    if (_favoriteIds.contains(productId)) {
      _favorites.removeWhere((p) => p.id == productId);
      _favoriteIds.remove(productId);
      await _saveToStorage();
      notifyListeners();
    }
  }

  /// Mengosongkan semua favorit untuk user saat ini
  Future<void> clearAll() async {
    _favorites.clear();
    _favoriteIds.clear();
    await _saveToStorage();
    notifyListeners();
  }

  /// Menyimpan daftar produk favorit ke Hive
  Future<void> _saveToStorage() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final key = _getUserStorageKey();
      final serialized = _favorites.map((p) => p.toMap()).toList();
      await Hive.box(_boxName).put(key, serialized);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }
}

