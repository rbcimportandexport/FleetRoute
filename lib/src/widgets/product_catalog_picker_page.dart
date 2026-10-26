import 'package:flutter/material.dart';

import '../services/product_catalog_service.dart';
import '../theme/app_theme.dart';

/// Reusable Product Catalog Picker (RBC / RAMA)
/// Displays searchable catalogue with category chips, product photos and specs.
class ProductCatalogPickerPage extends StatefulWidget {
  const ProductCatalogPickerPage({super.key});

  static Future<CatalogProduct?> show(BuildContext context) {
    return Navigator.of(context).push<CatalogProduct>(
      MaterialPageRoute(
        builder: (_) => const ProductCatalogPickerPage(),
      ),
    );
  }

  @override
  State<ProductCatalogPickerPage> createState() =>
      _ProductCatalogPickerPageState();
}

class _ProductCatalogPickerPageState extends State<ProductCatalogPickerPage> {
  final _searchController = TextEditingController();
  late final Future<List<CatalogProduct>> _products =
      ProductCatalogService.load();
  String _brand = 'ALL';
  String _category = 'ALL';
  String _query = '';

  static const _categories = <String>[
    'ALL',
    'BED',
    'CHAIR',
    'MANI PEDI',
    'MASSAGER',
    'SHAMPOO',
    'STOOL',
    'TROLLEY',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text(
          'RBC / RAMA Product Catalogue',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Product code ya category search karein',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('All')),
                      ButtonSegment(value: 'RBC', label: Text('RBC')),
                      ButtonSegment(value: 'RAMA', label: Text('RAMA')),
                    ],
                    selected: {_brand},
                    onSelectionChanged: (value) =>
                        setState(() => _brand = value.first),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: _categories.map((category) {
                      return ChoiceChip(
                        label: Text(
                            category == 'ALL' ? 'All Categories' : category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<CatalogProduct>>(
                      future: _products,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final filtered = snapshot.data!.where((product) {
                          final brandMatch =
                              _brand == 'ALL' || product.brand == _brand;
                          final categoryMatch = _category == 'ALL' ||
                              (_category == 'SHAMPOO'
                                  ? product.category.startsWith('SHAMPOO')
                                  : product.category == _category);
                          final text =
                              '${product.brand} ${product.category} ${product.code} ${product.name}'
                                  .toLowerCase();
                          return brandMatch &&
                              categoryMatch &&
                              (_query.isEmpty || text.contains(_query));
                        }).toList(growable: false);
                        if (filtered.isEmpty) {
                          return const Center(
                              child: Text('Koi matching product nahi mila.'));
                        }
                        return GridView.builder(
                          clipBehavior: Clip.hardEdge,
                          padding: const EdgeInsets.only(top: 2, bottom: 16),
                          itemCount: filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisExtent: 218,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return InkWell(
                              onTap: () => Navigator.pop(context, product),
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(11)),
                                        child: Image.asset(
                                          product.photoAsset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                                Icons.broken_image_outlined,
                                                color: AppColors.slate,
                                                size: 34),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(product.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          Text(product.category,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.slate)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
