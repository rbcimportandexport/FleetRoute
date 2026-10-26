import 'dart:convert';
import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../pages/seatbelt_gallery_page.dart';
import '../theme/app_theme.dart';
import 'seatbelt_verification_dialog.dart';

class SeatbeltRecordsDialog extends StatefulWidget {
  const SeatbeltRecordsDialog({
    required this.controller,
    this.initialDriverEmail,
    super.key,
  });

  final PlannerController controller;
  final String? initialDriverEmail;

  static Future<void> show(
    BuildContext context, {
    required PlannerController controller,
    String? initialDriverEmail,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SeatbeltGalleryPage(
          controller: controller,
          initialDriverEmail: initialDriverEmail,
        ),
      ),
    );
  }

  @override
  State<SeatbeltRecordsDialog> createState() => _SeatbeltRecordsDialogState();
}

class _SeatbeltRecordsDialogState extends State<SeatbeltRecordsDialog> {
  late String _viewMode; // 'all' or 'driver'
  String? _selectedDriverEmail;
  String _filterStatus = 'all'; // 'all', 'verified', 'rejected'
  final String _searchQuery = '';

  bool get _canUseAdminView => widget.controller.isLoggedIn
      ? widget.controller.loggedInRole == 'admin'
      : widget.controller.isAdmin;

  @override
  void initState() {
    super.initState();
    if (widget.initialDriverEmail != null &&
        widget.initialDriverEmail!.isNotEmpty) {
      _viewMode = 'driver';
      _selectedDriverEmail = widget.initialDriverEmail;
    } else {
      // Default to 'all' so records are immediately visible without empty driver mismatch
      _viewMode = 'all';
      _selectedDriverEmail = widget.controller.loggedInEmail ??
          widget.controller.activeDriverEmail;
    }
  }

  String _formatDateTime(DateTime dt) {
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
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}, $hour:$minute $ampm';
  }

  List<SeatbeltRecord> _getRecords() {
    var list = widget.controller.seatbeltRecords;

    if (_viewMode == 'driver') {
      final target = (_selectedDriverEmail ?? '').trim().toLowerCase();
      if (target.isNotEmpty) {
        final filtered = list.where((r) {
          final rEmail = r.driverId.trim().toLowerCase();
          final rName = r.driverName.trim().toLowerCase();
          return rEmail == target || rName == target;
        }).toList();
        // A selected driver with no records must show an empty state. Falling
        // back to the fleet list leaks another driver's photos into this view.
        list = filtered;
      }
    }

    // Filter by approval status
    if (_filterStatus == 'verified') {
      list = list.where((r) => r.isApproved).toList();
    } else if (_filterStatus == 'rejected') {
      list = list.where((r) => !r.isApproved).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((r) {
        return r.driverName.toLowerCase().contains(q) ||
            r.driverId.toLowerCase().contains(q) ||
            r.vehicleNumber.toLowerCase().contains(q) ||
            r.location.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  void _showFullPhoto(SeatbeltRecord record) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with status indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: record.isApproved
                        ? const Color(0xFF065F46)
                        : const Color(0xFF991B1B),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        record.isApproved
                            ? Icons.verified_user_rounded
                            : Icons.gpp_bad_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.driverName.isNotEmpty
                                  ? record.driverName
                                  : 'Driver Verification Photo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDateTime(record.timestamp)}${record.vehicleNumber.isNotEmpty ? ' • ${record.vehicleNumber}' : ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Main Photo Display with zoom feel
                Expanded(
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.5,
                      child: _buildPhotoWidget(
                        record.photoBase64,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Bottom Info Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E293B),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: record.isApproved
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.2)
                                  : const Color(0xFFEF4444)
                                      .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: record.isApproved
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  record.isApproved
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: record.isApproved
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFF87171),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  record.isApproved
                                      ? 'Seatbelt Verified (Approved)'
                                      : 'No Seatbelt (Rejected / Violation)',
                                  style: TextStyle(
                                    color: record.isApproved
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFF87171),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (record.vehicleNumber.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping_rounded,
                                      size: 13, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    record.vehicleNumber,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (record.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            record.notes,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(
    String photoBase64, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    try {
      String clean = photoBase64;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      final bytes = base64Decode(clean.trim());
      if (bytes.isEmpty) {
        return const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        );
      }
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      );
    } catch (_) {
      return const Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final records = _getRecords();
        final totalRecords = widget.controller.seatbeltRecords.length;
        final approvedCount =
            widget.controller.seatbeltRecords.where((r) => r.isApproved).length;
        final rejectedCount = totalRecords - approvedCount;
        final drivers = widget.controller.drivers;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (Modern Gradient Bar)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                const Color(0xFF60A5FA).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF60A5FA),
                          size: 22,
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
                                  'Seatbelt Verification Records',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$totalRecords',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Pre-trip cabin inspection photos with date, time & AI verification',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Metrics & Quick Stats Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      _buildStatChip(
                        label: 'Total Logs',
                        count: '$totalRecords',
                        color: const Color(0xFF2563EB),
                        icon: Icons.photo_library_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        label: 'Verified',
                        count: '$approvedCount',
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        label: 'Violations',
                        count: '$rejectedCount',
                        color: const Color(0xFFEF4444),
                        icon: Icons.warning_rounded,
                      ),
                      const Spacer(),
                      // Add Photo / Scan Seatbelt button
                      FilledButton.icon(
                        onPressed: () async {
                          await SeatbeltVerificationDialog.show(
                            context,
                            controller: widget.controller,
                          );
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 14),
                        label: const Text('Capture Photo',
                            style: TextStyle(fontSize: 11.5)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls: Mode Toggle & Status Filter Chips
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Mode toggle (All Fleet vs My Driver)
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'all',
                                label: Text('All Fleet Photos',
                                    style: TextStyle(fontSize: 11)),
                                icon: Icon(Icons.view_agenda_rounded, size: 13),
                              ),
                              ButtonSegment(
                                value: 'driver',
                                label: Text('Driver Account',
                                    style: TextStyle(fontSize: 11)),
                                icon: Icon(Icons.person_rounded, size: 13),
                              ),
                            ],
                            selected: {_viewMode},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) {
                                setState(() => _viewMode = set.first);
                              }
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const Spacer(),
                          // Clear All button if records exist
                          if (records.isNotEmpty)
                            TextButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Clear records?'),
                                    content: const Text(
                                        'All seatbelt verification photo logs will be removed.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Clear All'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  if (!mounted) return;
                                  await widget.controller
                                      .clearSeatbeltRecords();
                                }
                              },
                              icon: const Icon(Icons.delete_sweep_outlined,
                                  size: 15, color: Colors.red),
                              label: const Text('Clear All',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 11)),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filter chips row: All, Verified, Rejected
                      Row(
                        children: [
                          _buildFilterChip(
                            label: 'All',
                            statusKey: 'all',
                            count: totalRecords,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Verified Only',
                            statusKey: 'verified',
                            count: approvedCount,
                            activeColor: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Violations Only',
                            statusKey: 'rejected',
                            count: rejectedCount,
                            activeColor: const Color(0xFFEF4444),
                          ),
                        ],
                      ),

                      // Driver Picker dropdown if in Driver View and admin
                      if (_viewMode == 'driver' &&
                          (_canUseAdminView || drivers.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_circle_outlined,
                                  color: Color(0xFF2563EB), size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'Driver Filter:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (drivers.isNotEmpty)
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: drivers.any((d) =>
                                              d.email == _selectedDriverEmail)
                                          ? _selectedDriverEmail
                                          : null,
                                      hint: const Text('All Drivers',
                                          style: TextStyle(fontSize: 11)),
                                      isDense: true,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                      items: drivers
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d.email,
                                              child: Text(
                                                '${d.name} (${d.phone.isNotEmpty ? d.phone : d.email})',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDriverEmail = val;
                                        });
                                      },
                                    ),
                                  ),
                                )
                              else
                                const Expanded(
                                  child: Text(
                                    'Showing current driver profile records',
                                    style: TextStyle(
                                        fontSize: 11, color: Color(0xFF1E3A8A)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Content List of Verification Records
                Expanded(
                  child: records.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFDBEAFE),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_front_rounded,
                                    size: 42,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Seatbelt Photos in this View',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Start a cabin scan before starting your ride to record seatbelt compliance.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.slate,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await SeatbeltVerificationDialog.show(
                                      context,
                                      controller: widget.controller,
                                    );
                                  },
                                  icon: const Icon(Icons.camera_alt_rounded,
                                      size: 16),
                                  label: const Text(
                                      'Take Seatbelt Photo Now / फोटो खींचें'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return _SeatbeltRecordCard(
                              record: record,
                              formattedDate: _formatDateTime(record.timestamp),
                              photoWidget: _buildPhotoWidget(
                                record.photoBase64,
                                width: 92,
                                height: 92,
                              ),
                              onTapPhoto: () => _showFullPhoto(record),
                              canDelete: true,
                              onDelete: () => widget.controller
                                  .removeSeatbeltRecord(record.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String statusKey,
    required int count,
    Color activeColor = const Color(0xFF2563EB),
  }) {
    final isSelected = _filterStatus == statusKey;
    return InkWell(
      onTap: () {
        setState(() => _filterStatus = statusKey);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatbeltRecordCard extends StatelessWidget {
  const _SeatbeltRecordCard({
    required this.record,
    required this.formattedDate,
    required this.photoWidget,
    required this.onTapPhoto,
    required this.canDelete,
    required this.onDelete,
  });

  final SeatbeltRecord record;
  final String formattedDate;
  final Widget photoWidget;
  final VoidCallback onTapPhoto;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isApproved = record.isApproved;
    final primaryColor =
        isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final borderColor =
        isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
    final bgTint =
        isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prominent Photo Thumbnail
                InkWell(
                  onTap: onTapPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 92,
                          height: 92,
                          color: const Color(0xFF0F172A),
                          child: photoWidget,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.driverName.isNotEmpty
                                  ? record.driverName
                                  : 'Assigned Driver',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isApproved
                                      ? Icons.check_circle_rounded
                                      : Icons.error_rounded,
                                  size: 11,
                                  color: isApproved
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF991B1B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isApproved ? 'VERIFIED' : 'VIOLATION',
                                  style: TextStyle(
                                    color: isApproved
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF991B1B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Date and Time
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppColors.slate),
                          const SizedBox(width: 5),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Vehicle & Location badge
                      Row(
                        children: [
                          if (record.vehicleNumber.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping_outlined,
                                      size: 12, color: AppColors.navy),
                                  const SizedBox(width: 4),
                                  Text(
                                    record.vehicleNumber,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (record.location.isNotEmpty) ...[
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 12, color: AppColors.slate),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      record.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slate,
                                      ),
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
                ),
              ],
            ),
          ),

          // Bottom Action / Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    record.notes.isNotEmpty
                        ? record.notes
                        : (isApproved
                            ? 'Driver cabin inspection verified seatbelt fastened.'
                            : 'Driver seatbelt missing or unfastened.'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onTapPhoto,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded,
                          size: 14, color: primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        'View Full',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
