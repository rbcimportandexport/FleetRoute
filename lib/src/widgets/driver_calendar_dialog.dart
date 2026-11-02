import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';
import 'trip_detail_report_dialog.dart';

/// Interactive Driver Daily Activity & Cleaning Calendar Dialog
/// Lets admin and drivers click any date/day to inspect everything that occurred on that date:
/// - Trips started/completed (with distance, times & detail popup)
/// - Sunday & Daily Vehicle Cleaning photos (Before/After & angles)
/// - Seatbelt verification photos & status
/// - Attendance punch-in / punch-out duty hours
/// - Overspeeding, safety, memo/challan alerts
/// - Option to add notes or manual activity logs for that date
class DriverCalendarDialog extends StatefulWidget {
  const DriverCalendarDialog({
    required this.driverId,
    required this.driverName,
    required this.controller,
    super.key,
  });

  final String driverId;
  final String driverName;
  final PlannerController controller;

  static Future<void> show(
    BuildContext context, {
    required String driverId,
    required String driverName,
    required PlannerController controller,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DriverCalendarDialog(
        driverId: driverId,
        driverName: driverName,
        controller: controller,
      ),
    );
  }

  @override
  State<DriverCalendarDialog> createState() => _DriverCalendarDialogState();
}

class _DriverCalendarDialogState extends State<DriverCalendarDialog> {
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
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final note = textController.text.trim();
              if (note.isEmpty) return;
              Navigator.pop(ctx);

              final driver = widget.controller.currentDriver;
              final vehicle = driver?.assignedVehicle.trim().isNotEmpty == true
                  ? driver!.assignedVehicle.trim().toUpperCase()
                  : 'UNASSIGNED';

              // Record note in activity log & seatbelt records audit note
              await widget.controller.submitDriverPhotoRecord(
                category: 'Daily Log Note',
                photoBase64: '',
                vehicleNumber: vehicle,
                notes: 'Note [${_selectedDate.day}/${_selectedDate.month}]: $note',
              );

              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Note safaltapoorvak jod diya gaya!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('SAVE NOTE'),
          ),
        ],
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String base64Str, String title) {
    Uint8List? bytes;
    try {
      String clean = base64Str;
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            if (bytes != null)
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Image.memory(
                    bytes,
                    height: 380,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: Text('Image data available nahi hai.')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = widget.controller.getDriverTrips(
      driverName: widget.driverName,
      driverId: widget.driverId,
    );
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.calendar_month_rounded,
                    size: 22,
                    padding: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.driverName.isNotEmpty ? widget.driverName : "Driver"} - Activity Calendar',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kisi bhi din par click karke Trips, Cleaning, Speed & Activity dekhein',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
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
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),

              // Calendar Month Bar
              _buildMonthNavigator(),
              const SizedBox(height: 8),

              // Calendar Grid (7 columns: Mon..Sun)
              _buildCalendarGrid(allTrips, allRecords, allAttendance, allAlerts),
              const SizedBox(height: 10),

              // Selected Date Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year} ($totalItemsToday Recorded Events)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showAddManualNoteDialog(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Add Note',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Detailed events list for selected date
              Expanded(
                child: totalItemsToday == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 42, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} ko koi activity record nahi hui.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () => _showAddManualNoteDialog(context),
                              icon: const Icon(Icons.add_comment_rounded,
                                  size: 15),
                              label: const Text('Is din ka note add karein'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          // 1. Vehicle Cleaning Section
                          if (cleaningPhotos.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.local_car_wash_rounded,
                              title:
                                  'Sunday / Vehicle Cleaning Photos (${cleaningPhotos.length})',
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: cleaningPhotos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final p = cleaningPhotos[i];
                                  return _buildPhotoThumbnailCard(p);
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 2. Trips Section
                          if (tripsOnSelectedDate.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.local_shipping_rounded,
                              title:
                                  'Trips (${tripsOnSelectedDate.length})',
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(height: 6),
                            ...tripsOnSelectedDate.map(_buildTripCard),
                            const SizedBox(height: 14),
                          ],

                          // 3. Attendance / Duty Section
                          if (attendanceOnSelectedDate.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.badge_rounded,
                              title:
                                  'Duty & Attendance (${attendanceOnSelectedDate.length})',
                              color: const Color(0xFF0D9488),
                            ),
                            const SizedBox(height: 6),
                            ...attendanceOnSelectedDate.map(_buildAttendanceCard),
                            const SizedBox(height: 14),
                          ],

                          // 4. Safety, Speed & Memo Alerts
                          if (alertsOnSelectedDate.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.speed_rounded,
                              title:
                                  'Safety, Speed & Memo Alerts (${alertsOnSelectedDate.length})',
                              color: const Color(0xFFEA580C),
                            ),
                            const SizedBox(height: 6),
                            ...alertsOnSelectedDate.map(_buildAlertCard),
                            const SizedBox(height: 14),
                          ],

                          // 5. Other Documents & Photos
                          if (otherPhotos.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.camera_alt_rounded,
                              title:
                                  'Other Documents & Seatbelt Photos (${otherPhotos.length})',
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: otherPhotos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final p = otherPhotos[i];
                                  return _buildPhotoThumbnailCard(p);
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
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
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Previous Month',
        ),
        Text(
          '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            fontFamily: 'sans-serif',
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(
                  _focusedMonth.year, _focusedMonth.month + 1, 1);
            });
          },
          icon: const Icon(Icons.chevron_right_rounded),
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
    const weekHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    // DateTime weekday: 1 = Mon .. 7 = Sun
    final startingWeekday = firstDayOfMonth.weekday; // 1 to 7

    final totalGridCells = ((startingWeekday - 1) + daysInMonth <= 35) ? 35 : 42;

    return Column(
      children: [
        // Days of week header
        Row(
          children: weekHeaders.map((day) {
            final isSunday = day == 'S' && weekHeaders.lastIndexOf(day) == 6;
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSunday ? Colors.red.shade700 : AppColors.slate,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Grid cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
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
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isToday
                          ? AppColors.primarySoft
                          : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : (isToday
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0)),
                    width: isSelected || isToday ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isSunday
                                ? Colors.red.shade700
                                : AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Multi-event indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasCleaning)
                          _buildDot(
                              isSelected ? Colors.white : Colors.green.shade600),
                        if (hasTrips)
                          _buildDot(
                              isSelected ? Colors.white : Colors.blue.shade600),
                        if (hasAlerts)
                          _buildDot(
                              isSelected ? Colors.white : Colors.orange.shade700),
                        if (!hasCleaning && !hasTrips && !hasAlerts && (hasDuty || hasOtherPhotos))
                          _buildDot(
                              isSelected ? Colors.white : Colors.teal.shade600),
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'sans-serif',
          ),
        ),
      ],
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

  Widget _buildTripCard(TripRecord trip) {
    final distance = trip.actualDistanceKm > 0
        ? trip.actualDistanceKm
        : trip.plannedDistanceKm;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: trip.status == 'completed'
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trip.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: trip.status == 'completed'
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
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
            child: const Text('VIEW', style: TextStyle(fontSize: 11)),
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
        children: [
          Icon(
            isSpeed ? Icons.speed_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: isSpeed ? Colors.orange.shade800 : Colors.red.shade700,
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
                    color: isSpeed ? Colors.orange.shade900 : Colors.red.shade900,
                  ),
                ),
                Text(
                  alert.details,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
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
