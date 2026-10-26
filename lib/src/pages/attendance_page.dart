import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/app_localization_service.dart';
import '../theme/app_theme.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    required this.controller,
    super.key,
  });

  final PlannerController controller;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String _selectedDateFilter = 'all'; // today, week, month, all
  final String _selectedDriverFilter = 'all';
  String _selectedStatusFilter =
      'all'; // all, present, late, half_day, absent, on_leave
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AttendanceRecord> _filterRecords(List<AttendanceRecord> records) {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final query = _searchController.text.trim().toLowerCase();

    return records.where((record) {
      // Date filter
      if (_selectedDateFilter == 'today') {
        if (!record.date.startsWith(todayStr)) return false;
      } else if (_selectedDateFilter == 'week') {
        final recDate = DateTime.tryParse(record.date);
        if (recDate != null && now.difference(recDate).inDays > 7) return false;
      } else if (_selectedDateFilter == 'month') {
        final recDate = DateTime.tryParse(record.date);
        if (recDate != null && now.difference(recDate).inDays > 30) {
          return false;
        }
      }

      // Driver filter
      if (_selectedDriverFilter != 'all' &&
          record.driverId != _selectedDriverFilter) {
        return false;
      }

      // Status filter
      if (_selectedStatusFilter != 'all' &&
          record.status != _selectedStatusFilter) {
        return false;
      }

      // Search query
      if (query.isNotEmpty) {
        final match = record.driverName.toLowerCase().contains(query) ||
            record.driverId.toLowerCase().contains(query) ||
            record.notes.toLowerCase().contains(query);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _openRecordAttendanceDialog([AttendanceRecord? existing]) async {
    final drivers = widget.controller.drivers;
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No drivers available. Please register a driver first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String selectedDriverId =
        existing?.driverId ?? (drivers.isNotEmpty ? drivers.first.name : '');
    String selectedDriverName =
        existing?.driverName ?? (drivers.isNotEmpty ? drivers.first.name : '');
    String date =
        existing?.date ?? DateTime.now().toIso8601String().substring(0, 10);
    String startTime = existing?.startTime ?? DateTime.now().toIso8601String();
    String endTime = existing?.endTime ?? '';
    String status = existing?.status ?? 'present';
    final notesController = TextEditingController(text: existing?.notes ?? '');

    final result = await showDialog<AttendanceRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const AppIconBadge(icon: Icons.how_to_reg_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  existing == null ? 'Record Attendance' : 'Edit Attendance',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'Select Driver',
                        isDense: true,
                      ),
                      items: drivers.map((d) {
                        return DropdownMenuItem<String>(
                          value: d.name,
                          child: Text(
                            '${d.name} (${d.phone.isNotEmpty ? d.phone : "No Phone"})',
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'sans-serif'),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedDriverId = val;
                            selectedDriverName = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: date,
                      decoration: const InputDecoration(
                        labelText: 'Date (YYYY-MM-DD)',
                        isDense: true,
                        suffixIcon:
                            Icon(Icons.calendar_today_outlined, size: 16),
                      ),
                      onChanged: (val) => date = val.trim(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Attendance Status',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'present', child: Text('Present')),
                        DropdownMenuItem(value: 'late', child: Text('Late')),
                        DropdownMenuItem(
                            value: 'half_day', child: Text('Half Day')),
                        DropdownMenuItem(
                            value: 'absent', child: Text('Absent')),
                        DropdownMenuItem(
                            value: 'on_leave', child: Text('On Leave')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: startTime.length >= 16
                                ? startTime.substring(11, 16)
                                : '08:00',
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              isDense: true,
                              hintText: 'HH:MM',
                            ),
                            onChanged: (val) {
                              startTime = '$date T${val.trim()}:00';
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: endTime.length >= 16
                                ? endTime.substring(11, 16)
                                : '',
                            decoration: const InputDecoration(
                              labelText: 'End Time (Optional)',
                              isDense: true,
                              hintText: 'HH:MM',
                            ),
                            onChanged: (val) {
                              if (val.trim().isNotEmpty) {
                                endTime = '$date T${val.trim()}:00';
                              } else {
                                endTime = '';
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Duty Notes / Location',
                        isDense: true,
                        hintText: 'Depot check-in, remarks...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final record = AttendanceRecord(
                    id: existing?.id ??
                        'ATT-${DateTime.now().millisecondsSinceEpoch}',
                    driverId: selectedDriverId,
                    driverName: selectedDriverName,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    status: status,
                    totalWorkingHours:
                        AttendanceRecord.calculateHours(startTime, endTime),
                    notes: notesController.text.trim(),
                    createdAt:
                        existing?.createdAt ?? DateTime.now().toIso8601String(),
                  );
                  Navigator.pop(ctx, record);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Record'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await widget.controller.addOrUpdateAttendance(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance recorded for ${result.driverName}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _punchOutDriver(AttendanceRecord record) async {
    final now = DateTime.now();
    final endTimeStr = now.toIso8601String();
    final hours = AttendanceRecord.calculateHours(record.startTime, endTimeStr);
    final updated = record.copyWith(
      endTime: endTimeStr,
      totalWorkingHours: hours,
    );
    await widget.controller.addOrUpdateAttendance(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${record.driverName} punched out. Total duty: ${hours.toStringAsFixed(1)} hours'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allRecords = widget.controller.attendanceRecords;
        final filteredRecords = _filterRecords(allRecords);

        final totalDrivers = widget.controller.drivers.length;
        final presentCount =
            allRecords.where((a) => a.status == 'present').length;
        final onDutyCount = allRecords.where((a) => a.isOnDuty).length;
        final lateCount = allRecords
            .where((a) => a.status == 'late' || a.status == 'half_day')
            .length;
        final absentCount = allRecords
            .where((a) => a.status == 'absent' || a.status == 'on_leave')
            .length;

        return ColoredBox(
          color: AppColors.canvas,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final padding = isMobile ? 12.0 : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    padding, padding, padding, padding + 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isMobile),
                        const SizedBox(height: 16),
                        _buildKpiSummary(
                          totalDrivers: totalDrivers,
                          presentCount: presentCount,
                          onDutyCount: onDutyCount,
                          lateCount: lateCount,
                          absentCount: absentCount,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildFilterBar(isMobile),
                        const SizedBox(height: 16),
                        if (filteredRecords.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredRecords.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final record = filteredRecords[index];
                              return _buildAttendanceCard(record);
                            },
                          ),
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

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const AppIconBadge(
              icon: Icons.how_to_reg_outlined, size: 24, padding: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizationService.instance.tr('attendance'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Driver presence, punch times, and active duty hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _openRecordAttendanceDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              isMobile ? 'Punch' : 'Record Attendance',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: 'sans-serif',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary({
    required int totalDrivers,
    required int presentCount,
    required int onDutyCount,
    required int lateCount,
    required int absentCount,
    required bool isMobile,
  }) {
    final chips = [
      _AttendanceMetric(
        label: 'Drivers Registered',
        value: '$totalDrivers',
        icon: Icons.people_outline_rounded,
        color: AppColors.primary,
      ),
      _AttendanceMetric(
        label: 'Present Today',
        value: '$presentCount',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF16A34A),
      ),
      _AttendanceMetric(
        label: 'On Active Duty',
        value: '$onDutyCount',
        icon: Icons.timelapse_rounded,
        color: const Color(0xFF0284C7),
      ),
      _AttendanceMetric(
        label: 'Late / Half Day',
        value: '$lateCount',
        icon: Icons.alarm_outlined,
        color: const Color(0xFFD97706),
      ),
      _AttendanceMetric(
        label: 'Absent / Leave',
        value: '$absentCount',
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFDC2626),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600
            ? 2
            : constraints.maxWidth < 950
                ? 3
                : 5;
        final itemWidth =
            (constraints.maxWidth - (crossCount - 1) * 10) / crossCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: chips.map((chip) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: chip.color.withValues(alpha: 0.12),
                      foregroundColor: chip.color,
                      child: Icon(chip.icon, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chip.value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          Text(
                            chip.label,
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
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 220,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search driver or remarks...',
                prefixIcon:
                    Icon(Icons.search, size: 16, color: AppColors.slate),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          DropdownButton<String>(
            value: _selectedDateFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Dates')),
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: 'week', child: Text('Past 7 Days')),
              DropdownMenuItem(value: 'month', child: Text('This Month')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedDateFilter = val);
            },
          ),
          DropdownButton<String>(
            value: _selectedStatusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'present', child: Text('Present')),
              DropdownMenuItem(value: 'late', child: Text('Late')),
              DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
              DropdownMenuItem(value: 'absent', child: Text('Absent')),
              DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatusFilter = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.calendar_today_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 10),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontFamily: 'sans-serif',
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Use the "Record Attendance" button above to punch in drivers.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              fontFamily: 'sans-serif',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final statusColor = switch (record.status) {
      'present' => const Color(0xFF16A34A),
      'late' => const Color(0xFFD97706),
      'half_day' => const Color(0xFFD97706),
      'absent' => const Color(0xFFDC2626),
      'on_leave' => const Color(0xFF64748B),
      _ => AppColors.slate,
    };

    final statusBg = statusColor.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(icon: Icons.person_outline_rounded, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.driverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.status.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                    if (record.isOnDuty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                                radius: 3, backgroundColor: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text(
                              'ON DUTY',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildDetailItem(
                        Icons.calendar_today_outlined, 'Date: ${record.date}'),
                    _buildDetailItem(
                      Icons.schedule_outlined,
                      'In: ${record.startTime.length >= 16 ? record.startTime.substring(11, 16) : record.startTime}',
                    ),
                    _buildDetailItem(
                      Icons.alarm_off_outlined,
                      'Out: ${record.endTime.isNotEmpty ? (record.endTime.length >= 16 ? record.endTime.substring(11, 16) : record.endTime) : "Active"}',
                    ),
                    _buildDetailItem(
                      Icons.timelapse_outlined,
                      'Hours: ${record.totalWorkingHours > 0 ? record.totalWorkingHours.toStringAsFixed(1) : (record.isOnDuty ? "Tracking..." : "0.0")} hrs',
                    ),
                  ],
                ),
                if (record.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Notes: ${record.notes}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.slate,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (record.isOnDuty) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _punchOutDriver(record),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text(
                'Punch Out',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.slate),
            tooltip: 'Edit Record',
            onPressed: () => _openRecordAttendanceDialog(record),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.slate),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
            fontFamily: 'sans-serif',
          ),
        ),
      ],
    );
  }
}

class _AttendanceMetric {
  const _AttendanceMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
