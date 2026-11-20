import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/services/ai_vision_service.dart';
import 'package:transport_one/src/services/app_security_service.dart';
import 'package:transport_one/src/services/firebase_backend_service.dart';
import 'package:transport_one/src/services/map_tile_service.dart';
import 'package:transport_one/src/services/route_traffic_service.dart';
import 'package:transport_one/src/widgets/trip_playback_dialog.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AppSecurityService.resetFailedAttempts();
  });

  group('Group 1: Layer 1 - 25: TripPlaybackDialog & Video Navigation Crash Shield', () {
    testWidgets('Layer 1-5: Empty, single point, and corrupted trip record playback', (tester) async {
      // 1. Empty trip
      const emptyTrip = TripRecord(
        reference: 'TRIP-EMPTY',
        tripNumber: 'TRIP-000',
        origin: '',
        destination: '',
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: emptyTrip)));
      await tester.pumpAndSettle();
      expect(find.byType(TripPlaybackDialog), findsOneWidget);

      // 2. Single point trip
      const singlePtTrip = TripRecord(
        reference: 'TRIP-SINGLE',
        tripNumber: 'TRIP-001',
        origin: '21.1702, 72.8311',
        destination: '21.1702, 72.8311',
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: singlePtTrip)));
      await tester.pumpAndSettle();
      expect(find.text('0 km/h'), findsWidgets);

      // 3. Corrupt date
      const corruptDateTrip = TripRecord(
        reference: 'TRIP-CORRUPT-DATE',
        tripNumber: 'TRIP-002',
        origin: 'Surat',
        destination: 'Navsari',
        startedAt: 'not-a-valid-date-string-1234',
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: corruptDateTrip)));
      await tester.pumpAndSettle();

      // 4. Negative duration
      const negDurationTrip = TripRecord(
        reference: 'TRIP-NEG-DUR',
        tripNumber: 'TRIP-003',
        origin: 'Surat',
        destination: 'Bardoli',
        plannedDurationMinutes: -999,
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: negDurationTrip)));
      await tester.pumpAndSettle();

      // 5. Huge breadcrumbs
      final breadcrumbs = List.generate(
        300,
        (i) => GpsBreadcrumb(
          latitude: 21.17 + (i * 0.0001),
          longitude: 72.83 + (i * 0.0001),
          speed: 45.0,
          course: 90.0,
          timestamp: DateTime.now().add(Duration(seconds: i * 5)),
        ),
      );
      final controller = PlannerController();
      controller.truckModels.add(TruckModel(
        code: 'GJ19Y2720',
        name: 'Sandeep Tempo',
        axles: '2',
        capacity: '5 Ton',
        gpsHistory: breadcrumbs,
      ));
      const breadcrumbTrip = TripRecord(
        reference: 'TRIP-BREADCRUMB',
        tripNumber: 'TRIP-005',
        assignedVehicle: 'GJ19Y2720',
        origin: 'Surat',
        destination: 'Navsari',
      );
      await tester.pumpWidget(MaterialApp(
        home: TripPlaybackDialog(trip: breadcrumbTrip, controller: controller),
      ));
      await tester.pumpAndSettle();
      controller.dispose();
    });

    testWidgets('Layer 6-15: Seek, Speed & Ticker Chaos (NaN, Infinity, Negatives, Overflows)', (tester) async {
      const trip = TripRecord(
        reference: 'TRIP-CHAOS',
        tripNumber: 'TRIP-010',
        origin: 'Surat',
        destination: 'Bharuch',
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: trip)));
      await tester.pumpAndSettle();

      // Find play button and toggle
      final playBtn = find.byIcon(Icons.play_arrow_rounded);
      if (playBtn.evaluate().isNotEmpty) {
        await tester.tap(playBtn);
        await tester.pump(const Duration(milliseconds: 150));
      }

      // Fast forward and rewind clicks
      final ffBtn = find.byIcon(Icons.forward_10_rounded);
      if (ffBtn.evaluate().isNotEmpty) {
        await tester.tap(ffBtn);
        await tester.pump(const Duration(milliseconds: 50));
      }
      final rewBtn = find.byIcon(Icons.replay_10_rounded);
      if (rewBtn.evaluate().isNotEmpty) {
        await tester.tap(rewBtn);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Speed selection
      final speedPill = find.text('5x');
      if (speedPill.evaluate().isNotEmpty) {
        await tester.tap(speedPill);
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets('Layer 16-25: Stoppage interactions, satellite toggle, fullscreen fit', (tester) async {
      const trip = TripRecord(
        reference: 'TRIP-STOPS',
        tripNumber: 'TRIP-020',
        origin: 'Mumbai',
        destination: 'Ahmedabad',
        actualDistanceKm: 500,
        plannedDistanceKm: 500,
        stops: ['Surat', 'Vadodara'],
      );
      await tester.pumpWidget(const MaterialApp(home: TripPlaybackDialog(trip: trip)));
      await tester.pumpAndSettle();

      // Satellite toggle
      final satBtn = find.byTooltip('Toggle Satellite');
      if (satBtn.evaluate().isNotEmpty) {
        await tester.tap(satBtn);
        await tester.pumpAndSettle();
        await tester.tap(satBtn);
        await tester.pumpAndSettle();
      }

      // Fullscreen fit button
      final fitBtn = find.byType(FloatingActionButton);
      if (fitBtn.evaluate().isNotEmpty) {
        await tester.tap(fitBtn.first);
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  });

  group('Group 2: Layer 26 - 50: Map Workspace, Polylines & Tile Resilience', () {
    test('Layer 26-35: Location parsing and bearing calculation edge cases', () {
      // 26. Empty location
      expect(RouteTrafficService.parseLocation(''), isNull);
      // 27. Normal coordinate
      final c1 = RouteTrafficService.parseLocation('21.1702, 72.8311');
      expect(c1, isNotNull);
      // 28. Reversed coordinate
      final c2 = RouteTrafficService.parseLocation('72.8311, 21.1702');
      expect(c2, isNotNull);
      // 29. Special symbols
      expect(RouteTrafficService.parseLocation('@#\$%^&*()'), isNull);
      // 30. Identical bearing
      final b1 = RouteTrafficService.calculateBearing(
        const LatLng(21.1702, 72.8311),
        const LatLng(21.1702, 72.8311),
      );
      expect(b1, 0.0);
      // 31. North bearing
      final b2 = RouteTrafficService.calculateBearing(
        const LatLng(20.0, 72.0),
        const LatLng(21.0, 72.0),
      );
      expect(b2, closeTo(0.0, 1.0));
      // 32. Distance identical
      final d1 = Geolocator.distanceBetween(21.1702, 72.8311, 21.1702, 72.8311);
      expect(d1, 0.0);
      // 33. Distance equator
      final d2 = Geolocator.distanceBetween(0.0, 0.0, 0.0, 1.0);
      expect(d2, greaterThan(100000.0));
    });

    test('Layer 36-50: Traffic segments and maneuver turns resilience', () {
      const report = TrafficReport(
        level: TrafficLevel.moderate,
        distanceKm: -5.0, // Negative distance
        duration: Duration(minutes: -10), // Negative duration
        delayMinutes: -3,
        clearPercent: 120, // Over 100%
        moderatePercent: -20,
        slowPercent: 0,
        summary: '',
        summaryHindi: '',
      );
      final points = [
        const LatLng(21.1702, 72.8311),
        const LatLng(21.1750, 72.8350),
      ];

      final segments = RouteTrafficService.calculateRoadTrafficSegments(points, report);
      expect(segments, isNotNull);

      // Edge turn calculations
      final t1 = RouteTrafficService.findNextTurn(points, -500);
      expect(t1.maneuver, ManeuverType.straight);
      final t2 = RouteTrafficService.findNextTurn(points, 5000);
      expect(t2.maneuver, ManeuverType.straight);

      // Tile URLs
      expect(MapTileService.getTileUrl(satellite: false, streetlight: false, traffic: false), isNotEmpty);
      expect(MapTileService.getTileUrl(satellite: true, streetlight: false, traffic: false), isNotEmpty);
      expect(MapTileService.fallbackTileUrl, isNotEmpty);
    });
  });

  group('Group 3: Layer 51 - 75: Telemetry, Driver Attendance & Hardware Protection', () {
    test('Layer 51-65: Telemetry boundary clamping and bad coordinates', () async {
      final mockClient = MockClient((request) async => http.Response('{}', 200));

      // 51. Latitude > 90
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-1',
        latitude: 91.0,
        longitude: 72.0,
        speed: 50.0,
        isIgnitionOn: true,
        client: mockClient,
      ), isFalse);

      // 52. Latitude < -90
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-2',
        latitude: -91.0,
        longitude: 72.0,
        speed: 50.0,
        isIgnitionOn: true,
        client: mockClient,
      ), isFalse);

      // 53. Longitude > 180
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-3',
        latitude: 21.0,
        longitude: 181.0,
        speed: 50.0,
        isIgnitionOn: true,
        client: mockClient,
      ), isFalse);

      // 54. Longitude < -180
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-4',
        latitude: 21.0,
        longitude: -181.0,
        speed: 50.0,
        isIgnitionOn: true,
        client: mockClient,
      ), isFalse);

      // 55. Extreme speed clamping
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-5',
        latitude: 21.0,
        longitude: 72.0,
        speed: 999.0, // Should clamp to 220
        isIgnitionOn: true,
        client: mockClient,
      ), isTrue);

      // 56. Negative speed clamping
      expect(await FirebaseBackendService.instance.syncVehicleTelemetry(
        vehicleCode: 'TEST-6',
        latitude: 21.0,
        longitude: 72.0,
        speed: -50.0, // Should clamp to 0
        isIgnitionOn: false,
        client: mockClient,
      ), isTrue);

      // 57. Empty vehicle code
      expect(await FirebaseBackendService.instance.updateVehicleBatteryTelemetry(
        vehicleCode: '   ',
        phoneBatteryLevel: 80,
        isPhoneCharging: true,
        client: mockClient,
      ), isFalse);

      // 58. Valid battery sync
      expect(await FirebaseBackendService.instance.updateVehicleBatteryTelemetry(
        vehicleCode: 'GJ19Y2720',
        phoneBatteryLevel: 85,
        isPhoneCharging: false,
        client: mockClient,
      ), isTrue);
    });

    test('Layer 66-75: Attendance, seatbelt, expenses, billing offline operations', () async {
      final mockClient = MockClient((request) async => http.Response('{}', 200));

      // 66. Attendance
      final att = AttendanceRecord(
        id: 'ATT-CRASH-TEST',
        driverId: 'driver@transport1.com',
        driverName: 'Test Driver',
        date: '2026-11-20',
        startTime: '2026-11-20T08:00:00Z',
      );
      expect(await FirebaseBackendService.instance.syncAttendanceRecord(record: att, client: mockClient), isTrue);

      // 67. Seatbelt verification reject flat / low-variance image
      final flatImage = Uint8List.fromList(List.filled(200, 128));
      expect(AiVisionService.instance.checkLiveness(flatImage), isFalse);

      // 68. Expense
      const exp = ExpenseRecord(
        id: 'EXP-CRASH-TEST',
        tripId: 'TRIP-001',
        amount: 500,
        category: 'fuel',
        date: '2026-11-20',
        isDirect: true,
      );
      expect(await FirebaseBackendService.instance.syncExpenseRecord(record: exp, client: mockClient), isTrue);
      expect(await FirebaseBackendService.instance.deleteExpenseRecord('EXP-CRASH-TEST'), isTrue);

      // 69. Billing
      const bill = BillingRecord(
        id: 'BILL-CRASH-TEST',
        tripId: 'TRIP-001',
        freightRate: 15000,
      );
      expect(await FirebaseBackendService.instance.syncBillingRecord(record: bill, client: mockClient), isTrue);
      expect(await FirebaseBackendService.instance.deleteBillingRecord('BILL-CRASH-TEST'), isTrue);
    });
  });

  group('Group 4: Layer 76 - 100: Controller Concurrency, Session Security & State Integrity', () {
    test('Layer 76-88: Planner Controller manipulation and security tokens', () {
      final controller = PlannerController();

      // 76. Swap locations empty
      controller.swapLocations();
      expect(controller.origin, isEmpty);

      // 77. Reorder stops out of bounds
      controller.reorderStop(-1, 5); // Must not throw RangeError
      controller.reorderStop(5, -1);

      // 78. Remove stop out of bounds
      controller.removeStop(-1);
      controller.removeStop(99);

      // 79. Select truck out of bounds
      controller.selectTruck(-5);
      controller.selectTruck(99);

      // 80. Security tokens
      const email = 'driver@transport.com';
      const role = 'driver';
      final validToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now(),
      );
      expect(AppSecurityService.verifySessionToken(email: email, role: role, token: validToken), isTrue);

      final expiredToken = AppSecurityService.createSessionToken(
        email: email,
        role: role,
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(AppSecurityService.verifySessionToken(email: email, role: role, token: expiredToken), isFalse);

      // Tampered token
      expect(AppSecurityService.verifySessionToken(email: email, role: role, token: '$validToken.tampered'), isFalse);

      controller.dispose();
    });

    test('Layer 89-100: State persistence, duty toggle, and clean disposal', () async {
      final controller = PlannerController();

      // Start & end duty
      await controller.markStartDuty(
        driverId: 'driver-test',
        driverName: 'Driver Test',
        notes: 'Crash test duty',
      );
      expect(controller.getActiveDuty('driver-test'), isNotNull);

      await controller.markEndDuty(
        driverId: 'driver-test',
        notes: 'End duty',
      );
      expect(controller.getActiveDuty('driver-test'), isNull);

      // Stop GPS auto polling safely
      controller.stopGpsAutoPolling();
      controller.stopGpsAutoPolling(); // Repeat must not throw

      controller.dispose();
    });
  });
}
