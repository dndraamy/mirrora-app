import 'dart:convert';

/// Asal brand produk (Lokal Indonesia vs Internasional)
enum ProductOrigin {
  all,
  local,
  international;

  String get label {
    switch (this) {
      case ProductOrigin.all:
        return 'Semua';
      case ProductOrigin.local:
        return '🇮🇩 Brand Lokal';
      case ProductOrigin.international:
        return '🌍 Internasional';
    }
  }

  String get shortLabel {
    switch (this) {
      case ProductOrigin.all:
        return 'Semua';
      case ProductOrigin.local:
        return 'Lokal';
      case ProductOrigin.international:
        return 'Global';
    }
  }
}

/// Opsi Pengurutan Katalog
enum ProductSort {
  popular,
  priceLowToHigh,
  priceHighToLow,
  ratingHigh,
  nameAZ;

  String get label {
    switch (this) {
      case ProductSort.popular:
        return 'Terpopuler ⭐';
      case ProductSort.priceLowToHigh:
        return 'Harga: Terendah 🏷️';
      case ProductSort.priceHighToLow:
        return 'Harga: Tertinggi 💎';
      case ProductSort.ratingHigh:
        return 'Rating Tertinggi 🌟';
      case ProductSort.nameAZ:
        return 'Nama: A - Z 🔤';
    }
  }
}

/// Model data produk untuk katalog Explore Screen
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.origin,
    required this.price,
    required this.imageUrl,
    required this.description,
    this.rating = 4.8,
    this.reviewCount = 120,
    this.tags = const [],
    this.benefits = const [],
    this.howToUse = '',
    this.isBestseller = false,
    this.productLink = '',
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final ProductOrigin origin;
  final double price;
  final String imageUrl;
  final String description;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final List<String> benefits;
  final String howToUse;
  final bool isBestseller;
  final String productLink;

  /// Format harga ke Rupiah (cth: Rp 129.000)
  String get formattedPrice {
    final intPrice = price.round();
    final str = intPrice.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    final reversed = buffer.toString().split('').reversed.join('');
    return 'Rp $reversed';
  }

  /// Factory untuk mem-parsing respons dari Makeup API (Heroku)
  factory CatalogProduct.fromMakeupApi(Map<String, dynamic> json) {
    final rawPrice = double.tryParse(json['price']?.toString() ?? '0') ?? 12.0;
    // Konversi harga USD dari Makeup API ke perkiraan IDR (kurs ~16.000)
    final idrPrice = rawPrice > 0 ? (rawPrice * 16000).roundToDouble() : 185000.0;

    final rawName = (json['name'] as String?)?.trim() ?? 'Beauty Product';
    final rawBrand = (json['brand'] as String?)?.trim() ?? 'International';
    final capitalizedBrand = rawBrand.isNotEmpty
        ? rawBrand[0].toUpperCase() + rawBrand.substring(1)
        : 'Global';

    final rawType = (json['product_type'] as String?)?.toLowerCase() ?? 'makeup';
    String categoryName = 'Makeup';
    if (rawType.contains('lip') || rawType == 'lipstick' || rawType == 'lip_gloss') {
      categoryName = 'Lip & Cheek';
    } else if (rawType.contains('foundation') || rawType.contains('powder') || rawType == 'blush') {
      categoryName = 'Face & Base';
    } else if (rawType.contains('mascara') || rawType.contains('eyeliner') || rawType.contains('eyeshadow')) {
      categoryName = 'Eye Makeup';
    } else if (rawType.contains('cream') || rawType.contains('serum')) {
      categoryName = 'Skincare';
    }

    // Bersihkan deskripsi dari karakter aneh / newline berlebih
    var desc = (json['description'] as String?)?.trim() ?? '';
    desc = desc.replaceAll(RegExp(r'\s+'), ' ');
    if (desc.isEmpty) {
      desc = '$rawName dari $capitalizedBrand dengan formula inovatif yang tahan lama dan nyaman digunakan.';
    }

    final rawImg = json['image_link'] as String? ?? '';
    final featuredImg = json['api_featured_image'] as String? ?? '';
    var finalImg = rawImg.isNotEmpty ? rawImg : featuredImg;
    if (finalImg.startsWith('//')) {
      finalImg = 'https:$finalImg';
    }

    final rawRating = double.tryParse(json['rating']?.toString() ?? '') ?? 4.7;
    final tagList = (json['tag_list'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    return CatalogProduct(
      id: 'api_${json['id'] ?? rawName.hashCode}',
      name: rawName,
      brand: capitalizedBrand,
      category: categoryName,
      origin: ProductOrigin.international,
      price: idrPrice,
      imageUrl: finalImg,
      description: desc,
      rating: rawRating.clamp(3.5, 5.0),
      reviewCount: 80 + (rawName.hashCode.abs() % 450),
      tags: tagList.isNotEmpty ? tagList : ['Global Favorite', 'Cruelty Free'],
      benefits: [
        'Formula ramah kulit yang tahan lama',
        'Pigmentasi tinggi dengan hasil natural',
        'Mudah diaplikasikan untuk pemula maupun profesional',
      ],
      howToUse: 'Aplikasikan secukupnya pada area wajah yang diinginkan dan ratakan secara merata.',
      isBestseller: rawRating >= 4.5,
      productLink: json['product_link'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'origin': origin.name,
      'price': price,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'reviewCount': reviewCount,
      'tags': tags,
      'benefits': benefits,
      'howToUse': howToUse,
      'isBestseller': isBestseller,
      'productLink': productLink,
    };
  }

  factory CatalogProduct.fromMap(Map<String, dynamic> map) {
    return CatalogProduct(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      category: map['category'] as String,
      origin: map['origin'] == 'local'
          ? ProductOrigin.local
          : ProductOrigin.international,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String,
      description: map['description'] as String,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 120,
      tags: List<String>.from(map['tags'] ?? []),
      benefits: List<String>.from(map['benefits'] ?? []),
      howToUse: map['howToUse'] as String? ?? '',
      isBestseller: map['isBestseller'] as bool? ?? false,
      productLink: map['productLink'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());
}
