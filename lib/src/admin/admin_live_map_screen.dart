import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/planner_controller.dart';
import '../services/map_tile_service.dart';

class FleetDriverMarkerData {
  const FleetDriverMarkerData({
    required this.name,
    required this.phone,
    required this.assignedVehicle,
    required this.position,
    required this.isMoving,
    required this.isOnline,
    required this.speedKmh,
    required this.statusText,
    required this.badgeText,
    required this.lastSeenText,
  });

  final String name;
  final String phone;
  final String assignedVehicle;
  final LatLng position;
  final bool isMoving;
  final bool isOnline;
  final double speedKmh;
  final String statusText;
  final String badgeText;
  final String lastSeenText;
}

class AdminLiveMapScreen extends StatefulWidget {
  const AdminLiveMapScreen({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  final MapController _mapController = MapController();
  FleetDriverMarkerData? _selectedTarget;
  bool _isSatelliteMode = false;
  Timer? _gpsAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _syncGps();
    _gpsAutoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _syncGps());
  }

  void _syncGps() {
    widget.controller.syncProtrackGps(allowSimulationFallback: false);
  }

  @override
  void dispose() {
    _gpsAutoRefreshTimer?.cancel();
    super.dispose();
  }

  List<FleetDriverMarkerData> _getDriverMarkers() {
    final drivers = widget.controller.drivers.isNotEmpty
        ? widget.controller.drivers
        : PlannerController.defaultFleetDrivers;
    final trucks = widget.controller.truckModels.isNotEmpty
        ? widget.controller.truckModels
        : PlannerController.defaultFleetVehicles;

    // Create lookup for truck coordinates
    final truckMap = {for (final t in trucks) t.code: t};
    final now = DateTime.now();

    final result = <FleetDriverMarkerData>[];

    for (final driver in drivers) {
      final truck = truckMap[driver.assignedVehicle];
      LatLng pos;
      bool isMoving = false;
      bool isOnline = false;
      double speed = 0.0;
      String status = 'ऑफ़लाइन (लास्ट लोकेशन)';
      String badge = 'ऑफ़लाइन';
      String lastSeen = '';

      if (truck != null &&
          truck.currentLat != null &&
          truck.currentLng != null &&
          truck.currentLat != 0.0 &&
          truck.currentLng != 0.0) {
        // If Dadarao & Ramrao share GJ19J6633, apply minor visual offset if needed so both pins are visible
        if (driver.name.toLowerCase().contains('ramrao') && driver.assignedVehicle == 'GJ19J6633') {
          pos = LatLng(truck.currentLat! + 0.00035, truck.currentLng! + 0.00035);
        } else {
          pos = LatLng(truck.currentLat!, truck.currentLng!);
        }

        speed = truck.currentSpeed;
        final lastGpsDt = truck.lastGpsDateTime;
        if (lastGpsDt != null) {
          final diff = now.difference(lastGpsDt).abs();
          // Fresh within 10 minutes = Online Live
          if (diff.inMinutes < 10) {
            isOnline = true;
            isMoving = speed > 2.0;
            status = isMoving
                ? 'लाइव: चल रही है (${speed.toStringAsFixed(0)} km/h)'
                : 'लाइव: गाड़ी खड़ी है (पार्क)';
            badge = isMoving ? 'चल रही' : 'खड़ी है';
            lastSeen = 'अभी लाइव';
          } else {
            isOnline = false;
            isMoving = false;
            final timeAgo = diff.inHours > 0
                ? '${diff.inHours} घंटे पहले'
                : '${diff.inMinutes} मिनट पहले';
            status = 'ऑफ़लाइन • लास्ट लोकेशन ($timeAgo)';
            badge = 'ऑफ़लाइन';
            lastSeen = timeAgo;
          }
        } else {
          isOnline = false;
          status = 'ऑफ़लाइन (लास्ट लोकेशन)';
          badge = 'ऑफ़लाइन';
          lastSeen = 'पहले की';
        }
      } else {
        // Default safe baseline coordinate for drivers
        pos = const LatLng(21.17065, 73.00425);
        isOnline = false;
        status = 'ऑफ़लाइन (नो GPS डेटा)';
        badge = 'ऑफ़लाइन';
        lastSeen = 'उपलब्ध नहीं';
      }

      result.add(
        FleetDriverMarkerData(
          name: driver.name,
          phone: driver.phone,
          assignedVehicle: driver.assignedVehicle,
          position: pos,
          isMoving: isMoving,
          isOnline: isOnline,
          speedKmh: speed,
          statusText: status,
          badgeText: badge,
          lastSeenText: lastSeen,
        ),
      );
    }

    return result;
  }

  void _zoomToTarget(FleetDriverMarkerData target) {
    setState(() => _selectedTarget = target);
    _mapController.move(target.position, 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final driverItems = _getDriverMarkers();
    if (_selectedTarget == null && driverItems.isNotEmpty) {
      _selectedTarget = driverItems.first;
    }

    final markers = <Marker>[];
    for (final item in driverItems) {
      final isSelected = _selectedTarget?.phone == item.phone;

      markers.add(
        Marker(
          point: item.position,
          width: isSelected ? 160 : 70,
          height: isSelected ? 90 : 70,
          child: GestureDetector(
            onTap: () => setState(() => _selectedTarget = item),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.name} (${item.assignedVehicle})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.statusText,
                          style: TextStyle(
                            color: item.isMoving ? const Color(0xFF4ADE80) : const Color(0xFFFDE047),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 3),
                Container(
                  width: isSelected ? 44 : 38,
                  height: isSelected ? 44 : 38,
                  decoration: BoxDecoration(
                    color: item.isMoving
                        ? const Color(0xFF16A34A)
                        : (item.isOnline
                            ? (isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
                            : const Color(0xFF64748B)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isOnline ? Colors.white : const Color(0xFFCBD5E1),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: isSelected ? 22 : 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '6 ड्राइवर्स व गाड़ियों की लाइव लोकेशन',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: _isSatelliteMode ? 'सड़क मैप (Street Map)' : 'सैटेलाइट मैप (Satellite)',
            onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
            icon: Icon(
              _isSatelliteMode ? Icons.map_rounded : Icons.satellite_alt_rounded,
              color: const Color(0xFF2563EB),
            ),
          ),
          IconButton(
            tooltip: 'रिफ्रेश जीपीएस',
            onPressed: _syncGps,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF16A34A)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Authentic Real Google Maps (Street + Satellite toggle)
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(21.17065, 73.00425),
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteMode ? MapTileService.satelliteTileUrl : MapTileService.roadTileUrl,
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.transportone.transport_one',
                maxZoom: 20,
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Top Info Banner: Selected Driver and Vehicle Details
          if (_selectedTarget != null)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedTarget!.isMoving
                            ? const Color(0xFFDCFCE7)
                            : (_selectedTarget!.isOnline ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedTarget!.isMoving
                            ? Icons.navigation_rounded
                            : (_selectedTarget!.isOnline ? Icons.person_pin_circle_rounded : Icons.location_off_rounded),
                        color: _selectedTarget!.isMoving
                            ? const Color(0xFF16A34A)
                            : (_selectedTarget!.isOnline ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
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
                              Flexible(
                                child: Text(
                                  'चालक: ${_selectedTarget!.name} • ${_selectedTarget!.assignedVehicle}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_selectedTarget!.isOnline) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Text(
                                    'लास्ट लोकेशन',
                                    style: TextStyle(fontSize: 9, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTarget!.isOnline
                                ? 'फोन: ${_selectedTarget!.phone} | GPS: ${_selectedTarget!.position.latitude.toStringAsFixed(4)}, ${_selectedTarget!.position.longitude.toStringAsFixed(4)}'
                                : 'लास्ट अपडेट: ${_selectedTarget!.lastSeenText} | GPS: ${_selectedTarget!.position.latitude.toStringAsFixed(4)}, ${_selectedTarget!.position.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedTarget!.isMoving
                            ? const Color(0xFFDCFCE7)
                            : (_selectedTarget!.isOnline ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedTarget!.isMoving
                              ? const Color(0xFFBBF7D0)
                              : (_selectedTarget!.isOnline ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Text(
                        _selectedTarget!.badgeText,
                        style: TextStyle(
                          color: _selectedTarget!.isMoving
                              ? const Color(0xFF15803D)
                              : (_selectedTarget!.isOnline ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Horizontal Strip: Lists ALL 6 Drivers
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: driverItems.length,
                itemBuilder: (context, index) {
                  final item = driverItems[index];
                  final isSelected = _selectedTarget?.phone == item.phone;
                  final locationStr =
                      '${item.position.latitude.toStringAsFixed(4)}, ${item.position.longitude.toStringAsFixed(4)}';

                  return GestureDetector(
                    onTap: () => _zoomToTarget(item),
                    child: Container(
                      width: 215,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: item.isMoving
                                    ? const Color(0xFF16A34A)
                                    : (item.isOnline
                                        ? const Color(0xFFEAB308)
                                        : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: item.isMoving
                                      ? const Color(0xFFDCFCE7)
                                      : (item.isOnline ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: item.isMoving
                                        ? const Color(0xFFBBF7D0)
                                        : (item.isOnline ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  item.badgeText,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.isMoving
                                        ? const Color(0xFF15803D)
                                        : (item.isOnline ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.isOnline
                                ? 'गाड़ी: ${item.assignedVehicle} • ${item.phone}'
                                : 'लास्ट: ${item.lastSeenText} • ${item.assignedVehicle}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
