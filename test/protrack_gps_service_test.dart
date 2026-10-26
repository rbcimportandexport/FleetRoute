import 'package:flutter_test/flutter_test.dart';
import 'package:transport_one/src/services/protrack_gps_service.dart';

void main() {
  group('ProtrackGpsService Tests', () {
    setUp(() {
      ProtrackGpsService.instance.resetToDefaults();
    });

    test('generateSignature computes valid lowercase 32-char md5 hash', () {
      final sig = ProtrackGpsService.generateSignature('Abc@34590', 1556243443);
      expect(sig.length, 32);
      expect(sig, sig.toLowerCase());
      expect(sig, '3844afd2c3bf68f0f3f4aa0a9ee8ee6c');
    });

    test('ProtrackDevicePosition parses official accstatus schema correctly',
        () {
      final json = {
        'imei': '861234567890123',
        'latitude': 21.1702,
        'longitude': 72.8311,
        'speed': 45.5,
        'course': 180.0,
        'gpstime': 1776739200,
        'servertime': 1776739205,
        'accstatus': 1,
      };

      final pos =
          ProtrackDevicePosition.fromJson(json, vehicleCode: 'GJ19Y2720');

      expect(pos.imei, '861234567890123');
      expect(pos.vehicleCode, 'GJ19Y2720');
      expect(pos.latitude, 21.1702);
      expect(pos.longitude, 72.8311);
      expect(pos.speed, 45.5);
      expect(pos.course, 180.0);
      expect(pos.isIgnitionOn, isTrue);
      expect(pos.hasCoordinates, isTrue);
      expect(pos.gpsTime, isNotNull);
    });

    test('ProtrackDevicePosition parses accstatus 0 as ignition off', () {
      final json = {
        'imei': '861234567890123',
        'latitude': 21.1702,
        'longitude': 72.8311,
        'speed': 0.0,
        'course': 0.0,
        'gpstime': 1776739200,
        'accstatus': 0,
      };

      final pos =
          ProtrackDevicePosition.fromJson(json, vehicleCode: 'GJ19Y2720');
      expect(pos.isIgnitionOn, isFalse);
    });

    test('ProtrackDevicePosition parses numeric values in string form safely',
        () {
      final json = {
        'imei': '861234567890123',
        'latitude': '21.170250',
        'longitude': '72.831120',
        'speed': '52.4',
        'course': '175.5',
        'gpstime': '1776739200',
        'accstatus': '1',
      };

      final pos =
          ProtrackDevicePosition.fromJson(json, vehicleCode: 'GJ19Y2720');
      expect(pos.latitude, closeTo(21.170250, 0.0001));
      expect(pos.longitude, closeTo(72.831120, 0.0001));
      expect(pos.speed, closeTo(52.4, 0.01));
      expect(pos.course, closeTo(175.5, 0.01));
      expect(pos.isIgnitionOn, isTrue);
    });

    test(
        'ProtrackDevicePosition rejects invalid (0,0) and out-of-bounds coordinates',
        () {
      final zeroJson = {
        'imei': '861234567890123',
        'latitude': 0.0,
        'longitude': 0.0,
        'speed': 0.0,
      };
      final zeroPos = ProtrackDevicePosition.fromJson(zeroJson);
      expect(zeroPos.latitude, 0.0);
      expect(zeroPos.longitude, 0.0);
      expect(zeroPos.hasCoordinates, isFalse);
      expect(zeroPos.isValidCoordinate, isFalse);

      final outOfBoundsJson = {
        'imei': '861234567890123',
        'latitude': 120.0, // Invalid latitude (> 90)
        'longitude': 72.8311,
      };
      final outPos = ProtrackDevicePosition.fromJson(outOfBoundsJson);
      expect(outPos.latitude, 120.0);
      expect(outPos.isValidCoordinate, isFalse);
      expect(outPos.hasCoordinates, isFalse);
    });

    test('ProtrackDevicePosition missing gpsTime does not default to now', () {
      final json = {
        'imei': '861234567890123',
        'latitude': 21.1702,
        'longitude': 72.8311,
        'gpstime': 0,
      };
      final pos = ProtrackDevicePosition.fromJson(json);
      expect(pos.gpsTime, isNull);
    });

    test('isValidImei validates strict 15-digit format', () {
      expect(ProtrackGpsService.isValidImei('355139082439925'), isTrue);
      expect(ProtrackGpsService.isValidImei('12345'), isFalse);
      expect(ProtrackGpsService.isValidImei('35513908243992a'), isFalse);
      expect(ProtrackGpsService.isValidImei(''), isFalse);
    });

    test('login with mock client returns disabled when proxy not configured',
        () async {
      final service = ProtrackGpsService.instance;

      final result = await service.login(
        account: 'fleet_admin',
        password: 'password123',
      );

      expect(result['success'], isFalse);
      expect(result['message'], contains('Direct tracker credentials are disabled'));
      expect(service.debugAccessToken, isNull);
    });

    test('concurrent login calls single-flight to avoid redundant executions',
        () async {
      final service = ProtrackGpsService.instance;

      final results = await Future.wait([
        service.login(account: 'admin', password: 'pwd'),
        service.login(account: 'admin', password: 'pwd'),
      ]);

      expect(results[0]['success'], isFalse);
      expect(results[1]['success'], isFalse);
      expect(service.debugAccessToken, isNull);
    });

    test('credential update does not store vendor credentials on the client', () async {
      final service = ProtrackGpsService.instance;
      service.configureCredentials(
          account: 'initial_account', password: 'initial_password');

      expect(service.account, isEmpty);
      expect(service.debugAccessToken, isNull);
    });

    test(
        'fetchLiveTrackingResult fails closed when unauthenticated without leaking vendor data',
        () async {
      final service = ProtrackGpsService.instance;

      final result = await service.fetchLiveTrackingResult(
        imeis: ['861234567890123'],
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Protrack credentials not configured'));
    });

    test('fetchLiveTrackingResult handles empty IMEIs gracefully',
        () async {
      final service = ProtrackGpsService.instance;

      final result = await service.fetchLiveTrackingResult(
        imeis: [],
      );

      expect(result.success, isTrue);
      expect(result.positions, isEmpty);
    });

    test('fleet mappings sync and dynamic vehicle assignment', () {
      final service = ProtrackGpsService.instance;
      service.syncFleetMappings({
        'GJ19Y2720': '355139082439925',
        'GJ19J6633': '355710090223244',
      });

      expect(service.vehicleImeiMap['GJ19Y2720'], '355139082439925');
      expect(service.vehicleImeiMap['GJ19J6633'], '355710090223244');

      // Assign dynamic vehicle
      service.assignVehicleImei('GJ19Z0901', '355139084725909');
      expect(service.vehicleImeiMap['GJ19Z0901'], '355139084725909');

      // Clear vehicle mapping
      service.assignVehicleImei('GJ19Z0901', '');
      expect(service.vehicleImeiMap.containsKey('GJ19Z0901'), isFalse);
    });

    test('maskedAccount protects credentials from open display', () {
      final service = ProtrackGpsService.instance;
      service.configureCredentials(account: '8980399775', password: 'secret');
      expect(service.maskedAccount, 'Not Configured');
    });

    test('assignVehicleImei and syncFleetMappings enforce 15-digit IMEI format',
        () {
      final service = ProtrackGpsService.instance;

      // Invalid short IMEI should throw ArgumentError
      expect(
        () => service.assignVehicleImei('TRUCK01', '12345'),
        throwsArgumentError,
      );

      // Invalid non-digit IMEI should throw ArgumentError
      expect(
        () => service.assignVehicleImei('TRUCK02', '12345678901234a'),
        throwsArgumentError,
      );

      // Valid 15-digit IMEI should be accepted
      service.assignVehicleImei('TRUCK03', '861234567890123');
      expect(service.vehicleImeiMap['TRUCK03'], '861234567890123');

      // syncFleetMappings filters out invalid IMEIs
      service.syncFleetMappings({
        'TRUCK04': '861234567890124',
        'TRUCK05': 'invalid_imei',
      });
      expect(service.vehicleImeiMap['TRUCK04'], '861234567890124');
      expect(service.vehicleImeiMap.containsKey('TRUCK05'), isFalse);
    });

    test('clearCachedData clears positions and vehicle mappings', () {
      final service = ProtrackGpsService.instance;
      service.assignVehicleImei('TRUCK01', '861234567890123');
      expect(service.vehicleImeiMap.isNotEmpty, isTrue);

      service.clearCachedData();
      expect(service.vehicleImeiMap.isEmpty, isTrue);
      expect(service.latestPositions.isEmpty, isTrue);
    });
  });
}
