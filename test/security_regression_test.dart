import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/services/ai_vision_service.dart';
import 'package:transport_one/src/services/firebase_backend_service.dart';
import 'package:transport_one/src/services/map_tile_service.dart';
import 'package:transport_one/src/services/protrack_gps_service.dart';
import 'package:transport_one/src/services/route_traffic_service.dart';
import 'package:transport_one/src/services/whatsapp_otp_service.dart';

void main() {
  test('release source contains no seeded fleet identity or telemetry', () {
    expect(PlannerController.defaultFleetDrivers, isEmpty);
    expect(PlannerController.defaultFleetVehicles, isEmpty);
    expect(PlannerController().isAdmin, isFalse);
  });

  test('map uses documented providers instead of Google tile scraping', () {
    expect(MapTileService.roadTileUrl, contains('arcgisonline.com'));
    expect(MapTileService.roadTileUrl, isNot(contains('google.com')));
    expect(MapTileService.satelliteTileUrl, contains('arcgisonline.com'));
  });

  test('arbitrary bytes cannot pass local image validation', () {
    final arbitrary =
        Uint8List.fromList(List<int>.generate(5000, (i) => i % 256));
    expect(AiVisionService.instance.checkLiveness(arbitrary), isFalse);
    expect(AiVisionService.instance.checkLiveness(Uint8List(20)), isFalse);
  });

  test('direct Protrack credentials never configure the client', () {
    final service = ProtrackGpsService.instance..resetToDefaults();
    service.configureCredentials(account: 'user', password: 'secret');
    expect(service.account, isEmpty);
    expect(service.isConfigured, ProtrackGpsService.proxyUrl.isNotEmpty);
  });

  test('Firestore writes fail closed without Firebase authentication',
      () async {
    expect(FirebaseBackendService.instance.isConfigured, isFalse);
  });

  test('routing failure never produces mixed synthetic straight lines',
      () async {
    final client = MockClient((_) async => http.Response('unavailable', 503));
    final route = await RouteTrafficService.fetchMultiStopRoute(
      waypoints: const [LatLng(21.17, 72.83), LatLng(19.07, 72.87)],
      client: client,
    );
    expect(route.points, isEmpty);
    expect(route.isRealHighwayRoute, isFalse);
  });

  test('legacy client OTP is fail-closed', () async {
    final result = await WhatsAppOtpService.instance.sendOtp(
      phoneNumber: '9876543210',
    );
    expect(result['success'], isFalse);
    expect(
      WhatsAppOtpService.instance.verifyOtp(
        phoneNumber: '9876543210',
        enteredOtp: '123456',
      ),
      isFalse,
    );
  });
}
