import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/services/ai_vision_service.dart';
import 'package:transport_one/src/widgets/seatbelt_verification_dialog.dart';

void main() {
  group('P0.4 Seatbelt Adversarial & Fail-Closed Robustness Suite', () {
    test('1. Blank and pure-white/black images fail liveness and are rejected',
        () async {
      final pureWhite = Uint8List.fromList(List.filled(5000, 255));
      final pureBlack = Uint8List.fromList(List.filled(5000, 0));

      final whiteResult =
          await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: pureWhite,
        existingRecords: [],
      );
      expect(whiteResult.isApproved, isFalse);
      expect(whiteResult.livenessPassed, isFalse);

      final blackResult =
          await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: pureBlack,
        existingRecords: [],
      );
      expect(blackResult.isApproved, isFalse);
      expect(blackResult.livenessPassed, isFalse);
    });

    test(
        '2. Digital flat screens / map screenshots without cabin entropy fail liveness',
        () async {
      // Synthetic flat screen image with uniform value and 0 variance
      final flatScreen = Uint8List.fromList(List.generate(4000, (i) => 120));
      expect(AiVisionService.instance.checkLiveness(flatScreen), isFalse);

      final res = await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: flatScreen,
        existingRecords: [],
      );
      expect(res.isApproved, isFalse);
      expect(res.message, contains('Liveness check failed'));
    });

    test('3. Replay attack: previously approved photo is rejected on re-use',
        () async {
      final sampleBytes =
          Uint8List.fromList(List.generate(1000, (i) => (i * 31) % 256));
      final priorRecord = SeatbeltRecord(
        id: 'RECORD-PRIOR',
        driverName: 'Sandeep',
        driverId: '6355583474',
        vehicleNumber: 'GJ19Y2720',
        photoBase64: 'data:image/jpeg;base64,${base64Encode(sampleBytes)}',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isApproved: true,
      );

      final replayCheck = AiVisionService.instance.checkIsReplay(
        photoBytes: sampleBytes,
        existingRecords: [priorRecord],
      );
      expect(replayCheck, isTrue);

      final res = await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: sampleBytes,
        existingRecords: [priorRecord],
      );
      expect(res.isApproved, isFalse);
      expect(res.isReplay, isTrue);
      expect(res.message, contains('Replay attack detected'));
    });

    test(
        '4. Fail-closed: offline or unavailable Cloud Function rejects trip authorization',
        () async {
      final samplePhoto =
          Uint8List.fromList(List.generate(1000, (i) => (i * 47) % 256));

      // Mock client that returns 503 or connection timeout
      final offlineClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      // Direct verify with Cloud Function fails closed
      final res = await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: samplePhoto,
        existingRecords: [],
        client: offlineClient,
      );
      expect(res.isApproved, isFalse);
    });

    test(
        '5. Low-confidence response (< 0.80) fails closed even if raw boolean is true',
        () async {
      final samplePhoto =
          Uint8List.fromList(List.generate(1000, (i) => (i * 59) % 256));

      // Backend returns approval but with marginal/low confidence (0.65)
      final lowConfClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'isApproved': true,
            'confidence': 0.65,
            'message': 'Marginal match below threshold',
          }),
          200,
        );
      });

      final aiRes = await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: samplePhoto,
        existingRecords: [],
        client: lowConfClient,
      );
      expect(aiRes.isApproved, isFalse);

      final localRes =
          await SeatbeltVerificationDialog.analyzeSeatbeltImage(samplePhoto);
      expect(localRes.detected, isFalse);
    });

    test('6. Malformed JSON schema response fails closed gracefully', () async {
      final samplePhoto =
          Uint8List.fromList(List.generate(1000, (i) => (i * 71) % 256));

      final malformedClient = MockClient((request) async {
        return http.Response('{"invalidKey": 123}', 200);
      });

      final res = await AiVisionService.instance.verifySeatbeltAndDriver(
        photoBytes: samplePhoto,
        existingRecords: [],
        client: malformedClient,
      );
      expect(res.isApproved, isFalse);
    });
  });
}
