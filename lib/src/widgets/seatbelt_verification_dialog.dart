import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/ai_vision_service.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';
import 'seatbelt_records_dialog.dart';

enum VerificationStatus {
  idle,
  scanning,
  approved,
  rejected,
}

class SeatbeltAnalysisResult {
  const SeatbeltAnalysisResult(this.detected, this.message);

  final bool detected;
  final String message;
}

typedef _SeatbeltAnalysis = SeatbeltAnalysisResult;

class SeatbeltVerificationDialog extends StatefulWidget {
  const SeatbeltVerificationDialog({
    required this.controller,
    this.vehicleNumber = '',
    this.location = '',
    super.key,
  });

  final PlannerController controller;
  final String vehicleNumber;
  final String location;

  static Future<bool> show(
    BuildContext context, {
    required PlannerController controller,
    String vehicleNumber = '',
    String location = '',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SeatbeltVerificationDialog(
        controller: controller,
        vehicleNumber: vehicleNumber,
        location: location,
      ),
    );
    return result ?? false;
  }

  /// Evaluates a cabin photo against anti-grid texture frequency, strict YCbCr
  /// face biometric boundaries, T-zone luminance dip, and isolated continuous strap detection.
  static Future<SeatbeltAnalysisResult> analyzeSeatbeltImage(Uint8List bytes) =>
      _SeatbeltVerificationDialogState.analyzeSeatbelt(bytes);

  @override
  State<SeatbeltVerificationDialog> createState() =>
      _SeatbeltVerificationDialogState();
}

class _SeatbeltVerificationDialogState extends State<SeatbeltVerificationDialog>
    with SingleTickerProviderStateMixin {
  VerificationStatus _status = VerificationStatus.idle;
  bool _hasSeatbelt = false;
  String _analysisMessage = '';
  Uint8List? _uploadedImageBytes;
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Request notification permissions for outside-app alerts
    SafetyNotificationService.requestPermission();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _triggerPhotoCapture({required bool useCamera}) {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: useCamera,
      onPhotoSelected: (base64) {
        _onPhotoReceived(
          base64,
          useCamera ? 'Live Camera Photo' : 'Uploaded File Photo',
        );
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
    );
  }

  void _onPhotoReceived(String base64Data, String label) async {
    try {
      final commaIndex = base64Data.indexOf(',');
      final cleanBase64 =
          commaIndex >= 0 ? base64Data.substring(commaIndex + 1) : base64Data;
      // Memory protection: reject payloads exceeding 2.5MB before decode
      if (cleanBase64.length > 3670016) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Photo size exceeds 2.5MB limit. Please choose a smaller photo.')),
          );
        }
        return;
      }
      final bytes = base64Decode(cleanBase64.trim());
      if (bytes.isEmpty || bytes.length > 2621440) return;
      if (!mounted) return;

      setState(() {
        _uploadedImageBytes = bytes;
      });

      await _runAiScan(photoBytes: bytes, photoLabel: label);
    } catch (_) {}
  }

  static Future<SeatbeltAnalysisResult> analyzeSeatbelt(Uint8List bytes) async {
    if (bytes.length < 2500) {
      return const _SeatbeltAnalysis(
        false,
        'Photo bahut chhoti ya invalid hai. Clear cabin photo lein.',
      );
    }
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 160,
        targetHeight: 160,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      codec.dispose();
      if (byteData == null || byteData.lengthInBytes < 160 * 160 * 4) {
        return const _SeatbeltAnalysis(
          false,
          'Photo read nahi ho saki. Camera se nayi photo lein.',
        );
      }

      int redAt(int x, int y) => byteData.getUint8((y * 160 + x) * 4);
      int greenAt(int x, int y) => byteData.getUint8((y * 160 + x) * 4 + 1);
      int blueAt(int x, int y) => byteData.getUint8((y * 160 + x) * 4 + 2);
      double luminanceAt(int x, int y) =>
          redAt(x, y) * 0.299 + greenAt(x, y) * 0.587 + blueAt(x, y) * 0.114;

      // 1. Strict Human Driver Face & Biometric Validation:
      // A genuine cabin photo must contain a live human driver's face in the upper/mid frame.
      var skinPixels = 0;
      var faceSamples = 0;
      var strongestSkinBlock = 0.0;
      var skinXSum = 0;
      var minSkinX = 160;
      var maxSkinX = 0;
      var minSkinY = 160;
      var maxSkinY = 0;

      for (var blockY = 10; blockY < 90; blockY += 10) {
        for (var blockX = 20; blockX < 140; blockX += 12) {
          var blockSkin = 0;
          var blockSamples = 0;
          for (var y = blockY; y < blockY + 10; y += 2) {
            for (var x = blockX; x < blockX + 12; x += 2) {
              final r = redAt(x, y).toDouble();
              final g = greenAt(x, y).toDouble();
              final b = blueAt(x, y).toDouble();
              final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
              final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

              // Rigorous multi-complexion human skin tone formula:
              // Rejects gray fabrics, white/mesh chairs, wooden desks, and walls.
              final isSkin = cr >= 133 &&
                  cr <= 180 &&
                  cb >= 78 &&
                  cb <= 135 &&
                  r > 45 &&
                  g > 28 &&
                  b > 20 &&
                  r > g &&
                  g > b &&
                  (r - g) >= 8 &&
                  (r - b) >= 15;

              if (isSkin) {
                blockSkin++;
                skinXSum += x;
                if (x < minSkinX) minSkinX = x;
                if (x > maxSkinX) maxSkinX = x;
                if (y < minSkinY) minSkinY = y;
                if (y > maxSkinY) maxSkinY = y;
              }
              blockSamples++;
            }
          }
          skinPixels += blockSkin;
          faceSamples += blockSamples;
          final blockRatio = blockSkin / (blockSamples > 0 ? blockSamples : 1);
          if (blockRatio > strongestSkinBlock) {
            strongestSkinBlock = blockRatio;
          }
        }
      }

      final skinRatio = skinPixels / (faceSamples > 0 ? faceSamples : 1);
      final faceWidth = maxSkinX >= minSkinX ? (maxSkinX - minSkinX) : 0;
      final faceHeight = maxSkinY >= minSkinY ? (maxSkinY - minSkinY) : 0;
      final meanSkinX = skinPixels > 0 ? (skinXSum / skinPixels) : 0.0;
      final isFaceInFrame = meanSkinX >= 25.0 && meanSkinX <= 135.0;

      // Must have actual clustered human face presence (not random chair mesh or wall noise):
      final hasPersonEvidence = (skinPixels >= 32 &&
              skinRatio >= 0.035 &&
              strongestSkinBlock >= 0.20 &&
              faceWidth >= 12 &&
              faceHeight >= 10 &&
              isFaceInFrame) ||
          (skinPixels >= 25 && strongestSkinBlock >= 0.25);

      if (!hasPersonEvidence) {
        return const _SeatbeltAnalysis(
          false,
          'Driver/face detect nahi hua. Cabin mein baith kar seedhi selfie lein.',
        );
      }

      // 2. Anti-Keyboard / Extreme Artificial Grid Filter:
      // Real vehicle interiors have textures, stitches, and fabric grain (transitions 6-20).
      // Keyboards / barcodes have dense mechanical frequencies across 30+ pixels per line.
      int totalRowTransitions = 0;
      int sampledRows = 0;
      for (var y = 50; y <= 145; y += 4) {
        int rowTransitions = 0;
        for (var x = 20; x <= 140; x += 2) {
          final diff = (luminanceAt(x, y) - luminanceAt(x - 2, y)).abs();
          if (diff > 35) {
            rowTransitions++;
          }
        }
        totalRowTransitions += rowTransitions;
        sampledRows++;
      }
      final avgRowTransitions =
          totalRowTransitions / (sampledRows > 0 ? sampledRows : 1);
      if (avgRowTransitions > 28.0 && strongestSkinBlock < 0.40) {
        return const _SeatbeltAnalysis(
          false,
          'Keyboard ya barcode grid pattern detect hua. Asli cabin mein baith kar driver selfie lein.',
        );
      }

      // 3. Search the torso area for continuous diagonal seatbelt strap:
      // Commercial truck / passenger cabin cameras can be left-hand, right-hand, or selfie mirrored.
      var bestHitRatio = 0.0;
      var bestContinuousRun = 0;
      var bestBandRatio = 0.0;
      var bestBandRun = 0;
      var bestOffset = 0;
      final offsetHitRatios = <int, double>{};

      for (final contrastThresh in [14.0, 20.0, 26.0]) {
        for (final span in [30, 48, 65]) {
          for (final direction in [-1, 1]) {
            for (var offset = -48; offset <= 48; offset += 4) {
              var hits = 0;
              var run = 0;
              var bandHits = 0;
              var bandRun = 0;
              var longestBandRun = 0;
              var bandMisses = 0;
              var longestRun = 0;
              var samples = 0;

              for (var y = 45; y <= 145; y += 2) {
                final progress = (y - 45) / 100.0;
                final x =
                    (80 + offset + direction * (progress - 0.5) * span).round();
                if (x < 10 || x > 150) continue;

                final centre = (luminanceAt(x - 1, y) +
                        luminanceAt(x, y) +
                        luminanceAt(x + 1, y)) /
                    3;
                final sideA = luminanceAt(x - 7, y);
                final sideB = luminanceAt(x + 7, y);
                final diffA = (centre - sideA).abs();
                final diffB = (centre - sideB).abs();
                final surroundings = (sideA + sideB) / 2;
                final contrast = (centre - surroundings).abs();

                // A genuine seatbelt strap creates distinct edge or contrast against clothing
                final isStrapPixel = (contrast >= contrastThresh) ||
                    (diffA >= contrastThresh + 2 &&
                        diffB >= contrastThresh - 2) ||
                    (diffB >= contrastThresh + 2 &&
                        diffA >= contrastThresh - 2);

                // Seatbelts are often 10-25 px wide after down-scaling. A
                // centre-only edge check can sit entirely inside that band
                // and miss it, so compare the belt core with wider shoulders.
                var isWideStrapBand = false;
                for (final halfWidth in [9, 13, 17]) {
                  if (x - halfWidth < 2 || x + halfWidth > 157) continue;
                  final inner = (luminanceAt(x - 2, y) +
                          luminanceAt(x, y) +
                          luminanceAt(x + 2, y)) /
                      3;
                  final outer = (luminanceAt(x - halfWidth, y) +
                          luminanceAt(x + halfWidth, y)) /
                      2;
                  if ((inner - outer).abs() >= 11.0) {
                    isWideStrapBand = true;
                    break;
                  }
                }

                samples++;
                if (isStrapPixel) {
                  hits++;
                  run++;
                  if (run > longestRun) longestRun = run;
                } else {
                  run = 0;
                }

                if (isWideStrapBand) {
                  bandHits++;
                  bandRun++;
                  bandMisses = 0;
                  if (bandRun > longestBandRun) longestBandRun = bandRun;
                } else if (bandMisses < 2 && bandRun > 0) {
                  // Buckle, clothing folds and arm overlap may briefly hide
                  // an otherwise continuous shoulder-to-waist strap.
                  bandMisses++;
                  bandRun++;
                } else {
                  bandRun = 0;
                  bandMisses = 0;
                }
              }

              if (samples > 0) {
                final hitRatio = hits / samples;
                offsetHitRatios[offset] = hitRatio;
                if (hitRatio > bestHitRatio) {
                  bestHitRatio = hitRatio;
                  bestOffset = offset;
                }
                if (longestRun > bestContinuousRun) {
                  bestContinuousRun = longestRun;
                }
                final bandRatio = bandHits / samples;
                if (bandRatio > bestBandRatio) bestBandRatio = bandRatio;
                if (longestBandRun > bestBandRun) {
                  bestBandRun = longestBandRun;
                }
              }
            }
          }
        }
      }

      // Verify strap is not repetitive parallel barcode/stripes
      int parallelHighContrastStripes = 0;
      for (final entry in offsetHitRatios.entries) {
        if ((entry.key - bestOffset).abs() >= 16 && entry.value >= 0.70) {
          parallelHighContrastStripes++;
        }
      }
      if (parallelHighContrastStripes >= 7 && bestBandRatio < 0.28) {
        return const _SeatbeltAnalysis(
          false,
          'Parallel stripes ya grill pattern detect hua. Sirf ek continuous seatbelt strap honi chahiye.',
        );
      }

      final strapDetected = (bestHitRatio >= 0.31 && bestContinuousRun >= 5) ||
          (bestBandRatio >= 0.28 && bestBandRun >= 8);
      if (!strapDetected) {
        return const _SeatbeltAnalysis(
          false,
          'Shoulder se waist tak seatbelt strap clear nahi dikh rahi. Seedhi, roshni wali cabin photo lein.',
        );
      }

      return const _SeatbeltAnalysis(
        true,
        'Driver aur continuous shoulder seatbelt strap verify hui.',
      );
    } catch (_) {
      // Fail closed: an unreadable/unsupported file must never authorize a
      // safety-critical ride.
      return const _SeatbeltAnalysis(
        false,
        'Unsupported ya unreadable image. Camera se JPEG/PNG photo lein.',
      );
    }
  }

  Future<void> _runAiScan({
    required Uint8List photoBytes,
    required String photoLabel,
  }) async {
    setState(() {
      _status = VerificationStatus.scanning;
      _hasSeatbelt = false;
      _analysisMessage = '';
    });

    _scanController.repeat(reverse: true);

    // 1. Check Anti-Replay Guard, Liveness Entropy & Vision AI
    final aiGuardResult =
        await AiVisionService.instance.verifySeatbeltAndDriver(
      photoBytes: photoBytes,
      existingRecords: widget.controller.seatbeltRecords,
    );

    _SeatbeltAnalysis analysis;
    if (aiGuardResult.isReplay || !aiGuardResult.livenessPassed) {
      analysis = _SeatbeltAnalysis(false, aiGuardResult.message);
    } else if (aiGuardResult.aiEngine == 'Firebase Cloud Function AI' ||
        aiGuardResult.aiEngine == 'Gemini Multimodal Vision AI') {
      analysis = _SeatbeltAnalysis(
        aiGuardResult.isApproved,
        aiGuardResult.message,
      );
    } else {
      final localScan = await analyzeSeatbelt(photoBytes);
      analysis = localScan;
    }

    final seatbeltDetected = analysis.detected;
    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;
    _scanController.stop();

    final truckIdx = widget.controller.truckIndex ?? 0;
    final effVehicle = widget.vehicleNumber.isNotEmpty
        ? widget.vehicleNumber
        : (widget.controller.truckModels.isNotEmpty
            ? widget
                .controller
                .truckModels[
                    truckIdx.clamp(0, widget.controller.truckModels.length - 1)]
                .code
            : '');

    final effLocation =
        widget.location.isNotEmpty ? widget.location : widget.controller.origin;

    setState(() {
      _hasSeatbelt = seatbeltDetected;
      _analysisMessage = analysis.message;
    });

    // Detect MIME type dynamically from image magic bytes
    String mimeType = 'image/jpeg';
    if (photoBytes.length >= 8) {
      if (photoBytes[0] == 0x89 &&
          photoBytes[1] == 0x50 &&
          photoBytes[2] == 0x4E &&
          photoBytes[3] == 0x47) {
        mimeType = 'image/png';
      } else if (photoBytes[0] == 0x52 &&
          photoBytes[1] == 0x49 &&
          photoBytes[2] == 0x46 &&
          photoBytes[3] == 0x46) {
        mimeType = 'image/webp';
      }
    }
    final base64Photo = 'data:$mimeType;base64,${base64Encode(photoBytes)}';
    final activeDriver = widget.controller.selectedDriver;
    final driverName = widget.controller.loggedInName ??
        activeDriver?.name ??
        widget.controller.activeDriverName;
    final driverId = widget.controller.loggedInEmail ??
        activeDriver?.email ??
        widget.controller.activeDriverEmail;
    if (driverName == null ||
        driverName.trim().isEmpty ||
        driverId == null ||
        driverId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _status = VerificationStatus.rejected;
          _analysisMessage =
              'Authenticated driver is required for verification.';
        });
      }
      return;
    }

    // Save persistent SeatbeltRecord with Date, Time, Driver Name, and Photo
    final record = SeatbeltRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      driverName: driverName.trim(),
      driverId: driverId.trim(),
      vehicleNumber: effVehicle,
      photoBase64: base64Photo,
      timestamp: DateTime.now(),
      isApproved: seatbeltDetected,
      location: effLocation,
      notes: seatbeltDetected
          ? 'Pre-trip cabin inspection photo verified seatbelt buckled.'
          : 'Driver seatbelt not detected in pre-ride photo. Ride authorization blocked.',
    );
    await widget.controller.addSeatbeltRecord(record);

    if (seatbeltDetected) {
      if (mounted) {
        setState(() => _status = VerificationStatus.approved);
      }

      // External notification outside the app (Browser Push + Sound Chime)
      SafetyNotificationService.notifyDriverSafety(
        title: 'Pre-Ride Verification: APPROVED',
        body: effVehicle.isNotEmpty
            ? 'Seatbelt verified for vehicle $effVehicle. Safe trip authorization granted.'
            : 'Seatbelt verified. Safe trip authorization granted.',
        isRejected: false,
      );

      await widget.controller.addAlert(
        OperationsAlert(
          title: 'Seatbelt Verified: $driverName',
          details: effVehicle.isNotEmpty
              ? 'Pre-trip driver cabin inspection verified seatbelt buckled on vehicle $effVehicle. Safe trip authorization granted.'
              : 'Pre-trip driver cabin inspection verified seatbelt buckled. Safe trip authorization granted.',
          severity: 'info',
          category: 'seatbelt',
          vehicleNumber: effVehicle,
          location: effLocation,
          driverPhoto:
              '', // Avoid duplicate multi-megabyte photo payload in info alerts
          createdAt: DateTime.now().toIso8601String(),
          isResolved: true,
        ),
      );

      await widget.controller.logActivity(
        title: 'Seatbelt Verification Passed',
        details: effVehicle.isNotEmpty
            ? 'Pre-trip cabin inspection photo verified seatbelt buckled on vehicle $effVehicle.'
            : 'Pre-trip cabin inspection photo verified seatbelt buckled.',
        category: ActivityCategory.alert,
        action: 'verified',
      );
    } else {
      if (mounted) {
        setState(() => _status = VerificationStatus.rejected);
      }

      // External notification outside the app (Browser Push + Warning Alarm)
      SafetyNotificationService.notifyDriverSafety(
        title: 'CRITICAL ALERT: RIDE BLOCKED',
        body:
            'Driver seatbelt NOT detected in pre-ride photo! Fasten seatbelt immediately to start trip.',
        isRejected: true,
      );

      // Log critical alert in operations radar without duplicating multi-megabyte photo payload
      await widget.controller.logSeatbeltAlert(
        driverName: driverName,
        vehicleNumber: effVehicle,
        location: effLocation,
        driverPhoto:
            '', // Avoid duplicate storage; photo is stored in SeatbeltRecord
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final truckIdx = widget.controller.truckIndex ?? 0;
    final effectiveVehicle = widget.vehicleNumber.isNotEmpty
        ? widget.vehicleNumber
        : (widget.controller.truckModels.isNotEmpty
            ? widget
                .controller
                .truckModels[
                    truckIdx.clamp(0, widget.controller.truckModels.length - 1)]
                .code
            : '');

    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.90,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner
              _buildTopBanner(effectiveVehicle),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Regulatory advisory
                    _buildRegulationNotice(),
                    const SizedBox(height: 14),

                    // Cabin Viewfinder / Photo Scanner Area
                    _buildScannerViewfinder(),
                    const SizedBox(height: 14),

                    // Photo Selection / Demonstration Controls
                    _buildPhotoSelectionControls(),
                    const SizedBox(height: 14),

                    // Status Result Banner
                    if (_status != VerificationStatus.idle)
                      _buildStatusResultBanner(),

                    const SizedBox(height: 18),
                    // Action Buttons (Cancel / Re-scan / Start Ride)
                    _buildActionFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner(String vehicleCode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.airline_seat_recline_extra_rounded,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Flexible(
                      child: Text(
                        'Pre-Trip Safety Verification',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MANDATORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  vehicleCode.isNotEmpty
                      ? 'Vehicle: $vehicleCode · Cabin Checkpoint'
                      : 'Cabin Seatbelt Checkpoint',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF94A3B8), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            tooltip: 'Cancel & Exit',
          ),
        ],
      ),
    );
  }

  Widget _buildRegulationNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color: Color(0xFFD97706),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trip start karne se pehle driver cabin photo upload karna anivarya hai. Photo mein seatbelt pehne hona zaroori hai. Seatbelt na hone par ride reject aur lock ho jayegi.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerViewfinder() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _status == VerificationStatus.approved
              ? const Color(0xFF10B981)
              : _status == VerificationStatus.rejected
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF334155),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // If real photo was captured/uploaded, show the REAL PHOTO!
            if (_uploadedImageBytes != null)
              Positioned.fill(
                child: Image.memory(
                  _uploadedImageBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else
              // Cabin Silhouette Guidance when awaiting photo
              Positioned.fill(
                child: CustomPaint(
                  painter: _CabinInspectionPainter(
                    hasSeatbelt: _hasSeatbelt,
                    status: _status,
                  ),
                ),
              ),

            // Scanning Line Animation
            if (_status == VerificationStatus.scanning)
              AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, _) => Positioned(
                  top: _scanAnimation.value * 210,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF38BDF8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top Status Overlay Tag
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: _status == VerificationStatus.scanning
                          ? const Color(0xFF38BDF8)
                          : _status == VerificationStatus.approved
                              ? const Color(0xFF10B981)
                              : _status == VerificationStatus.rejected
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _status == VerificationStatus.scanning
                          ? 'VERIFYING CABIN SAFETY...'
                          : _status == VerificationStatus.approved
                              ? 'SEATBELT DETECTED'
                              : _status == VerificationStatus.rejected
                                  ? 'SEATBELT MISSING'
                                  : (_uploadedImageBytes != null
                                      ? 'CABIN PHOTO READY'
                                      : 'CAMERA STANDBY'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Torso Target Bounding Box
            Center(
              child: Container(
                width: 170,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _status == VerificationStatus.approved
                        ? const Color(0xFF10B981)
                        : _status == VerificationStatus.rejected
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Text(
                        _status == VerificationStatus.approved
                            ? 'Diagonal Strap: OK'
                            : _status == VerificationStatus.rejected
                                ? 'No Strap Detected'
                                : (_uploadedImageBytes != null
                                    ? 'Driver Attestation Area'
                                    : 'Driver Torso Area'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _status == VerificationStatus.approved
                              ? const Color(0xFF34D399)
                              : _status == VerificationStatus.rejected
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSelectionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driver Cabin Verification Photo:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _status == VerificationStatus.scanning
                  ? null
                  : () => _triggerPhotoCapture(useCamera: true),
              icon: const Icon(Icons.photo_camera_rounded, size: 16),
              label: const Text(
                'Camera Selfie Le (Take Photo)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _status == VerificationStatus.scanning
                  ? null
                  : () => _triggerPhotoCapture(useCamera: false),
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text(
                'Upload Photo (Gallery / File)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                foregroundColor: AppColors.navy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusResultBanner() {
    if (_status == VerificationStatus.scanning) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Processing captured photo and registering driver safety attestation...',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_status == VerificationStatus.approved) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_rounded,
                size: 20, color: Color(0xFF059669)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECORDED: Seatbelt Check Passed (Pre-Trip Cleared)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _analysisMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Rejected state
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_bad_rounded, size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTION REQUIRED: Clear Seatbelt Photo Required (Ride Pending Review)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _analysisMessage,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF991B1B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    final isRejected = _status == VerificationStatus.rejected;
    final isApproved = _status == VerificationStatus.approved;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => SeatbeltRecordsDialog.show(
            context,
            controller: widget.controller,
          ),
          icon: const Icon(Icons.photo_library_outlined, size: 15),
          label: const Text('Saved Photos', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel Trip',
                  style: TextStyle(color: AppColors.slate)),
            ),
            if (isRejected)
              FilledButton.icon(
                onPressed: () => _triggerPhotoCapture(useCamera: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-take Photo with Seatbelt'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
              )
            else
              FilledButton.icon(
                onPressed:
                    isApproved ? () => Navigator.pop(context, true) : null,
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Start Ride / Navigation'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CabinInspectionPainter extends CustomPainter {
  const _CabinInspectionPainter({
    required this.hasSeatbelt,
    required this.status,
  });

  final bool hasSeatbelt;
  final VerificationStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Driver Silhouette (Head)
    final headPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawCircle(Offset(cx, cy - 35), 26, headPaint);

    // Driver Torso
    final torsoPaint = Paint()..color = const Color(0xFF1E293B);
    final torsoPath = Path()
      ..moveTo(cx - 55, size.height)
      ..lineTo(cx - 40, cy - 5)
      ..quadraticBezierTo(cx, cy - 12, cx + 40, cy - 5)
      ..lineTo(cx + 55, size.height)
      ..close();
    canvas.drawPath(torsoPath, torsoPaint);

    // Seatbelt strap (diagonal shoulder belt)
    if (hasSeatbelt && status != VerificationStatus.idle) {
      final beltPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final beltPath = Path()
        ..moveTo(cx - 36, cy - 8)
        ..lineTo(cx + 46, size.height - 10);
      canvas.drawPath(beltPath, beltPaint);

      // Buckle clasp highlight
      final bucklePaint = Paint()..color = const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + 40, size.height - 25), width: 14, height: 18),
          const Radius.circular(3),
        ),
        bucklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CabinInspectionPainter oldDelegate) =>
      oldDelegate.hasSeatbelt != hasSeatbelt || oldDelegate.status != status;
}

// seatbelt  verfication  dialog page
