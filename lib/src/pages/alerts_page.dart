import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/seatbelt_records_dialog.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final searchController = TextEditingController();
  String severity = 'all';
  String selectedCategory = 'all';
  bool unresolvedOnly = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<(int, OperationsAlert)> get filteredAlerts {
    final query = searchController.text.trim().toLowerCase();
    return widget.controller.alerts.indexed
        .where((entry) {
          final alert = entry.$2;
          final matchesQuery = query.isEmpty ||
              alert.title.toLowerCase().contains(query) ||
              alert.details.toLowerCase().contains(query) ||
              alert.vehicleNumber.toLowerCase().contains(query) ||
              alert.challanNumber.toLowerCase().contains(query) ||
              alert.location.toLowerCase().contains(query);
          final matchesSeverity =
              severity == 'all' || alert.severity == severity;
          final matchesStatus = !unresolvedOnly || !alert.isResolved;
          final matchesCategory = selectedCategory == 'all' ||
              (selectedCategory == 'memo' && alert.isMemo) ||
              (selectedCategory == 'overspeed' && alert.isOverspeed) ||
              (selectedCategory == 'seatbelt' && alert.isSeatbelt) ||
              (selectedCategory == 'safety' && alert.category == 'safety');
          return matchesQuery &&
              matchesSeverity &&
              matchesStatus &&
              matchesCategory;
        })
        .toList()
        .reversed
        .toList();
  }

  String get _currentVehicleCode {
    if (widget.controller.truckModels.isNotEmpty &&
        widget.controller.truckIndex != null) {
      final idx = (widget.controller.truckIndex ?? 0)
          .clamp(0, widget.controller.truckModels.length - 1);
      return widget.controller.truckModels[idx].code;
    }
    return '';
  }

  Widget _buildBase64Image(
    String dataUri, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    try {
      String base64Str = dataUri;
      if (dataUri.contains(',')) {
        base64Str = dataUri.split(',').last;
      }
      final bytes = base64Decode(base64Str.trim());
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined,
              size: 20, color: AppColors.muted),
        ),
      );
    } catch (_) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.image_not_supported_outlined,
            size: 20, color: AppColors.muted),
      );
    }
  }

  void _showPhotoPreview(
    BuildContext context,
    String photoDataUri,
    String title,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded,
                        size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Driver Photo / Violation Evidence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildBase64Image(photoDataUri, fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Close'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
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

  Future<void> _attachPhotoToAlert(int index, OperationsAlert alert) async {
    final isMemo = alert.isMemo;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isMemo
                        ? Icons.receipt_long_rounded
                        : Icons.photo_camera_rounded,
                    color: isMemo
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMemo
                          ? 'Upload Challan Memo Evidence'
                          : 'Upload Photo / Safety Evidence',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Attach a camera photo or upload an image file for alert: "${alert.title}"',
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                title: const Text('Capture with Camera',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Take a live photo using device camera',
                    style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  SafetyNotificationService.pickDriverPhoto(
                    useCamera: true,
                    onPhotoSelected: (base64) async {
                      if (base64.isNotEmpty) {
                        await widget.controller.updateAlertPhoto(index, base64);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Photo attached to "${alert.title}".'),
                              backgroundColor: const Color(0xFF1E293B),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: Color(0xFF7C3AED), size: 20),
                ),
                title: Text(
                    isMemo
                        ? 'Upload Challan Document / Slip'
                        : 'Upload From Storage / Gallery',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Select image file from local device',
                    style: TextStyle(fontSize: 11.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  SafetyNotificationService.pickDriverPhoto(
                    useCamera: false,
                    onPhotoSelected: (base64) async {
                      if (base64.isNotEmpty) {
                        await widget.controller.updateAlertPhoto(index, base64);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Document / Photo attached to "${alert.title}".'),
                              backgroundColor: const Color(0xFF1E293B),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
              if (alert.driverPhoto.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fullscreen_rounded,
                        color: Color(0xFF2563EB), size: 20),
                  ),
                  title: const Text('View Full Photo',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPhotoPreview(context, alert.driverPhoto, alert.title);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626), size: 20),
                  ),
                  title: const Text('Remove Attached Photo',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFDC2626))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await widget.controller.updateAlertPhoto(index, '');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo removed from alert.'),
                          backgroundColor: Color(0xFF1E293B),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAlert({
    String? initialTitle,
    String? initialDetails,
    String? initialSeverity,
    String? initialCategory,
    String? initialVehicle,
    String? initialChallan,
    int? initialFine,
    String? initialLocation,
    String? initialPhoto,
  }) async {
    final alert = await showDialog<OperationsAlert>(
      context: context,
      builder: (_) => AddAlertDialog(
        controller: widget.controller,
        initialTitle: initialTitle,
        initialDetails: initialDetails,
        initialSeverity: initialSeverity,
        initialCategory: initialCategory,
        initialVehicle: initialVehicle,
        initialChallan: initialChallan,
        initialFine: initialFine,
        initialLocation: initialLocation,
        initialPhoto: initialPhoto,
      ),
    );
    if (alert == null) return;
    await widget.controller.addAlert(alert);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert "${alert.title}" registered successfully.'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteAlert(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alert?'),
        content: const Text(
          'This will permanently remove the alert notification from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      await widget.controller.removeAlert(index);
    }
  }

  Future<void> _clearAllAlerts() async {
    final count = widget.controller.alerts.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all alerts?'),
        content: Text(
          'This will permanently remove all $count alerts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 17),
            label: const Text('Clear All'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.controller.clearAllAlerts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count alerts cleared successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 650 ? 14 : 20,
              16,
              constraints.maxWidth < 650 ? 14 : 20,
              (constraints.maxWidth < 650 ? 14 : 20) + 80,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernHeader(),
                    const SizedBox(height: 14),
                    _buildFilterRow(),
                    const SizedBox(height: 14),
                    if (widget.controller.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filteredAlerts.isEmpty)
                      _buildCleanEmptyState()
                    else
                      for (final entry in filteredAlerts) ...[
                        _buildAlertCard(entry.$1, entry.$2),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 16),
                    _buildFooterStrip(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    final unreadCount =
        widget.controller.alerts.where((alert) => !alert.isRead).length;
    final totalCount = widget.controller.alerts.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Alerts & Notifications',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: unreadCount > 0
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: unreadCount > 0
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            '$totalCount Total',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: unreadCount > 0
                                  ? const Color(0xFFDC2626)
                                  : AppColors.slate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unreadCount > 0
                          ? '$unreadCount new unread alert${unreadCount > 1 ? 's' : ''}'
                          : 'All notifications caught up',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: unreadCount > 0
                            ? const Color(0xFFDC2626)
                            : AppColors.slate,
                        fontWeight:
                            unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _addAlert(
                  initialVehicle: _currentVehicleCode,
                  initialLocation: widget.controller.origin,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add Alert',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  if (unreadCount > 0)
                    InkWell(
                      onTap: () => widget.controller.markAllAlertsRead(),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.done_all_rounded,
                                size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text('Mark all as read',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: _clearAllAlerts,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_sweep_rounded,
                              size: 15, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text('Clear All',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13, color: AppColors.navy),
            decoration: InputDecoration(
              hintText: 'Search alerts by vehicle, challan #, or text...',
              hintStyle:
                  const TextStyle(fontSize: 12.5, color: AppColors.slate),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.slate),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterPill(
                  'all', 'All Alerts', Icons.notifications_none_rounded),
              const SizedBox(width: 6),
              _buildFilterPill(
                  'memo', 'Memos & Fines', Icons.receipt_long_rounded),
              const SizedBox(width: 6),
              _buildFilterPill('overspeed', 'Speed', Icons.speed_rounded),
              const SizedBox(width: 6),
              _buildFilterPill('seatbelt', 'Seatbelt',
                  Icons.airline_seat_recline_extra_rounded),
              const SizedBox(width: 6),
              _buildFilterPill('safety', 'Safety', Icons.shield_outlined),
              const SizedBox(width: 10),
              ActionChip(
                avatar: const Icon(Icons.photo_library_rounded,
                    size: 13, color: Color(0xFF2563EB)),
                label: const Text(
                  'Seatbelt Photos',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                backgroundColor: const Color(0xFFEFF6FF),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onPressed: () => SeatbeltRecordsDialog.show(
                  context,
                  controller: widget.controller,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String key, String label, IconData icon) {
    final isSelected = selectedCategory == key;
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : AppColors.slate,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.slate,
        ),
      ),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
        ),
      ),
      onSelected: (_) => setState(() => selectedCategory = key),
    );
  }

  Widget _buildCleanEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F2440),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'All Clear · No Active Alerts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'All fleet operations and vehicles are normal.\nNew alerts will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _addAlert(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Test Alert'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(int index, OperationsAlert alert) {
    final color = switch (alert.severity) {
      'critical' => const Color(0xFFEF4444),
      'warning' => const Color(0xFFF59E0B),
      _ => const Color(0xFF2563EB),
    };

    final bgTint = alert.isResolved
        ? const Color(0xFFF8FAFC)
        : alert.severity == 'critical'
            ? const Color(0xFFFFF1F2)
            : alert.severity == 'warning'
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF0F9FF);

    final border = alert.isResolved
        ? const Color(0xFFE2E8F0)
        : color.withValues(alpha: 0.35);

    final date = DateTime.tryParse(alert.createdAt)?.toLocal();
    final timeStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : 'Recent Alert';

    final (catLabel, catColor, catBg, catIcon) = alert.isMemo
        ? (
            'E-CHALLAN MEMO',
            const Color(0xFF7C3AED),
            const Color(0xFFF5F3FF),
            Icons.receipt_long_rounded
          )
        : alert.isOverspeed
            ? (
                'OVERSPEED VIOLATION',
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
                Icons.speed_rounded
              )
            : alert.isSeatbelt
                ? (
                    'SEATBELT INFRACTION',
                    const Color(0xFFD97706),
                    const Color(0xFFFFFBEB),
                    Icons.airline_seat_recline_extra_rounded
                  )
                : alert.category == 'safety'
                    ? (
                        'CABIN SAFETY CHECK',
                        const Color(0xFF0284C7),
                        const Color(0xFFF0F9FF),
                        Icons.security_rounded
                      )
                    : (
                        'GENERAL ADVISORY',
                        const Color(0xFF475569),
                        const Color(0xFFF1F5F9),
                        Icons.info_outline_rounded
                      );

    final categoryBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: catBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: catColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(catIcon, size: 10, color: catColor),
          const SizedBox(width: 4),
          Text(
            catLabel,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: catColor,
            ),
          ),
        ],
      ),
    );

    final metadataTags = <Widget>[
      if (alert.vehicleNumber.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 11, color: AppColors.slate),
              const SizedBox(width: 4),
              Text(
                alert.vehicleNumber,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      if (alert.challanNumber.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pin_outlined,
                  size: 11, color: Color(0xFF7C3AED)),
              const SizedBox(width: 4),
              Text(
                'Challan #${alert.challanNumber}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
      if (alert.fineAmount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: alert.isResolved
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: alert.isResolved
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.currency_rupee_rounded,
                size: 11,
                color: alert.isResolved
                    ? AppColors.slate
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 2),
              Text(
                alert.isResolved
                    ? '₹${alert.fineAmount} Paid'
                    : 'Fine: ₹${alert.fineAmount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: alert.isResolved
                      ? AppColors.slate
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      if (alert.location.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 11, color: AppColors.muted),
              const SizedBox(width: 3),
              Text(
                alert.location,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ),
      if (alert.driverPhoto.isNotEmpty)
        InkWell(
          onTap: () =>
              _showPhotoPreview(context, alert.driverPhoto, alert.title),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_camera_rounded,
                    size: 11, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  alert.isMemo
                      ? 'Challan Memo Attached'
                      : 'Photo Evidence Attached',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        )
      else
        InkWell(
          onTap: () => _attachPhotoToAlert(index, alert),
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    size: 11, color: AppColors.slate),
                const SizedBox(width: 4),
                Text(
                  alert.isMemo ? 'Attach Memo Photo' : 'Attach Photo',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final severityBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: alert.isResolved ? const Color(0xFFDCFCE7) : bgTint,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: alert.isResolved
                  ? const Color(0xFFA7F3D0)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            alert.isResolved ? 'RESOLVED' : alert.severity.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: alert.isResolved ? const Color(0xFF047857) : color,
            ),
          ),
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alert.isMemo && !alert.isResolved)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton.icon(
                  onPressed: () => widget.controller.toggleAlertResolved(index),
                  icon: const Icon(Icons.payment_rounded,
                      size: 13, color: Color(0xFF7C3AED)),
                  label: const Text(
                    'Settle / Pay',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F3FF),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFDDD6FE)),
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: () => _attachPhotoToAlert(index, alert),
              icon: Icon(
                alert.driverPhoto.isNotEmpty
                    ? Icons.photo_camera_rounded
                    : Icons.add_a_photo_outlined,
                size: 18,
                color: alert.driverPhoto.isNotEmpty
                    ? const Color(0xFF2563EB)
                    : AppColors.slate,
              ),
              tooltip: alert.driverPhoto.isNotEmpty
                  ? 'View or Update Photo Evidence'
                  : (alert.isMemo
                      ? 'Upload Challan Memo Photo'
                      : 'Upload Photo Evidence'),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => widget.controller.toggleAlertResolved(index),
              icon: Icon(
                alert.isResolved
                    ? Icons.restart_alt_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: alert.isResolved
                    ? AppColors.slate
                    : const Color(0xFF10B981),
              ),
              tooltip: alert.isResolved ? 'Reopen Alert' : 'Mark Resolved',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _deleteAlert(index),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.muted),
              tooltip: 'Delete Alert',
              visualDensity: VisualDensity.compact,
            ),
          ],
        );

        if (isMobile) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x040F2440),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 100,
                    color: alert.isResolved ? const Color(0xFF10B981) : color,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (alert.driverPhoto.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showPhotoPreview(
                                    context,
                                    alert.driverPhoto,
                                    alert.title,
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF93C5FD),
                                              width: 1.5,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: _buildBase64Image(
                                            alert.driverPhoto,
                                            width: 36,
                                            height: 36,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(1.5),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2563EB),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(3),
                                              bottomRight: Radius.circular(6),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.zoom_in_rounded,
                                            size: 9,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: bgTint,
                                  foregroundColor: alert.isResolved
                                      ? const Color(0xFF10B981)
                                      : color,
                                  child: Icon(
                                    alert.isResolved
                                        ? Icons.check_circle_rounded
                                        : catIcon,
                                    size: 16,
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          alert.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: alert.isResolved
                                                ? AppColors.slate
                                                : AppColors.navy,
                                            decoration: alert.isResolved
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        categoryBadge,
                                        severityBadge,
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actionButtons,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert.details,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: alert.isResolved
                                  ? AppColors.muted
                                  : AppColors.slate,
                              height: 1.35,
                            ),
                          ),
                          if (metadataTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: metadataTags,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Desktop layout
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F2440),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    color: alert.isResolved ? const Color(0xFF10B981) : color,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (alert.driverPhoto.isNotEmpty)
                            GestureDetector(
                              onTap: () => _showPhotoPreview(
                                context,
                                alert.driverPhoto,
                                alert.title,
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF93C5FD),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: _buildBase64Image(
                                        alert.driverPhoto,
                                        width: 44,
                                        height: 44,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2563EB),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(3),
                                          bottomRight: Radius.circular(7),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: bgTint,
                              foregroundColor: alert.isResolved
                                  ? const Color(0xFF10B981)
                                  : color,
                              child: Icon(
                                alert.isResolved
                                    ? Icons.check_circle_rounded
                                    : catIcon,
                                size: 18,
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
                                      alert.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: alert.isResolved
                                            ? AppColors.slate
                                            : AppColors.navy,
                                        decoration: alert.isResolved
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    categoryBadge,
                                    const SizedBox(width: 6),
                                    severityBadge,
                                    const Spacer(),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.details,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: alert.isResolved
                                        ? AppColors.muted
                                        : AppColors.slate,
                                    height: 1.35,
                                  ),
                                ),
                                if (metadataTags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: metadataTags,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          actionButtons,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.shield_rounded, size: 15, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Operational Incident Monitor',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(width: 8),
              Text('·', style: TextStyle(color: AppColors.muted)),
              SizedBox(width: 8),
              Text(
                'Telemetry Active',
                style: TextStyle(fontSize: 11, color: AppColors.slate),
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
                  'System Healthy',
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

class AddAlertDialog extends StatefulWidget {
  const AddAlertDialog({
    this.controller,
    this.initialTitle,
    this.initialDetails,
    this.initialSeverity,
    this.initialCategory,
    this.initialVehicle,
    this.initialChallan,
    this.initialFine,
    this.initialLocation,
    this.initialPhoto,
    super.key,
  });

  final PlannerController? controller;
  final String? initialTitle;
  final String? initialDetails;
  final String? initialSeverity;
  final String? initialCategory;
  final String? initialVehicle;
  final String? initialChallan;
  final int? initialFine;
  final String? initialLocation;
  final String? initialPhoto;

  @override
  State<AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<AddAlertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController detailsController;
  late final TextEditingController vehicleController;
  late final TextEditingController challanController;
  late final TextEditingController fineController;
  late final TextEditingController locationController;
  late String severity;
  late String category;
  String driverPhoto = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? '');
    detailsController =
        TextEditingController(text: widget.initialDetails ?? '');
    vehicleController =
        TextEditingController(text: widget.initialVehicle ?? '');
    challanController =
        TextEditingController(text: widget.initialChallan ?? '');
    fineController = TextEditingController(
      text: widget.initialFine != null ? widget.initialFine.toString() : '',
    );
    locationController =
        TextEditingController(text: widget.initialLocation ?? '');
    severity = widget.initialSeverity ?? 'warning';
    category = widget.initialCategory ?? 'general';
    driverPhoto = widget.initialPhoto ?? '';
  }

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    vehicleController.dispose();
    challanController.dispose();
    fineController.dispose();
    locationController.dispose();
    super.dispose();
  }

  List<String> get _titleSuggestions => switch (category) {
        'memo' => [
            'Red Light Signal Violation',
            'Speed Limit Exceeded Fine',
            'Illegal Highway Parking Memo',
            'Gross Overloading Violation',
            'Expired Pollution (PUC) Memo',
          ],
        'overspeed' => [
            'Overspeeding Alert (94 km/h)',
            'Highway Speed Limit Exceeded',
            'High Speed in Urban Zone',
          ],
        'seatbelt' => [
            'Seatbelt Violation: Driver Unbuckled',
            'Pre-Trip Seatbelt Check Failed',
            'In-Cabin Seatbelt Safety Non-Compliance',
          ],
        'safety' => [
            'Driver Fatigue & Drowsiness Warning',
            'Mobile Phone Distraction Warning',
            'Lane Departure Warning',
          ],
        _ => [
            'Road Congestion NH-48',
            'Heavy Rain & Fog Road Advisory',
            'Mandatory Route Detour',
          ],
      };

  String? _validateTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Alert title is required';
    }
    if (text.length < 5) {
      return 'Title must be at least 5 characters';
    }
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return 'Title cannot be only numbers. Enter a clear violation title';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(text)) {
      return 'Title contains invalid repeated characters';
    }
    final letters = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length >= 6 && !RegExp(r'[aeiouAEIOU]').hasMatch(letters)) {
      return 'Please enter a genuine readable title (no keyboard mash)';
    }
    return null;
  }

  String? _validateVehicleNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Vehicle number is required';
    }
    final clean = text.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Vehicle number cannot be only numbers (e.g. MH-12-AB-1234)';
    }
    if (RegExp(r'^[A-Z]+$').hasMatch(clean)) {
      return 'Vehicle number cannot be only letters (e.g. MH-12-AB-1234)';
    }
    if (clean.length < 4) {
      return 'Vehicle number is too short (e.g. MH-12-AB-1234 or TRK-101)';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(clean)) {
      return 'Vehicle number contains invalid repeated characters';
    }

    final isIndianPlate =
        RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{0,3}\d{3,4}$').hasMatch(clean);
    final isFleetCode = RegExp(r'^[A-Z]{2,5}\d{2,5}$').hasMatch(clean);
    final matchesKnownFleet = widget.controller?.truckModels.any((t) =>
            t.code.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase() == clean) ??
        false;

    if (!isIndianPlate && !isFleetCode && !matchesKnownFleet) {
      return 'Enter valid vehicle number (e.g. MH-12-AB-1234 or TRK-101)';
    }
    return null;
  }

  String? _validateLocation(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Location / Highway corridor is required';
    }
    if (text.length < 3) {
      return 'Location must be at least 3 characters';
    }
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return 'Location cannot be only numbers';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(text)) {
      return 'Location contains invalid repeated characters';
    }
    final letters = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length >= 6 && !RegExp(r'[aeiouAEIOU]').hasMatch(letters)) {
      return 'Please enter a genuine location / corridor name';
    }
    return null;
  }

  String? _validateChallanNumber(String? value) {
    if (category != 'memo') return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Challan / Memo number is required';
    }
    if (text.length < 4) {
      return 'Challan number must be at least 4 characters';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(text)) {
      return 'Invalid challan number format';
    }
    return null;
  }

  String? _validateFineAmount(String? value) {
    if (category != 'memo') return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Fine amount is required';
    }
    final amount = int.tryParse(text);
    if (amount == null) {
      return 'Enter a valid fine amount in ₹';
    }
    if (amount < 100) {
      return 'Fine amount must be at least ₹100';
    }
    if (amount > 200000) {
      return 'Fine amount cannot exceed ₹2,00,000';
    }
    return null;
  }

  String? _validateDetails(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Incident details are required';
    }
    if (text.length < 10) {
      return 'Please describe the incident in at least 10 characters';
    }
    if (RegExp(r'^\d+$').hasMatch(text)) {
      return 'Incident details cannot be only numbers';
    }
    if (RegExp(r'(.)\1{4,}').hasMatch(text)) {
      return 'Details contain invalid repeated characters';
    }
    final letters = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length >= 7 && !RegExp(r'[aeiouAEIOU]').hasMatch(letters)) {
      return 'Please enter a meaningful description (no keyboard mash)';
    }
    return null;
  }

  void _captureCameraPhoto() {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: true,
      onPhotoSelected: (base64) {
        if (mounted && base64.isNotEmpty) {
          setState(() {
            driverPhoto = base64;
          });
        }
      },
    );
  }

  void _uploadPhoto() {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: false,
      onPhotoSelected: (base64) {
        if (mounted && base64.isNotEmpty) {
          setState(() {
            driverPhoto = base64;
          });
        }
      },
    );
  }

  void _submit() {
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedFine = int.tryParse(fineController.text.trim()) ?? 0;
    Navigator.pop(
      context,
      OperationsAlert(
        title: titleController.text.trim(),
        details: detailsController.text.trim(),
        severity: severity,
        category: category,
        vehicleNumber: vehicleController.text.trim().toUpperCase(),
        challanNumber: challanController.text.trim(),
        fineAmount: parsedFine,
        location: locationController.text.trim(),
        driverPhoto: driverPhoto,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Widget _buildPhotoThumbnail() {
    if (driverPhoto.isEmpty) return const SizedBox.shrink();
    try {
      String base64Str = driverPhoto;
      if (driverPhoto.contains(',')) {
        base64Str = driverPhoto.split(',').last;
      }
      final bytes = base64Decode(base64Str.trim());
      return Image.memory(
        bytes,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 68,
          height: 68,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined,
              size: 20, color: AppColors.muted),
        ),
      );
    } catch (_) {
      return Container(
        width: 68,
        height: 68,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.image_not_supported_outlined,
            size: 20, color: AppColors.muted),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMemo = category == 'memo';
    final availableTrucks = widget.controller?.truckModels ?? const [];

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isMemo
                ? Icons.receipt_long_rounded
                : category == 'overspeed'
                    ? Icons.speed_rounded
                    : category == 'seatbelt'
                        ? Icons.airline_seat_recline_extra_rounded
                        : category == 'safety'
                            ? Icons.psychology_outlined
                            : Icons.warning_amber_rounded,
            size: 20,
            color: isMemo
                ? const Color(0xFF7C3AED)
                : category == 'overspeed'
                    ? const Color(0xFFEF4444)
                    : category == 'seatbelt'
                        ? const Color(0xFFD97706)
                        : category == 'safety'
                            ? const Color(0xFF0284C7)
                            : AppColors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMemo
                  ? 'Log E-Challan Traffic Memo'
                  : category == 'overspeed'
                      ? 'Log Overspeed Violation'
                      : category == 'seatbelt'
                          ? 'Log Seatbelt Violation'
                          : category == 'safety'
                              ? 'Log Driver Cabin Safety'
                              : 'Create Operational Alert',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Alert Category',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'memo',
                      child: Text('E-Challan Memo / Traffic Fine'),
                    ),
                    DropdownMenuItem(
                      value: 'overspeed',
                      child: Text('Overspeeding Violation'),
                    ),
                    DropdownMenuItem(
                      value: 'seatbelt',
                      child: Text('Seatbelt Non-Compliance'),
                    ),
                    DropdownMenuItem(
                      value: 'safety',
                      child: Text('Cabin Safety / Driver Fatigue'),
                    ),
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('General Road Advisory'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      category = value;
                      if (value == 'memo' && severity == 'info') {
                        severity = 'warning';
                      } else if (value == 'overspeed' || value == 'seatbelt') {
                        severity = 'critical';
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in _titleSuggestions)
                      ActionChip(
                        label: Text(item, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          setState(() {
                            titleController.text = item;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  validator: _validateTitle,
                  decoration: InputDecoration(
                    labelText: 'Alert Title *',
                    hintText: isMemo
                        ? 'e.g. Red Light Signal Violation'
                        : category == 'overspeed'
                            ? 'e.g. Overspeeding Alert (94 km/h)'
                            : category == 'seatbelt'
                                ? 'e.g. Seatbelt Violation: Driver Unbuckled'
                                : 'e.g. Traffic Congestion NH-48',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: vehicleController,
                        validator: _validateVehicleNumber,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number *',
                          hintText: 'e.g. MH-12-AB-1234',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: locationController,
                        validator: _validateLocation,
                        decoration: const InputDecoration(
                          labelText: 'Location / Highway *',
                          hintText: 'e.g. Mumbai Hub NH-48',
                        ),
                      ),
                    ),
                  ],
                ),
                if (availableTrucks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Fleet:',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted),
                      ),
                      for (final truck in availableTrucks.take(4))
                        ActionChip(
                          label: Text(truck.code,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () {
                            setState(() {
                              vehicleController.text = truck.code;
                            });
                          },
                        ),
                    ],
                  ),
                ],
                if (isMemo) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: challanController,
                          validator: _validateChallanNumber,
                          decoration: const InputDecoration(
                            labelText: 'Challan / Memo # *',
                            hintText: 'e.g. MH-2024-8921',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: fineController,
                          keyboardType: TextInputType.number,
                          validator: _validateFineAmount,
                          decoration: const InputDecoration(
                            labelText: 'Fine Amount (₹) *',
                            hintText: 'e.g. 1000',
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration:
                      const InputDecoration(labelText: 'Severity Level'),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info (Low)')),
                    DropdownMenuItem(
                        value: 'warning', child: Text('Warning (Medium)')),
                    DropdownMenuItem(
                        value: 'critical', child: Text('Critical (High)')),
                  ],
                  onChanged: (value) =>
                      setState(() => severity = value ?? 'warning'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsController,
                  minLines: 3,
                  maxLines: 5,
                  validator: _validateDetails,
                  decoration: const InputDecoration(
                    labelText: 'Incident Details *',
                    hintText:
                        'Describe violation, location, payment due, or instructions (min 10 characters)...',
                  ),
                ),
                const SizedBox(height: 14),
                // Driver Photo / Evidence Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: driverPhoto.isNotEmpty
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isMemo
                                ? Icons.receipt_long_rounded
                                : Icons.camera_alt_outlined,
                            size: 16,
                            color: driverPhoto.isNotEmpty
                                ? (isMemo
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF2563EB))
                                : AppColors.slate,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isMemo
                                ? 'Challan Memo Document / Slip Photo'
                                : 'Driver Photo / Violation Evidence',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const Spacer(),
                          if (driverPhoto.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 11, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMemo ? 'Memo Attached' : 'Photo Attached',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (driverPhoto.isNotEmpty) ...[
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _buildPhotoThumbnail(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMemo
                                        ? 'Challan memo evidence photo attached.'
                                        : 'Driver evidence photo captured.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _captureCameraPhoto,
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 13),
                                        label: const Text('Retake Camera',
                                            style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            setState(() => driverPhoto = ''),
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 13,
                                            color: Color(0xFFDC2626)),
                                        label: const Text('Remove',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFDC2626))),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _captureCameraPhoto,
                                icon: Icon(
                                    isMemo
                                        ? Icons.document_scanner_rounded
                                        : Icons.photo_camera_rounded,
                                    size: 14),
                                label: Text(
                                    isMemo
                                        ? 'Scan Memo (Camera)'
                                        : 'Camera Photo',
                                    style: const TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _uploadPhoto,
                                icon: const Icon(Icons.upload_file_rounded,
                                    size: 14),
                                label: Text(
                                    isMemo ? 'Upload Memo File' : 'Upload File',
                                    style: const TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isMemo ? 'Issue E-Challan' : 'Create Alert'),
        ),
      ],
    );
  }
}
