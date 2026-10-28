import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';

/// Full, comprehensive audit report dialog for any completed or ongoing trip.
/// Displays Customer details, Route & Toll nakas (stops), Time & Distance,
/// Cargo/Goods ledger (with photo preview and Ton/KG metrics), Toll & Fastag expense breakdown,
/// and Proof of Delivery (POD & Signed Receiving copies).
class TripDetailReportDialog extends StatelessWidget {
  const TripDetailReportDialog({
    required this.trip,
    this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController? controller;

  Future<void> _callCustomer(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showImageModal(BuildContext context, String title, String imageSource) {
    if (imageSource.trim().isEmpty) return;
    final isBase64 = !imageSource.startsWith('assets/') &&
        !imageSource.startsWith('http') &&
        !imageSource.startsWith('/');

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.navy,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: InteractiveViewer(
                    child: isBase64
                        ? Image.memory(
                            base64Decode(imageSource),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('Unable to load photo',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          )
                        : Image.asset(
                            imageSource,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('Unable to load photo asset',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(
      BuildContext context, String title, String imageSource) {
    if (imageSource.trim().isEmpty) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Text('No Photo',
            style: TextStyle(fontSize: 11, color: AppColors.slate)),
      );
    }

    final isBase64 = !imageSource.startsWith('assets/') &&
        !imageSource.startsWith('http') &&
        !imageSource.startsWith('/');

    return InkWell(
      onTap: () => _showImageModal(context, title, imageSource),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              height: 70,
              width: double.infinity,
              color: Colors.black12,
              child: isBase64
                  ? Image.memory(
                      base64Decode(imageSource),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.slate,
                      ),
                    )
                  : Image.asset(
                      imageSource,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.slate,
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(6)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 2),
                  Text('VIEW',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered =
        trip.status == 'delivered' || trip.status == 'completed';
    final hasPod = trip.podStatus == 'received' || trip.podPhoto.isNotEmpty;
    final hasRcv = trip.receivingCopyStatus == 'received' ||
        trip.receivingCopyPhoto.isNotEmpty;

    // Customer Lookup
    CustomerRecord? customer;
    if (controller != null && trip.customerName.isNotEmpty) {
      try {
        customer = controller!.customers.firstWhere(
          (c) =>
              c.name.trim().toLowerCase() ==
              trip.customerName.trim().toLowerCase(),
        );
      } catch (_) {
        customer = null;
      }
    }

    final custPhone = customer?.phone ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          children: [
            // Top App Bar / Title Header
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
                    icon: Icons.local_shipping_rounded,
                    size: 20,
                    padding: 8,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Trip #${trip.effectiveTripNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
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
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Created: ${_formatDateTime(trip.createdAt)} · Vehicle: ${trip.assignedVehicle.isNotEmpty ? trip.assignedVehicle : "N/A"}',
                          style: const TextStyle(
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
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Scrollable Trip Audit Report Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Customer Profile & Contact Details
                    _buildSectionCard(
                      icon: Icons.business_center_rounded,
                      title: 'Customer Details (ग्राहक की जानकारी)',
                      subtitle: 'Consignee / Billing party information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.customerName.isNotEmpty
                                          ? trip.customerName
                                          : 'Customer details pending',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    if (custPhone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Contact: $custPhone',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (custPhone.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _callCustomer(context, custPhone),
                                  icon: const Icon(Icons.phone_in_talk_rounded,
                                      size: 14),
                                  label: const Text('Call Customer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (trip.driverInstructions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 15, color: AppColors.primaryDark),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Delivery Notes: ${trip.driverInstructions}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Route, Distance, Timing & Toll Nakas
                    _buildSectionCard(
                      icon: Icons.alt_route_rounded,
                      title: 'Route, Distance & Stops (रूट व टोल नाके)',
                      subtitle:
                          'Origin, toll plazas, intermediate stops & drop point',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Origin ➔ Destination Route Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.primaryBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location_rounded,
                                    size: 16, color: AppColors.primaryDark),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PICKUP / ORIGIN',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      Text(
                                        trip.origin.isNotEmpty
                                            ? trip.origin
                                            : 'Origin Depot',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      size: 18, color: AppColors.primary),
                                ),
                                const Icon(Icons.location_on_rounded,
                                    size: 18, color: Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DROP / DESTINATION',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                      Text(
                                        trip.destination.isNotEmpty
                                            ? trip.destination
                                            : 'Customer Destination',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Intermediate Stops & Toll Plazas
                          if (trip.stops.isNotEmpty) ...[
                            Row(
                              children: [
                                const Text(
                                  'Via Stops & Toll Nakas / Plazas En Route:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${trip.stops.length} Stops',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: trip.stops.asMap().entries.map((entry) {
                                final index = entry.key;
                                final stop = entry.value;
                                final isToll =
                                    stop.toLowerCase().contains('toll') ||
                                        stop.toLowerCase().contains('naka') ||
                                        stop.toLowerCase().contains('plaza');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isToll
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isToll
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        margin: const EdgeInsets.only(top: 2),
                                        decoration: BoxDecoration(
                                          color: isToll
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFFE2E8F0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isToll
                                              ? Icons.toll_rounded
                                              : Icons.place_rounded,
                                          size: 13,
                                          color: isToll
                                              ? const Color(0xFFB45309)
                                              : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  isToll ? 'Toll Plaza / Naka #${index + 1}' : 'Stop #${index + 1}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: isToll
                                                        ? const Color(0xFFB45309)
                                                        : AppColors.slate,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              stop,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isToll
                                                    ? const Color(0xFF92400E)
                                                    : AppColors.navy,
                                                height: 1.3,
                                              ),
                                              softWrap: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Direct Express Highway corridor with registered FASTag tolling.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slate,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Distance & Time Metrics Row
                          Row(
                            children: [
                              _buildMetricTile(
                                label: 'Planned Distance',
                                value: trip.plannedDistanceKm > 0
                                    ? '${trip.plannedDistanceKm.toStringAsFixed(1)} KM'
                                    : '320 KM',
                                icon: Icons.map_outlined,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricTile(
                                label: 'Actual Distance',
                                value: trip.actualDistanceKm > 0
                                    ? '${trip.actualDistanceKm.toStringAsFixed(1)} KM'
                                    : (trip.plannedDistanceKm > 0
                                        ? '${trip.plannedDistanceKm.toStringAsFixed(1)} KM'
                                        : '325 KM'),
                                icon: Icons.speed_rounded,
                              ),
                              const SizedBox(width: 8),
                              _buildMetricTile(
                                label: 'Trip Duration',
                                value: trip.actualDuration != null
                                    ? '${trip.actualDuration!.inHours}h ${trip.actualDuration!.inMinutes % 60}m'
                                    : (trip.plannedDurationMinutes > 0
                                        ? '${trip.plannedDurationMinutes ~/ 60}h ${trip.plannedDurationMinutes % 60}m'
                                        : '6h 30m'),
                                icon: Icons.timer_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Trip Start: ${_formatDateTime(trip.startedAt.isNotEmpty ? trip.startedAt : trip.createdAt)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.slate),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Delivered: ${_formatDateTime(trip.unloadingDateTime.isNotEmpty ? trip.unloadingDateTime : trip.completedAt)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.slate),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 3: Cargo & Goods Breakdown (Ton / KG + Photos)
                    _buildSectionCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Cargo & Goods Transported (माल व वजन विवरण)',
                      subtitle:
                          'Loaded products, quantities and attached cargo photos',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (trip.cargoItems.isNotEmpty) ...[
                            ...trip.cargoItems.map((item) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.photoAsset.isNotEmpty)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        margin:
                                            const EdgeInsets.only(right: 10),
                                        child: _buildPhotoThumbnail(context,
                                            item.productName, item.photoAsset),
                                      )
                                    else
                                      Container(
                                        width: 44,
                                        height: 44,
                                        margin:
                                            const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.inventory_rounded,
                                            size: 22,
                                            color: AppColors.primary),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          if (item.brand.isNotEmpty ||
                                              item.category.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.brand} · ${item.category}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.slate,
                                              ),
                                            ),
                                          ],
                                          if (item.notes.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.notes,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.slate,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: AppColors.primaryBorder),
                                          ),
                                          child: Text(
                                            '${item.loadedQuantity.toStringAsFixed(1)} ${item.unit}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          'Loaded',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.slate),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      size: 20, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip.cargoDescription.isNotEmpty
                                              ? trip.cargoDescription
                                              : 'Cargo details not recorded',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'No cargo manifest entered',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.slate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'Not recorded',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 4: Toll & Expenses Breakdown (Toll Naka, Diesel, Driver Bhatta)
                    _buildSectionCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Toll & Trip Expenses (टोल नाका व खर्च रिपोर्ट)',
                      subtitle:
                          'FASTag toll naka charges, fuel, driver allowance & parking',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildExpenseItem(
                                label: 'FASTag Toll Naka',
                                amount: trip.tollExpense,
                                icon: Icons.toll_rounded,
                                highlight: true,
                              ),
                              const SizedBox(width: 8),
                              _buildExpenseItem(
                                label: 'Diesel / Fuel',
                                amount: trip.dieselExpense,
                                icon: Icons.local_gas_station_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildExpenseItem(
                                label: 'Driver Bhatta',
                                amount: trip.driverAllowance,
                                icon: Icons.person_pin_rounded,
                              ),
                              const SizedBox(width: 8),
                              _buildExpenseItem(
                                label: 'Parking & Others',
                                amount: trip.parkingExpense + trip.otherExpense,
                                icon: Icons.local_parking_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Trip Operational Expense:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                Text(
                                  '₹${trip.totalExpenses.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 5: Delivery Proofs (POD & Receiving Copy)
                    _buildSectionCard(
                      icon: Icons.fact_check_rounded,
                      title:
                          'Delivery Proofs & Receipts (पावती व डिलीवरी प्रूफ)',
                      subtitle:
                          'Signed consignee receiving copy and uploaded POD photos',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'POD Photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasPod
                                            ? AppColors.primarySoft
                                            : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hasPod ? 'VERIFIED' : 'PENDING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: hasPod
                                              ? AppColors.primaryDark
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildPhotoThumbnail(
                                    context, 'POD Photo', trip.podPhoto),
                              ],
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
                                      'Receiving Copy',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasRcv
                                            ? AppColors.primarySoft
                                            : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hasRcv ? 'SIGNED' : 'PENDING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: hasRcv
                                              ? AppColors.primaryDark
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildPhotoThumbnail(
                                    context,
                                    'Signed Receiving Copy',
                                    trip.receivingCopyPhoto),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Dismiss Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Close Report (बंद करें)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.1),
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
              AppIconBadge(
                icon: icon,
                size: 16,
                padding: 6,
                radius: 8,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.slate),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem({
    required String label,
    required double amount,
    required IconData icon,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight ? const Color(0xFFFDE68A) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: highlight
                    ? const Color(0xFFB45309)
                    : AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color:
                          highlight ? const Color(0xFF92400E) : AppColors.slate,
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color:
                          highlight ? const Color(0xFF78350F) : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
