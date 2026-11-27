import 'dart:convert';

import 'package:flutter/services.dart';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.brand,
    required this.category,
    required this.code,
    required this.name,
    required this.photoAsset,
    required this.originalPath,
  });

  final String id;
  final String brand;
  final String category;
  final String code;
  final String name;
  final String photoAsset;
  final String originalPath;

  String get displayName => '$brand $code';

  /// Returns typical real-world weight in KG based on salon furniture category
  double get approximateWeightKg {
    final cat = category.toUpperCase();
    if (cat.contains('BED')) return 45.0; // Facial / Massage Bed
    if (cat.contains('SHAMPOO')) return 40.0; // Shampoo Station / Chair
    if (cat.contains('CHAIR')) return 28.0; // Styling / Barber Chair
    if (cat.contains('MANI') || cat.contains('PEDI')) return 35.0; // Mani Pedi Station
    if (cat.contains('MASSAGER')) return 60.0; // Full Body Massager
    if (cat.contains('TROLLEY')) return 12.0; // Salon Trolley
    if (cat.contains('STOOL')) return 8.0; // Cutting / Operator Stool
    return 30.0; // Default reasonable weight
  }

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
        id: json['id']?.toString() ?? '',
        brand: json['brand']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        photoAsset: json['photoAsset']?.toString() ?? '',
        originalPath: json['originalPath']?.toString() ?? '',
      );
}

class ProductCatalogService {
  ProductCatalogService._();

  static List<CatalogProduct>? _cache;

  static Future<List<CatalogProduct>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(
      'assets/product_catalog/catalog.json',
    );
    final decoded = jsonDecode(raw);
    _cache = decoded is List
        ? decoded
            .whereType<Map>()
            .map((item) => CatalogProduct.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const [];
    return _cache!;
  }
}
