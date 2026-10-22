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

    var list = List<CatalogProduct>.from(
      _cachedProducts ?? _localProductsFallback,
    );

    // 1. Filter Asal Brand (Lokal vs Internasional)
    if (origin != ProductOrigin.all) {
      list = list.where((p) => p.origin == origin).toList();
    }

    // 2. Filter Kategori
    if (category != null && category.isNotEmpty && category != 'Semua') {
      list = list.where((p) {
        if (category == 'Skincare') {
          return p.category == 'Skincare' ||
              p.category == 'Serum' ||
              p.category == 'Sunscreen';
        } else if (category == 'Makeup') {
          return p.category == 'Makeup' ||
              p.category == 'Lip & Cheek' ||
              p.category == 'Face & Base' ||
              p.category == 'Eye Makeup';
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
        return matchName ||
            matchBrand ||
            matchCategory ||
            matchTags ||
            matchDesc;
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
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
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
    final uri = Uri.parse(
      'http://makeup-api.herokuapp.com/api/v1/products.json?brand=maybelline',
    );

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
      imageUrl: 'https://images.soco.id/4262f82a-a511-4795-81cd-d18d1894add6-image-0-1611729361739',
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
      imageUrl:
          'https://images.soco.id/5d365c76-e0c8-420e-a23e-0efa86850730-.jpg',
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
      imageUrl: 'https://images.soco.id/b80c1fbb-1d3b-4e79-8ea1-087ed0746dd6-image-0-1762314089456',
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
      imageUrl:
          'https://images.soco.id/bf1d3f7a-18dd-4f19-a90e-991ad8006e63-.jpg',
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
      imageUrl:
          'https://images.soco.id/0017e530-dd75-4c11-a29a-da52508840c8-.jpg',
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
      imageUrl: 'https://images.soco.id/6beb022e-5b8c-4e88-b9c1-2095da3d6e33-image-0-1617865173962',
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
      imageUrl: 'https://images.soco.id/79260583704-1587431932497.png',
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
      imageUrl: 'https://images.soco.id/34181423051-1594957699591.png',
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
      imageUrl: 'https://images.soco.id/a877bd75-063b-4221-aa6d-99563e2f618b-image-0-1629970762194',
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
      imageUrl:
          'https://images.soco.id/3d4d04ca-ab9c-44ff-8974-b871474b06e7-.jpg',
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
      imageUrl:
          'https://images.soco.id/ccb59675-f3bc-44e6-b248-a6dfe43667ad-.jpg',
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
    const CatalogProduct(
      id: 'local_azarine_01',
      name: 'Hydrasoothe Sunscreen Gel SPF 45 PA++++',
      brand: 'Azarine',
      category: 'Sunscreen',
      origin: ProductOrigin.local,
      price: 65000,
      imageUrl:
          'https://images.soco.id/04c908f1-81e8-4f97-9680-35f64901f70b-.jpg',
      description: 'Tabir surya bertekstur gel dingin yang sangat ringan, bebas minyak, tanpa silikon, dan cepat meresap tanpa rasa lengket.',
      rating: 4.9,
      reviewCount: 3200,
      tags: ['BPOM', 'Halal', 'Oil Free', 'Sunscreen Gel', 'Acne Safe'],
      benefits: [
        'Sensasi dingin menenangkan kulit kemerahan dan berjerawat',
        'Tekstur gel air yang sangat mudah dibaurkan',
        'Diformulasikan dengan Propolis, Aloe Vera, dan Green Tea',
      ],
      howToUse: 'Tuangkan dua ruas jari, ratakan pada seluruh wajah dan leher di pagi hari.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_roseallday_01',
      name: 'The Realest Lightweight Foundation',
      brand: 'Rose All Day',
      category: 'Face & Base',
      origin: ProductOrigin.local,
      price: 169000,
      imageUrl: 'https://s3-ap-southeast-1.amazonaws.com/img-sociolla/img/p/2/1/2/7/0/21270-large_default.jpg',
      description: 'Foundation cair seringan bulu dengan satin finish alami yang menyatu sempurna dengan tekstur asli kulit wajah.',
      rating: 4.8,
      reviewCount: 840,
      tags: ['BPOM', 'Lightweight', 'Satin Finish', 'Clean Aesthetic'],
      benefits: [
        'Coverage natural yang menyamarkan noda hitam seketika',
        'Tidak terasa berat dan tahan sepanjang hari',
        'Diperkaya Hyaluronic Acid dan Vitamin E',
      ],
      howToUse: 'Kocok perlahan, pump 1-2 tetes ke punggung tangan, lalu baurkan menggunakan sponge basah atau jari.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_luxcrime_01',
      name: 'Blur & Cover Two Way Cake Silk Glow',
      brand: 'Luxcrime',
      category: 'Face & Base',
      origin: ProductOrigin.local,
      price: 129000,
      imageUrl:
          'https://images.soco.id/ba023dea-e24b-4ae3-8d98-3a1ad9af7aa0-.jpg',
      description: 'Bedak dua arah dengan efek blur instan yang menyamarkan pori-pori dan garis halus untuk tampilan flawless bagai filter kamera.',
      rating: 4.9,
      reviewCount: 1980,
      tags: ['BPOM', 'Halal', 'Blur Effect', 'Oil Control', 'Flawless'],
      benefits: [
        'Menyamarkan pori-pori dan ketidaksempurnaan wajah seketika',
        'Hasil akhir silk matte yang halus dan tidak kering',
        'Menahan minyak wajah hingga berjam-jam',
      ],
      howToUse: 'Gunakan spons kering untuk hasil natural atau spons basah untuk coverage ekstra maksimal.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_mop_01',
      name: 'AM to PM Colorfast Hyalugloss Tint',
      brand: 'Mother of Pearl',
      category: 'Lip & Cheek',
      origin: ProductOrigin.local,
      price: 119000,
      imageUrl:
          'https://images.soco.id/980c064f-7174-4ade-842a-f632111dbb7e-.jpg',
      description: 'Lip gloss berkilau tinggi yang diperkaya Hyaluronic Acid, tidak lengket di bibir, dan memberikan stain warna memukau.',
      rating: 4.8,
      reviewCount: 760,
      tags: ['BPOM', 'Halal', 'High Shine', 'Hyaluronic', 'Plump Lips'],
      benefits: [
        'Memberikan kilau juicy mempesona tanpa rasa lengket',
        'Menghidrasi dan membuat bibir tampak lebih bervolume',
        'Warna pigmented yang tahan lama',
      ],
      howToUse: 'Pulaskan langsung ke bibir mulai dari bagian tengah ke arah luar sudut bibir.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_labore_01',
      name: 'BiomeProtect Sensitive Skin Hydrating Cleanser',
      brand: 'Labore',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 95000,
      imageUrl:
          'https://images.soco.id/3f621039-e464-46da-b247-bc7b266d1841-.jpg',
      description: 'Pembersih wajah lembut tanpa busa berlebih dengan teknologi Microbiome untuk menjaga keseimbangan bakteri baik kulit sensitif.',
      rating: 4.9,
      reviewCount: 640,
      tags: ['BPOM', 'Microbiome', 'Dermatologist Tested', 'Sensitive Safe'],
      benefits: [
        'Membersihkan kotoran tanpa mengikis kelembapan alami',
        'Bebas sabun, sulfat, alkohol, dan pewangi buatan',
        'Menenangkan kulit sensitif dan mudah kemerahan',
      ],
      howToUse: 'Basahi wajah dengan air, pijatkan cleanser dengan lembut lalu bilas hingga bersih.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_whitelab_01',
      name: 'Brightening Face Toner Niacinamide + Collagen',
      brand: 'Whitelab',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 62000,
      imageUrl:
          'https://images.soco.id/fc5f4678-c2bc-447b-b5f4-2e38987c2e7a-.jpg',
      description: 'Toner pencerah wajah dengan perpaduan Niacinamide dan Collagen untuk menjaga elastisitas kulit dan mengembalikan kesegaran wajah.',
      rating: 4.7,
      reviewCount: 890,
      tags: ['BPOM', 'Halal', 'Collagen', 'Brightening', 'Budget Friendly'],
      benefits: [
        'Mengangkat sisa kotoran dan sel kulit mati dengan lembut',
        'Menyegarkan dan mencerahkan kulit kusam',
        'Membantu penyerapan serum lebih maksimal',
      ],
      howToUse: 'Tuangkan pada kapas atau telapak tangan, tepuk-tepuk lembut ke seluruh area wajah dan leher.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_somethinc_03',
      name: 'Brow Wiz Retractable Eyebrow Pencil',
      brand: 'Somethinc',
      category: 'Makeup',
      origin: ProductOrigin.local,
      price: 55000,
      imageUrl: 'https://images.soco.id/20812788684-1598867175721.png',
      description: 'Pensil alis mekanik berujung ultra-presisi 0.5mm dengan spoolie lembut untuk menggambar serat alis tampak sangat natural.',
      rating: 4.9,
      reviewCount: 1540,
      tags: ['BPOM', 'Halal', 'Ultra Precision', 'Smudgeproof', 'Natural Brow'],
      benefits: [
        'Ujung mikro membuat goresan helaian alis presisi',
        'Formula waterproof dan tahan keringat seharian',
        'Dilengkapi spoolie brush untuk blending halus',
      ],
      howToUse: 'Putar pensil sedikit, bingkai dan arsir bagian alis yang kosong searah tumbuhnya rambut alis.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_roseallday_02',
      name: 'Lip Mousse Records Velvet Tint',
      brand: 'Rose All Day',
      category: 'Lip & Cheek',
      origin: ProductOrigin.local,
      price: 99000,
      imageUrl:
          'https://images.soco.id/1a3332cd-19f4-4b0c-8907-d1606f3463ae-.jpg',
      description: 'Lip tint bertekstur mousse selembut awan yang memberikan sensasi ringan di bibir dengan warna intens beraroma buah segar.',
      rating: 4.8,
      reviewCount: 910,
      tags: ['BPOM', 'Halal', 'Velvet Cloud', 'Non Drying', 'Aesthetic'],
      benefits: [
        'Bibir terasa lembut halus bagai beludru',
        'Tidak mempertegas garis kerutan bibir',
        'Formula tahan noda dengan stain yang menawan',
      ],
      howToUse: 'Baurkan di bibir bagian tengah lalu ratakan menggunakan jari untuk efek soft blur.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_carasun_01',
      name: 'Solar Smart UV Protector SPF 45 PA++++',
      brand: 'Carasun',
      category: 'Sunscreen',
      origin: ProductOrigin.local,
      price: 69000,
      imageUrl:
          'https://images.soco.id/3f2a5e08-6b53-477b-9a83-7608472510a2-.jpg',
      description: 'Sunscreen bertekstur cloud seringan awan yang nyaman dipakai di iklim tropis, menjaga kulit tetap lembap hingga 8 jam.',
      rating: 4.8,
      reviewCount: 1470,
      tags: [
        'BPOM',
        'Halal',
        'Cloud Texture',
        'Non Comedogenic',
        'Tropical Formula',
      ],
      benefits: [
        'Tekstur seringan awan tanpa rasa gerah atau berminyak',
        'Mengandung ekstrak Beras dan CityStem pelindung polusi',
        'Diformulasikan khusus untuk kulit wanita Indonesia',
      ],
      howToUse: 'Gunakan secukupnya pada wajah dan leher 15 menit sebelum beraktivitas di luar ruangan.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_glad2glow_01',
      name: 'Centella Allantoin Soothing Gel Moisturizer',
      brand: 'Glad2Glow',
      category: 'Skincare',
      origin: ProductOrigin.local,
      price: 43000,
      imageUrl:
          'https://images.soco.id/ac3ed485-7308-4c30-957f-b62d77740ff2-.jpg',
      description: 'Pelembap bertekstur gel ringan dengan sensasi dingin menyejukkan kulit berjerawat dan meredakan peradangan seketika.',
      rating: 4.8,
      reviewCount: 1670,
      tags: ['BPOM', 'Centella', 'Soothing Gel', 'Acne Care', 'Affordable'],
      benefits: [
        'Meredakan jerawat aktif dan kemerahan dengan cepat',
        'Mengontrol produksi sebum berlebih',
        'Cepat meresap tanpa meninggalkan rasa lengket',
      ],
      howToUse:
          'Ambil produk secukupnya, ratakan ke seluruh wajah pagi dan malam.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'local_avoskin_02',
      name: 'Your Skin Bae Niacinamide 12% + Centella Asiatica',
      brand: 'Avoskin',
      category: 'Serum',
      origin: ProductOrigin.local,
      price: 139000,
      imageUrl: 'https://images.soco.id/5a4c824f-c336-44b6-8d60-ee308bcedc78-image-0-1723431531657',
      description: 'Serum pencerah konsentrasi tinggi dengan Niacinamide 12% dan ekstrak Centella Asiatica untuk mengatasi noda bekas jerawat membandel.',
      rating: 4.8,
      reviewCount: 1220,
      tags: ['BPOM', 'Halal', 'Niacinamide 12%', 'Dark Spot Corrector'],
      benefits: [
        'Memudarkan noda hitam bekas jerawat PIH dan PIE',
        'Mencerahkan wajah secara merata',
        'Menenangkan kulit kemerahan akibat iritasi ringan',
      ],
      howToUse: 'Oleskan beberapa tetes ke area wajah secara merata pada pagi dan malam hari.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_skintific_02',
      name: '10% Niacinamide Brightening Serum',
      brand: 'Skintific',
      category: 'Serum',
      origin: ProductOrigin.local,
      price: 149000,
      imageUrl: 'https://images.soco.id/2ff90c78-9742-457c-9b92-0bb8d490b70f-image-0-1735210574457',
      description: 'Serum pencerah dengan Royal DSM Niacinamide, Alpha Arbutin, dan Centella untuk mencerahkan dalam 14 hari tanpa merusak skin barrier.',
      rating: 4.9,
      reviewCount: 1850,
      tags: ['BPOM', 'Royal Niacinamide', 'Alpha Arbutin', 'Fast Brightening'],
      benefits: [
        'Mencerahkan kulit kusam secara efektif dalam 14 hari',
        'Menyamarkan noda hitam dan bekas jerawat',
        'Membantu meratakan warna kulit tidak merata',
      ],
      howToUse: 'Teteskan pada wajah bersih, pijat memutar hingga terserap secara menyeluruh.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'local_luxcrime_02',
      name: 'Seamless Liquid Blush Cheek Color',
      brand: 'Luxcrime',
      category: 'Lip & Cheek',
      origin: ProductOrigin.local,
      price: 89000,
      imageUrl: 'https://images.soco.id/5994086883-1593661856502.png',
      description: 'Blush cair yang mudah dibaurkan dengan jari maupun spons, memberikan rona pipi segar berseri yang tahan seharian.',
      rating: 4.8,
      reviewCount: 710,
      tags: ['BPOM', 'Halal', 'Liquid Blush', 'Dewy Cheek', 'Blendable'],
      benefits: [
        'Rona pipi tampak merona alami dan segar merata',
        'Formula ringan dan tidak menggeser foundation',
        'Dapat juga digunakan sebagai perona kelopak mata',
      ],
      howToUse: 'Totolkan 1-2 titik kecil di tulang pipi, tepuk lembut hingga terbaur sempurna.',
      isBestseller: false,
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
      imageUrl: 'https://images.soco.id/18978041466-1597824924221.png',
      description: 'Formula vitamin dan mineral berkekuatan tinggi untuk mengurangi tampilan noda kulit, meminimalisir pori-pori, dan menyeimbangkan sebum.',
      rating: 4.9,
      reviewCount: 3800,
      tags: [
        'Canada',
        'Cruelty Free',
        'Niacinamide',
        'Pore Tightening',
        'Global Best Seller',
      ],
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
      imageUrl: 'https://images.soco.id/70b55a13-f4bb-440a-84c6-10f188b0c823-image-0-1615975483692',
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
      imageUrl:
          'https://images.soco.id/ce0347a2-83be-4149-8cba-50e5ed6c8dd7-.jpg',
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
      imageUrl:
          'https://images.soco.id/b6aa4db6-4dd3-4528-b5a1-74ea6081047d-.jpg',
      description: 'Masker tidur bibir kaya vitamin C dari Berry Fruit Complex yang melelehkan sel kulit mati dan mengembalikan kelembutan bibir saat tidur.',
      rating: 4.9,
      reviewCount: 2150,
      tags: [
        'K-Beauty',
        'Overnight Care',
        'Berry Complex',
        'Soft Lips',
        'Luxury',
      ],
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
      imageUrl: 'https://s3-ap-southeast-1.amazonaws.com/img-sociolla/img/p/1/2/6/2/0/12620-large_default.jpg',
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
      imageUrl: 'https://images.soco.id/30940240-8efb-4d77-ad72-5f6d8cbc28fb-image-0-1753092921261',
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
    const CatalogProduct(
      id: 'intl_boj_01',
      name: 'Relief Sun Rice + Probiotics SPF 50+ PA++++',
      brand: 'Beauty of Joseon',
      category: 'Sunscreen',
      origin: ProductOrigin.international,
      price: 175000,
      imageUrl:
          'https://images.soco.id/8522252a-88c5-438b-8aec-7054a5efe869-.jpg',
      description: 'Sunscreen organik viral asal Korea dengan 30% ekstrak beras dan fermentasi gandum untuk melindungi sekaligus menutrisi kulit.',
      rating: 4.9,
      reviewCount: 4100,
      tags: [
        'K-Beauty',
        'Rice Extract',
        'No Whitecast',
        'Viral Sunscreen',
        'Glow Finish',
      ],
      benefits: [
        'Memberikan perlindungan SPF 50+ tanpa rasa lengket',
        'Memberikan efek glowing natural tanpa whitecast',
        'Menutrisi kulit dengan vitamin B, C, E dari beras',
      ],
      howToUse: 'Oleskan secara merata pada wajah dan leher sebagai langkah terakhir skincare pagi.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_anua_01',
      name: 'Heartleaf 77% Soothing Toner Calm & Hydrate',
      brand: 'Anua',
      category: 'Skincare',
      origin: ProductOrigin.international,
      price: 245000,
      imageUrl:
          'https://images.soco.id/1a3838cf-91a2-4d7d-9d11-f60db5d809eb-.jpg',
      description: 'Toner Korea nomor satu dengan 77% ekstrak Daun Heartleaf untuk meredakan kemerahan, menenangkan iritasi, dan menjaga kelembapan.',
      rating: 4.9,
      reviewCount: 2780,
      tags: [
        'K-Beauty',
        'Heartleaf 77%',
        'Soothing',
        'Calming',
        'Sensitive Hero',
      ],
      benefits: [
        'Menenangkan kemerahan dan jerawat aktif secara instan',
        'Keseimbangan pH optimal untuk kulit sensitif',
        'Tekstur cair yang menyegarkan tanpa residu lengket',
      ],
      howToUse: 'Tuangkan pada kapas atau telapak tangan, tepuk perlahan ke seluruh wajah.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_ordinary_02',
      name: 'Hyaluronic Acid 2% + B5 Intense Hydration',
      brand: 'The Ordinary',
      category: 'Serum',
      origin: ProductOrigin.international,
      price: 175000,
      imageUrl: 'https://images.soco.id/12637446930-1597825163715.png',
      description: 'Serum formulasi hidrasi pendukung dengan asam hialuronat murni vegan dan Vitamin B5 untuk kelembapan multi-kedalaman.',
      rating: 4.8,
      reviewCount: 2210,
      tags: ['Canada', 'Hyaluronic Acid', 'Deep Hydration', 'Plump Skin'],
      benefits: [
        'Menghidrasi kulit hingga lapisan terdalam',
        'Membantu kulit tampak lebih kenyal dan kencang',
        'Vitamin B5 meningkatkan regenerasi permukaan kulit',
      ],
      howToUse: 'Teteskan beberapa tetes pada wajah lembap di pagi dan malam hari sebelum krim.',
      isBestseller: false,
    ),
    const CatalogProduct(
      id: 'intl_laneige_02',
      name: 'Water Sleeping Mask EX Hydration Booster',
      brand: 'Laneige',
      category: 'Skincare',
      origin: ProductOrigin.international,
      price: 395000,
      imageUrl: 'https://images.soco.id/db513e15-f525-4235-8b62-c1a9db5ae82b-image-0-1628191486340',
      description: 'Masker tidur intensif dengan Sleeping Micro-Biome dan Pro-biotics Complex untuk memulihkan kecerahan kulit saat tidur terlelap.',
      rating: 4.9,
      reviewCount: 1940,
      tags: [
        'K-Beauty',
        'Probiotics',
        'Overnight Mask',
        'Glowing Skin',
        'Iconic',
      ],
      benefits: [
        'Bangun pagi dengan kulit wajah tampak segar dan bercahaya',
        'Meningkatkan pertahanan skin barrier alami kulit',
        'Tekstur gel menyegarkan yang cepat meresap',
      ],
      howToUse: 'Gunakan 2-3 kali seminggu pada malam hari sebagai langkah akhir skincare. Bilas keesokan harinya.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_boj_02',
      name: 'Glow Serum Propolis + Niacinamide',
      brand: 'Beauty of Joseon',
      category: 'Serum',
      origin: ProductOrigin.international,
      price: 185000,
      imageUrl:
          'https://images.soco.id/fd16589c-ba85-4469-b326-e0bc2f599e21-.jpg',
      description: 'Serum legendaris dengan 60% ekstrak Propolis dan 2% Niacinamide untuk mengatasi pori-pori besar dan memberikan kilau dewy madu.',
      rating: 4.8,
      reviewCount: 2890,
      tags: ['K-Beauty', 'Propolis', 'Dewy Glow', 'Honey Skin', 'Pore Care'],
      benefits: [
        'Menenangkan peradangan kulit berkat sifat antibakteri propolis',
        'Menjadikan kulit tampak glowing bercahaya bagai madu',
        'Menjaga keseimbangan kadar air dan minyak wajah',
      ],
      howToUse: 'Teteskan 2-3 tetes ke wajah, ratakan dengan tepukan lembut hingga meresap.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_biore_01',
      name: 'UV Aqua Rich Watery Essence SPF 50+ PA++++',
      brand: 'Biore',
      category: 'Sunscreen',
      origin: ProductOrigin.international,
      price: 125000,
      imageUrl:
          'https://images.soco.id/a84a8ade-5515-46cb-acca-5bc954c40cd6-.jpg',
      description: 'Sunscreen asal Jepang dengan Micro Defense formula yang memberikan perlindungan menyeluruh hingga ke celah kulit mikroskopis.',
      rating: 4.9,
      reviewCount: 4500,
      tags: [
        'Japan',
        'Micro Defense',
        'Watery Essence',
        'Lightweight',
        'Cult Favorite',
      ],
      benefits: [
        'Tekstur watery yang langsung meleleh di kulit seperti air',
        'Sangat tahan air dan keringat (Water resistant 80 menit)',
        'Diperkaya Asam Hialuronat dan Royal Jelly Extract',
      ],
      howToUse: 'Oleskan secara merata pada wajah dan leher sebelum terpapar sinar matahari.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_skin1004_01',
      name: 'Madagascar Centella Hyalu-Cica Water-Fit Sun Serum',
      brand: 'Skin1004',
      category: 'Sunscreen',
      origin: ProductOrigin.international,
      price: 169000,
      imageUrl:
          'https://images.soco.id/8d6891e0-f416-4730-92c8-a11d4b580345-.jpg',
      description: 'Serum tabir surya kimiawi non-nano yang melembapkan dan menenangkan kulit dengan kombinasi emas Centella Asiatica dan Hyaluronic Acid.',
      rating: 4.9,
      reviewCount: 2340,
      tags: [
        'K-Beauty',
        'Madagascar Centella',
        'Hyalu-Cica',
        'Reef Safe',
        'Blue Light Protection',
      ],
      benefits: [
        'Hasil akhir dewy sehat tanpa rasa lengket sama sekali',
        'Formula ramah terumbu karang (Reef-safe)',
        'Menenangkan kulit yang sensitif dan mudah kemerahan',
      ],
      howToUse: 'Pump secukupnya lalu ratakan ke seluruh area wajah dan leher pada pagi hari.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_romand_01',
      name: 'Juicy Lasting Tint Glossy Stain',
      brand: 'Rom&nd',
      category: 'Lip & Cheek',
      origin: ProductOrigin.international,
      price: 119000,
      imageUrl:
          'https://images.soco.id/cf2ffd93-bdae-40d3-924b-0b52045d7b4d-.jpg',
      description: 'Pewarna bibir glossy 3-in-1 yang memberikan kilau permen buah manis, warna cerah merona, dan stain tahan lama sepanjang hari.',
      rating: 4.9,
      reviewCount: 3120,
      tags: [
        'K-Beauty',
        'Juicy Tint',
        'Glossy Stain',
        'Sugar Glaze',
        'Top Trend',
      ],
      benefits: [
        'Efek kilau buah berkilau yang memukau tanpa rasa lengket',
        'Stain warna tetap bertahan bahkan setelah kilaunya pudar',
        'Pilihan warna MLBB natural yang sangat cocok untuk daily look',
      ],
      howToUse: 'Oleskan perlahan pada bibir, jangan terlalu sering mengatupkan bibir agar kilaunya maksimal.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_rarebeauty_01',
      name: 'Soft Pinch Liquid Blush Dewy Finish',
      brand: 'Rare Beauty',
      category: 'Lip & Cheek',
      origin: ProductOrigin.international,
      price: 410000,
      imageUrl: 'https://image-optimizer-id.production.sephora-asia.net/images/product_images/closeup_1_Product_840122909801-Rare-Beauty-Soft-Pinch-Liquid-Blush-A_88a58500d21eec948bcdcd5a8716f2a9015266e8_1774585038.png',
      description: 'Blush on cair berpigmen sangat tinggi yang memberikan rona pipi sehat tahan lama dengan hasil akhir dewy berkilau alami.',
      rating: 4.9,
      reviewCount: 3890,
      tags: [
        'USA',
        'Cruelty Free',
        'High Pigment',
        'Dewy Cheek',
        'Celebrity Favorite',
      ],
      benefits: [
        'Satu titik kecil sudah cukup untuk menghasilkan warna memukau',
        'Daya tahan luar biasa tanpa mudah memudar seharian',
        'Formula bernapas yang menyatu mulus di atas makeup',
      ],
      howToUse: 'Cukup totolkan 1 titik kecil pada pipi lalu baurkan segera menggunakan jari atau kuas.',
      isBestseller: true,
    ),
    const CatalogProduct(
      id: 'intl_maybelline_02',
      name: 'Fit Me Matte + Poreless Liquid Foundation',
      brand: 'Maybelline',
      category: 'Face & Base',
      origin: ProductOrigin.international,
      price: 155000,
      imageUrl:
          'https://images.soco.id/ec9cf2d0-4330-43a6-b444-0ff2770fd1c4-.jpg',
      description: 'Foundation cair dengan micro-powders penyerap minyak untuk hasil akhir matte alami dan tampilan pori-pori yang tersamarkan rapi.',
      rating: 4.8,
      reviewCount: 5200,
      tags: [
        'USA',
        'Oil Control',
        'Poreless',
        'Matte Finish',
        'Best Seller Global',
      ],
      benefits: [
        'Formula ringan dan cocok untuk kulit normal hingga berminyak',
        'Menyamarkan pori-pori dan meratakan warna kulit seketika',
        'Dermatologist tested dan non-comedogenic',
      ],
      howToUse: 'Tuangkan secukupnya pada spons makeup atau jari, lalu ratakan dari bagian tengah wajah ke luar.',
      isBestseller: true,
    ),
  ];

  static List<CatalogProduct> get _localProductsFallback => [
    ..._indonesianLocalProducts,
    ..._curatedInternationalProducts,
  ];
}
