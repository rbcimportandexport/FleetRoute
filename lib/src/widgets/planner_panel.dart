import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/reverse_geocoding_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';

class PlannerPanel extends StatefulWidget {
  const PlannerPanel({
    required this.controller,
    this.scrollController,
    this.showDragHandle = false,
    this.scrollable = true,
    super.key,
  });

  final PlannerController controller;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final bool scrollable;

  @override
  State<PlannerPanel> createState() => _PlannerPanelState();
}

class _PlannerPanelState extends State<PlannerPanel> {
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  final List<TextEditingController> _stopControllers = [];
  bool _fetchingGps = false;

  @override
  void initState() {
    super.initState();
    originController = TextEditingController();
    destinationController = TextEditingController();
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    for (final c in _stopControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncStopControllers() {
    while (_stopControllers.length < widget.controller.stops.length) {
      final index = _stopControllers.length;
      final c = TextEditingController(text: widget.controller.stops[index]);
      _stopControllers.add(c);
    }
    while (_stopControllers.length > widget.controller.stops.length) {
      _stopControllers.removeLast().dispose();
    }
    for (int i = 0; i < widget.controller.stops.length; i++) {
      if (_stopControllers[i].text != widget.controller.stops[i]) {
        _stopControllers[i].text = widget.controller.stops[i];
      }
    }
  }

  Future<void> _useCurrentLocationForOrigin() async {
    if (_fetchingGps) return;
    setState(() => _fetchingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('GPS permission is required for live location.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation),
      );
      final point = LatLng(pos.latitude, pos.longitude);
      final place = await ReverseGeocodingService.labelFor(point);
      if (!mounted) return;
      originController.text = place;
      widget.controller.setOrigin(place);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Current Location set: $place. Map par pin ko drag karke exact building par adjust kar sakte hain.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read current GPS location.')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  void _swap() {
    widget.controller.swapLocations();
    originController.text = widget.controller.origin;
    destinationController.text = widget.controller.destination;
    _syncStopControllers();
  }

  Future<void> _addDriver() async {
    final result = await showDialog<DriverProfile>(
      context: context,
      builder: (context) => const _AddDriverDialog(),
    );
    if (result != null) {
      try {
        await widget.controller.addDriver(result);
      } on ArgumentError catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message?.toString() ?? 'Invalid driver details.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDrivers() => showDialog<void>(
        context: context,
        builder: (context) => _DriverListDialog(controller: widget.controller),
      );

  Future<void> _openLiveRoute() async {
    final travelMode =
        widget.controller.vehicle == VehicleType.bike ? 'bicycling' : 'driving';
    final queryParams = <String, String>{
      'api': '1',
      'origin': widget.controller.origin.trim(),
      'destination': widget.controller.destination.trim(),
      'travelmode': travelMode,
      'dir_action': 'navigate',
    };

    final stops =
        widget.controller.stops.where((s) => s.trim().isNotEmpty).toList();
    if (stops.isNotEmpty) {
      queryParams['waypoints'] = stops.join('|');
    }

    final routeUri = Uri.https('www.google.com', '/maps/dir/', queryParams);

    final opened = await launchUrl(
      routeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (originController.text != widget.controller.origin) {
          originController.text = widget.controller.origin;
        }
        if (destinationController.text != widget.controller.destination) {
          destinationController.text = widget.controller.destination;
        }
        _syncStopControllers();
        final content = Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showDragHandle)
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3DCE8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const Text(
                'LIVE NAVIGATION',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Route planner',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),

              // 1. ROUTE INPUTS (Pickup -> Stops -> Drop) FIRST
              _RouteInputs(
                controller: widget.controller,
                originController: originController,
                destinationController: destinationController,
                stopControllers: _stopControllers,
                onSwap: _swap,
                onUseCurrentLocation: _useCurrentLocationForOrigin,
                fetchingGps: _fetchingGps,
                onAddStop: () {
                  widget.controller.addStop('');
                  _syncStopControllers();
                },
                onRemoveStop: (index) {
                  widget.controller.removeStop(index);
                  _syncStopControllers();
                },
                onClearOrigin: () {
                  widget.controller.setOrigin('');
                  originController.clear();
                },
                onClearDestination: () {
                  widget.controller.setDestination('');
                  destinationController.clear();
                },
                onClearStops: () {
                  widget.controller.clearStops();
                  _syncStopControllers();
                },
                onContinueFromDestination: () {
                  final currentDest = widget.controller.destination;
                  widget.controller.continueFromDestination();
                  originController.text = currentDest;
                  destinationController.clear();
                  _syncStopControllers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Pichla Drop ab naya Pickup ban gaya ($currentDest). Agli manzil chuniye ya map par tap karein.'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // 2. QUICK ROUTE PRESETS (e.g. Bardoli -> Surat -> Kamrej)
              _QuickRoutePresets(
                controller: widget.controller,
                originController: originController,
                destinationController: destinationController,
              ),
              const SizedBox(height: 14),

              // 3. PRIMARY ACTION: START NAVIGATION
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: widget.controller.canStartNavigation
                      ? () {
                          if (widget.controller.isNavigating) {
                            widget.controller.stopNavigation();
                          } else {
                            widget.controller.startNavigation();
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.controller.isNavigating
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    disabledBackgroundColor: const Color(0xFFE8EDF5),
                    disabledForegroundColor: const Color(0xFFA8B4C6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: widget.controller.canShowRoute ? 3 : 0,
                  ),
                  icon: Icon(
                    widget.controller.isNavigating
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                    size: 20,
                  ),
                  label: Text(
                    widget.controller.isNavigating
                        ? 'STOP NAVIGATION (रोकें)'
                        : 'START NAVIGATION (लाइव शुरू करें)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed:
                      widget.controller.canShowRoute ? _openLiveRoute : null,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Open in Google Maps',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // 4. VEHICLE & FLEET SETTINGS
              const _SectionHeader(
                title: 'VEHICLE TYPE',
                action: 'Select Profile',
              ),
              const SizedBox(height: 8),
              Row(
                children: VehicleType.values
                    .map(
                      (vehicle) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: vehicle == VehicleType.truck ? 0 : 6,
                          ),
                          child: _VehicleCard(
                            vehicle: vehicle,
                            selected: widget.controller.vehicle == vehicle,
                            onTap: () =>
                                widget.controller.selectVehicle(vehicle),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: widget.controller.vehicle == VehicleType.truck
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _TruckModels(controller: widget.controller),
                      )
                    : const SizedBox(height: 4),
              ),
              const SizedBox(height: 14),
              _DriverRow(
                controller: widget.controller,
                onAdd: widget.controller.isAdmin ? _addDriver : null,
                onOpen: _showDrivers,
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              const _JourneyHelp(),
            ],
          ),
        );

        return ColoredBox(
          color: Colors.white,
          child: widget.scrollable
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  controller: widget.scrollController,
                  child: content,
                )
              : content,
        );
        /* Legacy duplicated panel body removed. */
        /*
            child: Column(children: [
                if (widget.showDragHandle)
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3DCE8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                const Text(
                  'LIVE NAVIGATION',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Route planner',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // 1. ROUTE INPUTS (Pickup -> Stops -> Drop) FIRST
                _RouteInputs(
                  controller: widget.controller,
                  originController: originController,
                  destinationController: destinationController,
                  stopControllers: _stopControllers,
                  onSwap: _swap,
                  onUseCurrentLocation: _useCurrentLocationForOrigin,
                  fetchingGps: _fetchingGps,
                  onAddStop: () {
                    widget.controller.addStop('');
                    _syncStopControllers();
                  },
                  onRemoveStop: (index) {
                    widget.controller.removeStop(index);
                    _syncStopControllers();
                  },
                  onClearOrigin: () {
                    widget.controller.setOrigin('');
                    originController.clear();
                  },
                  onClearDestination: () {
                    widget.controller.setDestination('');
                    destinationController.clear();
                  },
                  onClearStops: () {
                    widget.controller.clearStops();
                    _syncStopControllers();
                  },
                  onContinueFromDestination: () {
                    final currentDest = widget.controller.destination;
                    widget.controller.continueFromDestination();
                    originController.text = currentDest;
                    destinationController.clear();
                    _syncStopControllers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Pichla Drop ab naya Pickup ban gaya ($currentDest). Agli manzil chuniye ya map par tap karein.'),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 2. QUICK ROUTE PRESETS (e.g. Bardoli -> Surat -> Kamrej)
                _QuickRoutePresets(
                  controller: widget.controller,
                  originController: originController,
                  destinationController: destinationController,
                ),
                const SizedBox(height: 14),

                // 3. PRIMARY ACTION: START NAVIGATION
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: widget.controller.canStartNavigation
                        ? () {
                            if (widget.controller.isNavigating) {
                              widget.controller.stopNavigation();
                            } else {
                              widget.controller.startNavigation();
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.controller.isNavigating
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFFE8EDF5),
                      disabledForegroundColor: const Color(0xFFA8B4C6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: widget.controller.canShowRoute ? 3 : 0,
                    ),
                    icon: Icon(
                      widget.controller.isNavigating
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 20,
                    ),
                    label: Text(
                      widget.controller.isNavigating
                          ? 'STOP NAVIGATION (रोकें)'
                          : 'START NAVIGATION (लाइव शुरू करें)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.controller.canShowRoute ? _openLiveRoute : null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'Open in Google Maps',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // 4. VEHICLE & FLEET SETTINGS
                const _SectionHeader(
                  title: 'VEHICLE TYPE',
                  action: 'Select Profile',
                ),
                const SizedBox(height: 8),
                Row(
                  children: VehicleType.values
                      .map(
                        (vehicle) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: vehicle == VehicleType.truck ? 0 : 6,
                            ),
                            child: _VehicleCard(
                              vehicle: vehicle,
                              selected: widget.controller.vehicle == vehicle,
                              onTap: () =>
                                  widget.controller.selectVehicle(vehicle),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: widget.controller.vehicle == VehicleType.truck
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _TruckModels(controller: widget.controller),
                        )
                      : const SizedBox(height: 4),
                ),
                const SizedBox(height: 14),
                _DriverRow(
                  controller: widget.controller,
                  onAdd: widget.controller.isAdmin ? _addDriver : null,
                  onOpen: _showDrivers,
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                const _JourneyHelp(),
              ],),
        */
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .35,
          ),
        ),
        Text(
          action,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });
  final PlannerController controller;
  final VoidCallback? onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.field,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.isLoading
                              ? 'Loading drivers...'
                              : controller.drivers.isEmpty
                                  ? 'Drivers List (0)'
                                  : controller.drivers.length == 1
                                      ? controller.drivers.first.name
                                      : '${controller.drivers.first.name}  (+${controller.drivers.length - 1})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF8E8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${controller.drivers.length} Ready',
                          style: const TextStyle(
                            color: Color(0xFF168547),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Driver',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final VehicleType vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueSoft : AppColors.field,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.blue : const Color(0xFFE7EDF6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                vehicle.icon,
                size: 16,
                color: selected ? Colors.white : AppColors.slate,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                vehicle.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.blue : AppColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TruckModels extends StatelessWidget {
  const _TruckModels({required this.controller});
  final PlannerController controller;

  Future<void> _addModel(BuildContext context) async {
    final model = await showDialog<TruckModel>(
      context: context,
      builder: (context) => const _AddTruckModelDialog(),
    );
    if (model != null) {
      try {
        await controller.addTruckModel(model);
      } on ArgumentError catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(e.message?.toString() ?? 'Invalid vehicle details.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TRUCK MODELS & PAYLOAD',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .35,
                  ),
                ),
              ),
              if (controller.isAdmin)
                TextButton.icon(
                  onPressed: () => _addModel(context),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Add model'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (controller.truckModels.isEmpty)
            InkWell(
              onTap: controller.isAdmin ? () => _addModel(context) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        controller.isAdmin
                            ? 'No vehicle models added · Tap to add'
                            : 'No vehicle models added',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.88,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemCount: controller.truckModels.length,
              itemBuilder: (context, index) {
                final model = controller.truckModels[index];
                final selected = controller.truckIndex == index;
                return InkWell(
                  onTap: () => controller.selectTruck(index),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blueSoft : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.blue : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE9F1FC),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    model.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF4773A9),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${model.maxSpeed} km/h',
                              style: const TextStyle(
                                color: AppColors.orange,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (controller.isAdmin) ...[
                              const SizedBox(width: 3),
                              InkWell(
                                onTap: () async =>
                                    controller.removeTruckModel(index),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          model.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 10,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${model.axles}  ·  Cap: ${model.capacity}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RouteInputs extends StatelessWidget {
  const _RouteInputs({
    required this.controller,
    required this.originController,
    required this.destinationController,
    required this.stopControllers,
    required this.onSwap,
    required this.onUseCurrentLocation,
    required this.fetchingGps,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onClearOrigin,
    required this.onClearDestination,
    required this.onClearStops,
    required this.onContinueFromDestination,
  });

  final PlannerController controller;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final List<TextEditingController> stopControllers;
  final VoidCallback onSwap;
  final VoidCallback onUseCurrentLocation;
  final bool fetchingGps;
  final VoidCallback onAddStop;
  final ValueChanged<int> onRemoveStop;
  final VoidCallback onClearOrigin;
  final VoidCallback onClearDestination;
  final VoidCallback onClearStops;
  final VoidCallback onContinueFromDestination;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LocationField(
              label: 'From (शुरुआती स्थान / Pickup)',
              hint: 'Choose starting location or tap map',
              controller: originController,
              dot: false,
              suffix: Icons.my_location_rounded,
              onSuffixTap: onUseCurrentLocation,
              onClear: onClearOrigin,
              isLoading: fetchingGps,
              onChanged: controller.setOrigin,
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < controller.stops.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _StopLocationField(
                  index: i,
                  controller: i < stopControllers.length
                      ? stopControllers[i]
                      : TextEditingController(text: controller.stops[i]),
                  onChanged: (val) => controller.updateStop(i, val),
                  onRemove: () => onRemoveStop(i),
                ),
              ),
            ],
            _LocationField(
              label: 'To (अंतिम मंज़िल / Drop)',
              hint: 'Choose destination or tap map',
              controller: destinationController,
              dot: true,
              suffix: Icons.search_rounded,
              onClear: onClearDestination,
              onChanged: controller.setDestination,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onAddStop,
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  label: Text(
                    controller.stops.isEmpty
                        ? '+ Add Via Stop (स्टॉप जोड़ें)'
                        : '+ Add Another (और जोड़ें)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (controller.destination.trim().isNotEmpty)
                  TextButton.icon(
                    onPressed: onContinueFromDestination,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    label: const Text(
                      'Drop se aage jayein',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (controller.stops.isNotEmpty)
                  TextButton(
                    onPressed: onClearStops,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear stops',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (controller.stops.isEmpty)
          Positioned(
            right: 10,
            top: 74,
            child: Material(
              elevation: 2,
              shape: const CircleBorder(),
              color: Colors.white,
              child: IconButton(
                onPressed: onSwap,
                tooltip: 'Swap locations',
                icon: const Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: AppColors.slate,
                ),
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                padding: EdgeInsets.zero,
              ),
            ),
          )
        else
          Positioned(
            right: 10,
            top: 24,
            child: Material(
              elevation: 2,
              shape: const CircleBorder(),
              color: Colors.white,
              child: IconButton(
                onPressed: onSwap,
                tooltip: 'Reverse route direction',
                icon: const Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: AppColors.slate,
                ),
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }
}

class _StopLocationField extends StatelessWidget {
  const _StopLocationField({
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 21,
          height: 53,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              ...List.generate(
                3,
                (_) => Container(
                  width: 1,
                  height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  color: const Color(0xFFFCD34D),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 1, bottom: 5),
                child: Row(
                  children: [
                    Text(
                      'Stop ${index + 1} / Via (रास्ते का स्टॉप ${index + 1})',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 47,
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(color: AppColors.navy, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Bardoli, Surat, Kamrej or tap map',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFEF4444),
                        size: 16,
                      ),
                      tooltip: 'Remove Stop',
                      onPressed: onRemove,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.dot,
    required this.suffix,
    required this.onChanged,
    this.onSuffixTap,
    this.onClear,
    this.isLoading = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool dot;
  final IconData suffix;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSuffixTap;
  final VoidCallback? onClear;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    Widget? suffixWidget;
    if (isLoading) {
      suffixWidget = const SizedBox.square(
        dimension: 18,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      final hasText = controller.text.trim().isNotEmpty;
      suffixWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasText && onClear != null)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFFEF4444),
                size: 16,
              ),
              tooltip: 'Clear location',
              onPressed: () {
                controller.clear();
                onClear!();
              },
            ),
          if (onSuffixTap != null)
            IconButton(
              icon: Icon(suffix, color: AppColors.blue, size: 18),
              tooltip: 'Use current GPS location',
              onPressed: onSuffixTap,
            )
          else if (!hasText)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(suffix, color: AppColors.muted, size: 18),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 21,
          height: 53,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: dot ? AppColors.blue : Colors.white,
                  shape: dot ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: dot ? BorderRadius.circular(3) : null,
                  border:
                      dot ? null : Border.all(color: AppColors.blue, width: 3),
                ),
              ),
              if (!dot)
                ...List.generate(
                  3,
                  (_) => Container(
                    width: 1,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    color: const Color(0xFFB7C3D4),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 1, bottom: 5),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 47,
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(color: AppColors.navy, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    suffixIcon: suffixWidget,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickRoutePresets extends StatelessWidget {
  const _QuickRoutePresets({
    required this.controller,
    required this.originController,
    required this.destinationController,
  });

  final PlannerController controller;
  final TextEditingController originController;
  final TextEditingController destinationController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alt_route_rounded,
                size: 15, color: AppColors.slate),
            const SizedBox(width: 5),
            const Text(
              'Quick Routes (क्विक रूट्स)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.slate,
              ),
            ),
            const Spacer(),
            if (controller.origin.isNotEmpty ||
                controller.destination.isNotEmpty)
              TextButton(
                onPressed: () {
                  controller.clearRoute();
                  originController.clear();
                  destinationController.clear();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reset', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // User-requested multi-stop preset: Bardoli -> Surat -> Kamrej
            InkWell(
              onTap: () {
                controller.setOrigin('Bardoli');
                controller.clearStops();
                controller.addStop('Surat');
                controller.setDestination('Kamrej');
                originController.text = 'Bardoli';
                destinationController.text = 'Kamrej';
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (controller.origin.toLowerCase().contains('bardoli') &&
                          controller.destination
                              .toLowerCase()
                              .contains('kamrej') &&
                          controller.stops
                              .any((s) => s.toLowerCase().contains('surat')))
                      ? const Color(0xFFD97706)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.alt_route_rounded,
                      size: 13,
                      color: (controller.origin
                                  .toLowerCase()
                                  .contains('bardoli') &&
                              controller.destination
                                  .toLowerCase()
                                  .contains('kamrej') &&
                              controller.stops.any(
                                  (s) => s.toLowerCase().contains('surat')))
                          ? Colors.white
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Bardoli -> Surat -> Kamrej',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: (controller.origin
                                    .toLowerCase()
                                    .contains('bardoli') &&
                                controller.destination
                                    .toLowerCase()
                                    .contains('kamrej') &&
                                controller.stops.any(
                                    (s) => s.toLowerCase().contains('surat')))
                            ? Colors.white
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...RouteTrafficService.popularRoutes.map((r) {
              final from = r['from']!;
              final to = r['to']!;
              final isSelected = controller.origin
                      .toLowerCase()
                      .contains(from.toLowerCase()) &&
                  controller.destination
                      .toLowerCase()
                      .contains(to.toLowerCase()) &&
                  controller.stops.isEmpty;
              return InkWell(
                onTap: () {
                  originController.text = from;
                  destinationController.text = to;
                  controller.setRoute(
                    newOrigin: from,
                    newDestination: to,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.blue : AppColors.canvas,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.blue : const Color(0xFFD6DFEC),
                    ),
                  ),
                  child: Text(
                    '$from -> $to',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.navy,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Popular Cities (शहर चुनें):',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: RouteTrafficService.popularCities.take(14).map((city) {
            final isOrigin =
                controller.origin.toLowerCase().contains(city.toLowerCase());
            final isDest = controller.destination
                .toLowerCase()
                .contains(city.toLowerCase());
            final isStop = controller.stops
                .any((s) => s.toLowerCase().contains(city.toLowerCase()));
            final isSelected = isOrigin || isDest || isStop;
            return InkWell(
              onTap: () {
                if (controller.origin.isEmpty) {
                  originController.text = city;
                  controller.setOrigin(city);
                } else if (controller.destination.isEmpty) {
                  destinationController.text = city;
                  controller.setDestination(city);
                } else {
                  controller.addStop(city);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blueSoft : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.blue : const Color(0xFFD8E1EE),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        isOrigin
                            ? Icons.radio_button_checked_rounded
                            : Icons.location_on_rounded,
                        size: 11,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.blue : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _JourneyHelp extends StatelessWidget {
  const _JourneyHelp();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.blueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: Color(0xFF6B91C7),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan a live journey',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Enter locations or pin coordinates, then open live directions in Google Maps on this device.',
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.5,
                  fontSize: 9.5,
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: Text(
                  'Google Maps Platform · Built for Transport One',
                  style: TextStyle(color: Color(0xFFA6B2C2), fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverListDialog extends StatelessWidget {
  const _DriverListDialog({required this.controller});
  final PlannerController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Drivers'),
      content: SizedBox(
        width: 390,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.drivers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No drivers added',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              );
            }
            return ListView.separated(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              shrinkWrap: true,
              itemCount: controller.drivers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final driver = controller.drivers[index];
                final isItemAdmin = driver.role.toLowerCase() == 'admin';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isItemAdmin ? const Color(0xFFEFF6FF) : AppColors.blueSoft,
                    foregroundColor: isItemAdmin ? AppColors.blue : AppColors.navy,
                    child: Icon(isItemAdmin ? Icons.admin_panel_settings_rounded : Icons.person_outline_rounded),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          driver.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isItemAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isItemAdmin ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Text(
                          isItemAdmin ? 'ADMIN' : 'DRIVER',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isItemAdmin ? AppColors.blue : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    driver.email.isNotEmpty ? driver.email : (driver.phone.isNotEmpty ? '+91 ${driver.phone}' : 'No Email'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: controller.isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Change Role (Admin / Driver)',
                              icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.blue),
                              onSelected: (role) async {
                                await controller.toggleDriverRole(index, role);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'driver',
                                  child: Row(
                                    children: [
                                      Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF059669)),
                                      SizedBox(width: 8),
                                      Text('Make Driver (ड्राइवर बनाएं)'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'admin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.blue),
                                      SizedBox(width: 8),
                                      Text('Make Admin (एडमिन बनाएं)'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () async => controller.removeDriver(index),
                              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
                            ),
                          ],
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AddTruckModelDialog extends StatefulWidget {
  const _AddTruckModelDialog();

  @override
  State<_AddTruckModelDialog> createState() => _AddTruckModelDialogState();
}

class _AddTruckModelDialogState extends State<_AddTruckModelDialog> {
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  final axlesController = TextEditingController();
  final capacityController = TextEditingController();
  final speedController = TextEditingController();
  bool showError = false;

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    axlesController.dispose();
    capacityController.dispose();
    speedController.dispose();
    super.dispose();
  }

  void _submit() {
    final speed = int.tryParse(speedController.text.trim());
    if (codeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        axlesController.text.trim().isEmpty ||
        capacityController.text.trim().isEmpty ||
        speed == null ||
        speed <= 0) {
      setState(() => showError = true);
      return;
    }
    Navigator.pop(
      context,
      TruckModel(
        code: codeController.text.trim(),
        name: nameController.text.trim(),
        axles: axlesController.text.trim(),
        capacity: capacityController.text.trim(),
        maxSpeed: speed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add vehicle model'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Vehicle number'),
              ),
              if (showError) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Complete every field with valid vehicle information.',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Model name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: axlesController,
                decoration: const InputDecoration(labelText: 'Wheels / axles'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: capacityController,
                decoration:
                    const InputDecoration(labelText: 'Payload capacity'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: speedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum speed (km/h)',
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
        FilledButton(onPressed: _submit, child: const Text('Add model')),
      ],
    );
  }
}

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog();
  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showError = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add driver'),
      content: SizedBox(
        width: 330,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Driver name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Login PIN / Password',
                helperText: 'Minimum 4 characters required',
              ),
            ),
            if (showError) ...[
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter a name, email, and password of at least 4 characters.',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (nameController.text.trim().isEmpty ||
                emailController.text.trim().isEmpty ||
                passwordController.text.trim().length < 4) {
              setState(() => showError = true);
              return;
            }
            Navigator.pop(
              context,
              DriverProfile(
                nameController.text.trim(),
                emailController.text.trim(),
                password: passwordController.text.trim(),
              ),
            );
          },
          child: const Text('Add driver'),
        ),
      ],
    );
  }
}
