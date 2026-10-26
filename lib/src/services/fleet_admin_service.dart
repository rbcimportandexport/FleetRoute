import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/planner_models.dart';
import 'firebase_auth_service.dart';

class FleetAdminService {
  FleetAdminService._();
  static final FleetAdminService instance = FleetAdminService._();

  static const String endpoint =
      String.fromEnvironment('FLEET_ADMIN_API_URL', defaultValue: '');

  bool get isConfigured => endpoint.isNotEmpty;
  String get _driversEndpoint =>
      '${endpoint.replaceAll(RegExp(r'/+$'), '')}/drivers';

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await FirebaseAuthService.instance.idToken();
    if (token == null || token.isEmpty) {
      throw StateError('Admin authentication required.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> createDriver(
    DriverProfile driver,
    String password, {
    String assignedImei = '',
  }) async {
    if (!isConfigured) {
      // Local/offline standalone mode: allow local state without remote backend
      debugPrint('[FleetAdminService] Standalone mode: Remote driver creation skipped.');
      return;
    }
    final headers = await _authorizedHeaders();
    final response = await http
        .post(
          Uri.parse(_driversEndpoint),
          headers: headers,
          body: jsonEncode({
            'email': driver.email.trim().toLowerCase(),
            'password': password,
            'name': driver.name.trim(),
            'phone': driver.phone.trim(),
            'assignedVehicle': driver.assignedVehicle.trim().toUpperCase(),
            'assignedImei': assignedImei.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Driver account creation failed (${response.statusCode}).');
    }
  }

  Future<void> deleteDriver(String email) async {
    if (!isConfigured) {
      // Local/offline standalone mode: allow local state without remote backend
      debugPrint('[FleetAdminService] Standalone mode: Remote driver deletion skipped.');
      return;
    }
    final headers = await _authorizedHeaders();
    final response = await http
        .delete(
          Uri.parse(_driversEndpoint),
          headers: headers,
          body: jsonEncode({'email': email.trim().toLowerCase()}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Driver account deletion failed (${response.statusCode}).');
    }
  }
}
