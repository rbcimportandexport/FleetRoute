import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../pages/driver_dashboard_page.dart';

class AdminDriverViewScreen extends StatefulWidget {
  const AdminDriverViewScreen({
    required this.controller,
    this.initialDriver,
    super.key,
  });

  final PlannerController controller;
  final DriverProfile? initialDriver;

  @override
  State<AdminDriverViewScreen> createState() => _AdminDriverViewScreenState();
}

class _AdminDriverViewScreenState extends State<AdminDriverViewScreen> {
  late DriverProfile _selectedDriver;

  List<DriverProfile> get _allDrivers {
    final merged = <DriverProfile>[];
    final seen = <String>{};
    for (final d in [
      ...widget.controller.drivers,
      ...PlannerController.defaultFleetDrivers,
    ]) {
      final phone = d.phone.replaceAll(RegExp(r'\D'), '');
      final key = phone.isNotEmpty ? phone : d.email.trim().toLowerCase();
      if (key.isNotEmpty && seen.add(key)) {
        merged.add(d);
      }
    }
    return merged.isNotEmpty
        ? merged
        : PlannerController.defaultFleetDrivers.toList();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    final drivers = _allDrivers;
    final initial = widget.initialDriver;
    _selectedDriver = initial == null
        ? drivers.first
        : drivers.firstWhere(
            (d) =>
                (initial.email.isNotEmpty &&
                    d.email.trim().toLowerCase() ==
                        initial.email.trim().toLowerCase()) ||
                (initial.phone.isNotEmpty &&
                    d.phone.replaceAll(RegExp(r'\D'), '') ==
                        initial.phone.replaceAll(RegExp(r'\D'), '')) ||
                d.name.trim().toLowerCase() ==
                    initial.name.trim().toLowerCase(),
            orElse: () => drivers.first,
          );
    final idx = widget.controller.drivers.indexWhere(
      (d) =>
          (d.phone.isNotEmpty && d.phone == _selectedDriver.phone) ||
          d.email.trim().toLowerCase() ==
              _selectedDriver.email.trim().toLowerCase(),
    );
    if (idx >= 0) {
      widget.controller.selectDriver(idx);
    }
    unawaited(widget.controller.syncAllDataFromCloud());
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.selectDriver(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _allDrivers;
    final activeDriver = drivers.firstWhere(
      (d) =>
          (_selectedDriver.phone.isNotEmpty &&
              d.phone == _selectedDriver.phone) ||
          d.email.trim().toLowerCase() ==
              _selectedDriver.email.trim().toLowerCase() ||
          d.name == _selectedDriver.name,
      orElse: () => drivers.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${activeDriver.name} का लाइव डैशबोर्ड',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Driver Selector Horizontal Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'ड्राइवर बदलें:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activeDriver.phone.isNotEmpty
                            ? activeDriver.phone
                            : activeDriver.name,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF2563EB)),
                        items: drivers.map((driver) {
                          final isOnline = widget.controller.isVehicleOnline(driver.assignedVehicle);
                          final isOnDuty = widget.controller.isVehicleDriverOnDuty(driver.assignedVehicle) &&
                              (widget.controller.getActiveDuty(driver.email) != null ||
                                  widget.controller.getActiveDuty(driver.name) != null ||
                                  (driver.phone.isNotEmpty && widget.controller.getActiveDuty(driver.phone) != null));
                          return DropdownMenuItem<String>(
                            value: driver.phone.isNotEmpty
                                ? driver.phone
                                : driver.name,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${driver.name} (${driver.assignedVehicle}) • ${isOnline ? "ऑनलाइन" : "ऑफ़लाइन"}${isOnDuty ? " [ड्यूटी]" : ""}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF334155),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final matched = drivers.firstWhere(
                            (d) =>
                                (d.phone.isNotEmpty && d.phone == val) ||
                                d.name == val,
                            orElse: () => drivers.first,
                          );
                          setState(() {
                            _selectedDriver = matched;
                          });
                          final ctrlIdx = widget.controller.drivers.indexWhere(
                            (d) =>
                                (d.phone.isNotEmpty &&
                                    d.phone == matched.phone) ||
                                d.email.trim().toLowerCase() ==
                                    matched.email.trim().toLowerCase(),
                          );
                          if (ctrlIdx >= 0) {
                            widget.controller.selectDriver(ctrlIdx);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Render Full Interactive Driver Dashboard
          Expanded(
            key: ValueKey('${activeDriver.name}_${activeDriver.phone}_${activeDriver.assignedVehicle}'),
            child: DriverDashboardPage(
              controller: widget.controller,
              viewAsDriver: activeDriver,
            ),
          ),
        ],
      ),
    );
  }
}
