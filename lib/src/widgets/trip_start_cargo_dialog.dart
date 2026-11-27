import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/planner_controller.dart';
import '../models/driver_models.dart';
import '../services/bill_ocr_parser_service.dart';
import '../services/driver_database_service.dart';
import '../services/image_blur_detection_service.dart';

/// Pre-Trip Cargo, Bill & Customer Verification Sheet / Dialog
/// When START navigation button is tapped:
/// 1. Auto-shows: Origin (कहाँ से), Destination (कहाँ तक), Distance (दूरी KM)
/// 2. Auto-fills: Customer Name & Mobile Number
/// 3. Minimal driver inputs:
///    - Bill photo (बिल्टी / बिल फोटो)
///    - Cartons count (कार्टन संख्या)
///    - Carton photo (कार्टन / माल फोटो)
class TripStartCargoDialog extends StatefulWidget {
  final String origin;
  final String destination;
  final double distanceKm;
  final String? customerName;
  final String? customerPhone;
  final PlannerController controller;

  const TripStartCargoDialog({
    super.key,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    this.customerName,
    this.customerPhone,
    required this.controller,
  });

  static Future<bool> show(
    BuildContext context, {
    required String origin,
    required String destination,
    required double distanceKm,
    String? customerName,
    String? customerPhone,
    required PlannerController controller,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripStartCargoDialog(
        origin: origin,
        destination: destination,
        distanceKm: distanceKm,
        customerName: customerName,
        customerPhone: customerPhone,
        controller: controller,
      ),
    );
    return result ?? false;
  }

  @override
  State<TripStartCargoDialog> createState() => _TripStartCargoDialogState();
}

class _TripStartCargoDialogState extends State<TripStartCargoDialog> {
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _cartonCountController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;

  Uint8List? _billImageBytes;
  String _billImageBase64 = '';

  Uint8List? _cartonImageBytes;
  String _cartonImageBase64 = '';

  Uint8List? _meterImageBytes;
  String _meterImageBase64 = '';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Keep empty until bill photo is uploaded / scanned by the driver!
    _cartonCountController = TextEditingController(text: '');
    _customerNameController = TextEditingController(text: '');
    _customerPhoneController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _cartonCountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required bool isBill,
    required ImageSource source,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 98, // Keep maximum resolution for OCR precision
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      if (isBill) {
        // Blur Detection: Reject excessively blurry bill photos
        final blurCheck = ImageBlurDetectionService.instance.checkBlur(bytes);
        if (blurCheck.isBlurry) {
          if (mounted) {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.blur_on_rounded, color: Color(0xFFDC2626), size: 28),
                    SizedBox(width: 8),
                    Text('फोटो धुंधली (Blur) है', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
                content: const Text(
                  'बिल / बिल्टी की यह फोटो धुंधली (Blur) है और अक्षर साफ नहीं दिख रहे हैं।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ व स्पष्ट फोटो खींचें।',
                  style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
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
      }

      final base64Str = base64Encode(bytes);

      if (isBill) {
        // Automatically extract: Customer Name, Phone, and Total Carton Quantity from bill using ML Kit OCR
        final parsed = await ParsedBillDetails.extractFromBytes(
          bytes,
          fileName: picked.name,
          filePath: picked.path,
        );
        setState(() {
          _billImageBytes = bytes;
          _billImageBase64 = base64Str;
          // Set to parsed value or leave empty for driver to write (never force old hardcoded name!)
          if (parsed.customerName.isNotEmpty) {
            _customerNameController.text = parsed.customerName;
          }
          if (parsed.customerPhone.isNotEmpty) {
            _customerPhoneController.text = parsed.customerPhone;
          }
          _cartonCountController.text = '${parsed.totalCartons}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _customerNameController.text.isNotEmpty
                    ? '✅ बिल रीड हुआ: ${_customerNameController.text} (${_customerPhoneController.text}) | कार्टन: ${_cartonCountController.text}'
                    : 'बिल लोड हुआ! कृपया ग्राहक का नाम व विवरण जांचें।',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _cartonImageBytes = bytes;
          _cartonImageBase64 = base64Str;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickMeterImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();

      // Check if meter reading photo is blurry or unreadable
      final blurCheck = ImageBlurDetectionService.instance.checkBlur(bytes);
      if (blurCheck.isBlurry) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.blur_on_rounded, color: Color(0xFFDC2626), size: 28),
                  SizedBox(width: 8),
                  Text('मीटर फोटो धुंधली (Blur) है', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: const Text(
                'गाड़ी के मीटर (KM) की फोटो धुंधली है और रीडिंग साफ नहीं दिख रही।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ फोटो लें।',
                style: TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
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

      final base64Str = base64Encode(bytes);
      setState(() {
        _meterImageBytes = bytes;
        _meterImageBase64 = base64Str;
      });
    } catch (e) {
      debugPrint('Error picking meter image: $e');
    }
  }

  Future<void> _pickPdfDocument() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();

      final base64Str = base64Encode(bytes);
      final parsed = await ParsedBillDetails.extractFromBytes(
        bytes,
        fileName: file.name,
        filePath: file.path,
      );

      setState(() {
        _billImageBytes = bytes;
        _billImageBase64 = base64Str;
        // Dynamically set from parsed document or leave empty
        if (parsed.customerName.isNotEmpty) {
          _customerNameController.text = parsed.customerName;
        }
        if (parsed.customerPhone.isNotEmpty) {
          _customerPhoneController.text = parsed.customerPhone;
        }
        _cartonCountController.text = '${parsed.totalCartons}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _customerNameController.text.isNotEmpty
                  ? '✅ PDF बिल सेट हुआ: ${file.name} | ग्राहक: ${_customerNameController.text} | कार्टन: ${_cartonCountController.text}'
                  : 'PDF बिल लोड हुआ: ${file.name}',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking PDF document: $e');
    }
  }

  Future<void> _onConfirmAndStart() async {
    final cartons = _cartonCountController.text.trim();
    if (cartons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया कार्टन की संख्या दर्ज करें'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_billImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया बिल / बिल्टी की फोटो जोड़ें'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_cartonImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया लोड कार्टन / माल की फोटो जोड़ें'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_meterImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया ट्रिप शुरू करने से पहले मीटर (KM) की फोटो जोड़ें'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      // Save initial meter reading photo log
      if (_meterImageBytes != null) {
        final meterRecord = PhotoLogRecord(
          id: 'METER_START_${now.millisecondsSinceEpoch}',
          type: SmartCaptureType.meterOdometer,
          time: now,
          location: widget.origin.isNotEmpty ? widget.origin : 'सुरत (Surat)',
          summary: 'ट्रिप शुरू मीटर रीडिंग फोटो | गंतव्य: ${widget.destination}',
          docNumber: 'START-${now.millisecondsSinceEpoch.toString().substring(7)}',
          vendor: 'गाड़ी मीटर (KM)',
          imageBase64: _meterImageBase64,
          imageBytes: _meterImageBytes,
        );
        await DriverDatabaseService.instance.savePhotoLogRecord(meterRecord);
      }

      final record = PhotoLogRecord(
        id: 'TRIP_START_${now.millisecondsSinceEpoch}',
        type: SmartCaptureType.biltyCustomer,
        time: now,
        location: widget.origin.isNotEmpty ? widget.origin : 'सुरत (Surat)',
        summary:
            'ट्रिप स्टार्ट: $cartons कार्टन | ग्राहक: ${_customerNameController.text.trim()} (${_customerPhoneController.text.trim()}) | गंतव्य: ${widget.destination} (${widget.distanceKm.toStringAsFixed(1)} KM)',
        docNumber: 'BL-${now.millisecondsSinceEpoch.toString().substring(7)}',
        vendor: _customerNameController.text.trim(),
        imageBase64: _billImageBase64,
        imageBytes: _billImageBytes,
        secondaryImageBase64: _cartonImageBase64,
        secondaryImageBytes: _cartonImageBytes,
      );

      await DriverDatabaseService.instance.savePhotoLogRecord(record);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(true); // Don't block driver on network failure
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final originText = widget.origin.isNotEmpty
        ? widget.origin
        : 'RBC SALON FURNITURE, Aradhna Industrial Estate';
    final destText = widget.destination.isNotEmpty
        ? widget.destination
        : 'ग्राहक डिलीवरी पता (Customer Delivery Location)';
    final distText = widget.distanceKm > 0
        ? '${widget.distanceKm.toStringAsFixed(1)} KM'
        : '31.4 KM';

    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ट्रिप शुरू करने से पहले बिल व माल विवरण',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'रूट व ग्राहक विवरण ऑटोमैटिक भरा गया है',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Automatic Route & Distance Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            const Text(
                              'ऑटोमैटिक रूट व दूरी (Route Info)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                distText,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // From -> To
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.trip_origin, size: 16, color: Color(0xFF16A34A)),
                                Container(width: 2, height: 26, color: Colors.grey.shade300),
                                const Icon(Icons.location_on, size: 16, color: Color(0xFFEF4444)),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'कहाँ से: $originText',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'कहाँ तक: $destText',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Automatic Customer Name & Mobile
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_pin, size: 18, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Text(
                              'ग्राहक विवरण (ऑटोमैटिक)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _customerNameController,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'ग्राहक का नाम',
                                  hintText: 'बिल फोटो से अपने आप आएगा',
                                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                  labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.person, size: 16),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _customerPhoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'मोबाइल नंबर',
                                  hintText: 'ऑटोमैटिक',
                                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                  labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                  prefixIcon: const Icon(Icons.phone, size: 16),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Cartons Count Field (Driver input)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'कितने कार्टन ले जा रहे हैं?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              Text(
                                'गाड़ी में लोड कुल कार्टन संख्या',
                                style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _cartonCountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                            decoration: InputDecoration(
                              suffixText: 'कार्टन',
                              suffixStyle: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Two Photo Slots: Bill Photo & Carton Photo
                  Row(
                    children: [
                      // Photo 1: Bill Photo
                      Expanded(
                        child: _buildPhotoUploadCard(
                          title: '१. बिल / बिल्टी फोटो',
                          subtitle: 'कस्टमर चालान / बिल / PDF',
                          icon: Icons.receipt_long,
                          imageBytes: _billImageBytes,
                          onCamera: () => _pickImage(isBill: true, source: ImageSource.camera),
                          onGallery: () => _pickPdfDocument(), // Directly opens system file picker supporting both PDF and Photos!
                          onRemove: () => setState(() {
                            _billImageBytes = null;
                            _billImageBase64 = '';
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Photo 2: Carton Photo
                      Expanded(
                        child: _buildPhotoUploadCard(
                          title: '२. कार्टन / माल फोटो',
                          subtitle: 'गाड़ी में लोड कार्टन',
                          icon: Icons.photo_camera_back,
                          imageBytes: _cartonImageBytes,
                          onCamera: () => _pickImage(isBill: false, source: ImageSource.camera),
                          onGallery: () => _pickImage(isBill: false, source: ImageSource.gallery),
                          onRemove: () => setState(() {
                            _cartonImageBytes = null;
                            _cartonImageBase64 = '';
                          }),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Photo 3: Initial Meter / Odometer Photo (ट्रिप शुरू मीटर फोटो)
                  _buildPhotoUploadCard(
                    title: '३. गाड़ी मीटर (KM) फोटो (शुरू करने से पहले)',
                    subtitle: 'डैशबोर्ड ओडोमीटर / करंट KM रीडिंग',
                    icon: Icons.speed_rounded,
                    imageBytes: _meterImageBytes,
                    onCamera: () => _pickMeterImage(ImageSource.camera),
                    onGallery: () => _pickMeterImage(ImageSource.gallery),
                    onRemove: () => setState(() {
                      _meterImageBytes = null;
                      _meterImageBase64 = '';
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: EdgeInsets.fromLTRB(18, 12, 18, mq.viewInsets.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _onConfirmAndStart,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.navigation, color: Colors.white, size: 22),
                label: Text(
                  _isSaving ? 'सेव हो रहा है...' : 'कन्फर्म करें व नेविगेशन शुरू करें',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreviewWidget(Uint8List bytes) {
    final isPdf = bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F

    if (isPdf) {
      return Container(
        height: 95,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 36, color: Color(0xFFDC2626)),
            SizedBox(height: 4),
            Text(
              'PDF बिल लोड हुआ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes,
        height: 95,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 95,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_rounded, size: 32, color: Color(0xFF2563EB)),
                SizedBox(height: 4),
                Text('बिल दस्तावेज़ सेट', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Uint8List? imageBytes,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required VoidCallback onRemove,
  }) {
    final hasImage = imageBytes != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
          width: hasImage ? 1.8 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: hasImage ? const Color(0xFF16A34A) : Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasImage) ...[
            Stack(
              children: [
                _buildPhotoPreviewWidget(imageBytes),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text('दस्तावेज़ सेट', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              height: 75,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_present_rounded, color: Colors.grey, size: 24),
                    SizedBox(height: 4),
                    Text('फोटो / PDF जोड़ें', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt, size: 14),
                  label: const Text('कैमरा', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library, size: 14),
                  label: const Text('गैलरी / फाइल', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF475569),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
