import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/real_battery_service.dart';
import 'admin_driver_view_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.controller,
    required this.onNavigateToMap,
    required this.onNavigateToPlanner,
    this.onOpenDrawer,
    super.key,
  });

  final PlannerController controller;
  final VoidCallback onNavigateToMap;
  final VoidCallback onNavigateToPlanner;
  final VoidCallback? onOpenDrawer;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int? _batteryLevel;
  bool _isCharging = false;
  StreamSubscription<RealDeviceBatteryInfo>? _batterySub;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _fetchBattery();
    _batterySub = RealBatteryService.instance.onBatteryChanged.listen((info) {
      if (!mounted) return;
      setState(() {
        _batteryLevel = info.level;
        _isCharging = info.isCharging;
      });
    });
    // Actively sync latest data from cloud on mount and every 10 seconds
    unawaited(widget.controller.syncAllDataFromCloud());
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        widget.controller.syncAllDataFromCloud();
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    _batterySub?.cancel();
    super.dispose();
  }

  Future<void> _fetchBattery() async {
    try {
      final info = await RealBatteryService.instance.fetchBatteryInfo();
      if (mounted) {
        setState(() {
          _batteryLevel = info.level;
          _isCharging = info.isCharging;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final totalVehicles = widget.controller.truckModels.isNotEmpty ? widget.controller.truckModels.length : 5;
    final totalDrivers = widget.controller.drivers.isNotEmpty ? widget.controller.drivers.length : 6;
    final totalTrips = widget.controller.trips.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header: Sidebar Hamburger + RBC Logo + Battery Status + Logout
          Row(
            children: [
              if (widget.onOpenDrawer != null)
                IconButton(
                  onPressed: widget.onOpenDrawer,
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 28),
                  tooltip: 'साइडबार मेनू (Sidebar Menu)',
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'RBC TRANSPORT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saurabh Yadav • 9157661886',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Real Phone Battery & Charging Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: _isCharging ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isCharging ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCharging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
                      size: 16,
                      color: _isCharging ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _batteryLevel != null ? '$_batteryLevel%' : '...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isCharging ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () async {
                  await widget.controller.syncAllDataFromCloud();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                tooltip: 'ताज़ा करें (Sync Data)',
              ),
              IconButton(
                onPressed: () {
                  widget.controller.logout();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                tooltip: 'लॉगआउट',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'कुल गाड़ियाँ',
                  value: '$totalVehicles',
                  subtitle: 'सभी सक्रिय',
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: widget.onNavigateToMap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'कुल ड्राइवर',
                  value: '$totalDrivers',
                  subtitle: 'रजिस्टर्ड',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF059669),
                  onTap: widget.onNavigateToPlanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'सक्रिय ट्रिप्स',
                  value: '$totalTrips',
                  subtitle: 'ट्रिप रिकॉर्ड्स',
                  icon: Icons.route_rounded,
                  color: const Color(0xFFD97706),
                  onTap: widget.onNavigateToPlanner,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'लाइव लोकेशन',
                  value: 'Live GPS',
                  subtitle: 'गाड़ियाँ कहाँ खड़ी हैं',
                  icon: Icons.satellite_alt_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: widget.onNavigateToMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Shortcuts
          const Text(
            'क्विक एक्शन (Quick Navigation)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Button 1: Live Location Screen
          _buildActionTile(
            title: 'गाड़ियों की लाइव लोकेशन देखें',
            subtitle: 'मैप पर देखें कौन सी गाड़ी कहाँ खड़ी है या चल रही है',
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF2563EB),
            onTap: widget.onNavigateToMap,
          ),
          const SizedBox(height: 10),

          // Button 2: Trip Planner Screen
          _buildActionTile(
            title: 'नई ट्रिप प्लान करें व ड्राइवर असाइन करें',
            subtitle: 'गाड़ी और ड्राइवर चुनकर रूट और माल सेट करें',
            icon: Icons.add_road_rounded,
            iconColor: const Color(0xFF059669),
            onTap: widget.onNavigateToPlanner,
          ),
          const SizedBox(height: 24),

          // Vehicle Status List
          const Text(
            'फ्लीट गाड़ियाँ (Fleet Vehicles Status)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          ...widget.controller.truckModels.map((truck) {
            final isOnline = widget.controller.isVehicleOnline(truck.code);
            final isOnDuty = widget.controller.isVehicleDriverOnDuty(truck.code);
            final cleanTruckCode =
                truck.code.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            final allFleetDrivers = <DriverProfile>[];
            final seenKeys = <String>{};
            for (final d in [
              ...widget.controller.drivers,
              ...PlannerController.defaultFleetDrivers,
            ]) {
              final key = d.phone.replaceAll(RegExp(r'\D'), '').isNotEmpty
                  ? d.phone.replaceAll(RegExp(r'\D'), '')
                  : d.email.trim().toLowerCase();
              if (key.isNotEmpty && seenKeys.add(key)) {
                allFleetDrivers.add(d);
              }
            }
            final vehicleDrivers = allFleetDrivers
                .where((d) =>
                    d.assignedVehicle
                        .replaceAll(RegExp(r'[\s\-]'), '')
                        .toUpperCase() ==
                    cleanTruckCode)
                .toList();
            final telemetryDriverName = widget.controller
                    .telemetryDriverNameForVehicle(truck.code)
                    ?.trim()
                    .toLowerCase() ??
                '';
            DriverProfile? activeDriver;
            for (final d in vehicleDrivers) {
              if (widget.controller.getActiveDuty(d.email) != null ||
                  widget.controller.getActiveDuty(d.name) != null ||
                  (d.phone.isNotEmpty &&
                      widget.controller.getActiveDuty(d.phone) != null)) {
                activeDriver = d;
                break;
              }
            }
            activeDriver ??= vehicleDrivers.firstWhere(
              (d) =>
                  telemetryDriverName.isNotEmpty &&
                  d.name.trim().toLowerCase() == telemetryDriverName,
              orElse: () => vehicleDrivers.isNotEmpty
                  ? vehicleDrivers.first
                  : DriverProfile(
                      truck.assignedDriver.isNotEmpty
                          ? truck.assignedDriver
                          : 'Driver',
                      '',
                      assignedVehicle: truck.code,
                    ),
            );
            final effectiveDriverName = vehicleDrivers.length > 1 &&
                    telemetryDriverName.isEmpty &&
                    !isOnDuty
                ? vehicleDrivers.map((d) => d.name).join(' / ')
                : (activeDriver.name.isNotEmpty
                    ? activeDriver.name
                    : (truck.assignedDriver.isNotEmpty
                        ? truck.assignedDriver
                        : 'असाइन नहीं'));
            TripRecord? activeTrip;
            for (final t in widget.controller.trips) {
              if ((t.assignedVehicle.trim().toUpperCase() ==
                          truck.code.trim().toUpperCase() ||
                      t.assignedDriver.trim().toLowerCase() ==
                          truck.assignedDriver.trim().toLowerCase()) &&
                  (t.status.toLowerCase() == 'in_transit' ||
                      t.status.toLowerCase() == 'planned')) {
                activeTrip = t;
                break;
              }
            }
            final hasActiveTrip = activeTrip != null;
            final matchedDriverForTap = activeDriver;

            return InkWell(
              onTap: () {
                final matchedDriver = matchedDriverForTap;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminDriverViewScreen(
                      controller: widget.controller,
                      initialDriver: matchedDriver,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOnline ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                    width: isOnline ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isOnline ? const Color(0xFF16A34A).withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
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
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    truck.code,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'ऑनलाइन' : 'ऑफ़लाइन',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'चालक: $effectiveDriverName',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isOnDuty ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isOnDuty ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                isOnDuty ? 'ऑन ड्यूटी (ON)' : 'ऑफ ड्यूटी (OFF)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isOnDuty ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (truck.phoneBatteryLevel != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: truck.isPhoneCharging ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: truck.isPhoneCharging ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      truck.isPhoneCharging
                                          ? Icons.battery_charging_full_rounded
                                          : Icons.battery_full_rounded,
                                      size: 13,
                                      color: truck.isPhoneCharging ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${truck.phoneBatteryLevel}%${truck.isPhoneCharging ? " ⚡" : ""}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: truck.isPhoneCharging ? const Color(0xFF15803D) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: truck.hasCoordinates ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              truck.hasCoordinates
                                  ? 'लाइव GPS: ${truck.currentLat!.toStringAsFixed(4)}, ${truck.currentLng!.toStringAsFixed(4)}${truck.currentSpeed > 1 ? " • ${truck.currentSpeed.toStringAsFixed(0)} km/h" : " • खड़ी है"}'
                                  : 'लास्ट लोकेशन: GPS सिग्नल लोड हो रहा है',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasActiveTrip) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'ट्रिप: ${activeTrip.origin.split(',').first} ➔ ${activeTrip.destination.split(',').first}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
