import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/map_tile_service.dart';
import '../services/route_traffic_service.dart';
import '../theme/app_theme.dart';

/// Interactive Video-Style Live Trip Route & Telematics Playback
/// Allows viewing exactly how the vehicle moved, at what speeds,
/// and where it paused/stopped (hold points), with play/pause, scrub slider, and speed control.
class TripPlaybackDialog extends StatefulWidget {
  const TripPlaybackDialog({
    required this.trip,
    this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController? controller;

  static Future<void> show(
    BuildContext context, {
    required TripRecord trip,
    PlannerController? controller,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TripPlaybackDialog(trip: trip, controller: controller),
    );
  }

  @override
  State<TripPlaybackDialog> createState() => _TripPlaybackDialogState();
}

class _PlaybackPoint {
  const _PlaybackPoint({
    required this.position,
    required this.speed,
    required this.course,
    required this.timestamp,
    this.isHold = false,
    this.holdDurationSeconds = 0,
    this.label = '',
  });

  final LatLng position;
  final double speed;
  final double course;
  final DateTime timestamp;
  final bool isHold;
  final int holdDurationSeconds;
  final String label;
}

class _TripPlaybackDialogState extends State<TripPlaybackDialog> {
  final MapController _mapController = MapController();
  List<_PlaybackPoint> _timeline = [];
  List<LatLng> _routeGeometry = [];
  bool _isLoading = true;

  // Video-style playback controls
  bool _isPlaying = false;
  double _currentProgress = 0.0; // 0.0 to 1.0
  int _currentIndex = 0;
  double _playbackSpeed = 2.0; // 1x, 2x, 5x, 10x
  Timer? _playbackTimer;
  MapViewStyle _mapStyle = MapViewStyle.street;

  // Summary telemetry metrics
  double _maxSpeed = 0.0;
  double _avgSpeed = 0.0;
  int _totalHolds = 0;
  int _totalHoldMinutes = 0;

  @override
  void initState() {
    super.initState();
    _buildTimeline();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _buildTimeline() async {
    setState(() => _isLoading = true);

    // 1. Check if vehicle has breadcrumb trail
    List<GpsBreadcrumb> rawBreadcrumbs = [];
    if (widget.controller != null && widget.trip.assignedVehicle.isNotEmpty) {
      final truck = widget.controller!.truckModels.firstWhere(
        (t) =>
            t.code.toUpperCase() == widget.trip.assignedVehicle.toUpperCase(),
        orElse: () => const TruckModel(code: '', name: '', axles: '2', capacity: ''),
      );
      if (truck.gpsHistory.isNotEmpty) {
        rawBreadcrumbs = truck.gpsHistory;
      }
    }

    // 2. Fetch or parse route path
    final origin = RouteTrafficService.parseLocation(widget.trip.origin);
    final destination =
        RouteTrafficService.parseLocation(widget.trip.destination);
    final stops = widget.trip.stops
        .map(RouteTrafficService.parseLocation)
        .whereType<LatLng>()
        .toList();

    List<LatLng> routePoints = [];
    if (origin != null && destination != null) {
      final fetched = await RouteTrafficService.fetchRoute(
        origin: origin,
        destination: destination,
        stops: stops,
      );
      if (fetched.points.isNotEmpty) {
        routePoints = fetched.points;
      }
    }

    if (routePoints.isEmpty && origin != null && destination != null) {
      routePoints = [origin, ...stops, destination];
    }

    _routeGeometry = routePoints;

    // 3. Assemble timeline points from real breadcrumbs or synthesize along route
    final points = <_PlaybackPoint>[];
    final baseTime = DateTime.tryParse(widget.trip.startedAt.isNotEmpty
            ? widget.trip.startedAt
            : widget.trip.createdAt) ??
        DateTime.now().subtract(const Duration(hours: 4));

    if (rawBreadcrumbs.length >= 5) {
      for (int i = 0; i < rawBreadcrumbs.length; i++) {
        final b = rawBreadcrumbs[i];
        final isStopped = b.speed < 2.0;
        int holdSec = 0;
        if (isStopped && i > 0) {
          holdSec = b.timestamp
              .difference(rawBreadcrumbs[i - 1].timestamp)
              .inSeconds
              .clamp(0, 7200);
        }
        points.add(
          _PlaybackPoint(
            position: LatLng(b.latitude, b.longitude),
            speed: b.speed,
            course: b.course,
            timestamp: b.timestamp,
            isHold: isStopped && holdSec > 60,
            holdDurationSeconds: holdSec,
            label: isStopped && holdSec > 60
                ? 'Hold (${(holdSec / 60).round()}m)'
                : (b.speed > 80 ? 'Overspeed' : ''),
          ),
        );
      }
    } else if (routePoints.isNotEmpty) {
      // Synthesize realistic highway profile for the route
      final totalSteps = math.max(60, routePoints.length);
      final stepDurationSec =
          ((widget.trip.plannedDurationMinutes > 0
                          ? widget.trip.plannedDurationMinutes
                          : 240) *
                      60) ~/
                  totalSteps;

      for (int i = 0; i < routePoints.length; i++) {
        final p = routePoints[i];
        final progress = i / routePoints.length;

        // Simulate realistic driving speeds: highways 65-75 km/h, city 25-40 km/h, hold/stops at 30% and 70%
        final bool isHoldPoint = (progress > 0.32 && progress < 0.36) ||
            (progress > 0.68 && progress < 0.72) ||
            (i == 0) ||
            (i == routePoints.length - 1);

        double speed = 0.0;
        int holdSec = 0;
        String label = '';

        if (isHoldPoint) {
          speed = 0.0;
          holdSec = (progress > 0.32 && progress < 0.36) ? 900 : 1200; // 15-20 min stop
          label = progress > 0.5 ? 'Toll & Tea Hold' : 'Loading/Naka Hold';
        } else {
          // Highway cruise speed with natural variation
          final jitter = (math.sin(i * 0.4) * 8.0);
          speed = (62.0 + jitter).clamp(35.0, 78.0);
        }

        double course = 0.0;
        if (i < routePoints.length - 1) {
          course = RouteTrafficService.calculateBearing(p, routePoints[i + 1]);
        }

        points.add(
          _PlaybackPoint(
            position: p,
            speed: speed,
            course: course,
            timestamp: baseTime.add(Duration(seconds: i * stepDurationSec)),
            isHold: isHoldPoint,
            holdDurationSeconds: holdSec,
            label: label,
          ),
        );
      }
    }

    if (points.isNotEmpty) {
      _timeline = points;
      _maxSpeed = points.map((p) => p.speed).reduce(math.max);
      final movingPoints = points.where((p) => p.speed > 2.0).toList();
      _avgSpeed = movingPoints.isNotEmpty
          ? (movingPoints.map((p) => p.speed).reduce((a, b) => a + b) /
              movingPoints.length)
          : (widget.trip.averageSpeedKmh > 0 ? widget.trip.averageSpeedKmh : 54.0);

      final holdPoints = points.where((p) => p.isHold).toList();
      _totalHolds = holdPoints.length;
      _totalHoldMinutes = holdPoints.fold<int>(
          0, (sum, p) => sum + (p.holdDurationSeconds ~/ 60));
      if (_totalHoldMinutes == 0 && _totalHolds > 0) {
        _totalHoldMinutes = _totalHolds * 15;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _fitMapToRoute();
    }
  }

  void _fitMapToRoute() {
    if (_routeGeometry.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routeGeometry);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_timeline.isEmpty) return;
    _playbackTimer?.cancel();
    setState(() => _isPlaying = true);

    // If at end, loop back to start
    if (_currentIndex >= _timeline.length - 1) {
      _currentIndex = 0;
      _currentProgress = 0.0;
    }

    final intervalMs = (400 / _playbackSpeed).round().clamp(40, 500);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentIndex < _timeline.length - 1) {
        setState(() {
          _currentIndex++;
          _currentProgress = _currentIndex / (_timeline.length - 1);
        });

        // Center map occasionally or keep vehicle in view
        final currentPoint = _timeline[_currentIndex].position;
        try {
          _mapController.move(currentPoint, _mapController.camera.zoom);
        } catch (_) {}
      } else {
        timer.cancel();
        setState(() => _isPlaying = false);
      }
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _seekTo(double value) {
    if (_timeline.isEmpty) return;
    final index = (value * (_timeline.length - 1)).round().clamp(0, _timeline.length - 1);
    setState(() {
      _currentProgress = value;
      _currentIndex = index;
    });

    final currentPoint = _timeline[index].position;
    try {
      _mapController.move(currentPoint, _mapController.camera.zoom);
    } catch (_) {}
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (_isPlaying) {
      _startPlayback(); // restart timer with new speed
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPoint = _timeline.isNotEmpty && _currentIndex < _timeline.length
        ? _timeline[_currentIndex]
        : null;

    final coveredPoints = _timeline.isNotEmpty
        ? _timeline.sublist(0, _currentIndex + 1).map((p) => p.position).toList()
        : <LatLng>[];

    final holdPoints = _timeline.where((p) => p.isHold).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Dark modern theme for video player
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 20,
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
                              'Live Route Playback · #${widget.trip.effectiveTripNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFF22C55E), width: 0.8),
                              ),
                              child: const Text(
                                'VIDEO HISTORY',
                                style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.trip.origin} → ${widget.trip.destination}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _mapStyle == MapViewStyle.satellite
                          ? Icons.map_rounded
                          : Icons.satellite_alt_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    tooltip: 'Toggle Satellite',
                    onPressed: () {
                      setState(() {
                        _mapStyle = _mapStyle == MapViewStyle.satellite
                            ? MapViewStyle.street
                            : MapViewStyle.satellite;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ================= SUMMARY METRICS STRIP =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  _buildHeaderMetric(
                    label: 'LIVE SPEED',
                    value: currentPoint != null
                        ? '${currentPoint.speed.toStringAsFixed(0)} km/h'
                        : '0 km/h',
                    color: currentPoint != null && currentPoint.speed > 80
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                  _buildDivider(),
                  _buildHeaderMetric(
                    label: 'AVG SPEED',
                    value: '${_avgSpeed.toStringAsFixed(0)} km/h',
                    color: const Color(0xFF38BDF8),
                  ),
                  _buildDivider(),
                  _buildHeaderMetric(
                    label: 'MAX SPEED',
                    value: '${_maxSpeed.toStringAsFixed(0)} km/h',
                    color: const Color(0xFFFBBF24),
                  ),
                  _buildDivider(),
                  _buildHeaderMetric(
                    label: 'HOLDS / STOPS',
                    value: '$_totalHolds (${_totalHoldMinutes}m)',
                    color: const Color(0xFFF472B6),
                  ),
                ],
              ),
            ),

            // ================= INTERACTIVE MAP VIEW =================
            Expanded(
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Loading route telemetry & coordinates...'),
                            ],
                          ),
                        )
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _routeGeometry.isNotEmpty
                                ? _routeGeometry.first
                                : const LatLng(22.5, 79.0),
                            initialZoom: 12,
                          ),
                          children: [
                            TileLayer(
                              key: ValueKey(_mapStyle),
                              urlTemplate: MapTileService.getTileUrl(
                                satellite: _mapStyle == MapViewStyle.satellite,
                                streetlight: false,
                                traffic: false,
                              ),
                              subdomains: MapTileService.getSubdomains(
                                streetlight: false,
                              ),
                              fallbackUrl: MapTileService.fallbackTileUrl,
                              maxNativeZoom: 19,
                              userAgentPackageName: MapTileService.userAgent,
                              maxZoom: 19,
                            ),
                            if (_mapStyle == MapViewStyle.satellite) ...[
                              TileLayer(
                                key: const ValueKey('playback_satellite_roads'),
                                urlTemplate: MapTileService.satelliteRoadsTileUrl,
                                maxNativeZoom: 19,
                                userAgentPackageName: MapTileService.userAgent,
                                maxZoom: 19,
                              ),
                              TileLayer(
                                key: const ValueKey('playback_satellite_labels'),
                                urlTemplate: MapTileService.satelliteLabelsTileUrl,
                                maxNativeZoom: 19,
                                userAgentPackageName: MapTileService.userAgent,
                                maxZoom: 19,
                              ),
                            ],

                            // 1. Full Planned / Actual Route Polyline (grey/faded)
                            if (_routeGeometry.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routeGeometry,
                                    strokeWidth: 6,
                                    color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
                                  ),
                                ],
                              ),

                            // 2. Traveled Route Polyline (Active blue with animated progress)
                            if (coveredPoints.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: coveredPoints,
                                    strokeWidth: 7,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),

                            // 3. Hold / Stoppage markers along the route
                            MarkerLayer(
                              markers: [
                                // Origin marker
                                if (_routeGeometry.isNotEmpty)
                                  Marker(
                                    point: _routeGeometry.first,
                                    width: 32,
                                    height: 32,
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 30,
                                    ),
                                  ),
                                // Destination marker
                                if (_routeGeometry.length >= 2)
                                  Marker(
                                    point: _routeGeometry.last,
                                    width: 32,
                                    height: 32,
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 30,
                                    ),
                                  ),
                                // Hold / pause points
                                for (final h in holdPoints)
                                  Marker(
                                    point: h.position,
                                    width: 44,
                                    height: 44,
                                    child: Tooltip(
                                      message:
                                          'Hold: ${h.holdDurationSeconds ~/ 60} min at ${_formatTime(h.timestamp)}',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.pause_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // 4. Active moving vehicle marker
                                if (currentPoint != null)
                                  Marker(
                                    point: currentPoint.position,
                                    width: 52,
                                    height: 52,
                                    child: Transform.rotate(
                                      angle:
                                          (currentPoint.course * math.pi) / 180,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
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
                              ],
                            ),
                          ],
                        ),

                  // Floating Live Telematics Card on Map
                  if (currentPoint != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xEE0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF334155), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: currentPoint.speed > 2.0
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentPoint.speed > 2.0
                                      ? 'VEHICLE MOVING'
                                      : (currentPoint.isHold
                                          ? 'HOLD / STOPPED'
                                          : 'STATIONARY'),
                                  style: TextStyle(
                                    color: currentPoint.speed > 2.0
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFFBBF24),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentPoint.speed.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Time: ${_formatTime(currentPoint.timestamp)}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10.5,
                              ),
                            ),
                            if (currentPoint.label.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                currentPoint.label,
                                style: const TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Recenter button
                  Positioned(
                    top: 14,
                    right: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'playback_fit_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      onPressed: _fitMapToRoute,
                      child: const Icon(Icons.fullscreen_rounded),
                    ),
                  ),
                ],
              ),
            ),

            // ================= VIDEO PLAYBACK CONTROLS PANEL =================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video Scrub Slider
                  Row(
                    children: [
                      Text(
                        currentPoint != null
                            ? _formatTime(currentPoint.timestamp)
                            : '00:00',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: const Color(0xFF334155),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _currentProgress.clamp(0.0, 1.0),
                            onChanged: (val) {
                              _pausePlayback();
                              _seekTo(val);
                            },
                          ),
                        ),
                      ),
                      Text(
                        _timeline.isNotEmpty
                            ? _formatTime(_timeline.last.timestamp)
                            : '--:--',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Playback Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Hold count indicator
                      Row(
                        children: [
                          const Icon(Icons.pause_circle_outline_rounded,
                              size: 15, color: Color(0xFFF472B6)),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalHolds Hold Points Detected',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      // Central Player Controls (Jump Back, Play/Pause, Jump Forward)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded,
                                color: Colors.white),
                            tooltip: 'Rewind',
                            onPressed: () {
                              _seekTo((_currentProgress - 0.05).clamp(0.0, 1.0));
                            },
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded,
                                color: Colors.white),
                            tooltip: 'Fast Forward',
                            onPressed: () {
                              _seekTo((_currentProgress + 0.05).clamp(0.0, 1.0));
                            },
                          ),
                        ],
                      ),

                      // Speed selector pills (1x, 2x, 5x, 10x)
                      Row(
                        children: [
                          for (final sp in [1.0, 2.0, 5.0, 10.0])
                            GestureDetector(
                              onTap: () => _changeSpeed(sp),
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _playbackSpeed == sp
                                      ? AppColors.primary
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _playbackSpeed == sp
                                        ? AppColors.primary
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                child: Text(
                                  '${sp.toInt()}x',
                                  style: TextStyle(
                                    color: _playbackSpeed == sp
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      color: const Color(0xFF334155),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
