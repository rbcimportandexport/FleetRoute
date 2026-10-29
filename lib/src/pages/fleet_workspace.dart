import 'fastag_history_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../services/app_localization_service.dart';
import '../services/app_update_service.dart';
import '../services/incoming_intent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/seatbelt_records_dialog.dart';
import 'alerts_page.dart';
import 'attendance_page.dart';
import 'billing_page.dart';
import 'dashboard_page.dart';
import 'driver_portal_page.dart';
import 'document_gallery_page.dart';
import 'expenses_page.dart';
import 'operations_module_page.dart';
import 'reports_page.dart';
import 'route_planner_page.dart';
import 'trips_page.dart';

enum WorkspaceSection {
  dashboard,
  planner,
  trips,
  drivers,
  vehicles,
  attendance,
  expenses,
  billing,
  reports,
  alerts,
  driverDocuments,
  vehicleDocuments,
  fastag,
}

extension WorkspaceSectionView on WorkspaceSection {
  String get label => switch (this) {
        WorkspaceSection.dashboard =>
          AppLocalizationService.instance.tr('dashboard'),
        WorkspaceSection.planner =>
          AppLocalizationService.instance.tr('planner'),
        WorkspaceSection.trips => AppLocalizationService.instance.tr('trips'),
        WorkspaceSection.drivers =>
          AppLocalizationService.instance.tr('drivers'),
        WorkspaceSection.vehicles =>
          AppLocalizationService.instance.tr('vehicles'),
        WorkspaceSection.attendance =>
          AppLocalizationService.instance.tr('attendance'),
        WorkspaceSection.expenses =>
          AppLocalizationService.instance.tr('expenses'),
        WorkspaceSection.billing =>
          AppLocalizationService.instance.tr('billing'),
        WorkspaceSection.reports =>
          AppLocalizationService.instance.tr('reports'),
        WorkspaceSection.alerts => AppLocalizationService.instance.tr('alerts'),
        WorkspaceSection.driverDocuments => 'Driver Docs',
        WorkspaceSection.vehicleDocuments => 'Vehicle Docs',
        WorkspaceSection.fastag => 'FASTag Wallet',
      };

  IconData get icon => switch (this) {
        WorkspaceSection.dashboard => Icons.dashboard_rounded,
        WorkspaceSection.planner => Icons.map_outlined,
        WorkspaceSection.trips => Icons.route_outlined,
        WorkspaceSection.drivers => Icons.badge_outlined,
        WorkspaceSection.vehicles => Icons.local_shipping_outlined,
        WorkspaceSection.attendance => Icons.how_to_reg_outlined,
        WorkspaceSection.expenses => Icons.receipt_long_outlined,
        WorkspaceSection.billing => Icons.payments_outlined,
        WorkspaceSection.reports => Icons.assessment_outlined,
        WorkspaceSection.alerts => Icons.notifications_none_rounded,
        WorkspaceSection.driverDocuments => Icons.badge_outlined,
        WorkspaceSection.vehicleDocuments => Icons.folder_copy_outlined,
        WorkspaceSection.fastag => Icons.toll_rounded,
      };
}

class FleetWorkspace extends StatefulWidget {
  const FleetWorkspace({super.key, this.controller});

  final PlannerController? controller;

  @override
  State<FleetWorkspace> createState() => _FleetWorkspaceState();
}

class _FleetWorkspaceState extends State<FleetWorkspace> {
  late final PlannerController controller;
  bool _ownsController = false;
  WorkspaceSection selected = WorkspaceSection.dashboard;
  StreamSubscription<IncomingLocationData>? _intentSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      controller = widget.controller!;
      _ownsController = false;
    } else {
      controller = PlannerController();
      _ownsController = true;
      controller.load();
    }

    _listenLocationIntents();
  }

  void _listenLocationIntents() {
    // 1. Warm start listener
    _intentSubscription =
        IncomingIntentService().onLocationReceived.listen((data) {
      if (!mounted) return;
      if (selected != WorkspaceSection.planner) {
        setState(() => selected = WorkspaceSection.planner);
      }
    });

    // 2. Cold start check
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await IncomingIntentService().checkInitialLocation();
      if (initial != null && mounted) {
        if (selected != WorkspaceSection.planner) {
          setState(() => selected = WorkspaceSection.planner);
        }
      }
      // Silently check and apply updates in the background without any UI dialog
      AppUpdateService.instance.checkAndApplyUpdateSilently();
    });
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to sign out from Transport One?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      await controller.logout();
    }
  }

  Widget get _page {
    if (controller.isDriver) {
      return switch (selected) {
        WorkspaceSection.dashboard => DriverPortalPage(
            controller: controller,
            onNavigate: _select,
          ),
        WorkspaceSection.planner => RoutePlannerPage(controller: controller),
        WorkspaceSection.trips => TripsPage(
            controller: controller,
            onOpenPlanner: () => _select(WorkspaceSection.planner),
          ),
        WorkspaceSection.alerts => AlertsPage(controller: controller),
        WorkspaceSection.attendance => AttendancePage(controller: controller),
        _ => DriverPortalPage(
            controller: controller,
            onNavigate: _select,
          ),
      };
    }

    return switch (selected) {
      WorkspaceSection.dashboard => DashboardPage(
          controller: controller,
          onNavigate: _select,
        ),
      WorkspaceSection.planner => RoutePlannerPage(controller: controller),
      WorkspaceSection.trips => TripsPage(
          controller: controller,
          onOpenPlanner: () => _select(WorkspaceSection.planner),
        ),
      WorkspaceSection.drivers => OperationsModulePage(
          module: OperationsModule.drivers,
          controller: controller,
        ),
      WorkspaceSection.vehicles => OperationsModulePage(
          module: OperationsModule.vehicles,
          controller: controller,
        ),
      WorkspaceSection.attendance => AttendancePage(controller: controller),
      WorkspaceSection.expenses => ExpensesPage(controller: controller),
      WorkspaceSection.billing => BillingPage(controller: controller),
      WorkspaceSection.reports => ReportsPage(controller: controller),
      WorkspaceSection.alerts => AlertsPage(controller: controller),
      WorkspaceSection.driverDocuments => DocumentGalleryPage(
          controller: controller,
          mode: DocumentGalleryMode.driver,
        ),
      WorkspaceSection.vehicleDocuments => DocumentGalleryPage(
          controller: controller,
          mode: DocumentGalleryMode.vehicle,
        ),
      WorkspaceSection.fastag => FastagHistoryPage(
          controller: controller,
          vehicleCode: controller.truckModels.isNotEmpty ? controller.truckModels.first.code : '',
        ),
    };
  }

  void _select(WorkspaceSection value) {
    if (value != WorkspaceSection.planner) {
      controller.setPinMode(false);
    }
    setState(() => selected = value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizationService.instance.currentLanguage,
      builder: (context, currentLanguage, _) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 820;

                final mobileBottomSections = controller.isDriver
                    ? const [
                        WorkspaceSection.dashboard,
                        WorkspaceSection.planner
                      ]
                    : const [
                        WorkspaceSection.dashboard,
                        WorkspaceSection.planner,
                        WorkspaceSection.trips,
                        WorkspaceSection.reports,
                        WorkspaceSection.alerts,
                      ];

                final currentBottomIndex =
                    mobileBottomSections.indexOf(selected);
                final safeBottomIndex =
                    currentBottomIndex >= 0 ? currentBottomIndex : 0;

                if (!desktop) {
                  final isNavigatingOnPlanner =
                      selected == WorkspaceSection.planner &&
                          controller.isNavigating;
                  return Scaffold(
                    appBar: isNavigatingOnPlanner
                        ? null
                        : AppBar(
                            title: Text(
                              controller.isDriver
                                  ? (selected == WorkspaceSection.planner
                                      ? AppLocalizationService.instance
                                          .tr('trip_navigation_title')
                                      : selected == WorkspaceSection.attendance
                                          ? AppLocalizationService.instance
                                              .tr('attendance_history')
                                          : AppLocalizationService.instance
                                              .tr('driver_desk_title'))
                                  : selected.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.navy,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.white,
                            elevation: 0.5,
                            actions: [
                              _buildLanguagePicker(),
                              IconButton(
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.notifications_none_rounded,
                                        color: AppColors.iconColor),
                                    if (controller.alerts.any((a) =>
                                        !a.isResolved &&
                                        a.category != 'compliance'))
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDC2626),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                tooltip: 'Alerts & Notifications',
                                onPressed: () =>
                                    _select(WorkspaceSection.alerts),
                              ),
                              IconButton(
                                icon: const Icon(Icons.verified_user_outlined,
                                    color: AppColors.blue),
                                tooltip: 'Seatbelt Photos',
                                onPressed: () => SeatbeltRecordsDialog.show(
                                  context,
                                  controller: controller,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded,
                                    color: AppColors.iconColor),
                                tooltip: 'Sign Out',
                                onPressed: _confirmLogout,
                              ),
                            ],
                          ),
                    drawer: isNavigatingOnPlanner
                        ? null
                        : _Sidebar(
                            selected: selected,
                            controller: controller,
                            onLogout: _confirmLogout,
                            onSelected: (value) {
                              Navigator.pop(context);
                              _select(value);
                            },
                          ),
                    body: _page,
                    bottomNavigationBar: isNavigatingOnPlanner
                        ? null
                        : SafeArea(
                            top: false,
                            bottom: true,
                            child: _buildModernBottomNav(
                              sections: mobileBottomSections,
                              selectedIndex: safeBottomIndex,
                            ),
                          ),
                  );
                }

                return Scaffold(
                  body: SafeArea(
                    child: Row(
                      children: [
                        _Sidebar(
                          selected: selected,
                          controller: controller,
                          onLogout: _confirmLogout,
                          onSelected: _select,
                        ),
                        Expanded(child: _page),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildModernBottomNav({
    required List<WorkspaceSection> sections,
    required int selectedIndex,
  }) {
    final driverLabels = [
      AppLocalizationService.instance.tr('duty_and_photos'),
      AppLocalizationService.instance.tr('trip_and_route'),
    ];
    const driverIcons = [
      Icons.camera_alt_rounded,
      Icons.navigation_rounded,
    ];

    final centerIndex = (sections.length > 2 && sections.length.isOdd)
        ? sections.length ~/ 2
        : -1;

    return SizedBox(
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 72,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0F172A),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(sections.length, (index) {
                final active = index == selectedIndex;
                final label = controller.isDriver
                    ? driverLabels[index]
                    : sections[index].label;
                final icon = controller.isDriver
                    ? driverIcons[index]
                    : sections[index].icon;
                final isCenter = index == centerIndex;
                return Expanded(
                  child: Semantics(
                    selected: active,
                    button: true,
                    label: label,
                    child: InkWell(
                      onTap: () => _select(sections[index]),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCenter)
                              Transform.translate(
                                offset: const Offset(0, -12),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x667C3AED),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 26,
                                child: Icon(
                                  icon,
                                  size: active ? 22 : 20,
                                  color: active
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            if (isCenter)
                              Transform.translate(
                                offset: const Offset(0, -8),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF7C3AED),
                                    fontSize: controller.isDriver ? 10.5 : 8.5,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 15,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: active
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF64748B),
                                    fontSize: controller.isDriver ? 9.5 : 9.0,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePicker() {
    final currentLang = AppLocalizationService.instance.language;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: currentLang,
          isDense: true,
          items: AppLanguage.values.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Text(
                lang.code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) {
              AppLocalizationService.instance.setLanguage(lang);
            }
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelected,
    required this.controller,
    required this.onLogout,
  });

  final WorkspaceSection selected;
  final ValueChanged<WorkspaceSection> onSelected;
  final PlannerController controller;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      child: SizedBox(
        width: 230,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.route_rounded,
                          color: AppColors.blue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      controller.isDriver ? 'Driver Portal' : 'FleetRoute',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation Sections in scrollable view
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      for (final section in (controller.isDriver
                          ? const [
                              WorkspaceSection.dashboard,
                              WorkspaceSection.planner,
                              WorkspaceSection.alerts,
                            ]
                          : WorkspaceSection.values.where(
                              (section) =>
                                  section != WorkspaceSection.attendance,
                            )))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          child: Material(
                            color: selected == section
                                ? AppColors.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => onSelected(section),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: selected == section
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x3316A34A),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      (controller.isDriver &&
                                              section ==
                                                  WorkspaceSection.dashboard)
                                          ? Icons.camera_alt_rounded
                                          : (controller.isDriver &&
                                                  section ==
                                                      WorkspaceSection.planner)
                                              ? Icons.navigation_rounded
                                              : (controller.isDriver &&
                                                      section ==
                                                          WorkspaceSection
                                                              .attendance)
                                                  ? Icons.history_rounded
                                                  : section.icon,
                                      size: 19,
                                      color: selected == section
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        (controller.isDriver &&
                                                section ==
                                                    WorkspaceSection.dashboard)
                                            ? AppLocalizationService.instance
                                                .tr('duty_and_photos')
                                            : (controller.isDriver &&
                                                    section ==
                                                        WorkspaceSection
                                                            .planner)
                                                ? AppLocalizationService
                                                    .instance
                                                    .tr('trip_and_route')
                                                : (controller.isDriver &&
                                                        section ==
                                                            WorkspaceSection
                                                                .attendance)
                                                    ? AppLocalizationService
                                                        .instance
                                                        .tr('attendance_history')
                                                    : section.label,
                                        style: TextStyle(
                                          color: selected == section
                                              ? Colors.white
                                              : const Color(0xFF334155),
                                          fontWeight: selected == section
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Language selector in Sidebar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded,
                        size: 16, color: AppColors.slate),
                    const SizedBox(width: 8),
                    const Text(
                      'Language:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<AppLanguage>(
                        value: AppLocalizationService.instance.language,
                        isDense: true,
                        items: AppLanguage.values.map((lang) {
                          return DropdownMenuItem(
                            value: lang,
                            child: Text(
                              lang.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (lang) {
                          if (lang != null) {
                            AppLocalizationService.instance.setLanguage(lang);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // User Profile & Sign Out Box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: controller.isAdmin
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFDCFCE7),
                          child: Icon(
                            controller.isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.badge_rounded,
                            size: 16,
                            color: controller.isAdmin
                                ? AppColors.blue
                                : const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.isAdmin
                                    ? 'Admin'
                                    : (controller.loggedInName ?? 'Driver'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                controller.loggedInEmail ??
                                    (controller.isAdmin
                                        ? PlannerController.superAdminEmail
                                        : 'Active Driver'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onLogout,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded,
                                size: 13, color: Color(0xFFDC2626)),
                            SizedBox(width: 6),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6610B981),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Live monitoring on',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
