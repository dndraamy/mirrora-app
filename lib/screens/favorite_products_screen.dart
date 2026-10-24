import 'dart:async';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/currency_service.dart';
import '../services/favorites_service.dart';
import '../theme/mirrora_theme.dart';
import 'ai_assistant_screen.dart';

/// Halaman Menampilkan Daftar Produk Favorit yang Disimpan oleh Pengguna
class FavoriteProductsScreen extends StatefulWidget {
  const FavoriteProductsScreen({super.key});

  @override
  State<FavoriteProductsScreen> createState() => _FavoriteProductsScreenState();
}

class _FavoriteProductsScreenState extends State<FavoriteProductsScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final CurrencyService _currencyService = CurrencyService();

  late AppCurrency _currentCurrency;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _currentCurrency = _currencyService.detectUserCurrency();
    _currencyService.addListener(_onCurrencyUpdated);
    _favoritesService.addListener(_onFavoritesUpdated);
  }

  @override
  void dispose() {
    _currencyService.removeListener(_onCurrencyUpdated);
    _favoritesService.removeListener(_onFavoritesUpdated);
    super.dispose();
  }

  void _onCurrencyUpdated() {
    if (mounted) setState(() {});
  }

  void _onFavoritesUpdated() {
    if (mounted) setState(() {});
  }

  void _removeProduct(CatalogProduct product) {
    _favoritesService.removeFavorite(product.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.name} dihapus dari Favorit'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MirroraTheme.charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: MirroraTheme.blushPink,
          onPressed: () {
            _favoritesService.addFavorite(product);
          },
        ),
      ),
    );

    // Paksa tutup tepat setelah 2 detik (menghindari delay accessibility dari sistem Android)
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        messenger.hideCurrentSnackBar();
      }
    });
  }

  void _confirmClearAll() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MirroraTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Kosongkan Favorit?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Semua produk yang telah kamu simpan akan dihapus dari daftar produk favorit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: MirroraTheme.warmGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _favoritesService.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Daftar favorit berhasil dikosongkan.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: MirroraTheme.white,
            ),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
  }

  void _askAiAboutProduct(CatalogProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiAssistantScreen(),
      ),
    );
  }

  void _showProductDetails(CatalogProduct product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            final isFav = _favoritesService.isFavorite(product.id);
            return Container(
              decoration: const BoxDecoration(
                color: MirroraTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Preview
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: MirroraTheme.cream,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.spa_rounded, size: 64, color: MirroraTheme.dustyRose),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand & Origin
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.origin == ProductOrigin.local
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.origin == ProductOrigin.local ? '🇮🇩 Brand Lokal' : '🌍 Internasional',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: product.origin == ProductOrigin.local
                                ? const Color(0xFF2E6F3E)
                                : const Color(0xFFB07D30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.brand.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.dustyRose,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFB800)),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Product Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MirroraTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Text(
                    _currencyService.formatPrice(product.price, _currentCurrency),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.dustyRose,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: MirroraTheme.blushPink),
                  const SizedBox(height: 12),

                  // Description
                  const Text(
                    'Tentang Produk',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 13, height: 1.6, color: MirroraTheme.charcoal),
                  ),
                  const SizedBox(height: 16),

                  // Benefits
                  if (product.benefits.isNotEmpty) ...[
                    const Text(
                      'Manfaat Utama',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    ...product.benefits.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✨ ', style: TextStyle(fontSize: 13)),
                            Expanded(
                              child: Text(
                                b,
                                style: const TextStyle(fontSize: 13, color: MirroraTheme.charcoal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // How to use
                  if (product.howToUse.isNotEmpty) ...[
                    const Text(
                      'Cara Pemakaian',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.howToUse,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: MirroraTheme.warmGray),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _askAiAboutProduct(product);
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          label: const Text('Tanya AI', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MirroraTheme.dustyRose,
                            side: const BorderSide(color: MirroraTheme.dustyRose, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _favoritesService.toggleFavorite(product);
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: MirroraTheme.white,
                          ),
                          label: Text(
                            isFav ? 'Hapus Favorit' : 'Simpan Favorit',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFav ? Colors.redAccent : MirroraTheme.dustyRose,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favoritesService.favorites;

    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      appBar: AppBar(
        backgroundColor: MirroraTheme.cream,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: MirroraTheme.blushPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produk Favorit',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MirroraTheme.charcoal,
                  ),
                ),
                Text(
                  '${favorites.length} produk tersimpan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MirroraTheme.warmGray,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (favorites.isNotEmpty) ...[
            IconButton(
              tooltip: _isGridView ? 'Tampilan List' : 'Tampilan Grid',
              icon: Icon(
                _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                color: MirroraTheme.charcoal,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              tooltip: 'Kosongkan Semua',
              icon: const Icon(Icons.delete_outline_rounded, color: MirroraTheme.charcoal),
              onPressed: _confirmClearAll,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: favorites.isEmpty
            ? _buildEmptyState()
            : _buildProductList(favorites),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: MirroraTheme.blushPink.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 54,
                color: MirroraTheme.dustyRose,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Belum Ada Produk Favorit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MirroraTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Simpan produk skincare dan makeup impianmu dengan menekan ikon hati (❤️) pada katalog produk.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: MirroraTheme.warmGray,
              ),
            ),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text(
                'Jelajahi Katalog Produk',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MirroraTheme.dustyRose,
                foregroundColor: MirroraTheme.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(List<CatalogProduct> favorites) {
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final product = favorites[index];
          return _buildGridCard(product);
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: favorites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = favorites[index];
        return _buildListCard(product);
      },
    );
  }

  Widget _buildGridCard(CatalogProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetails(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with heart button
              Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: MirroraTheme.cream,
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.spa_rounded, color: MirroraTheme.dustyRose, size: 38),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: MirroraTheme.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.origin == ProductOrigin.local ? '🇮🇩 Lokal' : '🌍 Global',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: product.origin == ProductOrigin.local
                              ? const Color(0xFF2E6F3E)
                              : const Color(0xFFB07D30),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _removeProduct(product),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MirroraTheme.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.dustyRose,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MirroraTheme.charcoal,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MirroraTheme.charcoal,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _askAiAboutProduct(product),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: MirroraTheme.blushPink,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currencyService.formatPrice(product.price, _currentCurrency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MirroraTheme.dustyRose,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(CatalogProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: MirroraTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MirroraTheme.blushPink),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetails(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: MirroraTheme.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.spa_rounded, color: MirroraTheme.dustyRose, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            product.brand.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.dustyRose,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.origin == ProductOrigin.local
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.origin == ProductOrigin.local ? '🇮🇩 Lokal' : '🌍 Global',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: product.origin == ProductOrigin.local
                                    ? const Color(0xFF2E6F3E)
                                    : const Color(0xFFB07D30),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyService.formatPrice(product.price, _currentCurrency),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: MirroraTheme.dustyRose,
                        ),
                      ),
                    ],
                  ),
                ),

                // Heart Remove Action
                IconButton(
                  tooltip: 'Hapus dari favorit',
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () => _removeProduct(product),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
