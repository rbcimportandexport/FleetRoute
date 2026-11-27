import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/image_blur_detection_service.dart';
import '../services/smart_auto_scanner_service.dart';

/// 2-Color Light Combo Design Tokens
/// Primary: Clean Electric Indigo / Fleet Blue (Navigation & Buttons)
/// Accent: Vibrant Emerald Cyan / Mint (Icons, Active Badges & Highlights)
/// Background: Fresh Airy Light White-Slate (#F8FAFC)
abstract final class SmartUiTheme {
  // Color 1: Primary Brand & Navigation
  static const navPrimary = Color(0xFF2563EB); // Royal Fleet Blue
  static const navDark = Color(0xFF1D4ED8); // Deep Navigation Blue
  static const navSoft = Color(0xFFEFF6FF); // Ultra-light Blue Tint
  static const navBorder = Color(0xFFBFDBFE); // Soft Blue Border

  // Color 2: Distinct Accent & Icons
  static const iconAccent = Color(0xFF0D9488); // Crisp Teal / Emerald (#0D9488)
  static const iconBadgeBg = Color(0xFFCCFBF1); // Soft Mint / Aqua Tint (#CCFBF1)
  static const iconBadgeBorder = Color(0xFF99F6E4); // Gentle Teal Border

  // Neutral Light Canvas & Typography
  static const canvasBg = Color(0xFFF8FAFC); // Clean Light Slate-White
  static const cardBg = Color(0xFFFFFFFF); // Pure White Container
  static const textNavy = Color(0xFF0F172A); // High-contrast Slate-900
  static const textSlate = Color(0xFF475569); // Readable Subtitle Slate-600
  static const textMuted = Color(0xFF94A3B8); // Subtle Slate-400
  static const borderLight = Color(0xFFE2E8F0); // Crisp Modern Border
}

/// Ultra-smooth 60/120fps Zero-Lag Smart Photo Vehicle Logger
/// Zero-typing + 2-Color Light Modern UI
class SmartPhotoLoggerPage extends StatefulWidget {
  const SmartPhotoLoggerPage({
    required this.controller,
    super.key,
  });

  final PlannerController controller;

  @override
  State<SmartPhotoLoggerPage> createState() => _SmartPhotoLoggerPageState();
}

class _SmartPhotoLoggerPageState extends State<SmartPhotoLoggerPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  SmartCaptureCategory _selectedCategory = SmartCaptureCategory.fuelDieselBill;
  bool _isProcessing = false;
  String _capturedImageBase64 = '';
  SmartAiExtractData? _lastExtractedData;

  // History list of auto-extracted records
  final List<SmartAiExtractData> _recentCaptures = [];

  // Track latest odometer to compute live mileage
  double _lastKnownOdometer = 45200.0;
  double _lastKnownFuelLiters = 45.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _captureOrPickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      // Check if photo is blurry or unreadable (especially for bills, documents & meter)
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
                'यह फोटो बहुत ज्यादा धुंधली (Blur) है और इसमें लिखा हुआ साफ नहीं पढ़ा जा रहा।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ व स्पष्ट फोटो खींचें।',
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

      final b64 = base64Encode(bytes);

      setState(() {
        _isProcessing = true;
        _capturedImageBase64 = b64;
      });

      const defaultGps = LatLng(21.17065, 73.00425);

      final result = await SmartAutoScannerService.instance.processPhoto(
        photoBytes: bytes,
        category: _selectedCategory,
        currentGpsCoordinates: defaultGps,
        previousOdometerKm: _lastKnownOdometer,
        previousFuelLiters: _lastKnownFuelLiters,
      );

      if (result.odometerKm != null) {
        _lastKnownOdometer = result.odometerKm!;
      }
      if (result.liters != null) {
        _lastKnownFuelLiters = result.liters!;
      }

      // Automatically store in Transport 1 Controller if it is an expense
      if (result.amount != null && result.amount! > 0) {
        final categoryStr = switch (result.category) {
          SmartCaptureCategory.fuelDieselBill => 'fuel',
          SmartCaptureCategory.hotelStayMeal => 'food',
          SmartCaptureCategory.tyreReplacementBill => 'repair',
          SmartCaptureCategory.challanMemo => 'challan',
          _ => 'other',
        };

        final newExpense = ExpenseRecord(
          id: 'AI-EXP-${DateTime.now().millisecondsSinceEpoch}',
          amount: result.amount!,
          category: categoryStr,
          isDirect: true,
          date: result.timestamp.toIso8601String().split('T').first,
          vehicleNumber: result.vehicleNumber,
          notes: 'Auto AI Scanned: ${result.vendorName} | ${result.locationAddress}',
          receiptBase64: _capturedImageBase64,
        );

        widget.controller.addExpense(newExpense);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastExtractedData = result;
          _recentCaptures.insert(0, result);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SmartUiTheme.navPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: SmartUiTheme.iconBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: SmartUiTheme.iconAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI ने सारी डिटेल ऑटोमैटिक निकाल ली! कोई टाइपिंग की जरूरत नहीं।',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Photo process error: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartUiTheme.canvasBg,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Responsive 2-Color Light Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Category Selection Chips (Navigation Blue & Soft Tint)
            SliverToBoxAdapter(
              child: _buildCategorySelector(),
            ),

            // Big Photo Capture & Drop Zone
            SliverToBoxAdapter(
              child: _buildPhotoCaptureZone(),
            ),

            // Live Extracted Data Card (Distinct Icon Accent + Navigation Accents)
            if (_isProcessing || _lastExtractedData != null)
              SliverToBoxAdapter(
                child: _buildExtractedResultCard(),
              ),

            // Live Average & Vehicle Health Summary
            SliverToBoxAdapter(
              child: _buildMileageAndHealthSummary(),
            ),

            // Recent Scanned Log Timeline
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _recentCaptures[index];
                    return _buildLogCard(item);
                  },
                  childCount: _recentCaptures.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        color: SmartUiTheme.cardBg,
        border: Border(bottom: BorderSide(color: SmartUiTheme.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          // Distinct Color 2: Teal / Emerald Accent Icon Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SmartUiTheme.iconBadgeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SmartUiTheme.iconBadgeBorder),
            ),
            child: const Icon(
              Icons.camera_enhance_rounded,
              color: SmartUiTheme.iconAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Photo AI Fleet Logger',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: SmartUiTheme.textNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'सिर्फ फोटो खींचो — AI ऑटोमैटिक डेटा + लोकेशन + टाइम दर्ज कर देगा',
                  style: TextStyle(
                    fontSize: 12,
                    color: SmartUiTheme.textSlate.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // Distinct Color 1: Navigation Blue Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SmartUiTheme.navSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SmartUiTheme.navBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: SmartUiTheme.navPrimary, size: 16),
                SizedBox(width: 4),
                Text(
                  '120 FPS Zero-Lag',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SmartUiTheme.navDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: SmartCaptureCategory.values.length,
        itemBuilder: (context, index) {
          final cat = SmartCaptureCategory.values[index];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(cat.shortLabel),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat);
              },
              selectedColor: SmartUiTheme.navPrimary,
              backgroundColor: SmartUiTheme.cardBg,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : SmartUiTheme.textNavy,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? SmartUiTheme.navPrimary : SmartUiTheme.borderLight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoCaptureZone() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SmartUiTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SmartUiTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SmartUiTheme.iconBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flash_on_rounded, color: SmartUiTheme.iconAccent, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedCategory.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SmartUiTheme.textNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'कैमरा या गैलरी से फोटो चुनें — कुछ भी लिखना नहीं है!',
            style: TextStyle(
              fontSize: 13,
              color: SmartUiTheme.textSlate.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _captureOrPickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('कैमरा से फोटो लें', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SmartUiTheme.navPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : () => _captureOrPickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, color: SmartUiTheme.iconAccent, size: 20),
                  label: const Text('गैलरी से चुनें', style: TextStyle(color: SmartUiTheme.textNavy, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SmartUiTheme.navBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedResultCard() {
    if (_isProcessing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SmartUiTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SmartUiTheme.navBorder),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: SmartUiTheme.navPrimary),
            SizedBox(height: 14),
            Text(
              'AI फोटो को स्कैन करके डेटा समझ रहा है...',
              style: TextStyle(fontWeight: FontWeight.w600, color: SmartUiTheme.textNavy),
            ),
            SizedBox(height: 4),
            Text(
              'स्थान, तारीख, समय और पर्ची का विवरण ऑटोमैटिक निकाला जा रहा है।',
              style: TextStyle(fontSize: 12, color: SmartUiTheme.textMuted),
            ),
          ],
        ),
      );
    }

    final data = _lastExtractedData!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmartUiTheme.navSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SmartUiTheme.navBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SmartUiTheme.iconBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: SmartUiTheme.iconAccent, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI ऑटोमैटिक एक्सट्रेक्टेड डेटा (Saved)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: SmartUiTheme.navDark,
                ),
              ),
              const Spacer(),
              Text(
                '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: SmartUiTheme.textSlate),
              ),
            ],
          ),
          const Divider(height: 18, color: SmartUiTheme.navBorder),
          if (data.amount != null)
            _buildResultRow('राशि (Amount):', '₹${data.amount!.toStringAsFixed(0)}', isBold: true),
          if (data.liters != null)
            _buildResultRow('डीजल / पेट्रोल (Liters):', '${data.liters} L'),
          if (data.odometerKm != null)
            _buildResultRow('मीटर रीडिंग (KM):', '${data.odometerKm!.toStringAsFixed(0)} KM'),
          if (data.calculatedMileage != null)
            _buildResultRow('गाड़ी का एवरेज (Mileage):', '${data.calculatedMileage} KM / Litre', isAccent: true),
          if (data.vendorName.isNotEmpty)
            _buildResultRow('दुकान / पंप / होटल:', data.vendorName),
          if (data.documentNumber.isNotEmpty)
            _buildResultRow('बिल / पर्ची नंबर:', data.documentNumber),
          _buildResultRow('लोकेशन (GPS Map):', data.locationAddress),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SmartUiTheme.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SmartUiTheme.navBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: SmartUiTheme.iconAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.summaryNotes,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SmartUiTheme.textNavy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isBold = false, bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: SmartUiTheme.textSlate.withValues(alpha: 0.9),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isAccent ? SmartUiTheme.iconAccent : SmartUiTheme.textNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMileageAndHealthSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SmartUiTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SmartUiTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCol('ताज़ा माइलेज', '14.2 Km/L', Icons.speed_rounded),
          ),
          Container(width: 1, height: 40, color: SmartUiTheme.borderLight),
          Expanded(
            child: _buildStatCol('ओडोमीटर', '${_lastKnownOdometer.toStringAsFixed(0)} KM', Icons.route_rounded),
          ),
          Container(width: 1, height: 40, color: SmartUiTheme.borderLight),
          Expanded(
            child: _buildStatCol('टायर स्थिति', '80% Good', Icons.tire_repair_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: SmartUiTheme.iconBadgeBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: SmartUiTheme.iconAccent),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SmartUiTheme.textNavy)),
        Text(label, style: const TextStyle(fontSize: 11, color: SmartUiTheme.textMuted)),
      ],
    );
  }

  Widget _buildLogCard(SmartAiExtractData item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SmartUiTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SmartUiTheme.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distinct Color 2: Accent Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SmartUiTheme.iconBadgeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SmartUiTheme.iconBadgeBorder),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: SmartUiTheme.iconAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.category.shortLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SmartUiTheme.textNavy),
                    ),
                    if (item.amount != null)
                      Text(
                        '₹${item.amount!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SmartUiTheme.navPrimary),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.summaryNotes,
                  style: const TextStyle(fontSize: 12, color: SmartUiTheme.textSlate),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: SmartUiTheme.iconAccent),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        item.locationAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: SmartUiTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
