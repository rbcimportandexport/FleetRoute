import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/services/map_tile_service.dart';
import 'package:transport_one/src/services/route_traffic_service.dart';

void main() {
  group('MapTileService Tests', () {
    test('provides familiar primary and independent fallback tiles', () {
      expect(MapTileService.roadTileUrl, contains('arcgisonline.com'));
      expect(MapTileService.roadTileUrl, contains('{z}'));
      expect(MapTileService.roadTileUrl, contains('{x}'));
      expect(MapTileService.roadTileUrl, contains('{y}'));
      expect(MapTileService.satelliteTileUrl, contains('arcgisonline.com'));
      expect(
          MapTileService.satelliteTrafficTileUrl, contains('arcgisonline.com'));
      expect(MapTileService.trafficTileUrl, contains('arcgisonline.com'));
      expect(MapTileService.fallbackTileUrl, contains('openstreetmap.org'));
      expect(MapTileService.fallbackTileUrl, isNot(MapTileService.roadTileUrl));

      // Verify TileLayer accepts this configuration without error
      final layer = TileLayer(
        urlTemplate: MapTileService.getTileUrl(satellite: false, traffic: true),
        subdomains: MapTileService.subdomains,
        userAgentPackageName: MapTileService.userAgent,
      );
      expect(layer.subdomains, isEmpty);
    });

    test('getTileUrl selects correct URL according to view style and traffic',
        () {
      // Standard road
      expect(
        MapTileService.getTileUrl(
            satellite: false, streetlight: false, traffic: false),
        equals(MapTileService.roadTileUrl),
      );

      // Road with live traffic
      expect(
        MapTileService.getTileUrl(
            satellite: false, streetlight: false, traffic: true),
        equals(MapTileService.trafficTileUrl),
      );

      // Satellite hybrid without traffic
      expect(
        MapTileService.getTileUrl(
            satellite: true, streetlight: false, traffic: false),
        equals(MapTileService.satelliteTileUrl),
      );

      // Satellite hybrid WITH live traffic flow
      expect(
        MapTileService.getTileUrl(
            satellite: true, streetlight: false, traffic: true),
        equals(MapTileService.satelliteTrafficTileUrl),
      );

      // Streetlight / night navigation view
      expect(
        MapTileService.getTileUrl(
            satellite: false, streetlight: true, traffic: false),
        equals(MapTileService.streetlightTileUrl),
      );
      expect(
        MapTileService.getTileUrl(
            satellite: true, streetlight: true, traffic: true),
        equals(MapTileService.streetlightTileUrl),
      );

      // Fallback URL
      expect(MapTileService.fallbackTileUrl, contains('openstreetmap.org'));
    });

    test(
        'getSubdomains returns Carto subdomains only where template needs them',
        () {
      expect(MapTileService.getSubdomains(streetlight: true),
          equals(['a', 'b', 'c', 'd']));
      expect(MapTileService.getSubdomains(streetlight: false), isEmpty);
    });
  });

  group('Route Traffic Service Tests', () {
    final sampleRoute = [
      const LatLng(19.0760, 72.8777), // Mumbai
      const LatLng(19.0800, 72.8850),
      const LatLng(19.0900, 72.9000),
      const LatLng(19.1200, 72.9500),
      const LatLng(19.2000, 73.1000),
      const LatLng(19.3000, 73.3000),
      const LatLng(19.4000, 73.5000),
      const LatLng(18.5204, 73.8567), // Pune
    ];

    const reportModerate = TrafficReport(
      level: TrafficLevel.moderate,
      distanceKm: 140.0,
      duration: Duration(hours: 3),
      delayMinutes: 20,
      clearPercent: 60,
      moderatePercent: 30,
      slowPercent: 10,
      summary: 'Moderate slowdown on express corridor',
      summaryHindi: 'Highway par thoda traffic hai',
    );

    const reportHeavy = TrafficReport(
      level: TrafficLevel.heavy,
      distanceKm: 140.0,
      duration: Duration(hours: 4),
      delayMinutes: 45,
      clearPercent: 40,
      moderatePercent: 20,
      slowPercent: 40,
      summary: 'Congestion bottleneck',
      summaryHindi: 'Bhari jaam ki sambhavna',
    );

    test(
        'calculateRoadTrafficSegments divides route into colored traffic sections',
        () {
      final segments = RouteTrafficService.calculateRoadTrafficSegments(
          sampleRoute, reportModerate);
      expect(segments.isNotEmpty, isTrue);

      // Check segments have color and speed
      for (final seg in segments) {
        expect(seg.points.isNotEmpty, isTrue);
        expect(seg.color.a, greaterThan(0));
        expect(seg.speedKmh, greaterThan(0));
        expect(seg.label, isNotEmpty);
      }
    });

    test('calculateRoadTrafficSegments supports two-point routes', () {
      final points = [
        const LatLng(19.0760, 72.8777),
        const LatLng(18.5204, 73.8567),
      ];

      final segments = RouteTrafficService.calculateRoadTrafficSegments(
          points, reportModerate);

      expect(segments, hasLength(1));
      expect(segments.single.points, points);
      expect(segments.single.speedKmh, greaterThan(0));
    });

    test('calculateRoadHotspots generates badges along route', () {
      final hotspots =
          RouteTrafficService.calculateRoadHotspots(sampleRoute, reportHeavy);
      expect(hotspots.isNotEmpty, isTrue);
      for (final spot in hotspots) {
        expect(spot.label, isNotEmpty);
        expect(spot.locationName, isNotEmpty);
        expect(spot.speedKmh, greaterThan(0));
      }
    });
  });

  group('PlannerController Map View Style Tests', () {
    test('supports street, satellite, and streetlight styles seamlessly', () {
      final controller = PlannerController();
      expect(controller.mapStyle, equals(MapViewStyle.street));
      expect(controller.satellite, isFalse);
      expect(controller.isStreetlight, isFalse);

      controller.setMapStyle(MapViewStyle.satellite);
      expect(controller.mapStyle, equals(MapViewStyle.satellite));
      expect(controller.satellite, isTrue);
      expect(controller.isStreetlight, isFalse);

      controller.setMapStyle(MapViewStyle.streetlight);
      expect(controller.mapStyle, equals(MapViewStyle.streetlight));
      expect(controller.satellite, isFalse);
      expect(controller.isStreetlight, isTrue);

      // Backwards compatibility with setSatellite
      controller.setSatellite(true);
      expect(controller.mapStyle, equals(MapViewStyle.satellite));
      expect(controller.satellite, isTrue);
      expect(controller.isStreetlight, isFalse);

      controller.setSatellite(false);
      expect(controller.mapStyle, equals(MapViewStyle.street));
      expect(controller.satellite, isFalse);
      expect(controller.isStreetlight, isFalse);
    });
  });
}
