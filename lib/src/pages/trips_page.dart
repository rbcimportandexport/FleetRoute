import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/map_tile_service.dart';
import '../services/product_catalog_service.dart';
import '../services/reverse_geocoding_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cargo_workflow_dialogs.dart';
import '../widgets/delivery_proof_dialog.dart';
import '../widgets/trip_detail_report_dialog.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({
    required this.controller,
    this.onOpenPlanner,
    super.key,
  });

  final PlannerController controller;
  final VoidCallback? onOpenPlanner;

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _ProductCatalogPage extends StatefulWidget {
  const _ProductCatalogPage();

  @override
  State<_ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<_ProductCatalogPage> {
  final _searchController = TextEditingController();
  late final Future<List<CatalogProduct>> _products =
      ProductCatalogService.load();
  String _brand = 'ALL';
  String _category = 'ALL';
  String _query = '';

  static const _categories = <String>[
    'ALL',
    'BED',
    'CHAIR',
    'MANI PEDI',
    'MASSAGER',
    'SHAMPOO',
    'STOOL',
    'TROLLEY',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text(
          'RBC / RAMA Product Catalogue',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Product code ya category search karein',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('All')),
                      ButtonSegment(value: 'RBC', label: Text('RBC')),
                      ButtonSegment(value: 'RAMA', label: Text('RAMA')),
                    ],
                    selected: {_brand},
                    onSelectionChanged: (value) =>
                        setState(() => _brand = value.first),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: _categories.map((category) {
                      return ChoiceChip(
                        label: Text(
                            category == 'ALL' ? 'All Categories' : category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<CatalogProduct>>(
                      future: _products,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final filtered = snapshot.data!.where((product) {
                          final brandMatch =
                              _brand == 'ALL' || product.brand == _brand;
                          final categoryMatch = _category == 'ALL' ||
                              (_category == 'SHAMPOO'
                                  ? product.category.startsWith('SHAMPOO')
                                  : product.category == _category);
                          final text =
                              '${product.brand} ${product.category} ${product.code} ${product.name}'
                                  .toLowerCase();
                          return brandMatch &&
                              categoryMatch &&
                              (_query.isEmpty || text.contains(_query));
                        }).toList(growable: false);
                        if (filtered.isEmpty) {
                          return const Center(
                              child: Text('Koi matching product nahi mila.'));
                        }
                        return GridView.builder(
                          clipBehavior: Clip.hardEdge,
                          padding: const EdgeInsets.only(top: 2, bottom: 16),
                          itemCount: filtered.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisExtent: 218,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return InkWell(
                              onTap: () => Navigator.pop(context, product),
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(11)),
                                        child: Image.asset(
                                          product.photoAsset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                                Icons.broken_image_outlined,
                                                color: AppColors.slate,
                                                size: 34),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(product.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          Text(product.category,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.slate)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripsPageState extends State<TripsPage> {
  final referenceController = TextEditingController();
  final customerController = TextEditingController();
  final cargoDescController = TextEditingController();
  final cargoWeightController = TextEditingController();
  final departureTimeController = TextEditingController();
  final returnDepotController = TextEditingController();
  final driverInstructionsController = TextEditingController();
  gm.GoogleMapController? _tripGoogleMapController;
  bool _mapReady = false;

  TruckModel? selectedVehicle;
  String? selectedDriver;
  CatalogProduct? selectedCatalogProduct;

  LatLng? origin;
  final List<LatLng> stops = [];
  LatLng? destination;
  List<LatLng> _routePoints = [];
  double _plannedDistanceKm = 0;
  int _plannedDurationMinutes = 0;
  String _trafficSummary = '';
  bool _routeLoading = false;
  String? _routeError;
  int _routeRequestId = 0;
  DateTime? _historyDate;
  bool creating = false;
  MapViewStyle mapStyle = MapViewStyle.street;
  bool get satellite => mapStyle == MapViewStyle.satellite;
  bool get isStreetlight => mapStyle == MapViewStyle.streetlight;
  bool locating = false;
  bool savingTrip = false;
  bool showValidation = false;

  @override
  void initState() {
    super.initState();
    _initTripDefaults();
  }

  void _initTripDefaults() {
    referenceController.text = widget.controller.generateUniqueTripNumber();
    final now = DateTime.now();
    departureTimeController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    referenceController.dispose();
    customerController.dispose();
    cargoDescController.dispose();
    cargoWeightController.dispose();
    departureTimeController.dispose();
    returnDepotController.dispose();
    driverInstructionsController.dispose();
    _tripGoogleMapController?.dispose();
    super.dispose();
  }

  void _pin(LatLng point) {
    HapticFeedback.mediumImpact();
    setState(() {
      showValidation = false;
      if (origin == null) {
        origin = point;
      } else if (destination == null) {
        destination = point;
      } else {
        stops.add(destination!);
        destination = point;
      }
    });
    _fetchRoadPolyline();
  }

  void _startCreatingTrip() {
    _routeRequestId++;
    setState(() {
      creating = true;
      origin = null;
      destination = null;
      stops.clear();
      _routePoints = [];
      _plannedDistanceKm = 0;
      _plannedDurationMinutes = 0;
      _trafficSummary = '';
      _routeLoading = false;
      _routeError = null;
      showValidation = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && origin == null) _useCurrentLocation();
    });
  }

  void _cancelCreatingTrip() {
    _routeRequestId++;
    setState(() {
      creating = false;
      origin = null;
      destination = null;
      stops.clear();
      _routePoints = [];
      _routeLoading = false;
      _routeError = null;
      showValidation = false;
    });
  }

  final fm.MapController _flutterMapController = fm.MapController();

  void _centerMapOn(LatLng point, {double zoom = 16}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (kIsWeb) {
        try {
          _flutterMapController.move(point, zoom);
        } catch (_) {}
      }
      if (_mapReady) {
        _tripGoogleMapController?.animateCamera(
          gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(point.latitude, point.longitude),
            zoom,
          ),
        );
      }
    });
  }

  Future<void> _fetchRoadPolyline() async {
    final requestId = ++_routeRequestId;
    if (origin == null || destination == null) {
      if (_routePoints.isNotEmpty && mounted) {
        setState(() => _routePoints = []);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _routeLoading = true;
        _routeError = null;
      });
    }
    try {
      final res = await RouteTrafficService.fetchRoute(
        origin: origin!,
        destination: destination!,
        stops: stops,
      );
      if (mounted && requestId == _routeRequestId) {
        final traffic = RouteTrafficService.analyzeTraffic(
          distanceKm: res.distanceKm,
          vehicle: VehicleType.truck,
          truckModel: selectedVehicle,
        );
        setState(() {
          _routePoints = res.points;
          _plannedDistanceKm = res.distanceKm;
          _plannedDurationMinutes = traffic.duration.inMinutes;
          _trafficSummary = traffic.summary;
          if (!res.isRealHighwayRoute || res.points.length < 2) {
            _routeError =
                'Road route nahi mila. Internet check karke points dobara set karein.';
          }
        });
      }
    } catch (_) {
      if (mounted && requestId == _routeRequestId) {
        setState(() {
          _routePoints = [];
          _plannedDistanceKm = 0;
          _plannedDurationMinutes = 0;
          _trafficSummary = '';
          _routeError =
              'Road route load nahi hua. Internet check karke retry karein.';
        });
      }
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _routeLoading = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw Exception(
            'Phone ka GPS ON karke Current Location dobara dabayein.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw Exception('App Settings mein Location permission Allow karein.');
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
            'Location permission ke bina current location nahi milegi.');
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        throw Exception(
            'GPS location nahi mili. Khuli jagah mein dobara try karein.');
      }
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => origin = point);
      _centerMapOn(point);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _saveTrip() async {
    if (savingTrip) return;
    if (referenceController.text.trim().isEmpty ||
        origin == null ||
        destination == null ||
        selectedVehicle == null ||
        selectedDriver == null ||
        selectedDriver!.trim().isEmpty ||
        customerController.text.trim().isEmpty ||
        cargoDescController.text.trim().isEmpty) {
      setState(() => showValidation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pickup, drop, vehicle, driver, customer and cargo are required.',
          ),
        ),
      );
      return;
    }
    if (_routeLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Road route load ho raha hai…')),
      );
      return;
    }
    if (_routeError != null ||
        _routePoints.length < 2 ||
        _plannedDistanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_routeError ??
              'Valid road route nahi mila. Pickup/drop dobara set karein.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final cargoWeight =
        double.tryParse(cargoWeightController.text.trim()) ?? 0.0;
    final vehicleCap = selectedVehicle?.numericPayloadCapacityTon ?? 0.0;

    if (cargoWeight > 0 && vehicleCap > 0 && cargoWeight > vehicleCap) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payload Capacity Warning'),
          content: Text(
            'Entered cargo weight (${cargoWeight.toStringAsFixed(1)} Ton) exceeds vehicle payload capacity (${vehicleCap.toStringAsFixed(1)} Ton).\n\nAxle overload violation risk. Do you still wish to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel & Adjust'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => savingTrip = true);
    final pinnedPoints = <LatLng>[origin!, ...stops, destination!];
    final locationLabels = await Future.wait(
      pinnedPoints.map(ReverseGeocodingService.labelFor),
    );
    if (!mounted) return;
    final originText = locationLabels.first;
    final destinationText = locationLabels.last;
    final stopTexts = locationLabels.length > 2
        ? locationLabels.sublist(1, locationLabels.length - 1)
        : const <String>[];
    final tripNum = referenceController.text.trim();

    final newTrip = TripRecord(
      reference: tripNum,
      tripNumber: tripNum,
      customerName: customerController.text.trim(),
      assignedVehicle: selectedVehicle!.code,
      assignedDriver: selectedDriver!.trim(),
      cargoDescription: cargoDescController.text.trim(),
      cargoItems: cargoWeight > 0
          ? [
              CargoItem(
                id: 'C-1',
                productId: selectedCatalogProduct?.id ?? 'custom-product',
                brand: selectedCatalogProduct?.brand ?? '',
                category: selectedCatalogProduct?.category ?? '',
                photoAsset: selectedCatalogProduct?.photoAsset ?? '',
                productName: cargoDescController.text.trim().isNotEmpty
                    ? cargoDescController.text.trim()
                    : 'Industrial Goods',
                loadedQuantity: cargoWeight,
                unit: 'Ton',
              ),
            ]
          : const [],
      departureDateTime: departureTimeController.text.trim(),
      returnDepot: returnDepotController.text.trim(),
      driverInstructions: driverInstructionsController.text.trim(),
      origin: originText,
      destination: destinationText,
      stops: stopTexts,
      createdAt: DateTime.now().toIso8601String(),
      status: 'assigned',
      operationalStep: 'not_started',
      plannedDistanceKm: _plannedDistanceKm,
      plannedDurationMinutes: _plannedDurationMinutes,
      trafficSummary: _trafficSummary,
    );

    final error = await widget.controller.createTripWithValidation(newTrip);
    if (error != null) {
      if (mounted) {
        setState(() => savingTrip = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    widget.controller.setRoute(
      newOrigin: originText,
      newDestination: destinationText,
      newStops: stopTexts,
    );
    final totalPinned = 1 + (destination != null ? 1 : 0) + stops.length;
    if (!mounted) return;
    setState(() {
      creating = false;
      origin = null;
      destination = null;
      stops.clear();
      _routePoints = [];
      showValidation = false;
      _initTripDefaults();
      _plannedDistanceKm = 0;
      _plannedDurationMinutes = 0;
      _trafficSummary = '';
      _routeError = null;
      savingTrip = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Trip $tripNum saved with $totalPinned pinned places on map.'),
      ),
    );
    widget.onOpenPlanner?.call();
  }

  Future<void> _openRoute(TripRecord trip) async {
    final query = <String, String>{
      'api': '1',
      'origin': trip.origin,
      'destination': trip.destination,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };
    if (trip.stops.isNotEmpty) {
      query['waypoints'] = trip.stops.join('|');
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', query);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  Future<void> _deleteTrip(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip?'),
        content:
            const Text('This saved trip will be removed from this device.'),
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
      await widget.controller.removeTrip(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => ColoredBox(
        color: AppColors.canvas,
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TripsHeader(
                  creating: creating,
                  onAction: creating ? _cancelCreatingTrip : _startCreatingTrip,
                ),
                const SizedBox(height: 16),
                Expanded(child: creating ? _creator() : _tripList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _creator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final map = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: kIsWeb
                    ? fm.FlutterMap(
                        mapController: _flutterMapController,
                        options: fm.MapOptions(
                          initialCenter:
                              origin ?? const LatLng(21.1702, 72.8311),
                          initialZoom: origin == null ? 11.0 : 15.0,
                          minZoom: 3.0,
                          maxZoom: 19.0,
                          onLongPress: (tapPosition, point) => _pin(point),
                        ),
                        children: [
                          fm.TileLayer(
                            key: ValueKey(mapStyle),
                            urlTemplate: MapTileService.getTileUrl(
                              satellite: satellite,
                              streetlight: isStreetlight,
                              traffic: false,
                            ),
                            subdomains: MapTileService.getSubdomains(
                              streetlight: isStreetlight,
                            ),
                            fallbackUrl: MapTileService.fallbackTileUrl,
                            maxNativeZoom: 19,
                            userAgentPackageName: MapTileService.userAgent,
                            maxZoom: 19,
                          ),
                          fm.PolylineLayer(
                            polylines: [
                              if (origin != null && destination != null)
                                fm.Polyline(
                                  points: _routePoints.isNotEmpty
                                      ? _routePoints
                                      : [origin!, ...stops, destination!],
                                  color: AppColors.blue,
                                  strokeWidth: 5,
                                ),
                            ],
                          ),
                          fm.MarkerLayer(
                            markers: [
                              if (origin != null)
                                fm.Marker(
                                  point: origin!,
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.bottomCenter,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 38,
                                  ),
                                ),
                              for (int i = 0; i < stops.length; i++)
                                fm.Marker(
                                  point: stops[i],
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.bottomCenter,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.orange,
                                    size: 34,
                                  ),
                                ),
                              if (destination != null)
                                fm.Marker(
                                  point: destination!,
                                  width: 60,
                                  height: 60,
                                  alignment: Alignment.bottomCenter,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 38,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                    : gm.GoogleMap(
                        key: ValueKey(mapStyle),
                        initialCameraPosition: gm.CameraPosition(
                          target: gm.LatLng(
                            (origin ?? const LatLng(21.1702, 72.8311)).latitude,
                            (origin ?? const LatLng(21.1702, 72.8311))
                                .longitude,
                          ),
                          zoom: origin == null ? 11 : 15,
                        ),
                        mapType:
                            satellite ? gm.MapType.hybrid : gm.MapType.normal,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        gestureRecognizers: <Factory<
                            OneSequenceGestureRecognizer>>{
                          Factory<EagerGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                        onMapCreated: (controller) {
                          _tripGoogleMapController = controller;
                          _mapReady = true;
                          if (origin != null) _centerMapOn(origin!);
                        },
                        onLongPress: (point) =>
                            _pin(LatLng(point.latitude, point.longitude)),
                        polylines: {
                          if (origin != null && destination != null)
                            gm.Polyline(
                              polylineId:
                                  const gm.PolylineId('planned-trip-route'),
                              points: (_routePoints.isNotEmpty
                                      ? _routePoints
                                      : [origin!, ...stops, destination!])
                                  .map((point) => gm.LatLng(
                                      point.latitude, point.longitude))
                                  .toList(growable: false),
                              color: AppColors.blue,
                              width: 5,
                            ),
                        },
                        markers: {
                          if (origin != null)
                            gm.Marker(
                              markerId: const gm.MarkerId('pickup'),
                              position: gm.LatLng(
                                  origin!.latitude, origin!.longitude),
                              infoWindow: const gm.InfoWindow(title: 'Pickup'),
                              icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                                  gm.BitmapDescriptor.hueGreen),
                            ),
                          for (int i = 0; i < stops.length; i++)
                            gm.Marker(
                              markerId: gm.MarkerId('stop-$i'),
                              position: gm.LatLng(
                                  stops[i].latitude, stops[i].longitude),
                              infoWindow: gm.InfoWindow(title: 'Stop ${i + 1}'),
                              icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                                  gm.BitmapDescriptor.hueOrange),
                            ),
                          if (destination != null)
                            gm.Marker(
                              markerId: const gm.MarkerId('drop'),
                              position: gm.LatLng(destination!.latitude,
                                  destination!.longitude),
                              infoWindow: const gm.InfoWindow(title: 'Drop'),
                              icon: gm.BitmapDescriptor.defaultMarkerWithHue(
                                  gm.BitmapDescriptor.hueRed),
                            ),
                        },
                      ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: SegmentedButton<MapViewStyle>(
                  segments: const [
                    ButtonSegment(
                      value: MapViewStyle.street,
                      label: Text('Street'),
                      icon: Icon(Icons.map_outlined),
                    ),
                    ButtonSegment(
                      value: MapViewStyle.satellite,
                      label: Text('Satellite'),
                      icon: Icon(Icons.satellite_alt_outlined),
                    ),
                  ],
                  selected: {mapStyle},
                  onSelectionChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() => mapStyle = value.first);
                    }
                  },
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xEFFFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFB8C7D9)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              size: 17, color: AppColors.primary),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              origin == null
                                  ? 'Pickup ke liye map par hold karein'
                                  : destination == null
                                      ? 'Drop ke liye map par hold karein'
                                      : 'Via Stop add karne ke liye hold karein',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        final panel = _TripSetupPanel(
          referenceController: referenceController,
          onRegenerateTripNumber: () => setState(() {
            referenceController.text =
                widget.controller.generateUniqueTripNumber();
          }),
          customerController: customerController,
          cargoDescController: cargoDescController,
          cargoWeightController: cargoWeightController,
          selectedCatalogProduct: selectedCatalogProduct,
          onChooseProduct: () async {
            final product = await Navigator.of(context).push<CatalogProduct>(
              MaterialPageRoute(
                builder: (_) => const _ProductCatalogPage(),
              ),
            );
            if (product != null && mounted) {
              setState(() {
                selectedCatalogProduct = product;
                cargoDescController.text = product.displayName;
              });
            }
          },
          departureTimeController: departureTimeController,
          returnDepotController: returnDepotController,
          driverInstructionsController: driverInstructionsController,
          truckModels: widget.controller.truckModels,
          selectedVehicle: selectedVehicle,
          onVehicleSelected: (v) => setState(() => selectedVehicle = v),
          drivers: widget.controller.drivers,
          selectedDriver: selectedDriver,
          onDriverSelected: (d) => setState(() => selectedDriver = d),
          origin: origin,
          stops: stops,
          destination: destination,
          locating: locating,
          showValidation: showValidation,
          onCurrentLocation: _useCurrentLocation,
          onMoveStopUp: (i) {
            if (i > 0) {
              setState(() {
                final temp = stops[i];
                stops[i] = stops[i - 1];
                stops[i - 1] = temp;
              });
              _fetchRoadPolyline();
            }
          },
          onMoveStopDown: (i) {
            if (i < stops.length - 1) {
              setState(() {
                final temp = stops[i];
                stops[i] = stops[i + 1];
                stops[i + 1] = temp;
              });
              _fetchRoadPolyline();
            }
          },
          onRemoveStop: (i) {
            setState(() => stops.removeAt(i));
            _fetchRoadPolyline();
          },
          onReset: () => setState(() {
            origin = null;
            stops.clear();
            destination = null;
            showValidation = false;
          }),
          onSave: _saveTrip,
        );

        if (compact) {
          final mapHeight = (constraints.maxHeight * .5).clamp(300.0, 430.0);
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: mapHeight, child: map),
                const SizedBox(height: 12),
                panel,
                const SizedBox(height: 90),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: map),
            const SizedBox(width: 16),
            SizedBox(
              width: 340,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tripList() {
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.controller.trips.isEmpty) {
      return _EmptyTrips(onAdd: _startCreatingTrip);
    }
    final source = widget.controller.trips.indexed.where((entry) {
      if (_historyDate == null) return true;
      final trip = entry.$2;
      final rawDate = trip.startedAt.isNotEmpty
          ? trip.startedAt
          : (trip.departureDateTime.isNotEmpty
              ? trip.departureDateTime.replaceFirst(' ', 'T')
              : trip.createdAt);
      final date = DateTime.tryParse(rawDate);
      return date != null &&
          date.year == _historyDate!.year &&
          date.month == _historyDate!.month &&
          date.day == _historyDate!.day;
    });
    final indexed = source.toList().reversed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _TripSummary(trips: widget.controller.trips),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _historyDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _historyDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(_historyDate == null
                  ? 'Date-wise trip history'
                  : '${_historyDate!.day.toString().padLeft(2, '0')}-${_historyDate!.month.toString().padLeft(2, '0')}-${_historyDate!.year}'),
            ),
          ),
          if (_historyDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Show all trips',
              onPressed: () => setState(() => _historyDate = null),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        if (indexed.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('Is date par koi trip record nahi hai.')),
          ),
        for (final entry in indexed) ...[
          _TripCard(
            trip: entry.$2,
            tripIndex: entry.$1,
            controller: widget.controller,
            onOpen: () => _openRoute(entry.$2),
            onOpenInPlanner: () {
              widget.controller.setRoute(
                newOrigin: entry.$2.origin,
                newDestination: entry.$2.destination,
                newStops: entry.$2.stops,
              );
              widget.onOpenPlanner?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Trip "${entry.$2.reference}" Planner Map me load ho gaya!'),
                ),
              );
            },
            onStatus: (status) =>
                widget.controller.updateTripStatus(entry.$1, status),
            onDelete: () => _deleteTrip(entry.$1),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TripsHeader extends StatelessWidget {
  const _TripsHeader({required this.creating, required this.onAction});
  final bool creating;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                creating ? 'Create trip on map' : 'Trips',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                creating
                    ? 'Pin pickup first, then pin the destination.'
                    : 'Plan, save and launch real journeys.',
                style: const TextStyle(color: AppColors.slate),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAction,
          icon: Icon(creating ? Icons.close_rounded : Icons.add_rounded),
          label: Text(creating ? 'Cancel' : 'Add trip'),
        ),
      ],
    );
  }
}

class _TripSetupPanel extends StatelessWidget {
  const _TripSetupPanel({
    required this.referenceController,
    required this.onRegenerateTripNumber,
    required this.customerController,
    required this.cargoDescController,
    required this.cargoWeightController,
    required this.selectedCatalogProduct,
    required this.onChooseProduct,
    required this.departureTimeController,
    required this.returnDepotController,
    required this.driverInstructionsController,
    required this.truckModels,
    required this.selectedVehicle,
    required this.onVehicleSelected,
    required this.drivers,
    required this.selectedDriver,
    required this.onDriverSelected,
    required this.origin,
    required this.stops,
    required this.destination,
    required this.locating,
    required this.showValidation,
    required this.onCurrentLocation,
    required this.onMoveStopUp,
    required this.onMoveStopDown,
    required this.onRemoveStop,
    required this.onReset,
    required this.onSave,
  });

  final TextEditingController referenceController;
  final VoidCallback onRegenerateTripNumber;
  final TextEditingController customerController;
  final TextEditingController cargoDescController;
  final TextEditingController cargoWeightController;
  final CatalogProduct? selectedCatalogProduct;
  final VoidCallback onChooseProduct;
  final TextEditingController departureTimeController;
  final TextEditingController returnDepotController;
  final TextEditingController driverInstructionsController;

  final List<TruckModel> truckModels;
  final TruckModel? selectedVehicle;
  final ValueChanged<TruckModel?> onVehicleSelected;

  final List<DriverProfile> drivers;
  final String? selectedDriver;
  final ValueChanged<String?> onDriverSelected;

  final LatLng? origin;
  final List<LatLng> stops;
  final LatLng? destination;
  final bool locating;
  final bool showValidation;
  final VoidCallback onCurrentLocation;
  final ValueChanged<int> onMoveStopUp;
  final ValueChanged<int> onMoveStopDown;
  final ValueChanged<int> onRemoveStop;
  final VoidCallback onReset;
  final VoidCallback onSave;

  void _showSelectedProduct(BuildContext context, CatalogProduct product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${product.displayName} · ${product.category}'),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(40),
                child: Image.asset(product.photoAsset, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String coordinate(LatLng? point) => point == null
      ? 'Tap the map to select'
      : '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

  @override
  Widget build(BuildContext context) {
    final cargoWeight =
        double.tryParse(cargoWeightController.text.trim()) ?? 0.0;
    final vehicleCap = selectedVehicle?.numericPayloadCapacityTon ?? 0.0;
    final isOverloaded =
        cargoWeight > 0 && vehicleCap > 0 && cargoWeight > vehicleCap;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Trip Identifier & Customer
          const Text(
            'TRIP IDENTIFIER & CUSTOMER',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onChooseProduct,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(
              selectedCatalogProduct == null
                  ? 'Choose RBC / RAMA Product with Photo'
                  : '${selectedCatalogProduct!.brand} · ${selectedCatalogProduct!.category} · ${selectedCatalogProduct!.code}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectedCatalogProduct != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () =>
                        _showSelectedProduct(context, selectedCatalogProduct!),
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            selectedCatalogProduct!.photoAsset,
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCatalogProduct!.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          selectedCatalogProduct!.category,
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Trip Number / Reference',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRegenerateTripNumber,
                tooltip: 'Auto-generate sequential trip number',
                icon: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: customerController,
            decoration: const InputDecoration(
              labelText: 'Customer / Client Name',
              hintText: 'Tata Steel Logistics',
              isDense: true,
            ),
          ),

          const SizedBox(height: 14),

          // 2. Fleet Vehicle & Driver Selection
          const Text(
            'FLEET VEHICLE & DRIVER',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedVehicle?.code,
            decoration: const InputDecoration(
              labelText: 'Assigned Vehicle',
              isDense: true,
            ),
            items: truckModels.map((truck) {
              final isInactive = truck.isDisabled || truck.isUnderMaintenance;
              return DropdownMenuItem<String>(
                value: truck.code,
                child: Text(
                  '${truck.code} (${truck.payloadCapacity})${isInactive ? " [${truck.vehicleStatus.toUpperCase()}]" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isInactive ? const Color(0xFFDC2626) : AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (code) {
              if (code == null) return;
              try {
                final found = truckModels.firstWhere((t) => t.code == code);
                onVehicleSelected(found);
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedDriver,
            decoration: const InputDecoration(
              labelText: 'Assigned Driver',
              isDense: true,
            ),
            items: drivers.map((driver) {
              return DropdownMenuItem<String>(
                value: driver.name,
                child: Text(
                  '${driver.name} (Lic: ${driver.licenseNumber.isNotEmpty ? driver.licenseNumber : "Verified"})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onDriverSelected,
          ),

          const SizedBox(height: 14),

          // 3. Cargo Details & Payload Capacity Validation
          const Text(
            'CARGO & PAYLOAD VALIDATION',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: TextField(
                  controller: cargoDescController,
                  decoration: const InputDecoration(
                    labelText: 'Cargo Description',
                    hintText: 'Industrial Goods',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: cargoWeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight (Ton)',
                    hintText: '12',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),

          // Live Vehicle Capacity Status Badge
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isOverloaded
                  ? const Color(0xFFFEF2F2)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOverloaded
                    ? const Color(0xFFFECACA)
                    : AppColors.primaryBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOverloaded
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: isOverloaded
                      ? const Color(0xFFDC2626)
                      : AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOverloaded
                        ? 'Capacity Warning: Cargo (${cargoWeight.toStringAsFixed(1)} T) exceeds vehicle payload capacity (${vehicleCap.toStringAsFixed(1)} T)!'
                        : (vehicleCap > 0
                            ? 'Payload OK: ${cargoWeight.toStringAsFixed(1)} T / ${vehicleCap.toStringAsFixed(1)} T vehicle capacity.'
                            : 'Vehicle capacity: Available'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isOverloaded
                          ? const Color(0xFFB91C1C)
                          : AppColors.primaryDark,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Departure Time & Return Depot
          const Text(
            'DISPATCH & INSTRUCTIONS',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: departureTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Departure Date / Time',
                    hintText: 'YYYY-MM-DD HH:MM',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: returnDepotController,
                  decoration: const InputDecoration(
                    labelText: 'Return Depot / Yard',
                    hintText: 'Central Hub',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: driverInstructionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Driver Instructions',
              hintText:
                  'Special handling instructions, delivery radius, recipient checks...',
              isDense: true,
            ),
          ),

          const SizedBox(height: 14),

          // 5. Pinned Locations on Map
          const Text(
            'PINNED ROUTE & STOPS',
            style: TextStyle(
              color: AppColors.slate,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(height: 10),
          _PinnedLocation(
            label: '1. Pickup / origin',
            value: coordinate(origin),
            color: const Color(0xFF168547),
            selected: origin != null,
          ),
          const SizedBox(height: 8),
          _PinnedLocation(
            label: '2. Destination (Drop Point)',
            value: destination != null
                ? coordinate(destination)
                : (origin != null
                    ? 'Optional: Tap map to pin destination'
                    : 'Tap the map to select'),
            color: const Color(0xFFD83B4B),
            selected: destination != null,
          ),

          // Via Stops with Reordering Controls
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (int i = 0; i < stops.length; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Via Stop ${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          Text(
                            coordinate(stops[i]),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFB45309),
                              fontFamily: 'sans-serif',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                      onPressed: i > 0 ? () => onMoveStopUp(i) : null,
                      tooltip: 'Move Up',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                      onPressed:
                          i < stops.length - 1 ? () => onMoveStopDown(i) : null,
                      tooltip: 'Move Down',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      onPressed: () => onRemoveStop(i),
                      tooltip: 'Remove stop',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: locating ? null : onCurrentLocation,
            icon: locating
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: const Text('Use GPS as pickup'),
          ),

          if (showValidation)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Enter trip reference, assign driver & vehicle, and pin at least 1 location.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),

          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(onPressed: onReset, child: const Text('Reset pins')),
              const Spacer(),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  stops.isNotEmpty
                      ? 'Save (${2 + stops.length} Places)'
                      : 'Save trip',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinnedLocation extends StatelessWidget {
  const _PinnedLocation({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
  });
  final String label;
  final String value;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .06) : AppColors.field,
        border: Border.all(
            color: selected ? color.withValues(alpha: .45) : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(value,
                    style:
                        const TextStyle(color: AppColors.slate, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trips});
  final List<TripRecord> trips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final cardWidth = isCompact ? (constraints.maxWidth - 16) / 3 : 180.0;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TripCount(
              label: isCompact ? 'Total' : 'Total trips',
              value: trips.length,
              width: cardWidth,
            ),
            _TripCount(
              label: 'Active',
              value: trips
                  .where((trip) =>
                      trip.status == 'assigned' || trip.status == 'in_progress')
                  .length,
              width: cardWidth,
            ),
            _TripCount(
              label: 'Done',
              value: trips.where((trip) => trip.status == 'completed').length,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }
}

class _TripCount extends StatelessWidget {
  const _TripCount({
    required this.label,
    required this.value,
    this.width = 180,
  });
  final String label;
  final int value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F2440),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.tripIndex,
    required this.controller,
    required this.onOpen,
    required this.onOpenInPlanner,
    required this.onStatus,
    required this.onDelete,
  });

  final TripRecord trip;
  final int tripIndex;
  final PlannerController controller;
  final VoidCallback onOpen;
  final VoidCallback onOpenInPlanner;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  static const _validStatuses = [
    'planned',
    'assigned',
    'in_progress',
    'in_transit',
    'delivered',
    'completed',
    'cancelled',
  ];

  String get _safeStatus =>
      _validStatuses.contains(trip.status) ? trip.status : 'planned';

  void _showAuditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _TripAuditBillingDialog(
        trip: trip,
        tripIndex: tripIndex,
        controller: controller,
      ),
    );
  }

  void _showPhotoPreview(
      BuildContext context, String title, String photoBase64) {
    showDialog<void>(
      context: context,
      builder: (_) => _TripPhotoPreviewDialog(
        title: title,
        photoBase64: photoBase64,
      ),
    );
  }

  void _showProductPhoto(BuildContext context, CargoItem item) {
    if (item.photoAsset.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.brand} ${item.productName} · ${item.category}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.asset(item.photoAsset, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCargoLedger(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => CargoLedgerDialog(
        trip: trip,
      ),
    );
  }

  void _showDeliveryProofs(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => DeliveryProofGalleryDialog(
        trip: trip,
        controller: controller,
      ),
    );
  }

  Future<void> _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    await launchUrl(Uri.parse('tel:$clean'));
  }

  @override
  Widget build(BuildContext context) {
    final hasPod = trip.podStatus == 'received';
    final hasReceiving = trip.receivingCopyStatus == 'received';
    final isProfitable = trip.isProfitable;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F2440),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Icon, Trip #, Customer, Status Dropdown & Delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconBadge(
                icon: Icons.assignment_outlined,
                size: 20,
                padding: 7,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        InkWell(
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => TripDetailReportDialog(
                                trip: trip,
                                controller: controller,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Trip # ${trip.effectiveTripNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.navy,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new_rounded,
                                  size: 13, color: AppColors.primary),
                            ],
                          ),
                        ),
                        if (trip.reference.isNotEmpty &&
                            trip.reference != trip.effectiveTripNumber)
                          Text(
                            '(${trip.reference})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                      ],
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          trip.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.primaryDark,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            final matches = controller.customers.where(
                              (customer) =>
                                  customer.name.trim().toLowerCase() ==
                                  trip.customerName.trim().toLowerCase(),
                            );
                            if (matches.isNotEmpty &&
                                matches.first.phone.trim().isNotEmpty) {
                              _callCustomer(matches.first.phone);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primaryLight),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_outlined,
                                    size: 10, color: AppColors.primaryDark),
                                SizedBox(width: 3),
                                Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete trip',
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Assigned Vehicle, Driver, Status, Cargo & E-Way Bill
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _safeStatus,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'planned', child: Text('Planned')),
                      DropdownMenuItem(
                          value: 'assigned', child: Text('Assigned')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('In Progress')),
                      DropdownMenuItem(
                          value: 'in_transit', child: Text('In Transit')),
                      DropdownMenuItem(
                          value: 'delivered', child: Text('Delivered')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (value) {
                      if (value != null) onStatus(value);
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 13, color: AppColors.iconColor),
                    const SizedBox(width: 4),
                    Text(
                      trip.assignedVehicle.isNotEmpty
                          ? trip.assignedVehicle
                          : 'UNASSIGNED',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 13, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      trip.assignedDriver.isNotEmpty
                          ? trip.assignedDriver
                          : 'UNASSIGNED',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E40AF),
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              if (trip.ewayBillNumber.isNotEmpty)
                InkWell(
                  onTap: () => _showPhotoPreview(
                    context,
                    'E-Way Bill: ${trip.ewayBillNumber}',
                    trip.ewayBillPhoto,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 13, color: AppColors.slate),
                        const SizedBox(width: 4),
                        Text(
                          'E-Way: ${trip.ewayBillNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          if (trip.plannedDistanceKm > 0 || trip.startedAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9F5),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFBFE5D2)),
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  if (trip.plannedDistanceKm > 0)
                    Text(
                      'Route: ${trip.plannedDistanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  if (trip.plannedDurationMinutes > 0)
                    Text(
                      'ETA: ${trip.plannedDurationMinutes ~/ 60}h ${trip.plannedDurationMinutes % 60}m',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  if (trip.actualDuration != null)
                    Text(
                      'Actual time: ${trip.actualDuration!.inHours}h ${trip.actualDuration!.inMinutes.remainder(60)}m',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  if (trip.actualDistanceKm > 0)
                    Text(
                        'Actual: ${trip.actualDistanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(
                    trip.averageSpeedKmh > 0
                        ? 'Avg speed: ${trip.averageSpeedKmh.toStringAsFixed(1)} km/h'
                        : 'Avg speed: GPS data not recorded',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  if (trip.trafficSummary.isNotEmpty)
                    SizedBox(
                      width: 360,
                      child: Text('Traffic: ${trip.trafficSummary}',
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.slate)),
                    ),
                ],
              ),
            ),
          ],

          // Cargo Balance & Stop Ledger Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (trip.cargoItems.any((item) => item.photoAsset.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _showProductPhoto(
                        context,
                        trip.cargoItems.firstWhere(
                          (item) => item.photoAsset.isNotEmpty,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          trip.cargoItems
                              .firstWhere((item) => item.photoAsset.isNotEmpty)
                              .photoAsset,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                const Icon(Icons.inventory_2_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cargo: ${trip.cargoDescription}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                                fontFamily: 'sans-serif',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => _showCargoLedger(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: AppColors.primaryBorder),
                              ),
                              child: const Text(
                                'STOP LEDGER',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Load: ${trip.totalLoadedCargo.toStringAsFixed(1)}T',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Delivered: ${trip.totalDeliveredCargo.toStringAsFixed(1)}T',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ),
                          if (trip.totalRemainingCargo > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Rem: ${trip.totalRemainingCargo.toStringAsFixed(1)}T',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          if (trip.totalDamagedCargo > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Damage: ${trip.totalDamagedCargo.toStringAsFixed(1)}T',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          if (trip.totalReturnedCargo > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Returned: ${trip.totalReturnedCargo.toStringAsFixed(1)}T',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Route: Origin -> Destination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.radio_button_checked,
                    size: 13, color: AppColors.iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.origin,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 13, color: AppColors.iconColor),
                ),
                const Icon(Icons.location_on_rounded,
                    size: 13, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 4. Loading / Unloading Timestamps & Milestone Chips
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Loading Time:',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    Text(
                      trip.loadingDateTime.isNotEmpty
                          ? trip.loadingDateTime
                          : 'Pending',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: trip.loadingDateTime.isNotEmpty
                            ? AppColors.navy
                            : const Color(0xFFF59E0B),
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unloading Time:',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    Text(
                      trip.unloadingDateTime.isNotEmpty
                          ? trip.unloadingDateTime
                          : 'Pending',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: trip.unloadingDateTime.isNotEmpty
                            ? AppColors.navy
                            : const Color(0xFFF59E0B),
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 5. POD & Signed Receiving Copy Quick Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: () => _showPhotoPreview(
                  context,
                  'Proof of Delivery (POD) - Trip ${trip.effectiveTripNumber}',
                  trip.podPhoto,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasPod
                        ? AppColors.primaryLight
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasPod
                          ? AppColors.iconBadgeBorder
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPod
                            ? Icons.verified_rounded
                            : Icons.pending_outlined,
                        size: 13,
                        color: hasPod
                            ? AppColors.primaryDark
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'POD: ${trip.podStatus.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: hasPod
                              ? AppColors.primaryDark
                              : const Color(0xFFB45309),
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showPhotoPreview(
                  context,
                  'Signed Receiving Copy - Trip ${trip.effectiveTripNumber}',
                  trip.receivingCopyPhoto,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasReceiving
                        ? AppColors.primaryLight
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasReceiving
                          ? AppColors.iconBadgeBorder
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasReceiving
                            ? Icons.verified_rounded
                            : Icons.pending_outlined,
                        size: 13,
                        color: hasReceiving
                            ? AppColors.primaryDark
                            : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'RECEIVING: ${trip.receivingCopyStatus.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: hasReceiving
                              ? AppColors.primaryDark
                              : const Color(0xFFB45309),
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // 6. Freight Billing & Customer Invoice Breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'FREIGHT BILLING & INVOICE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate,
                        letterSpacing: 0.5,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    if (trip.customerInvoiceNumber.isNotEmpty)
                      Text(
                        'Inv: ${trip.customerInvoiceNumber} (${trip.customerInvoiceStatus.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Freight Rate',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.slate)),
                          Text(
                            '₹${trip.freightAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Advance Paid',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.slate)),
                          Text(
                            '₹${trip.advancePaid.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Balance Due',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.slate)),
                          Text(
                            '₹${trip.balanceDue.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 7. Audited Trip Expenses & Trip-Wise Profit & Loss (P&L) Report
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isProfitable
                  ? AppColors.primarySoft
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isProfitable
                    ? AppColors.primaryBorder
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfitable
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 15,
                          color: isProfitable
                              ? AppColors.primaryDark
                              : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TRIP P&L (PROFIT & LOSS)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isProfitable
                                ? AppColors.primaryDark
                                : const Color(0xFFDC2626),
                            letterSpacing: 0.5,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isProfitable
                            ? AppColors.primaryLight
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Net: ₹${trip.netProfit.toStringAsFixed(0)} (${trip.profitMarginPercentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isProfitable
                              ? AppColors.primaryDark
                              : const Color(0xFFDC2626),
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Expenses: Diesel ₹${trip.dieselExpense.toStringAsFixed(0)} · Toll ₹${trip.tollExpense.toStringAsFixed(0)} · Parking ₹${trip.parkingExpense.toStringAsFixed(0)} · Bhatta ₹${trip.driverAllowance.toStringAsFixed(0)} (Total ₹${trip.totalExpenses.toStringAsFixed(0)})',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.slate,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 8. Action Row: Audit Billing, Planner, Maps
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _showDeliveryProofs(context),
                    icon: const Icon(Icons.verified_user_outlined, size: 14),
                    label: const Text('Delivery Proofs',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primaryDark,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAuditDialog(context),
                    icon: const Icon(Icons.calculate_outlined, size: 14),
                    label: const Text('Audit Billing & Expenses',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primaryDark,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenInPlanner,
                    icon: const Icon(Icons.map_rounded,
                        size: 14, color: AppColors.blue),
                    label:
                        const Text('Planner', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.navigation_outlined, size: 14),
                    label: const Text('Maps', style: TextStyle(fontSize: 11)),
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
        ],
      ),
    );
  }
}

class _TripAuditBillingDialog extends StatefulWidget {
  const _TripAuditBillingDialog({
    required this.trip,
    required this.tripIndex,
    required this.controller,
  });

  final TripRecord trip;
  final int tripIndex;
  final PlannerController controller;

  @override
  State<_TripAuditBillingDialog> createState() =>
      _TripAuditBillingDialogState();
}

class _TripAuditBillingDialogState extends State<_TripAuditBillingDialog> {
  late final TextEditingController freightCtrl;
  late final TextEditingController advanceCtrl;
  late final TextEditingController invoiceNumCtrl;
  late final TextEditingController dieselCtrl;
  late final TextEditingController tollCtrl;
  late final TextEditingController parkingCtrl;
  late final TextEditingController bhattaCtrl;
  late final TextEditingController otherCtrl;
  late String invoiceStatus;
  late String podStatus;
  late String rcvStatus;

  @override
  void initState() {
    super.initState();
    freightCtrl = TextEditingController(
        text: widget.trip.freightAmount > 0
            ? widget.trip.freightAmount.toStringAsFixed(0)
            : '');
    advanceCtrl = TextEditingController(
        text: widget.trip.advancePaid > 0
            ? widget.trip.advancePaid.toStringAsFixed(0)
            : '');
    invoiceNumCtrl =
        TextEditingController(text: widget.trip.customerInvoiceNumber);
    dieselCtrl = TextEditingController(
        text: widget.trip.dieselExpense > 0
            ? widget.trip.dieselExpense.toStringAsFixed(0)
            : '');
    tollCtrl = TextEditingController(
        text: widget.trip.tollExpense > 0
            ? widget.trip.tollExpense.toStringAsFixed(0)
            : '');
    parkingCtrl = TextEditingController(
        text: widget.trip.parkingExpense > 0
            ? widget.trip.parkingExpense.toStringAsFixed(0)
            : '');
    bhattaCtrl = TextEditingController(
        text: widget.trip.driverAllowance > 0
            ? widget.trip.driverAllowance.toStringAsFixed(0)
            : '');
    otherCtrl = TextEditingController(
        text: widget.trip.otherExpense > 0
            ? widget.trip.otherExpense.toStringAsFixed(0)
            : '0');
    invoiceStatus = widget.trip.customerInvoiceStatus.isNotEmpty
        ? widget.trip.customerInvoiceStatus
        : 'draft';
    podStatus =
        widget.trip.podStatus.isNotEmpty ? widget.trip.podStatus : 'pending';
    rcvStatus = widget.trip.receivingCopyStatus.isNotEmpty
        ? widget.trip.receivingCopyStatus
        : 'pending';
  }

  @override
  void dispose() {
    freightCtrl.dispose();
    advanceCtrl.dispose();
    invoiceNumCtrl.dispose();
    dieselCtrl.dispose();
    tollCtrl.dispose();
    parkingCtrl.dispose();
    bhattaCtrl.dispose();
    otherCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final freight = double.tryParse(freightCtrl.text.trim()) ?? 0.0;
    final advance = double.tryParse(advanceCtrl.text.trim()) ?? 0.0;
    final diesel = double.tryParse(dieselCtrl.text.trim()) ?? 0.0;
    final toll = double.tryParse(tollCtrl.text.trim()) ?? 0.0;
    final parking = double.tryParse(parkingCtrl.text.trim()) ?? 0.0;
    final bhatta = double.tryParse(bhattaCtrl.text.trim()) ?? 0.0;
    final other = double.tryParse(otherCtrl.text.trim()) ?? 0.0;

    await widget.controller.updateTripBilling(
      index: widget.tripIndex,
      freightAmount: freight,
      advancePaid: advance,
      customerInvoiceNumber: invoiceNumCtrl.text.trim(),
      customerInvoiceStatus: invoiceStatus,
    );

    await widget.controller.updateTripExpenses(
      index: widget.tripIndex,
      dieselExpense: diesel,
      tollExpense: toll,
      parkingExpense: parking,
      driverAllowance: bhatta,
      otherExpense: other,
      replaceExisting: true,
    );

    if (podStatus != widget.trip.podStatus) {
      await widget.controller.updateTripPod(
        index: widget.tripIndex,
        podPhoto: widget.trip.podPhoto,
        podStatus: podStatus,
      );
    }

    if (rcvStatus != widget.trip.receivingCopyStatus) {
      await widget.controller.updateTripReceivingCopy(
        index: widget.tripIndex,
        receivingCopyPhoto: widget.trip.receivingCopyPhoto,
        receivingCopyStatus: rcvStatus,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip Freight, Expenses & P&L audited successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const AppIconBadge(
            icon: Icons.calculate_rounded,
            size: 20,
            padding: 6,
            radius: 8,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Audit Billing & Expenses: ${widget.trip.effectiveTripNumber}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CUSTOMER BILLING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: freightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Freight (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: advanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Advance Paid (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: invoiceNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                        hintText: 'INV-2026-001',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: invoiceStatus,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Status',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'sent', child: Text('Sent')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      ],
                      onChanged: (v) =>
                          setState(() => invoiceStatus = v ?? 'draft'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'AUDITED TRIP EXPENSES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dieselCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Diesel (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: tollCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Toll FASTag (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: parkingCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Parking / Entry (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: bhattaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Driver Bhatta (₹)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: otherCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Other Miscellaneous Expenses (₹)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'POD & RECEIVING AUDIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: podStatus,
                      decoration: const InputDecoration(
                        labelText: 'POD Status',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'received', child: Text('Received')),
                      ],
                      onChanged: (v) =>
                          setState(() => podStatus = v ?? 'pending'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: rcvStatus,
                      decoration: const InputDecoration(
                        labelText: 'Receiving Copy',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'received', child: Text('Received')),
                      ],
                      onChanged: (v) =>
                          setState(() => rcvStatus = v ?? 'pending'),
                    ),
                  ),
                ],
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
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Save Audit'),
        ),
      ],
    );
  }
}

class _TripPhotoPreviewDialog extends StatelessWidget {
  const _TripPhotoPreviewDialog({
    required this.title,
    required this.photoBase64,
  });

  final String title;
  final String photoBase64;

  @override
  Widget build(BuildContext context) {
    Widget imageContent;
    if (photoBase64.isNotEmpty) {
      try {
        final clean = photoBase64.contains(',')
            ? photoBase64.split(',').last.trim()
            : photoBase64.trim();
        final bytes = base64Decode(clean);
        imageContent = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      } catch (_) {
        imageContent = _buildPlaceholder();
      }
    } else {
      imageContent = _buildPlaceholder();
    }

    return AlertDialog(
      title: Row(
        children: [
          const AppIconBadge(
            icon: Icons.image_outlined,
            size: 18,
            padding: 6,
            radius: 8,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 340,
        child: Center(child: imageContent),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 40, color: AppColors.slate),
          SizedBox(height: 8),
          Text(
            'No photo uploaded yet.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Driver will upload from mobile Driver Portal.',
            style: TextStyle(fontSize: 11, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_location_alt_outlined,
                size: 46, color: AppColors.blue),
            const SizedBox(height: 12),
            const Text('No trips created'),
            const SizedBox(height: 6),
            const Text(
              'Create a trip by pinning pickup and destination on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Pin a new trip'),
            ),
          ],
        ),
      ),
    );
  }
}
