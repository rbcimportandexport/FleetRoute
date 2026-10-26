import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/firebase_options.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/services/ai_vision_service.dart';
import 'package:transport_one/src/services/app_security_service.dart';
import 'package:transport_one/src/services/firebase_backend_service.dart';
import 'package:transport_one/src/services/map_tile_service.dart';
import 'package:transport_one/src/services/route_traffic_service.dart';
import 'package:transport_one/src/widgets/seatbelt_verification_dialog.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AppSecurityService.resetFailedAttempts();
  });

  group('Deep Resilience & Fundamental Bug Fixes', () {
    test('findNextTurn guards against negative index without throwing', () {
      final points = [
        const LatLng(21.1702, 72.8311),
        const LatLng(21.1215, 73.1118),
        const LatLng(21.2709, 72.9634),
      ];

      // Negative index should not crash with RangeError
      final turnInfo = RouteTrafficService.findNextTurn(points, -1);
      expect(turnInfo.maneuver, ManeuverType.straight);
      expect(turnInfo.distanceMeters, 0);

      // Out of bounds index
      final turnInfoOob = RouteTrafficService.findNextTurn(points, 99);
      expect(turnInfoOob.maneuver, ManeuverType.straight);
    });

    test(
        'calculateRoadTrafficSegments handles short routes without ArgumentError in clamp',
        () {
      const report = TrafficReport(
        level: TrafficLevel.moderate,
        distanceKm: 12.0,
        duration: Duration(minutes: 25),
        delayMinutes: 5,
        clearPercent: 70,
        moderatePercent: 20,
        slowPercent: 10,
        summary: 'Moderate flow',
        summaryHindi: 'Madhyam traffic',
      );

      // 5 points route
      final points5 = [
        const LatLng(21.1, 72.8),
        const LatLng(21.12, 72.85),
        const LatLng(21.14, 72.9),
        const LatLng(21.16, 72.95),
        const LatLng(21.18, 73.0),
      ];
      final segments5 =
          RouteTrafficService.calculateRoadTrafficSegments(points5, report);
      expect(segments5.isNotEmpty, isTrue);

      // 6 points route
      final points6 = [...points5, const LatLng(21.2, 73.05)];
      final segments6 =
          RouteTrafficService.calculateRoadTrafficSegments(points6, report);
      expect(segments6.isNotEmpty, isTrue);

      // 12 points route
      final points12 = List.generate(
        12,
        (i) => LatLng(21.0 + (i * 0.05), 72.8 + (i * 0.05)),
      );
      final segments12 =
          RouteTrafficService.calculateRoadTrafficSegments(points12, report);
      expect(segments12.length, 4);
    });

    test('parseLocation exact city match takes priority over partial match',
        () {
      final delhi = RouteTrafficService.parseLocation('Delhi');
      expect(delhi, isNotNull);
      expect(delhi!.latitude, closeTo(28.6139, 0.01));

      // Coordinates regex does not crash with null groups
      final parsedCoord =
          RouteTrafficService.parseLocation('21.12345, 73.12345');
      expect(parsedCoord, isNotNull);
      expect(parsedCoord!.latitude, closeTo(21.12345, 0.0001));
      expect(parsedCoord.longitude, closeTo(73.12345, 0.0001));

      // Malformed text
      expect(RouteTrafficService.parseLocation('   '), isNull);
      expect(RouteTrafficService.parseLocation('unknown place 999'), isNull);
      expect(RouteTrafficService.parseLocation('suratanything'), isNull);
      expect(RouteTrafficService.parseLocation('notdelhi'), isNull);

      final address =
          RouteTrafficService.parseLocation('Ring Road, Surat, Gujarat');
      expect(address, isNotNull);
      expect(address!.latitude, closeTo(21.1702, 0.01));
    });

    test('multi-stop routing stitches road legs when unified request fails',
        () async {
      final requestedWaypointCounts = <int>[];
      final client = MockClient((request) async {
        final encodedCoordinates = request.url.pathSegments.last;
        final coordinates = encodedCoordinates.split(';');
        requestedWaypointCounts.add(coordinates.length);

        if (coordinates.length > 2) {
          return http.Response('{"code":"Error"}', 503);
        }

        final geometry = coordinates.map((coordinate) {
          final pair = coordinate.split(',');
          return [double.parse(pair[0]), double.parse(pair[1])];
        }).toList();
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 1000,
                'duration': 60,
                'geometry': {'coordinates': geometry},
              }
            ],
          }),
          200,
        );
      });

      const waypoints = [
        LatLng(21.10, 72.80),
        LatLng(21.20, 72.90),
        LatLng(21.30, 73.00),
        LatLng(21.40, 73.10),
      ];
      final result = await RouteTrafficService.fetchMultiStopRoute(
        waypoints: waypoints,
        client: client,
      );

      expect(requestedWaypointCounts.first, 4);
      expect(requestedWaypointCounts.where((count) => count == 2).length, 3);
      expect(result.isRealHighwayRoute, isTrue);
      expect(result.points, hasLength(4));
      for (int i = 0; i < waypoints.length; i++) {
        expect(result.points[i].latitude, closeTo(waypoints[i].latitude, 1e-6));
        expect(
          result.points[i].longitude,
          closeTo(waypoints[i].longitude, 1e-6),
        );
      }
      expect(result.distanceKm, 3);
    });

    test('reorderStop reorders intermediate stops safely', () {
      final controller = PlannerController();
      controller.addStop('Stop 1');
      controller.addStop('Stop 2');
      controller.addStop('Stop 3');

      // Reorder from index 0 to 2
      controller.reorderStop(0, 2);
      expect(controller.stops, ['Stop 2', 'Stop 1', 'Stop 3']);

      // Reorder from index 2 to 0
      controller.reorderStop(2, 0);
      expect(controller.stops, ['Stop 3', 'Stop 2', 'Stop 1']);

      // Out of bounds indices do nothing
      controller.reorderStop(-1, 2);
      expect(controller.stops, ['Stop 3', 'Stop 2', 'Stop 1']);
    });

    test('swapLocations resets isNavigating if navigation is active', () {
      final controller = PlannerController()
        ..setOrigin('Surat')
        ..setDestination('Bardoli');
      controller.startNavigation();
      expect(controller.isNavigating, isTrue);

      controller.swapLocations();
      expect(controller.isNavigating, isFalse);
      expect(controller.origin, 'Bardoli');
      expect(controller.destination, 'Surat');
    });

    test('continueFromDestination turns the completed drop into pickup', () {
      final controller = PlannerController()
        ..setOrigin('Surat')
        ..addStop('Kamrej')
        ..setDestination('Bardoli');
      controller.startNavigation();

      controller.continueFromDestination();

      expect(controller.origin, 'Bardoli');
      expect(controller.destination, isEmpty);
      expect(controller.stops, isEmpty);
      expect(controller.isNavigating, isFalse);
      expect(controller.canShowRoute, isFalse);
    });

    test('arrival requires both final-route progress and nearby GPS', () {
      const destination = LatLng(21.1702, 72.8311);

      expect(
        RouteTrafficService.hasArrived(
          currentLocation: const LatLng(21.1703, 72.8311),
          destination: destination,
          closestPointIndex: 99,
          routePointCount: 100,
        ),
        isTrue,
      );
      expect(
        RouteTrafficService.hasArrived(
          currentLocation: const LatLng(21.1703, 72.8311),
          destination: destination,
          closestPointIndex: 20,
          routePointCount: 100,
        ),
        isFalse,
      );
      expect(
        RouteTrafficService.hasArrived(
          currentLocation: const LatLng(21.1800, 72.8311),
          destination: destination,
          closestPointIndex: 99,
          routePointCount: 100,
        ),
        isFalse,
      );
    });

    test('decryptPayload handles legacy JSON with colons without corrupting',
        () {
      const rawJson = '{"key":"value","number":123}';
      final decrypted = AppSecurityService.decryptPayload(rawJson);
      expect(decrypted, rawJson);

      // Encrypted round-trip
      final encrypted = AppSecurityService.encryptPayload(rawJson);
      expect(encrypted.startsWith('{"'), isFalse);
      final recovered = AppSecurityService.decryptPayload(encrypted);
      expect(recovered, rawJson);
    });

    test('multi-stop pinning allows consecutive additions of stops 1, 2, 3, 4',
        () {
      final controller = PlannerController();
      controller.setOrigin('21.170240, 72.831060'); // Place 1: Surat
      controller.setDestination('21.125500, 73.112200'); // Place 2: Bardoli
      expect(controller.origin, isNotEmpty);
      expect(controller.destination, isNotEmpty);

      // Pin Place 3 (Via Stop 1: Kamrej)
      controller.addStop('21.270000, 72.960000');
      expect(controller.stops.length, 1);

      // Pin Place 4 (Via Stop 2: Navsari)
      controller.addStop('20.946700, 72.952000');
      expect(controller.stops.length, 2);

      // Total route places: 4 (Origin + 2 Stops + Destination)
      expect(controller.stops[0], '21.270000, 72.960000');
      expect(controller.stops[1], '20.946700, 72.952000');
    });

    test(
        'findClosestPointIndex with currentIndex prevents progress jump on route loop / self-intersection',
        () {
      // Create a figure-8 / looping route:
      // Index 0..10 goes north, index 10..20 loops east and crosses index 5, index 20..30 goes south
      final points = <LatLng>[
        const LatLng(21.10, 72.80), // 0
        const LatLng(21.12, 72.80), // 1
        const LatLng(21.14, 72.80), // 2
        const LatLng(21.16, 72.80), // 3
        const LatLng(21.18, 72.80), // 4
        const LatLng(21.20, 72.80), // 5 (crossing point)
        const LatLng(21.22, 72.80), // 6
        const LatLng(21.24, 72.80), // 7
        const LatLng(21.24, 72.82), // 8
        const LatLng(21.22, 72.82), // 9
        const LatLng(21.20, 72.80001), // 10 (crosses near index 5 again!)
        const LatLng(21.18, 72.82), // 11
        const LatLng(21.16, 72.82), // 12
        const LatLng(21.14, 72.82), // 13
        const LatLng(21.12, 72.82), // 14
        const LatLng(21.10, 72.82), // 15
      ];

      const vehicleLoc =
          LatLng(21.20002, 72.80002); // physically close to both 5 and 10

      // When vehicle is at index 2 early in the trip, global search might pick 10 if closer by float delta,
      // but localized search around index 2 MUST pick index 5 and NOT jump to index 10!
      final localizedIdx = RouteTrafficService.findClosestPointIndex(
        points,
        vehicleLoc,
        currentIndex: 2,
        searchWindow: 6, // window covers indices 0..8
      );
      expect(localizedIdx, 5);

      // When vehicle has legitimately progressed to index 9, localized search correctly picks index 10
      final progressedIdx = RouteTrafficService.findClosestPointIndex(
        points,
        vehicleLoc,
        currentIndex: 9,
        searchWindow: 6,
      );
      expect(progressedIdx, 10);
    });

    test('AppSecurityService.verifySessionToken rejects future-dated tokens',
        () {
      const email = 'driver@transport.com';
      const role = 'driver';

      // 1. Legitimate current session token (created now)
      final validToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now(),
      );
      expect(
        AppSecurityService.verifySessionToken(
          email: email,
          role: role,
          token: validToken,
        ),
        isTrue,
      );

      // 2. Future-dated token (+2 hours in the future)
      final futureToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(
        AppSecurityService.verifySessionToken(
          email: email,
          role: role,
          token: futureToken,
        ),
        isFalse,
      );

      // 3. Far future-dated token (+1 year in the future)
      final farFutureToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now().add(const Duration(days: 365)),
      );
      expect(
        AppSecurityService.verifySessionToken(
          email: email,
          role: role,
          token: farFutureToken,
        ),
        isFalse,
      );

      // 4. Expired token (10 days old, maxAge is 7 days)
      final expiredToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(
        AppSecurityService.verifySessionToken(
          email: email,
          role: role,
          token: expiredToken,
        ),
        isFalse,
      );
    });

    test('AiVisionService detects photo replay attack and liveness', () {
      final photo1 =
          Uint8List.fromList(List.generate(300, (i) => (i * 17) % 256));
      final photo2 =
          Uint8List.fromList(List.generate(300, (i) => (i * 23) % 256));
      final flatScreen =
          Uint8List.fromList(List.filled(400, 128)); // 0 variance

      final record = SeatbeltRecord(
        id: 'REC-1',
        driverName: 'Test Driver',
        driverId: 'test@driver.com',
        vehicleNumber: 'GJ19Y2720',
        photoBase64: 'data:image/jpeg;base64,${base64Encode(photo1)}',
        timestamp: DateTime.now(),
        isApproved: true,
      );

      // Photo 1 is in existing records, so it must be flagged as replay
      expect(
        AiVisionService.instance.checkIsReplay(
          photoBytes: photo1,
          existingRecords: [record],
        ),
        isTrue,
      );

      // Photo 2 is fresh, so it is NOT a replay
      expect(
        AiVisionService.instance.checkIsReplay(
          photoBytes: photo2,
          existingRecords: [record],
        ),
        isFalse,
      );

      // Flat screen image with 0 variance fails liveness
      expect(AiVisionService.instance.checkLiveness(flatScreen), isFalse);

      // Arbitrary bytes are not a trustworthy live camera image. The
      // safety-critical verifier must fail closed without backend approval.
      expect(AiVisionService.instance.checkLiveness(photo1), isFalse);
    });

    test('TrafficReport contains isEstimated flag and provider metadata', () {
      final report = RouteTrafficService.analyzeTraffic(
        distanceKm: 120.0,
        vehicle: VehicleType.truck,
      );
      expect(report.isEstimated, isTrue);
      expect(report.providerName, 'Highway Traffic Flow Model');
    });

    test(
        'MapTileService provides official OSM and Carto endpoints alongside Google layers',
        () {
      expect(MapTileService.osmTileUrl, contains('tile.openstreetmap.org'));
      expect(MapTileService.cartoVoyagerTileUrl, contains('cartocdn.com'));
    });

    test('SeatbeltVerificationDialog rejects corrupt or small images',
        () async {
      final corruptBytes = Uint8List.fromList(List.filled(100, 0));
      final result =
          await SeatbeltVerificationDialog.analyzeSeatbeltImage(corruptBytes);
      expect(result.detected, isFalse);
      expect(result.message, contains('Photo bahut chhoti ya invalid hai'));
    });

    test(
        'SeatbeltVerificationDialog accurately approves genuine driver seatbelt photos',
        () async {
      final assetFile = File('test/assets/sample_seatbelt_driver.png');
      if (assetFile.existsSync()) {
        final bytes = await assetFile.readAsBytes();
        final result =
            await SeatbeltVerificationDialog.analyzeSeatbeltImage(bytes);
        expect(result.detected, isTrue);
        expect(result.message, contains('verify hui'));
      }
    });

    test(
        'FirebaseBackendService syncs seatbelt and telemetry records in standalone/mock mode',
        () async {
      final backend = FirebaseBackendService.instance;
      final record = SeatbeltRecord(
        id: 'SYNC-101',
        driverName: 'Test Driver',
        driverId: 'driver@transport.com',
        vehicleNumber: 'GJ19Y2720',
        photoBase64: 'data:image/jpeg;base64,mockphoto123',
        timestamp: DateTime.now(),
        isApproved: true,
      );

      // When mock client is provided
      final mockClient = MockClient((request) async {
        return http.Response(
            '{"name":"projects/transport-one/databases/(default)/documents/record"}',
            200);
      });

      final syncSuccess =
          await backend.syncSeatbeltRecord(record: record, client: mockClient);
      expect(syncSuccess, isTrue);

      final telemetrySuccess = await backend.syncVehicleTelemetry(
        vehicleCode: 'GJ19Y2720',
        latitude: 21.1702,
        longitude: 72.8311,
        speed: 45.0,
        isIgnitionOn: true,
        client: mockClient,
      );
      expect(telemetrySuccess, isTrue);
    });

    test('DefaultFirebaseOptions provides platform-appropriate configuration',
        () {
      expect(DefaultFirebaseOptions.projectId, 'transport-one');
      expect(DefaultFirebaseOptions.appId, contains('839976327049'));
      expect(DefaultFirebaseOptions.storageBucket,
          contains('firebasestorage.app'));
    });
  });
}
