import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet to capture/upload Hotel / Dhaba stay bills and food photos
class HotelStayMealExpenseSheet extends StatefulWidget {
  const HotelStayMealExpenseSheet({
    required this.controller,
    this.trip,
    this.hotelName = '',
    super.key,
  });

  final PlannerController controller;
  final TripRecord? trip;
  final String hotelName;

  static Future<void> show(
    BuildContext context, {
    required PlannerController controller,
    TripRecord? trip,
    String hotelName = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HotelStayMealExpenseSheet(
        controller: controller,
        trip: trip,
        hotelName: hotelName,
      ),
    );
  }

  @override
  State<HotelStayMealExpenseSheet> createState() =>
      _HotelStayMealExpenseSheetState();
}

class _HotelStayMealExpenseSheetState extends State<HotelStayMealExpenseSheet> {
  final _hotelNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  Uint8List? _billPhotoBytes;
  String _billPhotoBase64 = '';

  Uint8List? _foodPhotoBytes;
  String _foodPhotoBase64 = '';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.hotelName.isNotEmpty) {
      _hotelNameController.text = widget.hotelName;
    }
  }

  @override
  void dispose() {
    _hotelNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _pickPhoto({required bool isBill, required bool useCamera}) {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: useCamera,
      onPhotoSelected: (base64Data) {
        try {
          String clean = base64Data;
          if (clean.contains(',')) clean = clean.split(',').last;
          final bytes = base64Decode(clean.trim());
          if (bytes.isEmpty) return;

          setState(() {
            if (isBill) {
              _billPhotoBytes = bytes;
              _billPhotoBase64 = clean.trim();
            } else {
              _foodPhotoBytes = bytes;
              _foodPhotoBase64 = clean.trim();
            }
          });
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo select nahi ho paayi.')),
            );
          }
        }
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        }
      },
    );
  }

  Future<void> _submitStayAndMeal() async {
    final hotelName = _hotelNameController.text.trim();
    final amountText = _amountController.text.trim();
    final notes = _notesController.text.trim();

    if (_billPhotoBase64.isEmpty && _foodPhotoBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kripya khane ki photo ya hotel bill ki photo upload karein.'),
          backgroundColor: Color(0xFFEA580C),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final double amount = double.tryParse(amountText) ?? 0.0;
    final effectiveVehicle = widget.trip?.assignedVehicle.isNotEmpty == true
        ? widget.trip!.assignedVehicle
        : (widget.controller.currentDriver?.assignedVehicle ?? 'UNASSIGNED');
    final effectiveDriverName = widget.controller.loggedInName ??
        widget.controller.currentDriver?.name ??
        'Driver';
    final effectiveDriverId = widget.controller.loggedInEmail ??
        widget.controller.currentDriver?.email ??
        'unassigned';

    final hotelTitle = hotelName.isNotEmpty ? hotelName : 'Hotel / Dhaba Stay';
    final now = DateTime.now();

    // 1. If food photo provided, store as Meal Photo Record
    if (_foodPhotoBase64.isNotEmpty) {
      await widget.controller.submitDriverPhotoRecord(
        category: 'Hotel Food & Meal',
        photoBase64: _foodPhotoBase64,
        vehicleNumber: effectiveVehicle,
        notes: '$hotelTitle - Khane ki photo${notes.isNotEmpty ? " ($notes)" : ""}',
      );
    }

    // 2. If bill photo provided, store as Hotel/Dhaba Bill Record
    if (_billPhotoBase64.isNotEmpty) {
      await widget.controller.submitDriverPhotoRecord(
        category: 'Hotel / Dhaba Bill',
        photoBase64: _billPhotoBase64,
        vehicleNumber: effectiveVehicle,
        notes: '$hotelTitle - Bill ₹${amount.toStringAsFixed(0)}${notes.isNotEmpty ? " ($notes)" : ""}',
      );
    }

    // 3. Register as an ExpenseRecord if amount or bill is present
    if (amount > 0 || _billPhotoBase64.isNotEmpty) {
      final expense = ExpenseRecord(
        id: 'EXP-HOTEL-${now.millisecondsSinceEpoch}',
        tripId: widget.trip?.reference ?? '',
        vehicleNumber: effectiveVehicle,
        driverId: effectiveDriverId,
        driverName: effectiveDriverName,
        category: 'Food & Stay',
        isDirect: true,
        amount: amount > 0 ? amount : 0.0,
        date: now.toIso8601String().substring(0, 10),
        receiptBase64: _billPhotoBase64.isNotEmpty
            ? _billPhotoBase64
            : _foodPhotoBase64,
        notes: '$hotelTitle${notes.isNotEmpty ? " - $notes" : ""}',
        createdBy: effectiveDriverName,
        createdAt: now.toIso8601String(),
      );
      await widget.controller.addExpense(expense);
    }

    // 4. Log alert note for admin/driver timeline
    final alert = OperationsAlert(
      id: 'stay_${now.millisecondsSinceEpoch}',
      category: 'Hotel Stay & Meal',
      title: '🍽️ $hotelTitle',
      details:
          'Driver $effectiveDriverName halted at $hotelTitle. Bill: ₹${amount.toStringAsFixed(0)} · Photos uploaded.',
      createdAt: now.toIso8601String(),
      severity: 'info',
      vehicleNumber: effectiveVehicle,
    );
    widget.controller.alerts.insert(0, alert);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $hotelTitle: Khana aur bill record safalta se save ho gaya!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hotel Stay, Khana & Bill Entry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Hotel par rukne par khane ki photo aur bill attach karein',
                        style: TextStyle(fontSize: 11, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.slate),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),

            // Hotel / Dhaba Name Field
            TextField(
              controller: _hotelNameController,
              decoration: InputDecoration(
                labelText: 'Hotel ya Dhaba Ka Naam',
                hintText: 'e.g. Rajput Dhaba, Highway Kings Hotel',
                prefixIcon: const Icon(Icons.hotel_rounded, color: Color(0xFFEA580C)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Bill Amount (Kharcha ₹)',
                hintText: 'e.g. 250',
                prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF16A34A)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // TWO PHOTO CAPTURE CARDS: (1) Khane Ki Photo & (2) Hotel Bill Ki Photo
            Row(
              children: [
                // 1. Food Photo Box
                Expanded(
                  child: _buildPhotoUploadBox(
                    title: '🍽️ Khane Ki Photo',
                    subtitle: 'Food / Thali Photo',
                    bytes: _foodPhotoBytes,
                    isBill: false,
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Bill Photo Box
                Expanded(
                  child: _buildPhotoUploadBox(
                    title: '🧾 Bill Ki Photo',
                    subtitle: 'Hotel / Dhaba Receipt',
                    bytes: _billPhotoBytes,
                    isBill: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Extra Notes / Description (Optional)',
                hintText: 'e.g. Rat ka khana + Chai break',
                prefixIcon: const Icon(Icons.note_alt_rounded, color: AppColors.slate),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            FilledButton.icon(
              onPressed: _isSaving ? null : _submitStayAndMeal,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isSaving ? 'Record Jama Ho Raha Hai...' : 'Khana Aur Bill Jama Karein',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoUploadBox({
    required String title,
    required String subtitle,
    required Uint8List? bytes,
    required bool isBill,
  }) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bytes != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
          width: bytes != null ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (bytes != null)
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isBill ? Icons.receipt_rounded : Icons.restaurant_menu_rounded,
                          size: 26,
                          color: const Color(0xFFEA580C),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 9.5, color: AppColors.slate),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(isBill: isBill, useCamera: true),
                  icon: const Icon(Icons.camera_alt, size: 13),
                  label: const Text('Camera', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPhoto(isBill: isBill, useCamera: false),
                  icon: const Icon(Icons.photo_library, size: 13),
                  label: const Text('Gallery', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
