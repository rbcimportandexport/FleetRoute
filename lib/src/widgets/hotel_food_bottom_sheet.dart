import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/hotel_bill_ocr_service.dart';

class HotelFoodBottomSheet extends StatefulWidget {
  const HotelFoodBottomSheet({
    super.key,
    required this.onCompleted,
    this.vehicleCode = '',
    this.driverName = '',
  });

  final String vehicleCode;
  final String driverName;

  final void Function({
    required Uint8List billBytes,
    required String billBase64,
    required Uint8List dishBytes,
    required String dishBase64,
    required double amount,
    required String hotelName,
    required String notes,
  }) onCompleted;

  @override
  State<HotelFoodBottomSheet> createState() => _HotelFoodBottomSheetState();
}

class _HotelFoodBottomSheetState extends State<HotelFoodBottomSheet> {
  Uint8List? _billBytes;
  String? _billBase64;

  Uint8List? _dishBytes;
  String? _dishBase64;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _hotelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _hotelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto({
    required bool isBill,
    required ImageSource source,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);

      if (mounted) {
        if (isBill) {
          setState(() {
            _billBytes = bytes;
            _billBase64 = base64;
          });

          // Automatically extract amount, hotel name and all dishes using on-device ML Kit
          final parsed = await ParsedHotelBill.parseFromPhoto(bytes, fileName: picked.name);
          if (mounted) {
            setState(() {
              if (parsed.amount > 0) {
                _amountController.text = parsed.amount % 1 == 0
                    ? parsed.amount.toStringAsFixed(0)
                    : parsed.amount.toStringAsFixed(2);
              }
              if (parsed.hotelName.isNotEmpty) {
                _hotelController.text = parsed.hotelName;
              }
              if (parsed.dishesSummary.isNotEmpty) {
                _notesController.text = parsed.dishesSummary;
              }
            });
          }
        } else {
          setState(() {
            _dishBytes = bytes;
            _dishBase64 = base64;
          });
        }

        if (isBill && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('बिल से राशि ₹${_amountController.text} व डिश (${_notesController.text}) ऑटोमैटिक भर दिए गए!'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('फोटो नहीं ली जा सकी। कृपया पुनः प्रयास करें।')),
        );
      }
    }
  }

  void _submit() {
    if (_billBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('कृपया पहले होटल/ढाबा के बिल की फोटो लें!'),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    if (_dishBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('कृपया साथ में खाने/थाली/डिश की फोटो भी अवश्य अटैच करें!'),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      return;
    }

    final amtParsed = double.tryParse(_amountController.text.trim()) ?? 180.0;
    final hotelParsed = _hotelController.text.trim().isNotEmpty
        ? _hotelController.text.trim()
        : 'राजस्थानी हाईवे ढाबा & टी स्टॉल';

    setState(() => _isSubmitting = true);

    widget.onCompleted(
      billBytes: _billBytes!,
      billBase64: _billBase64!,
      dishBytes: _dishBytes!,
      dishBase64: _dishBase64!,
      amount: amtParsed,
      hotelName: hotelParsed,
      notes: _notesController.text.trim(),
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('होटल बिल और खाने की थाली दोनों फोटो सफलतापूर्वक दर्ज हो गईं!'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  Widget _buildPhotoSlot({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isBill,
    required Uint8List? bytes,
  }) {
    final hasPhoto = bytes != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPhoto ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: hasPhoto ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Preview Thumbnail
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: hasPhoto ? Colors.black12 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPhoto ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: hasPhoto
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 160),
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      icon,
                      color: const Color(0xFF64748B),
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Titles & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      hasPhoto
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_empty_rounded,
                      size: 13,
                      color: hasPhoto
                          ? const Color(0xFF16A34A)
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPhoto ? 'फोटो दर्ज हो गई' : 'फोटो अनिवार्य है',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: hasPhoto
                            ? const Color(0xFF16A34A)
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Buttons: Camera & Gallery
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _capturePhoto(isBill: isBill, source: ImageSource.camera),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'कैमरा',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _capturePhoto(isBill: isBill, source: ImageSource.gallery),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'गैलरी',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicleCode.trim().isNotEmpty ? widget.vehicleCode.trim() : 'FLEET';
    final driverName = widget.driverName.trim().isNotEmpty ? widget.driverName.trim() : 'Driver';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 24,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'होटल व खाना खर्चा (बिल + थाली)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'गाड़ी: $vehicle · ड्राइवर: $driverName',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Hotel Bill Photo Slot
                _buildPhotoSlot(
                  title: '1. होटल / ढाबा बिल की पर्ची',
                  subtitle: 'होटल / ढाबा रसीद व बिल',
                  icon: Icons.receipt_long_rounded,
                  isBill: true,
                  bytes: _billBytes,
                ),

                // 2. Dish / Food Photo Slot
                _buildPhotoSlot(
                  title: '2. खाने की थाली / डिश की फोटो',
                  subtitle: 'भोजन की थाली व डिश फोटो',
                  icon: Icons.dinner_dining_rounded,
                  isBill: false,
                  bytes: _dishBytes,
                ),

                const SizedBox(height: 4),

                // Amount Field
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'बिल की कुल राशि (₹ Amount, e.g. 180)',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18, color: Color(0xFF2563EB)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),

                // Hotel Name Field
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _hotelController,
                    decoration: const InputDecoration(
                      hintText: 'होटल / ढाबा का नाम (Optional, e.g. राजस्थानी ढाबा)',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                ),

                // Notes Field
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'टिप्पणी / Note (e.g. दोपहर का खाना, 2 चाय)',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),

          // Submit Bottom Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text(
                'होटल बिल व भोजन फोटो जमा करें',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
