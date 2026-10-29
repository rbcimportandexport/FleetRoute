import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/product_catalog_service.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';
import 'product_catalog_picker_page.dart';

/// Pre-Trip Customer & Cargo Intake Dialog.
/// Mandatory verification of customer name, phone, goods description,
/// cargo photos (camera/gallery), weight (Ton/KG), and delivery notes
/// before trip / live navigation starts.
class PreTripCustomerDetailsDialog extends StatefulWidget {
  const PreTripCustomerDetailsDialog({
    required this.controller,
    required this.origin,
    required this.destination,
    super.key,
  });

  final PlannerController controller;
  final String origin;
  final String destination;

  static Future<bool> show(
    BuildContext context, {
    required PlannerController controller,
    required String origin,
    required String destination,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PointerInterceptor(
        child: PreTripCustomerDetailsDialog(
          controller: controller,
          origin: origin,
          destination: destination,
        ),
      ),
    );
    return res ?? false;
  }

  @override
  State<PreTripCustomerDetailsDialog> createState() =>
      _PreTripCustomerDetailsDialogState();
}

class _PreTripCustomerDetailsDialogState
    extends State<PreTripCustomerDetailsDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cargoDescController;
  late final TextEditingController _weightController;
  late final TextEditingController _instructionsController;

  CustomerRecord? _selectedCustomer;
  CatalogProduct? _selectedCatalogProduct;
  bool _isSaving = false;
  String _weightUnit = 'Ton'; // 'Ton' or 'KG'
  final List<String> _cargoPhotoBase64List = [];

  @override
  void initState() {
    super.initState();

    // Check if an existing trip or customer matches
    TripRecord? activeTrip;
    for (final t in widget.controller.trips) {
      if (t.origin.trim().toLowerCase() == widget.origin.trim().toLowerCase() ||
          t.destination.trim().toLowerCase() ==
              widget.destination.trim().toLowerCase()) {
        activeTrip = t;
        break;
      }
    }

    String initialCust = activeTrip?.customerName ?? '';
    String initialCargo = activeTrip?.cargoDescription ?? '';
    double initialWeight = activeTrip?.totalLoadedCargo ?? 0;

    _customerNameController = TextEditingController(text: initialCust);
    _phoneController = TextEditingController();
    _cargoDescController = TextEditingController(
      text: initialCargo.isNotEmpty ? initialCargo : 'Industrial Cargo',
    );
    _weightController = TextEditingController(
      text: initialWeight > 0 ? initialWeight.toStringAsFixed(1) : '1.0',
    );
    _instructionsController = TextEditingController(
      text: activeTrip?.driverInstructions ?? '',
    );

    // If matches any directory customer, populate phone & instructions
    if (initialCust.isNotEmpty) {
      for (final c in widget.controller.customers) {
        if (c.name.trim().toLowerCase() == initialCust.trim().toLowerCase()) {
          _selectedCustomer = c;
          _phoneController.text = c.phone;
          if (_instructionsController.text.isEmpty) {
            _instructionsController.text = c.deliveryInstructions;
          }
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _cargoDescController.dispose();
    _weightController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addCargoPhoto({required bool useCamera}) {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: useCamera,
      onPhotoSelected: (base64) {
        if (!mounted) return;
        setState(() {
          _cargoPhotoBase64List.add(base64);
        });
      },
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      },
    );
  }

  void _onCustomerSelected(CustomerRecord customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _phoneController.text = customer.phone;
      if (customer.deliveryInstructions.isNotEmpty) {
        _instructionsController.text = customer.deliveryInstructions;
      }
    });
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final customerName = _customerNameController.text.trim();
    final phone = _phoneController.text.trim();
    final cargoDesc = _cargoDescController.text.trim();
    final rawWeight = double.tryParse(_weightController.text.trim()) ?? 1.0;
    // Calculate normalized Ton weight for fleet capacity
    final weightInTon = _weightUnit == 'KG' ? (rawWeight / 1000.0) : rawWeight;
    final instructions = _instructionsController.text.trim();

    setState(() => _isSaving = true);

    try {
      // 1. Save or update customer in directory if new
      final existingCustIdx = widget.controller.customers.indexWhere(
        (c) => c.name.trim().toLowerCase() == customerName.toLowerCase(),
      );

      if (existingCustIdx >= 0) {
        if (phone.isNotEmpty &&
            widget.controller.customers[existingCustIdx].phone.isEmpty) {
          final updated = widget.controller.customers[existingCustIdx].copyWith(
            phone: phone,
            deliveryInstructions: instructions.isNotEmpty
                ? instructions
                : widget.controller.customers[existingCustIdx]
                    .deliveryInstructions,
          );
          await widget.controller.updateCustomer(updated);
        }
      } else {
        final newCust = CustomerRecord(
          id: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
          name: customerName,
          phone: phone,
          deliveryInstructions: instructions,
          createdAt: DateTime.now().toIso8601String(),
        );
        await widget.controller.addCustomer(newCust);
      }

      // 2. Link or create active trip record so customer and cargo details persist
      final truckIdx = widget.controller.truckIndex ?? 0;
      final vehicleCode = widget.controller.truckModels.isNotEmpty
          ? widget
              .controller
              .truckModels[
                  truckIdx.clamp(0, widget.controller.truckModels.length - 1)]
              .code
          : '';

      final activeDriver = widget.controller.selectedDriver;
      final driverName = widget.controller.loggedInName ??
          activeDriver?.name ??
          widget.controller.activeDriverName ??
          'Primary Driver';

      // Find matching active trip or create a new trip record
      final existingTripIdx = widget.controller.trips.indexWhere(
        (t) =>
            t.origin.trim().toLowerCase() == widget.origin.trim().toLowerCase() &&
            t.destination.trim().toLowerCase() ==
                widget.destination.trim().toLowerCase() &&
            t.status != 'completed',
      );

      final tripRef = existingTripIdx >= 0
          ? widget.controller.trips[existingTripIdx].reference
          : 'TRIP-${DateTime.now().millisecondsSinceEpoch % 1000000}';

      final primaryPhoto = _cargoPhotoBase64List.isNotEmpty
          ? _cargoPhotoBase64List.first
          : '';

      final record = TripRecord(
        reference: tripRef,
        tripNumber: tripRef,
        customerName: customerName,
        assignedVehicle: vehicleCode,
        assignedDriver: driverName,
        cargoDescription: cargoDesc,
        cargoItems: [
          CargoItem(
            id: 'CI-1',
            productId: _selectedCatalogProduct?.id ?? 'custom-product',
            brand: _selectedCatalogProduct?.brand ?? '',
            category: _selectedCatalogProduct?.category ?? '',
            productName: cargoDesc,
            photoAsset: primaryPhoto.isNotEmpty
                ? primaryPhoto
                : (_selectedCatalogProduct?.photoAsset ?? ''),
            loadedQuantity: weightInTon,
            unit: _weightUnit,
            notes: _cargoPhotoBase64List.length > 1
                ? '${_cargoPhotoBase64List.length} cargo photos attached'
                : (_selectedCatalogProduct != null
                    ? '${_selectedCatalogProduct!.brand} ${_selectedCatalogProduct!.code}'
                    : ''),
          ),
        ],
        driverInstructions: instructions,
        origin: widget.origin,
        destination: widget.destination,
        stops: widget.controller.stops,
        createdAt: DateTime.now().toIso8601String(),
        status: 'in_progress',
        operationalStep: 'started',
      );

      await widget.controller.addTrip(record);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersList = widget.controller.customers;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_ind_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Customer & Trip Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFDC2626),
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                child: Text(
                                  'MANDATORY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Trip start se pehle customer aur maal ki detail anivarya hai',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8)),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route info preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route_rounded,
                                color: AppColors.blue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Route: ${widget.origin}  ${widget.destination}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.controller.stops.isNotEmpty)
                                    Text(
                                      '+ ${widget.controller.stops.length} intermediate stops',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Existing Customers Quick Select (if available)
                      if (customersList.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 14, color: AppColors.blue),
                            SizedBox(width: 6),
                            Text(
                              'Saved Customers (Pehle se save client):',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: customersList.take(6).map((c) {
                              final isSelected = _selectedCustomer?.id == c.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) => _onCustomerSelected(c),
                                  selectedColor:
                                      const Color(0xFF10B981).withValues(alpha: 0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 1. Customer Name
                      const Text(
                        'Customer / Client Name (ग्राहक का नाम) *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Ramesh Patel / ABC Enterprises',
                          prefixIcon: const Icon(Icons.person_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Customer name likhna zaroori hai';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. Customer Phone Number
                      const Text(
                        'Customer Mobile Number (मोबाइल नंबर) *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 9876543210',
                          prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Customer ka phone number zaroori hai';
                          }
                          if (val.trim().length < 8) {
                            return 'Valid phone number dalein (min 8 digits)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Choose RBC / RAMA Product with Photo button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final product = await ProductCatalogPickerPage.show(context);
                          if (product != null && mounted) {
                            setState(() {
                              _selectedCatalogProduct = product;
                              _cargoDescController.text = product.displayName;
                            });
                          }
                        },
                        icon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF10B981)),
                        label: Text(
                          _selectedCatalogProduct == null
                              ? 'Choose RBC / RAMA Product with Photo'
                              : '${_selectedCatalogProduct!.brand} · ${_selectedCatalogProduct!.category} · ${_selectedCatalogProduct!.code}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      if (_selectedCatalogProduct != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  _selectedCatalogProduct!.photoAsset,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                      size: 36,
                                      color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCatalogProduct!.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    Text(
                                      '${_selectedCatalogProduct!.category} · ${_selectedCatalogProduct!.name}',
                                      style: const TextStyle(
                                        color: Color(0xFF047857),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                tooltip: 'Clear selected product',
                                onPressed: () {
                                  setState(() {
                                    _selectedCatalogProduct = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Quick Cargo Presets for Drivers (Chairs, Tables, Beds, Boxes, etc.)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Cargo Presets (कुर्सी, मेज़, बेड आदि):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final preset in [
                                '10 Chairs (कुर्सी)',
                                '4 Tables (मेज़)',
                                '2 Beds (बेड)',
                                '15 Boxes (पेटी)',
                                'Iron / Steel',
                              ])
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    setState(() {
                                      final current = _cargoDescController.text.trim();
                                      if (current.isEmpty || current == 'Industrial Cargo' || current == 'Steel / Goods') {
                                        _cargoDescController.text = preset;
                                      } else if (!current.contains(preset)) {
                                        _cargoDescController.text = '$current, $preset';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      preset,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cargo / Maal (सामान) *',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cargoDescController,
                                  style: const TextStyle(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Steel / Goods',
                                    prefixIcon: const Icon(
                                        Icons.inventory_2_rounded,
                                        size: 18),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Cargo detail likhein';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Weight *',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    // Unit Switcher (Ton / KG)
                                    Container(
                                      height: 22,
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (_weightUnit != 'Ton') {
                                                final cur = double.tryParse(_weightController.text) ?? 0;
                                                setState(() {
                                                  _weightUnit = 'Ton';
                                                  if (cur > 0) {
                                                    _weightController.text = (cur / 1000.0).toStringAsFixed(2);
                                                  }
                                                });
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: _weightUnit == 'Ton' ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                                boxShadow: _weightUnit == 'Ton'
                                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 2)]
                                                    : null,
                                              ),
                                              child: Text(
                                                'Ton',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: _weightUnit == 'Ton' ? FontWeight.w800 : FontWeight.w600,
                                                  color: _weightUnit == 'Ton' ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              if (_weightUnit != 'KG') {
                                                final cur = double.tryParse(_weightController.text) ?? 0;
                                                setState(() {
                                                  _weightUnit = 'KG';
                                                  if (cur > 0) {
                                                    _weightController.text = (cur * 1000.0).toStringAsFixed(0);
                                                  }
                                                });
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: _weightUnit == 'KG' ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                                boxShadow: _weightUnit == 'KG'
                                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 2)]
                                                    : null,
                                              ),
                                              child: Text(
                                                'KG',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: _weightUnit == 'KG' ? FontWeight.w800 : FontWeight.w600,
                                                  color: _weightUnit == 'KG' ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _weightController,
                                  style: const TextStyle(fontSize: 12.5),
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    hintText: _weightUnit == 'KG' ? '500' : '1.5',
                                    suffixText: _weightUnit,
                                    suffixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                  ),
                                  validator: (val) {
                                    final numVal = double.tryParse(val ?? '');
                                    if (numVal == null || numVal <= 0) {
                                      return 'Vajan dalein';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Cargo / Goods Photos (Camera & Gallery upload)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.add_a_photo_rounded,
                                  size: 16, color: Color(0xFF0284C7)),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Cargo / Goods Photos (सामान की फोटो)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              if (_cargoPhotoBase64List.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_cargoPhotoBase64List.length} Added',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _addCargoPhoto(useCamera: true),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                  label: const Text('Camera'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0284C7),
                                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                                    backgroundColor: const Color(0xFFF0F9FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _addCargoPhoto(useCamera: false),
                                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                                    backgroundColor: const Color(0xFFECFDF5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Photos Preview Grid / Scroll
                      if (_cargoPhotoBase64List.isNotEmpty)
                        Container(
                          height: 86,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cargoPhotoBase64List.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              if (idx == _cargoPhotoBase64List.length) {
                                return InkWell(
                                  onTap: () => _addCargoPhoto(useCamera: true),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF94A3B8),
                                        style: BorderStyle.solid,
                                      ),
                                      color: const Color(0xFFF8FAFC),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 24, color: Color(0xFF64748B)),
                                        SizedBox(height: 4),
                                        Text(
                                          'Add More',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final b64 = _cargoPhotoBase64List[idx];
                              Uint8List? bytes;
                              try {
                                final comma = b64.indexOf(',');
                                final clean = comma != -1 ? b64.substring(comma + 1) : b64;
                                bytes = base64Decode(clean.trim());
                              } catch (_) {}

                              return Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: bytes != null
                                        ? Image.memory(
                                            bytes,
                                            fit: BoxFit.cover,
                                            width: 80,
                                            height: 80,
                                          )
                                        : const Icon(Icons.image, color: Colors.grey),
                                  ),
                                  Positioned(
                                    top: 3,
                                    right: 3,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _cargoPhotoBase64List.removeAt(idx);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _addCargoPhoto(useCamera: true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: Color(0xFF0284C7), size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Camera ya Gallery se saman / goods ki photos attach karein',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8), size: 20),
                              ],
                            ),
                          ),
                        ),

                      // 5. Delivery Instructions / Notes
                      const Text(
                        'Delivery Notes / Special Instructions (कोई विशेष निर्देश)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _instructionsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Call customer 30 mins before arrival / Gate 2 par delivery',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel Trip',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submitDetails,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Confirm & Proceed to Safety',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
