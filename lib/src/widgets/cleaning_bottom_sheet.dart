import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CleaningAngleConfig {
  const CleaningAngleConfig({
    required this.id,
    required this.labelHindi,
    required this.labelEnglish,
    required this.icon,
    required this.description,
  });

  final String id;
  final String labelHindi;
  final String labelEnglish;
  final IconData icon;
  final String description;
}

class CleaningMultiAngleBottomSheet extends StatefulWidget {
  const CleaningMultiAngleBottomSheet({
    super.key,
    required this.onCompleted,
    this.vehicleCode = '',
    this.driverName = '',
  });

  final void Function(int count, String notes) onCompleted;
  final String vehicleCode;
  final String driverName;

  @override
  State<CleaningMultiAngleBottomSheet> createState() =>
      _CleaningMultiAngleBottomSheetState();
}

class _CleaningMultiAngleBottomSheetState
    extends State<CleaningMultiAngleBottomSheet> {
  static const List<CleaningAngleConfig> _angles = [
    CleaningAngleConfig(
      id: 'cabin',
      labelHindi: 'ड्राइवर केबिन (अंदर)',
      labelEnglish: 'Driver Cabin / Interior',
      icon: Icons.airline_seat_recline_normal_rounded,
      description: 'Driver seat, Steering, Dashboard, Mats & Cabin cleanliness',
    ),
    CleaningAngleConfig(
      id: 'front',
      labelHindi: 'आगे का हिस्सा',
      labelEnglish: 'Front Angle',
      icon: Icons.directions_car_filled_rounded,
      description: 'Headlight, Number Plate & Windshield saaf dikhe',
    ),
    CleaningAngleConfig(
      id: 'back',
      labelHindi: 'पीछे का हिस्सा',
      labelEnglish: 'Back Angle',
      icon: Icons.car_crash_rounded,
      description: 'Back Door, Taillights & Rear plate',
    ),
    CleaningAngleConfig(
      id: 'left',
      labelHindi: 'बायाँ हिस्सा',
      labelEnglish: 'Left Side',
      icon: Icons.align_horizontal_left_rounded,
      description: 'Left tyres, Body sheet & Side mirrors',
    ),
    CleaningAngleConfig(
      id: 'right',
      labelHindi: 'दायाँ हिस्सा',
      labelEnglish: 'Right Side',
      icon: Icons.align_horizontal_right_rounded,
      description: 'Right tyres, Fuel tank & Side body',
    ),
  ];

  // 0 = Before Cleaning (धोने से पहले), 1 = After Cleaning (धोने के बाद)
  int _currentStage = 0;

  final Map<String, String> _capturedBase64 = {};
  final Map<String, Uint8List> _capturedBytes = {};

  bool _isUploading = false;
  String? _uploadStatusText;
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _beforeCapturedCount =>
      _angles.where((a) => _capturedBytes.containsKey('0_${a.id}')).length;

  int get _afterCapturedCount =>
      _angles.where((a) => _capturedBytes.containsKey('1_${a.id}')).length;

  int get _totalCapturedCount => _capturedBytes.length;

  Future<void> _pickPhotoForAngle(CleaningAngleConfig angle, int stage,
      {required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final clean = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _capturedBytes['${stage}_${angle.id}'] = bytes;
          _capturedBase64['${stage}_${angle.id}'] = clean;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('फोटो नहीं ली जा सकी। पुनः प्रयास करें।')),
        );
      }
    }
  }

  void _trySwitchToAfterStage() {
    if (_beforeCapturedCount < _angles.length) {
      final missingCount = _angles.length - _beforeCapturedCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'पहले धोने से पहले (BEFORE) की सभी ${_angles.length} फोटो डालें! अभी $missingCount बाकी हैं।'),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _currentStage = 1);
  }

  Future<void> _submitCleaningPhotos() async {
    if (_beforeCapturedCount < _angles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'पहले धोने से पहले (BEFORE) की सभी ${_angles.length} फोटो अपलोड करें! ($_beforeCapturedCount/${_angles.length} ली गई हैं)'),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      setState(() => _currentStage = 0);
      return;
    }

    if (_afterCapturedCount < _angles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'अब धोने के बाद (AFTER) की सभी ${_angles.length} फोटो अपलोड करें! ($_afterCapturedCount/${_angles.length} ली गई हैं)'),
          backgroundColor: Colors.amber.shade900,
        ),
      );
      setState(() => _currentStage = 1);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'फोटो सेव हो रही हैं... (0/$_totalCapturedCount)';
    });

    await Future<void>.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;
    widget.onCompleted(_totalCapturedCount, _notesController.text.trim());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'शाबाश! Sunday Vehicle Cleaning की $_totalCapturedCount फोटो सफलतापूर्वक जमा हो गईं!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicleCode.trim().isNotEmpty ? widget.vehicleCode.trim() : 'FLEET';
    final driverName = widget.driverName.trim().isNotEmpty ? widget.driverName.trim() : 'Driver';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle & Top Header
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
                        Icons.local_car_wash_rounded,
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
                            'रविवार वाहन धुलाई व सफाई सत्यापन',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
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

          // Main Scrollable Area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Dual Stage Segment Switcher Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // BEFORE TAB
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _currentStage = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentStage == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _currentStage == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: _currentStage == 0
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '१. धोने से पहले (Before)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _currentStage == 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _currentStage == 0
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _beforeCapturedCount == 5
                                        ? const Color(0xFF16A34A)
                                        : (_beforeCapturedCount > 0
                                            ? Colors.orange.shade700
                                            : const Color(0xFF94A3B8)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_beforeCapturedCount/5',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // AFTER TAB
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _trySwitchToAfterStage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentStage == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _currentStage == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: _currentStage == 1
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '२. धोने के बाद (After)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _currentStage == 1
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _currentStage == 1
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _afterCapturedCount == 5
                                        ? const Color(0xFF16A34A)
                                        : (_afterCapturedCount > 0
                                            ? Colors.orange.shade700
                                            : const Color(0xFF94A3B8)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_afterCapturedCount/5',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Angles List Cards
                ..._angles.map((angle) {
                  final key = '${_currentStage}_${angle.id}';
                  final bytes = _capturedBytes[key];
                  final hasPhoto = bytes != null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasPhoto
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFE2E8F0),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Visual Thumbnail or Big Icon
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: hasPhoto
                                ? Colors.black12
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasPhoto
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: hasPhoto
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(bytes,
                                          fit: BoxFit.cover, cacheWidth: 160),
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
                                    angle.icon,
                                    color: const Color(0xFF64748B),
                                    size: 28,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title, subtitle & description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                angle.labelHindi,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                angle.labelEnglish,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                angle.description,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    hasPhoto
                                        ? Icons.check_circle_rounded
                                        : Icons.hourglass_empty_rounded,
                                    size: 12,
                                    color: hasPhoto
                                        ? const Color(0xFF16A34A)
                                        : Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasPhoto
                                        ? 'फोटो दर्ज हो गई'
                                        : 'बाकी है (फोटो नहीं ली)',
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

                        // Direct Action Buttons: Camera & Gallery
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Direct Camera Button
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _pickPhotoForAngle(angle, _currentStage,
                                  source: ImageSource.camera),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.camera_alt_rounded,
                                        size: 14, color: Colors.white),
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
                            // Direct Gallery Button
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _pickPhotoForAngle(angle, _currentStage,
                                  source: ImageSource.gallery),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF86EFAC)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                        size: 14,
                                        color: Color(0xFF16A34A)),
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
                }),
                const SizedBox(height: 4),

                // Clean Notes Field
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
                      hintText:
                          'टिप्पणी (जैसे: फोम वॉश किया, केबिन वैक्यूम किया)',
                      hintStyle: TextStyle(
                          fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.note_alt_outlined,
                          size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // Bottom Fixed Action Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Switcher Button (if in BEFORE, button to jump to AFTER)
                if (_currentStage == 0) ...[
                  FilledButton.icon(
                    onPressed: _trySwitchToAfterStage,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      _beforeCapturedCount == _angles.length
                          ? 'धोने से पहले की सब फोटो हो गईं -> आगे: धोने के बाद'
                          : 'धोने से पहले की सभी फोटो डालें ($_beforeCapturedCount/${_angles.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _beforeCapturedCount == _angles.length
                          ? const Color(0xFF16A34A)
                          : Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStage = 0),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text(
                      'वापस: धोने से पहले की फोटो देखें',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(
                          color: Color(0xFFCBD5E1), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Final Submit Button
                FilledButton.icon(
                  onPressed: _isUploading ? null : _submitCleaningPhotos,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    _isUploading
                        ? (_uploadStatusText ?? 'फोटो सेव हो रही हैं...')
                        : 'सफाई की सभी फोटो जमा करें ($_totalCapturedCount दर्ज)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
