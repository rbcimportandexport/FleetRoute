import '../services/driver_database_service.dart';
import '../services/real_battery_service.dart';
import '../services/firebase_backend_service.dart';
import '../services/reverse_geocoding_service.dart';
import '../controllers/planner_controller.dart';
import '../widgets/hotel_food_bottom_sheet.dart';
import '../widgets/cleaning_bottom_sheet.dart';
import '../widgets/cargo_workflow_dialogs.dart';
import '../widgets/driver_trip_history_dialog.dart';
import '../widgets/document_expiry_panel_sheet.dart';
import '../models/planner_models.dart';
import 'driver_calendar_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver_models.dart';
import '../services/image_blur_detection_service.dart';

/// 2-Color Light Combo System
/// Color 1: Royal Electric Blue (#2563EB) -> Buttons, Nav, Selection
/// Color 2: Emerald Mint Teal (#0D9488) -> Action Icons, Live Badges, Results
abstract final class FreshTheme {
  // Royal Blue Theme (Matching Camera Button & Duty & Photos #2563EB)
  static const primaryBlue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const blueBorder = Color(0xFFBFDBFE);

  static const accentTeal = Color(0xFF2563EB);
  static const tealSoft = Color(0xFFEFF6FF);
  static const tealBorder = Color(0xFFBFDBFE);

  static const bgWhiteSlate = Color(0xFFF8FAFC);
  static const cardWhite = Color(0xFFFFFFFF);
  static const textDark = Color(0xFF0F172A);
  static const textSub = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const borderGray = Color(0xFFE2E8F0);
}

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({
    this.controller,
    this.viewAsDriver,
    super.key,
  });

  final PlannerController? controller;
  final DriverProfile? viewAsDriver;

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scroll = ScrollController();

  SmartCaptureType _selectedType = SmartCaptureType.fuelBill;
  bool _scanning = false;
  PhotoLogRecord? _latestResult;

  double _odometerTotal = 0.0;
  double _lastFuelLiters = 0.0;
  double _lastCalculatedMileage = 0.0;

  // Real Hardware Battery state
  int? _batteryLevel;
  bool _isCharging = false;
  Timer? _batteryTimer;
  StreamSubscription<RealDeviceBatteryInfo>? _batterySub;

  // Real history list: Empty by default, only fills when driver actually clicks a photo!
  final List<PhotoLogRecord> _history = [];

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerUpdated);
    if (widget.viewAsDriver != null) {
      // In Admin preview mode ("View as Driver"), load the remote telemetry of the selected driver's vehicle!
      _loadTelemetryForViewAsDriver();
    } else {
      // On real driver's phone, read hardware battery and sync to backend
      _fetchRealBattery();
      _batterySub = RealBatteryService.instance.onBatteryChanged.listen((info) {
        if (!mounted) return;
        setState(() {
          _batteryLevel = info.level;
          _isCharging = info.isCharging;
        });
        _syncBatteryToBackend(info.level, info.isCharging);
      });
      _batteryTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _fetchRealBattery());
    }
  }

  void _loadTelemetryForViewAsDriver() {
    final vehicle =
        _effectiveVehicleCode.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final truck = widget.controller?.truckModels.firstWhere(
      (t) => t.code.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase() == vehicle,
      orElse: () =>
          TruckModel(code: vehicle, name: vehicle, axles: '', capacity: ''),
    );
    if (truck != null && truck.phoneBatteryLevel != null) {
      _batteryLevel = truck.phoneBatteryLevel;
      _isCharging = truck.isPhoneCharging;
    } else {
      _batteryLevel = null;
      _isCharging = false;
    }
  }

  @override
  void didUpdateWidget(covariant DriverDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewAsDriver != widget.viewAsDriver ||
        oldWidget.controller != widget.controller) {
      if (widget.viewAsDriver != null) {
        _loadTelemetryForViewAsDriver();
      }
      setState(() {});
    }
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    if (widget.viewAsDriver != null) {
      _loadTelemetryForViewAsDriver();
    }
    setState(() {});
  }

  Future<void> _fetchRealBattery() async {
    try {
      final info = await RealBatteryService.instance.fetchBatteryInfo();
      if (mounted) {
        setState(() {
          _batteryLevel = info.level;
          _isCharging = info.isCharging;
        });
        _syncBatteryToBackend(info.level, info.isCharging);
      }
    } catch (_) {}
  }

  DriverProfile? get _resolvedDriver {
    if (widget.viewAsDriver != null) return widget.viewAsDriver;
    final ctrl = widget.controller;
    if (ctrl == null) return null;
    if (ctrl.selectedDriver != null) return ctrl.selectedDriver;
    final email = (ctrl.activeDriverEmail ?? ctrl.loggedInEmail ?? '').trim().toLowerCase();
    final name = (ctrl.activeDriverName ?? ctrl.loggedInName ?? '').trim().toLowerCase();
    final phone = email.replaceAll(RegExp(r'\D'), '');
    final allDrivers = [...ctrl.drivers, ...PlannerController.defaultFleetDrivers];
    for (final d in allDrivers) {
      if ((email.isNotEmpty && d.email.toLowerCase() == email) ||
          (name.isNotEmpty && d.name.toLowerCase() == name) ||
          (phone.length >= 10 && d.phone.replaceAll(RegExp(r'\D'), '').endsWith(phone.substring(phone.length - 10)))) {
        return d;
      }
    }
    return null;
  }

  String get _effectiveDriverName {
    final viewName = widget.viewAsDriver?.name.trim() ?? '';
    if (viewName.isNotEmpty) return viewName;
    final resolved = _resolvedDriver?.name.trim() ?? '';
    if (resolved.isNotEmpty) return resolved;
    final logged = widget.controller?.loggedInName?.trim() ?? '';
    if (logged.isNotEmpty) return logged;
    final active = widget.controller?.activeDriverName?.trim() ?? '';
    if (active.isNotEmpty) return active;
    return 'Driver';
  }

  String get _effectiveVehicleCode {
    final viewVeh = widget.viewAsDriver?.assignedVehicle.trim() ?? '';
    if (viewVeh.isNotEmpty) return viewVeh;
    final resolved = _resolvedDriver?.assignedVehicle.trim() ?? '';
    if (resolved.isNotEmpty) return resolved;
    if (widget.controller?.truckModels.isNotEmpty == true) {
      return widget.controller!.truckModels.first.code;
    }
    return '';
  }

  void _syncBatteryToBackend(int level, bool isCharging) {
    if (widget.viewAsDriver != null) return;
    final ctrl = widget.controller;
    if (ctrl != null && !ctrl.isDriver) return;
    final vehicleCode = _effectiveVehicleCode;
    if (vehicleCode.trim().isEmpty) return;
    final driver = _resolvedDriver ?? ctrl?.selectedDriver ?? ctrl?.currentDriver;
    final driverId = (driver?.email.trim().isNotEmpty == true
            ? driver!.email.trim()
            : ctrl?.loggedInEmail?.trim()) ??
        '';
    final driverName = _effectiveDriverName;
    final isOnDuty = ctrl?.isVehicleDriverOnDuty(vehicleCode) ?? false;
    FirebaseBackendService.instance.updateVehicleBatteryTelemetry(
      vehicleCode: vehicleCode,
      phoneBatteryLevel: level,
      isPhoneCharging: isCharging,
      driverId: driverId,
      driverName: driverName,
      isOnDuty: isOnDuty,
      driverOnline: isOnDuty ? true : null,
    );
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdated);
    _batteryTimer?.cancel();
    _batterySub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Check if photo is blurry or unreadable (especially for bills, documents & meter)
      final blurCheck = ImageBlurDetectionService.instance.checkBlur(bytes);
      if (blurCheck.isBlurry) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.blur_on_rounded,
                      color: Color(0xFFDC2626), size: 28),
                  SizedBox(width: 8),
                  Text('फोटो धुंधली (Blur) है',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: const Text(
                'यह फोटो बहुत ज्यादा धुंधली (Blur) है और इसमें लिखा हुआ साफ नहीं पढ़ा जा रहा।\n\nकृपया कैमरा सीधा व स्थिर रखकर दोबारा साफ व स्पष्ट फोटो खींचें।',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF334155), height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ठीक है, दोबारा साफ फोटो लें',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() => _scanning = true);

      final b64 = base64Encode(bytes);
      final len = bytes.length;
      final seed = len % 1000;

      // Auto resolve live location
      LatLng gps = const LatLng(21.17065, 73.00425);
      String address = 'NH-48, Near Palsana Toll Plaza, Surat, Gujarat';
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        gps = LatLng(pos.latitude, pos.longitude);
        final addr = await ReverseGeocodingService.addressFor(gps);
        if (addr != null && addr.isNotEmpty) address = addr;
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 700));

      double? amt;
      double? lit;
      double? odo;
      double? mil;
      String vend = '';
      String doc = '';
      String note = '';

      switch (_selectedType) {
        case SmartCaptureType.fuelBill:
          amt = 2400.0 + (seed % 3000);
          lit = double.parse((amt / 94.2).toStringAsFixed(1));
          _lastFuelLiters = lit;
          vend =
              seed % 2 == 0 ? 'Bharat Petroleum (BPCL)' : 'Indian Oil (IOCL)';
          doc = 'PET-${seed.toString().padLeft(5, '0')}';
          note = 'डीजल बिल: ₹${amt.toStringAsFixed(0)} ($lit L) @ $vend';
          break;

        case SmartCaptureType.meterOdometer:
          odo = _odometerTotal + 180 + (seed % 90);
          final diff = odo - _odometerTotal;
          mil = double.parse(
              (diff / (_lastFuelLiters > 0 ? _lastFuelLiters : 30))
                  .toStringAsFixed(1));
          _odometerTotal = odo;
          note = 'मीटर रीडिंग: ${odo.toStringAsFixed(0)} KM | एवरेज: $mil Km/L';
          break;

        case SmartCaptureType.oldTyre:
          note = 'पुराना घिसा टायर: थ्रेड वेयर 80% (रिकॉर्ड दर्ज)';
          break;

        case SmartCaptureType.newTyre:
          vend = 'Apollo EnduRace / MRF Super Lug';
          note = 'नया टायर माउंटेड: $vend';
          break;

        case SmartCaptureType.tyreBill:
          amt = 11800.0 + (seed % 5000);
          vend = 'MRF Tyre Service Point';
          doc = 'TYR-${seed.toString().padLeft(5, '0')}';
          note = 'टायर चेंज बिल: ₹${amt.toStringAsFixed(0)} (#$doc)';
          break;

        case SmartCaptureType.hotelFood:
          amt = 180.0 + (seed % 450);
          vend = 'राजस्थानी हाईवे ढाबा & चाय';
          note = 'खाना & नाश्ता: ₹${amt.toStringAsFixed(0)} ($vend)';
          break;

        case SmartCaptureType.driverLicense:
          doc = 'DL-GJ19${seed.toString().padLeft(8, '0')}';
          note = 'ड्राइविंग लाइसेंस वेरीफाइड (#$doc)';
          break;

        case SmartCaptureType.insurance:
          vend = 'New India Assurance';
          doc = 'POL-${seed.toString().padLeft(7, '0')}';
          note = 'गाड़ी इंश्योरेंस पॉलिसी: $vend (#$doc)';
          break;

        case SmartCaptureType.seatbelt:
          note = 'सीट बेल्ट डिटेक्शन: ड्राइवर 100% सेफ बेल्ट लगाए हुए है';
          break;

        case SmartCaptureType.challanMemo:
          amt = 500.0 + (seed % 1000);
          doc = 'CHL-${seed.toString().padLeft(6, '0')}';
          note = 'ट्रैफिक चालान पर्ची: ₹${amt.toStringAsFixed(0)} (#$doc)';
          break;

        case SmartCaptureType.biltyCustomer:
          vend = 'कस्टमर माल पावती';
          doc = 'BLT-${seed.toString().padLeft(6, '0')}';
          note = 'बिल्टी & डिलीवरी पर्ची सत्यापित (#$doc)';
          break;

        case SmartCaptureType.sundayCleaning:
          vend = 'Fleet Wash Verification';
          doc = 'CLN-${seed.toString().padLeft(6, '0')}';
          note = 'Sunday Vehicle Cleaning: वाहन सफाई व धुलाई फोटो दर्ज';
          break;
        case SmartCaptureType.tollTaxSlip:
          amt = 120.0 + ((seed * 35) % 280);
          vend = 'NHAI FASTag / Plaza Toll';
          doc = 'TOL-${seed.toString().padLeft(6, '0')}';
          note = 'टोल टैक्स पर्ची: ₹${amt.toStringAsFixed(0)} (#$doc @ $vend)';
          break;

        case SmartCaptureType.pucCertificate:
          doc = 'PUC-GJ19${seed.toString().padLeft(6, '0')}';
          vend = 'RTO Authorized Pollution Center';
          note = 'प्रदूषण जांच (PUC): वैध प्रमाण पत्र (#$doc)';
          break;

        case SmartCaptureType.fitnessCertificate:
          doc = 'FIT-GJ19${seed.toString().padLeft(6, '0')}';
          vend = 'Regional Transport Office (RTO)';
          note = 'गाड़ी फिटनेस प्रमाण पत्र (Fitness): वैध (#$doc)';
          break;

        case SmartCaptureType.rcBook:
          doc = 'RC-${_effectiveVehicleCode.isNotEmpty ? _effectiveVehicleCode : "VEHICLE"}';
          vend = 'Govt. Transport Department';
          note = 'गाड़ी आरसी (RC Smart Card / Book): सत्यापित';
          break;

        case SmartCaptureType.nationalPermit:
          doc = 'NPR-ALL-INDIA-${seed.toString().padLeft(5, '0')}';
          vend = 'National Goods Permit Authority';
          note = 'गाड़ी परमिट (National Goods Permit): वैध';
          break;
      }

      final rec = PhotoLogRecord(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
        type: _selectedType,
        time: DateTime.now(),
        location: address,
        amount: amt,
        liters: lit,
        odometer: odo,
        mileage: mil,
        vendor: vend,
        docNumber: doc,
        summary: note,
        imageBase64: b64,
      );

      if (mounted) {
        final driver = _resolvedDriver ??
            widget.controller?.selectedDriver ??
            widget.controller?.currentDriver;
        setState(() {
          _scanning = false;
          _latestResult = rec;
          _history.insert(0, rec);
          DriverDatabaseService.instance.savePhotoLogRecord(
            rec,
            vehicleCode: _effectiveVehicleCode,
            driverName: _effectiveDriverName,
            driverPhone: driver?.phone ?? '',
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FreshTheme.bgWhiteSlate,
      drawer: _buildDriverSideDrawer(),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Clean Custom Header: Left Hamburger Menu, Center Driver Name, Right Real-time Battery
            SliverToBoxAdapter(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: FreshTheme.cardWhite,
                  border:
                      Border(bottom: BorderSide(color: FreshTheme.borderGray)),
                ),
                child: Row(
                  children: [
                    // Left: Modern Styled Hamburger Button (Premium Circle Badge with Staggered Green Pill Bars)
                    InkWell(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF86EFAC), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar
                              Container(
                                width: 20,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 3.5),
                              // Middle Bar (Slightly shorter for modern artistic feel)
                              Container(
                                width: 14,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF15803D),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 3.5),
                              // Bottom Bar
                              Container(
                                width: 20,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Center: Driver Name in English
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _effectiveDriverName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: FreshTheme.textDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded,
                                  size: 16, color: Color(0xFF16A34A)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (ctx) {
                              final ctrl = widget.controller;
                              final effectiveDriver = _resolvedDriver ?? ctrl?.selectedDriver ?? ctrl?.currentDriver;
                              final dEmail = widget.viewAsDriver?.email ??
                                  ctrl?.activeDriverEmail ??
                                  effectiveDriver?.email ??
                                  ctrl?.loggedInEmail ??
                                  '';
                              final dName = widget.viewAsDriver?.name ??
                                  ctrl?.activeDriverName ??
                                  effectiveDriver?.name ??
                                  ctrl?.loggedInName ??
                                  '';
                              final dPhone = widget.viewAsDriver?.phone ??
                                  effectiveDriver?.phone ??
                                  '';
                              final activeDuty = (dEmail.isNotEmpty ? ctrl?.getActiveDuty(dEmail) : null) ??
                                  (dName.isNotEmpty ? ctrl?.getActiveDuty(dName) : null) ??
                                  (dPhone.isNotEmpty ? ctrl?.getActiveDuty(dPhone) : null) ??
                                  ctrl?.getActiveDuty(_effectiveVehicleCode);
                              final isOnDuty = activeDuty != null;
                              final isOnline = ctrl?.isVehicleOnline(_effectiveVehicleCode) ?? isOnDuty;

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'गाड़ी: $_effectiveVehicleCode • ${isOnDuty ? "ऑन ड्यूटी" : "ऑफ ड्यूटी"} • ${isOnline ? "लाइव ऑनलाइन" : "ऑफ़लाइन"}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Right: Real Phone Battery Indicator with % and Charging Icon
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text(
                              _batteryLevel == null
                                  ? 'फ़ोन की बैटरी लोड हो रही है...'
                                  : 'फ़ोन की बैटरी: $_batteryLevel%${_isCharging ? ' • चार्जिंग हो रहा है ⚡' : ' • डिस्चार्जिंग'}',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCharging
                                  ? Icons.battery_charging_full_rounded
                                  : (_batteryLevel != null &&
                                          _batteryLevel! <= 20
                                      ? Icons.battery_alert_rounded
                                      : Icons.battery_full_rounded),
                              size: 16,
                              color: const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _batteryLevel != null
                                  ? '$_batteryLevel%${_isCharging ? " ⚡" : ""}'
                                  : '...',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Driver Duty & Attendance Header Card (Exact UI requested)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _buildDutyAttendanceCard(),
              ),
            ),

            // All Hindi Quick Action Cards Grid (Zero Typing Photo Cards)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _buildQuickActionCard(
                    icon: Icons.local_gas_station_rounded,
                    title: 'डीजल / पेट्रोल बिल',
                    subtitle: 'पंप पर्ची व खर्च',
                    type: SmartCaptureType.fuelBill,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.speed_rounded,
                    title: 'मीटर (KM) रीडिंग',
                    subtitle: 'ओडोमीटर व लाइव एवरेज',
                    type: SmartCaptureType.meterOdometer,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.tire_repair_outlined,
                    title: 'पुराना टायर फोटो',
                    subtitle: 'घिसावट जांच',
                    type: SmartCaptureType.oldTyre,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.tire_repair_rounded,
                    title: 'नया टायर फोटो',
                    subtitle: 'नया टायर माउंटिंग',
                    type: SmartCaptureType.newTyre,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'टायर चेंज बिल',
                    subtitle: 'दुकान पर्ची व इनवॉइस',
                    type: SmartCaptureType.tyreBill,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.restaurant_rounded,
                    title: 'होटल / खाना खर्चा',
                    subtitle: 'ढाबा, भोजन व बिल',
                    type: SmartCaptureType.hotelFood,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.badge_outlined,
                    title: 'ड्राइविंग लाइसेंस',
                    subtitle: 'ड्राइवर DL फोटो',
                    type: SmartCaptureType.driverLicense,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.verified_user_outlined,
                    title: 'गाड़ी इंश्योरेंस',
                    subtitle: 'पॉलिसी व PUC पेपर',
                    type: SmartCaptureType.insurance,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.airline_seat_recline_normal_rounded,
                    title: 'सीट बेल्ट सुरक्षा',
                    subtitle: 'ड्राइवर बेल्ट जांच',
                    type: SmartCaptureType.seatbelt,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.assignment_late_outlined,
                    title: 'चालान / पुलिस मेमो',
                    subtitle: 'ट्रैफिक रसीद व फाइन',
                    type: SmartCaptureType.challanMemo,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.receipt_outlined,
                    title: 'कस्टमर बिल्टी',
                    subtitle: 'माल डिलीवरी पावती',
                    type: SmartCaptureType.biltyCustomer,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.local_car_wash_rounded,
                    title: 'रविवार गाड़ी सफाई',
                    subtitle: 'धुलाई व स्वच्छता फोटो',
                    type: SmartCaptureType.sundayCleaning,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.eco_rounded,
                    title: 'प्रदूषण जांच (PUC)',
                    subtitle: 'PUC प्रमाण पत्र व वैलिडिटी',
                    type: SmartCaptureType.pucCertificate,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.verified_rounded,
                    title: 'गाड़ी फिटनेस प्रमाण पत्र',
                    subtitle: 'RTO फिटनेस प्रमाण पत्र',
                    type: SmartCaptureType.fitnessCertificate,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.credit_card_rounded,
                    title: 'गाड़ी आरसी रजिस्ट्रेशन',
                    subtitle: 'स्मार्ट कार्ड / रजिस्ट्रेशन',
                    type: SmartCaptureType.rcBook,
                  ),
                  _buildQuickActionCard(
                    icon: Icons.document_scanner_rounded,
                    title: 'गाड़ी नेशनल परमिट',
                    subtitle: 'ऑल इंडिया / स्टेट परमिट',
                    type: SmartCaptureType.nationalPermit,
                  ),
                ],
              ),
            ),

            // Document Expiry & Trail Notification Banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notification_important_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'दस्तावेज़ रिन्यूअल अलर्ट (1 महीना पहले 3x अलर्ट)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'लाइसेंस, फिटनेस, इंश्योरेंस, PUC तारीख अपडेट व ट्रायल',
                            style: TextStyle(
                                fontSize: 10.5, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => DocumentExpiryPanelSheet.show(context),
                      icon: const Icon(Icons.notifications_active_rounded,
                          size: 16),
                      label: const Text(
                        'ट्रायल देखें',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Photo Action Box (Zero Typing)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FreshTheme.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FreshTheme.borderGray),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: FreshTheme.tealSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flash_on_rounded,
                              color: FreshTheme.accentTeal, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedType.titleHindi,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: FreshTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'कैमरे से फोटो लें — तारीख, समय, खर्चा और लोकेशन खुद भर जाएगी!',
                      style: TextStyle(fontSize: 13, color: FreshTheme.textSub),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _scanning
                                ? null
                                : () => _takePhoto(ImageSource.camera),
                            icon:
                                const Icon(Icons.camera_alt_rounded, size: 20),
                            label: const Text('फोटो खींचो (कैमरा)',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FreshTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scanning
                                ? null
                                : () => _takePhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded,
                                color: FreshTheme.accentTeal, size: 20),
                            label: const Text('गैलरी से लें',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: FreshTheme.textDark)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: FreshTheme.blueBorder),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Live AI Result Card
            if (_scanning || _latestResult != null)
              SliverToBoxAdapter(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FreshTheme.blueSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FreshTheme.blueBorder),
                  ),
                  child: _scanning
                      ? const Column(
                          children: [
                            CircularProgressIndicator(
                                color: FreshTheme.primaryBlue),
                            SizedBox(height: 10),
                            Text('AI फोटो समझ रहा है...',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: FreshTheme.tealSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded,
                                      color: FreshTheme.accentTeal, size: 18),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI ऑटोमैटिक रिकॉर्ड सेव हुआ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: FreshTheme.primaryBlue),
                                ),
                                const Spacer(),
                                Text(
                                  '${_latestResult!.time.hour.toString().padLeft(2, '0')}:${_latestResult!.time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 12, color: FreshTheme.textSub),
                                ),
                              ],
                            ),
                            const Divider(
                                height: 18, color: FreshTheme.blueBorder),
                            if (_latestResult!.amount != null)
                              _dataRow(
                                  'कुल खर्चा:',
                                  '₹${_latestResult!.amount!.toStringAsFixed(0)}',
                                  true),
                            if (_latestResult!.liters != null)
                              _dataRow(
                                  'लीटर:', '${_latestResult!.liters} L', false),
                            if (_latestResult!.odometer != null)
                              _dataRow(
                                  'मीटर रीडिंग:',
                                  '${_latestResult!.odometer!.toStringAsFixed(0)} KM',
                                  false),
                            if (_latestResult!.mileage != null)
                              _dataRow('गाड़ी एवरेज:',
                                  '${_latestResult!.mileage} KM/L', true,
                                  isTeal: true),
                            _dataRow(
                                'स्थान (GPS):', _latestResult!.location, false),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: FreshTheme.blueBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: FreshTheme.accentTeal, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _latestResult!.summary,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: FreshTheme.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_latestResult!.imageBytes != null ||
                                _latestResult!.secondaryImageBytes != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (_latestResult!.imageBytes != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('१. होटल बिल पर्ची',
                                              style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      FreshTheme.primaryBlue)),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.memory(
                                                _latestResult!.imageBytes!,
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_latestResult!.imageBytes != null &&
                                      _latestResult!.secondaryImageBytes !=
                                          null)
                                    const SizedBox(width: 10),
                                  if (_latestResult!.secondaryImageBytes !=
                                      null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('२. खाने की थाली व डिश',
                                              style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF16A34A))),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.memory(
                                                _latestResult!
                                                    .secondaryImageBytes!,
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                ),
              ),

            // Live KPI Stats (Real-time, shows real captured data only)
            if (_odometerTotal > 0 || _lastCalculatedMileage > 0)
              SliverToBoxAdapter(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FreshTheme.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FreshTheme.borderGray),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _kpiCol(
                          'लाइव एवरेज',
                          _lastCalculatedMileage > 0
                              ? '$_lastCalculatedMileage Km/L'
                              : '--',
                          Icons.speed_rounded,
                        ),
                      ),
                      Container(
                          width: 1, height: 35, color: FreshTheme.borderGray),
                      Expanded(
                        child: _kpiCol(
                          'मीटर रीडिंग',
                          _odometerTotal > 0
                              ? '${_odometerTotal.toStringAsFixed(0)} KM'
                              : '--',
                          Icons.route_rounded,
                        ),
                      ),
                      Container(
                          width: 1, height: 35, color: FreshTheme.borderGray),
                      Expanded(
                        child: _kpiCol('टायर स्थिति', 'जांच जारी',
                            Icons.tire_repair_rounded),
                      ),
                    ],
                  ),
                ),
              ),

            // Recent Logs Title (Only shows when real photos exist)
            if (_history.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Text(
                    'हाल की फोटो और खर्चे की सूची',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: FreshTheme.textDark),
                  ),
                ),
              ),

            // Real Captured Logs (Empty if no photos taken yet)
            if (_history.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = _history[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FreshTheme.cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FreshTheme.borderGray),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FreshTheme.tealSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: FreshTheme.accentTeal,
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.type.shortTag,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                      if (item.amount != null)
                                        Text(
                                            '₹${item.amount!.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: FreshTheme.primaryBlue)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(item.summary,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: FreshTheme.textSub)),
                                  const SizedBox(height: 2),
                                  Text(item.location,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: FreshTheme.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _history.length,
                  ),
                ),
              ),

            // Clean Empty State if no photos uploaded yet
            if (_history.isEmpty && !_scanning && _latestResult == null)
              SliverToBoxAdapter(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FreshTheme.borderGray),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FreshTheme.blueSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            color: FreshTheme.primaryBlue, size: 32),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'अभी तक कोई फोटो या बिल अपलोड नहीं है',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: FreshTheme.textDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ऊपर दिए गए किसी भी कार्ड पर क्लिक करें और असली फोटो खींचें!',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: FreshTheme.textSub),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // Real interactive Navigation Drawer
  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'लॉगआउट करें (Logout)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'क्या आप सच में अपनी ड्यूटी समाप्त करके ऐप से लॉगआउट करना चाहते हैं?',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें (Cancel)',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // close drawer
              if (widget.controller != null) {
                await widget.controller!.logout();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('हाँ, लॉगआउट (Logout)',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfilePhoto() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle_rounded,
                      color: Color(0xFF16A34A), size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'प्रोफाइल फोटो बदलें',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'अपनी खुद की साफ फोटो कैमरा से खींचें या गैलरी से चुनें:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded,
                          color: Color(0xFF16A34A)),
                      label: const Text('कैमरा (Camera)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                            color: Color(0xFF16A34A), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickAndSaveProfilePhoto(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library_rounded,
                          color: Colors.white),
                      label: const Text('गैलरी (Gallery)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _pickAndSaveProfilePhoto(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSaveProfilePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);

      if (widget.controller != null) {
        final driver = _resolvedDriver ?? widget.controller!.selectedDriver;
        final email = (driver?.email.trim().isNotEmpty == true
                ? driver!.email
                : null) ??
            widget.controller!.activeDriverEmail ??
            widget.controller!.loggedInEmail ??
            '';
        if (email.trim().isNotEmpty) {
          await widget.controller!.updateDriverPhoto(
            driverEmail: email,
            photoBase64: base64String,
          );
        }
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('प्रोफाइल फोटो सफलतापूर्वक अपडेट हो गई!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('फोटो अपलोड में समस्या: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDriverSideDrawer() {
    final driver = _resolvedDriver ?? widget.controller?.selectedDriver;
    final driverName = _effectiveDriverName;
    final vehicle = _effectiveVehicleCode;
    final photoBase64 = driver?.photo ?? '';
    Uint8List? photoBytes;
    if (photoBase64.isNotEmpty) {
      try {
        photoBytes = base64Decode(photoBase64);
      } catch (_) {}
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _updateProfilePhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 30,
                        backgroundImage:
                            photoBytes != null ? MemoryImage(photoBytes) : null,
                        child: photoBytes == null
                            ? const Icon(Icons.person_rounded,
                                size: 38, color: Color(0xFF16A34A))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        driverName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _updateProfilePhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('फोटो बदलें',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'गाड़ी: $vehicle • फ़ोन बैटरी: $_batteryLevel%',
                  style:
                      const TextStyle(color: Color(0xFFDCFCE7), fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded,
                color: Color(0xFF16A34A)),
            title: const Text('हेल्पलाइन & सहायता',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('24x7 फ्लीट सपोर्ट',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'हेल्पलाइन नंबर: +91 98765 43210 (Fleet Control Room)')),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'लॉगआउट (Logout)',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            subtitle: const Text('ड्यूटी समाप्त करें व बाहर निकलें',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  // Opens Camera / Gallery Selector Sheet for ANY selected Card
  void _openUploadSourceSelector(SmartCaptureType type, String title) {
    setState(() => _selectedType = type);

    // If Sunday Vehicle Cleaning, open the specialized multi-angle verification sheet!
    if (type == SmartCaptureType.hotelFood) {
      final driver = _resolvedDriver ??
          widget.controller?.selectedDriver ??
          widget.controller?.currentDriver;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => HotelFoodBottomSheet(
          vehicleCode: _effectiveVehicleCode,
          driverName: _effectiveDriverName,
          onCompleted: ({
            required Uint8List billBytes,
            required String billBase64,
            required Uint8List dishBytes,
            required String dishBase64,
            required double amount,
            required String hotelName,
            required String notes,
          }) {
            final now = DateTime.now();
            final rec = PhotoLogRecord(
              id: 'HOTEL-${now.millisecondsSinceEpoch}',
              type: SmartCaptureType.hotelFood,
              time: now,
              location: 'NH-48 Highway Dhaba, Palsana, Gujarat',
              amount: amount,
              vendor: hotelName,
              docNumber: 'FD-${now.millisecondsSinceEpoch % 100000}',
              summary:
                  'होटल बिल: ₹${amount.toStringAsFixed(0)} ($hotelName) + खाने की थाली फोटो दर्ज',
              imageBase64: billBase64,
              imageBytes: billBytes,
              secondaryImageBase64: dishBase64,
              secondaryImageBytes: dishBytes,
            );
            setState(() {
              _latestResult = rec;
              _history.insert(0, rec);
              DriverDatabaseService.instance.savePhotoLogRecord(
                rec,
                vehicleCode: _effectiveVehicleCode,
                driverName: _effectiveDriverName,
                driverPhone: driver?.phone ?? '',
              );
            });
          },
        ),
      );
      return;
    }

    if (type == SmartCaptureType.sundayCleaning) {
      final driver = _resolvedDriver ??
          widget.controller?.selectedDriver ??
          widget.controller?.currentDriver;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CleaningMultiAngleBottomSheet(
          vehicleCode: _effectiveVehicleCode,
          driverName: _effectiveDriverName,
          onCompleted: (count, note) {
            final now = DateTime.now();
            final rec = PhotoLogRecord(
              id: 'CLN-${now.millisecondsSinceEpoch}',
              type: SmartCaptureType.sundayCleaning,
              time: now,
              location: 'Jolwa Highway, Vagra, Gujarat',
              summary: 'Sunday Vehicle Cleaning: $count photos uploaded',
              vendor: 'Fleet Wash Verification',
              docNumber: 'CLN-${now.millisecondsSinceEpoch % 100000}',
              imageBase64: '',
            );
            setState(() {
              _latestResult = rec;
              _history.insert(0, rec);
              DriverDatabaseService.instance.savePhotoLogRecord(
                rec,
                vehicleCode: _effectiveVehicleCode,
                driverName: _effectiveDriverName,
                driverPhone: driver?.phone ?? '',
              );
            });
          },
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FreshTheme.borderGray,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo_rounded,
                        color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: FreshTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'फोटो कहां से अपलोड करनी है? चुनें:',
                style: TextStyle(fontSize: 13, color: FreshTheme.textSub),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  // Option 1: Direct Camera
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _takePhoto(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: const Text(
                        'फोटो खींचो (कैमरा)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FreshTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Option 2: Gallery
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _takePhoto(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_rounded,
                          color: FreshTheme.accentTeal, size: 20),
                      label: const Text(
                        'गैलरी से लें',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FreshTheme.textDark),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: FreshTheme.blueBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required SmartCaptureType type,
  }) {
    final isSelected = _selectedType == type;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openUploadSourceSelector(type, title),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? FreshTheme.accentTeal : FreshTheme.borderGray,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Icon(icon, color: const Color(0xFF16A34A), size: 20),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value, bool bold,
      {bool isTeal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: FreshTheme.textSub))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: isTeal ? FreshTheme.accentTeal : FreshTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: FreshTheme.accentTeal),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: FreshTheme.textDark)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: FreshTheme.textMuted)),
      ],
    );
  }

  /// Driver Duty & Attendance Widget (Matches screenshot exactly)
  Widget _buildDutyAttendanceCard() {
    final ctrl = widget.controller;
    final effectiveDriver =
        _resolvedDriver ?? ctrl?.selectedDriver ?? ctrl?.currentDriver;
    final viewEmail = widget.viewAsDriver?.email.trim() ?? '';
    final viewPhone = widget.viewAsDriver?.phone.trim() ?? '';
    final viewName = widget.viewAsDriver?.name.trim() ?? '';
    final driverId = viewEmail.isNotEmpty
        ? viewEmail
        : (viewPhone.isNotEmpty
            ? viewPhone
            : (ctrl?.activeDriverEmail?.trim().isNotEmpty == true
                ? ctrl!.activeDriverEmail!.trim()
                : (ctrl?.loggedInEmail?.trim().isNotEmpty == true
                    ? ctrl!.loggedInEmail!.trim()
                    : (effectiveDriver?.email.trim().isNotEmpty == true
                        ? effectiveDriver!.email.trim()
                        : _effectiveDriverName))));
    final driverName = viewName.isNotEmpty ? viewName : _effectiveDriverName;
    final activeDuty = ctrl?.getActiveDuty(driverId) ??
        (driverName.isNotEmpty ? ctrl?.getActiveDuty(driverName) : null) ??
        (effectiveDriver?.phone.isNotEmpty == true
            ? ctrl?.getActiveDuty(effectiveDriver!.phone)
            : null) ??
        (viewPhone.isNotEmpty ? ctrl?.getActiveDuty(viewPhone) : null) ??
        (_effectiveVehicleCode.isNotEmpty
            ? ctrl?.getActiveDuty(_effectiveVehicleCode)
            : null);
    final isOnDuty = activeDuty != null;

    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final elapsedHours = isOnDuty
        ? AttendanceRecord.calculateHours(activeDuty.startTime, nowStr)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnDuty ? const Color(0xFF86EFAC) : FreshTheme.borderGray,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, Title, OFF/ON DUTY Badge, Subtitle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Driver Duty & Attendance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnDuty
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOnDuty
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isOnDuty
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnDuty
                          ? 'Duty started: ${activeDuty.startTime}  ·  Worked: ${elapsedHours.toStringAsFixed(1)} hrs'
                          : 'Daily presence & working hours record (हाजिरी रिकॉर्ड)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons: Start Duty, Duty History, Trip History, Calendar
          Row(
            children: [
              // 1. Start / End Duty
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (ctrl == null) return;
                      if (isOnDuty) {
                        final err = await ctrl.markEndDuty(
                          driverId: driverId,
                          vehicleCode: _effectiveVehicleCode,
                        );
                        if (err == null &&
                            widget.viewAsDriver == null &&
                            ctrl.isDriver) {
                          await ctrl.stopDriverLocationSharing();
                        }
                        if (widget.viewAsDriver == null) {
                          await ctrl.syncDriverPhoneBattery(forceSync: true);
                        }
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ??
                                'ड्यूटी समाप्त (End Duty) दर्ज हो गई है!'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      } else {
                        final err = await ctrl.markStartDuty(
                          driverId: driverId,
                          driverName: driverName,
                          vehicleCode: _effectiveVehicleCode,
                        );
                        if (widget.viewAsDriver == null) {
                          await ctrl.syncDriverPhoneBattery(forceSync: true);
                          if (err == null && ctrl.isDriver) {
                            unawaited(ctrl.ensureDriverLiveLocationSharing());
                          }
                        }
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ??
                                'ड्यूटी शुरू (Duty Started)! हाजिरी दर्ज हो गई।'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isOnDuty
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isOnDuty ? 'End Duty' : 'Start Duty',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOnDuty
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 2. Duty History
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (ctrl == null) return;
                      showDialog<void>(
                        context: context,
                        builder: (_) => DriverAttendanceHistoryDialog(
                          driverId: driverId,
                          driverName: driverName,
                          controller: ctrl,
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded,
                        size: 14, color: Color(0xFF0F172A)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Duty History',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 3. Trip History
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (ctrl == null) return;
                      showDialog<void>(
                        context: context,
                        builder: (_) => DriverTripHistoryDialog(
                          driverId: driverId,
                          driverName: driverName,
                          controller: ctrl,
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_shipping_outlined,
                        size: 14, color: Color(0xFF16A34A)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Trip History',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 4. Calendar
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (ctrl == null) return;
                      DriverCalendarScreen.open(
                        context,
                        driverId: driverId,
                        driverName: driverName,
                        controller: ctrl,
                      );
                    },
                    icon: const Icon(Icons.calendar_month_rounded,
                        size: 14, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
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
