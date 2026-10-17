import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/beauty_api_service.dart';
import '../theme/mirrora_theme.dart';
import 'ai_assistant_screen.dart';

/// Screen Explore: Katalog produk skincare dan makeup
/// Menyajikan produk Brand Lokal (Indonesia) dan Brand Internasional (via API)
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final BeautyApiService _apiService = BeautyApiService();
  final TextEditingController _searchController = TextEditingController();

  ProductOrigin _selectedOrigin = ProductOrigin.all;
  String _selectedCategory = 'Semua';
  ProductSort _selectedSort = ProductSort.popular;
  bool _isGridView = true;

  bool _isLoading = true;
  List<CatalogProduct> _products = [];
  final Set<String> _favoriteProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final results = await _apiService.getProducts(
      origin: _selectedOrigin,
      category: _selectedCategory,
      query: _searchController.text,
      sort: _selectedSort,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _products = results;
      _isLoading = false;
    });
  }

  void _onOriginChanged(ProductOrigin origin) {
    if (_selectedOrigin == origin) return;
    setState(() => _selectedOrigin = origin);
    _loadCatalog();
  }

  void _onCategoryChanged(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    _loadCatalog();
  }

  void _toggleFavorite(String productId) {
    setState(() {
      if (_favoriteProductIds.contains(productId)) {
        _favoriteProductIds.remove(productId);
      } else {
        _favoriteProductIds.add(productId);
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _favoriteProductIds.contains(productId)
              ? '✨ Produk ditambahkan ke Wishlist!'
              : 'Produk dihapus dari Wishlist.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: MirroraTheme.charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: MirroraTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 18),
              const Text(
                'Urutkan Produk',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              ...ProductSort.values.map((sortOption) {
                final isSelected = _selectedSort == sortOption;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    sortOption.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? MirroraTheme.dustyRose : MirroraTheme.charcoal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: MirroraTheme.dustyRose)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedSort = sortOption);
                    _loadCatalog();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showProductDetails(CatalogProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isFav = _favoriteProductIds.contains(product.id);
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
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

                  // Hero Image
                  Hero(
                    tag: 'product_img_${product.id}',
                    child: Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: MirroraTheme.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MirroraTheme.blushPink.withValues(alpha: 0.6)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.spa_rounded, size: 54, color: MirroraTheme.dustyRose),
                                      const SizedBox(height: 8),
                                      Text(
                                        product.brand,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: MirroraTheme.warmGray),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: product.origin == ProductOrigin.local
                                    ? const Color(0xFFEAF5EE)
                                    : const Color(0xFFFFF7EB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: product.origin == ProductOrigin.local
                                      ? const Color(0xFF4E8F5E).withValues(alpha: 0.4)
                                      : MirroraTheme.softGold.withValues(alpha: 0.4),
                                ),
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
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleFavorite(product.id),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: MirroraTheme.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: isFav ? Colors.redAccent : MirroraTheme.charcoal,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Brand & Category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MirroraTheme.blushPink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.brand.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${product.category}',
                        style: const TextStyle(fontSize: 13, color: MirroraTheme.warmGray, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MirroraTheme.charcoal),
                      ),
                      Text(
                        ' (${product.reviewCount})',
                        style: const TextStyle(fontSize: 12, color: MirroraTheme.warmGray),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MirroraTheme.charcoal,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Price
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MirroraTheme.cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MirroraTheme.blushPink),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Harga Estimasi:',
                          style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray),
                        ),
                        const Spacer(),
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Deskripsi
                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 13.5, height: 1.55, color: Color(0xFF4A4543)),
                  ),

                  if (product.benefits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Manfaat Utama',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    ...product.benefits.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4, right: 8),
                                child: Icon(Icons.check_circle_rounded, size: 15, color: MirroraTheme.dustyRose),
                              ),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(fontSize: 13, height: 1.4, color: MirroraTheme.charcoal),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  if (product.howToUse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Cara Pakai',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tips_and_updates_rounded, size: 18, color: MirroraTheme.dustyRose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.howToUse,
                              style: const TextStyle(fontSize: 12.5, height: 1.45, color: MirroraTheme.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (product.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: product.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MirroraTheme.cream,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: MirroraTheme.blushPink),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AiAssistantScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.smart_toy_rounded, size: 18),
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
                            _toggleFavorite(product.id);
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: MirroraTheme.white,
                          ),
                          label: Text(
                            isFav ? 'Di Wishlist' : 'Simpan Wishlist',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: MirroraTheme.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MirroraTheme.dustyRose,
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
    return Scaffold(
      backgroundColor: MirroraTheme.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadCatalog(forceRefresh: true),
          color: MirroraTheme.dustyRose,
          backgroundColor: MirroraTheme.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Header Bar & Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explore Beauty ✨',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: MirroraTheme.charcoal,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Katalog Skincare & Makeup Terpilih',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MirroraTheme.warmGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MirroraTheme.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: MirroraTheme.dustyRose.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome, color: MirroraTheme.dustyRose, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: MirroraTheme.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: MirroraTheme.dustyRose.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _loadCatalog(),
                          decoration: InputDecoration(
                            hintText: 'Cari produk, brand (Somethinc, Maybelline...)',
                            hintStyle: const TextStyle(fontSize: 13.5, color: MirroraTheme.warmGray),
                            prefixIcon: const Icon(Icons.search_rounded, color: MirroraTheme.dustyRose, size: 22),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: MirroraTheme.warmGray),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadCatalog();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Origin Filter Toggle (Semua, 🇮🇩 Brand Lokal, 🌍 Internasional)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: MirroraTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MirroraTheme.blushPink),
                    ),
                    child: Row(
                      children: ProductOrigin.values.map((origin) {
                        final isSelected = _selectedOrigin == origin;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _onOriginChanged(origin),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? MirroraTheme.dustyRose : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: MirroraTheme.dustyRose.withValues(alpha: 0.28),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  origin.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? MirroraTheme.white : MirroraTheme.charcoal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // 3. Category Horizontal Pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: BeautyApiService.categories.length,
                      itemBuilder: (context, index) {
                        final cat = BeautyApiService.categories[index];
                        final name = cat['name']!;
                        final icon = cat['icon']!;
                        final isSelected = _selectedCategory == name;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _onCategoryChanged(name),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? MirroraTheme.charcoal : MirroraTheme.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? MirroraTheme.charcoal : MirroraTheme.blushPink,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: MirroraTheme.charcoal.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? MirroraTheme.white : MirroraTheme.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 4. Highlight Banner (Brand Lokal & Internasional)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE89AAB), Color(0xFFC98C9C), Color(0xFFA86678)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: MirroraTheme.dustyRose.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: MirroraTheme.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '✨ Curated Beauty Catalog',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MirroraTheme.white),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Kolaborasi Brand Lokal & Global',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: MirroraTheme.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Temukan rekomendasi Somethinc, Avoskin, Maybelline, hingga The Ordinary!',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFFFECEF), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: MirroraTheme.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('💄', style: TextStyle(fontSize: 26)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Result Bar (Count, Sort & View Mode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'Menampilkan ${_products.length} produk',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MirroraTheme.charcoal,
                        ),
                      ),
                      const Spacer(),
                      // Sort Button
                      InkWell(
                        onTap: _showSortBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: MirroraTheme.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MirroraTheme.blushPink),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 16, color: MirroraTheme.dustyRose),
                              const SizedBox(width: 4),
                              Text(
                                _selectedSort.label.split(' ')[0],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MirroraTheme.charcoal,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, size: 18, color: MirroraTheme.warmGray),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // View Mode Toggle (Grid vs List)
                      InkWell(
                        onTap: () => setState(() => _isGridView = !_isGridView),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: MirroraTheme.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: MirroraTheme.blushPink),
                          ),
                          child: Icon(
                            _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                            size: 16,
                            color: MirroraTheme.dustyRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Products Grid / List / Shimmer Loading / Empty State
              if (_isLoading)
                _buildLoadingShimmer()
              else if (_products.isEmpty)
                _buildEmptyState()
              else if (_isGridView)
                _buildProductGrid()
              else
                _buildProductList(),

              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shimmer / Skeleton Loading State
  Widget _buildLoadingShimmer() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: MirroraTheme.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MirroraTheme.blushPink),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: MirroraTheme.cream,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 10, color: MirroraTheme.blushPink),
                          const SizedBox(height: 8),
                          Container(width: double.infinity, height: 12, color: MirroraTheme.cream),
                          const SizedBox(height: 6),
                          Container(width: 80, height: 12, color: MirroraTheme.cream),
                          const Spacer(),
                          Container(width: 70, height: 14, color: MirroraTheme.blushPink),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: 6,
        ),
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: MirroraTheme.blushPink,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Produk Tidak Ditemukan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MirroraTheme.charcoal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Coba ubah kata kunci pencarian atau ganti filter kategori / brand di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: MirroraTheme.warmGray, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedOrigin = ProductOrigin.all;
                    _selectedCategory = 'Semua';
                    _selectedSort = ProductSort.popular;
                  });
                  _loadCatalog();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset Filter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MirroraTheme.dustyRose,
                  foregroundColor: MirroraTheme.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Grid Mode (2 columns)
  Widget _buildProductGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.64,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _products[index];
            return _buildGridCard(product);
          },
          childCount: _products.length,
        ),
      ),
    );
  }

  Widget _buildGridCard(CatalogProduct product) {
    final isFav = _favoriteProductIds.contains(product.id);
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        decoration: BoxDecoration(
          color: MirroraTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MirroraTheme.blushPink.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: MirroraTheme.dustyRose.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + Origin Pill + Wishlist Button
            Expanded(
              flex: 11,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Container(
                        color: MirroraTheme.cream,
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.spa_rounded, color: MirroraTheme.dustyRose, size: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Origin Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.origin == ProductOrigin.local
                            ? const Color(0xFFEAF5EE).withValues(alpha: 0.95)
                            : const Color(0xFFFFF7EB).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
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
                  // Favorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MirroraTheme.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : MirroraTheme.charcoal,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand & Rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.brand.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: MirroraTheme.dustyRose,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Name
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: MirroraTheme.charcoal,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Short Description
                    Expanded(
                      child: Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: MirroraTheme.warmGray,
                          height: 1.25,
                        ),
                      ),
                    ),

                    // Price Tag
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MirroraTheme.blushPink.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MirroraTheme.dustyRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List Mode (Horizontal full cards)
  Widget _buildProductList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _products[index];
            final isFav = _favoriteProductIds.contains(product.id);
            return GestureDetector(
              onTap: () => _showProductDetails(product),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MirroraTheme.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MirroraTheme.blushPink),
                  boxShadow: [
                    BoxShadow(
                      color: MirroraTheme.dustyRose.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 90,
                        height: 95,
                        color: MirroraTheme.cream,
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.spa_rounded, color: MirroraTheme.dustyRose, size: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info
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
                                      ? const Color(0xFFEAF5EE)
                                      : const Color(0xFFFFF7EB),
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
                            ],
                          ),
                          const SizedBox(height: 3),
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
                          const SizedBox(height: 3),
                          Text(
                            product.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: MirroraTheme.warmGray),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MirroraTheme.dustyRose,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB800)),
                                  const SizedBox(width: 2),
                                  Text(
                                    product.rating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MirroraTheme.charcoal),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => _toggleFavorite(product.id),
                                    child: Icon(
                                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isFav ? Colors.redAccent : MirroraTheme.charcoal,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _products.length,
        ),
      ),
    );
  }
}
