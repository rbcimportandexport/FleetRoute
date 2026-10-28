import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/app_localization_service.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';
import 'fleet_workspace.dart';
import 'route_planner_page.dart';
import '../widgets/cargo_workflow_dialogs.dart';
import '../widgets/delivery_proof_dialog.dart';
import '../widgets/driver_trip_history_dialog.dart';
import '../widgets/seatbelt_records_dialog.dart';
import '../widgets/trip_detail_report_dialog.dart';

class DriverPortalPage extends StatefulWidget {
  const DriverPortalPage({
    required this.controller,
    required this.onNavigate,
    this.driverOverride,
    this.adminPreview = false,
    super.key,
  });

  final PlannerController controller;
  final ValueChanged<WorkspaceSection> onNavigate;
  final DriverProfile? driverOverride;
  final bool adminPreview;

  static Future<void> openDriverDashboard(
    BuildContext context, {
    required PlannerController controller,
    required DriverProfile driver,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverPortalPage(
          controller: controller,
          driverOverride: driver,
          adminPreview: true,
          onNavigate: (_) {},
        ),
      ),
    );
  }

  @override
  State<DriverPortalPage> createState() => _DriverPortalPageState();
}

class _DriverPortalPageState extends State<DriverPortalPage> {
  DriverProfile? get _activeDriver =>
      widget.driverOverride ?? widget.controller.currentDriver;

  TruckModel? get _activeTruck {
    final code = _activeDriver?.assignedVehicle.trim().toLowerCase() ?? '';
    if (code.isEmpty) return null;
    for (final truck in widget.controller.truckModels) {
      if (truck.code.trim().toLowerCase() == code ||
          truck.name.trim().toLowerCase() == code) {
        return truck;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeeklyReminders();
      _ensureActiveDutyGps();
    });
  }

  Future<void> _ensureActiveDutyGps() async {
    if (widget.adminPreview || !widget.controller.isDriver) return;
    final driver = _activeDriver;
    if (driver == null) return;
    final driverId = _dutyDriverId(driver, driver.name);
    if (widget.controller.getActiveDuty(driverId) == null) return;
    await widget.controller.ensureDriverLiveLocationSharing();
  }

  void _checkWeeklyReminders() {
    if (widget.adminPreview) return;
    final now = DateTime.now();
    final driver = widget.controller.currentDriver;
    final vehicle = driver?.assignedVehicle.trim() ?? '';
    if (vehicle.isEmpty) return;

    if (now.weekday == DateTime.sunday) {
      final hasCleaningAlert = widget.controller.alerts.any(
        (a) => a.category == 'cleaning' && a.vehicleNumber == vehicle,
      );
      if (!hasCleaningAlert) {
        widget.controller.logSundayCleaningAlert(
          driverName: driver?.name ?? 'Driver',
          vehicleNumber: vehicle,
        );
      }
    }
  }

  void _openPhotoCapture(BuildContext context, {required String category}) {
    if (widget.adminPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Admin preview mein upload band hai. Driver apne account se upload karega.'),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoUploadBottomSheet(
        controller: widget.controller,
        category: category,
      ),
    );
  }

  String _photoDayDateTime(DateTime timestamp) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = timestamp.hour == 0
        ? 12
        : (timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '${days[timestamp.weekday - 1]}, ${timestamp.day} ${months[timestamp.month - 1]} ${timestamp.year}  •  $hour:$minute $period';
  }

  void _showCategoryPhotos(
    BuildContext context, {
    required String title,
    required List<SeatbeltRecord> records,
    required VoidCallback uploadAction,
  }) {
    final sortedRecords = [...records]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .88,
          maxChildSize: .96,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                child: Row(
                  children: [
                    const AppIconBadge(
                        icon: Icons.photo_library_outlined,
                        size: 20,
                        padding: 8),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.navy)),
                          Text(
                              '${sortedRecords.length} uploaded image${sortedRecords.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.slate)),
                        ],
                      ),
                    ),
                    if (!widget.adminPreview)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Future<void>.delayed(
                              const Duration(milliseconds: 180), uploadAction);
                        },
                        icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                        label: const Text('Upload'),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: sortedRecords.isEmpty
                    ? ListView(
                        controller: scrollController,
                        children: [
                          const SizedBox(height: 90),
                          const Icon(Icons.photo_library_outlined,
                              size: 54, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text('Abhi koi image upload nahi hui.',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate)),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                        itemCount: sortedRecords.length,
                        separatorBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFDDE5EC)),
                        ),
                        itemBuilder: (context, index) {
                          final record = sortedRecords[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 230,
                                  color: const Color(0xFFF1F5F9),
                                  child: _buildThumbnail(record.photoBase64,
                                      fit: BoxFit.contain),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFDCFCE7),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.schedule_rounded,
                                        size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            _photoDayDateTime(record.timestamp),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navy)),
                                        const SizedBox(height: 3),
                                        Text(
                                            '${record.driverName}  •  ${record.vehicleNumber}',
                                            style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.slate)),
                                        if (record.location
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text('Location: ${record.location}',
                                              style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppColors.slate)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppColors.primary),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNextSundayDate() {
    final now = DateTime.now();
    final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
    final nextSunday =
        now.add(Duration(days: daysUntilSunday == 0 ? 7 : daysUntilSunday));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${nextSunday.day} ${months[nextSunday.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizationService.instance.currentLanguage,
      builder: (context, _, __) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final driver = _activeDriver;
            final driverName =
                driver?.name ?? widget.controller.loggedInName ?? 'Driver';
            final vehicleNumber =
                driver?.assignedVehicle.trim().isNotEmpty == true
                    ? driver!.assignedVehicle.trim()
                    : 'Not assigned';
            final dutyDriverId = _dutyDriverId(driver, driverName);
            final isOnDuty =
                widget.controller.getActiveDuty(dutyDriverId) != null;
            final isSunday = DateTime.now().weekday == DateTime.sunday;
            final driverRecords = widget.controller.seatbeltRecords.where((r) {
              final tVehicle =
                  vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
              final rVehicle = r.vehicleNumber
                  .replaceAll(RegExp(r'[\s\-]'), '')
                  .toUpperCase();
              final tDriver = driverName.trim().toLowerCase();
              final rDriver = r.driverName.trim().toLowerCase();
              return (rVehicle.isNotEmpty && rVehicle == tVehicle) ||
                  (rDriver.isNotEmpty && rDriver == tDriver);
            }).toList();

            // Resolve active assigned trip for driver/vehicle
            TripRecord? activeTrip;
            for (final t in widget.controller.trips) {
              final vMatch = t.assignedVehicle.isNotEmpty &&
                  t.assignedVehicle
                          .replaceAll(RegExp(r'[\s\-]'), '')
                          .toUpperCase() ==
                      vehicleNumber
                          .replaceAll(RegExp(r'[\s\-]'), '')
                          .toUpperCase();
              final dMatch = t.assignedDriver.isNotEmpty &&
                  t.assignedDriver.trim().toLowerCase() ==
                      driverName.trim().toLowerCase();
              if (vMatch || dMatch) {
                if (t.status != 'delivered') {
                  activeTrip = t;
                  break;
                }
              }
            }
            activeTrip ??=
                !widget.adminPreview && widget.controller.trips.isNotEmpty
                    ? widget.controller.trips.first
                    : null;

            return Scaffold(
              backgroundColor: AppColors.canvas,
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Driver & Vehicle Profile Header (Clean White Card)
                      _buildDriverHeader(driverName, vehicleNumber,
                          driver?.phone ?? '', isOnDuty),
                      const SizedBox(height: 14),

                      // 1A. Highlighted Alert: New Ride Assigned by Admin (Accept & Start Actions)
                      if (activeTrip != null &&
                          (activeTrip.status == 'assigned' ||
                              activeTrip.operationalStep == 'not_started')) ...[
                        _buildNewRideAssignedAlertCard(
                          activeTrip,
                          vehicleNumber,
                          driverName,
                          widget.controller.trips.indexOf(activeTrip),
                        ),
                      ],

                      // 1B. Driver Attendance & Duty Presence (Requirement 1: Start/End Duty, Duplicate Guard, Working Hours)
                      _buildDriverAttendanceCard(
                          driver, driverName, vehicleNumber, activeTrip),
                      const SizedBox(height: 14),

                      // 2. Active Trip Sheet & Milestone Actions (Trip #, Loading/Unloading, POD, Expenses)
                      if (activeTrip != null) ...[
                        _buildActiveTripSheetCard(
                            activeTrip, vehicleNumber, driverName),
                        const SizedBox(height: 14),
                      ],

                      // 3. Driver Compliance (Driving License & Driver Insurance Validity)
                      _buildDriverDocumentsCard(driver),
                      const SizedBox(height: 14),

                      // 4. Tyre Change & Daily Fluids Check Actions
                      _buildOperationsActionRow(vehicleNumber),
                      const SizedBox(height: 14),

                      // 5. Weekly Sunday Cleaning Card (Same Green Icon Badge)
                      _buildSundayCleaningCard(isSunday, vehicleNumber),
                      const SizedBox(height: 12),

                      // 6. Police / RTO Memo Quick Banner (Same Green Icon Badge)
                      _buildMemoQuickActionBanner(vehicleNumber),
                      const SizedBox(height: 14),

                      // 7. Maintenance & Insurance Notification Cards (Same Green Icon Badges)
                      _buildMaintenanceAndInsuranceSection(vehicleNumber),
                      const SizedBox(height: 20),

                      // 5. Easy One-Tap Photo Action Center Header
                      Row(
                        children: [
                          const AppIconBadge(
                            icon: Icons.camera_alt_rounded,
                            size: 18,
                            padding: 6,
                            radius: 8,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizationService.instance
                                      .tr('quick_upload_title'),
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
                                  AppLocalizationService.instance
                                      .tr('quick_upload_subtitle'),
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
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. Action Grid - Every icon has the EXACT same color & badge
                      _buildPhotoActionGrid(context, driverRecords),
                      const SizedBox(height: 18),

                      // 7. GPS Navigation Quick Launcher (Same Green Icon Badge)
                      _buildNavigationLauncher(activeTrip),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _dutyDriverId(DriverProfile? driver, String fallbackName) {
    if (driver?.name.trim().isNotEmpty == true) return driver!.name.trim();
    if (driver?.email.trim().isNotEmpty == true) return driver!.email.trim();
    if (driver?.phone.trim().isNotEmpty == true) return driver!.phone.trim();
    return fallbackName.trim();
  }

  Widget _buildDriverHeader(
      String name, String vehicle, String phone, bool isOnDuty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'sans-serif',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOnDuty
                                ? AppColors.primaryLight
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOnDuty
                                  ? AppColors.iconBadgeBorder
                                  : const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 8,
                                  color: isOnDuty
                                      ? AppColors.iconColor
                                      : AppColors.slate),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizationService.instance
                                    .tr(isOnDuty ? 'on_duty' : 'off_duty'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isOnDuty
                                      ? AppColors.primaryDark
                                      : AppColors.slate,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.isNotEmpty ? 'Mob: $phone' : 'Fleet Active Driver',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => widget.adminPreview
                    ? Navigator.pop(context)
                    : _confirmLogout(context),
                borderRadius: BorderRadius.circular(10),
                child: AppIconBadge(
                  icon: widget.adminPreview
                      ? Icons.arrow_back_rounded
                      : Icons.logout_rounded,
                  size: 18,
                  padding: 7,
                  radius: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              children: [
                const AppIconBadge(
                  icon: Icons.local_shipping_rounded,
                  size: 20,
                  padding: 6,
                  radius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizationService.instance.tr('assigned_vehicle'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      Text(
                        vehicle,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizationService.instance.tr('verified_truck'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteVehicleDetails(
      TruckModel? truck, String assignedVehicle) {
    String value(String raw) => raw.trim().isEmpty ? 'Not configured' : raw;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppIconBadge(
                icon: Icons.local_shipping_outlined,
                size: 18,
                padding: 7,
                radius: 9,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete Vehicle Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (truck == null)
            Text(
              assignedVehicle == 'Not assigned'
                  ? 'No vehicle assigned to this driver.'
                  : 'Vehicle $assignedVehicle is assigned, but its master record was not found.',
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _vehicleDetail('Vehicle Number', truck.code),
                _vehicleDetail('Vehicle Name / Model', truck.name),
                _vehicleDetail('Vehicle Type', value(truck.vehicleModel)),
                _vehicleDetail('Owner', value(truck.ownerName)),
                _vehicleDetail('Status', value(truck.vehicleStatus)),
                _vehicleDetail('Capacity', value(truck.capacity)),
                _vehicleDetail('Axles', value(truck.axles)),
                _vehicleDetail('Odometer', '${truck.currentOdometerKm} km'),
                _vehicleDetail('Next Service', '${truck.nextServiceKm} km'),
                _vehicleDetail('Speed Limit', '${truck.maxSpeed} km/h'),
                _vehicleDetail('FASTag Balance',
                    'Rs ${truck.fastagBalance.toStringAsFixed(0)}'),
                _vehicleDetail('GPS / Tracker',
                    truck.hasValidGpsFix ? 'Connected' : 'No live fix'),
                _vehicleDetail('Last GPS Update', value(truck.lastGpsUpdate)),
                _vehicleDetail('Insurance No.', value(truck.insuranceNumber)),
                _vehicleDetail(
                    'Insurance Expiry', value(truck.insuranceExpiry)),
                _vehicleDetail('PUC No.', value(truck.pucNumber)),
                _vehicleDetail('PUC Expiry', value(truck.pucExpiry)),
                _vehicleDetail('Fitness No.', value(truck.fitnessNumber)),
                _vehicleDetail('Fitness Expiry', value(truck.fitnessExpiry)),
                _vehicleDetail('RC Expiry', value(truck.rcExpiry)),
                _vehicleDetail(
                    'Permit Expiry', value(truck.allIndiaPermitExpiry)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _vehicleDetail(String label, String value) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.slate)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
        ],
      ),
    );
  }

  void _openPodCapture(BuildContext context, TripRecord trip,
      {bool isReceivingCopy = false}) {
    final cat =
        isReceivingCopy ? 'Signed Receiving Copy' : 'Proof of Delivery (POD)';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoUploadBottomSheet(
        controller: widget.controller,
        category: cat,
        onPhotoUploaded: (base64) async {
          final tripIndex = widget.controller.trips.indexOf(trip);
          if (tripIndex != -1) {
            if (isReceivingCopy) {
              await widget.controller.updateTripReceivingCopy(
                index: tripIndex,
                receivingCopyPhoto: base64,
              );
            } else {
              await widget.controller.updateTripPod(
                index: tripIndex,
                podPhoto: base64,
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildDriverAttendanceCard(DriverProfile? driver, String driverName,
      String vehicleNumber, TripRecord? activeTrip) {
    final driverId = _dutyDriverId(driver, driverName);
    final activeDuty = widget.controller.getActiveDuty(driverId);
    final isOnDuty = activeDuty != null;

    final now = DateTime.now();
    final nowStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final elapsedHours = isOnDuty
        ? AttendanceRecord.calculateHours(activeDuty.startTime, nowStr)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnDuty ? AppColors.iconBadgeBorder : AppColors.border,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnDuty ? AppColors.primary : AppColors.navy)
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon:
                    isOnDuty ? Icons.timer_rounded : Icons.access_time_rounded,
                size: 20,
                padding: 7,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppLocalizationService.instance
                                .tr('duty_attendance_title'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnDuty
                                ? AppColors.primaryLight
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOnDuty
                                  ? AppColors.iconBadgeBorder
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            isOnDuty
                                ? AppLocalizationService.instance.tr('on_duty')
                                : AppLocalizationService.instance
                                    .tr('off_duty'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isOnDuty
                                  ? AppColors.primaryDark
                                  : AppColors.slate,
                              fontFamily: 'sans-serif',
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
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isOnDuty && widget.controller.lastGpsSyncError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded,
                      size: 17, color: Color(0xFFDC2626)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.controller.lastGpsSyncError!,
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFF991B1B)),
                    ),
                  ),
                  TextButton(
                    onPressed: _ensureActiveDutyGps,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (isOnDuty) {
                      final err = await widget.controller
                          .markEndDuty(driverId: driverId);
                      if (err == null) {
                        widget.controller.stopGpsAutoPolling();
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ??
                              'Duty ended successfully! Hours recorded.'),
                          backgroundColor: err != null
                              ? const Color(0xFFDC2626)
                              : AppColors.primary,
                        ),
                      );
                    } else {
                      final err = await widget.controller.markStartDuty(
                        driverId: driverId,
                        driverName: driverName,
                        tripId: activeTrip?.reference ?? '',
                      );
                      String? gpsError;
                      if (err == null) {
                        gpsError = await widget.controller
                            .ensureDriverLiveLocationSharing();
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ??
                              (gpsError ??
                                  'Duty started! Live GPS location shared.')),
                          backgroundColor: err != null || gpsError != null
                              ? const Color(0xFFDC2626)
                              : AppColors.primary,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isOnDuty
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isOnDuty
                        ? AppLocalizationService.instance.tr('end_duty')
                        : AppLocalizationService.instance.tr('start_duty'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isOnDuty ? const Color(0xFFD97706) : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => DriverAttendanceHistoryDialog(
                        driverId: driverId,
                        driverName: driverName,
                        controller: widget.controller,
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: Text(
                    AppLocalizationService.instance.tr('attendance_history'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => DriverTripHistoryDialog(
                        driverId: driverId,
                        driverName: driverName,
                        controller: widget.controller,
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 14),
                  label: Text(
                    AppLocalizationService.instance.tr('trip_history'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteActiveTrip(TripRecord trip) async {
    final index = widget.controller.trips.indexOf(trip);
    if (index < 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text(
          'Trip ${trip.effectiveTripNumber} permanently remove ho jayegi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.controller.removeTrip(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip ${trip.effectiveTripNumber} deleted.')),
    );
  }

  Widget _buildActiveTripSheetCard(
      TripRecord trip, String vehicleNumber, String driverName) {
    final tripIndex = widget.controller.trips.indexOf(trip);
    final isDelivered = trip.status == 'delivered';
    final currentStep =
        trip.operationalStep.isEmpty ? 'not_started' : trip.operationalStep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Trip Number + Status Chip + View Report Button
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => TripDetailReportDialog(
                        trip: trip,
                        controller: widget.controller,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.assignment_outlined,
                        size: 18,
                        padding: 6,
                        radius: 8,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Trip # ${trip.effectiveTripNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => TripDetailReportDialog(
                      trip: trip,
                      controller: widget.controller,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.iconBadgeBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 11, color: AppColors.primaryDark),
                      SizedBox(width: 3),
                      Text(
                        'REPORT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? AppColors.primaryLight
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDelivered
                        ? AppColors.iconBadgeBorder
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  trip.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDelivered
                        ? AppColors.primaryDark
                        : const Color(0xFFB45309),
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _deleteActiveTrip(trip),
                tooltip: 'Delete trip',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 10-Step Operational Lifecycle Stepper (Requirement 6)
          _buildOperationalStepper(trip),
          const SizedBox(height: 14),

          // Route: Origin -> Destination
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    size: 14, color: AppColors.iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.iconColor),
                ),
                const Icon(Icons.location_on_rounded,
                    size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cargo & Shipment Balance Section (Requirement 2)
          _buildCargoBalanceSection(trip),
          const SizedBox(height: 12),

          // Customer and Location Details with Quick Contact (Requirement 9)
          _buildCustomerContactCard(trip),
          const SizedBox(height: 14),

          // Dynamic Lifecycle Primary Action Button (10 steps)
          if (!isDelivered) ...[
            _buildNextLifecycleActionButton(trip, currentStep, tripIndex),
            const SizedBox(height: 10),
          ],

          // Quick Action Bar: POD Upload, Receiving Copy, Expense Logger
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => DeliveryProofDialog(
                        trip: trip,
                        controller: widget.controller,
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_outlined, size: 14),
                  label: Text(
                    trip.podStatus == 'received'
                        ? 'POD: SAVED'
                        : AppLocalizationService.instance.tr('delivery_proof'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(
                      color: trip.podStatus == 'received'
                          ? AppColors.primary
                          : AppColors.primaryBorder,
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPodCapture(context, trip, isReceivingCopy: true),
                  icon: const Icon(Icons.receipt_outlined, size: 14),
                  label: Text(
                    trip.receivingCopyStatus == 'received'
                        ? 'RCV: SAVED'
                        : AppLocalizationService.instance.tr('receiving_copy'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(
                      color: trip.receivingCopyStatus == 'received'
                          ? AppColors.primary
                          : AppColors.primaryBorder,
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showTripExpenseSheet(context, trip),
                  icon: const Icon(Icons.payments_outlined, size: 14),
                  label: Text(
                    AppLocalizationService.instance.tr('kharcha'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalStepper(TripRecord trip) {
    const steps = [
      'not_started',
      'navigating_pickup',
      'arrived_pickup',
      'loading',
      'loaded',
      'navigating_delivery',
      'arrived_delivery',
      'unloading',
      'unloaded',
      'trip_completed',
    ];

    final currentIdx = steps.indexOf(trip.operationalStep);
    final effectiveIdx =
        currentIdx >= 0 ? currentIdx : (trip.status == 'delivered' ? 9 : 0);
    final stepNum = effectiveIdx + 1;

    String stepTitle;
    String stepHindi;
    switch (trip.operationalStep) {
      case 'not_started':
        stepTitle = 'Step 1/10: Ready to Start Trip';
        stepHindi = 'यात्रा शुरू करने के लिए तैयार';
        break;
      case 'navigating_pickup':
        stepTitle = 'Step 2/10: En Route to Pickup Point';
        stepHindi = 'पिकअप स्थान के रास्ते में हैं';
        break;
      case 'arrived_pickup':
        stepTitle = 'Step 3/10: Arrived at Pickup Depot';
        stepHindi = 'पिकअप गोदाम पर पहुंचे';
        break;
      case 'loading':
        stepTitle = 'Step 4/10: Cargo Loading in Progress';
        stepHindi = 'सामान लोड हो रहा है';
        break;
      case 'loaded':
        stepTitle = 'Step 5/10: Loading Verified & Secured';
        stepHindi = 'माल लोड हो गया, चलने के लिए तैयार';
        break;
      case 'navigating_delivery':
        stepTitle = 'Step 6/10: In Transit to Customer Drop';
        stepHindi = 'डिलीवरी स्थान की तरफ बढ़ रहे हैं';
        break;
      case 'arrived_delivery':
        stepTitle = 'Step 7/10: Arrived at Destination Drop';
        stepHindi = 'ग्राहक के पते पर पहुंचे';
        break;
      case 'unloading':
        stepTitle = 'Step 8/10: Cargo Unloading in Progress';
        stepHindi = 'माल उतारा जा रहा है';
        break;
      case 'unloaded':
        stepTitle = 'Step 9/10: Unloading Complete';
        stepHindi = 'अनलोडिंग पूरी हुई, प्रूफ बाकी है';
        break;
      case 'trip_completed':
        stepTitle = 'Step 10/10: Delivery Proof Confirmed';
        stepHindi = 'डिलीवरी पूरी और यात्रा समाप्त';
        break;
      default:
        stepTitle = 'Step $stepNum/10: In Progress';
        stepHindi = 'यात्रा चालू है';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                stepTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$stepNum of 10',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.iconColor,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          stepHindi,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.slate,
            fontFamily: 'sans-serif',
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: stepNum / 10.0,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCargoBalanceSection(TripRecord trip) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizationService.instance.tr('cargo_balance_title'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                    letterSpacing: 0.5,
                    fontFamily: 'sans-serif',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => CargoLedgerDialog(trip: trip),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 12, color: AppColors.iconColor),
                    const SizedBox(width: 3),
                    Text(
                      AppLocalizationService.instance.tr('stop_ledger'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.iconColor,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBalanceBadge('Loaded', trip.totalLoadedCargo,
                  const Color(0xFFEFF6FF), const Color(0xFF1E40AF)),
              const SizedBox(width: 6),
              _buildBalanceBadge('Delivered', trip.totalDeliveredCargo,
                  AppColors.primarySoft, AppColors.primaryDark),
              const SizedBox(width: 6),
              _buildBalanceBadge('Remaining', trip.totalRemainingCargo,
                  const Color(0xFFFFFBEB), const Color(0xFFD97706)),
              if (trip.totalDamagedCargo > 0 ||
                  trip.totalReturnedCargo > 0) ...[
                const SizedBox(width: 6),
                _buildBalanceBadge(
                    'Issues',
                    trip.totalDamagedCargo + trip.totalReturnedCargo,
                    const Color(0xFFFEF2F2),
                    const Color(0xFFDC2626)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBadge(
      String label, double value, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
                fontFamily: 'sans-serif',
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.85),
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerContactCard(TripRecord trip) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.business_outlined,
                size: 16,
                padding: 5,
                radius: 6,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.customerName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Cargo: ${trip.cargoDescription}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trip.driverInstructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: Color(0xFFB45309)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Driver Notice: ${trip.driverInstructions}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final query = Uri.encodeComponent(trip.destination);
                    final url = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$query');
                    launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 13),
                  label:
                      Text(AppLocalizationService.instance.tr('google_maps')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryBorder),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final customer = widget.controller.customers.firstWhere(
                      (c) =>
                          c.name.toLowerCase() ==
                          trip.customerName.toLowerCase(),
                      orElse: () => CustomerRecord(
                        id: '',
                        name: trip.customerName,
                        phone: '',
                        address: trip.destination,
                      ),
                    );
                    final phone = customer.phone.replaceAll(RegExp(r'\D'), '');
                    if (phone.isNotEmpty) {
                      launchUrl(Uri.parse('tel:$phone'));
                    }
                  },
                  icon: const Icon(Icons.phone_rounded, size: 13),
                  label:
                      Text(AppLocalizationService.instance.tr('call_customer')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewRideAssignedAlertCard(
    TripRecord trip,
    String vehicleNumber,
    String driverName,
    int tripIndex,
  ) {
    final isAssignedOnly = trip.status == 'assigned';

    // Format cargo summary with items
    String cargoSummary = trip.cargoDescription;
    if (trip.cargoItems.isNotEmpty) {
      final itemsStr = trip.cargoItems
          .map((item) =>
              '${item.loadedQuantity > 0 ? "${item.loadedQuantity.toStringAsFixed(item.loadedQuantity.truncateToDouble() == item.loadedQuantity ? 0 : 1)} " : ""}${item.productName}${item.unit.isNotEmpty ? " (${item.unit})" : ""}')
          .join(', ');
      cargoSummary = itemsStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A16A34A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAssignedOnly
                          ? 'NEW RIDE ASSIGNED BY ADMIN'
                          : 'RIDE ACCEPTED - READY TO START',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isAssignedOnly
                            ? const Color(0xFF15803D)
                            : const Color(0xFF0284C7),
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    Text(
                      'Trip # ${trip.effectiveTripNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAssignedOnly
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAssignedOnly
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  trip.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isAssignedOnly
                        ? const Color(0xFFB45309)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFBBF7D0)),
          const SizedBox(height: 10),

          // Route: Origin -> Stops -> Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin_rounded,
                  size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pickup: ${trip.origin}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (trip.stops.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (int i = 0; i < trip.stops.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Stop ${i + 1}: ${trip.stops[i]}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Drop: ${trip.destination}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Customer & Cargo Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer: ${trip.customerName.isNotEmpty ? trip.customerName : "Direct Customer"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cargo: $cargoSummary',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trip.plannedDistanceKm > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${trip.plannedDistanceKm.toStringAsFixed(0)} KM',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Two Action Buttons: Accept Ride & Start Ride
          Row(
            children: [
              if (isAssignedOnly) ...[
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      await widget.controller.acceptTrip(trip.reference);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride Accepted! Ab aap trip start kar sakte hain.'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'ACCEPT RIDE (स्वीकार करें)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (isAssignedOnly) {
                      await widget.controller.acceptTrip(trip.reference);
                    }
                    await widget.controller.updateTripOperationalStep(
                      tripReference: trip.reference,
                      step: 'navigating_pickup',
                      status: 'in_transit',
                    );
                    if (tripIndex >= 0) {
                      await widget.controller.updateTripMilestones(
                        index: tripIndex,
                        status: 'in_transit',
                      );
                    }
                    widget.controller.setRoute(
                      newOrigin: trip.origin.trim(),
                      newDestination: trip.destination.trim(),
                      newStops: trip.stops,
                    );
                    if (widget.adminPreview || Navigator.of(context).canPop()) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Route Map & Live Navigation'),
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                            ),
                            body: RoutePlannerPage(controller: widget.controller),
                          ),
                        ),
                      );
                    } else {
                      widget.onNavigate(WorkspaceSection.planner);
                    }
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text(
                    isAssignedOnly
                        ? 'START & OPEN MAP'
                        : 'START TRIP & OPEN MAP',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
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

  Widget _buildNextLifecycleActionButton(
      TripRecord trip, String currentStep, int tripIndex) {
    String label;
    IconData icon;
    Color buttonColor;
    VoidCallback? onTap;

    switch (currentStep) {
      case 'not_started':
        final isAssignedOnly = trip.status == 'assigned';
        label = isAssignedOnly
            ? '1. ACCEPT RIDE (एडमिन की राइड स्वीकार करें)'
            : '1. START TRIP & OPEN MAP (यात्रा शुरू करें)';
        icon = isAssignedOnly ? Icons.check_circle_rounded : Icons.play_arrow_rounded;
        buttonColor = isAssignedOnly ? const Color(0xFF16A34A) : AppColors.primary;
        onTap = () async {
          if (isAssignedOnly) {
            await widget.controller.acceptTrip(trip.reference);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ride Accepted! Ab aap trip start kar sakte hain.'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
          } else {
            await widget.controller.updateTripOperationalStep(
              tripReference: trip.reference,
              step: 'navigating_pickup',
              status: 'in_transit',
            );
            if (tripIndex >= 0) {
              await widget.controller.updateTripMilestones(
                index: tripIndex,
                status: 'in_transit',
              );
            }
            widget.controller.setRoute(
              newOrigin: trip.origin.trim(),
              newDestination: trip.destination.trim(),
              newStops: trip.stops,
            );
            if (widget.adminPreview || Navigator.of(context).canPop()) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Route Map & Live Navigation'),
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    body: RoutePlannerPage(controller: widget.controller),
                  ),
                ),
              );
            } else {
              widget.onNavigate(WorkspaceSection.planner);
            }
          }
        };
        break;

      case 'navigating_pickup':
        label = '2. CONFIRM ARRIVAL AT PICKUP (पिकअप पर पहुंचे)';
        icon = Icons.location_on_rounded;
        buttonColor = const Color(0xFF0284C7);
        onTap = () async {
          await widget.controller.updateTripOperationalStep(
            tripReference: trip.reference,
            step: 'arrived_pickup',
          );
        };
        break;

      case 'arrived_pickup':
        label = '3. START LOADING (माल लोड करना शुरू करें)';
        icon = Icons.forklift;
        buttonColor = AppColors.primary;
        onTap = () async {
          await widget.controller.updateTripOperationalStep(
            tripReference: trip.reference,
            step: 'loading',
          );
        };
        break;

      case 'loading':
        label = '4. FINISH LOADING (लोडिंग पूरी करें / લોડિંગ પૂર્ણ કરો)';
        icon = Icons.check_circle_outline_rounded;
        buttonColor = AppColors.primary;
        onTap = () {
          showDialog<void>(
            context: context,
            builder: (_) =>
                CargoLoadingDialog(trip: trip, controller: widget.controller),
          );
        };
        break;

      case 'loaded':
        label = '5. NAVIGATE TO DROP LOCATION (डिलीवरी के लिए निकलें)';
        icon = Icons.navigation_rounded;
        buttonColor = const Color(0xFF0F766E);
        onTap = () async {
          await widget.controller.updateTripOperationalStep(
            tripReference: trip.reference,
            step: 'navigating_delivery',
          );
        };
        break;

      case 'navigating_delivery':
        label = '6. CONFIRM ARRIVAL AT DROP (डिलीवरी स्थान पर पहुंचे)';
        icon = Icons.where_to_vote_rounded;
        buttonColor = const Color(0xFF0284C7);
        onTap = () async {
          await widget.controller.updateTripOperationalStep(
            tripReference: trip.reference,
            step: 'arrived_delivery',
          );
        };
        break;

      case 'arrived_delivery':
        label = '7. START UNLOADING (अनलोडिंग शुरू करें)';
        icon = Icons.inventory_2_outlined;
        buttonColor = const Color(0xFF0F766E);
        onTap = () async {
          await widget.controller.updateTripOperationalStep(
            tripReference: trip.reference,
            step: 'unloading',
          );
        };
        break;

      case 'unloading':
        label = '8. FINISH UNLOADING (अनलोडिंग पूरी करें / અનલોડિંગ પૂર્ણ કરો)';
        icon = Icons.done_all_rounded;
        buttonColor = const Color(0xFF0F766E);
        onTap = () {
          showDialog<void>(
            context: context,
            builder: (_) =>
                CargoUnloadingDialog(trip: trip, controller: widget.controller),
          );
        };
        break;

      case 'unloaded':
        label = '9. CAPTURE POD & COMPLETE TRIP (डिलीवरी प्रूफ व हस्ताक्षर)';
        icon = Icons.assignment_turned_in_rounded;
        buttonColor = AppColors.primary;
        onTap = () {
          showDialog<void>(
            context: context,
            builder: (_) =>
                DeliveryProofDialog(trip: trip, controller: widget.controller),
          );
        };
        break;

      default:
        label = 'TRIP COMPLETED (यात्रा समाप्त / યાત્રા પૂર્ણ)';
        icon = Icons.check_circle_rounded;
        buttonColor = AppColors.primary;
        onTap = null;
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'sans-serif',
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildDriverDocumentsCard(DriverProfile? driver) {
    final dl = driver?.licenseNumber.isNotEmpty == true
        ? driver!.licenseNumber
        : 'Not configured';
    final dlExp = driver?.licenseExpiry.isNotEmpty == true
        ? driver!.licenseExpiry
        : 'Not configured';
    final ins = driver?.driverInsurancePolicy.isNotEmpty == true
        ? driver!.driverInsurancePolicy
        : 'Not configured';
    final insExp = driver?.driverInsuranceExpiry.isNotEmpty == true
        ? driver!.driverInsuranceExpiry
        : 'Not configured';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.badge_outlined,
                size: 18,
                padding: 6,
                radius: 8,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizationService.instance.tr('driver_docs_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppLocalizationService.instance
                          .tr('driver_docs_subtitle'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizationService.instance
                            .tr('driving_license_label'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dl,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Exp: $dlExp',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizationService.instance
                            .tr('driver_insurance_label'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ins,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Exp: $insExp',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                          fontFamily: 'sans-serif',
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

  Widget _buildOperationsActionRow(String vehicleNumber) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showTyreChangeDialog(context, vehicleNumber),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.tire_repair_rounded,
                    size: 16,
                    padding: 6,
                    radius: 8,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizationService.instance.tr('tyre_change'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppLocalizationService.instance
                              .tr('report_km_position'),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => _showDailyFluidsCheckDialog(context, vehicleNumber),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.oil_barrel_rounded,
                    size: 16,
                    padding: 6,
                    radius: 8,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizationService.instance.tr('daily_fluids'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppLocalizationService.instance
                              .tr('fluids_check_desc'),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTripExpenseSheet(BuildContext context, TripRecord trip) {
    final dieselCtrl = TextEditingController();
    final tollCtrl = TextEditingController();
    final parkingCtrl = TextEditingController();
    final allowanceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String slipBase64 = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const AppIconBadge(
                        icon: Icons.payments_rounded,
                        size: 20,
                        padding: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trip Expense Logger (Kharcha Jodo)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.navy,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            Text(
                              'Trip #${trip.effectiveTripNumber}  ·  Diesel, Toll, Bhatta',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dieselCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Diesel (Rs)',
                            prefixIcon: const Icon(
                                Icons.local_gas_station_rounded,
                                size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: tollCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Toll Tax (Rs)',
                            prefixIcon:
                                const Icon(Icons.toll_rounded, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: parkingCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Parking (Rs)',
                            prefixIcon: const Icon(Icons.local_parking_rounded,
                                size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: allowanceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Driver Bhatta (Rs)',
                            prefixIcon:
                                const Icon(Icons.person_pin_rounded, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes / Petrol Pump Name',
                      hintText: 'e.g. Surat Highway HP Pump',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      SafetyNotificationService.pickDriverPhoto(
                        useCamera: true,
                        onPhotoSelected: (base64) {
                          setSheetState(() => slipBase64 = base64);
                        },
                      );
                    },
                    icon: Icon(
                      slipBase64.isNotEmpty
                          ? Icons.check_circle_rounded
                          : Icons.camera_alt_outlined,
                      size: 16,
                      color: slipBase64.isNotEmpty
                          ? AppColors.primary
                          : AppColors.slate,
                    ),
                    label: Text(
                      slipBase64.isNotEmpty
                          ? 'Slip Photo Attached (Tap to change)'
                          : 'Parchi / Slip Ki Photo Lo',
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontWeight: FontWeight.w700,
                        color: slipBase64.isNotEmpty
                            ? AppColors.primaryDark
                            : AppColors.navy,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      final diesel =
                          double.tryParse(dieselCtrl.text.trim()) ?? 0.0;
                      final toll = double.tryParse(tollCtrl.text.trim()) ?? 0.0;
                      final parking =
                          double.tryParse(parkingCtrl.text.trim()) ?? 0.0;
                      final allowance =
                          double.tryParse(allowanceCtrl.text.trim()) ?? 0.0;
                      final notes = notesCtrl.text.trim();

                      final tripIndex = widget.controller.trips.indexOf(trip);
                      if (tripIndex != -1) {
                        await widget.controller.updateTripExpenses(
                          index: tripIndex,
                          diesel: diesel > 0 ? diesel : null,
                          toll: toll > 0 ? toll : null,
                          parking: parking > 0 ? parking : null,
                          driverAllowance: allowance > 0 ? allowance : null,
                          notes: notes.isNotEmpty ? notes : null,
                          slipPhoto: slipBase64.isNotEmpty ? slipBase64 : null,
                        );
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Kharcha safaltapoorvak jod diya gaya!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'KHARCHA JAMA KAREIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTyreChangeDialog(BuildContext context, String vehicleNumber) {
    final vehicleIndex = widget.controller.truckModels.indexWhere((truck) =>
        truck.code.trim().toUpperCase() == vehicleNumber.trim().toUpperCase());
    final savedOdometer = vehicleIndex >= 0
        ? widget.controller.truckModels[vehicleIndex].currentOdometerKm
        : 0;
    final kmCtrl = TextEditingController(
        text: savedOdometer > 0 ? savedOdometer.toString() : '');
    final tyreNumCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    String selectedPos = 'Front Left';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Tyre Change Report',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.navy,
              fontFamily: 'sans-serif',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kitne KM par kaunsa tyre badla gaya:',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                      fontFamily: 'sans-serif'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Meter Reading (KM)',
                    prefixIcon: const Icon(Icons.speed_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedPos,
                  decoration: InputDecoration(
                    labelText: 'Tyre Position',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Front Left',
                        child: Text('Front Left (Aage Bayan)')),
                    DropdownMenuItem(
                        value: 'Front Right',
                        child: Text('Front Right (Aage Dayan)')),
                    DropdownMenuItem(
                        value: 'Rear Left Outer',
                        child: Text('Rear Left Outer (Peeche Bayan)')),
                    DropdownMenuItem(
                        value: 'Rear Right Outer',
                        child: Text('Rear Right Outer (Peeche Dayan)')),
                    DropdownMenuItem(
                        value: 'Stepney', child: Text('Stepney (Extra Tyre)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedPos = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tyreNumCtrl,
                  decoration: InputDecoration(
                    labelText: 'New Tyre No. / Brand',
                    hintText: 'e.g. MRF-Steel-8821',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Replacement Cost (₹)',
                    hintText: 'Actual tyre cost',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(fontFamily: 'sans-serif')),
            ),
            FilledButton(
              onPressed: () async {
                final km = int.tryParse(kmCtrl.text.trim()) ?? 0;
                final tyreNum = tyreNumCtrl.text.trim();
                final replacementCost =
                    double.tryParse(costCtrl.text.trim()) ?? 0;
                if (km <= 0 || tyreNum.isEmpty || replacementCost < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Valid odometer, tyre number aur actual cost enter karein.'),
                    ),
                  );
                  return;
                }
                await widget.controller.addTyreRecord(
                  vehicleCode: vehicleNumber,
                  tyre: TyreRecord(
                    tyreNumber: tyreNum,
                    position: selectedPos,
                    fittingDate: DateTime.now().toString().substring(0, 10),
                    fittingKm: km,
                    currentKm: km,
                    replacementCost: replacementCost,
                    condition: 'Good',
                    notes: 'Fitted by driver on duty',
                  ),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Tyre change record safaltapoorvak save ho gaya!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Save Report',
                  style: TextStyle(fontFamily: 'sans-serif')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDailyFluidsCheckDialog(BuildContext context, String vehicleNumber) {
    bool oil = true;
    bool coolant = true;
    bool battery = true;
    bool brakes = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget checkRow({
            required String title,
            required String subtitle,
            required bool value,
            required ValueChanged<bool> onChanged,
          }) {
            return Semantics(
              button: true,
              checked: value,
              child: InkWell(
                onTap: () => onChanged(!value),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                  decoration: BoxDecoration(
                    color: value
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: value
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                )),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 10.5, color: AppColors.slate)),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: value,
                        activeColor: AppColors.primary,
                        onChanged: (next) => onChanged(next ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final allOkay = oil && coolant && battery && brakes;
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    color: const Color(0xFFF0FDF4),
                    child: Row(
                      children: [
                        const Icon(Icons.fact_check_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily Fluids & Safety Check',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppColors.navy)),
                              SizedBox(height: 2),
                              Text('Check every item before submitting',
                                  style: TextStyle(
                                      fontSize: 10.5, color: AppColors.slate)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          checkRow(
                              title: 'Engine Oil Level OK',
                              subtitle: 'Dipstick check verified',
                              value: oil,
                              onChanged: (v) => setDialogState(() => oil = v)),
                          const SizedBox(height: 8),
                          checkRow(
                              title: 'Coolant Water Level OK',
                              subtitle: 'Radiator reservoir filled',
                              value: coolant,
                              onChanged: (v) =>
                                  setDialogState(() => coolant = v)),
                          const SizedBox(height: 8),
                          checkRow(
                              title: 'Battery Terminal OK',
                              subtitle: 'No loose wires, battery charged',
                              value: battery,
                              onChanged: (v) =>
                                  setDialogState(() => battery = v)),
                          const SizedBox(height: 8),
                          checkRow(
                              title: 'Brakes & Air Pressure OK',
                              subtitle: 'Pedal and pressure are normal',
                              value: brakes,
                              onChanged: (v) =>
                                  setDialogState(() => brakes = v)),
                          if (!allOkay) ...[
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFDC2626), size: 17),
                                SizedBox(width: 6),
                                Expanded(
                                    child: Text(
                                        'Unchecked item ko theek kiye bina report submit nahi hogi.',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFFB91C1C),
                                            fontWeight: FontWeight.w700))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: !allOkay
                                ? null
                                : () async {
                                    await widget.controller.logActivity(
                                      title: 'Daily Fluids Check Submitted',
                                      details:
                                          'Vehicle $vehicleNumber: Engine Oil: $oil, Coolant: $coolant, Battery: $battery, Brakes: $brakes.',
                                      category: ActivityCategory.vehicle,
                                      action: 'verified',
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Daily fluids inspection verified & saved!'),
                                          backgroundColor: AppColors.primary,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline_rounded,
                                size: 18),
                            label: const Text('Sab Theek Hai',
                                style: TextStyle(fontFamily: 'sans-serif')),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSundayCleaningCard(bool isSunday, String vehicle) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Same Unified Green Icon Badge
              const AppIconBadge(
                icon: Icons.local_car_wash_rounded,
                size: 22,
                padding: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isSunday
                                ? 'Sunday Vehicle Cleaning Due Today!'
                                : 'Weekly Sunday Cleaning Schedule',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSunday ? 'DUE TODAY' : 'WEEKLY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSunday
                          ? 'Aaj Sunday hai! Gaadi ($vehicle) dho kar saaf photo upload karein.'
                          : 'Agla Sunday cleaning due date: ${_getNextSundayDate()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openPhotoCapture(context,
                  category: 'Sunday Vehicle Cleaning'),
              icon: const Icon(Icons.add_a_photo_rounded, size: 16),
              label: Text(
                isSunday
                    ? 'Gadi Saaf Photo Upload Karein'
                    : 'Cleaning Photo Upload Karein',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'sans-serif',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoQuickActionBanner(String vehicle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Same Unified Green Icon Badge
          const AppIconBadge(
            icon: Icons.assignment_late_rounded,
            size: 20,
            padding: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizationService.instance.tr('memo_banner_title'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizationService.instance.tr('memo_banner_sub'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.slate,
                    fontFamily: 'sans-serif',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () =>
                _openPhotoCapture(context, category: 'Police & RTO Memo'),
            icon: const Icon(Icons.add_a_photo_rounded, size: 14),
            label: Text(
              AppLocalizationService.instance.tr('take_photo'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'sans-serif',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceAndInsuranceSection(String vehicle) {
    TruckModel? assignedTruck;
    for (final truck in widget.controller.truckModels) {
      if (truck.code.trim().toUpperCase() == vehicle.trim().toUpperCase()) {
        assignedTruck = truck;
        break;
      }
    }
    final maintenanceStatus = assignedTruck == null
        ? 'Vehicle not configured'
        : assignedTruck.nextServiceKm <= 0
            ? 'Service schedule not configured'
            : '${assignedTruck.kmUntilNextService} km until next service';
    final insuranceStatus = assignedTruck == null
        ? 'Vehicle not configured'
        : 'Insurance: ${assignedTruck.insuranceExpiry.isEmpty ? "Not configured" : assignedTruck.insuranceExpiry}\nPUC: ${assignedTruck.pucExpiry.isEmpty ? "Not configured" : assignedTruck.pucExpiry}';
    return Row(
      children: [
        // Maintenance Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Same Unified Green Icon Badge
                    const AppIconBadge(
                      icon: Icons.build_rounded,
                      size: 16,
                      padding: 6,
                      radius: 8,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizationService.instance
                            .tr('maintenance_and_insurance'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  maintenanceStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate,
                    height: 1.3,
                    fontFamily: 'sans-serif',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openPhotoCapture(context,
                      category: 'Vehicle Maintenance'),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          size: 14, color: AppColors.iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          AppLocalizationService.instance
                              .tr('upload_meter_photo'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.iconColor,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Insurance Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Same Unified Green Icon Badge
                    const AppIconBadge(
                      icon: Icons.verified_user_rounded,
                      size: 16,
                      padding: 6,
                      radius: 8,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizationService.instance
                            .tr('insurance_puc_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  insuranceStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate,
                    height: 1.3,
                    fontFamily: 'sans-serif',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openPhotoCapture(context,
                      category: 'Insurance & Documents'),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner_outlined,
                          size: 14, color: AppColors.iconColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          AppLocalizationService.instance.tr('upload_document'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.iconColor,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoActionGrid(
      BuildContext context, List<SeatbeltRecord> records) {
    final actions = [
      (
        title: AppLocalizationService.instance.tr('seatbelt_photo'),
        subtitle: 'Pre-trip selfie check',
        hindi: AppLocalizationService.instance.tr('seatbelt_photo'),
        icon: Icons.airline_seat_recline_extra_rounded,
        keys: const ['seatbelt', 'pre-trip cabin'],
        action: () =>
            _openPhotoCapture(context, category: 'Driver Seatbelt Photo'),
      ),
      (
        title: AppLocalizationService.instance.tr('sunday_cleaning'),
        subtitle: 'Wash & cleanliness photo',
        hindi: AppLocalizationService.instance.tr('sunday_cleaning'),
        icon: Icons.local_car_wash_rounded,
        keys: const ['sunday vehicle cleaning'],
        action: () =>
            _openPhotoCapture(context, category: 'Sunday Vehicle Cleaning'),
      ),
      (
        title: AppLocalizationService.instance.tr('police_memo'),
        subtitle: 'Traffic fine & RTO receipt',
        hindi: AppLocalizationService.instance.tr('police_memo'),
        icon: Icons.assignment_late_rounded,
        keys: const ['police & rto memo', 'challan'],
        action: () => _openPhotoCapture(context, category: 'Police & RTO Memo'),
      ),
      (
        title: AppLocalizationService.instance.tr('meter_photo'),
        subtitle: 'Odometer & tyre check',
        hindi: AppLocalizationService.instance.tr('meter_photo'),
        icon: Icons.build_circle_rounded,
        keys: const ['vehicle maintenance', 'meter'],
        action: () =>
            _openPhotoCapture(context, category: 'Vehicle Maintenance'),
      ),
      (
        title: AppLocalizationService.instance.tr('insurance_puc'),
        subtitle: 'Policy & PUC certificate',
        hindi: AppLocalizationService.instance.tr('insurance_puc'),
        icon: Icons.verified_user_rounded,
        keys: const ['insurance & documents', 'puc'],
        action: () =>
            _openPhotoCapture(context, category: 'Insurance & Documents'),
      ),
      (
        title: AppLocalizationService.instance.tr('fuel_receipt'),
        subtitle: 'Transport & fuel bills',
        hindi: AppLocalizationService.instance.tr('fuel_receipt'),
        icon: Icons.receipt_long_rounded,
        keys: const ['bilty & fuel receipts', 'diesel', 'toll'],
        action: () =>
            _openPhotoCapture(context, category: 'Bilty & Fuel Receipts'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final item = actions[index];
        SeatbeltRecord? latestPhoto;
        for (final record in records) {
          final searchable = record.notes.toLowerCase();
          if (item.keys.any(searchable.contains)) {
            latestPhoto = record;
            break;
          }
        }
        final categoryRecords = records.where((record) {
          final searchable = record.notes.toLowerCase();
          return item.keys.any(searchable.contains);
        }).toList();
        return InkWell(
          onTap: () => _showCategoryPhotos(
            context,
            title: item.title,
            records: categoryRecords,
            uploadAction: item.action,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04),
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
                    // Same Unified Green Icon Badge
                    if (latestPhoto != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: _buildThumbnail(latestPhoto.photoBase64),
                        ),
                      )
                    else
                      AppIconBadge(
                        icon: item.icon,
                        size: 20,
                        padding: 8,
                        radius: 10,
                      ),
                    if (latestPhoto != null)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 13, color: AppColors.iconColor),
                          SizedBox(width: 3),
                          Text('SAVED',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.iconColor)),
                        ],
                      )
                    else
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: AppColors.iconColor),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.hindi,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationLauncher([TripRecord? activeTrip]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iconBadgeBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Same Unified Green Icon Badge
          const AppIconBadge(
            icon: Icons.navigation_rounded,
            size: 24,
            padding: 10,
            radius: 12,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizationService.instance.tr('route_map_live_gps'),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    fontFamily: 'sans-serif',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeTrip != null
                      ? '${activeTrip.origin} -> ${activeTrip.destination}'
                      : AppLocalizationService.instance.tr('route_map_sub'),
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontFamily: 'sans-serif',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              if (activeTrip != null) {
                widget.controller.setRoute(
                  newOrigin: activeTrip.origin.trim(),
                  newDestination: activeTrip.destination.trim(),
                  newStops: activeTrip.stops,
                );
              }
              if (widget.adminPreview || Navigator.of(context).canPop()) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Route Map & Live Navigation'),
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                      ),
                      body: RoutePlannerPage(controller: widget.controller),
                    ),
                  ),
                );
              } else {
                widget.onNavigate(WorkspaceSection.planner);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              AppLocalizationService.instance.tr('open_map'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'sans-serif',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPhotosGallery(List<SeatbeltRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Center(
          child: Column(
            children: [
              const AppIconBadge(
                icon: Icons.photo_library_outlined,
                size: 28,
                padding: 10,
                radius: 14,
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizationService.instance.tr('no_photos_uploaded'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontSize: 13,
                  fontFamily: 'sans-serif',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizationService.instance.tr('quick_upload_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 11,
                  fontFamily: 'sans-serif',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizationService.instance.tr('recent_photos'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => SeatbeltRecordsDialog.show(
                context,
                controller: widget.controller,
              ),
              child: Text(
                AppLocalizationService.instance.tr('view_all'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.iconColor,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length.clamp(0, 5),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rec = records[index];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: AppColors.primarySoft,
                      child: _buildThumbnail(rec.photoBase64),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.notes.isNotEmpty
                              ? rec.notes
                              : 'Driver Verification Photo',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${rec.vehicleNumber}  ·  ${_formatDate(rec.timestamp)}',
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 11,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 12, color: AppColors.iconColor),
                        SizedBox(width: 4),
                        Text(
                          'SAVED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iconColor,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThumbnail(String photo, {BoxFit fit = BoxFit.cover}) {
    try {
      String clean = photo;
      if (clean.contains(',')) clean = clean.split(',').last;
      final bytes = base64Decode(clean.trim());
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_outlined, size: 24, color: AppColors.slate),
      );
    } catch (_) {
      return const Icon(Icons.image_outlined, size: 24, color: AppColors.slate);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hr:$min $ampm';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Sign Out', style: TextStyle(fontFamily: 'sans-serif')),
        content: const Text(
          'Kya aap Transport One se logout karna chahte hain?',
          style: TextStyle(fontFamily: 'sans-serif'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'sans-serif')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign Out',
                style: TextStyle(fontFamily: 'sans-serif')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.controller.logout();
    }
  }
}

class _PhotoUploadBottomSheet extends StatefulWidget {
  const _PhotoUploadBottomSheet({
    required this.controller,
    required this.category,
    this.onPhotoUploaded,
  });

  final PlannerController controller;
  final String category;
  final ValueChanged<String>? onPhotoUploaded;

  @override
  State<_PhotoUploadBottomSheet> createState() =>
      _PhotoUploadBottomSheetState();
}

class _PhotoUploadBottomSheetState extends State<_PhotoUploadBottomSheet> {
  Uint8List? _capturedImageBytes;
  String _capturedBase64 = '';
  bool _isUploading = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onPhotoCaptured(String base64Data) {
    try {
      String clean = base64Data;
      if (clean.contains(',')) clean = clean.split(',').last;
      final bytes = base64Decode(clean.trim());
      if (bytes.isEmpty || bytes.length > 2621440) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Photo 2.5 MB se chhoti honi chahiye.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _capturedImageBytes = bytes;
          _capturedBase64 = clean;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected photo read nahi ho paayi.')),
        );
      }
    }
  }

  void _triggerDeviceCamera(bool useCamera) {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: useCamera,
      onPhotoSelected: _onPhotoCaptured,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Future<void> _submitPhoto() async {
    if (_capturedBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pehle photo lein ya gallery se select karein.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    final userNote = _notesController.text.trim();
    final combinedNotes = userNote.isNotEmpty ? userNote : widget.category;

    await widget.controller.submitDriverPhotoRecord(
      category: widget.category,
      photoBase64: _capturedBase64,
      notes: combinedNotes,
    );

    if (widget.onPhotoUploaded != null) {
      widget.onPhotoUploaded!(_capturedBase64);
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.category} photo safaltapoorvak jama ho gayi!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.controller.currentDriver;
    final vehicle = driver?.assignedVehicle.trim().isNotEmpty == true
        ? driver!.assignedVehicle.trim()
        : 'Not assigned';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Same Unified Green Icon Badge
              const AppIconBadge(
                icon: Icons.add_a_photo_rounded,
                size: 22,
                padding: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    Text(
                      'Vehicle: $vehicle · Driver: ${driver?.name ?? "Fleet Driver"}',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11.5,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Photo Preview / Viewfinder (Clean Light Green Tint - No Heavy Black)
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.iconBadgeBorder,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  if (_capturedImageBytes != null)
                    Positioned.fill(
                      child:
                          Image.memory(_capturedImageBytes!, fit: BoxFit.cover),
                    )
                  else
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconBadge(
                            icon: Icons.camera_alt_outlined,
                            size: 40,
                            padding: 14,
                            radius: 20,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Camera se live photo lein ya file chunein',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$vehicle | ${driver?.name ?? "Driver"} | ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'sans-serif',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Two Primary Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _triggerDeviceCamera(true),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text(
                    'CAMERA',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _triggerDeviceCamera(false),
                  icon: const Icon(Icons.photo_library_outlined,
                      size: 18, color: AppColors.iconColor),
                  label: const Text(
                    'GALLERY / FILE',
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Submit Button
          if (_capturedImageBytes != null) ...[
            FilledButton.icon(
              onPressed: _isUploading ? null : _submitPhoto,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                _isUploading ? 'SAVING PHOTO...' : 'PHOTO JAMA KAREIN (SUBMIT)',
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
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
