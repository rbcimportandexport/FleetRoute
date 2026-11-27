import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/fuel_bill_ocr_service.dart';
import '../services/image_blur_detection_service.dart';
import '../theme/app_theme.dart';

/// Quick Fuel / Diesel Bill Upload Sheet during Navigation
class QuickFuelExpenseSheet extends StatefulWidget {
  const QuickFuelExpenseSheet({
    required this.controller,
    super.key,
  });

  final PlannerController controller;

  static Future<void> show(BuildContext context, {required PlannerController controller}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickFuelExpenseSheet(controller: controller),
    );
  }

  @override
  State<QuickFuelExpenseSheet> createState() => _QuickFuelExpenseSheetState();
}

class _QuickFuelExpenseSheetState extends State<QuickFuelExpenseSheet> {
  final _amountController = TextEditingController();
  final _litersController = TextEditingController();
  final _pumpNameController = TextEditingController();
  final _notesController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  Uint8List? _billBytes;
  String _billBase64 = '';
  Uint8List? _meterBytes;
  String _meterBase64 = '';
  bool _isReadingOcr = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _litersController.dispose();
    _pumpNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickBillPhoto(ImageSource source) async {
    await _pickAndProcessPhoto(source, isMeter: false);
  }

  Future<void> _pickMeterPhoto(ImageSource source) async {
    await _pickAndProcessPhoto(source, isMeter: true);
  }

  Future<void> _pickAndProcessPhoto(ImageSource source, {required bool isMeter}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      // Blur check: Reject blurry pump receipt or dispenser meter
      final blurCheck = ImageBlurDetectionService.instance.checkBlur(bytes);
      if (blurCheck.isBlurry) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.blur_on_rounded, color: Color(0xFFDC2626), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isMeter ? 'मीटर फोटो धुंधली (Blur) है' : 'पंप पर्ची धुंधली (Blur) है',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: Text(
                isMeter
                    ? 'डीजल मशीन के मीटर की फोटो धुंधली (Blur) है और अंक साफ नहीं दिख रहे।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ मीटर फोटो लें।'
                    : 'डीजल पर्ची की फोटो धुंधली (Blur) है और अक्षर साफ नहीं दिख रहे।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ पर्ची फोटो लें।',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ठीक है, दोबारा साफ फोटो लें', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        if (isMeter) {
          _meterBytes = bytes;
          _meterBase64 = base64Encode(bytes);
        } else {
          _billBytes = bytes;
          _billBase64 = base64Encode(bytes);
        }
        _isReadingOcr = true;
      });

      // Run Automatic OCR on Receipt or Machine Meter Screen
      try {
        final parsed = await ParsedFuelDetails.parseFromPhoto(bytes);
        if (mounted) {
          setState(() {
            _isReadingOcr = false;
            if (parsed.amount > 0) {
              _amountController.text = parsed.amount.toStringAsFixed(parsed.amount % 1 == 0 ? 0 : 2);
            }
            if (parsed.liters > 0) {
              _litersController.text = parsed.liters.toStringAsFixed(parsed.liters % 1 == 0 ? 0 : 2);
            }
            if (parsed.pumpName.isNotEmpty) {
              _pumpNameController.text = parsed.pumpName;
            }
          });
          if (parsed.amount > 0 || parsed.liters > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ ऑटो-रीड: ₹${_amountController.text}${_litersController.text.isNotEmpty ? " · ${_litersController.text} L" : ""}',
                ),
                backgroundColor: const Color(0xFF16A34A),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[QuickFuel] OCR parsing failed: $e');
        if (mounted) setState(() => _isReadingOcr = false);
      }
    } catch (e) {
      debugPrint('Error picking fuel photo: $e');
      if (mounted) setState(() => _isReadingOcr = false);
    }
  }

  Future<void> _saveFuelExpense() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final liters = double.tryParse(_litersController.text.trim()) ?? 0.0;
    final pump = _pumpNameController.text.trim();

    if (amount <= 0 && _billBase64.isEmpty && _meterBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया डीजल खर्च की राशि लिखें या मीटर / पर्ची की फोटो जोड़ें।'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final activeTrip = widget.controller.activeTripForCurrentDriver;
      final vehicle = widget.controller.currentDriver?.assignedVehicle ?? '';

      // 1. Add to Controller Expenses
      final now = DateTime.now();
      final newExpense = ExpenseRecord(
        id: 'FUEL-${now.millisecondsSinceEpoch}',
        tripId: activeTrip?.effectiveTripNumber ?? '',
        amount: amount,
        category: 'fuel',
        isDirect: true,
        date: now.toIso8601String().split('T').first,
        vehicleNumber: vehicle,
        notes: 'डीजल: ₹${amount.toStringAsFixed(0)} ${liters > 0 ? "($liters L)" : ""} @ ${pump.isNotEmpty ? pump : "Petrol Pump"}',
        receiptBase64: _billBase64.isNotEmpty ? _billBase64 : _meterBase64,
      );
      await widget.controller.addExpense(newExpense);

      // 2. Update trip diesel expense directly
      if (activeTrip != null && amount > 0) {
        final tIdx = widget.controller.trips.indexWhere((t) => t.reference == activeTrip.reference);
        if (tIdx >= 0) {
          await widget.controller.updateTripExpenses(
            index: tIdx,
            diesel: amount,
            notes: 'डीजल मीटर व पर्ची दर्ज',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ डीजल बिल ₹${amount.toStringAsFixed(0)} सफलतापूर्वक दर्ज हो गया!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('खर्च सेव करने में समस्या: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'डीजल / पेट्रोल खर्च दर्ज करें',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
                      ),
                      Text(
                        'मशीन का मीटर व पंप पर्ची फोटो लें (राशि ऑटो-रीड होगी)',
                        style: TextStyle(fontSize: 11.5, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            if (_isReadingOcr) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
                    SizedBox(width: 10),
                    Text(
                      'AI OCR: मीटर व पर्ची से राशि और लीटर पढ़ा जा रहा है...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 20),

            // Two Photo Slots: 1. Dispenser Meter Photo | 2. Pump Bill Photo
            Row(
              children: [
                // Meter Photo Slot
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _meterBytes != null ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            height: 64,
                            color: Colors.white,
                            child: _meterBytes != null
                                ? Image.memory(_meterBytes!, fit: BoxFit.cover)
                                : const Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 30),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('1. मशीन मीटर फोटो', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          _meterBytes != null ? '✅ मीटर फोटो लोड' : 'रीडिंग स्क्रीन फोटो',
                          style: TextStyle(
                            fontSize: 10,
                            color: _meterBytes != null ? const Color(0xFF16A34A) : AppColors.slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              onPressed: () => _pickMeterPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            IconButton.outlined(
                              onPressed: () => _pickMeterPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(side: const BorderSide(color: Color(0xFFBFDBFE))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Bill/Slip Photo Slot
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _billBytes != null ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            height: 64,
                            color: Colors.white,
                            child: _billBytes != null
                                ? Image.memory(_billBytes!, fit: BoxFit.cover)
                                : const Icon(Icons.receipt_long_rounded, color: Color(0xFF94A3B8), size: 30),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('2. पंप पर्ची फोटो', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          _billBytes != null ? '✅ पर्ची फोटो लोड' : 'डीजल बिल पर्ची',
                          style: TextStyle(
                            fontSize: 10,
                            color: _billBytes != null ? const Color(0xFF16A34A) : AppColors.slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filled(
                              onPressed: () => _pickBillPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            IconButton.outlined(
                              onPressed: () => _pickBillPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(side: const BorderSide(color: Color(0xFFBFDBFE))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount & Liters Fields
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      labelText: 'डीजल खर्च (₹)',
                      hintText: 'e.g. 5000',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _litersController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      labelText: 'लीटर (Liters)',
                      hintText: 'e.g. 55.4',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pump Name / Location
            TextField(
              controller: _pumpNameController,
              decoration: InputDecoration(
                labelText: 'पेट्रोल पंप का नाम / जगह',
                hintText: 'e.g. Indian Oil, Ankleshwar Highway',
                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveFuelExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'डीजल खर्च सेव करें',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
