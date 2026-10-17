import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

/// Service untuk memuat katalog produk kecantikan (Skincare & Makeup)
/// Mendukung Brand Lokal Indonesia & Brand Internasional melalui integrasi API
class BeautyApiService {
  static final BeautyApiService _instance = BeautyApiService._internal();
  factory BeautyApiService() => _instance;
  BeautyApiService._internal();

  /// Cache produk yang sudah di-fetch agar perpindahan tab/filter instan
  List<CatalogProduct>? _cachedProducts;
  bool _isFetchingApi = false;

  /// Kategori yang tersedia di katalog Explore
  static const List<Map<String, String>> categories = [
    {'name': 'Semua', 'icon': '⭐'},
    {'name': 'Skincare', 'icon': '🧴'},
    {'name': 'Makeup', 'icon': '💄'},
    {'name': 'Serum', 'icon': '💧'},
    {'name': 'Sunscreen', 'icon': '☀️'},
    {'name': 'Lip & Cheek', 'icon': '💋'},
    {'name': 'Face & Base', 'icon': '🌸'},
  ];

  /// Mengambil semua produk dengan filter, origin, pencarian, dan pengurutan
  Future<List<CatalogProduct>> getProducts({
    String? category,
    ProductOrigin origin = ProductOrigin.all,
    String? query,
    ProductSort sort = ProductSort.popular,
    bool forceRefresh = false,
  }) async {
    if (_cachedProducts == null || forceRefresh) {
      await _loadAllProducts(forceRefresh: forceRefresh);
    }

    var list = List<CatalogProduct>.from(_cachedProducts ?? _localProductsFallback);

    // 1. Filter Asal Brand (Lokal vs Internasional)
    if (origin != ProductOrigin.all) {
      list = list.where((p) => p.origin == origin).toList();
    }

    // 2. Filter Kategori
    if (category != null && category.isNotEmpty && category != 'Semua') {
      list = list.where((p) {
        if (category == 'Skincare') {
          return p.category == 'Skincare' || p.category == 'Serum' || p.category == 'Sunscreen';
        } else if (category == 'Makeup') {
          return p.category == 'Makeup' || p.category == 'Lip & Cheek' || p.category == 'Face & Base' || p.category == 'Eye Makeup';
        }
        return p.category.toLowerCase().contains(category.toLowerCase());
      }).toList();
    }

    // 3. Filter Pencarian Teks
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((p) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchBrand = p.brand.toLowerCase().contains(q);
        final matchCategory = p.category.toLowerCase().contains(q);
        final matchTags = p.tags.any((t) => t.toLowerCase().contains(q));
        final matchDesc = p.description.toLowerCase().contains(q);
        return matchName || matchBrand || matchCategory || matchTags || matchDesc;
      }).toList();
    }

    // 4. Pengurutan
    switch (sort) {
      case ProductSort.popular:
        list.sort((a, b) {
          if (a.isBestseller && !b.isBestseller) return -1;
          if (!a.isBestseller && b.isBestseller) return 1;
          return b.reviewCount.compareTo(a.reviewCount);
        });
        break;
      case ProductSort.priceLowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSort.priceHighToLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSort.ratingHigh:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case ProductSort.nameAZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return list;
  }

  /// Memuat kombinasi produk lokal dan API eksternal
  Future<void> _loadAllProducts({bool forceRefresh = false}) async {
    if (_isFetchingApi && !forceRefresh) return;
    _isFetchingApi = true;

    final combined = <CatalogProduct>[];
    // Masukkan koleksi produk lokal terlengkap terlebih dahulu
    combined.addAll(_indonesianLocalProducts);
    // Masukkan koleksi produk global terverifikasi
    combined.addAll(_curatedInternationalProducts);

    // Ambil data live dari Makeup API untuk memperkaya katalog brand luar negeri
    try {
      final apiProducts = await _fetchLiveMakeupApi().timeout(
        const Duration(seconds: 4),
        onTimeout: () => <CatalogProduct>[],
      );
      if (apiProducts.isNotEmpty) {
        // Hindari duplikasi nama
        final existingNames = combined.map((p) => p.name.toLowerCase()).toSet();
        for (final p in apiProducts) {
          if (!existingNames.contains(p.name.toLowerCase())) {
            combined.add(p);
            existingNames.add(p.name.toLowerCase());
          }
        }
      }
    } catch (_) {
      // Jika offline atau API timeout, fallback tetap sangat kaya dan berfungsi normal
    }

    _cachedProducts = combined;
    _isFetchingApi = false;
  }

  /// Request live ke endpoint Makeup API
  Future<List<CatalogProduct>> _fetchLiveMakeupApi() async {
    final results = <CatalogProduct>[];
    final uri = Uri.parse('http://makeup-api.herokuapp.com/api/v1/products.json?brand=maybelline');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        // Ambil produk yang memiliki gambar valid
        for (final item in decoded.take(20)) {
          if (item is Map<String, dynamic>) {
            final img = item['image_link']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';
            if (img.isNotEmpty && name.isNotEmpty) {
              results.add(CatalogProduct.fromMakeupApi(item));
            }
          }
        }
      }
    }
    return results;
  }

  // =========================================================================
  // KOLEKSI BRAND LOKAL INDONESIA (Somethinc, Avoskin, Wardah, Skintific, dll)
  // =========================================================================
  static final List<CatalogProduct> _indonesianLocalProducts = [
    const CatalogProduct(
      id: 'local_somethinc_01',
      name: '5% Niacinamide + Sabi Beet Brightening Serum',
      brand: 'Somethinc',
      category: 'Serum',
      origin: ProductOrigin.local,
      price: 119000,
      imageUrl: 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=600&auto=format&fit=crop&q=80',
      description: 'Serum pencerah kulit dengan 5% Niacinamide dan Sabiwhite untuk memudarkan noda hitam serta memperkuat skin barrier tanpa iritasi.',
      rating: 4.9,
      reviewCount: 1420,
      tags: ['BPOM', 'Halal', 'Niacinamide', 'Brightening', 'Best Seller'],
      benefits: [
        'Mencerahkan wajah secara maksimal dalam 4 minggu',
        'Menyamarkan noda hitam dan hiperpigmentasi',
        'Memperbaiki tekstur kulit yang kasar',
      ],
      howToUse: 'Teteskan 5-10 tetes ke telapak tangan, tepuk perlahan pada wajah yang telah dibersihkan pagi dan malam.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_skintific_01',
      name: '5X Ceramide Barrier Repair Moisture Gel',
      brand: 'Skintific',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 139000,
      imageUrl: 'https://images.unsplash.com/photo-1598440947619-2c35fc9aa908?w=600&auto=format&fit=crop&q=80',
      description: 'Moisturizer viral dengan 5 jenis Ceramide, Hyaluronic Acid, dan Centella Asiatica untuk mengunci kelembapan dan menenangkan kemerahan.',
      rating: 4.9,
      reviewCount: 2310,
      tags: ['BPOM', 'Barrier Repair', 'Sensitive Safe', 'Viral', 'Hydrating'],
      benefits: [
        'Memperbaiki dan memperkuat skin barrier',
        'Menghidrasi kulit hingga lapisan terdalam',
        'Meredakan kemerahan dan breakout dengan sensasi sejuk',
      ],
      howToUse: 'Oleskan secukupnya pada area pipi, dahi, hidung, dan dagu secara merata setiap pagi dan malam.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_avoskin_01',
      name: 'Miraculous Retinol Toner Anti-Aging',
      brand: 'Avoskin',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 199000,
      imageUrl: 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=600&auto=format&fit=crop&q=80',
      description: 'Toner anti-aging dengan kandungan 1% Actosome Retinol, Peptide, dan Niacinamide untuk menyamarkan garis halus dan elastisitas kulit.',
      rating: 4.8,
      reviewCount: 890,
      tags: ['BPOM', 'Halal', 'Anti Aging', 'Retinol', 'Cruelty Free'],
      benefits: [
        'Memicu regenerasi sel kulit baru',
        'Menyamarkan garis halus dan kerutan',
        'Menjaga elastisitas dan kekenyalan kulit wajah',
      ],
      howToUse: 'Gunakan pada malam hari setelah cuci muka. Awali dengan 2-3 kali seminggu untuk adaptasi kulit.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_wardah_01',
      name: 'UV Shield Aqua Fresh Sunscreen Serum SPF 50',
      brand: 'Wardah',
      category: 'Sunscreen',
      origin: ProductOrigin.local,
      price: 59000,
      imageUrl: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&auto=format&fit=crop&q=80',
      description: 'Tabir surya bertekstur cair ringan seperti air dengan Broad Spectrum Protection SPF 50 PA++++ tanpa whitecast dan tidak lengket.',
      rating: 4.8,
      reviewCount: 1650,
      tags: ['BPOM', 'Halal', 'SPF 50+', 'No Whitecast', 'Daily Sunscreen'],
      benefits: [
        'Melindungi dari sinar UVA/UVB dan Blue Light',
        'Formula Aquafresh Technology yang menyegarkan',
        'Bebas alkohol dan non-comedogenic',
      ],
      howToUse: 'Oleskan sebanyak dua ruas jari secara merata ke seluruh wajah dan leher 15 menit sebelum terpapar sinar matahari.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_makeover_01',
      name: 'Powerstay Matte Powder Foundation 24H',
      brand: 'Make Over',
      category: 'Face & Base',
      origin: ProductOrigin.local,
      price: 195000,
      imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&auto=format&fit=crop&q=80',
      description: 'Bedak padat foundation dengan daya tahan hingga 24 jam dengan hasil akhir matte lembut dan oil control luar biasa.',
      rating: 4.9,
      reviewCount: 1120,
      tags: ['BPOM', 'Halal', 'High Coverage', 'Matte Finish', 'Pro Makeup'],
      benefits: [
        'Coverage medium hingga full yang buildable',
        'Menyerap minyak berlebih seharian tanpa cakey',
        'Pori-pori tampak tersamarkan seketika',
      ],
      howToUse: 'Aplikasikan menggunakan puff atau powder brush ke seluruh wajah secara merata.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_somethinc_02',
      name: 'Copy Paste Breathable Mesh Cushion SPF 35',
      brand: 'Somethinc',
      category: 'Face & Base',
      origin: ProductOrigin.local,
      price: 185000,
      imageUrl: 'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?w=600&auto=format&fit=crop&q=80',
      description: 'Cushion hybrid makeup-skincare lokal pertama dengan formula breathable, glowing finish, dan coverage natural yang menawan.',
      rating: 4.8,
      reviewCount: 940,
      tags: ['BPOM', 'Halal', 'Cushion', 'Healthy Glow', 'SPF 35'],
      benefits: [
        'Menyamarkan ketidaksempurnaan dengan hasil dewy sehat',
        'Ringan di kulit dan tidak menyumbat pori-pori',
        'Dilengkapi SPF 35 PA++++ untuk perlindungan ekstra',
      ],
      howToUse: 'Tekan puff ke mesh cushion secara perlahan, lalu tepuk-tepuk lembut ke seluruh permukaan wajah.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_emina_01',
      name: 'Glossy Stain Lip Tint Hydrating Shine',
      brand: 'Emina',
      category: 'Lip & Cheek',
      origin: ProductOrigin.local,
      price: 47000,
      imageUrl: 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=600&auto=format&fit=crop&q=80',
      description: 'Lip tint bertekstur gel dengan hasil akhir glossy berkilau yang melembapkan bibir dan tahan lama sepanjang hari.',
      rating: 4.7,
      reviewCount: 780,
      tags: ['BPOM', 'Halal', 'Lip Tint', 'Juicy Lips', 'Teen Favorite'],
      benefits: [
        'Bibir tampak segar dan kenyal natural',
        'Tidak membuat bibir kering atau pecah-pecah',
        'Stain warna tahan lama hingga 8 jam',
      ],
      howToUse: 'Oleskan pada bibir bagian dalam untuk ombre look, atau pulaskan penuh untuk kilau bibir merona.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_studiotropik_01',
      name: 'DreamSetter Makeup Setting Spray Anti-Pollution',
      brand: 'Studio Tropik',
      category: 'Makeup',
      origin: ProductOrigin.local,
      price: 145000,
      imageUrl: 'https://images.unsplash.com/photo-1608248597359-0097651a2d54?w=600&auto=format&fit=crop&q=80',
      description: 'Setting spray viral berukuran mikro yang mengunci riasan hingga 16 jam sekaligus melindungi kulit dari partikel polusi perkotaan.',
      rating: 4.9,
      reviewCount: 1380,
      tags: ['BPOM', 'Halal', 'Long Lasting', 'Setting Spray', 'Holy Grail'],
      benefits: [
        'Membuat riasan tahan lama dan transferproof',
        'Micro mist yang halus dan merata di wajah',
        'Ekstrak Marrubium Vulgare sebagai pelindung anti-polusi',
      ],
      howToUse: 'Kocok botol, semprotkan dengan jarak 20 cm dari wajah dengan gerakan membentuk huruf X dan T.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_scarlett_01',
      name: 'Brightly Ever After Serum Phyto Whitening',
      brand: 'Scarlett',
      category: 'Serum',
      origin: ProductOrigin.local,
      price: 75000,
      imageUrl: 'https://images.unsplash.com/photo-1601049541289-9b1b7bbbfe19?w=600&auto=format&fit=crop&q=80',
      description: 'Serum dengan kandungan Lavender Water, Phyto Whitening, Niacinamide, dan Glutathione untuk menutrisi kulit kusam menjadi bercahaya.',
      rating: 4.7,
      reviewCount: 650,
      tags: ['BPOM', 'Halal', 'Glutathione', 'Glow Booster'],
      benefits: [
        'Membantu mencerahkan dan meratakan warna kulit',
        'Menutrisi dan meningkatkan kelembapan kulit',
        'Mengandung antioksidan untuk melawan radikal bebas',
      ],
      howToUse: 'Gunakan 2-3 tetes pada wajah bersih, pijat lembut hingga meresap sempurna.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_dearme_01',
      name: 'Skin Barrier Water Cream 5% Ceramide',
      brand: 'Dear Me Beauty',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 129000,
      imageUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=600&auto=format&fit=crop&q=80',
      description: 'Pelembap berbasis air dengan 5 jenis Ceramide dan Hyaluronic Acid yang meleleh di kulit, memberikan sensasi dingin dan hidrasi instan.',
      rating: 4.8,
      reviewCount: 520,
      tags: ['BPOM', 'Water Cream', 'Soothing', 'Clean Beauty'],
      benefits: [
        'Tekstur watery yang cepat meresap tanpa rasa lengket',
        'Membantu menenangkan kulit iritasi dan kemerahan',
        'Menjaga kelembapan hingga 24 jam penuh',
      ],
      howToUse: 'Ratakan secukupnya pada wajah dan leher setelah menggunakan serum favorit Anda.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_wardah_02',
      name: 'Colorfit Velvet Matte Lip Mousse',
      brand: 'Wardah',
      category: 'Lip & Cheek',
      origin: ProductOrigin.local,
      price: 75000,
      imageUrl: 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=600&auto=format&fit=crop&q=80',
      description: 'Lip mousse dengan tekstur velvet lembut yang memberikan hasil matte powdery halus tanpa membuat garis bibir terlihat kering.',
      rating: 4.8,
      reviewCount: 1890,
      tags: ['BPOM', 'Halal', 'Velvet Matte', 'Comfort Lip'],
      benefits: [
        'Tekstur mousse yang empuk dan ringan di bibir',
        'Pigmentasi intens dalam satu kali pulasan',
        'Diperkaya Vitamin E untuk menjaga kelembapan',
      ],
      howToUse: 'Aplikasikan secara merata menggunakan aplikator doe-foot ke seluruh permukaan bibir.',
      isBestseller: true,
    ),
  ];

  // =========================================================================
  // KOLEKSI BRAND INTERNASIONAL TERVERIFIKASI (The Ordinary, COSRX, dll)
  // =========================================================================
  static final List<CatalogProduct> _curatedInternationalProducts = [
    const CatalogProduct(
      id: 'intl_ordinary_01',
      name: 'Niacinamide 10% + Zinc 1% Oil Control Serum',
      brand: 'The Ordinary',
      category: 'Serum',
      origin: ProductOrigin.international,
      price: 165000,
      imageUrl: 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=600&auto=format&fit=crop&q=80',
      description: 'Formula vitamin dan mineral berkekuatan tinggi untuk mengurangi tampilan noda kulit, meminimalisir pori-pori, dan menyeimbangkan sebum.',
      rating: 4.9,
      reviewCount: 3800,
      tags: ['Canada', 'Cruelty Free', 'Niacinamide', 'Pore Tightening', 'Global Best Seller'],
      benefits: [
        'Mengontrol produksi minyak berlebih pada T-zone',
        'Menyamarkan pori-pori besar secara bertahap',
        'Membantu menenangkan peradangan bekas jerawat',
      ],
      howToUse: 'Oleskan ke seluruh wajah pagi dan malam sebelum menggunakan krim pelembap yang lebih kental.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_cosrx_01',
      name: 'Advanced Snail 96 Mucin Power Essence',
      brand: 'COSRX',
      category: 'Skincare',
      origin: ProductOrigin.international,
      price: 225000,
      imageUrl: 'https://images.unsplash.com/photo-1608248597359-0097651a2d54?w=600&auto=format&fit=crop&q=80',
      description: 'Essence terkenal asal Korea Selatan dengan 96% filtrat sekresi lendir siput untuk memperbaiki elastisitas, dehidrasi, dan tekstur kulit.',
      rating: 4.9,
      reviewCount: 2950,
      tags: ['K-Beauty', 'Snail Mucin', 'Hydration', 'Repair', 'Glass Skin'],
      benefits: [
        'Memberikan hidrasi intensif dan kilau glass skin',
        'Memperbaiki sel kulit yang rusak akibat jerawat',
        'Sangat menenangkan bagi kulit sensitif',
      ],
      howToUse: 'Setelah toner, tuangkan 2 pump ke telapak tangan lalu tepuk-tepuk perlahan ke seluruh wajah hingga terserap.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_maybelline_01',
      name: 'SuperStay Matte Ink Liquid Lipstick 16H',
      brand: 'Maybelline',
      category: 'Lip & Cheek',
      origin: ProductOrigin.international,
      price: 139000,
      imageUrl: 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=600&auto=format&fit=crop&q=80',
      description: 'Lipstick cair berpigmen tinggi dengan formula transferproof hingga 16 jam yang tidak luntur meski makan dan minum.',
      rating: 4.8,
      reviewCount: 3100,
      tags: ['USA', 'Transferproof', '16H Wear', 'Iconic', 'Matte Lip'],
      benefits: [
        'Warna intens tahan lama tanpa perlu touch-up',
        'Aplikator panah presisi untuk garis bibir rapi',
        'Tersedia dalam puluhan pilihan warna memukau',
      ],
      howToUse: 'Aplikasikan di tengah bibir atas lalu ikuti kontur bibir, ratakan ke bibir bawah. Biarkan kering 2 menit.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_laneige_01',
      name: 'Lip Sleeping Mask Berry Moisture Wrap',
      brand: 'Laneige',
      category: 'Lip & Cheek',
      origin: ProductOrigin.international,
      price: 290000,
      imageUrl: 'https://images.unsplash.com/photo-1598440947619-2c35fc9aa908?w=600&auto=format&fit=crop&q=80',
      description: 'Masker tidur bibir kaya vitamin C dari Berry Fruit Complex yang melelehkan sel kulit mati dan mengembalikan kelembutan bibir saat tidur.',
      rating: 4.9,
      reviewCount: 2150,
      tags: ['K-Beauty', 'Overnight Care', 'Berry Complex', 'Soft Lips', 'Luxury'],
      benefits: [
        'Menghilangkan bibir kering pecah-pecah dalam semalam',
        'Moisture Wrap Technology mengunci hidrasi 8 jam',
        'Aroma berry manis yang merelaksasi',
      ],
      howToUse: 'Gunakan spatula sebelum tidur, pulaskan tebal pada bibir. Usap perlahan keesokan paginya.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_nyx_01',
      name: 'Soft Matte Lip Cream Lightweight Formula',
      brand: 'NYX',
      category: 'Lip & Cheek',
      origin: ProductOrigin.international,
      price: 125000,
      imageUrl: 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=600&auto=format&fit=crop&q=80',
      description: 'Formula legendaris yang memadukan kelembutan krim dengan hasil akhir matte lembut, beraroma vanila manis yang menggoda.',
      rating: 4.7,
      reviewCount: 1450,
      tags: ['USA', 'Cruelty Free', 'Velvet Texture', 'Everyday Nude'],
      benefits: [
        'Sangat ringan seperti tidak memakai lipstick',
        'Tidak mempertegas garis-garis halus bibir',
        'Warna nude elegan cocok untuk daily makeup',
      ],
      howToUse: 'Pulaskan langsung menggunakan kuas aplikator secara merata pada bibir.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'intl_clinique_01',
      name: 'Moisture Surge 100H Auto-Replenishing Hydrator',
      brand: 'Clinique',
      category: 'Skincare',
      origin: ProductOrigin.international,
      price: 380000,
      imageUrl: 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&auto=format&fit=crop&q=80',
      description: 'Gel pelembap bebas minyak dengan Aloe Bio-ferment dan Asam Hialuronat yang meresap lebih dari 10 lapisan ke dalam kulit.',
      rating: 4.9,
      reviewCount: 1670,
      tags: ['Dermatologist Tested', 'Oil Free', '100H Moisture', 'Prestige'],
      benefits: [
        'Menghidrasi kulit tanpa rasa berminyak sedikitpun',
        'Memberikan kilau sehat dewy sepanjang hari',
        'Aman untuk semua jenis kulit termasuk sensitif',
      ],
      howToUse: 'Gunakan pagi dan malam setelah rutinitas skincare atau sebagai masker kilat 5 menit.',
      isBestseller: true,
    ),
  ];

  static List<CatalogProduct> get _localProductsFallback => [
        ..._indonesianLocalProducts,
        ..._curatedInternationalProducts,
      ];
}
