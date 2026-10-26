import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';
import 'trip_detail_report_dialog.dart';

/// Dialog showing full driver trip history:
/// Total trips completed, total distance, summary stats,
/// and clickable trip cards that open the comprehensive trip detail report dialog.
class DriverTripHistoryDialog extends StatefulWidget {
  const DriverTripHistoryDialog({
    required this.driverId,
    required this.driverName,
    required this.controller,
    super.key,
  });

  final String driverId;
  final String driverName;
  final PlannerController controller;

  @override
  State<DriverTripHistoryDialog> createState() =>
      _DriverTripHistoryDialogState();
}

class _DriverTripHistoryDialogState extends State<DriverTripHistoryDialog> {
  String _filter = 'all'; // all, completed, in_progress

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _openTripDetail(TripRecord trip) {
    showDialog<void>(
      context: context,
      builder: (_) => TripDetailReportDialog(
        trip: trip,
        controller: widget.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTrips = widget.controller.getDriverTrips(
      driverName: widget.driverName,
      driverId: widget.driverId,
    );

    // If matching by name/id yielded empty, fallback to all controller trips if driver is primary
    final trips = allTrips.isNotEmpty
        ? allTrips
        : widget.controller.trips.where((t) {
            final active = widget.controller.selectedDriver?.name ?? '';
            return active.isNotEmpty &&
                t.assignedDriver.toLowerCase().contains(active.toLowerCase());
          }).toList();

    final filteredTrips = trips.where((t) {
      if (_filter == 'completed') {
        return t.status == 'completed' || t.status == 'delivered';
      }
      if (_filter == 'in_progress') {
        return t.status != 'completed' && t.status != 'delivered';
      }
      return true;
    }).toList();

    // Summary calculation
    final totalTrips = trips.length;
    final completedCount = trips
        .where((t) => t.status == 'completed' || t.status == 'delivered')
        .length;
    final totalKm = trips.fold(0.0, (sum, t) {
      final km = t.actualDistanceKm > 0 ? t.actualDistanceKm : t.plannedDistanceKm;
      return sum + km;
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.history_edu_rounded,
                    size: 20,
                    padding: 8,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.driverName} · Trip History (ट्रिप इतिहास)',
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
                          'Driver all trips, cargo records & detailed reports',
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Driver Summary Stats Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL TRIPS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '$totalTrips Trips',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '$completedCount Done',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL KM DRIVEN',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '${totalKm.toStringAsFixed(0)} KM',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${trips.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Delivered / Completed ($completedCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('in_progress', 'Ongoing (${totalTrips - completedCount})'),
                ],
              ),
            ),

            // Trips List
            Expanded(
              child: filteredTrips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_bus_outlined,
                              size: 48, color: AppColors.slate.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text(
                            'No trip records found for this driver.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: filteredTrips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final trip = filteredTrips[index];
                        final isDelivered = trip.status == 'delivered' ||
                            trip.status == 'completed';
                        final hasPod = trip.podStatus == 'received' ||
                            trip.podPhoto.isNotEmpty;

                        return InkWell(
                          onTap: () => _openTripDetail(trip),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const AppIconBadge(
                                      icon: Icons.local_shipping_outlined,
                                      size: 16,
                                      padding: 6,
                                      radius: 8,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Trip #${trip.effectiveTripNumber}',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          Text(
                                            trip.customerName.isNotEmpty
                                                ? 'Customer: ${trip.customerName}'
                                                : 'General Commercial Freight',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDelivered
                                            ? AppColors.primarySoft
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDelivered
                                              ? AppColors.primaryBorder
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Text(
                                        trip.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDelivered
                                              ? AppColors.primaryDark
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Origin ➔ Destination
                                Row(
                                  children: [
                                    const Icon(Icons.circle,
                                        size: 8, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        trip.origin,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navy),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.arrow_forward_rounded,
                                          size: 13, color: AppColors.slate),
                                    ),
                                    const Icon(Icons.location_on,
                                        size: 12, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip.destination,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navy),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Footer: Date + Goods Info + Toll nakas badge + Click to View
                                Row(
                                  children: [
                                    Text(
                                      _formatDate(trip.createdAt),
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.slate),
                                    ),
                                    if (trip.stops.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${trip.stops.length} Toll/Stops',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (hasPod) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'POD OK',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    const Text(
                                      'View Report ➔',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.slate,
          ),
        ),
      ),
    );
  }
}
