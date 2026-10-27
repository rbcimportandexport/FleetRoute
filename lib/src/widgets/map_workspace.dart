import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/firebase_backend_service.dart';
import '../services/incoming_intent_service.dart';
import '../services/map_tile_service.dart';
import '../services/reverse_geocoding_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';
import 'pre_trip_customer_details_dialog.dart';
import 'seatbelt_verification_dialog.dart';

class MapWorkspace extends StatefulWidget {
  const MapWorkspace({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<MapWorkspace> createState() => _MapWorkspaceState();
}

class _MapWorkspaceState extends State<MapWorkspace> {
  static const _india = LatLng(22.6, 79.0);
  final MapController _mapController = MapController();
  gm.GoogleMapController? _googleMapController;
  final GlobalKey _mapViewKey = GlobalKey();
  LatLng? _userLocation;
  LatLng? _pinnedOrigin;
  LatLng? _pinnedDestination;
  String? _draggingPin; // 'origin', 'destination', or 'stop_0', 'stop_1'...
  Offset _dragPointerToPinOffset = Offset.zero;
  String _activePinMode = 'pickup'; // 'pickup' or 'drop'
  bool _locating = false;
  double _zoom = 5.0;

  String _shortLocationName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Location';
    final first = clean.split(',').first.trim();
    if (RegExp(r'^[-+]?\d').hasMatch(first)) return 'GPS Location';
    return first.length > 24 ? '${first.substring(0, 24)}…' : first;
  }

  // Real-time Traffic and Routing
  // A newly pinned route should use the standard blue navigation line.
  // Traffic colours remain optional through the explicit Traffic toggle.
  bool _trafficEnabled = false;
  bool _cardExpanded = false;
  bool _loadingRoute = false;
  int _tileErrorCount = 0;
  // ignore: unused_field
  int _tileLayerRevision = 0;
  bool _mapTilesFailed = false;
  bool _tileErrorUpdateScheduled = false;
  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 0;
  String? _lastRouteKey;
  int _routeRequestId = 0;
  TrafficReport? _trafficReport;
  bool _isFallbackRoute = false;

  // Live Navigation State
  bool _isNavigating = false;
  int _navIndex = 0;
  LatLng? _currentNavPosition;
  double _currentNavBearing = 0.0;
  double _currentSpeed = 0.0; // Stationary initially (0 km/h)
  NavigationTurnInfo? _currentTurnInfo;
  Timer? _navTimer;
  StreamSubscription<Position>? _gpsSubscription;
  Position? _lastGpsPosition;
  DateTime? _lastGpsTime;
  DateTime? _lastTrackerFixTime;
  LatLng? _lastTrackerPosition;
  bool _usingVehicleTracker = false;
  bool _cameraFollowLocked = true;
  bool _isVerifyingSeatbelt = false;
  bool _arrivalPromptShown = false;
  StreamSubscription<IncomingLocationData>? _intentSubscription;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _listenIncomingLocationIntents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onControllerChanged();
      // Only auto-center if no incoming intent location is waiting and no origin configured
      final hasPendingIntent = IncomingIntentService().latestLocation != null;
      if (!hasPendingIntent && widget.controller.origin.trim().isEmpty) {
        if (widget.controller.truckModels.any((t) => t.hasCoordinates)) {
          _fitFleet();
        } else if (_userLocation == null) {
          _autoCenterUserLocation();
        }
      }
    });
  }

  void _listenIncomingLocationIntents() {
    // 1. Warm start intents (when app was already open or minimized)
    _intentSubscription =
        IncomingIntentService().onLocationReceived.listen((data) {
      if (!mounted) return;
      _applyIncomingLocation(data);
    });

    // 2. Cold start / pending intent (when app was launched fresh or navigation switched)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cached = IncomingIntentService().latestLocation;
      if (cached != null && mounted) {
        _applyIncomingLocation(cached);
        IncomingIntentService().clearLatestLocation();
        return;
      }
      final initialData = await IncomingIntentService().checkInitialLocation();
      if (initialData != null && mounted) {
        _applyIncomingLocation(initialData);
        IncomingIntentService().clearLatestLocation();
      }
    });
  }

  Future<void> _applyIncomingLocation(IncomingLocationData data) async {
    try {
      _showMessage('Opening shared location from Google Maps / WhatsApp...');

      // 1. Resolve current GPS location as Pickup (Origin)
      LatLng? currentGps = _userLocation;
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.whileInUse ||
              perm == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 4),
              ),
            );
            currentGps = LatLng(pos.latitude, pos.longitude);
          }
        }
      } catch (e) {
        debugPrint('[MapWorkspace] Incoming intent GPS fetch error: $e');
      }

      // Fallback: if GPS read is null, try last known position
      if (currentGps == null) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            currentGps = LatLng(lastKnown.latitude, lastKnown.longitude);
          }
        } catch (_) {}
      }

      // Default fallback if GPS is not enabled on device yet: default to current user position or center
      currentGps ??=
          _pinnedOrigin ?? _userLocation ?? const LatLng(21.1702, 72.8311);

      // 2. Resolve Incoming Location as Destination (Drop)
      LatLng? dropPos = data.coordinates;
      String dropLabel = data.addressQuery ?? '';

      // If coordinates are missing but text/query exists, search coordinates
      if (dropPos == null &&
          data.addressQuery != null &&
          data.addressQuery!.isNotEmpty) {
        dropPos = RouteTrafficService.parseLocation(data.addressQuery!);
        dropPos ??=
            await ReverseGeocodingService.searchCoordinates(data.addressQuery!);
      }

      // If coordinates found but label is empty, format label
      if (dropPos != null) {
        if (dropLabel.isEmpty) {
          dropLabel = await ReverseGeocodingService.labelFor(dropPos);
        }
      } else if (dropLabel.isNotEmpty) {
        // Last fallback: try parsing from rawUri
        dropPos = RouteTrafficService.parseLocation(data.rawUri);
      }

      if (dropPos == null) {
        _showMessage(
            'Location link received, but could not detect coordinates.');
        return;
      }

      // 3. Atomically update State and Controller for both Pickup & Drop
      final originLabel = await ReverseGeocodingService.labelFor(currentGps);

      if (!mounted) return;
      setState(() {
        _userLocation = currentGps;
        _pinnedOrigin = currentGps;
        _pinnedDestination = dropPos;
      });

      widget.controller.setRoute(
        newOrigin: originLabel,
        newDestination: dropLabel.isNotEmpty
            ? dropLabel
            : '${dropPos.latitude.toStringAsFixed(6)}, ${dropPos.longitude.toStringAsFixed(6)}',
        newStops: const [],
      );

      // 4. Center map on drop and fit both Pickup and Drop pins in view
      try {
        _mapController.move(dropPos, 14.5);
      } catch (_) {}

      try {
        _googleMapController?.animateCamera(
          gm.CameraUpdate.newLatLngZoom(_googlePoint(dropPos), 15.0),
        );
      } catch (_) {}

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        try {
          final bounds = LatLngBounds.fromPoints([currentGps!, dropPos!]);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            ),
          );
        } catch (_) {}
      });

      // 5. Trigger route calculation immediately
      _fetchRoute(currentGps, dropPos, []);

      _showMessage('Pickup: My Location | Drop: $dropLabel');
    } catch (e) {
      debugPrint('[MapWorkspace] Failed to apply incoming intent: $e');
    }
  }

  Future<void> _autoCenterUserLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled || !mounted) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (!mounted) return;
      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = userPos;
        _pinnedOrigin = userPos;
      });
      widget.controller.setOrigin(_format(userPos));
      try {
        _mapController.move(userPos, 15.0);
      } catch (e) {
        debugPrint('[MapWorkspace] MapController move skipped: $e');
      }
      final locationName = await ReverseGeocodingService.labelFor(userPos);
      if (!mounted) return;
      widget.controller.setOrigin(locationName);
    } catch (e) {
      debugPrint('[MapWorkspace] Initial location skipped or unavailable: $e');
    }
  }

  @override
  void didUpdateWidget(covariant MapWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    _navTimer?.cancel();
    _gpsSubscription?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    _mapController.dispose();
    super.dispose();
  }

  LatLng? get _effectiveOrigin {
    // While dragging, render the live pin preview instead of the old value in
    // the text field. The controller is updated only after the drag ends.
    if (_draggingPin == 'origin' && _pinnedOrigin != null) {
      return _pinnedOrigin;
    }
    final parsed = RouteTrafficService.parseLocation(widget.controller.origin);
    if (parsed != null) return parsed;
    return _pinnedOrigin;
  }

  LatLng? get _effectiveDestination {
    if (_draggingPin == 'destination' && _pinnedDestination != null) {
      return _pinnedDestination;
    }
    final parsed =
        RouteTrafficService.parseLocation(widget.controller.destination);
    if (parsed != null) return parsed;
    return _pinnedDestination;
  }

  List<LatLng> get _effectiveStops {
    final list = <LatLng>[];
    for (final stop in widget.controller.stops) {
      if (stop.trim().isEmpty) continue;
      final parsed = RouteTrafficService.parseLocation(stop);
      if (parsed != null) {
        list.add(parsed);
      }
    }
    return list;
  }

  TruckModel? get _selectedLiveTruck {
    final trucks = widget.controller.truckModels;
    if (trucks.isEmpty) return null;

    // P1.7: Driver navigation must ALWAYS select the assigned vehicle.
    if (widget.controller.isDriver) {
      final assigned = widget.controller.selectedDriver?.assignedVehicle
          .trim()
          .toUpperCase();
      if (assigned != null && assigned.isNotEmpty) {
        for (final truck in trucks) {
          if (truck.code.toUpperCase() == assigned ||
              truck.name.toUpperCase().contains(assigned)) {
            return truck;
          }
        }
      }
    }

    // Admin must explicitly select a vehicle; truckIndex must not override driver assignment
    final selected = widget.controller.truckIndex;
    if (selected != null && selected >= 0 && selected < trucks.length) {
      return trucks[selected];
    }

    final driverAssigned =
        widget.controller.selectedDriver?.assignedVehicle.trim().toUpperCase();
    if (driverAssigned != null && driverAssigned.isNotEmpty) {
      for (final truck in trucks) {
        if (truck.code.toUpperCase() == driverAssigned ||
            truck.name.toUpperCase().contains(driverAssigned)) {
          return truck;
        }
      }
    }

    // P1.7: Never silently default to the first truck
    return null;
  }

  bool _hasFreshTrackerFix(TruckModel? truck) =>
      truck != null &&
      truck.hasCoordinates &&
      truck.hasValidGpsFix &&
      !truck.isDemoTelemetry &&
      !truck.isGpsStale;

  String get _navigationGpsSource {
    final truck = _selectedLiveTruck;
    if (_usingVehicleTracker) {
      if (_hasFreshTrackerFix(truck)) {
        return 'VEHICLE GPS${truck!.code.isEmpty ? '' : ' · ${truck.code}'}';
      } else if (truck != null && truck.hasCoordinates) {
        final timeStr = truck.lastGpsTime != null
            ? '${truck.lastGpsTime!.hour.toString().padLeft(2, '0')}:${truck.lastGpsTime!.minute.toString().padLeft(2, '0')}'
            : '';
        return 'VEHICLE STALE (${truck.code}${(timeStr.isNotEmpty ? ' $timeStr' : '')})';
      }
    }
    if (_lastGpsPosition != null) {
      return 'PHONE GPS';
    }
    return 'NO FIX';
  }

  LatLng? _getStopLatLng(int index) {
    if (index < 0 || index >= widget.controller.stops.length) return null;
    return RouteTrafficService.parseLocation(widget.controller.stops[index]);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Clear stale map pins if user emptied the origin or destination
    if (widget.controller.origin.trim().isEmpty) {
      _pinnedOrigin = null;
    }
    if (widget.controller.destination.trim().isEmpty) {
      _pinnedDestination = null;
    }

    // Check navigation trigger from controller
    if (widget.controller.isNavigating && !_isNavigating) {
      _startLiveNavigation();
    } else if (!widget.controller.isNavigating && _isNavigating) {
      _stopLiveNavigation();
    }

    if (_isNavigating) {
      _applySelectedTruckFix();
    }

    final origin = _effectiveOrigin;
    final dest = _effectiveDestination;
    final stops = _effectiveStops;

    if (origin != null && dest != null) {
      _fetchRoute(origin, dest, stops);
    } else {
      if (_routePoints.isNotEmpty || _lastRouteKey != null || _loadingRoute) {
        _routeRequestId++;
        setState(() {
          _routePoints = [];
          _routeDistanceKm = 0;
          _lastRouteKey = null;
          _loadingRoute = false;
          _trafficReport = null;
        });
      }
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng dest,
      [List<LatLng> stops = const []]) async {
    final stopsKey = stops
        .map((s) =>
            '${s.latitude.toStringAsFixed(4)},${s.longitude.toStringAsFixed(4)}')
        .join(';');
    final key =
        '${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}->'
        '${stopsKey.isEmpty ? "" : "$stopsKey->"}'
        '${dest.latitude.toStringAsFixed(5)},${dest.longitude.toStringAsFixed(5)}';

    if (_lastRouteKey == key) {
      if (_routePoints.isNotEmpty) {
        return;
      }
      if (_loadingRoute) return;
    }
    _lastRouteKey = key;
    final requestId = ++_routeRequestId;

    setState(() => _loadingRoute = true);

    final result = await RouteTrafficService.fetchRoute(
      origin: origin,
      destination: dest,
      stops: stops,
    );

    if (!mounted || requestId != _routeRequestId || _lastRouteKey != key) {
      return;
    }

    final isFallback = !result.isRealHighwayRoute && result.points.isNotEmpty;
    widget.controller.setRouteRoutable(
      !isFallback,
      isFallback
          ? 'Route unavailable: Road routing server temporarily offline'
          : null,
    );

    setState(() {
      _routePoints = result.points;
      _routeDistanceKm = result.distanceKm;
      _isFallbackRoute = isFallback;
      _loadingRoute = false;
    });

    _updateRouteReport(result);

    if (!_isNavigating) {
      _fitRoute();
    }
  }

  void _updateRouteReport(RouteResult result) {
    if (!mounted) return;
    if (result.distanceKm <= 0 || result.rawDurationSeconds <= 0) {
      setState(() => _trafficReport = null);
      return;
    }

    final report = TrafficReport(
      level: TrafficLevel.smooth,
      distanceKm: result.distanceKm,
      duration: Duration(seconds: result.rawDurationSeconds.round()),
      delayMinutes: 0,
      clearPercent: 0,
      moderatePercent: 0,
      slowPercent: 0,
      summary: MapTileService.hasAuthorizedTrafficProvider
          ? 'Route ETA received from routing provider. Enable traffic for the licensed live overlay.'
          : 'Route and ETA received from OSRM. Live traffic provider is not configured.',
      summaryHindi: MapTileService.hasAuthorizedTrafficProvider
          ? 'Route provider ka real ETA mila hai. Licensed live traffic overlay available hai.'
          : 'OSRM se real road route aur ETA mila hai. Live traffic provider configured nahi hai.',
      isEstimated: false,
      providerName: 'OSRM routing',
    );

    if (mounted) {
      setState(() => _trafficReport = report);
    }
  }

  void _fitRoute() {
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [
            if (_effectiveOrigin != null) _effectiveOrigin!,
            ..._effectiveStops,
            if (_effectiveDestination != null) _effectiveDestination!,
          ];
    if (points.length < 2) return;

    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }

  void _fitFleet() {
    final truckPoints = <LatLng>[];
    for (final truck in widget.controller.truckModels) {
      if (truck.hasCoordinates) {
        truckPoints.add(LatLng(truck.latitude!, truck.longitude!));
      }
    }
    if (truckPoints.isEmpty) return;

    try {
      if (truckPoints.length == 1) {
        _mapController.move(truckPoints.first, 13.0);
      } else {
        final bounds = LatLngBounds.fromPoints(truckPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _showFleetLocation() async {
    _fitFleet();
    if (!mounted) return;
    await _openFleetDriverSheet();
  }

  Future<void> _openFleetDriverSheet() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final vehicles = widget.controller.truckModels;
            final online =
                vehicles.where((v) => v.hasCoordinates && !v.isGpsStale).length;
            return SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Expanded(
                      child: Text('All Drivers Live Location',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Text(
                        '$online Online · ${vehicles.length - online} Offline'),
                  ]),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    itemBuilder: (_, index) =>
                        _fleetDriverTile(sheetContext, vehicles[index]),
                  ),
                ),
              ]),
            );
          },
        ),
      );

  Widget _fleetDriverTile(BuildContext sheetContext, TruckModel vehicle) {
    final online = vehicle.hasCoordinates && !vehicle.isGpsStale;
    final drivers = widget.controller.drivers
        .where((d) =>
            d.assignedVehicle.trim().toUpperCase() ==
            vehicle.code.trim().toUpperCase())
        .map((d) => d.name)
        .join(' / ');
    return ListTile(
      leading: Icon(Icons.person_pin_circle_rounded,
          color: online ? Colors.green : Colors.red),
      title: Text(drivers.isEmpty ? vehicle.assignedDriver : drivers),
      subtitle: Text(vehicle.code +
          (online
              ? ' · Live ${vehicle.currentSpeed.toStringAsFixed(0)} km/h'
              : ' · Offline / no recent GPS')),
      trailing: Text(online ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              color: online ? Colors.green : Colors.red)),
      onTap: () async {
        Navigator.pop(sheetContext);
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
        if (vehicle.hasCoordinates) {
          final point = LatLng(vehicle.latitude!, vehicle.longitude!);
          _mapController.move(point, 16);
          _googleMapController?.animateCamera(
              gm.CameraUpdate.newLatLngZoom(_googlePoint(point), 16));
        }
        _showVehicleIdentity(vehicle);
      },
    );
  }

  // ==================== LIVE NAVIGATION ENGINE ====================

  Future<void> _startLiveNavigation() async {
    if (_isVerifyingSeatbelt) return;
    _isVerifyingSeatbelt = true;

    final origin = _effectiveOrigin;
    final dest = _effectiveDestination;
    if (origin == null || dest == null) {
      _isVerifyingSeatbelt = false;
      _showMessage('Please select both starting point and destination first.');
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      return;
    }

    if (_routePoints.isEmpty) {
      await _fetchRoute(origin, dest, _effectiveStops);
    }
    if (!mounted) {
      _isVerifyingSeatbelt = false;
      return;
    }

    if (_routePoints.length < 2) {
      _isVerifyingSeatbelt = false;
      _showMessage('Unable to plot route for live navigation.');
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      return;
    }

    if (_isFallbackRoute) {
      _isVerifyingSeatbelt = false;
      _showMessage(
          'Road routing server temporarily offline. Navigation requires a road-following route and cannot start on a straight-line estimate.');
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      return;
    }

    final truckIdx = widget.controller.truckIndex ?? 0;
    final vehicleCode = widget.controller.truckModels.isNotEmpty
        ? widget
            .controller
            .truckModels[
                truckIdx.clamp(0, widget.controller.truckModels.length - 1)]
            .code
        : '';

    // 1. Mandatory Pre-Trip Customer & Cargo Intake Dialog
    final hasCustomerDetails = await PreTripCustomerDetailsDialog.show(
      context,
      controller: widget.controller,
      origin: widget.controller.origin,
      destination: widget.controller.destination,
    );

    if (!mounted) {
      _isVerifyingSeatbelt = false;
      return;
    }

    if (!hasCustomerDetails) {
      _isVerifyingSeatbelt = false;
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      _showMessage(
          'Trip Cancelled: Customer aur trip details bharna zaroori hai.');
      return;
    }

    // 2. Mandatory Pre-Trip Driver Seatbelt & Cabin Safety Check
    final isVerified = await SeatbeltVerificationDialog.show(
      context,
      controller: widget.controller,
      vehicleNumber: vehicleCode,
      location: widget.controller.origin,
    );

    if (!mounted) {
      _isVerifyingSeatbelt = false;
      return;
    }

    if (!isVerified) {
      _isVerifyingSeatbelt = false;
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      _showMessage(
          'Trip Authorization Denied: Mandatory seatbelt verification failed.');
      return;
    }

    // Re-verify that route points are still valid after the async verification dialog
    if (_routePoints.length < 2) {
      _isVerifyingSeatbelt = false;
      _showMessage('Route was updated. Please start navigation again.');
      if (widget.controller.isNavigating) {
        widget.controller.stopNavigation();
      }
      return;
    }

    // Default to REAL GPS TRACKING
    _navTimer?.cancel();
    _lastGpsPosition = null;
    _lastGpsTime = null;
    _arrivalPromptShown = false;

    LatLng initialPos = _routePoints.first;
    double initialBearing = RouteTrafficService.calculateBearing(
      _routePoints[0],
      _routePoints[1],
    );
    double initialSpeed = 0.0;
    int initialNavIndex = 0;

    // Prefer the vehicle's own Protrack position. Previously navigation
    // always used this phone's GPS, so an admin could not follow the truck.
    final liveTruck = _selectedLiveTruck;
    final hasVehicleFix = _hasFreshTrackerFix(liveTruck);
    final mayUsePhoneGps = !widget.controller.isAdmin || liveTruck == null;
    if (widget.controller.isAdmin && liveTruck != null && !hasVehicleFix) {
      _isVerifyingSeatbelt = false;
      _showMessage(
        'Selected vehicle tracker is stale/offline. Fresh Protrack location ke bina live vehicle navigation start nahi hogi.',
      );
      return;
    }
    if (hasVehicleFix) {
      initialPos = LatLng(liveTruck!.latitude!, liveTruck.longitude!);
      initialBearing = liveTruck.course;
      initialSpeed = liveTruck.currentSpeed.clamp(0.0, 180.0);
      initialNavIndex = RouteTrafficService.findClosestPointIndex(
        _routePoints,
        initialPos,
      );
      _lastTrackerFixTime = liveTruck.lastGpsTime;
      _lastTrackerPosition = initialPos;
    }

    // Fall back to this phone's GPS only when the selected vehicle does not
    // have a fresh tracker fix.
    try {
      if (hasVehicleFix) {
        // The phone stream is still started below as an automatic fallback
        // if the vehicle tracker later becomes stale.
      } else if (mayUsePhoneGps) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          _showMessage(
              'Device Location (GPS) on karein real tracking ke liye.');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          _showMessage(
              'Location permission blocked in settings. Please enable GPS.');
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 4),
            ),
          );
          _lastGpsPosition = pos;
          _lastGpsTime = DateTime.now();
          final gpsLatLng = LatLng(pos.latitude, pos.longitude);
          final closestIdx = RouteTrafficService.findClosestPointIndex(
              _routePoints, gpsLatLng);

          if (_routePoints.isNotEmpty &&
              closestIdx >= 0 &&
              closestIdx < _routePoints.length) {
            final distMeters = Geolocator.distanceBetween(
              gpsLatLng.latitude,
              gpsLatLng.longitude,
              _routePoints[closestIdx].latitude,
              _routePoints[closestIdx].longitude,
            );

            // If GPS is within 25 km of the plotted route, place vehicle directly at real GPS location
            if (distMeters <= 25000) {
              initialPos = gpsLatLng;
              initialNavIndex = closestIdx;
            }
          }
          if (pos.heading > 0) {
            initialBearing = pos.heading;
          }
        }
      }
    } catch (_) {
      // Keep start of route if GPS read takes longer
    }

    _isVerifyingSeatbelt = false;
    setState(() {
      _isNavigating = true;
      _usingVehicleTracker = hasVehicleFix;
      _navIndex = initialNavIndex;
      _currentNavPosition = initialPos;
      _currentNavBearing = initialBearing;
      _currentTurnInfo =
          RouteTrafficService.findNextTurn(_routePoints, initialNavIndex);
      _cameraFollowLocked = true;
      _currentSpeed = initialSpeed;
    });

    // Notify the page shell as well. Without this notification the map went
    // into navigation mode while the large planner remained visible below it.
    if (!widget.controller.isNavigating) {
      widget.controller.startNavigation();
    }

    _animateCameraToNavVehicle(initialPos, initialBearing);

    // Start listening to REAL DEVICE GPS - No fake timer!
    if (mayUsePhoneGps) {
      _startRealGpsTracking();
    }
  }

  void _startRealGpsTracking() {
    _gpsSubscription?.cancel();
    _navTimer?.cancel();

    try {
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2, // minimum 2 meters physical movement
        ),
      ).listen(
        _updateGpsLocation,
        onError: (err) {
          _showMessage('GPS Signal error: $err');
        },
      );
      _showMessage('Real GPS Navigation Active (Real movement tracking)');
    } catch (e) {
      _showMessage('GPS error: $e');
    }
  }

  void _stopLiveNavigation() {
    _navTimer?.cancel();
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _lastGpsPosition = null;
    _lastGpsTime = null;
    _lastTrackerFixTime = null;
    _lastTrackerPosition = null;
    setState(() {
      _isNavigating = false;
      _usingVehicleTracker = false;
      _cameraFollowLocked = true;
      _currentSpeed = 0.0;
    });
    if (widget.controller.isNavigating) {
      widget.controller.stopNavigation();
    }
    try {
      _mapController.rotate(0);
    } catch (_) {}
    _fitRoute();
  }

  void _recenterNavCamera() {
    setState(() => _cameraFollowLocked = true);
    if (_currentNavPosition != null) {
      _animateCameraToNavVehicle(_currentNavPosition!, _currentNavBearing);
    }
  }

  void _applySelectedTruckFix() {
    if (!mounted || !_isNavigating) return;
    final truck = _selectedLiveTruck;
    if (!_hasFreshTrackerFix(truck)) {
      if (_usingVehicleTracker) {
        setState(() => _usingVehicleTracker = false);
      }
      return;
    }

    final position = LatLng(truck!.latitude!, truck.longitude!);
    final fixTime = truck.lastGpsTime;
    final unchanged =
        _lastTrackerPosition == position && _lastTrackerFixTime == fixTime;
    if (unchanged) return;

    _lastTrackerPosition = position;
    _lastTrackerFixTime = fixTime;
    final closestIdx = _routePoints.isEmpty
        ? _navIndex
        : RouteTrafficService.findClosestPointIndex(
            _routePoints,
            position,
            currentIndex: _navIndex,
          );
    final bearing = truck.course.isFinite
        ? (truck.course % 360.0 + 360.0) % 360.0
        : _currentNavBearing;
    final speed = truck.currentSpeed.clamp(0.0, 180.0);

    setState(() {
      _usingVehicleTracker = true;
      _currentNavPosition = position;
      _currentNavBearing = bearing;
      _currentSpeed = speed;
      _navIndex = closestIdx;
      if (_routePoints.isNotEmpty) {
        _currentTurnInfo =
            RouteTrafficService.findNextTurn(_routePoints, closestIdx);
      }
    });

    if (_cameraFollowLocked) {
      _animateCameraToNavVehicle(position, bearing);
    }

    final destination = _effectiveDestination;
    if (destination != null &&
        !_arrivalPromptShown &&
        RouteTrafficService.hasArrived(
          currentLocation: position,
          destination: destination,
          closestPointIndex: closestIdx,
          routePointCount: _routePoints.length,
        )) {
      unawaited(_handleDestinationArrival());
    }
  }

  void _animateCameraToNavVehicle(LatLng position, double bearing) {
    try {
      _mapController.move(position, 17.5);
      _mapController.rotate(bearing);
    } catch (_) {}
  }

  void _updateGpsLocation(Position pos) {
    if (!mounted || !_isNavigating) return;

    // P1.8: "Remote Vehicle Tracking" uses only Protrack data.
    // Never replace a stale remote truck position with the admin phone location.
    final selectedTruck = _selectedLiveTruck;
    if (widget.controller.isAdmin && selectedTruck != null) {
      // An administrator's handset location is never the selected truck's
      // location. Wait for a fresh tracker fix instead of moving the truck.
      return;
    }
    if (_usingVehicleTracker && selectedTruck != null) {
      // Retain the vehicle tracker as authoritative; update phone position metadata only
      _lastGpsPosition = pos;
      _lastGpsTime = DateTime.now();
      return;
    }

    if (_hasFreshTrackerFix(selectedTruck)) {
      return;
    }

    final newLatLng = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    // Check physical movement distance from last GPS fix
    double movedMeters = 0.0;
    if (_lastGpsPosition != null) {
      movedMeters = Geolocator.distanceBetween(
        _lastGpsPosition!.latitude,
        _lastGpsPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
    }

    // Real Speed Calculation:
    // Only calculate speed if user actually moved > 1.2 meters (avoids GPS jitter / drift when stopped)
    double realSpeed = 0.0;
    if (pos.speed > 0.4 && movedMeters > 1.2) {
      realSpeed = pos.speed * 3.6; // convert m/s to km/h
    } else if (_lastGpsPosition != null &&
        _lastGpsTime != null &&
        movedMeters > 2.0) {
      final elapsedSec = now.difference(_lastGpsTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0.4) {
        realSpeed = (movedMeters / elapsedSec) * 3.6;
      }
    }

    if (realSpeed > 160) {
      realSpeed = 0.0; // Filter unreasonable GPS teleport glitch
    }

    // Heading / Bearing Calculation:
    double bearing = _currentNavBearing;
    if (pos.heading > 0 && (movedMeters > 1.5 || pos.speed > 0.5)) {
      bearing = pos.heading;
    } else if (_lastGpsPosition != null && movedMeters > 2.0) {
      bearing = RouteTrafficService.calculateBearing(
        LatLng(_lastGpsPosition!.latitude, _lastGpsPosition!.longitude),
        newLatLng,
      );
    }

    _lastGpsPosition = pos;
    _lastGpsTime = now;

    // Find nearest point along route to update turn instructions and distance remaining
    int closestIdx = _navIndex;
    if (_routePoints.isNotEmpty) {
      closestIdx = RouteTrafficService.findClosestPointIndex(
        _routePoints,
        newLatLng,
        currentIndex: _navIndex,
      );
    }

    setState(() {
      _currentNavPosition = newLatLng;
      _currentNavBearing = bearing;
      _currentSpeed = realSpeed; // 0 km/h when user is not moving!
      _navIndex = closestIdx;
      if (_routePoints.isNotEmpty) {
        _currentTurnInfo =
            RouteTrafficService.findNextTurn(_routePoints, closestIdx);
      }
    });

    if (_cameraFollowLocked) {
      _animateCameraToNavVehicle(newLatLng, bearing);
    }

    // Real driver phone GPS telemetry sync to Firestore
    final activeVehicleCode = selectedTruck?.code ??
        widget.controller.selectedDriver?.assignedVehicle ??
        '';
    if (activeVehicleCode.isNotEmpty) {
      unawaited(
        FirebaseBackendService.instance.syncVehicleTelemetry(
          vehicleCode: activeVehicleCode,
          latitude: newLatLng.latitude,
          longitude: newLatLng.longitude,
          speed: realSpeed,
          isIgnitionOn: realSpeed > 1.0,
        ),
      );
    }

    final destination = _effectiveDestination;
    if (destination != null &&
        !_arrivalPromptShown &&
        RouteTrafficService.hasArrived(
          currentLocation: newLatLng,
          destination: destination,
          closestPointIndex: closestIdx,
          routePointCount: _routePoints.length,
        )) {
      unawaited(_handleDestinationArrival());
    }
  }

  Future<void> _handleDestinationArrival() async {
    if (!mounted || !_isNavigating || _arrivalPromptShown) return;
    _arrivalPromptShown = true;
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
    if (!mounted) return;

    setState(() {
      _currentSpeed = 0;
      _navIndex = _routePoints.isEmpty ? 0 : _routePoints.length - 1;
      if (_routePoints.isNotEmpty) {
        _currentTurnInfo =
            RouteTrafficService.findNextTurn(_routePoints, _navIndex);
      }
    });

    final continueTrip = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.flag_circle_rounded,
          color: Color(0xFF10B981),
          size: 44,
        ),
        title: const Text(
          'Aap destination par pahunch gaye',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Kya aapko yahan se aage kisi aur jagah jana hai?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Nahi, trip khatam'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Haan, naya drop'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (continueTrip == true) {
      _continueFromCurrentDrop();
    } else {
      _stopLiveNavigation();
      _showMessage('Trip complete ho gaya.');
    }
  }

  void _continueFromCurrentDrop() {
    final currentDrop = widget.controller.destination.trim();
    final dropPoint = _effectiveDestination;

    if (_isNavigating) {
      _stopLiveNavigation();
    }
    setState(() {
      _pinnedOrigin = dropPoint;
      _userLocation = dropPoint;
      _pinnedDestination = null;
      _arrivalPromptShown = false;
    });
    widget.controller.continueFromDestination();

    if (dropPoint != null) {
      try {
        _mapController.move(dropPoint, 15.5);
      } catch (_) {}
    }
    _showMessage(
      'Pichla Drop ab naya Pickup ban gaya ($currentDrop). Ab map par nayi manzil tap karein.',
    );
  }

  // ==================== MARKERS & POLYLINES ====================

  // ignore: unused_element
  List<Marker> get _markers {
    final origin = _effectiveOrigin;
    final dest = _effectiveDestination;

    return [
      if (_isNavigating && _currentNavPosition != null)
        Marker(
          point: _currentNavPosition!,
          width: 52,
          height: 52,
          child: Transform.rotate(
            angle: _currentNavBearing * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      if (_userLocation != null && !_isNavigating)
        Marker(
          point: _userLocation!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x550284C7),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.my_location_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
      if (origin != null && (!_isNavigating || _navIndex == 0))
        Marker(
          point: origin,
          width: 170,
          height: 68,
          alignment: Alignment.bottomCenter,
          child: _DraggableMapMarker(
            key: const ValueKey('pickup-map-marker'),
            enabled: !_isNavigating,
            onTap: _showPickupActionsDialog,
            onDragStart: (globalPosition) =>
                _beginPinDrag('origin', globalPosition),
            onDragUpdate: (globalPosition) {
              if (_isNavigating || _draggingPin != 'origin') return;
              _handlePinPanUpdate('origin', globalPosition);
            },
            onDragEnd: () {
              if (_isNavigating) return;
              _handlePinPanEnd('origin');
            },
            onDragCancel: () {
              if (mounted) setState(() => _draggingPin = null);
            },
            child: AnimatedScale(
              scale: _draggingPin == 'origin' ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                        left: 6, right: 3, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _draggingPin == 'origin'
                              ? const Color(0x6610B981)
                              : const Color(0x33000000),
                          blurRadius: _draggingPin == 'origin' ? 8 : 4,
                          spreadRadius: _draggingPin == 'origin' ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _draggingPin == 'origin'
                                ? 'Move Pickup'
                                : 'Pickup · ${_shortLocationName(widget.controller.origin)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _removePickupPin,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.location_on,
                    color: _draggingPin == 'origin'
                        ? const Color(0xFF059669)
                        : const Color(0xFF10B981),
                    size: 36,
                  ),
                ],
              ),
            ),
          ),
        ),
      for (int i = 0; i < widget.controller.stops.length; i++) ...[
        if (_getStopLatLng(i) != null)
          Marker(
            point: _getStopLatLng(i)!,
            width: 90,
            height: 60,
            alignment: Alignment.bottomCenter,
            child: _DraggableMapMarker(
              key: ValueKey('stop-map-marker-$i'),
              enabled: !_isNavigating,
              onTap: () => _showStopActionsDialog(i),
              onDragStart: (globalPosition) =>
                  _beginPinDrag('stop_$i', globalPosition, stopIndex: i),
              onDragUpdate: (globalPosition) {
                if (_isNavigating || _draggingPin != 'stop_$i') return;
                _handlePinPanUpdate('stop_$i', globalPosition, stopIndex: i);
              },
              onDragEnd: () {
                if (_isNavigating) return;
                _handlePinPanEnd('stop_$i', stopIndex: i);
              },
              onDragCancel: () {
                if (mounted) setState(() => _draggingPin = null);
              },
              child: AnimatedScale(
                scale: _draggingPin == 'stop_$i' ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                          left: 6, right: 3, top: 2, bottom: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: _draggingPin == 'stop_$i'
                                ? const Color(0x66F59E0B)
                                : const Color(0x33000000),
                            blurRadius: _draggingPin == 'stop_$i' ? 8 : 4,
                            spreadRadius: _draggingPin == 'stop_$i' ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _draggingPin == 'stop_$i'
                                  ? 'Move Stop ${i + 1}'
                                  : 'Stop ${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _removeStopAt(i),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      color: _draggingPin == 'stop_$i'
                          ? const Color(0xFFD97706)
                          : const Color(0xFFF59E0B),
                      size: 36,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      if (dest != null)
        Marker(
          point: dest,
          width: 170,
          height: 68,
          alignment: Alignment.bottomCenter,
          child: _DraggableMapMarker(
            key: const ValueKey('drop-map-marker'),
            enabled: !_isNavigating,
            onTap: _showDropActionsDialog,
            onDragStart: (globalPosition) =>
                _beginPinDrag('destination', globalPosition),
            onDragUpdate: (globalPosition) {
              if (_isNavigating || _draggingPin != 'destination') return;
              _handlePinPanUpdate('destination', globalPosition);
            },
            onDragEnd: () {
              if (_isNavigating) return;
              _handlePinPanEnd('destination');
            },
            onDragCancel: () {
              if (mounted) setState(() => _draggingPin = null);
            },
            child: AnimatedScale(
              scale: _draggingPin == 'destination' ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                        left: 6, right: 3, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _draggingPin == 'destination'
                              ? const Color(0x66EF4444)
                              : const Color(0x33000000),
                          blurRadius: _draggingPin == 'destination' ? 8 : 4,
                          spreadRadius: _draggingPin == 'destination' ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _draggingPin == 'destination'
                                ? 'Move Drop'
                                : 'Drop · ${_shortLocationName(widget.controller.destination)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _removeDropPin,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFF991B1B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.location_on,
                    color: _draggingPin == 'destination'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFEF4444),
                    size: 36,
                  ),
                ],
              ),
            ),
          ),
        ),
      for (final truck in widget.controller.truckModels)
        if (truck.hasCoordinates)
          Marker(
            key: ValueKey('truck-marker-${truck.code}'),
            point: LatLng(truck.latitude!, truck.longitude!),
            width: 72,
            height: 52,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _showVehicleIdentity(truck),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: truck.isDemoTelemetry
                          ? const Color(0xFFD97706)
                          : (truck.isIgnitionOn
                              ? (truck.isMoving
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2563EB))
                              : const Color(0xFF64748B)),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      truck.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Transform.rotate(
                    angle: (truck.course * math.pi) / 180,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: truck.isDemoTelemetry
                              ? const Color(0xFFD97706)
                              : (truck.isIgnitionOn
                                  ? (truck.isMoving
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF2563EB))
                                  : const Color(0xFF64748B)),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 14,
                        color: truck.isDemoTelemetry
                            ? const Color(0xFFD97706)
                            : (truck.isIgnitionOn
                                ? (truck.isMoving
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB))
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];
  }

  gm.LatLng _googlePoint(LatLng point) =>
      gm.LatLng(point.latitude, point.longitude);

  Set<gm.Marker> get _googleMarkers {
    final markers = <gm.Marker>{};
    final origin = _effectiveOrigin;
    final destination = _effectiveDestination;
    if (origin != null) {
      markers.add(gm.Marker(
        // A colour-specific ID forces the native map to recreate this pin
        // instead of reusing a previously cached red default marker.
        markerId: const gm.MarkerId('pickup_green'),
        position: _googlePoint(origin),
        draggable: !_isNavigating,
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            gm.BitmapDescriptor.hueGreen),
        infoWindow:
            gm.InfoWindow(title: 'Pickup', snippet: widget.controller.origin),
        onDragEnd: (point) async {
          final value = LatLng(point.latitude, point.longitude);
          setState(() => _pinnedOrigin = value);
          final label = await ReverseGeocodingService.labelFor(value);
          if (mounted) widget.controller.setOrigin(label);
        },
      ));
    }
    for (int i = 0; i < _effectiveStops.length; i++) {
      markers.add(gm.Marker(
        markerId: gm.MarkerId('stop_$i'),
        position: _googlePoint(_effectiveStops[i]),
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            gm.BitmapDescriptor.hueOrange),
        infoWindow: gm.InfoWindow(title: 'Stop ${i + 1}'),
      ));
    }
    if (destination != null) {
      markers.add(gm.Marker(
        markerId: const gm.MarkerId('drop_red'),
        position: _googlePoint(destination),
        draggable: !_isNavigating,
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            gm.BitmapDescriptor.hueRed),
        infoWindow: gm.InfoWindow(
            title: 'Drop (Destination)',
            snippet: widget.controller.destination),
        onDragEnd: (point) async {
          final value = LatLng(point.latitude, point.longitude);
          setState(() => _pinnedDestination = value);
          final label = await ReverseGeocodingService.labelFor(value);
          if (mounted) widget.controller.setDestination(label);
        },
      ));
    }
    for (final truck in widget.controller.truckModels) {
      if (!truck.hasCoordinates) continue;
      markers.add(gm.Marker(
        markerId: gm.MarkerId('truck_${truck.code}'),
        position: gm.LatLng(truck.latitude!, truck.longitude!),
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(truck.isMoving
            ? gm.BitmapDescriptor.hueAzure
            : gm.BitmapDescriptor.hueBlue),
        infoWindow: gm.InfoWindow(
          title: truck.code,
          snippet: truck.isMoving
              ? 'Moving · ${truck.currentSpeed} km/h'
              : 'Stationary',
        ),
        onTap: () => _showVehicleIdentity(truck),
      ));
    }
    return markers;
  }

  Set<gm.Polyline> get _googlePolylines {
    if (_routePoints.length < 2) return const {};
    return {
      gm.Polyline(
        polylineId: const gm.PolylineId('active_route'),
        points: _routePoints.map(_googlePoint).toList(growable: false),
        color: const Color(0xFF2563EB),
        width: 6,
        geodesic: true,
      ),
    };
  }

  // ignore: unused_element
  List<CircleMarker> get _circles {
    if (!_isNavigating || _currentNavPosition == null) return [];
    return [
      CircleMarker(
        point: _currentNavPosition!,
        radius: 28,
        useRadiusInMeter: false,
        color: const Color(0x332563EB),
        borderColor: const Color(0xFF2563EB),
        borderStrokeWidth: 2,
      ),
    ];
  }

  // ignore: unused_element
  List<Polyline> get _polylines {
    final polylines = <Polyline>[];

    // Fleet GPS breadcrumb trails
    for (final truck in widget.controller.truckModels) {
      if (truck.gpsHistory.length >= 2) {
        polylines.add(
          Polyline(
            points: truck.gpsHistory
                .map((b) => LatLng(b.latitude, b.longitude))
                .toList(),
            color: const Color(0x802563EB),
            strokeWidth: 3.5,
          ),
        );
      }
    }

    if (_routePoints.length < 2) return polylines;

    // High-contrast background casing for visual depth
    polylines.add(
      Polyline(
        points: _routePoints,
        color: widget.controller.isStreetlight
            ? const Color(0xFF020617)
            : const Color(0xFF1E293B),
        strokeWidth: 9,
      ),
    );

    if (!_trafficEnabled ||
        !MapTileService.hasAuthorizedTrafficProvider ||
        _trafficReport == null) {
      polylines.add(
        Polyline(
          points: _routePoints,
          color: const Color(0xFF2563EB),
          strokeWidth: 6,
        ),
      );
      return polylines;
    }

    // Dynamic Live Traffic Flow on the road
    final segments = RouteTrafficService.calculateRoadTrafficSegments(
      _routePoints,
      _trafficReport!,
    );

    if (segments.isEmpty) {
      polylines.add(
        Polyline(
          points: _routePoints,
          color: const Color(0xFF10B981),
          strokeWidth: 6,
        ),
      );
      return polylines;
    }

    for (final seg in segments) {
      polylines.add(
        Polyline(
          points: seg.points,
          color: seg.color,
          strokeWidth: 6,
        ),
      );
    }

    return polylines;
  }

  void _zoomBy(double amount) {
    try {
      _zoom = (_mapController.camera.zoom + amount).clamp(2.0, 19.0);
      _mapController.move(_mapController.camera.center, _zoom);
    } catch (_) {}
  }

  // ignore: unused_element
  void _handleMapTileError() {
    _tileErrorCount++;
    if (_tileErrorCount < 6 ||
        _mapTilesFailed ||
        _tileErrorUpdateScheduled ||
        !mounted) {
      return;
    }
    _tileErrorUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tileErrorUpdateScheduled = false;
      if (!mounted || _mapTilesFailed) return;
      setState(() => _mapTilesFailed = true);
    });
  }

  void _retryMapTiles() {
    setState(() {
      _tileErrorCount = 0;
      _mapTilesFailed = false;
      _tileLayerRevision++;
    });
  }

  Future<void> _showCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(
            'Turn on Location Services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationFailure('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(
          'Location permission is blocked. Enable it in device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = location;
        _pinnedOrigin = location;
      });
      widget.controller.setOrigin(_format(location));
      _zoom = 16.0;
      try {
        _mapController.move(location, _zoom);
      } catch (_) {}
      await _googleMapController?.animateCamera(
        gm.CameraUpdate.newLatLngZoom(_googlePoint(location), _zoom),
      );
      final locationName = await ReverseGeocodingService.labelFor(location);
      if (!mounted) return;
      widget.controller.setOrigin(locationName);
      _showMessage('Live location: $locationName');
    } on _LocationFailure catch (error) {
      _showMessage(error.message);
    } on TimeoutException {
      _showMessage('Location request timed out.');
    } catch (_) {
      _showMessage('Unable to read the current location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleLiveTraffic() {
    setState(() => _trafficEnabled = !_trafficEnabled);
    _showMessage(
        _trafficEnabled ? 'Google live traffic ON' : 'Google traffic OFF');
  }

  void _clearRoute() {
    setState(() {
      _pinnedOrigin = null;
      _pinnedDestination = null;
      _routePoints = [];
      _routeDistanceKm = 0;
      _lastRouteKey = null;
      _trafficReport = null;
    });
    widget.controller.clearRoute();
    _showMessage('Route cleared. Aap naye points select kar sakte hain.');
  }

  LatLng? _pinLocation(String pinType, int? stopIndex) {
    if (pinType == 'origin') return _effectiveOrigin;
    if (pinType == 'destination') return _effectiveDestination;
    if (stopIndex != null) return _getStopLatLng(stopIndex);
    return null;
  }

  void _beginPinDrag(String pinType, Offset globalPosition, {int? stopIndex}) {
    if (_isNavigating) return;
    final current = _pinLocation(pinType, stopIndex);
    final mapBox = _mapViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (current == null || mapBox == null) return;

    try {
      final localPointer = mapBox.globalToLocal(globalPosition);
      final currentPinOffset =
          _mapController.camera.latLngToScreenOffset(current);
      _dragPointerToPinOffset = currentPinOffset - localPointer;
      setState(() {
        _draggingPin = pinType;
        if (pinType == 'origin') {
          _pinnedOrigin = current;
        } else if (pinType == 'destination') {
          _pinnedDestination = current;
        }
      });
    } catch (_) {}
  }

  void _handlePinPanUpdate(String pinType, Offset globalPosition,
      {int? stopIndex}) {
    LatLng? current;
    if (pinType == 'origin') {
      current = _effectiveOrigin;
    } else if (pinType == 'destination') {
      current = _effectiveDestination;
    } else if (stopIndex != null) {
      current = _getStopLatLng(stopIndex);
    }
    if (current == null) return;

    try {
      final camera = _mapController.camera;
      final mapBox =
          _mapViewKey.currentContext?.findRenderObject() as RenderBox?;
      if (mapBox == null) return;
      final localPointer = mapBox.globalToLocal(globalPosition);
      final newOffset = localPointer + _dragPointerToPinOffset;
      final newLatLng = camera.screenOffsetToLatLng(newOffset);

      setState(() {
        if (pinType == 'origin') {
          _pinnedOrigin = newLatLng;
          _userLocation = newLatLng;
        } else if (pinType == 'destination') {
          _pinnedDestination = newLatLng;
        } else if (stopIndex != null &&
            stopIndex >= 0 &&
            stopIndex < widget.controller.stops.length) {
          widget.controller.stops[stopIndex] = _format(newLatLng);
        }
      });
    } catch (_) {}
  }

  Future<void> _handlePinPanEnd(String pinType, {int? stopIndex}) async {
    setState(() => _draggingPin = null);

    if (pinType == 'origin' && _pinnedOrigin != null) {
      final label = await ReverseGeocodingService.labelFor(_pinnedOrigin!);
      if (!mounted) return;
      widget.controller.setOrigin(label);
      _showMessage('Pickup pin updated: $label');
    } else if (pinType == 'destination' && _pinnedDestination != null) {
      final label = await ReverseGeocodingService.labelFor(_pinnedDestination!);
      if (!mounted) return;
      widget.controller.setDestination(label);
      _showMessage('Drop pin updated: $label');
    } else if (stopIndex != null &&
        stopIndex >= 0 &&
        stopIndex < widget.controller.stops.length) {
      final stopCoord = widget.controller.stops[stopIndex];
      widget.controller.updateStop(stopIndex, stopCoord);
      _showMessage('Stop ${stopIndex + 1} pin updated: $stopCoord');
    }
  }

  void _showDropActionsDialog() {
    final dest = widget.controller.destination;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination (Drop Point)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dest.isNotEmpty ? dest : 'Drop Location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
                title: const Text(
                  'Yahan se naya trip shuru karein',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                subtitle: const Text(
                  'Current Drop naya Pickup ban jayega, agla drop chunein',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _continueFromCurrentDrop();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_location_alt_outlined,
                      color: Color(0xFFD97706), size: 20),
                ),
                title: const Text(
                  'Iske aage aur stop jodein',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                subtitle: const Text(
                  'Current Drop via-stop ban jayega, agla Drop map par tap karein',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _pinnedDestination = null;
                  });
                  widget.controller.extendRouteTo('');
                  _showMessage(
                      'Pichla Drop ab Via-Stop ban gaya. Map par naya Drop point tap karein.');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.open_in_new_rounded,
                      color: AppColors.slate, size: 20),
                ),
                title: const Text(
                  'Google Maps par open karein',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openExternalNav();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626), size: 20),
                ),
                title: const Text(
                  'Drop point hatayein (Remove Drop Pin)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                subtitle: const Text(
                  'Yeh destination pin map se delete ho jayega',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeDropPin();
                },
              ),
              if (widget.controller.stops.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.clear_all_rounded,
                        color: Color(0xFFD97706), size: 20),
                  ),
                  title: Text(
                    'Sare via-stops hatayein (${widget.controller.stops.length} Stops)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  subtitle: const Text(
                    'Sare beech ke stop pins remove ho jayenge',
                    style: TextStyle(fontSize: 11, color: AppColors.slate),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeAllStops();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeStopAt(int index) {
    if (index < 0 || index >= widget.controller.stops.length) return;
    setState(() {
      _routePoints = [];
      _routeDistanceKm = 0;
      _lastRouteKey = null;
      _trafficReport = null;
    });
    widget.controller.removeStop(index);
    _showMessage('Stop ${index + 1} pin hata diya gaya.');
  }

  void _removeDropPin() {
    setState(() {
      _pinnedDestination = null;
      _routePoints = [];
      _routeDistanceKm = 0;
      _lastRouteKey = null;
      _trafficReport = null;
    });
    widget.controller.setDestination('');
    _showMessage('Drop pin hata diya gaya. Map par naya Drop tap karein.');
  }

  void _removeAllStops() {
    setState(() {
      _routePoints = [];
      _routeDistanceKm = 0;
      _lastRouteKey = null;
      _trafficReport = null;
    });
    widget.controller.clearStops();
    _showMessage('Sare via-stops pins hata diye gaye.');
  }

  void _removePickupPin() {
    setState(() {
      _pinnedOrigin = null;
      _routePoints = [];
      _routeDistanceKm = 0;
      _lastRouteKey = null;
      _trafficReport = null;
    });
    widget.controller.setOrigin('');
    _showMessage('Pickup pin hata diya gaya. Map par naya Pickup tap karein.');
  }

  void _showPickupActionsDialog() {
    final origin = widget.controller.origin;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Origin (Pickup Point)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          origin.isNotEmpty ? origin : 'Pickup Location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626), size: 20),
                ),
                title: const Text(
                  'Pickup point hatayein (Remove Pickup Pin)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                subtitle: const Text(
                  'Yeh pickup pin map se delete ho jayega',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removePickupPin();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: AppColors.navy, size: 20),
                ),
                title: const Text(
                  'Pura route clear karein (Clear Everything)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _clearRoute();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStopActionsDialog(int index) {
    if (index < 0 || index >= widget.controller.stops.length) return;
    final stopVal = widget.controller.stops[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Via Stop ${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stopVal.isNotEmpty ? stopVal : 'Stop Location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626), size: 20),
                ),
                title: Text(
                  'Yeh Stop ${index + 1} hatayein (Remove Stop)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                subtitle: const Text(
                  'Sirf yeh stop pin map aur route se delete ho jayega',
                  style: TextStyle(fontSize: 11, color: AppColors.slate),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _routePoints = [];
                    _routeDistanceKm = 0;
                    _lastRouteKey = null;
                    _trafficReport = null;
                  });
                  widget.controller.removeStop(index);
                  _showMessage('Stop ${index + 1} pin hata diya gaya.');
                },
              ),
              if (widget.controller.stops.length > 1)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.clear_all_rounded,
                        color: Color(0xFFD97706), size: 20),
                  ),
                  title: const Text(
                    'Sare via-stops hatayein (Remove All Stops)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeAllStops();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSetLocationSheet({String? initialMode}) {
    final originCtrl = TextEditingController(text: widget.controller.origin);
    final destCtrl = TextEditingController(text: widget.controller.destination);
    bool locatingPickup = false;
    bool locatingDrop = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_location_alt_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set Route / Pickup & Drop',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.navy,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Type location, pick GPS, or tap map directly',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Direct Tap Map Shortcut Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Tap Map directly:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                Navigator.pop(bottomSheetContext);
                                setState(() => _activePinMode = 'pickup');
                                _showMessage(
                                    'Pickup Mode ON: Map par tap karke Pickup set karein (Green Pin).');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF10B981)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place_rounded,
                                        size: 14, color: Color(0xFF10B981)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Pick on Map',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Navigator.pop(bottomSheetContext);
                                setState(() => _activePinMode = 'drop');
                                _showMessage(
                                    'Drop Mode ON: Map par tap karke Drop set karein (Red Pin).');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFEF4444)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        size: 14, color: Color(0xFFEF4444)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Drop on Map',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pickup Field with Clear and Current GPS button
                      TextField(
                        controller: originCtrl,
                        autofocus: initialMode == 'pickup',
                        decoration: InputDecoration(
                          labelText: '1. Pickup Point (कहाँ से माल लोड होगा)',
                          hintText: 'e.g. Surat, Bardoli, Ring Road...',
                          prefixIcon: const Icon(Icons.my_location_rounded,
                              color: Color(0xFF10B981), size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (originCtrl.text.isNotEmpty)
                                IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  tooltip: 'Clear Pickup',
                                  onPressed: () {
                                    originCtrl.clear();
                                    setSheetState(() {});
                                  },
                                ),
                              locatingPickup
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.gps_fixed_rounded,
                                          color: Color(0xFF10B981), size: 20),
                                      tooltip: 'Use My GPS Location as Pickup',
                                      onPressed: () async {
                                        setSheetState(
                                            () => locatingPickup = true);
                                        try {
                                          final pos = await Geolocator
                                              .getCurrentPosition(
                                            locationSettings:
                                                const LocationSettings(
                                              accuracy: LocationAccuracy.medium,
                                              timeLimit: Duration(seconds: 8),
                                            ),
                                          );
                                          final userPos = LatLng(
                                              pos.latitude, pos.longitude);
                                          final place =
                                              await ReverseGeocodingService
                                                  .labelFor(userPos);
                                          originCtrl.text = place;
                                          setState(() {
                                            _userLocation = userPos;
                                            _pinnedOrigin = userPos;
                                            _activePinMode = 'drop';
                                          });
                                          widget.controller.setOrigin(place);
                                          try {
                                            _mapController.move(userPos, 15.0);
                                          } catch (_) {}
                                          _googleMapController?.animateCamera(
                                            gm.CameraUpdate.newLatLngZoom(
                                                _googlePoint(userPos), 16),
                                          );
                                        } catch (e) {
                                          _showMessage('GPS fetch skipped: $e');
                                        } finally {
                                          setSheetState(
                                              () => locatingPickup = false);
                                        }
                                      },
                                    ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF10B981), width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Swap Origin and Destination
                      Center(
                        child: InkWell(
                          onTap: () {
                            final tmp = originCtrl.text;
                            originCtrl.text = destCtrl.text;
                            destCtrl.text = tmp;
                            final tmpPoint = _pinnedOrigin;
                            setState(() {
                              _pinnedOrigin = _pinnedDestination;
                              _pinnedDestination = tmpPoint;
                            });
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(15),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_vert_rounded,
                                    size: 16, color: AppColors.navy),
                                SizedBox(width: 4),
                                Text(
                                  'Swap Pickup & Drop',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Destination Field
                      TextField(
                        controller: destCtrl,
                        autofocus: initialMode == 'drop',
                        decoration: InputDecoration(
                          labelText: '2. Destination (Drop / कहाँ पहुँचना है)',
                          hintText: 'e.g. Kamrej, Mumbai, Ahmedabad...',
                          prefixIcon: const Icon(Icons.location_on_rounded,
                              color: Color(0xFFEF4444), size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (destCtrl.text.isNotEmpty)
                                IconButton(
                                  icon:
                                      const Icon(Icons.clear_rounded, size: 18),
                                  tooltip: 'Clear Drop',
                                  onPressed: () {
                                    destCtrl.clear();
                                    setSheetState(() {});
                                  },
                                ),
                              locatingDrop
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.gps_fixed_rounded,
                                          color: Color(0xFFEF4444), size: 20),
                                      tooltip: 'Use My GPS Location as Drop',
                                      onPressed: () async {
                                        setSheetState(
                                            () => locatingDrop = true);
                                        try {
                                          final pos = await Geolocator
                                              .getCurrentPosition(
                                            locationSettings:
                                                const LocationSettings(
                                              accuracy: LocationAccuracy.medium,
                                              timeLimit: Duration(seconds: 8),
                                            ),
                                          );
                                          final userPos = LatLng(
                                              pos.latitude, pos.longitude);
                                          final place =
                                              await ReverseGeocodingService
                                                  .labelFor(userPos);
                                          destCtrl.text = place;
                                          setState(() {
                                            _pinnedDestination = userPos;
                                          });
                                          widget.controller
                                              .setDestination(place);
                                          try {
                                            _mapController.move(userPos, 15.0);
                                          } catch (_) {}
                                          _googleMapController?.animateCamera(
                                            gm.CameraUpdate.newLatLngZoom(
                                                _googlePoint(userPos), 16),
                                          );
                                        } catch (e) {
                                          _showMessage('GPS fetch skipped: $e');
                                        } finally {
                                          setSheetState(
                                              () => locatingDrop = false);
                                        }
                                      },
                                    ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFEF4444), width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Selection Chips for Major Hubs
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          'Surat',
                          'Bardoli',
                          'Kamrej',
                          'Navsari',
                          'Ahmedabad',
                          'Mumbai',
                          'Ankleshwar',
                          'Vapi',
                        ].map((city) {
                          return ActionChip(
                            label: Text(city),
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            onPressed: () {
                              if (originCtrl.text.trim().isEmpty) {
                                originCtrl.text = city;
                              } else {
                                destCtrl.text = city;
                              }
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                if (!widget.controller.pinMode) {
                                  widget.controller.togglePinMode();
                                }
                                _showMessage(
                                  'Tap Mode Active: Map par tap karke Pickup aur Drop choose karein.',
                                );
                              },
                              icon:
                                  const Icon(Icons.touch_app_rounded, size: 16),
                              label: const Text('Tap on Map'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.navy,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final orig = originCtrl.text.trim();
                                final dest = destCtrl.text.trim();
                                if (orig.isNotEmpty) {
                                  final pt =
                                      RouteTrafficService.parseLocation(orig);
                                  if (pt != null) {
                                    setState(() => _pinnedOrigin = pt);
                                  }
                                  widget.controller.setOrigin(orig);
                                }
                                if (dest.isNotEmpty) {
                                  final pt =
                                      RouteTrafficService.parseLocation(dest);
                                  if (pt != null) {
                                    setState(() => _pinnedDestination = pt);
                                  }
                                  widget.controller.setDestination(dest);
                                }
                                Navigator.pop(bottomSheetContext);
                                _showMessage(
                                    'Locations updated! Calculating route...');
                              },
                              icon: const Icon(Icons.check_circle_rounded,
                                  size: 16),
                              label: const Text('Apply Route'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (_isNavigating) return;

    final coordString = _format(point);

    // 1. If in Drop mode, ALWAYS set / update Drop!
    if (_activePinMode == 'drop') {
      // If pickup is not set yet, use current user location or fallback as pickup
      if (widget.controller.origin.trim().isEmpty || _pinnedOrigin == null) {
        final fallbackOrigin = _userLocation ?? const LatLng(21.1702, 72.8311);
        _pinnedOrigin = fallbackOrigin;
        ReverseGeocodingService.labelFor(fallbackOrigin).then((origName) {
          if (!mounted) return;
          widget.controller.setOrigin(origName);
        });
      }

      setState(() {
        _pinnedDestination = point;
      });
      widget.controller.setDestination(coordString);
      _showMessage('Drop Pinned ($coordString). Calculating route...');

      ReverseGeocodingService.labelFor(point).then((locationName) {
        if (!mounted) return;
        if (_pinnedDestination == point) {
          widget.controller.setDestination(locationName);
          _showMessage(
              'Drop Set: $locationName. Route ready! "Start" dabayein.');
        }
      });
      return;
    }

    // 2. Otherwise in Pickup mode:
    if (_activePinMode == 'pickup' ||
        widget.controller.origin.trim().isEmpty ||
        _pinnedOrigin == null) {
      setState(() {
        _pinnedOrigin = point;
        _userLocation = point;
        _activePinMode =
            'drop'; // automatically advance to Drop mode for next tap
      });
      widget.controller.setOrigin(coordString);
      _showMessage('Pickup Pinned ($coordString). Ab Drop tap karein.');

      ReverseGeocodingService.labelFor(point).then((locationName) {
        if (!mounted) return;
        if (_pinnedOrigin == point) {
          widget.controller.setOrigin(locationName);
          _showMessage(
              'Pickup Set: $locationName. Ab Map par Destination (Drop) tap karein.');
        }
      });
      return;
    }

    // 3. Fallback: if both are set, extend with stop
    setState(() => _pinnedDestination = point);
    widget.controller.extendRouteTo(coordString);
    _showMessage(
        'Stop ${widget.controller.stops.length} saved. New Drop pinned: $coordString.');

    ReverseGeocodingService.labelFor(point).then((locationName) {
      if (!mounted) return;
      if (_pinnedDestination == point) {
        widget.controller.setDestination(locationName);
      }
    });
  }

  Future<void> _openExternalNav() async {
    final origin = _effectiveOrigin;
    final dest = _effectiveDestination;
    if (origin == null || dest == null) return;

    final travelMode =
        widget.controller.vehicle == VehicleType.bike ? 'bicycling' : 'driving';
    final queryParams = <String, String>{
      'api': '1',
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${dest.latitude},${dest.longitude}',
      'travelmode': travelMode,
      'dir_action': 'navigate',
    };

    final stops = _effectiveStops;
    if (stops.isNotEmpty) {
      queryParams['waypoints'] =
          stops.map((s) => '${s.latitude},${s.longitude}').join('|');
    }

    final routeUri = Uri.https('www.google.com', '/maps/dir/', queryParams);

    final opened = await launchUrl(
      routeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('Unable to open Google Maps navigation.');
    }
  }

  String _format(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  void _showVehicleTelematicsModal(TruckModel truck) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final speed = truck.currentSpeed.toStringAsFixed(1);
        final isStale = truck.isGpsStale;
        final status = truck.isDemoTelemetry
            ? 'Demo Simulation'
            : (isStale
                ? 'Offline · Stale GPS (>5m)'
                : (truck.isMoving
                    ? 'Moving ($speed km/h)'
                    : (truck.isIgnitionOn
                        ? 'Idle · ACC ON'
                        : 'Parked · ACC OFF')));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.satellite_alt_rounded,
                            color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          truck.code,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${truck.name} · ${truck.capacity}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IMEI: ${truck.maskedImei}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStale
                            ? const Color(0xFFFEF2F2)
                            : (truck.isIgnitionOn
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isStale
                              ? const Color(0xFFDC2626)
                              : (truck.isIgnitionOn
                                  ? const Color(0xFF16A34A)
                                  : AppColors.slate),
                        ),
                      ),
                    ),
                    if (truck.lastGpsTime != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Updated: ${_formatRelativeTime(truck.lastGpsTime!)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVehicleIdentity(TruckModel truck) {
    final assignedNames = widget.controller.drivers
        .where((driver) =>
            driver.assignedVehicle.trim().toUpperCase() ==
            truck.code.trim().toUpperCase())
        .map((driver) => driver.name.trim())
        .where((name) => name.isNotEmpty)
        .join(' / ');
    final driverName = assignedNames.isNotEmpty
        ? assignedNames
        : (truck.assignedDriver.trim().isNotEmpty
            ? truck.assignedDriver.trim()
            : 'Driver not assigned');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.local_shipping_rounded, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(truck.code,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(driverName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteVehicleDetails(TruckModel truck) {
    String value(String raw) =>
        raw.trim().isEmpty ? 'Not configured' : raw.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Complete Vehicle Details',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _vehicleDetailCard('Vehicle Number', truck.code, width),
                        _vehicleDetailCard(
                            'Vehicle Name / Model', truck.name, width),
                        _vehicleDetailCard(
                            'Vehicle Type', value(truck.vehicleModel), width),
                        _vehicleDetailCard(
                            'Owner', value(truck.ownerName), width),
                        _vehicleDetailCard(
                            'Status', value(truck.vehicleStatus), width),
                        _vehicleDetailCard(
                            'Capacity', value(truck.capacity), width),
                        _vehicleDetailCard('Axles', value(truck.axles), width),
                        _vehicleDetailCard(
                            'Odometer', '${truck.currentOdometerKm} km', width),
                        _vehicleDetailCard(
                            'Next Service', '${truck.nextServiceKm} km', width),
                        _vehicleDetailCard(
                            'Speed Limit', '${truck.maxSpeed} km/h', width),
                        _vehicleDetailCard(
                            'FASTag Balance',
                            'Rs ${truck.fastagBalance.toStringAsFixed(0)}',
                            width),
                        _vehicleDetailCard(
                            'GPS / Tracker',
                            truck.hasValidGpsFix ? 'Connected' : 'No live fix',
                            width),
                        _vehicleDetailCard('Last GPS Update',
                            value(truck.lastGpsUpdate), width),
                        _vehicleDetailCard('Insurance No.',
                            value(truck.insuranceNumber), width),
                        _vehicleDetailCard('Insurance Expiry',
                            value(truck.insuranceExpiry), width),
                        _vehicleDetailCard(
                            'PUC No.', value(truck.pucNumber), width),
                        _vehicleDetailCard(
                            'PUC Expiry', value(truck.pucExpiry), width),
                        _vehicleDetailCard(
                            'Fitness No.', value(truck.fitnessNumber), width),
                        _vehicleDetailCard('Fitness Expiry',
                            value(truck.fitnessExpiry), width),
                        _vehicleDetailCard(
                            'RC Expiry', value(truck.rcExpiry), width),
                        _vehicleDetailCard('Permit Expiry',
                            value(truck.allIndiaPermitExpiry), width),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleDetailCard(String label, String value, double width) =>
      Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.slate)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final initialZoom = compact ? 5.35 : 4.85;
          final hasRoute =
              _effectiveOrigin != null && _effectiveDestination != null;

          return Stack(
            children: [
              Positioned.fill(
                child: gm.GoogleMap(
                  key: _mapViewKey,
                  initialCameraPosition: gm.CameraPosition(
                    target: _googlePoint(
                        _effectiveOrigin ?? _userLocation ?? _india),
                    zoom: initialZoom,
                  ),
                  mapType: widget.controller.satellite
                      ? gm.MapType.hybrid
                      : gm.MapType.normal,
                  trafficEnabled: _trafficEnabled,
                  myLocationEnabled: _userLocation != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  markers: _googleMarkers,
                  polylines: _googlePolylines,
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                    final target = _effectiveOrigin ?? _userLocation;
                    if (target != null) {
                      controller.animateCamera(gm.CameraUpdate.newLatLngZoom(
                          _googlePoint(target), 16));
                    }
                  },
                  onTap: (point) =>
                      _handleMapTap(LatLng(point.latitude, point.longitude)),
                  onCameraMove: (position) {
                    _zoom = position.zoom;
                    if (_isNavigating && _cameraFollowLocked) {
                      setState(() => _cameraFollowLocked = false);
                    }
                  },
                ),
              ),

              if (_mapTilesFailed)
                Positioned(
                  left: 16,
                  right: 16,
                  top: _isNavigating ? 112 : 72,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded,
                                size: 18, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Map load nahi hua. Internet check karke retry karein.',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _retryMapTiles,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (_isFallbackRoute && _routePoints.isNotEmpty && !_isNavigating)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 72,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: const Color(0xFFFEF3C7),
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alt_route_rounded,
                                size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Straight-line estimate: Road routing server temporarily offline.',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                final orig = _effectiveOrigin;
                                final dest = _effectiveDestination;
                                if (orig != null && dest != null) {
                                  _fetchRoute(orig, dest, _effectiveStops);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ==================== LIVE NAVIGATION TOP HUD ====================
              if (_isNavigating)
                Positioned(
                  left: 14,
                  right: 14,
                  top: 14,
                  child: _NavigationTopHud(
                    turnInfo: _currentTurnInfo,
                    speed: _currentSpeed,
                    gpsSource: _navigationGpsSource,
                    compact: compact,
                    vehicle: widget.controller.vehicle,
                    remainingDistanceKm: _remainingDistanceKm,
                    remainingTimeStr: _remainingTimeStr,
                    isLocked: _cameraFollowLocked,
                    onRecenter: _recenterNavCamera,
                    onExit: _stopLiveNavigation,
                  ),
                ),

              // ==================== TOP-LEFT STANDARD CONTROLS (WHEN NOT NAVIGATING) ====================
              if (!_isNavigating)
                Positioned(
                  left: 14,
                  right: compact ? 14 : null,
                  top: 14,
                  child: compact
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _CompactMapBar(
                              controller: widget.controller,
                              activePinMode: _activePinMode,
                              trafficEnabled: _trafficEnabled,
                              onToggleTraffic: _toggleLiveTraffic,
                              hasRoute: hasRoute,
                              onFitRoute: _fitRoute,
                              onClearRoute: _clearRoute,
                              onSetLocation: _openSetLocationSheet,
                              onSetPickup: () {
                                setState(() => _activePinMode = 'pickup');
                                _showMessage(
                                    'Pickup Mode ON: Map par tap karein pickup badalne ke liye (Green Pin).');
                              },
                              onSetDrop: () {
                                setState(() => _activePinMode = 'drop');
                                _showMessage(
                                    'Drop Mode ON: Map par tap karein drop point set karne ke liye (Red Pin).');
                              },
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (constraints.maxWidth - 200)
                                .clamp(200.0, 750.0),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _MapTypeControl(controller: widget.controller),
                              _MapButton(
                                icon: Icons.edit_location_alt_rounded,
                                label: 'Set Route',
                                active: true,
                                activeColor: AppColors.primary,
                                onTap: _openSetLocationSheet,
                              ),
                              _MapButton(
                                icon: Icons.place_rounded,
                                label: 'Set Pickup',
                                active: _activePinMode == 'pickup',
                                activeColor: const Color(0xFF10B981),
                                onTap: () {
                                  setState(() => _activePinMode = 'pickup');
                                  _showMessage(
                                      'Pickup Mode ON: Map par tap karein pickup badalne ke liye (Green Pin).');
                                },
                              ),
                              _MapButton(
                                icon: Icons.location_on_rounded,
                                label: 'Set Drop',
                                active: _activePinMode == 'drop',
                                activeColor: const Color(0xFFEF4444),
                                onTap: () {
                                  setState(() => _activePinMode = 'drop');
                                  _showMessage(
                                      'Drop Mode ON: Map par tap karein drop point set karne ke liye (Red Pin).');
                                },
                              ),
                              _MapButton(
                                icon: Icons.add_location_alt_outlined,
                                label: widget.controller.pinMode
                                    ? 'Tap to Pin'
                                    : 'Pin on map',
                                active: widget.controller.pinMode,
                                onTap: widget.controller.togglePinMode,
                              ),
                              _MapButton(
                                icon: Icons.traffic_rounded,
                                label: _trafficEnabled
                                    ? 'Traffic: ON'
                                    : 'Traffic: OFF',
                                active: _trafficEnabled,
                                activeColor: const Color(0xFF10B981),
                                onTap: _toggleLiveTraffic,
                              ),
                              if (hasRoute ||
                                  _effectiveOrigin != null ||
                                  _effectiveDestination != null ||
                                  widget.controller.stops.isNotEmpty) ...[
                                _MapButton(
                                  icon: Icons.refresh_rounded,
                                  label: 'Clear Route',
                                  onTap: _clearRoute,
                                ),
                              ],
                              if (hasRoute) ...[
                                _MapButton(
                                  icon: Icons.play_arrow_rounded,
                                  label: 'START LIVE',
                                  active: true,
                                  activeColor: const Color(0xFF10B981),
                                  onTap: _startLiveNavigation,
                                ),
                                _MapButton(
                                  icon: Icons.crop_free_rounded,
                                  label: 'Fit Route',
                                  onTap: _fitRoute,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),

              // Top-right Provider Badge and Traffic Legend
              if (!compact && !_isNavigating)
                Positioned(
                  right: 15,
                  top: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const _ProviderBadge(),
                      if (_trafficEnabled) ...[
                        const SizedBox(height: 6),
                        _buildTrafficLegend(),
                      ],
                    ],
                  ),
                ),

              // Keep setup controls off the navigation map. They used to
              // consume valuable space and overlap the live controls.
              if (!_isNavigating)
                Positioned(
                  right: 14,
                  bottom: compact ? 14 : 18,
                  child: Column(
                    children: [
                      if (!compact) ...[
                        _ZoomControls(onZoom: _zoomBy),
                        const SizedBox(height: 9),
                      ],
                      _LocationButton(
                        locating: _locating,
                        onPressed: _showCurrentLocation,
                      ),
                    ],
                  ),
                ),

              // Active Route and Live Traffic Summary (when not navigating)
              if (hasRoute && _trafficReport != null && !_isNavigating)
                Positioned(
                  left: 14,
                  bottom: compact ? 14 : 18,
                  child: compact
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x260F2035),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() => _cardExpanded = !_cardExpanded);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.controller.vehicle.icon,
                                  size: 14,
                                  color: const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_trafficReport!.formattedDistance} · ${_trafficReport!.formattedDuration}',
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _trafficReport!.level.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _trafficReport!.level.label,
                                  style: TextStyle(
                                    color: _trafficReport!.level ==
                                            TrafficLevel.smooth
                                        ? const Color(0xFF047857)
                                        : (_trafficReport!.level ==
                                                TrafficLevel.moderate
                                            ? const Color(0xFFB45309)
                                            : const Color(0xFFB91C1C)),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _startLiveNavigation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.navigation_rounded,
                                            size: 11, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'START',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _RouteTrafficCard(
                          report: _trafficReport!,
                          origin: widget.controller.origin.isNotEmpty
                              ? widget.controller.origin
                              : _format(_effectiveOrigin!),
                          destination: widget.controller.destination.isNotEmpty
                              ? widget.controller.destination
                              : _format(_effectiveDestination!),
                          vehicle: widget.controller.vehicle,
                          trafficEnabled: _trafficEnabled,
                          isLoadingRoute: _loadingRoute,
                          isExpanded: _cardExpanded,
                          onToggleExpand: () {
                            setState(() => _cardExpanded = !_cardExpanded);
                          },
                          onStartNavigation: _startLiveNavigation,
                          onFitRoute: _fitRoute,
                          onToggleTraffic: _toggleLiveTraffic,
                          onOpenNavigation: _openExternalNav,
                          routeSummary: widget.controller.routePathSummary,
                        ),
                ),

              // ==================== LIVE NAVIGATION BOTTOM CONTROLS ====================
              if (_isNavigating)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 18,
                  child: _NavigationBottomControls(
                    isLocked: _cameraFollowLocked,
                    speed: _currentSpeed,
                    gpsSource: _navigationGpsSource,
                    compact: compact,
                    onRecenter: _recenterNavCamera,
                    onStop: _stopLiveNavigation,
                  ),
                ),

              // Helpful Map Route Placement Guidance Banner (Desktop / Tablet view)
              if (!_isNavigating && !compact)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 72,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: (_effectiveOrigin == null
                                          ? const Color(0xFF10B981)
                                          : (_effectiveDestination == null
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFF59E0B)))
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _effectiveOrigin == null
                                      ? Icons.touch_app_rounded
                                      : (_effectiveDestination == null
                                          ? Icons.place_rounded
                                          : Icons.add_location_alt_rounded),
                                  color: _effectiveOrigin == null
                                      ? const Color(0xFF10B981)
                                      : (_effectiveDestination == null
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B)),
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _effectiveOrigin == null
                                    ? 'Map par tap karein ya Search dabayein'
                                    : (_effectiveDestination == null
                                        ? 'Pickup set! Ab Drop tap karein'
                                        : 'Tap map to add Stop ${widget.controller.stops.length + 1}'),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Mode Switchers
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() => _activePinMode = 'pickup');
                                  _showMessage(
                                      'Pickup Mode ON: Map par tap karein pickup badalne ke liye (Green Pin).');
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: _activePinMode == 'pickup'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _activePinMode == 'pickup'
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFA7F3D0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Set Pickup',
                                    style: TextStyle(
                                      color: _activePinMode == 'pickup'
                                          ? Colors.white
                                          : const Color(0xFF047857),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() => _activePinMode = 'drop');
                                  _showMessage(
                                      'Drop Mode ON: Map par tap karein drop point set karne ke liye (Red Pin).');
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: _activePinMode == 'drop'
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _activePinMode == 'drop'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFFECACA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Set Drop',
                                    style: TextStyle(
                                      color: _activePinMode == 'drop'
                                          ? Colors.white
                                          : const Color(0xFFB91C1C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _openSetLocationSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primaryBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_rounded,
                                          size: 13, color: AppColors.primary),
                                      SizedBox(width: 3),
                                      Text(
                                        'Search',
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (hasRoute) ...[
                                const SizedBox(width: 5),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _startLiveNavigation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x3310B981),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.navigation_rounded,
                                            size: 13, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'Start',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (_effectiveOrigin != null) ...[
                                const SizedBox(width: 5),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() {
                                      _pinnedOrigin = null;
                                      _routePoints = [];
                                      _trafficReport = null;
                                      _activePinMode = 'pickup';
                                    });
                                    widget.controller.setOrigin('');
                                    _showMessage(
                                        'Pickup reset. Ab map par naya pickup point tap karein.');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double get _remainingDistanceKm {
    if (_routePoints.length < 2) return 0;
    final total = _routeDistanceKm;
    final fraction = _navIndex / (_routePoints.length - 1);
    return (total * (1.0 - fraction)).clamp(0, total);
  }

  String get _remainingTimeStr {
    final dist = _remainingDistanceKm;
    if (dist <= 0) return 'Arrived';
    final speed = _currentSpeed > 0 ? _currentSpeed : 45.0;
    final hours = dist / speed;
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _buildTrafficLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.traffic_rounded, size: 13, color: AppColors.navy),
          const SizedBox(width: 6),
          _legendItem(const Color(0xFF10B981), 'Fast'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFF59E0B), 'Medium'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFEF4444), 'Slow/Jam'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }
}

// ==================== LIVE NAVIGATION TOP HUD ====================

class _NavigationTopHud extends StatelessWidget {
  const _NavigationTopHud({
    required this.turnInfo,
    required this.speed,
    required this.gpsSource,
    required this.compact,
    required this.vehicle,
    required this.remainingDistanceKm,
    required this.remainingTimeStr,
    required this.isLocked,
    required this.onRecenter,
    required this.onExit,
  });

  final NavigationTurnInfo? turnInfo;
  final double speed;
  final String gpsSource;
  final bool compact;
  final VehicleType vehicle;
  final double remainingDistanceKm;
  final String remainingTimeStr;
  final bool isLocked;
  final VoidCallback onRecenter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final info = turnInfo;
    final maneuver = info?.maneuver ?? ManeuverType.straight;
    final isOverspeeding = speed > 80.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Maneuver Direction Icon (Left, Right, Upper, Down)
                  Container(
                    width: compact ? 42 : 50,
                    height: compact ? 42 : 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D10B981),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      maneuver.icon,
                      color: Colors.white,
                      size: compact ? 27 : 32,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 14),

                  // Main Turn Instruction & Direction Side
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                maneuver.directionSide,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: speed < 1.0
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: speed < 1.0
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                speed < 1.0
                                    ? '$gpsSource · STOPPED'
                                    : '$gpsSource · LIVE',
                                style: TextStyle(
                                  color: speed < 1.0
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF047857),
                                  fontSize: compact ? 7.5 : 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info?.instructionHindi ?? 'सीधे चलें',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          speed < 1.0
                              ? 'रुकी हुई है (Physical movement hone par hi aage badhegi)'
                              : (info?.instructionEnglish ??
                                  'Continue straight'),
                          style: TextStyle(
                            color: speed < 1.0
                                ? const Color(0xFFD97706)
                                : AppColors.slate,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Live Speedometer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOverspeeding
                          ? const Color(0xFFFEE2E2)
                          : AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOverspeeding
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFD8E1EE),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          speed.toStringAsFixed(0),
                          style: TextStyle(
                            color: isOverspeeding
                                ? const Color(0xFFDC2626)
                                : speed < 1.0
                                    ? AppColors.slate
                                    : AppColors.blue,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          isOverspeeding
                              ? 'OVERSPEED'
                              : speed < 1.0
                                  ? 'STOPPED'
                                  : 'km/h',
                          style: TextStyle(
                            color: isOverspeeding || speed < 1.0
                                ? const Color(0xFFEF4444)
                                : AppColors.slate,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 10),

                  // Exit Navigation Button
                  IconButton(
                    onPressed: onExit,
                    tooltip: 'Exit Navigation',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              if (isOverspeeding) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'OVERSPEED WARNING: ${speed.toStringAsFixed(0)} km/h exceeds 80 km/h limit! Slow down to avoid E-Challan.',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 6),

              // Bottom Stats: Distance remaining, ETA, Vehicle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(vehicle.icon, size: 14, color: AppColors.slate),
                      const SizedBox(width: 6),
                      Text(
                        '${remainingDistanceKm.toStringAsFixed(1)} km remaining',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: AppColors.slate),
                      const SizedBox(width: 5),
                      Text(
                        'ETA: $remainingTimeStr',
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (!isLocked)
                    TextButton.icon(
                      onPressed: onRecenter,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.blue,
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 14),
                      label: const Text('Recenter',
                          style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LIVE NAVIGATION BOTTOM CONTROLS ====================

class _NavigationBottomControls extends StatelessWidget {
  const _NavigationBottomControls({
    required this.isLocked,
    required this.speed,
    required this.gpsSource,
    required this.compact,
    required this.onRecenter,
    required this.onStop,
  });

  final bool isLocked;
  final double speed;
  final String gpsSource;
  final bool compact;
  final VoidCallback onRecenter;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1A0F2440),
                  blurRadius: 14,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stop Navigation Button
              FilledButton.icon(
                onPressed: onStop,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: const Icon(Icons.stop_circle_rounded, size: 16),
                label: const Text(
                  'STOP (रोकें)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),

              // Real GPS Status Indicator Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF10B981), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      speed < 1.0
                          ? '$gpsSource · STOPPED'
                          : '$gpsSource · ${speed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),

              // Recenter Button
              IconButton(
                onPressed: onRecenter,
                tooltip: 'Lock Camera on Vehicle',
                style: IconButton.styleFrom(
                  backgroundColor:
                      isLocked ? const Color(0xFF2563EB) : AppColors.field,
                  foregroundColor: isLocked ? Colors.white : AppColors.navy,
                  side: isLocked
                      ? null
                      : const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ROUTE & TRAFFIC OVERVIEW CARD ====================

class _RouteTrafficCard extends StatelessWidget {
  const _RouteTrafficCard({
    required this.report,
    required this.origin,
    required this.destination,
    required this.vehicle,
    required this.trafficEnabled,
    required this.isLoadingRoute,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onStartNavigation,
    required this.onFitRoute,
    required this.onToggleTraffic,
    required this.onOpenNavigation,
    this.routeSummary = '',
  });

  final TrafficReport report;
  final String origin;
  final String destination;
  final VehicleType vehicle;
  final bool trafficEnabled;
  final bool isLoadingRoute;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onStartNavigation;
  final VoidCallback onFitRoute;
  final VoidCallback onToggleTraffic;
  final VoidCallback onOpenNavigation;
  final String routeSummary;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 480 ? (width - 32) : 380.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E0F2035),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: report.level.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.traffic_rounded,
                      size: 16,
                      color: report.level.color,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              report.formattedDistance,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.navy,
                              ),
                            ),
                            const Text(' · ',
                                style: TextStyle(color: AppColors.muted)),
                            Flexible(
                              child: Text(
                                '${report.formattedDuration} (${vehicle.label})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.blue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: report.level.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                report.level.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: report.level.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isLoadingRoute)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppColors.slate,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFEDF2F7)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (routeSummary.isNotEmpty &&
                      routeSummary.contains('->')) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route_rounded,
                              size: 14, color: AppColors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              routeSummary,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Show traffic metrics only when a licensed live provider is active.
                  if (trafficEnabled &&
                      MapTileService.hasAuthorizedTrafficProvider &&
                      report.clearPercent > 0 &&
                      report.moderatePercent > 0 &&
                      report.slowPercent > 0) ...[
                    Row(
                      children: [
                        const Text(
                          'Estimated Traffic Flow: ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${report.clearPercent}% Clear  ·  +${report.delayMinutes}m delay',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: report.level.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: Row(
                          children: [
                            Expanded(
                              flex: report.clearPercent,
                              child: const ColoredBox(color: Color(0xFF10B981)),
                            ),
                            Expanded(
                              flex: report.moderatePercent,
                              child: const ColoredBox(color: Color(0xFFF59E0B)),
                            ),
                            Expanded(
                              flex: report.slowPercent,
                              child: const ColoredBox(color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hindi & English Traffic Status Summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.summaryHindi,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            report.summary,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // PRIMARY ACTION: START LIVE NAVIGATION
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: onStartNavigation,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text(
                        'START LIVE NAVIGATION (शुरू करें)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary Actions: Fit Route, Google Maps
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onFitRoute,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.crop_free_rounded, size: 14),
                          label: const Text('Fit Route',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenNavigation,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('External Map',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Captures the pointer before FlutterMap's pan recognizer can claim it.
/// Raw pointer updates keep working consistently for mouse, touch and stylus
/// on web and native platforms.
class _DraggableMapMarker extends StatefulWidget {
  const _DraggableMapMarker({
    required this.child,
    required this.enabled,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  State<_DraggableMapMarker> createState() => _DraggableMapMarkerState();
}

class _DraggableMapMarkerState extends State<_DraggableMapMarker> {
  int? _activePointer;
  Offset? _downPosition;
  bool _dragStarted = false;

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryButton) == 0) {
      return;
    }
    _activePointer = event.pointer;
    _downPosition = event.position;
    _dragStarted = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || !widget.enabled) return;
    final down = _downPosition;
    if (down == null) return;
    if (!_dragStarted && (event.position - down).distance >= 4) {
      _dragStarted = true;
      widget.onDragStart(down);
    }
    if (_dragStarted) {
      widget.onDragUpdate(event.position);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    if (_dragStarted && widget.enabled) {
      widget.onDragEnd();
    } else {
      if (widget.enabled) widget.onDragCancel();
      widget.onTap();
    }
    _resetPointer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    if (widget.enabled) widget.onDragCancel();
    _resetPointer();
  }

  void _resetPointer() {
    _activePointer = null;
    _downPosition = null;
    _dragStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? (_dragStarted
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab)
          : MouseCursor.defer,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
            EagerGestureRecognizer.new,
            (_) {},
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: widget.child,
        ),
      ),
    );
  }
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.message);
  final String message;
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoom});
  final void Function(double) onZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 8)],
      ),
      child: Column(
        children: [
          IconButton(
            onPressed: () => onZoom(1),
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 42, child: Divider(height: 1)),
          IconButton(
            onPressed: () => onZoom(-1),
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.locating, required this.onPressed});
  final bool locating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'current-location',
      onPressed: locating ? null : onPressed,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.blue,
      tooltip: 'Use current location',
      child: locating
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location_rounded, size: 19),
    );
  }
}

class _FleetGpsButton extends StatelessWidget {
  const _FleetGpsButton({
    required this.hasCoords,
    required this.onPressed,
  });

  final bool hasCoords;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'fleet-gps-location',
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor:
          hasCoords ? const Color(0xFF16A34A) : const Color(0xFFD97706),
      tooltip: hasCoords
          ? 'Fleet Vehicles (Gadi ki location)'
          : 'Live Demo Telemetry load karein',
      child: Icon(
        hasCoords ? Icons.local_shipping_rounded : Icons.gps_fixed_rounded,
        size: 20,
      ),
    );
  }
}

class _MapTypeControl extends StatelessWidget {
  const _MapTypeControl({required this.controller});
  final PlannerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [BoxShadow(color: Color(0x260F2035), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapTypeItem(
            label: 'Street',
            icon: Icons.map_outlined,
            selected: controller.mapStyle == MapViewStyle.street,
            onTap: () => controller.setMapStyle(MapViewStyle.street),
          ),
          _MapTypeItem(
            label: 'Satellite',
            icon: Icons.satellite_alt_outlined,
            selected: controller.mapStyle == MapViewStyle.satellite,
            onTap: () => controller.setMapStyle(MapViewStyle.satellite),
          ),
        ],
      ),
    );
  }
}

class _MapTypeItem extends StatelessWidget {
  const _MapTypeItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.slate,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.slate,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.blue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: active
                ? Border.all(
                    color: effectiveActiveColor.withValues(alpha: .5),
                    width: 1.5,
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? effectiveActiveColor : AppColors.slate,
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? effectiveActiveColor : AppColors.slate,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge();

  @override
  Widget build(BuildContext context) {
    const trafficLabel = 'Google Live Traffic';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8)],
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: AppColors.green),
          SizedBox(width: 7),
          Text(
            'Google Maps · $trafficLabel',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMapBar extends StatelessWidget {
  const _CompactMapBar({
    required this.controller,
    required this.activePinMode,
    required this.trafficEnabled,
    required this.onToggleTraffic,
    required this.hasRoute,
    required this.onFitRoute,
    required this.onClearRoute,
    required this.onSetLocation,
    required this.onSetPickup,
    required this.onSetDrop,
  });

  final PlannerController controller;
  final String activePinMode;
  final bool trafficEnabled;
  final VoidCallback onToggleTraffic;
  final bool hasRoute;
  final VoidCallback onFitRoute;
  final VoidCallback onClearRoute;
  final VoidCallback onSetLocation;
  final VoidCallback onSetPickup;
  final VoidCallback onSetDrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F2035),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Set Location (Pickup & Drop search / picker)
          InkWell(
            onTap: onSetLocation,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.primaryBorder, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_location_alt_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'Route',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Dedicated Set Pickup Button (Green)
          InkWell(
            onTap: onSetPickup,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: activePinMode == 'pickup'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: activePinMode == 'pickup'
                      ? const Color(0xFF059669)
                      : const Color(0xFFA7F3D0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: 13,
                    color: activePinMode == 'pickup'
                        ? Colors.white
                        : const Color(0xFF047857),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Pickup',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: activePinMode == 'pickup'
                          ? Colors.white
                          : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Dedicated Set Drop Button (Red)
          InkWell(
            onTap: onSetDrop,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: activePinMode == 'drop'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: activePinMode == 'drop'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFFECACA),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: activePinMode == 'drop'
                        ? Colors.white
                        : const Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Drop',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: activePinMode == 'drop'
                          ? Colors.white
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Map Style switcher (Street <-> Satellite hybrid)
          InkWell(
            onTap: () {
              final next = controller.mapStyle == MapViewStyle.satellite
                  ? MapViewStyle.street
                  : MapViewStyle.satellite;
              controller.setMapStyle(next);
            },
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    controller.mapStyle == MapViewStyle.satellite
                        ? Icons.satellite_alt_rounded
                        : Icons.map_rounded,
                    size: 15,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    controller.mapStyle == MapViewStyle.satellite
                        ? 'Satellite'
                        : 'Street',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Live Traffic toggle icon
          _CompactIconButton(
            icon: Icons.traffic_rounded,
            tooltip: 'Google Live Traffic',
            active: trafficEnabled,
            activeColor: const Color(0xFF10B981),
            onTap: onToggleTraffic,
          ),
          const SizedBox(width: 4),
          // Pin on map toggle icon
          _CompactIconButton(
            icon: Icons.add_location_alt_outlined,
            tooltip: 'Pin on map',
            active: controller.pinMode,
            activeColor: const Color(0xFF2563EB),
            onTap: controller.togglePinMode,
          ),
          if (hasRoute) ...[
            const SizedBox(width: 4),
            _CompactIconButton(
              icon: Icons.crop_free_rounded,
              tooltip: 'Fit route',
              onTap: onFitRoute,
            ),
          ],
          if (hasRoute ||
              controller.origin.isNotEmpty ||
              controller.destination.isNotEmpty ||
              controller.stops.isNotEmpty) ...[
            const SizedBox(width: 4),
            _CompactIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear route & pins',
              onTap: onClearRoute,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.activeColor = const Color(0xFF2563EB),
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: active
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.6), width: 1.2)
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: active ? activeColor : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
