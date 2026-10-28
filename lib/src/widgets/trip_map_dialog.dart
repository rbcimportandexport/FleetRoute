import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/map_tile_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';

class TripMapDialog extends StatefulWidget {
  const TripMapDialog({this.initialTrip, super.key});

  final TripRecord? initialTrip;

  @override
  State<TripMapDialog> createState() => _TripMapDialogState();
}

class _TripMapDialogState extends State<TripMapDialog> {
  final TextEditingController _referenceController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _pickup;
  final List<LatLng> _stops = [];
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  MapViewStyle _mapStyle = MapViewStyle.street;
  bool get _satellite => _mapStyle == MapViewStyle.satellite;
  bool get _streetlight => _mapStyle == MapViewStyle.streetlight;
  bool _locating = false;
  bool _showValidation = false;

  static const _indiaCenter = LatLng(22.5, 79.0);

  static const _cities = [
    ('Delhi', LatLng(28.6139, 77.2090)),
    ('Mumbai', LatLng(19.0760, 72.8777)),
    ('Bengaluru', LatLng(12.9716, 77.5946)),
    ('Kolkata', LatLng(22.5726, 88.3639)),
    ('Hyderabad', LatLng(17.3850, 78.4867)),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTrip != null) {
      _referenceController.text = widget.initialTrip!.reference;
      _pickup = RouteTrafficService.parseLocation(widget.initialTrip!.origin);
      _destination =
          RouteTrafficService.parseLocation(widget.initialTrip!.destination);
      _stops.addAll(
        widget.initialTrip!.stops
            .map(RouteTrafficService.parseLocation)
            .whereType<LatLng>(),
      );
    } else {
      final now = DateTime.now();
      _referenceController.text =
          'TRIP-${now.day}${now.hour}${now.minute.toString().padLeft(2, '0')}';
    }
    if (_pickup != null && _destination != null) {
      _fetchRoadPolyline();
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _format(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  void _onMapTap(LatLng point) {
    setState(() {
      _showValidation = false;
      if (_pickup == null) {
        // Place 1: Pickup
        _pickup = point;
      } else if (_destination == null) {
        // Place 2: Destination
        _destination = point;
      } else {
        // Place 3, 4, etc.: keep the order in which points were tapped.
        _stops.add(_destination!);
        _destination = point;
      }
    });
    _fetchRoadPolyline();
  }

  Future<void> _fetchRoadPolyline() async {
    if (_pickup == null || _destination == null) {
      if (_routePoints.isNotEmpty && mounted) {
        setState(() => _routePoints = []);
      }
      return;
    }
    try {
      final res = await RouteTrafficService.fetchRoute(
        origin: _pickup!,
        destination: _destination!,
        stops: _stops,
      );
      if (mounted) {
        setState(() => _routePoints = res.points);
      }
    } catch (_) {}
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is not available.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _pickup = point);
      try {
        _mapController.move(point, 15);
      } catch (_) {}
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _flyTo(LatLng target) {
    try {
      _mapController.move(target, 11);
    } catch (_) {}
  }

  void _resetPins() {
    setState(() {
      _pickup = null;
      _stops.clear();
      _destination = null;
      _showValidation = false;
    });
  }

  void _submit() {
    final ref = _referenceController.text.trim();
    if (ref.isEmpty || _pickup == null) {
      setState(() => _showValidation = true);
      return;
    }

    final originText = _format(_pickup!);
    // Supports 1 to 4+ places pinned: if only 1 place pinned, destination = pickup hub
    final destinationText =
        _destination != null ? _format(_destination!) : originText;

    final trip = TripRecord(
      reference: ref,
      origin: originText,
      destination: destinationText,
      stops: _stops.map(_format).toList(growable: false),
      status: 'planned',
      createdAt: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 680,
          minWidth: 320,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;

            if (isDesktop) {
              return Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildMapSection(constraints),
                  ),
                  Container(
                    width: 350,
                    color: Colors.white,
                    child: _buildDetailsPanel(),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildMapSection(constraints),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.white,
                    child: _buildDetailsPanel(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMapSection(BoxConstraints constraints) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickup ?? _indiaCenter,
              initialZoom: 5.0,
              minZoom: 2.5,
              maxZoom: 19.0,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                key: ValueKey(_mapStyle),
                urlTemplate: MapTileService.getTileUrl(
                  satellite: _satellite,
                  streetlight: _streetlight,
                  traffic: false,
                ),
                subdomains: MapTileService.getSubdomains(
                  streetlight: _streetlight,
                ),
                fallbackUrl: MapTileService.fallbackTileUrl,
                maxNativeZoom: 19,
                userAgentPackageName: MapTileService.userAgent,
                maxZoom: 19,
              ),
              if (_satellite) ...[
                TileLayer(
                  key: const ValueKey('satellite_roads_overlay'),
                  urlTemplate: MapTileService.satelliteRoadsTileUrl,
                  maxNativeZoom: 19,
                  userAgentPackageName: MapTileService.userAgent,
                  maxZoom: 19,
                ),
                TileLayer(
                  key: const ValueKey('satellite_labels_overlay'),
                  urlTemplate: MapTileService.satelliteLabelsTileUrl,
                  maxNativeZoom: 19,
                  userAgentPackageName: MapTileService.userAgent,
                  maxZoom: 19,
                ),
              ],
              PolylineLayer(
                polylines: [
                  if (_pickup != null && _destination != null)
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [
                              _pickup!,
                              ..._stops,
                              _destination!,
                            ],
                      color: AppColors.blue,
                      strokeWidth: 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_pickup != null)
                    Marker(
                      point: _pickup!,
                      width: 65,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Pickup',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.location_on,
                              color: Color(0xFF10B981), size: 30),
                        ],
                      ),
                    ),
                  for (int i = 0; i < _stops.length; i++)
                    Marker(
                      point: _stops[i],
                      width: 65,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Stop ${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.location_on,
                              color: Color(0xFFF59E0B), size: 30),
                        ],
                      ),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 65,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Drop',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.location_on,
                              color: Color(0xFFEF4444), size: 30),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Map Type Toggle
        Positioned(
          left: 12,
          top: 12,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(8),
            child: SegmentedButton<MapViewStyle>(
              segments: const [
                ButtonSegment(
                  value: MapViewStyle.street,
                  label: Text('Street', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.map_outlined, size: 14),
                ),
                ButtonSegment(
                  value: MapViewStyle.satellite,
                  label: Text('Satellite', style: TextStyle(fontSize: 11)),
                  icon: Icon(Icons.satellite_alt_outlined, size: 14),
                ),
              ],
              selected: {_mapStyle},
              onSelectionChanged: (val) {
                if (val.isNotEmpty) {
                  setState(() => _mapStyle = val.first);
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStatePropertyAll(Colors.white),
              ),
            ),
          ),
        ),
        // Quick City Jump Pills
        Positioned(
          left: 12,
          bottom: 12,
          right: 12,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F2440),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Jump to:',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (final (cityName, coords) in _cities)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _flyTo(coords),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Text(
                            cityName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Tap Instruction Overlay
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F2440),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_rounded,
                    color: AppColors.blue, size: 14),
                const SizedBox(width: 6),
                Text(
                  _pickup == null
                      ? 'Tap map to pin 1st place (Pickup)'
                      : _destination == null
                          ? 'Tap map to pin 2nd place (Destination)'
                          : '${2 + _stops.length} places pinned (Tap map to add more)',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsPanel() {
    final hasPickup = _pickup != null;
    final hasDestination = _destination != null;
    final totalPinned =
        (hasPickup ? 1 : 0) + (hasDestination ? 1 : 0) + _stops.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pin Trip on Map',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Pin 1 to 4+ places directly on Google Map',
                      style: TextStyle(fontSize: 11, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'Trip Reference',
              hintText: 'e.g. TRIP-101 or Dispatch code',
              prefixIcon: Icon(Icons.tag_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          // Location 1: Pickup / Origin
          _buildLocationCard(
            label: '1. Pickup / Starting Place',
            point: _pickup,
            isSet: hasPickup,
            color: const Color(0xFF16A34A),
            softColor: const Color(0xFFDCFCE7),
            icon: Icons.trip_origin_rounded,
            hint: 'Tap on Google Map to set Location 1',
          ),
          const SizedBox(height: 10),
          // Location 2: Destination
          _buildLocationCard(
            label: '2. Destination (Drop Point)',
            point: _destination,
            isSet: hasDestination,
            color: const Color(0xFFEF4444),
            softColor: const Color(0xFFFEE2E2),
            icon: Icons.location_on_rounded,
            hint: hasPickup
                ? 'Tap map to pin Destination (or keep 1 place)'
                : 'First pin Location 1 on the map',
          ),
          if (_stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (int i = 0; i < _stops.length; i++) ...[
              _buildLocationCard(
                label: 'Via Stop ${i + 1} (Place ${i + 3})',
                point: _stops[i],
                isSet: true,
                color: const Color(0xFFF59E0B),
                softColor: const Color(0xFFFEF3C7),
                icon: Icons.place_rounded,
                hint: 'Via Stop ${i + 1}',
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 14),
          // Current GPS Button
          OutlinedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 16),
            label: const Text(
              'Use My Current Location (GPS)',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          // Reset pins button
          if (hasPickup)
            TextButton.icon(
              onPressed: _resetPins,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text(
                'Reset Map Pins',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ),
          if (_showValidation)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _referenceController.text.trim().isEmpty
                    ? 'Please enter a valid trip reference.'
                    : 'Please tap on the Google Map to pin at least 1 location.',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 18),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    totalPinned > 2
                        ? 'Save $totalPinned-Place Trip'
                        : hasDestination
                            ? 'Save 2-Place Trip'
                            : hasPickup
                                ? 'Save 1-Place Trip'
                                : 'Pin to Save',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String label,
    required LatLng? point,
    required bool isSet,
    required Color color,
    required Color softColor,
    required IconData icon,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSet ? softColor : AppColors.canvas,
        border: Border.all(
          color: isSet ? color : AppColors.border,
          width: isSet ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(icon, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSet ? color : AppColors.slate,
                      ),
                    ),
                    if (isSet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'PINNED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isSet ? _format(point!) : hint,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSet ? FontWeight.w700 : FontWeight.w500,
                    color: isSet ? AppColors.navy : AppColors.muted,
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
