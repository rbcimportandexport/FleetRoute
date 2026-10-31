import 'package:flutter/material.dart';

import '../services/product_catalog_service.dart';
import '../theme/app_theme.dart';

/// Reusable Product Catalog Picker (RBC / RAMA)
/// Displays searchable catalogue with category chips, product photos and specs.
class ProductCatalogPickerPage extends StatefulWidget {
  const ProductCatalogPickerPage({
    this.initialSelected = const [],
    super.key,
  });

  final List<CatalogProduct> initialSelected;

  static Future<List<CatalogProduct>?> show(
    BuildContext context, {
    List<CatalogProduct> initialSelected = const [],
  }) {
    return Navigator.of(context).push<List<CatalogProduct>>(
      MaterialPageRoute(
        builder: (_) => ProductCatalogPickerPage(
          initialSelected: initialSelected,
        ),
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
  final List<CatalogProduct> _selectedItems = [];
  String _brand = 'ALL';
  String _category = 'ALL';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedItems.addAll(widget.initialSelected);
  }

  void _toggleProduct(CatalogProduct product) {
    setState(() {
      final index = _selectedItems.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems.add(product);
      }
    });
  }

  bool _isSelected(CatalogProduct product) {
    return _selectedItems.any((p) => p.id == product.id);
  }

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
        title: Text(
          _selectedItems.isEmpty
              ? 'RBC / RAMA Product Catalogue'
              : "${_selectedItems.length} Products Selected",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_selectedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _selectedItems),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  "Add (${_selectedItems.length})",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
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
                          padding: const EdgeInsets.only(top: 2, bottom: 80),
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
                            final isSel = _isSelected(product);

                            return InkWell(
                              onTap: () => _toggleProduct(product),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFF0FDF4) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF10B981)
                                        : AppColors.border,
                                    width: isSel ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isSel
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x2210B981),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    Column(
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
                                              Text(
                                                product.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: isSel
                                                      ? const Color(0xFF065F46)
                                                      : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                product.category,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.slate,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSel
                                              ? const Color(0xFF10B981)
                                              : Colors.black.withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSel
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selectedItems.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ' Products Selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, _selectedItems),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      label: const Text(
                        'Confirm Selection',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
