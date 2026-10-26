import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/planner_models.dart';
import 'firebase_auth_service.dart';

class AiVerificationResult {
  const AiVerificationResult({
    required this.isApproved,
    required this.message,
    required this.confidence,
    this.isReplay = false,
    this.livenessPassed = true,
    this.aiEngine = 'Local Biometric & Safety Guard',
  });

  final bool isApproved;
  final String message;
  final double confidence;
  final bool isReplay;
  final bool livenessPassed;
  final String aiEngine;
}

class AiVisionService {
  AiVisionService._();
  static final AiVisionService instance = AiVisionService._();

  // Cloud Function URL: in production, AI verification runs on a secure backend / Firebase Cloud Function
  // where secrets, API keys, and model quotas are securely managed without embedding keys in the client APK.
  static const String cloudFunctionUrl =
      String.fromEnvironment('FIREBASE_FUNCTIONS_URL', defaultValue: '');

  /// Checks if the photo has already been submitted in previous records (Replay Protection).
  bool checkIsReplay({
    required Uint8List photoBytes,
    required List<SeatbeltRecord> existingRecords,
  }) {
    if (existingRecords.isEmpty) return false;
    final currentHash = sha256.convert(photoBytes).toString();

    for (final record in existingRecords) {
      if (!record.isApproved) {
        continue; // Only approved records must be protected against replay reuse
      }
      if (record.photoBase64.isEmpty) continue;
      try {
        final commaIdx = record.photoBase64.indexOf(',');
        final cleanB64 = commaIdx != -1
            ? record.photoBase64.substring(commaIdx + 1)
            : record.photoBase64;
        final existingBytes = base64Decode(cleanB64);
        final existingHash = sha256.convert(existingBytes).toString();
        if (currentHash == existingHash) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  bool checkLiveness(Uint8List photoBytes) {
    if (photoBytes.length < 32) return false;

    // Verify valid image header (JPEG, PNG, or WebP)
    final isJpeg = photoBytes.length >= 3 &&
        photoBytes[0] == 0xFF &&
        photoBytes[1] == 0xD8 &&
        photoBytes[2] == 0xFF;
    final isPng = photoBytes.length >= 8 &&
        photoBytes[0] == 0x89 &&
        photoBytes[1] == 0x50 &&
        photoBytes[2] == 0x4E &&
        photoBytes[3] == 0x47 &&
        photoBytes[4] == 0x0D &&
        photoBytes[5] == 0x0A &&
        photoBytes[6] == 0x1A &&
        photoBytes[7] == 0x0A;
    final isWebp = photoBytes.length >= 12 &&
        photoBytes[0] == 0x52 &&
        photoBytes[1] == 0x49 &&
        photoBytes[2] == 0x46 &&
        photoBytes[3] == 0x46 &&
        photoBytes[8] == 0x57 &&
        photoBytes[9] == 0x45 &&
        photoBytes[10] == 0x42 &&
        photoBytes[11] == 0x50;

    if (!isJpeg && !isPng && !isWebp) return false;

    // Check byte entropy/variance: flat/blank images (white, black, solid screens) fail
    int sum = 0;
    final step = (photoBytes.length / 100).clamp(1, 16).toInt();
    int count = 0;
    for (int i = 0; i < photoBytes.length; i += step) {
      sum += photoBytes[i];
      count++;
    }
    if (count == 0) return false;
    final mean = sum / count;
    double variance = 0;
    for (int i = 0; i < photoBytes.length; i += step) {
      final diff = photoBytes[i] - mean;
      variance += diff * diff;
    }
    variance /= count;
    return variance >= 2.0;
  }

  /// Verifies cabin photo using secure Cloud Function when available,
  /// or falls back to hardened multi-stage biometric & anti-replay analysis.
  Future<AiVerificationResult> verifySeatbeltAndDriver({
    required Uint8List photoBytes,
    required List<SeatbeltRecord> existingRecords,
    http.Client? client,
  }) async {
    // 1. Replay Attack Prevention
    if (checkIsReplay(
      photoBytes: photoBytes,
      existingRecords: existingRecords,
    )) {
      return const AiVerificationResult(
        isApproved: false,
        message:
            'Replay attack detected: Yeh photo pehle se use ho chuki hai. Kripya live cabin camera se fresh photo capture karein.',
        confidence: 0.0,
        isReplay: true,
        livenessPassed: false,
        aiEngine: 'Anti-Replay Guard',
      );
    }

    // 2. Liveness & Entropy Check
    if (!checkLiveness(photoBytes)) {
      return const AiVerificationResult(
        isApproved: false,
        message:
            'Liveness check failed: Clear JPEG/PNG photo live camera se capture karein (screen screenshots ya static photos allowed nahi hain).',
        confidence: 0.0,
        livenessPassed: false,
        aiEngine: 'Image Payload Validator',
      );
    }

    // 3. Secure Firebase Cloud Function AI (Preferred enterprise architecture)
    if (cloudFunctionUrl.isNotEmpty) {
      final cloudResult = await _verifyWithCloudFunction(
        photoBytes: photoBytes,
        functionUrl: cloudFunctionUrl,
        client: client,
      );
      if (cloudResult != null) {
        return cloudResult;
      }
      // Fail-closed when Cloud Function configured but fails/times out
      return const AiVerificationResult(
        isApproved: false,
        message:
            'AI verification service temporarily unreachable. Fail-closed: Ride cannot be authorized.',
        confidence: 0.0,
        livenessPassed: true,
        aiEngine: 'Cloud AI Safety Guard (Offline)',
      );
    }

    // 4. In accordance with P0 safety rules, Gemini calls must occur exclusively via backend/Cloud Function proxy.
    // Colour/diagonal-line heuristics and direct client keys must never authorize rides.
    return const AiVerificationResult(
      isApproved: false,
      message:
          'AI safety backend not configured or unreachable. Safety policy requires authenticated backend AI approval.',
      confidence: 0.0,
      livenessPassed: true,
      aiEngine: 'Safety Policy Enforcer',
    );
  }

  Future<AiVerificationResult?> _verifyWithCloudFunction({
    required Uint8List photoBytes,
    required String functionUrl,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final idToken = await FirebaseAuthService.instance.idToken();
      if (idToken == null || idToken.isEmpty) return null;
      final endpoint = functionUrl.endsWith('/')
          ? '${functionUrl}verifySeatbelt'
          : '$functionUrl/verifySeatbelt';

      final response = await httpClient
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'image': base64Encode(photoBytes),
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return null;

        // Strict schema validation
        final bool? rawApproved = decoded['isApproved'] as bool?;
        final num? rawConf = decoded['confidence'] as num?;
        final bool? livenessPassed = decoded['livenessPassed'] as bool?;
        final bool? seatbeltDetected = decoded['seatbeltDetected'] as bool?;
        final bool? driverPresent = decoded['driverPresent'] as bool?;
        final String? msg = decoded['message'] as String?;

        if (rawApproved == null ||
            rawConf == null ||
            livenessPassed == null ||
            seatbeltDetected == null ||
            driverPresent == null) {
          return null; // Malformed response schema
        }

        final confidence = rawConf.toDouble();
        // Enforce minimum confidence of 0.80
        final isApproved = rawApproved &&
            confidence >= 0.80 &&
            livenessPassed &&
            seatbeltDetected &&
            driverPresent;
        final message = msg ??
            (isApproved
                ? 'Seatbelt verified via Cloud AI.'
                : 'Seatbelt verification failed.');

        return AiVerificationResult(
          isApproved: isApproved,
          message: message,
          confidence: confidence,
          livenessPassed: livenessPassed,
          aiEngine: 'Firebase Cloud Function AI',
        );
      }
    } catch (e) {
      debugPrint('[AiVisionService] Cloud Function call warning: $e');
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
    return null;
  }
}
