import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';
import '../widgets/trip_detail_report_dialog.dart';
import '../widgets/trip_playback_dialog.dart';

/// Full Dedicated Screen for Driver Activity & Operations Calendar
class DriverCalendarScreen extends StatefulWidget {
  const DriverCalendarScreen({
    required this.driverId,
    required this.driverName,
    required this.controller,
    super.key,
  });

  final String driverId;
  final String driverName;
  final PlannerController controller;

  static Future<void> open(
    BuildContext context, {
    required String driverId,
    required String driverName,
    required PlannerController controller,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverCalendarScreen(
          driverId: driverId,
          driverName: driverName,
          controller: controller,
        ),
      ),
    );
  }

  @override
  State<DriverCalendarScreen> createState() => _DriverCalendarScreenState();
}

class _DriverCalendarScreenState extends State<DriverCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  List<TripRecord> _getTripsForDate(DateTime date, List<TripRecord> allTrips) {
    return allTrips.where((t) {
      DateTime? tripDate = _parseDate(t.departureDateTime);
      tripDate ??= _parseDate(t.loadingDateTime);
      tripDate ??= _parseDate(t.createdAt);
      if (tripDate == null) return false;
      return _isSameDay(tripDate, date);
    }).toList();
  }

  List<SeatbeltRecord> _getPhotosForDate(
      DateTime date, List<SeatbeltRecord> allRecords) {
    final targetDriver = widget.driverName.trim().toLowerCase();
    final targetId = widget.driverId.trim().toLowerCase();

    return allRecords.where((r) {
      if (!_isSameDay(r.timestamp, date)) return false;
      final rName = r.driverName.trim().toLowerCase();
      final rId = r.driverId.trim().toLowerCase();
      if (targetDriver.isEmpty && targetId.isEmpty) return true;
      return rName == targetDriver ||
          rId == targetId ||
          rName.contains(targetDriver) ||
          targetDriver.contains(rName);
    }).toList();
  }

  List<AttendanceRecord> _getAttendanceForDate(
      DateTime date, List<AttendanceRecord> allAttendance) {
    final targetDriver = widget.driverName.trim().toLowerCase();
    final targetId = widget.driverId.trim().toLowerCase();

    return allAttendance.where((a) {
      final aDate = _parseDate(a.startTime) ?? _parseDate(a.date);
      if (aDate == null || !_isSameDay(aDate, date)) return false;
      final aName = a.driverName.trim().toLowerCase();
      final aId = a.driverId.trim().toLowerCase();
      if (targetDriver.isEmpty && targetId.isEmpty) return true;
      return aName == targetDriver || aId == targetId;
    }).toList();
  }

  List<OperationsAlert> _getAlertsForDate(
      DateTime date, List<OperationsAlert> allAlerts) {
    final targetDriver = widget.driverName.trim().toLowerCase();
    final targetVehicle =
        widget.controller.currentDriver?.assignedVehicle.trim().toLowerCase() ??
            '';

    return allAlerts.where((a) {
      final aDate = _parseDate(a.createdAt);
      if (aDate == null || !_isSameDay(aDate, date)) return false;
      final text = '${a.title} ${a.details} ${a.vehicleNumber}'.toLowerCase();
      if (targetDriver.isNotEmpty && text.contains(targetDriver)) return true;
      if (targetVehicle.isNotEmpty && text.contains(targetVehicle)) return true;
      return a.category.toLowerCase().contains('speed') ||
          a.category.toLowerCase().contains('cleaning');
    }).toList();
  }

  void _showAddManualNoteDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_add_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} Ka Note Likhein',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Gaadi servicing par thi / Diesel 50L dalwaya / Tyre change kiya',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final noteText = textController.text.trim();
              if (noteText.isNotEmpty) {
                final newAlert = OperationsAlert(
                  id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                  category: 'Manual Note',
                  title: 'Driver Log: ${widget.driverName}',
                  details: noteText,
                  createdAt: _selectedDate.toIso8601String(),
                  severity: 'info',
                  vehicleNumber: widget.controller.currentDriver?.assignedVehicle ?? '',
                );
                widget.controller.alerts.insert(0, newAlert);
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String rawPhoto, String title) {
    Uint8List? bytes;
    try {
      String clean = rawPhoto;
      if (clean.contains(',')) clean = clean.split(',').last;
      bytes = base64Decode(clean.trim());
    } catch (_) {}

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(fontSize: 14)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: const CloseButton(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Image not available'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = widget.controller.trips;
    final allRecords = widget.controller.seatbeltRecords;
    final allAttendance = widget.controller.attendanceRecords;
    final allAlerts = widget.controller.alerts;

    final tripsOnSelectedDate = _getTripsForDate(_selectedDate, allTrips);
    final photosOnSelectedDate = _getPhotosForDate(_selectedDate, allRecords);
    final cleaningPhotos = photosOnSelectedDate
        .where((r) => r.notes.toLowerCase().contains('cleaning'))
        .toList();
    final otherPhotos = photosOnSelectedDate
        .where((r) => !r.notes.toLowerCase().contains('cleaning'))
        .toList();
    final attendanceOnSelectedDate =
        _getAttendanceForDate(_selectedDate, allAttendance);
    final alertsOnSelectedDate = _getAlertsForDate(_selectedDate, allAlerts);

    final totalItemsToday = tripsOnSelectedDate.length +
        cleaningPhotos.length +
        otherPhotos.length +
        attendanceOnSelectedDate.length +
        alertsOnSelectedDate.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 clean background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.driverName.isNotEmpty ? widget.driverName : "Driver"} - Activity Calendar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Trips · Cleaning · Speeds · Duty · Safety Logs',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Go to Today',
            icon: const Icon(Icons.today_rounded, color: AppColors.primary),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedMonth = DateTime(now.year, now.month, 1);
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Calendar View Card (Month Navigation + Grid)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildMonthNavigator(),
                    const SizedBox(height: 10),
                    _buildCalendarGrid(allTrips, allRecords, allAttendance, allAlerts),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Selected Date Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_available_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            '$totalItemsToday Recorded Events for this date',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddManualNoteDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Note'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Events List for Selected Date
              if (totalItemsToday == 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} ko koi activity record nahi hui.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showAddManualNoteDialog(context),
                          icon: const Icon(Icons.add_comment_rounded, size: 16),
                          label: const Text('Is din ka note add karein'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Vehicle Cleaning Section
                    if (cleaningPhotos.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.local_car_wash_rounded,
                        title:
                            'Sunday / Vehicle Cleaning Photos (${cleaningPhotos.length})',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: cleaningPhotos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final p = cleaningPhotos[i];
                            return _buildPhotoThumbnailCard(p);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. Trips Section
                    if (tripsOnSelectedDate.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.local_shipping_rounded,
                        title: 'Trips (${tripsOnSelectedDate.length})',
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 8),
                      ...tripsOnSelectedDate.map(_buildTripCard),
                      const SizedBox(height: 16),
                    ],

                    // 3. Attendance / Duty Section
                    if (attendanceOnSelectedDate.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.badge_rounded,
                        title:
                            'Duty & Attendance (${attendanceOnSelectedDate.length})',
                        color: const Color(0xFF0D9488),
                      ),
                      const SizedBox(height: 8),
                      ...attendanceOnSelectedDate.map(_buildAttendanceCard),
                      const SizedBox(height: 16),
                    ],

                    // 4. Safety, Speed & Memo Alerts
                    if (alertsOnSelectedDate.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.speed_rounded,
                        title:
                            'Safety, Speed & Memo Alerts (${alertsOnSelectedDate.length})',
                        color: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 8),
                      ...alertsOnSelectedDate.map(_buildAlertCard),
                      const SizedBox(height: 16),
                    ],

                    // 5. Other Documents & Photos
                    if (otherPhotos.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.camera_alt_rounded,
                        title:
                            'Other Documents & Seatbelt Photos (${otherPhotos.length})',
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: otherPhotos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final p = otherPhotos[i];
                            return _buildPhotoThumbnailCard(p);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                  _focusedMonth.year, _focusedMonth.month - 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
          tooltip: 'Previous Month',
        ),
        Text(
          '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                  _focusedMonth.year, _focusedMonth.month + 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
          tooltip: 'Next Month',
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
    List<TripRecord> allTrips,
    List<SeatbeltRecord> allRecords,
    List<AttendanceRecord> allAttendance,
    List<OperationsAlert> allAlerts,
  ) {
    const dayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    final totalGridCells = ((startingWeekday - 1 + daysInMonth) <= 35) ? 35 : 42;

    return Column(
      children: [
        // Days of week header row
        Row(
          children: dayHeaders.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isSunday = idx == 6;
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSunday ? Colors.red.shade700 : AppColors.slate,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Grid cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.15,
          ),
          itemCount: totalGridCells,
          itemBuilder: (context, index) {
            final dayOffset = index - (startingWeekday - 1);
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const SizedBox.shrink();
            }

            final dayNumber = dayOffset + 1;
            final cellDate =
                DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
            final isSelected = _isSameDay(cellDate, _selectedDate);
            final isToday = _isSameDay(cellDate, DateTime.now());
            final isSunday = cellDate.weekday == DateTime.sunday;

            // Check what data exists on this day
            final hasTrips = _getTripsForDate(cellDate, allTrips).isNotEmpty;
            final photos = _getPhotosForDate(cellDate, allRecords);
            final hasCleaning =
                photos.any((p) => p.notes.toLowerCase().contains('cleaning'));
            final hasOtherPhotos =
                photos.any((p) => !p.notes.toLowerCase().contains('cleaning'));
            final hasDuty =
                _getAttendanceForDate(cellDate, allAttendance).isNotEmpty;
            final hasAlerts =
                _getAlertsForDate(cellDate, allAlerts).isNotEmpty;

            return InkWell(
              onTap: () {
                setState(() => _selectedDate = cellDate);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isToday
                          ? AppColors.primarySoft
                          : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : (isToday
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0)),
                    width: isSelected || isToday ? 1.6 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : (isSunday
                                ? Colors.red.shade700
                                : AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasTrips)
                          _buildDot(
                              isSelected ? Colors.white : const Color(0xFF2563EB)),
                        if (hasCleaning)
                          _buildDot(
                              isSelected ? Colors.white : const Color(0xFF16A34A)),
                        if (hasAlerts)
                          _buildDot(
                              isSelected ? Colors.white : const Color(0xFFDC2626)),
                        if (hasDuty && !hasTrips && !hasCleaning && !hasAlerts)
                          _buildDot(
                              isSelected ? Colors.white : const Color(0xFF0D9488)),
                        if (hasOtherPhotos && !hasCleaning)
                          _buildDot(
                              isSelected ? Colors.white : const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(TripRecord trip) {
    final distance = trip.actualDistanceKm > 0
        ? trip.actualDistanceKm
        : trip.plannedDistanceKm;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car_rounded,
                size: 20, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trip.assignedVehicle.isNotEmpty
                          ? trip.assignedVehicle
                          : 'Vehicle Trip',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trip.status.toLowerCase() == 'completed'
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trip.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: trip.status.toLowerCase() == 'completed'
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.origin} → ${trip.destination}',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Distance: ${distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Live Video Playback',
            icon: const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.primary, size: 24),
            onPressed: () {
              TripPlaybackDialog.show(
                context,
                trip: trip,
                controller: widget.controller,
              );
            },
          ),
          TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => TripDetailReportDialog(
                  trip: trip,
                  controller: widget.controller,
                ),
              );
            },
            child: const Text('VIEW',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857))),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final startDt = _parseDate(record.startTime);
    final endDt = _parseDate(record.endTime);
    final punchIn = startDt != null
        ? '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}'
        : record.startTime;
    final punchOut = endDt != null
        ? '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}'
        : (record.endTime.isNotEmpty ? record.endTime : 'Still On Duty');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              size: 16, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Duty Time: $punchIn → $punchOut',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF134E4A),
              ),
            ),
          ),
          Text(
            record.isOnDuty ? 'ACTIVE' : 'COMPLETED',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: record.isOnDuty ? Colors.green.shade700 : AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(OperationsAlert alert) {
    final isSpeed = alert.category.toLowerCase().contains('speed');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSpeed ? const Color(0xFFFFF7ED) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSpeed ? const Color(0xFFFFEDD5) : const Color(0xFFFEE2E2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSpeed ? Icons.speed_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: isSpeed ? const Color(0xFFEA580C) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isSpeed ? const Color(0xFF9A3412) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  alert.details,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.navy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnailCard(SeatbeltRecord record) {
    Uint8List? bytes;
    try {
      String clean = record.photoBase64;
      if (clean.contains(',')) clean = clean.split(',').last;
      bytes = base64Decode(clean.trim());
    } catch (_) {}

    return GestureDetector(
      onTap: () => _showFullImageDialog(
          context, record.photoBase64, record.notes.isNotEmpty ? record.notes : 'Photo'),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(9)),
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.broken_image_rounded, size: 24),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                record.notes.isNotEmpty ? record.notes : 'Photo',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }
}
