import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/driver_report_detail_dialog.dart';
import '../widgets/seatbelt_records_dialog.dart';
import '../widgets/trip_map_dialog.dart';
import 'alerts_page.dart';

enum OperationsModule { drivers, vehicles, trips, alerts }

extension OperationsModuleView on OperationsModule {
  String get title => switch (this) {
        OperationsModule.drivers => 'Drivers',
        OperationsModule.vehicles => 'Vehicles',
        OperationsModule.trips => 'Trips',
        OperationsModule.alerts => 'Alerts',
      };

  String get singular => switch (this) {
        OperationsModule.drivers => 'driver',
        OperationsModule.vehicles => 'vehicle',
        OperationsModule.trips => 'trip',
        OperationsModule.alerts => 'alert',
      };

  IconData get icon => switch (this) {
        OperationsModule.drivers => Icons.badge_outlined,
        OperationsModule.vehicles => Icons.local_shipping_outlined,
        OperationsModule.trips => Icons.route_outlined,
        OperationsModule.alerts => Icons.notifications_none_rounded,
      };
}

class OperationsModulePage extends StatelessWidget {
  const OperationsModulePage({
    required this.module,
    required this.controller,
    super.key,
  });

  final OperationsModule module;
  final PlannerController controller;

  List<Object> get _records => switch (module) {
        OperationsModule.drivers => controller.drivers,
        OperationsModule.vehicles => controller.truckModels,
        OperationsModule.trips => controller.trips,
        OperationsModule.alerts => controller.alerts,
      };

  Future<void> _add(BuildContext context) async {
    if (module == OperationsModule.trips) {
      final trip = await showDialog<TripRecord>(
        context: context,
        builder: (_) => const TripMapDialog(),
      );
      if (trip != null) {
        await controller.addTrip(trip);
        controller.setRoute(
          newOrigin: trip.origin,
          newDestination: trip.destination,
          newStops: trip.stops,
        );
      }
      return;
    }

    if (module == OperationsModule.alerts) {
      final alert = await showDialog<OperationsAlert>(
        context: context,
        builder: (_) => AddAlertDialog(controller: controller),
      );
      if (alert != null) {
        await controller.addAlert(alert);
      }
      return;
    }

    final record = await showDialog<Object>(
      context: context,
      builder: (_) => AddRecordDialog(module: module),
    );
    if (record == null) return;
    try {
      if (record is DriverProfile) await controller.addDriver(record);
      if (record is TruckModel) await controller.addTruckModel(record);
      if (record is OperationsAlert) await controller.addAlert(record);
    } on ArgumentError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e.message?.toString() ?? 'Invalid entry. Please try again.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${module.singular}?'),
        content: const Text('This record will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    switch (module) {
      case OperationsModule.drivers:
        await controller.removeDriver(index);
      case OperationsModule.vehicles:
        await controller.removeTruckModel(index);
      case OperationsModule.trips:
        await controller.removeTrip(index);
      case OperationsModule.alerts:
        await controller.removeAlert(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ColoredBox(
        color: AppColors.canvas,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final canManage = controller.isAdmin;
            return Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.blueSoft,
                              foregroundColor: AppColors.blue,
                              child: Icon(module.icon, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    module.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    'Manage ${module.title.toLowerCase()} records',
                                    style: const TextStyle(
                                      color: AppColors.slate,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (module == OperationsModule.drivers)
                              OutlinedButton.icon(
                                onPressed: () => SeatbeltRecordsDialog.show(
                                  context,
                                  controller: controller,
                                ),
                                icon: const Icon(Icons.photo_library_outlined,
                                    size: 16),
                                label: const Text('Seatbelt Photos'),
                              ),
                            if (canManage)
                              FilledButton.icon(
                                onPressed: () => _add(context),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: Text('Add ${module.singular}'),
                              ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                module.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Manage real ${module.title.toLowerCase()} records',
                                style: const TextStyle(color: AppColors.slate),
                              ),
                            ],
                          ),
                        ),
                        if (module == OperationsModule.drivers) ...[
                          OutlinedButton.icon(
                            onPressed: () => SeatbeltRecordsDialog.show(
                              context,
                              controller: controller,
                            ),
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 16),
                            label: const Text('Seatbelt Photos'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (canManage)
                          FilledButton.icon(
                            onPressed: () => _add(context),
                            icon: const Icon(Icons.add_rounded),
                            label: Text('Add ${module.singular}'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.blueSoft,
                          foregroundColor: AppColors.blue,
                          child: Icon(module.icon),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_records.length}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'saved ${module.title.toLowerCase()} records',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.slate),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: controller.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _records.isEmpty
                            ? _EmptyModule(
                                module: module,
                                onAdd: canManage ? () => _add(context) : null,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                itemCount: _records.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final record = _records[index];
                                  return _RecordCard(
                                    record: record,
                                    icon: module.icon,
                                    controller: controller,
                                    onViewSeatbeltPhotos: record
                                            is DriverProfile
                                        ? () => SeatbeltRecordsDialog.show(
                                              context,
                                              controller: controller,
                                              initialDriverEmail: record.email,
                                            )
                                        : null,
                                    onRemove: canManage
                                        ? () => _remove(context, index)
                                        : null,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyModule extends StatelessWidget {
  const _EmptyModule({required this.module, required this.onAdd});
  final OperationsModule module;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F2440),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(module.icon, size: 36, color: AppColors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${module.title.toLowerCase()} configured yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your real ${module.title.toLowerCase()} to manage dispatches, track fleet operations, and plan delivery routes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add ${module.singular}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _buildRecordBase64Image(String dataUri) {
  try {
    String base64Str = dataUri;
    if (dataUri.contains(',')) {
      base64Str = dataUri.split(',').last;
    }
    final bytes = base64Decode(base64Str.trim());
    return Image.memory(
      bytes,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.person_rounded,
        size: 20,
        color: AppColors.blue,
      ),
    );
  } catch (_) {
    return const Icon(
      Icons.person_rounded,
      size: 20,
      color: AppColors.blue,
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.icon,
    required this.controller,
    required this.onRemove,
    this.onViewSeatbeltPhotos,
  });
  final Object record;
  final IconData icon;
  final PlannerController controller;
  final VoidCallback? onRemove;
  final VoidCallback? onViewSeatbeltPhotos;

  (String, String, String?) get _content => switch (record) {
        DriverProfile driver => (
            driver.name,
            'ID: ${driver.email}${driver.phone.isNotEmpty ? " · Ph: ${driver.phone}" : ""}${driver.assignedVehicle.isNotEmpty ? " · Truck: ${driver.assignedVehicle}" : ""}',
            driver.password.isEmpty ? 'Unset' : 'Active',
          ),
        TruckModel vehicle => (
            vehicle.name,
            '${vehicle.code} · ${vehicle.capacity}${vehicle.imei.isNotEmpty ? " · IMEI: ${vehicle.maskedImei}" : ""}',
            vehicle.isMoving
                ? '${vehicle.currentSpeed.toStringAsFixed(0)} km/h · ${vehicle.isIgnitionOn ? "ACC ON" : "ACC OFF"}'
                : (vehicle.isNeverSynced
                    ? 'No GPS Sync'
                    : (vehicle.isIgnitionOn
                        ? 'Idle · ACC ON'
                        : 'Parked · Max ${vehicle.maxSpeed} km/h')),
          ),
        TripRecord trip => (
            trip.reference,
            '${trip.origin} -> ${trip.destination}',
            trip.status,
          ),
        OperationsAlert alert => (
            alert.title,
            alert.details,
            alert.severity,
          ),
        _ => ('Record', '', null),
      };

  Widget _buildComplianceChip(String label, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $date',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'sans-serif',
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildDriverStatChip(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$title: ',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.slate,
                  fontFamily: 'sans-serif',
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckCard(BuildContext context, TruckModel vehicle) {
    final truckIndex =
        controller.truckModels.indexWhere((t) => t.code == vehicle.code);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.local_shipping_rounded, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name.isNotEmpty ? vehicle.name : vehicle.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle.code} · ${vehicle.capacity} · ${vehicle.axles} axles${vehicle.imei.isNotEmpty ? " · IMEI: ${vehicle.maskedImei}" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: Color(0xFFEF4444)),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: vehicle.isMoving
                  ? const Color(0xFFDCFCE7)
                  : (vehicle.isNeverSynced
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  vehicle.isMoving
                      ? Icons.play_arrow_rounded
                      : (vehicle.isNeverSynced
                          ? Icons.gps_off_rounded
                          : Icons.pause_rounded),
                  size: 14,
                  color: vehicle.isMoving
                      ? AppColors.primary
                      : (vehicle.isNeverSynced
                          ? AppColors.slate
                          : const Color(0xFFB45309)),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    vehicle.isMoving
                        ? '${vehicle.currentSpeed.toStringAsFixed(0)} km/h · ACC ON · Moving'
                        : (vehicle.isNeverSynced
                            ? 'No GPS Sync'
                            : (vehicle.isIgnitionOn
                                ? 'Idle · ACC ON'
                                : 'Parked · Max ${vehicle.maxSpeed} km/h')),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'sans-serif',
                      color: vehicle.isMoving
                          ? AppColors.primary
                          : (vehicle.isNeverSynced
                              ? AppColors.slate
                              : const Color(0xFFB45309)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: vehicle.isFastagLow
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              border: Border.all(
                color: vehicle.isFastagLow
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFBBF7D0),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.toll_rounded,
                      size: 18,
                      color: vehicle.isFastagLow
                          ? const Color(0xFFDC2626)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FASTag Balance: ₹${vehicle.fastagBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          fontFamily: 'sans-serif',
                          color: vehicle.isFastagLow
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF166534),
                        ),
                      ),
                    ),
                    if (vehicle.isFastagLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Low Balance (< ₹500)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: truckIndex == -1
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _FastagRechargeDialog(
                                  vehicle: vehicle,
                                  truckIndex: truckIndex,
                                  controller: controller,
                                ),
                              ),
                      icon: const Icon(Icons.add_card_rounded, size: 14),
                      label: const Text(
                        'Recharge FASTag',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _FastagHistoryDialog(vehicle: vehicle),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 14),
                      label: Text(
                        'History (${vehicle.fastagRecharges.length})',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Insurance Auto-Pay: ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate),
                      ),
                    ),
                    Switch(
                      value: vehicle.isInsuranceAutoPay,
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) => controller.toggleAutoPay(
                        vehicleCode: vehicle.code,
                        isInsuranceAutoPay: val,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Service Auto-Pay: ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate),
                      ),
                    ),
                    Switch(
                      value: vehicle.isServiceAutoPay,
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) => controller.toggleAutoPay(
                        vehicleCode: vehicle.code,
                        isServiceAutoPay: val,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Fleet Compliance & Permits',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'sans-serif'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: truckIndex == -1
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _VehicleComplianceDialog(
                                  vehicle: vehicle,
                                  truckIndex: truckIndex,
                                  controller: controller,
                                ),
                              ),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 13),
                      label: const Text('Edit Dates',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildComplianceChip('RC', vehicle.rcExpiry),
                    _buildComplianceChip('PUC', vehicle.pucExpiry),
                    _buildComplianceChip('Fitness', vehicle.fitnessExpiry),
                    _buildComplianceChip(
                        'AITP Permit', vehicle.allIndiaPermitExpiry),
                    _buildComplianceChip(
                        'State Tax', vehicle.statePermitTaxExpiry),
                    _buildComplianceChip('Insurance', vehicle.insuranceExpiry),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: vehicle.isServiceDueSoon
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF8FAFC),
              border: Border.all(
                color: vehicle.isServiceDueSoon
                    ? const Color(0xFFFDE68A)
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 16,
                      color: vehicle.isServiceDueSoon
                          ? const Color(0xFFB45309)
                          : AppColors.slate,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Next Service: ${vehicle.nextServiceKm} km (Due in ${vehicle.kmUntilNextService} km)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: vehicle.isServiceDueSoon
                              ? const Color(0xFF92400E)
                              : AppColors.slate,
                        ),
                      ),
                    ),
                    if (vehicle.isServiceDueSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Due Soon!',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: truckIndex == -1
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _TyreTrackingDialog(
                                  vehicle: vehicle,
                                  truckIndex: truckIndex,
                                  controller: controller,
                                ),
                              ),
                      icon: const Icon(Icons.album_outlined, size: 14),
                      label: Text(
                        'Tyre Tracking (${vehicle.tyres.length})',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: truckIndex == -1
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _VehicleServiceDialog(
                                  vehicle: vehicle,
                                  truckIndex: truckIndex,
                                  controller: controller,
                                ),
                              ),
                      icon: const Icon(Icons.car_repair_rounded, size: 14),
                      label: Text(
                        'Service Logs (${vehicle.serviceHistory.length})',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, DriverProfile driver) {
    final driverIndex =
        controller.drivers.indexWhere((d) => d.email == driver.email);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => DriverReportDetailDialog(
            driver: driver,
            controller: controller,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  driver.photo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF93C5FD), width: 1.5),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: _buildRecordBase64Image(driver.photo),
                          ),
                        )
                      : const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          child: Icon(Icons.person_rounded, size: 24),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                driver.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: driver.password.isEmpty
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                driver.password.isEmpty ? 'Unset' : 'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: driver.password.isEmpty
                                      ? AppColors.slate
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${driver.email}${driver.phone.isNotEmpty ? " · Ph: ${driver.phone}" : ""}${driver.assignedVehicle.isNotEmpty ? " · Truck: ${driver.assignedVehicle}" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      onPressed: onRemove,
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Color(0xFFEF4444)),
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'DL: ${driver.licenseNumber} (Exp: ${driver.licenseExpiry})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.health_and_safety_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Insurance: ${driver.driverInsurancePolicy} (Exp: ${driver.driverInsuranceExpiry})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'sans-serif',
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildDriverStatChip(
                        'Trips Completed',
                        '${driver.completedTripsCount}',
                        Icons.check_circle_outline_rounded,
                        AppColors.primary),
                    _buildDriverStatChip(
                        'Total KM Driven',
                        '${driver.totalKilometersDriven} km',
                        Icons.route_rounded,
                        const Color(0xFF2563EB)),
                    _buildDriverStatChip(
                        'Traffic Violations',
                        '${driver.violationsCount}',
                        Icons.warning_amber_rounded,
                        driver.violationsCount > 0
                            ? const Color(0xFFDC2626)
                            : AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DriverReportDetailDialog(
                        driver: driver,
                        controller: controller,
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        size: 14, color: Color(0xFFDC2626)),
                    label: const Text('View Report & PDF',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  if (onViewSeatbeltPhotos != null)
                    OutlinedButton.icon(
                      onPressed: onViewSeatbeltPhotos,
                      icon: const Icon(Icons.photo_library_outlined, size: 14),
                      label: const Text('Seatbelt Photos',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: driverIndex == -1
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (_) => _DriverComplianceDialog(
                                driver: driver,
                                driverIndex: driverIndex,
                                controller: controller,
                              ),
                            ),
                    icon: const Icon(Icons.edit_note_rounded, size: 14),
                    label: const Text('Update Compliance & Stats',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericCard(BuildContext context) {
    final (title, subtitle, badge) = _content;
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.blueSoft,
            foregroundColor: AppColors.blue,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompact && badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCompact && badge != null) ...[
                Chip(label: Text(badge), visualDensity: VisualDensity.compact),
                const SizedBox(width: 4),
              ],
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (record is TruckModel) {
      return _buildTruckCard(context, record as TruckModel);
    }
    if (record is DriverProfile) {
      return _buildDriverCard(context, record as DriverProfile);
    }
    return _buildGenericCard(context);
  }
}

class _FastagRechargeDialog extends StatefulWidget {
  const _FastagRechargeDialog({
    required this.vehicle,
    required this.truckIndex,
    required this.controller,
  });

  final TruckModel vehicle;
  final int truckIndex;
  final PlannerController controller;

  @override
  State<_FastagRechargeDialog> createState() => _FastagRechargeDialogState();
}

class _FastagRechargeDialogState extends State<_FastagRechargeDialog> {
  final _amountCtrl = TextEditingController(text: '1000');
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _provider = 'Paytm Payments Bank';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid recharge amount'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final ref = _refCtrl.text.trim().isNotEmpty
        ? _refCtrl.text.trim()
        : 'FTG-${now.millisecondsSinceEpoch.toString().substring(7)}';

    await widget.controller.rechargeFastag(
      vehicleCode: widget.vehicle.code,
      amount: amt,
      refNumber: ref,
      provider: _provider,
      notes: _notesCtrl.text.trim(),
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'FASTag recharged with ₹${amt.toStringAsFixed(0)} successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('FASTag Recharge · ${widget.vehicle.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance: ₹${widget.vehicle.fastagBalance.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.slate),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Recharge Amount (₹)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(
                  labelText: 'FASTag Bank / Issuer', isDense: true),
              items: const [
                DropdownMenuItem(
                    value: 'Paytm Payments Bank',
                    child: Text('Paytm Payments Bank')),
                DropdownMenuItem(
                    value: 'ICICI Bank FASTag',
                    child: Text('ICICI Bank FASTag')),
                DropdownMenuItem(
                    value: 'SBI FASTag', child: Text('SBI FASTag')),
                DropdownMenuItem(
                    value: 'Axis Bank FASTag', child: Text('Axis Bank FASTag')),
                DropdownMenuItem(
                    value: 'IDFC FIRST Bank', child: Text('IDFC FIRST Bank')),
                DropdownMenuItem(
                    value: 'Other Issuer', child: Text('Other Issuer')),
              ],
              onChanged: (val) =>
                  setState(() => _provider = val ?? 'Paytm Payments Bank'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Recharge Ref / UTR / Order ID',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Recharge Now')),
      ],
    );
  }
}

class _FastagHistoryDialog extends StatelessWidget {
  const _FastagHistoryDialog({required this.vehicle});
  final TruckModel vehicle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('FASTag Recharge History · ${vehicle.name}'),
      content: SizedBox(
        width: 480,
        child: vehicle.fastagRecharges.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No FASTag recharge transactions recorded yet.',
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: vehicle.fastagRecharges.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final item = vehicle.fastagRecharges[
                      vehicle.fastagRecharges.length - 1 - idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.toll_rounded, size: 20),
                    ),
                    title: Text(
                        '₹${item.amount.toStringAsFixed(0)} · ${item.provider}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                        'Date: ${item.date} · Ref: ${item.rechargeId}${item.notes.isNotEmpty ? "\nNotes: ${item.notes}" : ""}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate)),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class _VehicleComplianceDialog extends StatefulWidget {
  const _VehicleComplianceDialog({
    required this.vehicle,
    required this.truckIndex,
    required this.controller,
  });

  final TruckModel vehicle;
  final int truckIndex;
  final PlannerController controller;

  @override
  State<_VehicleComplianceDialog> createState() =>
      _VehicleComplianceDialogState();
}

class _VehicleComplianceDialogState extends State<_VehicleComplianceDialog> {
  late final TextEditingController rcCtrl;
  late final TextEditingController pucCtrl;
  late final TextEditingController fitnessCtrl;
  late final TextEditingController aitpCtrl;
  late final TextEditingController stateTaxCtrl;
  late final TextEditingController insuranceCtrl;
  late final TextEditingController nextServiceCtrl;
  late final TextEditingController odoCtrl;

  @override
  void initState() {
    super.initState();
    rcCtrl = TextEditingController(text: widget.vehicle.rcExpiry);
    pucCtrl = TextEditingController(text: widget.vehicle.pucExpiry);
    fitnessCtrl = TextEditingController(text: widget.vehicle.fitnessExpiry);
    aitpCtrl = TextEditingController(text: widget.vehicle.allIndiaPermitExpiry);
    stateTaxCtrl =
        TextEditingController(text: widget.vehicle.statePermitTaxExpiry);
    insuranceCtrl = TextEditingController(text: widget.vehicle.insuranceExpiry);
    nextServiceCtrl =
        TextEditingController(text: widget.vehicle.nextServiceKm.toString());
    odoCtrl = TextEditingController(
        text: widget.vehicle.currentOdometerKm.toString());
  }

  @override
  void dispose() {
    rcCtrl.dispose();
    pucCtrl.dispose();
    fitnessCtrl.dispose();
    aitpCtrl.dispose();
    stateTaxCtrl.dispose();
    insuranceCtrl.dispose();
    nextServiceCtrl.dispose();
    odoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nextKm = int.tryParse(nextServiceCtrl.text.trim()) ??
        widget.vehicle.nextServiceKm;
    final odoKm =
        int.tryParse(odoCtrl.text.trim()) ?? widget.vehicle.currentOdometerKm;

    await widget.controller.updateVehicleCompliance(
      vehicleCode: widget.vehicle.code,
      rcExpiry: rcCtrl.text.trim(),
      pucExpiry: pucCtrl.text.trim(),
      fitnessExpiry: fitnessCtrl.text.trim(),
      allIndiaPermitExpiry: aitpCtrl.text.trim(),
      statePermitTaxExpiry: stateTaxCtrl.text.trim(),
      insuranceExpiry: insuranceCtrl.text.trim(),
      nextServiceKm: nextKm,
      currentOdometerKm: odoKm,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle compliance dates updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Compliance · ${widget.vehicle.name}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: rcCtrl,
                decoration: const InputDecoration(
                    labelText: 'RC Registration Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pucCtrl,
                decoration: const InputDecoration(
                    labelText: 'PUC Certificate Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fitnessCtrl,
                decoration: const InputDecoration(
                    labelText: 'Fitness Certificate Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: aitpCtrl,
                decoration: const InputDecoration(
                    labelText: 'All India Permit (AITP) Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stateTaxCtrl,
                decoration: const InputDecoration(
                    labelText: 'State Permit Tax Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: insuranceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Vehicle Insurance Expiry', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: odoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Current Odometer (km)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextServiceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Next Service Due at (km)', isDense: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save Compliance')),
      ],
    );
  }
}

class _TyreTrackingDialog extends StatefulWidget {
  const _TyreTrackingDialog({
    required this.vehicle,
    required this.truckIndex,
    required this.controller,
  });

  final TruckModel vehicle;
  final int truckIndex;
  final PlannerController controller;

  @override
  State<_TyreTrackingDialog> createState() => _TyreTrackingDialogState();
}

class _TyreTrackingDialogState extends State<_TyreTrackingDialog> {
  void _openAddTyreDialog() {
    final tyreNoCtrl = TextEditingController();
    final fittingKmCtrl = TextEditingController(
        text: widget.vehicle.currentOdometerKm.toString());
    final currentKmCtrl = TextEditingController(
        text: widget.vehicle.currentOdometerKm.toString());
    final costCtrl = TextEditingController(text: '14500');
    final notesCtrl = TextEditingController();
    String position = 'Front Left';
    String condition = 'Good';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Tyre Replacement'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tyreNoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Tyre Serial / Brand Number', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: position,
                    decoration: const InputDecoration(
                        labelText: 'Position', isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'Front Left', child: Text('Front Left')),
                      DropdownMenuItem(
                          value: 'Front Right', child: Text('Front Right')),
                      DropdownMenuItem(
                          value: 'Rear Left Outer',
                          child: Text('Rear Left Outer')),
                      DropdownMenuItem(
                          value: 'Rear Left Inner',
                          child: Text('Rear Left Inner')),
                      DropdownMenuItem(
                          value: 'Rear Right Outer',
                          child: Text('Rear Right Outer')),
                      DropdownMenuItem(
                          value: 'Rear Right Inner',
                          child: Text('Rear Right Inner')),
                      DropdownMenuItem(value: 'Spare', child: Text('Spare')),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => position = val ?? 'Front Left'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fittingKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Fitting Odometer (km)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Current Odometer (km)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Replacement Cost (₹)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: condition,
                    decoration: const InputDecoration(
                        labelText: 'Condition', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Good', child: Text('Good')),
                      DropdownMenuItem(
                          value: 'Moderate', child: Text('Moderate')),
                      DropdownMenuItem(
                          value: 'Needs Replacement',
                          child: Text('Needs Replacement')),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => condition = val ?? 'Good'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)', isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final fitKm = int.tryParse(fittingKmCtrl.text.trim()) ?? 0;
                final curKm = int.tryParse(currentKmCtrl.text.trim()) ?? fitKm;
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                final now = DateTime.now();
                final dateStr =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                final tyre = TyreRecord(
                  tyreNumber: tyreNoCtrl.text.trim().isNotEmpty
                      ? tyreNoCtrl.text.trim()
                      : 'TYR-${now.millisecondsSinceEpoch.toString().substring(8)}',
                  position: position,
                  fittingDate: dateStr,
                  fittingKm: fitKm,
                  currentKm: curKm,
                  replacementCost: cost,
                  condition: condition,
                  notes: notesCtrl.text.trim(),
                );

                await widget.controller.addTyreRecord(
                  vehicleCode: widget.vehicle.code,
                  tyre: tyre,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Add Tyre'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tyres = widget.vehicle.tyres;

    return AlertDialog(
      title: Text('Tyre Management · ${widget.vehicle.name}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Track tyre fitting, run distance, and replacement costs.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openAddTyreDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text('Add Tyre',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tyres.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No tyres recorded for this vehicle yet.',
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tyres.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final tyre = tyres[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE2E8F0),
                        foregroundColor: Color(0xFF1E293B),
                        child: Icon(Icons.album_outlined, size: 20),
                      ),
                      title: Text('${tyre.position} · ${tyre.tyreNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(
                        'KM Run: ${tyre.kmRun} km · Fit: ${tyre.fittingKm} km · Current: ${tyre.currentKm} km\nCondition: ${tyre.condition} · Cost: ₹${tyre.replacementCost.toStringAsFixed(0)}${tyre.notes.isNotEmpty ? " · ${tyre.notes}" : ""}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class _VehicleServiceDialog extends StatefulWidget {
  const _VehicleServiceDialog({
    required this.vehicle,
    required this.truckIndex,
    required this.controller,
  });

  final TruckModel vehicle;
  final int truckIndex;
  final PlannerController controller;

  @override
  State<_VehicleServiceDialog> createState() => _VehicleServiceDialogState();
}

class _VehicleServiceDialogState extends State<_VehicleServiceDialog> {
  void _openAddServiceDialog() {
    final odoCtrl = TextEditingController();
    final nextServiceCtrl = TextEditingController();
    final garageCtrl = TextEditingController();
    final mechanicCtrl = TextEditingController();
    final partsCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool oil = false;
    bool brake = false;
    bool battery = false;
    bool coolant = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Service & Repair'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: odoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Actual Odometer Reading (km)',
                      helperText: widget.vehicle.currentOdometerKm > 0
                          ? 'Last recorded: ${widget.vehicle.currentOdometerKm} km'
                          : 'Enter reading shown on vehicle meter',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nextServiceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Next Service Due KM (optional)',
                      helperText: 'Blank chhodein—automatic KM add nahi hoga',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: garageCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Garage / Service Center Name',
                        isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mechanicCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Mechanic Name / Contact', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Service / Repair Cost (₹)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: partsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Spare Parts Replaced', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Notes / Inclusions', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Service Checks Completed:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Engine Oil Changed'),
                    value: oil,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => oil = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Brakes Checked & Tuned'),
                    value: brake,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => brake = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Battery Health Inspected'),
                    value: battery,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) =>
                        setDialogState(() => battery = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Coolant & Fluids Checked'),
                    value: coolant,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) =>
                        setDialogState(() => coolant = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final odo = int.tryParse(odoCtrl.text.trim()) ?? 0;
                final nextServiceKm = int.tryParse(nextServiceCtrl.text.trim());
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                final now = DateTime.now();
                final dateStr =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                final service = VehicleServiceRecord(
                  id: 'SRV-${now.millisecondsSinceEpoch}',
                  serviceDate: dateStr,
                  odometerKm: odo,
                  garageName: garageCtrl.text.trim().isNotEmpty
                      ? garageCtrl.text.trim()
                      : '',
                  mechanicDetails: mechanicCtrl.text.trim(),
                  engineOilChanged: oil,
                  brakeChecked: brake,
                  batteryChecked: battery,
                  coolantChecked: coolant,
                  sparePartsReplaced: partsCtrl.text.trim(),
                  repairCost: cost,
                  notes: notesCtrl.text.trim(),
                );

                final error = await widget.controller.addVehicleServiceLog(
                  vehicleCode: widget.vehicle.code,
                  service: service,
                  nextServiceKm: nextServiceKm,
                );
                if (!ctx.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save Service Log'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.vehicle.serviceHistory;

    return AlertDialog(
      title: Text('Service & Maintenance · ${widget.vehicle.name}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.vehicle.isServiceDueSoon
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF0FDF4),
                border: Border.all(
                  color: widget.vehicle.isServiceDueSoon
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFBBF7D0),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 20,
                    color: widget.vehicle.isServiceDueSoon
                        ? const Color(0xFFB45309)
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next Service: ${widget.vehicle.nextServiceKm} km (Due in ${widget.vehicle.kmUntilNextService} km)\nCurrent Odometer: ${widget.vehicle.currentOdometerKm} km',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.vehicle.isServiceDueSoon
                            ? const Color(0xFF92400E)
                            : const Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recorded Garage & Maintenance Logs:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openAddServiceDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text('Add Service Log',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No service logs recorded for this vehicle yet.',
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = history[history.length - 1 - idx];
                    final checks = [
                      if (item.engineOilChanged) 'Oil Changed',
                      if (item.brakeChecked) 'Brakes Tuned',
                      if (item.batteryChecked) 'Battery OK',
                      if (item.coolantChecked) 'Coolant OK',
                    ].join(' · ');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDCFCE7),
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.car_repair_rounded, size: 20),
                      ),
                      title: Text(
                          '${item.garageName} · ₹${item.repairCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(
                        'Date: ${item.serviceDate} · Odometer: ${item.odometerKm} km${item.mechanicDetails.isNotEmpty ? " · Mech: ${item.mechanicDetails}" : ""}\nChecks: $checks${item.sparePartsReplaced.isNotEmpty ? "\nParts: ${item.sparePartsReplaced}" : ""}${item.notes.isNotEmpty ? "\nNotes: ${item.notes}" : ""}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

class _DriverComplianceDialog extends StatefulWidget {
  const _DriverComplianceDialog({
    required this.driver,
    required this.driverIndex,
    required this.controller,
  });

  final DriverProfile driver;
  final int driverIndex;
  final PlannerController controller;

  @override
  State<_DriverComplianceDialog> createState() =>
      _DriverComplianceDialogState();
}

class _DriverComplianceDialogState extends State<_DriverComplianceDialog> {
  late final TextEditingController dlCtrl;
  late final TextEditingController dlExpCtrl;
  late final TextEditingController insCtrl;
  late final TextEditingController insExpCtrl;
  late final TextEditingController tripsCtrl;
  late final TextEditingController kmCtrl;
  late final TextEditingController violationsCtrl;

  @override
  void initState() {
    super.initState();
    dlCtrl = TextEditingController(text: widget.driver.licenseNumber);
    dlExpCtrl = TextEditingController(text: widget.driver.licenseExpiry);
    insCtrl = TextEditingController(text: widget.driver.driverInsurancePolicy);
    insExpCtrl =
        TextEditingController(text: widget.driver.driverInsuranceExpiry);
    tripsCtrl = TextEditingController(
        text: widget.driver.completedTripsCount.toString());
    kmCtrl = TextEditingController(
        text: widget.driver.totalKilometersDriven.toString());
    violationsCtrl =
        TextEditingController(text: widget.driver.violationsCount.toString());
  }

  @override
  void dispose() {
    dlCtrl.dispose();
    dlExpCtrl.dispose();
    insCtrl.dispose();
    insExpCtrl.dispose();
    tripsCtrl.dispose();
    kmCtrl.dispose();
    violationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final trips = int.tryParse(tripsCtrl.text.trim()) ??
        widget.driver.completedTripsCount;
    final km =
        int.tryParse(kmCtrl.text.trim()) ?? widget.driver.totalKilometersDriven;
    final violations = int.tryParse(violationsCtrl.text.trim()) ??
        widget.driver.violationsCount;

    await widget.controller.updateDriverCompliance(
      driverEmail: widget.driver.email,
      licenseNumber: dlCtrl.text.trim(),
      licenseExpiry: dlExpCtrl.text.trim(),
      driverInsurancePolicy: insCtrl.text.trim(),
      driverInsuranceExpiry: insExpCtrl.text.trim(),
      completedTripsCount: trips,
      totalKilometersDriven: km,
      violationsCount: violations,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Driver compliance and performance stats updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Compliance & Stats · ${widget.driver.name}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dlCtrl,
                decoration: const InputDecoration(
                    labelText: 'Driving License (DL) Number', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dlExpCtrl,
                decoration: const InputDecoration(
                    labelText: 'DL Expiry Date (YYYY-MM-DD)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: insCtrl,
                decoration: const InputDecoration(
                    labelText: 'Driver Insurance Policy / Insurer',
                    isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: insExpCtrl,
                decoration: const InputDecoration(
                    labelText: 'Driver Insurance Expiry Date', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tripsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Completed Trips Count', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: kmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Total Kilometers Driven (km)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: violationsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Traffic Violations / Challans Count',
                    isDense: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _submit, child: const Text('Save Driver Compliance')),
      ],
    );
  }
}

class AddRecordDialog extends StatefulWidget {
  const AddRecordDialog({required this.module, super.key});
  final OperationsModule module;

  @override
  State<AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<AddRecordDialog> {
  final fields = List.generate(6, (_) => TextEditingController());
  String severity = 'info';
  String driverPhoto = '';
  bool invalid = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  List<String> get labels => switch (widget.module) {
        OperationsModule.drivers => [
            'Driver full name',
            'Driver Login ID / Email',
            'Phone number (optional)',
            'Login PIN / Password',
            'Assigned vehicle number (optional)',
          ],
        OperationsModule.vehicles => [
            'Vehicle number',
            'Vehicle model',
            'Wheels / axles',
            'Payload capacity',
            'Maximum speed (km/h)',
            'GPS Tracker IMEI (optional)',
          ],
        OperationsModule.trips => [
            'Trip reference',
            'Starting location',
            'Destination',
          ],
        OperationsModule.alerts => ['Alert title', 'Details'],
      };

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
    final values = labels
        .asMap()
        .entries
        .map((entry) => fields[entry.key].text.trim())
        .toList();

    if (widget.module == OperationsModule.drivers) {
      if (values[0].isEmpty || values[1].isEmpty) {
        setState(() {
          invalid = true;
          errorMessage = 'Driver Name and Login ID/Email are required.';
        });
        return;
      }
      if (values[0].length < 3) {
        setState(() {
          invalid = true;
          errorMessage = 'Driver name must be at least 3 characters.';
        });
        return;
      }
      if (RegExp(r'^\d+$').hasMatch(values[0])) {
        setState(() {
          invalid = true;
          errorMessage = 'Driver name cannot be only numbers.';
        });
        return;
      }
      final pin = values[3].trim();
      if (pin.length < 8 || pin.length > 72) {
        setState(() {
          invalid = true;
          errorMessage =
              'Please set a secure driver PIN / password (minimum 8 to 72 characters).';
        });
        return;
      }
      final record = DriverProfile(
        values[0],
        values[1],
        photo: driverPhoto,
        phone: values[2],
        password: pin,
        assignedVehicle: values[4],
        role: 'driver',
        createdAt: DateTime.now().toIso8601String(),
      );
      Navigator.pop(context, record);
      return;
    }

    final isVehicles = widget.module == OperationsModule.vehicles;
    final requiredValues = isVehicles ? values.take(5) : values;

    if (requiredValues.any((value) => value.isEmpty)) {
      setState(() {
        invalid = true;
        errorMessage = 'Please complete all required fields.';
      });
      return;
    }

    final speed = isVehicles ? int.tryParse(values[4]) : null;
    if (isVehicles && (speed == null || speed <= 0)) {
      setState(() {
        invalid = true;
        errorMessage = 'Enter a valid positive speed number.';
      });
      return;
    }

    final Object record = switch (widget.module) {
      OperationsModule.drivers =>
        DriverProfile(values[0], values[1], photo: driverPhoto),
      OperationsModule.vehicles => TruckModel(
          code: values[0].toUpperCase(),
          name: values[1],
          axles: values[2],
          capacity: values[3],
          maxSpeed: speed ?? 60,
          imei: values.length > 5 ? values[5].trim() : '',
        ),
      OperationsModule.trips => TripRecord(
          reference: values[0],
          origin: values[1],
          destination: values[2],
        ),
      OperationsModule.alerts => OperationsAlert(
          title: values[0],
          details: values[1],
          severity: severity,
          driverPhoto: driverPhoto,
          createdAt: DateTime.now().toIso8601String(),
        ),
    };
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.module == OperationsModule.trips) {
      return const TripMapDialog();
    }

    return AlertDialog(
      title: Text(widget.module == OperationsModule.drivers
          ? 'Create Driver Account'
          : 'Add ${widget.module.singular}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.module == OperationsModule.drivers) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: AppColors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin Driver Account Creation: Enter driver details and assign their secure login PIN.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              for (final entry in labels.asMap().entries) ...[
                TextField(
                  controller: fields[entry.key],
                  autofocus: entry.key == 0,
                  keyboardType: entry.value.contains('speed')
                      ? TextInputType.number
                      : (entry.value.contains('Email') ||
                              entry.value.contains('ID'))
                          ? TextInputType.emailAddress
                          : entry.value.contains('Phone')
                              ? TextInputType.phone
                              : TextInputType.text,
                  decoration: InputDecoration(labelText: entry.value),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.module == OperationsModule.drivers) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
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
                          const Icon(Icons.photo_camera_outlined,
                              size: 15, color: AppColors.slate),
                          const SizedBox(width: 6),
                          const Text(
                            'Driver Photo',
                            style: TextStyle(
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
                              child: const Text(
                                'Photo Ready',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (driverPhoto.isNotEmpty)
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: _buildRecordBase64Image(driverPhoto),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _captureCameraPhoto,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 12),
                                    label: const Text('Retake',
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
                                        size: 12,
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
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _captureCameraPhoto,
                                icon: const Icon(Icons.photo_camera_rounded,
                                    size: 13),
                                label: const Text('Camera',
                                    style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _uploadPhoto,
                                icon: const Icon(Icons.upload_file_rounded,
                                    size: 13),
                                label: const Text('Upload File',
                                    style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.module == OperationsModule.alerts)
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(
                        value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) => severity = value ?? 'info',
                ),
              if (invalid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage.isNotEmpty
                        ? errorMessage
                        : 'Complete every field with valid information.',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// end  of  the  page
