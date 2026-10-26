import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WhatsAppOtpService {
  WhatsAppOtpService._();
  static final WhatsAppOtpService instance = WhatsAppOtpService._();

  static const String _baseUrl = String.fromEnvironment(
    'WHATSAPP_OTP_API_URL',
    defaultValue: 'https://transport-one-otp.transport-one-rbc.workers.dev',
  );

  bool get hasApiKey => _baseUrl.startsWith('https://');
  String templateName = 'transport_auth_otp';

  void configure({required String key, String? template}) {
    if (template != null && template.trim().isNotEmpty) {
      templateName = template.trim();
    }
  }

  void reset() {}

  String? getTenDigitPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return digits;
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      final value = digits.substring(1);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return value;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final value = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return value;
    }
    return null;
  }

  String cleanPhone(String raw) {
    final phone = getTenDigitPhone(raw);
    return phone == null ? '' : '+91$phone';
  }

  @visibleForTesting
  Future<Map<String, dynamic>> Function(String phoneNumber)? testSendOtpHandler;
  @visibleForTesting
  Future<Map<String, dynamic>> Function(String phoneNumber, String otp)?
      testVerifyOtpHandler;
  @visibleForTesting
  String? Function(String phoneNumber, String enteredOtp)?
      testVerifyOtpAndGetProofHandler;
  @visibleForTesting
  bool Function(String phoneNumber, String token)? testVerifyProofTokenHandler;

  Future<Map<String, dynamic>> _post(String path, Map<String, String> body,
      {http.Client? client}) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient
          .post(Uri.parse('$_baseUrl$path'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return const {
        'success': false,
        'message': 'OTP server returned an invalid response.'
      };
    } catch (_) {
      return const {
        'success': false,
        'message': 'OTP server se connection nahi hua. Internet check karein.'
      };
    } finally {
      if (client == null) activeClient.close();
    }
  }

  Future<Map<String, dynamic>> sendOtp(
      {required String phoneNumber, http.Client? client}) async {
    if (testSendOtpHandler != null) return testSendOtpHandler!(phoneNumber);
    final phone = getTenDigitPhone(phoneNumber);
    if (phone == null) {
      return const {
        'success': false,
        'message': 'Valid 10-digit mobile number enter karein.'
      };
    }
    return _post('/send', {'phoneNumber': phone}, client: client);
  }

  Future<Map<String, dynamic>> verifyOtpRemote(
      {required String phoneNumber,
      required String enteredOtp,
      http.Client? client}) async {
    if (testVerifyOtpHandler != null) {
      return testVerifyOtpHandler!(phoneNumber, enteredOtp);
    }
    final phone = getTenDigitPhone(phoneNumber);
    if (phone == null || !RegExp(r'^\d{6}$').hasMatch(enteredOtp.trim())) {
      return const {
        'success': false,
        'message': 'Valid phone aur 6-digit OTP enter karein.'
      };
    }
    return _post('/verify', {'phoneNumber': phone, 'otp': enteredOtp.trim()},
        client: client);
  }

  bool verifyOtp({required String phoneNumber, required String enteredOtp}) =>
      false;
  String? verifyOtpAndGetProof(
          {required String phoneNumber, required String enteredOtp}) =>
      testVerifyOtpAndGetProofHandler?.call(phoneNumber, enteredOtp);
  bool verifyProofToken(String phoneNumber, String token) =>
      testVerifyProofTokenHandler?.call(phoneNumber, token) ?? false;
  @visibleForTesting
  String generateProofToken(String phoneNumber) =>
      'test_proof_token_$phoneNumber';
}
