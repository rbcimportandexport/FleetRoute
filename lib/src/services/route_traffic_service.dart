import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/planner_models.dart';
import 'firebase_auth_service.dart';

enum ManeuverType {
  straight,
  slightLeft,
  turnLeft,
  sharpLeft,
  slightRight,
  turnRight,
  sharpRight,
  uTurn;

  IconData get icon => switch (this) {
        ManeuverType.straight => Icons.arrow_upward_rounded,
        ManeuverType.slightLeft => Icons.turn_slight_left_rounded,
        ManeuverType.turnLeft => Icons.turn_left_rounded,
        ManeuverType.sharpLeft => Icons.turn_sharp_left_rounded,
        ManeuverType.slightRight => Icons.turn_slight_right_rounded,
        ManeuverType.turnRight => Icons.turn_right_rounded,
        ManeuverType.sharpRight => Icons.turn_sharp_right_rounded,
        ManeuverType.uTurn => Icons.u_turn_left_rounded,
      };

  String get labelHindi => switch (this) {
        ManeuverType.straight => 'सीधे चलें (Go Straight)',
        ManeuverType.slightLeft => 'हल्का बाएँ (Keep Left)',
        ManeuverType.turnLeft => 'बाएँ मुड़ें (Turn Left)',
        ManeuverType.sharpLeft => 'तीव्र बाएँ (Sharp Left)',
        ManeuverType.slightRight => 'हल्का दाएँ (Keep Right)',
        ManeuverType.turnRight => 'दाएँ मुड़ें (Turn Right)',
        ManeuverType.sharpRight => 'तीव्र दाएँ (Sharp Right)',
        ManeuverType.uTurn => 'वापस मुड़ें (U-Turn)',
      };

  String get directionSide => switch (this) {
        ManeuverType.straight => 'Upper Side (आगे)',
        ManeuverType.slightLeft => 'Left Side (बाएँ)',
        ManeuverType.turnLeft => 'Left Side (बाएँ)',
        ManeuverType.sharpLeft => 'Left Side (बाएँ)',
        ManeuverType.slightRight => 'Right Side (दाएँ)',
        ManeuverType.turnRight => 'Right Side (दाएँ)',
        ManeuverType.sharpRight => 'Right Side (दाएँ)',
        ManeuverType.uTurn => 'Down Side (नीचे / वापस)',
      };
}

class NavigationTurnInfo {
  const NavigationTurnInfo({
    required this.maneuver,
    required this.distanceMeters,
    required this.bearing,
    required this.instructionHindi,
    required this.instructionEnglish,
    required this.cardinalDirection,
  });

  final ManeuverType maneuver;
  final double distanceMeters;
  final double bearing;
  final String instructionHindi;
  final String instructionEnglish;
  final String cardinalDirection;
}

enum TrafficLevel {
  smooth,
  moderate,
  heavy;

  Color get color => switch (this) {
        TrafficLevel.smooth => const Color(0xFF10B981),
        TrafficLevel.moderate => const Color(0xFFF59E0B),
        TrafficLevel.heavy => const Color(0xFFEF4444),
      };

  Color get backgroundColor => switch (this) {
        TrafficLevel.smooth => const Color(0xFFDCFCE7),
        TrafficLevel.moderate => const Color(0xFFFEF3C7),
        TrafficLevel.heavy => const Color(0xFFFEE2E2),
      };

  String get label => switch (this) {
        TrafficLevel.smooth => 'Smooth Flow (सामान्य)',
        TrafficLevel.moderate => 'Moderate (हल्का ट्रैफिक)',
        TrafficLevel.heavy => 'Heavy Congestion (जाम)',
      };
}

class TrafficReport {
  const TrafficReport({
    required this.level,
    required this.distanceKm,
    required this.duration,
    required this.delayMinutes,
    required this.clearPercent,
    required this.moderatePercent,
    required this.slowPercent,
    required this.summary,
    required this.summaryHindi,
    this.isEstimated = true,
    this.providerName = 'Highway Traffic Flow Model',
  });

  final TrafficLevel level;
  final double distanceKm;
  final Duration duration;
  final int delayMinutes;
  final int clearPercent;
  final int moderatePercent;
  final int slowPercent;
  final String summary;
  final String summaryHindi;
  final bool isEstimated;
  final String providerName;

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get formattedDuration {
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.rawDurationSeconds,
    required this.isRealHighwayRoute,
  });

  final List<LatLng> points;
  final double distanceKm;
  final double rawDurationSeconds;
  final bool isRealHighwayRoute;
}

class RoadTrafficSegment {
  const RoadTrafficSegment({
    required this.points,
    required this.level,
    required this.speedKmh,
    required this.label,
    this.isEstimated = true,
  });

  final List<LatLng> points;
  final TrafficLevel level;
  final int speedKmh;
  final String label;
  final bool isEstimated;

  Color get color => switch (level) {
        TrafficLevel.smooth => const Color(0xFF10B981),
        TrafficLevel.moderate => const Color(0xFFF59E0B),
        TrafficLevel.heavy => const Color(0xFFEF4444),
      };
}

class RoadTrafficHotspot {
  const RoadTrafficHotspot({
    required this.point,
    required this.level,
    required this.speedKmh,
    required this.label,
    required this.locationName,
    this.isEstimated = true,
  });

  final LatLng point;
  final TrafficLevel level;
  final int speedKmh;
  final String label;
  final String locationName;
  final bool isEstimated;
}

class RouteTrafficService {
  static Map<String, LatLng> get cityCoordinates => _cityCoordinates;

  static const Map<String, LatLng> _cityCoordinates = {
    'delhi': LatLng(28.6139, 77.2090),
    'new delhi': LatLng(28.6139, 77.2090),
    'mumbai': LatLng(19.0760, 72.8777),
    'bombay': LatLng(19.0760, 72.8777),
    'bengaluru': LatLng(12.9716, 77.5946),
    'bangalore': LatLng(12.9716, 77.5946),
    'kolkata': LatLng(22.5726, 88.3639),
    'calcutta': LatLng(22.5726, 88.3639),
    'hyderabad': LatLng(17.3850, 78.4867),
    'chennai': LatLng(13.0827, 80.2707),
    'madras': LatLng(13.0827, 80.2707),
    'ahmedabad': LatLng(23.0225, 72.5714),
    'surat': LatLng(21.1702, 72.8311),
    'pune': LatLng(18.5204, 73.8567),
    'jaipur': LatLng(26.9124, 75.7873),
    'lucknow': LatLng(26.8467, 80.9462),
    'kanpur': LatLng(26.4499, 80.3319),
    'nagpur': LatLng(21.1458, 79.0882),
    'indore': LatLng(22.7196, 75.8577),
    'bhopal': LatLng(23.2599, 77.4126),
    'patna': LatLng(25.6127, 85.1444),
    'vadodara': LatLng(22.3072, 73.1812),
    'baroda': LatLng(22.3072, 73.1812),
    'ghaziabad': LatLng(28.6692, 77.4538),
    'ludhiana': LatLng(30.9010, 75.8573),
    'agra': LatLng(27.1767, 78.0081),
    'nashik': LatLng(19.9975, 73.7898),
    'rajkot': LatLng(22.3039, 70.8022),
    'varanasi': LatLng(25.3176, 82.9739),
    'srinagar': LatLng(34.0837, 74.7973),
    'aurangabad': LatLng(19.8762, 75.3433),
    'dhanbad': LatLng(23.7957, 86.4304),
    'amritsar': LatLng(31.6340, 74.8723),
    'allahabad': LatLng(25.4358, 81.8463),
    'prayagraj': LatLng(25.4358, 81.8463),
    'ranchi': LatLng(23.3441, 85.3096),
    'howrah': LatLng(22.5958, 88.2636),
    'coimbatore': LatLng(11.0168, 76.9558),
    'jabalpur': LatLng(23.1815, 79.9864),
    'gwalior': LatLng(26.2183, 78.1828),
    'vijayawada': LatLng(16.5062, 80.6480),
    'jodhpur': LatLng(26.2389, 73.0243),
    'madurai': LatLng(9.9252, 78.1198),
    'raipur': LatLng(21.2514, 81.6296),
    'kota': LatLng(25.2138, 75.8648),
    'chandigarh': LatLng(30.7333, 76.7794),
    'guwahati': LatLng(26.1445, 91.7362),
    'bhuj': LatLng(23.2420, 69.6669),
    'kandla': LatLng(23.0033, 70.2174),
    'mundra': LatLng(22.8394, 69.7214),
    'gandhidham': LatLng(23.0753, 70.1337),
    'jamnagar': LatLng(22.4707, 70.0577),
    'bhavnagar': LatLng(21.7645, 72.1519),
    'bharuch': LatLng(21.7051, 72.9959),
    'vapi': LatLng(20.3893, 72.9106),
    'bardoli': LatLng(21.1215, 73.1118),
    'kamrej': LatLng(21.2709, 72.9634),
    'navsari': LatLng(20.9467, 72.9520),
    'ankleshwar': LatLng(21.6264, 73.0033),
    'valsad': LatLng(20.5992, 72.9342),
    'kim': LatLng(21.4019, 72.9234),
    'kosamba': LatLng(21.4746, 72.9554),
    'jolva': LatLng(21.2052, 73.0135),
    'kadodara': LatLng(21.1718, 72.9642),
    'palsana': LatLng(21.0825, 72.9972),
    'tadkeshwar': LatLng(21.3619, 73.0847),
    'mandvi': LatLng(21.2580, 73.3039),
    'vyara': LatLng(21.1120, 73.3980),
    'songadh': LatLng(21.1685, 73.5593),
    'dahej': LatLng(21.7107, 72.5857),
    'zaghadia': LatLng(21.7142, 73.1534),
  };

  /// Popular quick routes across India for instant planning
  static const List<Map<String, String>> popularRoutes = [
    {'from': 'Bardoli', 'to': 'Kamrej', 'distance': '36 km'},
    {'from': 'Surat', 'to': 'Bardoli', 'distance': '34 km'},
    {'from': 'Delhi', 'to': 'Jaipur', 'distance': '280 km'},
    {'from': 'Mumbai', 'to': 'Pune', 'distance': '150 km'},
    {'from': 'Ahmedabad', 'to': 'Surat', 'distance': '265 km'},
    {'from': 'Bengaluru', 'to': 'Chennai', 'distance': '345 km'},
    {'from': 'Delhi', 'to': 'Agra', 'distance': '230 km'},
    {'from': 'Kolkata', 'to': 'Dhanbad', 'distance': '270 km'},
  ];

  /// Popular cities for quick selection chips
  static const List<String> popularCities = [
    'Bardoli',
    'Surat',
    'Kamrej',
    'Navsari',
    'Ahmedabad',
    'Mumbai',
    'Pune',
    'Vadodara',
    'Delhi',
    'Jaipur',
    'Bengaluru',
    'Chennai',
    'Hyderabad',
    'Indore',
  ];

  /// Returns the nearest major city name if point is within 4 km of its center,
  /// otherwise returns formatted high-precision coordinates.
  static String findNearestCityName(LatLng point) {
    String? closestCity;
    double minDistance = double.infinity;

    for (final entry in _cityCoordinates.entries) {
      final dist = straightDistanceKm(point, entry.value);
      if (dist < minDistance) {
        minDistance = dist;
        closestCity = entry.key;
      }
    }

    if (closestCity != null && minDistance <= 4.0) {
      // Capitalize city name
      final titleCase = closestCity
          .split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
      return titleCase;
    }

    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  /// Parses text into a [LatLng] coordinate.
  /// Handles "lat, lng", "lat lng", and city names as complete words in an
  /// address. Complete-word matching prevents arbitrary text such as
  /// "suratanything" from being accepted as Surat.
  static LatLng? parseLocation(String? text) {
    if (text == null) return null;
    final clean = text.trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();

    // 1. Lat/Lng regex match (prioritized so addresses with explicit coordinates
    // like "Mota, Bardoli Taluka, Gujarat (21.174901, 73.052134)" return the
    // exact GPS coordinates rather than snapping to the city center).
    final regex = RegExp(
      r'([-+]?\d{1,2}(?:\.\d{3,}))[,\s]+([-+]?\d{1,3}(?:\.\d{3,})?)',
    );
    final match = regex.firstMatch(clean);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          return LatLng(lat, lng);
        }
      }
    }

    // Also support any general lat/lng format
    final generalRegex = RegExp(
      r'([-+]?\d{1,2}(?:\.\d+)?)[,\s]+([-+]?\d{1,3}(?:\.\d+)?)',
    );

    // 2. Exact city name or a complete city-name token inside an address.
    for (final entry in _cityCoordinates.entries) {
      final cityPattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(entry.key)}([^a-z0-9]|\$)',
      );
      if (cityPattern.hasMatch(lower)) {
        return entry.value;
      }
    }

    // 3. Fallback general Lat/Lng regex match
    final generalMatch = generalRegex.firstMatch(clean);
    if (generalMatch != null) {
      final lat = double.tryParse(generalMatch.group(1)!);
      final lng = double.tryParse(generalMatch.group(2)!);
      if (lat != null && lng != null) {
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }

  /// Calculates geodesic straight-line distance in kilometers.
  static double straightDistanceKm(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000.0;
  }

  /// Estimates road distance with typical highway curvature factor (~1.25x).
  static double estimateRoadDistanceKm(LatLng start, LatLng end) {
    return straightDistanceKm(start, end) * 1.25;
  }

  /// Fetches real highway road polyline and distance from OSRM for origin,
  /// optional intermediate stops, and destination.
  static Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> stops = const [],
  }) async {
    final waypoints = [origin, ...stops, destination];
    return fetchMultiStopRoute(waypoints: waypoints);
  }

  /// Fetches a unified highway route across multiple waypoints in sequential order.
  static Future<RouteResult> fetchMultiStopRoute({
    required List<LatLng> waypoints,
    http.Client? client,
  }) async {
    if (waypoints.length < 2) {
      return const RouteResult(
        points: [],
        distanceKm: 0,
        rawDurationSeconds: 0,
        isRealHighwayRoute: false,
      );
    }

    final ownsClient = client == null;
    final routeClient = client ?? http.Client();
    try {
      // First ask for one unified road geometry in the exact waypoint order.
      final unified = await _fetchOsrmLeg(
        routeClient,
        waypoints,
        timeout: const Duration(seconds: 12),
      );
      if (unified != null) return unified;

      // Large multi-stop requests can time out. Recover each consecutive leg
      // independently and stitch them into one continuous road polyline.
      final fetchedLegs = await Future.wait<RouteResult?>([
        for (int i = 0; i < waypoints.length - 1; i++)
          _fetchOsrmLeg(
            routeClient,
            [waypoints[i], waypoints[i + 1]],
            timeout: const Duration(seconds: 8),
          ),
      ]);

      // Never mix road geometry with synthetic straight lines. A partially
      // fabricated route can cut across fields/water and is unsafe to follow.
      if (fetchedLegs.any((leg) => leg == null)) {
        return const RouteResult(
          points: [],
          distanceKm: 0,
          rawDurationSeconds: 0,
          isRealHighwayRoute: false,
        );
      }

      final mergedPoints = <LatLng>[];
      double totalDistance = 0;
      double totalDuration = 0;
      var allLegsUseRoads = true;

      for (int i = 0; i < fetchedLegs.length; i++) {
        final leg = fetchedLegs[i]!;

        if (mergedPoints.isEmpty) {
          mergedPoints.addAll(leg.points);
        } else {
          mergedPoints.addAll(leg.points.skip(1));
        }
        totalDistance += leg.distanceKm;
        totalDuration += leg.rawDurationSeconds;
        allLegsUseRoads = allLegsUseRoads && leg.isRealHighwayRoute;
      }

      return RouteResult(
        points: mergedPoints,
        distanceKm: totalDistance,
        rawDurationSeconds: totalDuration,
        isRealHighwayRoute: allLegsUseRoads,
      );
    } finally {
      if (ownsClient) routeClient.close();
    }
  }

  static const String routingProxyUrl =
      String.fromEnvironment('ROUTING_API_URL', defaultValue: '');

  static final Map<String, RouteResult> _routeCache = {};

  static Future<RouteResult?> _fetchOsrmLeg(
    http.Client client,
    List<LatLng> waypoints, {
    required Duration timeout,
  }) async {
    try {
      final coordsParam = waypoints
          .map((point) =>
              '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}')
          .join(';');

      final cacheKey = coordsParam;
      if (_routeCache.containsKey(cacheKey)) {
        return _routeCache[cacheKey];
      }

      final uri = routingProxyUrl.isNotEmpty
          ? Uri.parse('$routingProxyUrl?coords=$coordsParam')
          : Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
              '$coordsParam?overview=full&geometries=geojson&steps=false',
            );

      final headers = <String, String>{'User-Agent': 'TransportOne/1.1'};
      if (routingProxyUrl.isNotEmpty) {
        final idToken = await FirebaseAuthService.instance.idToken();
        if (idToken == null || idToken.isEmpty) return null;
        headers['Authorization'] = 'Bearer $idToken';
      }
      final response = await client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['code'] != 'Ok' ||
          decoded['routes'] is! List ||
          (decoded['routes'] as List).isEmpty) {
        return null;
      }

      final rawRoute = (decoded['routes'] as List).first;
      if (rawRoute is! Map<String, dynamic> ||
          rawRoute['geometry'] is! Map<String, dynamic>) {
        return null;
      }
      final geometry = rawRoute['geometry'] as Map<String, dynamic>;
      if (geometry['coordinates'] is! List) return null;

      final points = <LatLng>[];
      for (final coordinate in geometry['coordinates'] as List) {
        if (coordinate is List &&
            coordinate.length >= 2 &&
            coordinate[0] is num &&
            coordinate[1] is num) {
          points.add(LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ));
        }
      }
      if (points.length < 2) return null;

      final result = RouteResult(
        points: points,
        distanceKm: ((rawRoute['distance'] as num?)?.toDouble() ?? 0) / 1000.0,
        rawDurationSeconds: (rawRoute['duration'] as num?)?.toDouble() ?? 0,
        isRealHighwayRoute: true,
      );
      if (_routeCache.length >= 100) {
        _routeCache.remove(_routeCache.keys.first);
      }
      _routeCache[cacheKey] = result;
      return result;
    } on http.ClientException catch (e) {
      debugPrint('[RoutingService] Network communication error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[RoutingService] Route parse error: $e');
      return null;
    }
  }

  /// Calculates traffic analysis, expected delay, and vehicle duration.
  static TrafficReport analyzeTraffic({
    required double distanceKm,
    required VehicleType vehicle,
    TruckModel? truckModel,
  }) {
    // Average operational speeds on Indian National/State Highways (km/h)
    double avgSpeed;
    switch (vehicle) {
      case VehicleType.truck:
        if (truckModel != null && truckModel.maxSpeed > 0) {
          avgSpeed = (truckModel.maxSpeed * 0.72).clamp(35.0, 65.0);
        } else {
          avgSpeed = 48.0;
        }
        break;
      case VehicleType.car:
        avgSpeed = 72.0;
        break;
      case VehicleType.bike:
        avgSpeed = 52.0;
        break;
    }

    final rawHours = distanceKm / avgSpeed;
    var baseSeconds = (rawHours * 3600).round();

    // Time-of-day traffic congestion analysis
    final hour = DateTime.now().hour;
    final isPeakHour = (hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 21);

    // Calculate delay and percentages based on distance and peak status
    int delayMins;
    TrafficLevel level;
    int clearPercent;
    int moderatePercent;
    int slowPercent;
    String summary;
    String summaryHindi;

    if (distanceKm < 30) {
      if (isPeakHour) {
        level = TrafficLevel.moderate;
        delayMins = 8;
        clearPercent = 65;
        moderatePercent = 25;
        slowPercent = 10;
        summary = 'City traffic moderate. Minor delays at intersections.';
        summaryHindi =
            'शहर में हल्का ट्रैफिक है, सिग्नल्स पर सामान्य देरी होगी।';
      } else {
        level = TrafficLevel.smooth;
        delayMins = 3;
        clearPercent = 88;
        moderatePercent = 10;
        slowPercent = 2;
        summary = 'Smooth local traffic. Roads clear.';
        summaryHindi = 'सड़कें साफ़ हैं, सामान्य गति से आवागमन चालू है।';
      }
    } else if (distanceKm < 150) {
      if (isPeakHour) {
        level = TrafficLevel.moderate;
        delayMins = 16;
        clearPercent = 74;
        moderatePercent = 20;
        slowPercent = 6;
        summary = 'Highway traffic moderate with minor toll plaza queues.';
        summaryHindi =
            'हाईवे पर हल्का ट्रैफिक है, टोल प्लाज़ा पर सामान्य समय लगेगा।';
      } else {
        level = TrafficLevel.smooth;
        delayMins = 6;
        clearPercent = 86;
        moderatePercent = 11;
        slowPercent = 3;
        summary = 'Highway clear. Optimal fleet movement.';
        summaryHindi = 'हाईवे खुला है, गाड़ियाँ तेज़ रफ़्तार से चल रही हैं।';
      }
    } else {
      // Long distance corridor (e.g. 500+ km)
      if (isPeakHour) {
        level = TrafficLevel.moderate;
        delayMins = 24;
        clearPercent = 80;
        moderatePercent = 16;
        slowPercent = 4;
        summary =
            'Active corridor traffic. Moderate flow through bypass junctions.';
        summaryHindi =
            'कॉरिडोर पर यातायात सक्रिय है, बायपास और जंक्शनों पर हल्का ट्रैफिक।';
      } else {
        level = TrafficLevel.smooth;
        delayMins = 12;
        clearPercent = 87;
        moderatePercent = 10;
        slowPercent = 3;
        summary = 'Corridor flow normal. Smooth continuous driving conditions.';
        summaryHindi =
            'लंबी दूरी का कॉरिडोर साफ़ है, सामान्य गति से यात्रा जारी रहेगी।';
      }
    }

    final totalDuration = Duration(seconds: baseSeconds + (delayMins * 60));

    return TrafficReport(
      level: level,
      distanceKm: distanceKm,
      duration: totalDuration,
      delayMinutes: delayMins,
      clearPercent: clearPercent,
      moderatePercent: moderatePercent,
      slowPercent: slowPercent,
      summary: summary,
      summaryHindi: summaryHindi,
    );
  }

  /// Calculates comfortable [LatLngBounds] to display a route.
  static LatLngBounds boundsForPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds.fromPoints([
        const LatLng(20.0, 70.0),
        const LatLng(28.0, 85.0),
      ]);
    }
    return LatLngBounds.fromPoints(points);
  }

  /// Calculates the bearing / heading (0 - 360 degrees) from [start] to [end].
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = _degToRad(start.latitude);
    final startLng = _degToRad(start.longitude);
    final endLat = _degToRad(end.latitude);
    final endLng = _degToRad(end.longitude);

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final radians = math.atan2(y, x);
    return (_radToDeg(radians) + 360.0) % 360.0;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);

  /// Determines the turn maneuver type based on bearing difference.
  static ManeuverType getManeuver(double currentBearing, double nextBearing) {
    final diff = (nextBearing - currentBearing + 540) % 360 - 180;
    if (diff.abs() < 22) return ManeuverType.straight;
    if (diff >= 22 && diff < 65) return ManeuverType.slightRight;
    if (diff >= 65 && diff < 125) return ManeuverType.turnRight;
    if (diff >= 125 && diff < 160) return ManeuverType.sharpRight;
    if (diff <= -22 && diff > -65) return ManeuverType.slightLeft;
    if (diff <= -65 && diff > -125) return ManeuverType.turnLeft;
    if (diff <= -125 && diff > -160) return ManeuverType.sharpLeft;
    return ManeuverType.uTurn;
  }

  /// Returns cardinal direction label with directional side (Upper, Down, Left, Right).
  static String getCardinalDirection(double bearing) {
    final b = (bearing % 360 + 360) % 360;
    if (b >= 337.5 || b < 22.5) return 'North (Upper Side / उत्तर)';
    if (b >= 22.5 && b < 67.5) return 'North-East (Upper-Right)';
    if (b >= 67.5 && b < 112.5) return 'East (Right Side / पूर्व)';
    if (b >= 112.5 && b < 157.5) return 'South-East (Down-Right)';
    if (b >= 157.5 && b < 202.5) return 'South (Down Side / दक्षिण)';
    if (b >= 202.5 && b < 247.5) return 'South-West (Down-Left)';
    if (b >= 247.5 && b < 292.5) return 'West (Left Side / पश्चिम)';
    return 'North-West (Upper-Left)';
  }

  /// Finds the index of the point in [points] that is closest to [location].
  /// When [currentIndex] is provided, bounds search to a localized neighborhood around current
  /// progress to prevent navigation jumps on self-intersecting or looping routes.
  static int findClosestPointIndex(
    List<LatLng> points,
    LatLng location, {
    int? currentIndex,
    int searchWindow = 35,
  }) {
    if (points.isEmpty) return 0;
    int start = 0;
    int end = points.length;
    if (currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < points.length) {
      start = (currentIndex - 5).clamp(0, points.length - 1);
      end = (currentIndex + searchWindow).clamp(1, points.length);
    }
    var closestIdx = currentIndex ?? 0;
    var minDistance = double.infinity;
    for (var i = start; i < end; i++) {
      final d = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  /// Returns true only when the vehicle is physically close to the final
  /// destination and has progressed through most of the plotted route.
  /// The progress guard prevents an arrival prompt when a route happens to
  /// begin close to its destination or loops near it.
  static bool hasArrived({
    required LatLng currentLocation,
    required LatLng destination,
    required int closestPointIndex,
    required int routePointCount,
    double thresholdMeters = 75,
  }) {
    if (routePointCount < 2 ||
        closestPointIndex < 0 ||
        closestPointIndex >= routePointCount ||
        thresholdMeters <= 0) {
      return false;
    }

    final routeProgress = closestPointIndex / (routePointCount - 1);
    if (routeProgress < 0.9) return false;

    final distanceToDestination = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );
    return distanceToDestination <= thresholdMeters;
  }

  /// Scans forward on the route points to find the next turn and remaining distance.
  static NavigationTurnInfo findNextTurn(
      List<LatLng> points, int currentIndex) {
    if (points.length < 2 ||
        currentIndex < 0 ||
        currentIndex >= points.length - 1) {
      return const NavigationTurnInfo(
        maneuver: ManeuverType.straight,
        distanceMeters: 0,
        bearing: 0,
        instructionHindi: 'मंज़िल पर पहुँच गए (Arrived at destination)',
        instructionEnglish: 'You have arrived at your destination',
        cardinalDirection: 'Arrived',
      );
    }

    final currentBearing = calculateBearing(
      points[currentIndex],
      points[currentIndex + 1],
    );

    double accumulatedDistance = 0;
    var turnManeuver = ManeuverType.straight;
    double turnBearing = currentBearing;

    final maxLookahead = math.min(currentIndex + 35, points.length - 1);
    for (var i = currentIndex; i < maxLookahead; i++) {
      accumulatedDistance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );

      final nextBearing = calculateBearing(points[i], points[i + 1]);
      final maneuver = getManeuver(currentBearing, nextBearing);

      if (maneuver != ManeuverType.straight) {
        turnManeuver = maneuver;
        turnBearing = nextBearing;
        break;
      }
    }

    String hindiText;
    String engText;
    final dist = accumulatedDistance.round();

    switch (turnManeuver) {
      case ManeuverType.turnLeft:
      case ManeuverType.sharpLeft:
        hindiText = dist > 40
            ? '$dist m बाद बाएँ मुड़ें (Left Turn)'
            : 'अब बाएँ मुड़ें (Turn Left Now)';
        engText = dist > 40 ? 'In $dist m turn left' : 'Turn left now';
        break;
      case ManeuverType.slightLeft:
        hindiText = dist > 40
            ? '$dist m बाद हल्का बाएँ रखें'
            : 'हल्का बाएँ चलें (Keep Left)';
        engText = dist > 40 ? 'In $dist m keep left' : 'Keep left';
        break;
      case ManeuverType.turnRight:
      case ManeuverType.sharpRight:
        hindiText = dist > 40
            ? '$dist m बाद दाएँ मुड़ें (Right Turn)'
            : 'अब दाएँ मुड़ें (Turn Right Now)';
        engText = dist > 40 ? 'In $dist m turn right' : 'Turn right now';
        break;
      case ManeuverType.slightRight:
        hindiText = dist > 40
            ? '$dist m बाद हल्का दाएँ रखें'
            : 'हल्का दाएँ चलें (Keep Right)';
        engText = dist > 40 ? 'In $dist m keep right' : 'Keep right';
        break;
      case ManeuverType.uTurn:
        hindiText =
            dist > 40 ? '$dist m बाद U-Turn लें' : 'वापस मुड़ें (U-Turn Now)';
        engText = dist > 40 ? 'In $dist m make a U-Turn' : 'Make a U-Turn';
        break;
      case ManeuverType.straight:
        hindiText = 'सीधे चलें (Continue Straight)';
        engText = 'Continue straight on route';
        break;
    }

    return NavigationTurnInfo(
      maneuver: turnManeuver,
      distanceMeters: accumulatedDistance,
      bearing: turnBearing,
      instructionHindi: hindiText,
      instructionEnglish: engText,
      cardinalDirection: getCardinalDirection(currentBearing),
    );
  }

  /// Partitions route polyline points into live traffic congestion segments.
  static List<RoadTrafficSegment> calculateRoadTrafficSegments(
    List<LatLng> points,
    TrafficReport report,
  ) {
    if (points.length < 2) return [];

    // Four partitions require at least five points. Real OSRM routes normally
    // contain many more, but very short/fallback routes must still render.
    if (points.length < 5) {
      final speed = switch (report.level) {
        TrafficLevel.smooth => 60,
        TrafficLevel.moderate => 36,
        TrafficLevel.heavy => 20,
      };
      return [
        RoadTrafficSegment(
          points: List<LatLng>.unmodifiable(points),
          level: report.level,
          speedKmh: speed,
          label: 'Route traffic ($speed km/h)',
        ),
      ];
    }

    final segments = <RoadTrafficSegment>[];
    final total = points.length;

    // Partition points into 4 realistic highway corridor segments:
    // 1. Origin departure (0% to 15%): Urban start -> moderate slowdown
    // 2. Main express highway (15% to 65%): High speed smooth cruising
    // 3. Toll plaza / Highway interchange (65% to 80%): Moderate/heavy slowdown
    // 4. Destination arrival (80% to 100%): City approach -> heavy/moderate traffic

    int idx1 = (total * 0.15).round().clamp(1, total - 1);
    int idx2 = (total * 0.65).round().clamp(idx1 + 1, total - 1);
    int idx3 = (total * 0.82).round().clamp(idx2 + 1, total - 1);

    // Segment 1: Origin Departure
    final seg1Points = points.sublist(0, idx1 + 1);
    final seg1Level = report.level == TrafficLevel.smooth
        ? TrafficLevel.smooth
        : TrafficLevel.moderate;
    final seg1Speed = seg1Level == TrafficLevel.smooth ? 55 : 34;
    segments.add(RoadTrafficSegment(
      points: seg1Points,
      level: seg1Level,
      speedKmh: seg1Speed,
      label: 'Departure Arterial ($seg1Speed km/h)',
    ));

    // Segment 2: Main Express Corridor
    final seg2Points = points.sublist(idx1, idx2 + 1);
    const seg2Level = TrafficLevel.smooth;
    const seg2Speed = 78;
    segments.add(RoadTrafficSegment(
      points: seg2Points,
      level: seg2Level,
      speedKmh: seg2Speed,
      label: 'Express Highway ($seg2Speed km/h Clear)',
    ));

    // Segment 3: Highway Toll / Intersect Bottleneck
    final seg3Points = points.sublist(idx2, idx3 + 1);
    final seg3Level = report.level == TrafficLevel.heavy
        ? TrafficLevel.heavy
        : TrafficLevel.moderate;
    final seg3Speed = seg3Level == TrafficLevel.heavy ? 22 : 42;
    segments.add(RoadTrafficSegment(
      points: seg3Points,
      level: seg3Level,
      speedKmh: seg3Speed,
      label: 'Toll Plaza / Interchange ($seg3Speed km/h)',
    ));

    // Segment 4: Destination Arrival
    final seg4Points = points.sublist(idx3, total);
    final seg4Level = report.level == TrafficLevel.smooth
        ? TrafficLevel.smooth
        : (report.level == TrafficLevel.moderate
            ? TrafficLevel.moderate
            : TrafficLevel.heavy);
    final seg4Speed = seg4Level == TrafficLevel.heavy
        ? 18
        : (seg4Level == TrafficLevel.moderate ? 36 : 60);
    segments.add(RoadTrafficSegment(
      points: seg4Points,
      level: seg4Level,
      speedKmh: seg4Speed,
      label: 'Destination Approach ($seg4Speed km/h)',
    ));

    return segments;
  }

  /// Places live road traffic hotspot indicators along the highway.
  static List<RoadTrafficHotspot> calculateRoadHotspots(
    List<LatLng> points,
    TrafficReport report,
  ) {
    if (points.length < 6) return [];
    final hotspots = <RoadTrafficHotspot>[];
    final total = points.length;

    // Hotspot 1: High speed smooth corridor (~38% of route)
    final idx1 = (total * 0.38).round().clamp(0, total - 1);
    hotspots.add(RoadTrafficHotspot(
      point: points[idx1],
      level: TrafficLevel.smooth,
      speedKmh: 76,
      label: '76 km/h Smooth',
      locationName: 'National Highway Corridor',
    ));

    // Hotspot 2: Toll Plaza / Congestion slowdown (~72% of route)
    final idx2 = (total * 0.72).round().clamp(0, total - 1);
    final isCongested = report.level != TrafficLevel.smooth;
    hotspots.add(RoadTrafficHotspot(
      point: points[idx2],
      level: isCongested ? TrafficLevel.heavy : TrafficLevel.moderate,
      speedKmh: isCongested ? 24 : 45,
      label: isCongested ? '24 km/h Jam (+8m)' : '45 km/h Slow',
      locationName: 'Toll Plaza / Flyover Approach',
    ));

    return hotspots;
  }
}
