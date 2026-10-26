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
