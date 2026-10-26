import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';

class DeliveryProofDialog extends StatefulWidget {
  const DeliveryProofDialog({
    required this.trip,
    required this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController controller;

  @override
  State<DeliveryProofDialog> createState() => _DeliveryProofDialogState();
}

class _DeliveryProofDialogState extends State<DeliveryProofDialog> {
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _deliveredQtyController = TextEditingController();
  final _damagedQtyController = TextEditingController(text: '0');
  final _returnedQtyController = TextEditingController(text: '0');
  final _reasonController = TextEditingController();

  final List<List<Offset>> _signatureStrokes = [];
  String? _signatureBase64;
  String? _photoBase64;
  Uint8List? _photoBytes;

  double? _currentLat;
  double? _currentLng;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recipientNameController.text = widget.trip.customerName;
    _deliveredQtyController.text = widget.trip.totalRemainingCargo > 0
        ? widget.trip.totalRemainingCargo.toStringAsFixed(0)
        : (widget.trip.totalLoadedCargo > 0
            ? widget.trip.totalLoadedCargo.toStringAsFixed(0)
            : '1');
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _deliveredQtyController.dispose();
    _damagedQtyController.dispose();
    _returnedQtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _currentLat = pos.latitude;
            _currentLng = pos.longitude;
            _isLocating = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  Future<String?> _exportSignatureToBase64() async {
    if (_signatureStrokes.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = 360.0;
      const height = 160.0;

      // Draw white background
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

      // Draw signature strokes
      final strokePaint = Paint()
        ..color = const Color(0xFF0F2440)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      for (final stroke in _signatureStrokes) {
        if (stroke.length < 2) continue;
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, strokePaint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }
    } catch (_) {}
    return null;
  }

  void _triggerPhotoCapture(bool useCamera) {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: useCamera,
      onPhotoSelected: (base64Data) {
        try {
          final clean = base64Data.contains(',')
              ? base64Data.split(',').last.trim()
              : base64Data.trim();
          final bytes = base64Decode(clean);
          if (bytes.isEmpty || bytes.length > 2621440) {
            if (mounted) {
              setState(() => _errorMessage =
                  'Photo must be a valid image smaller than 2.5 MB.');
            }
            return;
          }
          if (mounted) {
            setState(() {
              _errorMessage = null;
              _photoBase64 = clean;
              _photoBytes = bytes;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() => _errorMessage = 'Selected photo is unreadable.');
          }
        }
      },
      onError: (message) {
        if (mounted) setState(() => _errorMessage = message);
      },
    );
  }

  Future<void> _submitProof() async {
    final name = _recipientNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Recipient name is required.');
      return;
    }

    final phone = _recipientPhoneController.text.trim();
    if (phone.isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() =>
          _errorMessage = 'Valid 10-digit recipient phone number is required.');
      return;
    }

    final deliveredQty =
        double.tryParse(_deliveredQtyController.text.trim()) ?? 0;
    final damagedQty = double.tryParse(_damagedQtyController.text.trim()) ?? 0;
    final returnedQty =
        double.tryParse(_returnedQtyController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();

    if (deliveredQty <= 0 && damagedQty <= 0 && returnedQty <= 0) {
      setState(() =>
          _errorMessage = 'Delivered quantity must be greater than zero.');
      return;
    }

    if ((damagedQty > 0 || returnedQty > 0) && reason.isEmpty) {
      setState(() =>
          _errorMessage = 'Please specify reason for damaged/returned goods.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final sigBase64 =
        await _exportSignatureToBase64() ?? _signatureBase64 ?? '';
    final photoBase64 = _photoBase64 ?? '';

    if (photoBase64.isEmpty && sigBase64.isEmpty && reason.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Photo ya Signature upload karein, ya neeche Reason/Remark likhein (e.g. Challan not given).';
      });
      return;
    }

    final now = DateTime.now();
    final timeStr =
        '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final proof = DeliveryProofRecord(
      id: 'POD-${DateTime.now().millisecondsSinceEpoch}',
      tripId: widget.trip.reference,
      recipientName: name,
      recipientPhone: phone,
      deliveredQuantity: deliveredQty,
      damagedQuantity: damagedQty,
      returnedQuantity: returnedQty,
      damageOrRefusalReason: reason,
      photoBase64: photoBase64,
      signatureBase64: sigBase64,
      latitude: _currentLat ?? 0.0,
      longitude: _currentLng ?? 0.0,
      timestamp: timeStr,
      isConfirmed: true,
    );

    final error = await widget.controller.submitDeliveryProof(
      tripReference: widget.trip.reference,
      proof: proof,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Delivery proof captured successfully! Trip marked delivered.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.assignment_turned_in_rounded,
                    size: 22,
                    padding: 8,
                    radius: 10,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receiving & Delivery Proof (POD)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pahuch / Hastakshar / Photo (Delivery Confirmation)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Geotag Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed_rounded,
                              size: 16, color: AppColors.iconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentLat != null && _currentLng != null
                                  ? 'GPS Geotag: ${_currentLat!.toStringAsFixed(5)}, ${_currentLng!.toStringAsFixed(5)}'
                                  : (_isLocating
                                      ? 'Acquiring GPS fix...'
                                      : 'GPS Geotag Pending'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ),
                          if (_isLocating)
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            InkWell(
                              onTap: _fetchGpsLocation,
                              child: const Icon(Icons.refresh_rounded,
                                  size: 16, color: AppColors.primaryDark),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Recipient Name & Phone
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _recipientNameController,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'sans-serif',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Recipient Name *',
                              hintText: 'e.g. Ramesh Patel',
                              prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _recipientPhoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'sans-serif',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Recipient Phone *',
                              hintText: '10 digits mobile',
                              prefixIcon:
                                  const Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quantity Row: Delivered, Damaged, Returned
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _deliveredQtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Delivered Qty *',
                              hintText: 'e.g. 50',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _damagedQtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Damaged Qty',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _returnedQtyController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Returned Qty',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reason if damaged/returned or no challan
                    TextField(
                      controller: _reasonController,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'sans-serif',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Challan Not Available / Damage / Delivery Remarks',
                        hintText:
                            'e.g. Challan copy not available, direct customer hand-off, or damaged goods note',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Signature Pad Canvas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recipient Digital Signature (हस्ताक्षर / સહી)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        if (_signatureStrokes.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _signatureStrokes.clear();
                                _signatureBase64 = null;
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 14),
                            label: const Text('Clear / मिटाएं'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _signatureStrokes.isNotEmpty
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _signatureStrokes.add([details.localPosition]);
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              if (_signatureStrokes.isNotEmpty) {
                                _signatureStrokes.last
                                    .add(details.localPosition);
                              }
                            });
                          },
                          child: CustomPaint(
                            painter:
                                _SignaturePainter(strokes: _signatureStrokes),
                            child: _signatureStrokes.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Ungli se yahan sign karein (Sign here with finger)',
                                      style: TextStyle(
                                        color: AppColors.slate,
                                        fontSize: 11.5,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  )
                                : const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Proof Capture
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Delivery Photo / Challan Copy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '(Photo ya Sign ya Reason jaruri)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        if (_photoBase64 != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _photoBase64 = null;
                                _photoBytes = null;
                              });
                            },
                            child: const Text('Remove Photo',
                                style: TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 11.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_photoBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.iconBadgeBorder),
                          ),
                          child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _triggerPhotoCapture(true),
                              icon: const Icon(Icons.camera_alt_rounded,
                                  size: 16),
                              label: const Text('CAMERA (फोटो खींचें)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryDark,
                                side: const BorderSide(
                                    color: AppColors.primaryBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _triggerPhotoCapture(false),
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 16),
                              label: const Text('GALLERY (गैलरी)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.navy,
                                side: const BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitProof,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'SAVING PROOF...'
                        : 'CONFIRM DELIVERY & FINISH TRIP (डिलीवरी पूरी करें)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F2440)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// Gallery viewer dialog to inspect delivery proofs, signatures, GPS geotags, and recipient photos
class DeliveryProofGalleryDialog extends StatefulWidget {
  const DeliveryProofGalleryDialog({
    required this.trip,
    required this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController controller;

  @override
  State<DeliveryProofGalleryDialog> createState() =>
      _DeliveryProofGalleryDialogState();
}

class _DeliveryProofGalleryDialogState
    extends State<DeliveryProofGalleryDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DeliveryProofRecord> _getProofs() {
    final list = <DeliveryProofRecord>[];
    final fromController = widget.controller
        .deliveryProofsForTrip(widget.trip.effectiveTripNumber);
    list.addAll(fromController);

    if (widget.trip.deliveryProof != null) {
      if (!list.any((p) => p.id == widget.trip.deliveryProof!.id)) {
        list.add(widget.trip.deliveryProof!);
      }
    }
    for (final p in widget.trip.deliveryProofs) {
      if (!list.any((item) => item.id == p.id)) {
        list.add(p);
      }
    }

    if (_filterQuery.isEmpty) return list;
    final q = _filterQuery.toLowerCase();
    return list.where((p) {
      return p.recipientName.toLowerCase().contains(q) ||
          p.recipientPhone.toLowerCase().contains(q) ||
          p.stopLocation.toLowerCase().contains(q) ||
          p.damageOrRefusalReason.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Google Maps.')),
      );
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place call to $phone.')),
      );
    }
  }

  List<List<Offset>> _parseStrokes(String raw) {
    if (!raw.startsWith('strokes:')) return [];
    try {
      final jsonStr = raw.substring('strokes:'.length);
      final decoded = jsonDecode(jsonStr) as List;
      final result = <List<Offset>>[];
      for (final strokeItem in decoded) {
        if (strokeItem is List) {
          final stroke = <Offset>[];
          for (final pt in strokeItem) {
            if (pt is Map) {
              final x = (pt['x'] as num?)?.toDouble() ?? 0.0;
              final y = (pt['y'] as num?)?.toDouble() ?? 0.0;
              stroke.add(Offset(x, y));
            }
          }
          if (stroke.isNotEmpty) result.add(stroke);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final proofs = _getProofs();
    final hasPod = widget.trip.podPhoto.isNotEmpty;
    final hasReceiving = widget.trip.receivingCopyPhoto.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.verified_user_outlined,
                    size: 20,
                    padding: 7,
                    radius: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Proofs: ${widget.trip.effectiveTripNumber}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.trip.customerName} - ${widget.trip.destination}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _filterQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by recipient, phone, or location...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Proofs list
            Expanded(
              child: (proofs.isEmpty && !hasPod && !hasReceiving)
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (proofs.isNotEmpty) ...[
                          const Text(
                            'CONFIRMED STOP DELIVERIES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate,
                              letterSpacing: 0.5,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (int i = 0; i < proofs.length; i++) ...[
                            _buildProofCard(proofs[i], i + 1),
                            const SizedBox(height: 12),
                          ],
                        ],
                        if (hasPod || hasReceiving) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'OFFICIAL BILLING & TRANSIT COPIES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate,
                              letterSpacing: 0.5,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (hasPod)
                            _buildPhotoCard(
                              title: 'Proof of Delivery (POD)',
                              status: widget.trip.podStatus.toUpperCase(),
                              photoBase64: widget.trip.podPhoto,
                              date: widget.trip.podReceivedAt,
                            ),
                          if (hasPod && hasReceiving)
                            const SizedBox(height: 10),
                          if (hasReceiving)
                            _buildPhotoCard(
                              title: 'Signed Receiving Copy',
                              status:
                                  widget.trip.receivingCopyStatus.toUpperCase(),
                              photoBase64: widget.trip.receivingCopyPhoto,
                              date: '',
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_outlined, size: 48, color: AppColors.slate),
            SizedBox(height: 12),
            Text(
              'No delivery proofs uploaded yet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.navy,
                fontFamily: 'sans-serif',
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Driver will capture recipient signature, geotag, and delivery photo upon reaching destination.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.slate,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofCard(DeliveryProofRecord proof, int index) {
    final strokes = _parseStrokes(proof.signatureBase64);
    final hasStrokes = strokes.isNotEmpty;
    final isImageSig = proof.signatureBase64.isNotEmpty && !hasStrokes;
    final hasGps = proof.latitude != null && proof.longitude != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Stop #, Recipient Name, Timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  'Proof #$index',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proof.recipientName.isNotEmpty
                          ? proof.recipientName
                          : 'Recipient (Authorized Signatory)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (proof.recipientPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 12, color: AppColors.slate),
                          const SizedBox(width: 4),
                          Text(
                            proof.recipientPhone,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _callPhone(proof.recipientPhone),
                            child: const Text(
                              'CALL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (proof.isConfirmed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 11, color: AppColors.primaryDark),
                      SizedBox(width: 3),
                      Text(
                        'CONFIRMED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Quantities summary
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Delivered: ${proof.deliveredQuantity.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
              if (proof.damagedQuantity > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Damaged: ${proof.damagedQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ),
              if (proof.returnedQuantity > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Returned: ${proof.returnedQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ),
            ],
          ),

          // Damage or refusal reason
          if (proof.damageOrRefusalReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_problem_outlined,
                      size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Refusal / Damage: ${proof.damageOrRefusalReason}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // GPS geotag row
          if (hasGps) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'GPS: ${proof.latitude!.toStringAsFixed(5)}, ${proof.longitude!.toStringAsFixed(5)} (${proof.timestamp})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _openMaps(proof.latitude!, proof.longitude!),
                    child: const Text(
                      'OPEN MAPS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Signature and Photo previews
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Signature visualizer
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: hasStrokes
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            size: const Size(double.infinity, 100),
                            painter: _SignaturePainter(strokes: strokes),
                          ),
                        )
                      : (isImageSig
                          ? _buildImage(proof.signatureBase64)
                          : const Center(
                              child: Text(
                                'Digital Signature Captured',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.slate,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )),
                ),
              ),

              // Photo preview if available
              if (proof.photoBase64.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _buildImage(proof.photoBase64),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard({
    required String title,
    required String status,
    required String photoBase64,
    required String date,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Received: $date',
              style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _buildImage(photoBase64),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String base64Str) {
    try {
      final clean = base64Str.contains(',')
          ? base64Str.split(',').last.trim()
          : base64Str.trim();
      final bytes = base64Decode(clean);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    } catch (_) {
      return const Center(
        child:
            Icon(Icons.broken_image_outlined, size: 32, color: AppColors.slate),
      );
    }
  }
}
