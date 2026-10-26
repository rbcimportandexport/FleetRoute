import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/protrack_gps_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';
import 'fleet_workspace.dart';
import 'operations_module_page.dart';
import '../widgets/trip_map_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.controller,
    required this.onNavigate,
    super.key,
  });

  final PlannerController controller;
  final ValueChanged<WorkspaceSection> onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Timer? _timeUpdateTimer;
  String _selectedFilter = 'all';
  String _dateRangeFilter = 'all'; // all, today, week, month
  final TextEditingController _searchController = TextEditingController();
  int _recentTab = 0; // 0: Trips, 1: Drivers, 2: Vehicles
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Update time and relative time strings periodically
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeUpdateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _shortCity(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'Not set';
    final parsed = RouteTrafficService.parseLocation(clean);
    if (parsed != null) {
      final city = RouteTrafficService.findNearestCityName(parsed);
      if (city.isNotEmpty && !city.contains(',')) {
        return city;
      }
      return '${parsed.latitude.toStringAsFixed(3)}, ${parsed.longitude.toStringAsFixed(3)}';
    }
    return clean;
  }

  String _friendlyLocation(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'Not set';
    final parsed = RouteTrafficService.parseLocation(clean);
    if (parsed != null) {
      final city = RouteTrafficService.findNearestCityName(parsed);
      if (city.isNotEmpty && !city.contains(',')) {
        return '$city (${parsed.latitude.toStringAsFixed(2)}, ${parsed.longitude.toStringAsFixed(2)})';
      }
    }
    return clean;
  }

  List<ActivityEvent> get _filteredActivities {
    final query = _searchController.text.trim().toLowerCase();
    return widget.controller.activities.where((event) {
      final matchesFilter = switch (_selectedFilter) {
        'driver' => event.category == ActivityCategory.driver,
        'vehicle' => event.category == ActivityCategory.vehicle,
        'trip' => event.category == ActivityCategory.trip,
        'alert' => event.category == ActivityCategory.alert,
        'planner' => event.category == ActivityCategory.planner,
        _ => true,
      };

      final matchesQuery = query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          event.details.toLowerCase().contains(query) ||
          event.action.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _openAddDialog(OperationsModule module) async {
    if (module == OperationsModule.trips) {
      final trip = await showDialog<TripRecord>(
        context: context,
        builder: (_) => const TripMapDialog(),
      );
      if (trip != null) {
        await widget.controller.addTrip(trip);
        widget.controller.setRoute(
          newOrigin: trip.origin,
          newDestination: trip.destination,
          newStops: trip.stops,
        );
      }
      return;
    }

    final record = await showDialog<Object>(
      context: context,
      builder: (_) => AddRecordDialog(module: module),
    );
    if (record == null) return;
    try {
      if (record is DriverProfile) await widget.controller.addDriver(record);
      if (record is TruckModel) await widget.controller.addTruckModel(record);
      if (record is OperationsAlert) await widget.controller.addAlert(record);
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e.message?.toString() ?? 'Invalid entry. Please try again.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _loadTripIntoRoute(TripRecord trip) {
    widget.controller.setRoute(
      newOrigin: trip.origin,
      newDestination: trip.destination,
      newStops: trip.stops,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Route loaded: ${_shortCity(trip.origin)} -> ${_shortCity(trip.destination)}',
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Open Planner',
          textColor: const Color(0xFF60A5FA),
          onPressed: () => widget.onNavigate(WorkspaceSection.planner),
        ),
      ),
    );
  }

  Future<void> _viewTripOnMap(TripRecord trip) async {
    await showDialog<void>(
      context: context,
      builder: (_) => TripMapDialog(initialTrip: trip),
    );
  }

  Future<void> _clearActivityLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity Feed?'),
        content: const Text(
          'This will clear the recorded live timeline log on this device. Existing drivers, vehicles, trips, and alerts will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Log'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      await widget.controller.clearActivities();
    }
  }

  Future<void> _openExternalRoute() async {
    if (!widget.controller.canShowRoute) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': widget.controller.origin,
      'destination': widget.controller.destination,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return ColoredBox(
          color: const Color(0xFFF4F7F6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 700;
              final padding = mobile ? 14.0 : 22.0;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    padding, padding, padding, padding + 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSimpleWelcome(ctrl),
                        const SizedBox(height: 16),
                        _buildPrimaryDriverAction(),
                        const SizedBox(height: 18),
                        _buildSimpleStats(ctrl),
                        const SizedBox(height: 20),
                        _simpleTitle(
                            'Quick actions', 'Roz ke kaam ek tap mein'),
                        const SizedBox(height: 10),
                        _buildSimpleActions(),
                        const SizedBox(height: 22),
                        _buildSimpleDrivers(ctrl),
                        const SizedBox(height: 18),
                        _buildSimpleOperations(ctrl),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSimpleWelcome(PlannerController ctrl) {
    final activeTrips =
        ctrl.trips.where((trip) => trip.status == 'in_transit').length;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0A8F55),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.local_shipping_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fleet Dashboard',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy)),
              Text(
                activeTrips == 0
                    ? 'Aaj koi trip transit mein nahi hai'
                    : '$activeTrips trip abhi transit mein',
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
        _buildLivePulseIndicator(compact: true),
      ],
    );
  }

  Widget _buildPrimaryDriverAction() {
    return Material(
      color: const Color(0xFF073D2C),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openAddDialog(OperationsModule.drivers),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF13B76A),
                child: Icon(Icons.person_add_alt_1_rounded,
                    color: Colors.white, size: 25),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Driver',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Account, phone, vehicle aur photo add karein',
                        style: TextStyle(
                            color: Color(0xFFC7E7DA), fontSize: 11.5)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleStats(PlannerController ctrl) {
    final openAlerts = ctrl.alerts.where((a) => !a.isResolved).length;
    final transit = ctrl.trips.where((t) => t.status == 'in_transit').length;
    final stats = [
      (
        'Drivers',
        '${ctrl.drivers.length}',
        Icons.badge_outlined,
        WorkspaceSection.drivers,
        const Color(0xFF2563EB)
      ),
      (
        'Vehicles',
        '${ctrl.truckModels.length}',
        Icons.local_shipping_outlined,
        WorkspaceSection.vehicles,
        const Color(0xFF7C3AED)
      ),
      (
        'Active trips',
        '$transit',
        Icons.alt_route_rounded,
        WorkspaceSection.trips,
        const Color(0xFF0A8F55)
      ),
      (
        'Open alerts',
        '$openAlerts',
        Icons.notifications_none_rounded,
        WorkspaceSection.alerts,
        const Color(0xFFDC2626)
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: stats.map((item) {
          return SizedBox(
            width: width,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => widget.onNavigate(item.$4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE1E8E5)),
                  ),
                  child: Row(children: [
                    Icon(item.$3, color: item.$5, size: 23),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: AppColors.navy)),
                        Text(item.$1,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.slate)),
                      ],
                    )),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _simpleTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate)),
        ],
      );

  Widget _buildSimpleActions() {
    final actions = [
      (
        'Add Vehicle',
        Icons.add_road_rounded,
        () => _openAddDialog(OperationsModule.vehicles)
      ),
      (
        'Create Trip',
        Icons.route_rounded,
        () => _openAddDialog(OperationsModule.trips)
      ),
      (
        'Attendance',
        Icons.how_to_reg_rounded,
        () => widget.onNavigate(WorkspaceSection.attendance)
      ),
      (
        'Reports',
        Icons.file_download_outlined,
        () => widget.onNavigate(WorkspaceSection.reports)
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: actions
            .map((action) => SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                    onPressed: action.$3,
                    icon: Icon(action.$2, size: 19),
                    label: Text(action.$1),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFF075E42),
                      side: const BorderSide(color: Color(0xFFCFE0DA)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ))
            .toList(),
      );
    });
  }

  Widget _buildSimpleDrivers(PlannerController ctrl) {
    final drivers = ctrl.drivers.reversed.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E8E5)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _simpleTitle('Drivers', 'Latest registered drivers')),
          TextButton(
            onPressed: () => widget.onNavigate(WorkspaceSection.drivers),
            child: const Text('View all'),
          ),
        ]),
        const SizedBox(height: 10),
        if (drivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(children: [
              const Icon(Icons.person_add_alt_rounded,
                  size: 34, color: AppColors.slate),
              const SizedBox(height: 8),
              const Text('Abhi koi driver add nahi hai'),
              TextButton(
                onPressed: () => _openAddDialog(OperationsModule.drivers),
                child: const Text('Add first driver'),
              ),
            ]),
          )
        else
          for (var i = 0; i < drivers.length; i++) ...[
            _simpleDriverRow(drivers[i]),
            if (i != drivers.length - 1)
              const Divider(height: 18, color: Color(0xFFE7ECEA)),
          ],
      ]),
    );
  }

  Widget _simpleDriverRow(DriverProfile driver) {
    final initial = driver.name.trim().isEmpty
        ? 'D'
        : driver.name.trim().substring(0, 1).toUpperCase();
    return InkWell(
      onTap: () => widget.onNavigate(WorkspaceSection.drivers),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE4F7EE),
          foregroundColor: const Color(0xFF087549),
          child: Text(initial,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 11),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driver.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.navy)),
            Text(
                driver.assignedVehicle.isEmpty
                    ? (driver.phone.isEmpty ? driver.email : driver.phone)
                    : 'Vehicle: ${driver.assignedVehicle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.slate)),
          ],
        )),
        const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
      ]),
    );
  }

  Widget _buildSimpleOperations(PlannerController ctrl) {
    final planned = ctrl.trips.where((t) => t.status == 'planned').length;
    final completed = ctrl.trips.where((t) => t.status == 'completed').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.fact_check_outlined, color: Color(0xFF087549)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
          '$planned planned trips  |  $completed completed trips',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF164B39)),
        )),
        IconButton(
          tooltip: 'Open trips',
          onPressed: () => widget.onNavigate(WorkspaceSection.trips),
          icon:
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF087549)),
        ),
      ]),
    );
  }

  // ignore: unused_element
  Widget _buildHeader(PlannerController ctrl) {
    final hour = _currentTime.hour.toString().padLeft(2, '0');
    final min = _currentTime.minute.toString().padLeft(2, '0');
    final sec = _currentTime.second.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F2440),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final clockWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: AppColors.slate),
                    const SizedBox(width: 5),
                    Text(
                      '$hour:$min:$sec',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );

              if (isMobile) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x332563EB),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.dashboard_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Fleet Dashboard',
                                      style: TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    _buildLivePulseIndicator(compact: true),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Real-time operations feed',
                                  style: TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          clockWidget,
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x332563EB),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.dashboard_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Live Operations Dashboard',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildLivePulseIndicator(),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Fleet operations status and route management across all active modules',
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    clockWidget,
                  ],
                ),
              );
            },
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Quick Dispatch:',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildHeaderButton(
                  icon: Icons.person_add_rounded,
                  label: 'Add Driver',
                  onTap: () => _openAddDialog(OperationsModule.drivers),
                ),
                _buildHeaderButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add Vehicle',
                  onTap: () => _openAddDialog(OperationsModule.vehicles),
                ),
                _buildHeaderButton(
                  icon: Icons.add_road_rounded,
                  label: 'Create Trip',
                  onTap: () => _openAddDialog(OperationsModule.trips),
                ),
                _buildHeaderButton(
                  icon: Icons.how_to_reg_outlined,
                  label: 'Attendance',
                  onTap: () => widget.onNavigate(WorkspaceSection.attendance),
                ),
                _buildHeaderButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Expenses',
                  onTap: () => widget.onNavigate(WorkspaceSection.expenses),
                ),
                _buildHeaderButton(
                  icon: Icons.payments_outlined,
                  label: 'Billing',
                  onTap: () => widget.onNavigate(WorkspaceSection.billing),
                ),
                _buildHeaderButton(
                  icon: Icons.assessment_outlined,
                  label: 'Reports',
                  onTap: () => widget.onNavigate(WorkspaceSection.reports),
                ),
                _buildHeaderButton(
                  icon: Icons.notification_add_rounded,
                  label: 'Raise Alert',
                  onTap: () => _openAddDialog(OperationsModule.alerts),
                ),
                _buildHeaderButton(
                  icon: Icons.alt_route_rounded,
                  label: 'Open Route Planner',
                  isPrimary: true,
                  onTap: () => widget.onNavigate(WorkspaceSection.planner),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePulseIndicator({bool compact = false}) {
    final ctrl = widget.controller;
    final bool isSyncing = ctrl.isGpsSyncing;
    final bool hasDemo = ctrl.truckModels.any((t) => t.isDemoTelemetry);
    final bool hasLive = ProtrackGpsService.instance.isAuthenticated &&
        ctrl.lastGpsSyncTime != null &&
        ctrl.truckModels.any((t) => t.hasValidGpsFix && !t.isGpsStale) &&
        !hasDemo &&
        ctrl.lastGpsSyncError == null;
    final bool hasError = ctrl.lastGpsSyncError != null;

    final Color bgColor;
    final Color borderColor;
    final Color dotColor;
    final Color textColor;
    final String label;

    if (isSyncing) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF3B82F6);
      dotColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1D4ED8);
      label = compact ? 'SYNC' : 'SYNCING';
    } else if (hasDemo) {
      bgColor = const Color(0xFFFEF3C7);
      borderColor = const Color(0xFFF59E0B);
      dotColor = const Color(0xFFD97706);
      textColor = const Color(0xFFB45309);
      label = compact ? 'DEMO' : 'DEMO STREAM';
    } else if (hasLive) {
      bgColor = const Color(0xFFDCFCE7);
      borderColor = const Color(0xFF10B981);
      dotColor = const Color(0xFF10B981);
      textColor = const Color(0xFF047857);
      label = compact ? 'LIVE' : 'LIVE STREAM';
    } else if (hasError) {
      bgColor = const Color(0xFFFEE2E2);
      borderColor = const Color(0xFFEF4444);
      dotColor = const Color(0xFFDC2626);
      textColor = const Color(0xFFB91C1C);
      label = compact ? 'OFFLINE' : 'GPS OFFLINE';
    } else {
      bgColor = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFCBD5E1);
      dotColor = const Color(0xFF64748B);
      textColor = const Color(0xFF475569);
      label = compact ? 'STANDBY' : 'GPS STANDBY';
    }

    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 3.5,
              backgroundColor: dotColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? AppColors.blue : const Color(0xFFD8E1EE),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isPrimary ? Colors.white : AppColors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppColors.navy,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDateRangeFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x060F2440), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.date_range_outlined, size: 16, color: AppColors.slate),
              SizedBox(width: 6),
              Text(
                'Filter Operations:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
              ),
            ],
          ),
          for (final (id, label) in [
            ('all', 'All Time'),
            ('today', 'Today'),
            ('week', 'This Week'),
            ('month', 'This Month'),
          ])
            InkWell(
              onTap: () => setState(() => _dateRangeFilter = id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _dateRangeFilter == id
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _dateRangeFilter == id
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _dateRangeFilter == id
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: _dateRangeFilter == id
                        ? const Color(0xFF15803D)
                        : AppColors.slate,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildKpiMetrics({
    required PlannerController ctrl,
    required List<OperationsAlert> unresolvedAlerts,
    required int criticalCount,
    required int warningCount,
    required int completedTrips,
    required int inTransitTrips,
    required int plannedTrips,
    required bool isDesktop,
  }) {
    final now = DateTime.now();
    bool isInDateRange(String dateStr) {
      if (_dateRangeFilter == 'all') return true;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return true;
      if (_dateRangeFilter == 'today') {
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      }
      if (_dateRangeFilter == 'week') {
        return now.difference(dt).inDays <= 7;
      }
      if (_dateRangeFilter == 'month') {
        return now.difference(dt).inDays <= 30;
      }
      return true;
    }

    // Dynamic metrics
    final relevantTrips =
        ctrl.trips.where((t) => isInDateRange(t.createdAt)).toList();
    final activeTrips = ctrl.trips
        .where((t) =>
            t.status != 'completed' &&
            t.status != 'cancelled' &&
            isInDateRange(t.createdAt))
        .toList();

    double cargoOnboardTons = 0.0;
    for (final t in activeTrips) {
      if (t.cargoItems.isNotEmpty) {
        for (final c in t.cargoItems) {
          cargoOnboardTons +=
              c.remainingQuantity > 0 ? c.remainingQuantity : c.loadedQuantity;
        }
      } else {
        cargoOnboardTons += 20.0;
      }
    }

    final totalRevenue =
        relevantTrips.fold<double>(0.0, (s, t) => s + t.freightAmount);
    final relevantExpenses = ctrl.expenses
        .where((e) =>
            e.status != 'rejected' &&
            isInDateRange(e.date.isNotEmpty ? e.date : e.createdAt))
        .toList();
    final totalExp = relevantExpenses.fold<double>(0.0, (s, e) => s + e.amount);
    final netProfit = totalRevenue - totalExp;
    final profitMargin =
        totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    final relevantBills = ctrl.billingRecords
        .where((b) => isInDateRange(
            b.invoiceDate.isNotEmpty ? b.invoiceDate : b.createdAt))
        .toList();
    final totalReceivables =
        relevantBills.fold<double>(0.0, (s, b) => s + b.balanceDue);
    final unpaidBillsCount =
        relevantBills.where((b) => b.balanceDue > 0).length;

    final activeVehicles = ctrl.truckModels
        .where((t) => !t.isDisabled && !t.isUnderMaintenance)
        .length;
    final inShopVehicles =
        ctrl.truckModels.where((t) => t.isUnderMaintenance).length;

    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayAtt = ctrl.attendanceRecords
        .where((a) => a.date.startsWith(todayStr))
        .toList();
    final presentToday = todayAtt.where((a) => a.status == 'present').length;
    final onDutyNow = ctrl.attendanceRecords.where((a) => a.isOnDuty).length;

    final cards = [
      _KpiCardData(
        title: 'Trips & Deliveries',
        count: '${relevantTrips.length}',
        subtitle:
            '${relevantTrips.where((t) => t.status == "planned").length} Planned · ${relevantTrips.where((t) => t.status == "in_transit").length} In Transit',
        indicator:
            '${relevantTrips.where((t) => t.status == "completed").length} Completed',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF059669),
        bgSoft: const Color(0xFFECFDF5),
        onTap: () => widget.onNavigate(WorkspaceSection.trips),
      ),
      _KpiCardData(
        title: 'Cargo Onboard',
        count: '${cargoOnboardTons.toStringAsFixed(1)} Tons',
        subtitle: 'Across ${activeTrips.length} Active Shipments',
        indicator: 'In-Transit Freight',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF2563EB),
        bgSoft: const Color(0xFFEFF6FF),
        onTap: () => widget.onNavigate(WorkspaceSection.trips),
      ),
      _KpiCardData(
        title: 'Net Profit / Loss',
        count: '₹${netProfit.abs().toStringAsFixed(0)}',
        subtitle:
            'Rev: ₹${totalRevenue.toStringAsFixed(0)} · Exp: ₹${totalExp.toStringAsFixed(0)}',
        indicator:
            '${netProfit >= 0 ? "+" : "-"}${profitMargin.toStringAsFixed(1)}% Margin',
        icon: Icons.analytics_outlined,
        color:
            netProfit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        bgSoft:
            netProfit >= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        onTap: () => widget.onNavigate(WorkspaceSection.expenses),
      ),
      _KpiCardData(
        title: 'Pending Receivables',
        count: '₹${totalReceivables.toStringAsFixed(0)}',
        subtitle: '$unpaidBillsCount Unpaid / Partial Bills',
        indicator: 'Aging Balance Due',
        icon: Icons.payments_outlined,
        color: const Color(0xFFD97706),
        bgSoft: const Color(0xFFFEF3C7),
        onTap: () => widget.onNavigate(WorkspaceSection.billing),
      ),
      _KpiCardData(
        title: 'Fleet Vehicles',
        count: '${ctrl.truckModels.length}',
        subtitle: '$activeVehicles Ready · $inShopVehicles In-Shop',
        indicator: 'Live GPS Fleet',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF7C3AED),
        bgSoft: const Color(0xFFF3E8FF),
        onTap: () => widget.onNavigate(WorkspaceSection.vehicles),
      ),
      _KpiCardData(
        title: 'Driver Presence',
        count: '${ctrl.drivers.length} Drivers',
        subtitle: '$presentToday Present Today · $onDutyNow On Duty',
        indicator: 'Real-time Shifts',
        icon: Icons.how_to_reg_outlined,
        color: const Color(0xFF0D9488),
        bgSoft: const Color(0xFFCCFBF1),
        onTap: () => widget.onNavigate(WorkspaceSection.attendance),
      ),
      _KpiCardData(
        title: 'Active Alerts',
        count: '${unresolvedAlerts.length}',
        subtitle: '$criticalCount Critical · $warningCount Warning',
        indicator: criticalCount > 0 ? 'Action Required' : 'All Clear',
        icon: Icons.notifications_active_outlined,
        color: criticalCount > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        bgSoft: criticalCount > 0
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFECFDF5),
        onTap: () => widget.onNavigate(WorkspaceSection.alerts),
      ),
      _KpiCardData(
        title: 'Logistics Reports',
        count: '11 Reports',
        subtitle: 'Trip, P&L, Fuel, POD, SLA & CSV',
        indicator: 'Audit Ready',
        icon: Icons.assessment_outlined,
        color: const Color(0xFF4F46E5),
        bgSoft: const Color(0xFFEEF2FF),
        onTap: () => widget.onNavigate(WorkspaceSection.reports),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 1120
                ? 2
                : 4;

        if (crossAxisCount == 4) {
          return Column(
            children: [
              Row(
                children: [
                  for (int i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: _buildKpiCard(cards[i])),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (int i = 4; i < 8; i++) ...[
                    if (i > 4) const SizedBox(width: 14),
                    Expanded(child: _buildKpiCard(cards[i])),
                  ],
                ],
              ),
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.map((data) {
            final width = (constraints.maxWidth - (crossAxisCount - 1) * 14) /
                crossAxisCount;
            return SizedBox(
              width: width,
              child: _buildKpiCard(data),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiCardData data) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F2440),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: data.bgSoft,
                    foregroundColor: data.color,
                    child: Icon(data.icon, size: 19),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: data.bgSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.indicator,
                      style: TextStyle(
                        color: data.color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data.count,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLiveActivityStream(PlannerController ctrl) {
    final activities = _filteredActivities;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Live Activity Feed',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blueSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${ctrl.activities.length}',
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ctrl.activities.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearActivityLog,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                        label: const Text(
                          'Clear Log',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every addition, modification, status update and dispatch across the platform reflects here live in real-time.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.slate),
                ),
                const SizedBox(height: 12),
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    hintText: 'Search live activities...',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                          'all', 'All (${ctrl.activities.length})'),
                      _buildFilterChip('driver',
                          'Drivers (${_countCategory(ctrl, ActivityCategory.driver)})'),
                      _buildFilterChip('vehicle',
                          'Vehicles (${_countCategory(ctrl, ActivityCategory.vehicle)})'),
                      _buildFilterChip('trip',
                          'Trips (${_countCategory(ctrl, ActivityCategory.trip)})'),
                      _buildFilterChip('alert',
                          'Alerts (${_countCategory(ctrl, ActivityCategory.alert)})'),
                      _buildFilterChip('planner',
                          'System (${_countCategory(ctrl, ActivityCategory.planner)})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (ctrl.isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (activities.isEmpty)
            _buildEmptyActivityFeed(ctrl)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final event = activities[index];
                return _buildActivityCard(event, ctrl);
              },
            ),
        ],
      ),
    );
  }

  int _countCategory(PlannerController ctrl, ActivityCategory cat) =>
      ctrl.activities.where((a) => a.category == cat).length;

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.slate,
          ),
        ),
        selectedColor: AppColors.blue,
        backgroundColor: AppColors.canvas,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.blue : const Color(0xFFD8E1EE),
          ),
        ),
        onSelected: (_) => setState(() => _selectedFilter = key),
      ),
    );
  }

  Widget _buildEmptyActivityFeed(PlannerController ctrl) {
    final hasSearch = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.sensors_rounded,
                size: 32,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasSearch
                  ? 'No matching activities'
                  : 'Live Activity Stream Waiting',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasSearch
                  ? 'Try searching for another keyword or change your active category filter.'
                  : 'Add a driver, vehicle, trip or alert. Every addition and change will show up here live in real-time!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openAddDialog(OperationsModule.drivers),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Driver',
                      style: TextStyle(fontSize: 11.5)),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openAddDialog(OperationsModule.trips),
                  icon: const Icon(Icons.add, size: 15),
                  label:
                      const Text('Add Trip', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityEvent event, PlannerController ctrl) {
    final cat = event.category;
    final timeStr = _formatRelativeTime(event.timestamp);

    final (actionBg, actionFg, actionIcon) = switch (event.action) {
      'added' => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          Icons.add_circle_outline_rounded
        ),
      'removed' => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          Icons.remove_circle_outline_rounded
        ),
      'resolved' => (
          const Color(0xFFF3E8FF),
          const Color(0xFF7E22CE),
          Icons.check_circle_outline_rounded
        ),
      'system' => (
          const Color(0xFFE0F2FE),
          const Color(0xFF0369A1),
          Icons.info_outline_rounded
        ),
      _ => (
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          Icons.sync_rounded
        ),
    };

    // Check if this event corresponds to a Trip with coordinates
    TripRecord? matchedTrip;
    if (cat == ActivityCategory.trip) {
      for (final t in ctrl.trips) {
        if (event.details.contains(t.reference)) {
          matchedTrip = t;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: cat.background,
                foregroundColor: cat.color,
                child: Icon(cat.icon, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(actionIcon, size: 10, color: actionFg),
                              const SizedBox(width: 4),
                              Text(
                                event.action.toUpperCase(),
                                style: TextStyle(
                                  color: actionFg,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.label,
                          style: TextStyle(
                            color: cat.color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (matchedTrip != null) ...[
                      // Render friendly resolved route details
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD8E1EE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_checked,
                                size: 12, color: AppColors.blue),
                            const SizedBox(width: 5),
                            Text(
                              _shortCity(matchedTrip.origin),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 12, color: AppColors.slate),
                            ),
                            const Icon(Icons.location_on,
                                size: 12, color: Color(0xFFEF4444)),
                            const SizedBox(width: 5),
                            Text(
                              _shortCity(matchedTrip.destination),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              matchedTrip.reference,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        event.details,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slate,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _navigateForEvent(event),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                tooltip: 'Go to ${cat.label} module',
                visualDensity: VisualDensity.compact,
                color: AppColors.muted,
              ),
            ],
          ),
          if (matchedTrip != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _viewTripOnMap(matchedTrip!),
                  icon: const Icon(Icons.map_rounded, size: 13),
                  label:
                      const Text('View on Map', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: () => _loadTripIntoRoute(matchedTrip!),
                  icon: const Icon(Icons.alt_route_rounded, size: 13),
                  label: const Text('Load in Planner',
                      style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _navigateForEvent(ActivityEvent event) {
    final section = switch (event.category) {
      ActivityCategory.driver => WorkspaceSection.drivers,
      ActivityCategory.vehicle => WorkspaceSection.vehicles,
      ActivityCategory.trip => WorkspaceSection.trips,
      ActivityCategory.alert => WorkspaceSection.alerts,
      ActivityCategory.planner => WorkspaceSection.planner,
    };
    widget.onNavigate(section);
  }

  // ignore: unused_element
  Widget _buildSidebarPanels({
    required PlannerController ctrl,
    required List<OperationsAlert> unresolvedAlerts,
  }) {
    return Column(
      children: [
        _buildProtrackGpsCard(ctrl),
        const SizedBox(height: 18),
        _buildPlannerStatusCard(ctrl),
        const SizedBox(height: 18),
        _buildRecentItemsCard(ctrl),
        const SizedBox(height: 18),
        _buildActiveAlertsCard(ctrl, unresolvedAlerts),
      ],
    );
  }

  Widget _buildProtrackGpsCard(PlannerController ctrl) {
    final syncedTime = ctrl.lastGpsSyncTime != null
        ? _formatRelativeTime(ctrl.lastGpsSyncTime!)
        : 'Not synced yet';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt_rounded,
                        color: AppColors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Protrack Live GPS',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildLivePulseIndicator(compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Account: ${ProtrackGpsService.instance.maskedAccount} · Last sync: $syncedTime',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.slate,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: ctrl.truckModels.map((truck) {
                final isIgnition = truck.isIgnitionOn;
                final isMoving = truck.isMoving;
                final isNeverSynced = truck.isNeverSynced;
                final isDemo = truck.isDemoTelemetry;
                final isStale = truck.isGpsStale;

                final Color dotColor;
                final Color badgeBg;
                final Color badgeText;
                final String statusLabel;

                if (isNeverSynced) {
                  dotColor = const Color(0xFF94A3B8);
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeText = const Color(0xFF64748B);
                  statusLabel = 'NO SYNC';
                } else if (isDemo) {
                  dotColor = const Color(0xFFF59E0B);
                  badgeBg = const Color(0xFFFEF3C7);
                  badgeText = const Color(0xFFB45309);
                  statusLabel = isMoving
                      ? 'DEMO ${truck.currentSpeed.toStringAsFixed(0)} km/h'
                      : (isIgnition ? 'DEMO IDLE' : 'DEMO PARKED');
                } else if (isStale) {
                  dotColor = const Color(0xFFEF4444);
                  badgeBg = const Color(0xFFFEE2E2);
                  badgeText = const Color(0xFFB91C1C);
                  statusLabel = 'STALE FIX';
                } else if (isIgnition) {
                  dotColor = const Color(0xFF10B981);
                  badgeBg = isMoving
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFDBEAFE);
                  badgeText = isMoving
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF2563EB);
                  statusLabel = isMoving
                      ? '${truck.currentSpeed.toStringAsFixed(0)} km/h'
                      : 'ACC ON';
                } else {
                  dotColor = const Color(0xFF94A3B8);
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeText = AppColors.slate;
                  statusLabel = 'ACC OFF';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              truck.code,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              truck.imei.isNotEmpty
                                  ? 'IMEI: ${truck.maskedImei}'
                                  : 'No IMEI',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.muted,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (ctrl.lastGpsSyncError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ctrl.lastGpsSyncError!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: ctrl.isGpsSyncing
                    ? null
                    : () async {
                        final res = await ctrl.syncProtrackGps();
                        if (mounted) {
                          final isSuccess = res['success'] == true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ??
                                  (isSuccess
                                      ? 'GPS Sync complete.'
                                      : 'GPS Sync failed.')),
                              backgroundColor: isSuccess
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                icon: ctrl.isGpsSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  ctrl.isGpsSyncing ? 'Syncing...' : 'Sync GPS',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showConfigureGpsDialog(context, ctrl),
                icon: const Icon(Icons.settings_suggest_rounded, size: 15),
                label: const Text(
                  'GPS Settings',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConfigureGpsDialog(BuildContext context, PlannerController ctrl) {
    final configured = ProtrackGpsService.instance.isConfigured;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.satellite_alt_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Protrack GPS Settings', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Protrack login/password APK mein save nahi hote. Live GPS trusted Firebase proxy se aata hai.',
              style: TextStyle(fontSize: 12, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                configured ? Icons.verified_user : Icons.cloud_off,
                color: configured ? Colors.green : Colors.red,
              ),
              title: Text(
                  configured ? 'Secure proxy configured' : 'Proxy URL missing'),
              subtitle: Text(configured
                  ? ProtrackGpsService.instance.maskedAccount
                  : 'Build with PROTRACK_PROXY_URL pointing to the deployed function.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final res = await ctrl.syncProtrackGps();
              if (context.mounted) {
                final ok = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ??
                        (ok ? 'GPS Connected!' : 'Sync Failed')),
                    backgroundColor:
                        ok ? const Color(0xFF1E293B) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: const Text('Test Secure Sync'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerStatusCard(PlannerController ctrl) {
    final isRouteReady = ctrl.canShowRoute;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.near_me_rounded,
                        color: AppColors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Route Status',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRouteReady
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isRouteReady ? 'ROUTE ACTIVE' : 'NO ROUTE',
                  style: TextStyle(
                    color: isRouteReady
                        ? const Color(0xFF16A34A)
                        : AppColors.slate,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.blueSoft,
                foregroundColor: AppColors.blue,
                child: Icon(ctrl.vehicle.icon, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Vehicle Profile: ${ctrl.vehicle.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFF),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        size: 13, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ctrl.origin.isNotEmpty
                            ? _friendlyLocation(ctrl.origin)
                            : 'Starting point not selected',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ctrl.origin.isNotEmpty
                              ? AppColors.navy
                              : AppColors.muted,
                          fontWeight: ctrl.origin.isNotEmpty
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 5),
                      SizedBox(
                        height: 10,
                        child: VerticalDivider(
                          color: Color(0xFFCBD5E1),
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ctrl.destination.isNotEmpty
                            ? _friendlyLocation(ctrl.destination)
                            : 'Destination not selected',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ctrl.destination.isNotEmpty
                              ? AppColors.navy
                              : AppColors.muted,
                          fontWeight: ctrl.destination.isNotEmpty
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isRouteReady) ...[
            Builder(
              builder: (context) {
                final p1 = RouteTrafficService.parseLocation(ctrl.origin);
                final p2 = RouteTrafficService.parseLocation(ctrl.destination);
                final distKm = (p1 != null && p2 != null)
                    ? RouteTrafficService.estimateRoadDistanceKm(p1, p2)
                    : 150.0;
                TruckModel? truckModel;
                if (ctrl.vehicle == VehicleType.truck &&
                    ctrl.truckIndex != null &&
                    ctrl.truckIndex! >= 0 &&
                    ctrl.truckIndex! < ctrl.truckModels.length) {
                  truckModel = ctrl.truckModels[ctrl.truckIndex!];
                }
                final report = RouteTrafficService.analyzeTraffic(
                  distanceKm: distKm,
                  vehicle: ctrl.vehicle,
                  truckModel: truckModel,
                );
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: report.level.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: report.level.color.withValues(alpha: .35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.traffic_rounded,
                          size: 16, color: report.level.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  report.formattedDistance,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const Text(' · ',
                                    style: TextStyle(color: AppColors.muted)),
                                Text(
                                  'Est. ${report.formattedDuration}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Traffic: ${report.level.label} · +${report.delayMinutes}m delay',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: report.level.color,
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
          ] else if (ctrl.trips.isNotEmpty) ...[
            // Quick load banner when route is empty but trips exist
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_auto_rounded,
                      size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Load ${ctrl.trips.last.reference} (${_shortCity(ctrl.trips.last.origin)} -> ${_shortCity(ctrl.trips.last.destination)})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _loadTripIntoRoute(ctrl.trips.last),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Load',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (isRouteReady) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openExternalRoute,
                    icon: const Icon(Icons.open_in_new, size: 13),
                    label: const Text('Open Map',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => widget.onNavigate(WorkspaceSection.planner),
                  child: const Text('Open Planner',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemsCard(PlannerController ctrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Recent Fleet Records',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final section = switch (_recentTab) {
                      0 => WorkspaceSection.trips,
                      1 => WorkspaceSection.drivers,
                      _ => WorkspaceSection.vehicles,
                    };
                    widget.onNavigate(section);
                  },
                  child:
                      const Text('View All ->', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildSegmentButton(0, 'Trips (${ctrl.trips.length})'),
                const SizedBox(width: 6),
                _buildSegmentButton(1, 'Drivers (${ctrl.drivers.length})'),
                const SizedBox(width: 6),
                _buildSegmentButton(2, 'Vehicles (${ctrl.truckModels.length})'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _buildRecentTabContent(ctrl),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title) {
    final active = _recentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _recentTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.blueSoft : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppColors.blue : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.blue : AppColors.slate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTabContent(PlannerController ctrl) {
    if (_recentTab == 0) {
      if (ctrl.trips.isEmpty) {
        return _buildEmptyRecentMessage(
          'No trips created yet',
          'Create a trip to track routes live.',
          () => _openAddDialog(OperationsModule.trips),
          'Create Trip',
        );
      }
      final latest = ctrl.trips.reversed.take(4).toList();
      return Column(
        children: latest.map((trip) {
          final isDone = trip.status == 'completed';
          final isInTransit = trip.status == 'in_transit';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFECFDF5),
                  foregroundColor: Color(0xFF059669),
                  child: Icon(Icons.alt_route_rounded, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.reference,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_shortCity(trip.origin)} -> ${_shortCity(trip.destination)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _loadTripIntoRoute(trip),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                  tooltip: 'Load into Planner',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.blue,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFDCFCE7)
                        : isInTransit
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trip.status.toUpperCase(),
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF16A34A)
                          : isInTransit
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD97706),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else if (_recentTab == 1) {
      if (ctrl.drivers.isEmpty) {
        return _buildEmptyRecentMessage(
          'No drivers registered',
          'Add fleet drivers for delivery assignments.',
          () => _openAddDialog(OperationsModule.drivers),
          'Add Driver',
        );
      }
      final latest = ctrl.drivers.reversed.take(4).toList();
      return Column(
        children: latest.map((driver) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.blueSoft,
                  foregroundColor: AppColors.blue,
                  child: Icon(Icons.person_outline_rounded, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        driver.email,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      if (ctrl.truckModels.isEmpty) {
        return _buildEmptyRecentMessage(
          'No vehicles configured',
          'Add truck specs for capacity planning.',
          () => _openAddDialog(OperationsModule.vehicles),
          'Add Vehicle',
        );
      }
      final latest = ctrl.truckModels.reversed.take(4).toList();
      return Column(
        children: latest.map((model) {
          final hasGps = model.imei.isNotEmpty;
          final isMoving = model.isMoving;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: hasGps
                      ? (isMoving
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9))
                      : const Color(0xFFF3E8FF),
                  foregroundColor: hasGps
                      ? (isMoving ? const Color(0xFF16A34A) : AppColors.slate)
                      : const Color(0xFF7C3AED),
                  child: Icon(
                    hasGps
                        ? Icons.gps_fixed_rounded
                        : Icons.local_shipping_outlined,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${model.code} · ${model.capacity}${model.imei.isNotEmpty ? " · IMEI: ${model.maskedImei}" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (hasGps)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: model.isIgnitionOn
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      model.isIgnitionOn
                          ? (isMoving
                              ? '${model.currentSpeed.toStringAsFixed(0)} km/h'
                              : 'ACC ON')
                          : 'ACC OFF',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: model.isIgnitionOn
                            ? const Color(0xFF16A34A)
                            : AppColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildEmptyRecentMessage(
    String title,
    String desc,
    VoidCallback onAdd,
    String buttonText,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              desc,
              style: const TextStyle(fontSize: 11, color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: onAdd,
              child: Text(buttonText, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlertsCard(
    PlannerController ctrl,
    List<OperationsAlert> unresolvedAlerts,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: unresolvedAlerts.isNotEmpty
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Operational Alerts & Notifications',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(WorkspaceSection.alerts),
                child: const Text('Manage ->', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (unresolvedAlerts.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All systems operational. No active critical warnings.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceAround,
                children: [
                  Builder(
                    builder: (context) {
                      final hasFreshFix = ctrl.truckModels
                          .any((t) => t.hasValidGpsFix && !t.isGpsStale);
                      final isDemo =
                          ctrl.truckModels.any((t) => t.isDemoTelemetry);
                      final String gpsStatus;
                      final Color gpsColor;
                      final Color dotColor;

                      if (ctrl.isGpsSyncing) {
                        gpsStatus = 'Syncing';
                        gpsColor = const Color(0xFF2563EB);
                        dotColor = const Color(0xFF3B82F6);
                      } else if (ctrl.lastGpsSyncError != null) {
                        gpsStatus = 'Offline';
                        gpsColor = const Color(0xFFDC2626);
                        dotColor = const Color(0xFFEF4444);
                      } else if (isDemo) {
                        gpsStatus = 'Demo Feed';
                        gpsColor = const Color(0xFFD97706);
                        dotColor = const Color(0xFFF59E0B);
                      } else if (hasFreshFix) {
                        gpsStatus = 'Online';
                        gpsColor = const Color(0xFF047857);
                        dotColor = const Color(0xFF10B981);
                      } else if (ctrl.lastGpsSyncTime != null) {
                        gpsStatus = 'Stale Fix';
                        gpsColor = const Color(0xFFD97706);
                        dotColor = const Color(0xFFF59E0B);
                      } else {
                        gpsStatus = 'Standby';
                        gpsColor = const Color(0xFF64748B);
                        dotColor = const Color(0xFF94A3B8);
                      }

                      return _SystemRadarStat(
                        label: 'GPS Stream',
                        status: gpsStatus,
                        statusColor: gpsColor,
                        dotColor: dotColor,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final String routeStatus;
                      final Color routeColor;
                      final Color dotColor;

                      if (ctrl.isNavigating) {
                        routeStatus = 'Navigating';
                        routeColor = const Color(0xFF2563EB);
                        dotColor = const Color(0xFF3B82F6);
                      } else if (ctrl.canShowRoute) {
                        routeStatus = 'Active Route';
                        routeColor = const Color(0xFF047857);
                        dotColor = const Color(0xFF10B981);
                      } else if (ctrl.origin.trim().isNotEmpty ||
                          ctrl.destination.trim().isNotEmpty) {
                        routeStatus = 'Configuring';
                        routeColor = const Color(0xFFD97706);
                        dotColor = const Color(0xFFF59E0B);
                      } else {
                        routeStatus = 'Ready';
                        routeColor = const Color(0xFF047857);
                        dotColor = const Color(0xFF10B981);
                      }

                      return _SystemRadarStat(
                        label: 'OSRM Route',
                        status: routeStatus,
                        statusColor: routeColor,
                        dotColor: dotColor,
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final hasFreshFix = ctrl.truckModels
                          .any((t) => t.hasValidGpsFix && !t.isGpsStale);
                      final String trafficStatus;
                      final Color trafficColor;
                      final Color dotColor;

                      if (ctrl.isNavigating) {
                        trafficStatus = 'Live Tracking';
                        trafficColor = const Color(0xFF047857);
                        dotColor = const Color(0xFF10B981);
                      } else if (ctrl.lastGpsSyncTime != null && hasFreshFix) {
                        trafficStatus = 'Synced';
                        trafficColor = const Color(0xFF1D4ED8);
                        dotColor = const Color(0xFF2563EB);
                      } else if (ctrl.isGpsSyncing) {
                        trafficStatus = 'Updating';
                        trafficColor = const Color(0xFF2563EB);
                        dotColor = const Color(0xFF3B82F6);
                      } else {
                        trafficStatus = 'Standby';
                        trafficColor = const Color(0xFF64748B);
                        dotColor = const Color(0xFF94A3B8);
                      }

                      return _SystemRadarStat(
                        label: 'GPS Telemetry',
                        status: trafficStatus,
                        statusColor: trafficColor,
                        dotColor: dotColor,
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            Column(
              children: unresolvedAlerts.take(3).map((alert) {
                final originalIndex = ctrl.alerts.indexOf(alert);
                final isCritical = alert.severity == 'critical';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCritical
                          ? const Color(0xFFFECDD3)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isCritical
                            ? Icons.error_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 17,
                        color: isCritical
                            ? const Color(0xFFE11D48)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isCritical
                                          ? const Color(0xFF9F1239)
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCritical
                                        ? const Color(0xFFE11D48)
                                        : const Color(0xFFD97706),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alert.severity.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              alert.details,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCritical
                                    ? const Color(0xFFBE123C)
                                    : const Color(0xFFB45309),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () =>
                                    ctrl.toggleAlertResolved(originalIndex),
                                child: Text(
                                  'Mark as Resolved',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isCritical
                                        ? const Color(0xFFE11D48)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFooterSummary(PlannerController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: AppColors.blue),
              const SizedBox(width: 8),
              const Text(
                'Central Fleet Command',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              const Text('·', style: TextStyle(color: AppColors.muted)),
              const SizedBox(width: 8),
              Text(
                '${ctrl.drivers.length} Drivers · ${ctrl.truckModels.length} Vehicles · ${ctrl.trips.length} Trips',
                style: const TextStyle(fontSize: 11, color: AppColors.slate),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                SizedBox(width: 5),
                Text(
                  'Real-Time Ready',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
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

class _SystemRadarStat extends StatelessWidget {
  const _SystemRadarStat({
    required this.label,
    required this.status,
    this.statusColor = const Color(0xFF047857),
    this.dotColor = const Color(0xFF10B981),
  });
  final String label;
  final String status;
  final Color statusColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 3, backgroundColor: dotColor),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.indicator,
    required this.icon,
    required this.color,
    required this.bgSoft,
    required this.onTap,
  });

  final String title;
  final String count;
  final String subtitle;
  final String indicator;
  final IconData icon;
  final Color color;
  final Color bgSoft;
  final VoidCallback onTap;
}
