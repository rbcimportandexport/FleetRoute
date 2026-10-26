import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';
import 'trip_detail_report_dialog.dart';

class DriverReportDetailDialog extends StatelessWidget {
  const DriverReportDetailDialog({
    required this.driver,
    required this.controller,
    super.key,
  });

  final DriverProfile driver;
  final PlannerController controller;

  TruckModel? get _assignedTruck {
    if (driver.assignedVehicle.isEmpty) return null;
    try {
      return controller.truckModels.firstWhere(
        (t) =>
            t.code.toLowerCase() == driver.assignedVehicle.toLowerCase() ||
            t.name.toLowerCase().contains(driver.assignedVehicle.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isTrackerLive(TruckModel truck) =>
      truck.hasCoordinates &&
      truck.hasValidGpsFix &&
      !truck.isDemoTelemetry &&
      !truck.isGpsStale;

  List<TripRecord> get _driverTrips {
    return controller.trips.where((t) {
      final matchPhone =
          driver.phone.isNotEmpty && t.assignedDriver.contains(driver.phone);
      final matchEmail =
          driver.email.isNotEmpty && t.assignedDriver.contains(driver.email);
      final matchName =
          driver.name.isNotEmpty && t.assignedDriver.contains(driver.name);
      return matchPhone || matchEmail || matchName;
    }).toList();
  }

  List<AttendanceRecord> get _driverAttendance {
    return controller.attendanceRecords.where((a) {
      return a.driverId == driver.email ||
          a.driverId == driver.phone ||
          a.driverName == driver.name;
    }).toList();
  }

  List<SeatbeltRecord> get _driverSeatbelt {
    return controller.seatbeltRecords.where((s) {
      return s.driverId == driver.email ||
          s.driverId == driver.phone ||
          s.driverName == driver.name;
    }).toList();
  }

  List<DeliveryProofRecord> get _driverDeliveryProofs {
    return controller.deliveryProofs.where((p) {
      return p.driverName == driver.name;
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not available';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _copyReport(BuildContext context) {
    final truck = _assignedTruck;
    final trips = _driverTrips;
    final attendance = _driverAttendance;
    final seatbelt = _driverSeatbelt;
    final proofs = _driverDeliveryProofs;

    final buffer = StringBuffer();
    buffer.writeln('========================================================');
    buffer.writeln('            TRANSPORT ONE FLEET MANAGEMENT');
    buffer.writeln('      OFFICIAL DRIVER & VEHICLE COMPLIANCE REPORT');
    buffer
        .writeln('========================================================\n');
    buffer.writeln('Generated On: ${DateTime.now().toIso8601String()}\n');

    buffer.writeln('1. DRIVER PROFILE & IDENTIFICATION');
    buffer.writeln('--------------------------------------------------------');
    buffer.writeln('Name              : ${driver.name}');
    buffer.writeln('Phone / Username  : ${driver.phone}');
    buffer.writeln('Email / ID        : ${driver.email}');
    buffer.writeln('Role              : ${driver.role.toUpperCase()}');
    buffer.writeln(
        'Assigned Vehicle  : ${driver.assignedVehicle.isNotEmpty ? driver.assignedVehicle : "Not Assigned"}');
    buffer.writeln(
        'Account Status    : ${driver.password.isEmpty ? "Credentials Unset" : "Active & Verified"}');
    buffer.writeln('Created / Updated : ${_formatDate(driver.createdAt)}\n');

    buffer.writeln('2. DRIVING LICENSE & COMPLIANCE');
    buffer.writeln('--------------------------------------------------------');
    buffer.writeln('Driving License No : ${driver.licenseNumber}');
    buffer.writeln('License Expiry Date: ${driver.licenseExpiry}');
    buffer.writeln('Driver Insurance   : ${driver.driverInsurancePolicy}');
    buffer.writeln('Insurance Expiry   : ${driver.driverInsuranceExpiry}');
    buffer.writeln('Completed Trips    : ${driver.completedTripsCount}');
    buffer.writeln('Total KM Driven    : ${driver.totalKilometersDriven} km');
    buffer.writeln('Traffic Violations : ${driver.violationsCount}\n');

    buffer.writeln('3. ASSIGNED VEHICLE DETAILS');
    buffer.writeln('--------------------------------------------------------');
    if (truck != null) {
      buffer.writeln('Vehicle Code      : ${truck.code}');
      buffer.writeln('Vehicle Name      : ${truck.name}');
      buffer.writeln(
          'Model / Status    : ${truck.vehicleModel} (${truck.vehicleStatus})');
      buffer.writeln('Capacity / Axles  : ${truck.capacity} / ${truck.axles}');
      buffer.writeln('Speed Limit       : ${truck.maxSpeed} km/h');
      buffer.writeln('Current Odometer  : ${truck.currentOdometerKm} km');
      buffer.writeln(
          'Next Service Due  : ${truck.nextServiceKm} km (Due in ${truck.kmUntilNextService} km)');
      buffer.writeln(
          'Fitness Expiry    : ${truck.fitnessExpiry} (Doc: ${truck.fitnessNumber})');
      buffer.writeln(
          'Insurance Expiry  : ${truck.insuranceExpiry} (Doc: ${truck.insuranceNumber})');
      buffer.writeln(
          'PUC Expiry        : ${truck.pucExpiry} (Doc: ${truck.pucNumber})');
      buffer.writeln(
          'GPS Telemetry Fix : Lat ${truck.currentLat ?? 0.0}, Lng ${truck.currentLng ?? 0.0}');
      buffer.writeln('GPS Last Updated  : ${_formatDate(truck.lastGpsUpdate)}');
      buffer.writeln(
          'Tracker Status    : ${_isTrackerLive(truck) ? "ONLINE / LIVE" : "STALE / NO FIX"}');
    } else {
      buffer.writeln(
          'No vehicle registered with code "${driver.assignedVehicle}".\n');
    }

    buffer.writeln('\n4. TRIP HISTORY & PERFORMANCE (${trips.length} Trips)');
    buffer.writeln('--------------------------------------------------------');
    for (int i = 0; i < trips.length; i++) {
      final t = trips[i];
      buffer.writeln('[#${i + 1}] Trip No: ${t.effectiveTripNumber}');
      buffer.writeln('     Route: ${t.origin} -> ${t.destination}');
      buffer.writeln(
          '     Status: ${t.status.toUpperCase()} | Customer: ${t.customerName}');
      buffer.writeln('     Updated: ${_formatDate(t.createdAt)}');
    }
    if (trips.isEmpty) {
      buffer.writeln('No trips recorded under this driver profile.');
    }

    buffer.writeln('\n5. ATTENDANCE & SAFETY SUMMARY');
    buffer.writeln('--------------------------------------------------------');
    buffer.writeln('Attendance Logs  : ${attendance.length} entries recorded');
    buffer.writeln('Seatbelt Audits  : ${seatbelt.length} photos evaluated');
    buffer.writeln('Delivery Proofs  : ${proofs.length} ePOD signed receipts');
    buffer
        .writeln('\n========================================================');
    buffer.writeln('           END OF DRIVER COMPLIANCE REPORT');
    buffer.writeln('========================================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Complete Driver & Vehicle Report copied to clipboard! You can paste or save as PDF/text.',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final truck = _assignedTruck;
    final trips = _driverTrips;
    final attendance = _driverAttendance;
    final seatbelt = _driverSeatbelt;
    final proofs = _driverDeliveryProofs;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 750),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                driver.photo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFF93C5FD), width: 1.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: _buildBase64Image(driver.photo),
                        ),
                      )
                    : const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.person_rounded, size: 28),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID / Phone: ${driver.phone.isNotEmpty ? driver.phone : driver.email}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                        'Driving License & Compliance Documents',
                        Icons.badge_outlined),
                    _buildInfoGrid([
                      _InfoItem('License Number (DL)', driver.licenseNumber),
                      _InfoItem('License Expiry', driver.licenseExpiry),
                      _InfoItem(
                          'Insurance Policy', driver.driverInsurancePolicy),
                      _InfoItem(
                          'Insurance Expiry', driver.driverInsuranceExpiry),
                      _InfoItem(
                          'Trips Completed', '${driver.completedTripsCount}'),
                      _InfoItem('Total Distance',
                          '${driver.totalKilometersDriven} km'),
                      _InfoItem(
                          'Traffic Violations', '${driver.violationsCount}'),
                      _InfoItem(
                          'Profile Created', _formatDate(driver.createdAt)),
                    ]),
                    const SizedBox(height: 18),
                    _buildSectionHeader('Assigned Vehicle & Telemetry',
                        Icons.local_shipping_outlined),
                    if (truck != null) ...[
                      _buildInfoGrid([
                        _InfoItem('Vehicle Code', truck.code),
                        _InfoItem('Vehicle Model', truck.name),
                        _InfoItem('Vehicle Type', truck.vehicleModel),
                        _InfoItem('Capacity & Axles',
                            '${truck.capacity} (${truck.axles})'),
                        _InfoItem('Current Odometer',
                            '${truck.currentOdometerKm} km'),
                        _InfoItem('Next Service Due',
                            '${truck.nextServiceKm} km (Due: ${truck.kmUntilNextService} km)'),
                        _InfoItem('Fitness Expiry', truck.fitnessExpiry),
                        _InfoItem('Insurance Expiry', truck.insuranceExpiry),
                        _InfoItem('PUC Expiry', truck.pucExpiry),
                        _InfoItem(
                            'Live Tracker Status',
                            _isTrackerLive(truck)
                                ? 'LIVE / CONNECTED'
                                : 'STALE / NO FIX'),
                        _InfoItem(
                            'Last GPS Fix', _formatDate(truck.lastGpsUpdate)),
                      ]),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          driver.assignedVehicle.isNotEmpty
                              ? 'Assigned vehicle code: "${driver.assignedVehicle}", but vehicle telemetry record not found in system.'
                              : 'No vehicle assigned to this driver yet.',
                          style: const TextStyle(
                              color: Color(0xFFB91C1C), fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildSectionHeader('Operational Summary & Audit',
                        Icons.analytics_outlined),
                    _buildInfoGrid([
                      _InfoItem('Total Assigned Trips', '${trips.length}'),
                      _InfoItem('Attendance Logs', '${attendance.length}'),
                      _InfoItem('Seatbelt Records', '${seatbelt.length}'),
                      _InfoItem('Delivery Proofs (POD)', '${proofs.length}'),
                    ]),
                    if (trips.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Recent Trips:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      ...trips.take(10).map((t) => InkWell(
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => TripDetailReportDialog(
                                  trip: t,
                                  controller: controller,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.route_outlined,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${t.effectiveTripNumber}: ${t.origin} -> ${t.destination} (${t.status.toUpperCase()})',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(t.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.slate),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 16, color: AppColors.slate),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyReport(context),
                  icon: const Icon(Icons.copy_all_outlined,
                      size: 18, color: Color(0xFFDC2626)),
                  label: const Text('Copy Full Report',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: items
            .map((item) => SizedBox(
                  width: 270,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value.isNotEmpty ? item.value : '—',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBase64Image(String rawBase64) {
    try {
      final sanitized =
          rawBase64.contains(',') ? rawBase64.split(',').last : rawBase64;
      final bytes = base64Decode(sanitized);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return const Icon(Icons.person_rounded,
          size: 24, color: AppColors.primary);
    }
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}
