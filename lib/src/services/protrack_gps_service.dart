import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'firebase_auth_service.dart';
import 'package:latlong2/latlong.dart';

double _parseDouble(Object? value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

DateTime? _parseGpsDateTime(Object? value) {
  if (value == null) return null;
  if (value is num) {
    final valInt = value.toInt();
    if (valInt <= 0) return null;
    // Distinguish epoch seconds (10 digits, e.g. ~1776000000) from epoch milliseconds (13 digits)
    if (valInt > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(valInt);
    }
    return DateTime.fromMillisecondsSinceEpoch(valInt * 1000);
  }
  final s = value.toString().trim();
  if (s.isEmpty || s == '0') return null;
  final epoch = int.tryParse(s);
  if (epoch != null && epoch > 0) {
    if (epoch > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
  }
  return DateTime.tryParse(s);
}

/// Represents live telemetry for a GPS tracker from Protrack365 Open API.
class ProtrackDevicePosition {
  const ProtrackDevicePosition({
    required this.imei,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.course,
    required this.gpsTime,
    required this.serverTime,
    this.status = '',
    this.vehicleCode = '',
    this.isIgnitionOn = false,
  });

  final String imei;
  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final DateTime? gpsTime;
  final DateTime serverTime;
  final String status;
  final String vehicleCode;
  final bool isIgnitionOn;

  LatLng get coordinates => LatLng(latitude, longitude);

  bool get isValidCoordinate =>
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0 &&
      (latitude.abs() > 0.0001 || longitude.abs() > 0.0001);

  bool get hasCoordinates => isValidCoordinate;

  bool get hasValidFix => gpsTime != null && isValidCoordinate;

  factory ProtrackDevicePosition.fromJson(
    Map<String, dynamic> json, {
    String vehicleCode = '',
  }) {
    final gpsDt = _parseGpsDateTime(json['gpstime']);
    final srvDt = _parseGpsDateTime(json['servertime']) ?? DateTime.now();

    // Official Protrack API schema uses accstatus (1 = ON, 0 = OFF)
    final accStatusRaw = json['accstatus'];
    final accRaw = json['acc'];
    final statusStr = json['status']?.toString().toLowerCase() ?? '';

    bool ignition = false;
    if (accStatusRaw != null) {
      final s = accStatusRaw.toString().trim();
      ignition = s == '1' || accStatusRaw == 1;
    } else if (accRaw != null) {
      final s = accRaw.toString().trim();
      ignition = s == '1' || accRaw == 1;
    } else {
      ignition = statusStr.contains('acc on') ||
          statusStr.contains('acc:1') ||
          statusStr.contains('moving');
    }

    return ProtrackDevicePosition(
      imei: json['imei']?.toString().trim() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      speed: _parseDouble(json['speed']),
      course: _parseDouble(json['course']),
      gpsTime: gpsDt,
      serverTime: srvDt,
      status: json['status']?.toString() ?? '',
      vehicleCode: vehicleCode,
      isIgnitionOn: ignition,
    );
  }

  Map<String, dynamic> toJson() => {
        'imei': imei,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'course': course,
        if (gpsTime != null) 'gpsTime': gpsTime!.toIso8601String(),
        'serverTime': serverTime.toIso8601String(),
        'status': status,
        'vehicleCode': vehicleCode,
        'isIgnitionOn': isIgnitionOn,
      };
}

/// Structured response from Protrack live tracking API.
class ProtrackFetchResult {
  const ProtrackFetchResult({
    required this.success,
    this.positions = const [],
    this.errorCode,
    this.errorMessage,
    this.isTokenExpired = false,
  });

  final bool success;
  final List<ProtrackDevicePosition> positions;
  final int? errorCode;
  final String? errorMessage;
  final bool isTokenExpired;
}

class ProtrackDevice {
  const ProtrackDevice({
    required this.imei,
    this.name = '',
    this.model = '',
    this.plateNumber = '',
  });

  final String imei;
  final String name;
  final String model;
  final String plateNumber;

  factory ProtrackDevice.fromJson(Map<String, dynamic> json) => ProtrackDevice(
        imei: json['imei']?.toString().trim() ?? '',
        name: json['devicename']?.toString().trim() ?? '',
        model: json['devicetype']?.toString().trim() ?? '',
        plateNumber: json['platenumber']?.toString().trim() ?? '',
      );
}

/// Official Protrack365 Open API Client for live fleet telematics.
class ProtrackGpsService {
  ProtrackGpsService._();
  static final ProtrackGpsService instance = ProtrackGpsService._();

  // Protrack credentials and vendor tokens must stay on the backend.
  static const String proxyUrl =
      String.fromEnvironment('PROTRACK_PROXY_URL', defaultValue: '');

  String _baseUrl = proxyUrl;
  String? _accessToken;
  String _account = '';

  Future<Map<String, dynamic>>? _loginInFlight;

  // Vehicle code to IMEI map
  final Map<String, String> _vehicleImeiMap = {};

  // Cached positions
  final Map<String, ProtrackDevicePosition> _latestPositions = {};

  bool get isConfigured => proxyUrl.isNotEmpty;
  bool get isAuthenticated => proxyUrl.isNotEmpty;

  String get account => _account;

  String get maskedAccount {
    if (proxyUrl.isNotEmpty) return 'Backend Proxy Active';
    if (_account.isEmpty) return 'Not Configured';
    if (_account.length <= 4) return '****';
    return '${_account.substring(0, 3)}****${_account.substring(_account.length - 3)}';
  }

  @visibleForTesting
  String? get debugAccessToken => _accessToken;

  Map<String, String> get vehicleImeiMap => Map.unmodifiable(_vehicleImeiMap);
  Map<String, ProtrackDevicePosition> get latestPositions =>
      Map.unmodifiable(_latestPositions);

  static bool isValidImei(String imei) {
    final clean = imei.trim();
    return RegExp(r'^\d{15}$').hasMatch(clean);
  }

  void configureCredentials({
    required String account,
    required String password,
    String? baseUrl,
  }) {
    // Intentionally do not retain credentials supplied by UI. Direct vendor
    // authentication would expose them in memory/web builds and bypass the
    // backend's access control and rate limiting.
    _account = '';
    _accessToken = null;
    _latestPositions.clear();
  }

  void resetToDefaults() {
    _baseUrl = proxyUrl;
    _account = '';
    _accessToken = null;
    _loginInFlight = null;
    _vehicleImeiMap.clear();
    _latestPositions.clear();
  }

  void assignVehicleImei(String vehicleCode, String imei) {
    final cleanCode =
        vehicleCode.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    final cleanImei = imei.trim();
    if (cleanImei.isEmpty) {
      _vehicleImeiMap.remove(cleanCode);
      return;
    }
    if (!isValidImei(cleanImei)) {
      throw ArgumentError('Invalid IMEI: must be a 15-digit number.');
    }
    _vehicleImeiMap[cleanCode] = cleanImei;
  }

  void syncFleetMappings(Map<String, String> codeToImei) {
    _vehicleImeiMap.clear();
    for (final entry in codeToImei.entries) {
      final cleanCode =
          entry.key.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
      final cleanImei = entry.value.trim();
      if (cleanImei.isNotEmpty && isValidImei(cleanImei)) {
        _vehicleImeiMap[cleanCode] = cleanImei;
      }
    }
  }

  void clearCachedData() {
    _vehicleImeiMap.clear();
    _latestPositions.clear();
  }

  /// Calculates the MD5 encrypted signature required by Protrack Open API:
  /// formula: md5(md5(password) + time)
  static String generateSignature(String password, int timestampSeconds) {
    final firstPass =
        md5.convert(utf8.encode(password.trim())).toString().toLowerCase();
    final combined = '$firstPass$timestampSeconds';
    return md5.convert(utf8.encode(combined)).toString().toLowerCase();
  }

  /// Authenticates with Protrack365 and retrieves access_token.
  /// Prevents concurrent login requests from invalidating each other.
  Future<Map<String, dynamic>> login({
    String? account,
    String? password,
    http.Client? client,
  }) async {
    if (_loginInFlight != null) {
      return await _loginInFlight!;
    }

    final completer = Completer<Map<String, dynamic>>();
    _loginInFlight = completer.future;

    try {
      final res = await _performLogin(
        account: account,
        password: password,
        client: client,
      );
      completer.complete(res);
      return res;
    } catch (e) {
      final err = {
        'success': false,
        'message': 'Protrack connection failed: $e',
      };
      completer.complete(err);
      return err;
    } finally {
      _loginInFlight = null;
    }
  }

  Future<Map<String, dynamic>> _performLogin({
    String? account,
    String? password,
    http.Client? client,
  }) async {
    if (proxyUrl.isEmpty) {
      return {
        'success': false,
        'message':
            'Secure Protrack proxy is not configured. Direct tracker credentials are disabled.',
      };
    }
    return {
      'success': true,
      'account': maskedAccount,
      'expiresIn': 86400,
      'message': 'Protrack proxy active.',
    };

    /* Direct Protrack authorization removed from executable code.
    final effectiveAccount = (account ?? _account).trim();
    final effectivePassword = (password ?? _password).trim();

    if (effectiveAccount.isEmpty || effectivePassword.isEmpty) {
      return {
        'success': false,
        'message': 'Protrack account username aur password configure karein.',
      };
    }

    final timestampSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signature = generateSignature(effectivePassword, timestampSeconds);

    final url = Uri.parse('REMOVED_DIRECT_ENDPOINT');

    final httpClient = client ?? http.Client();
    try {
      final response =
          await httpClient.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Protrack server error (HTTP ${response.statusCode})',
        };
      }

      final dynamic data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Invalid JSON response from Protrack server.',
        };
      }

      final code = data['code'];
      final bool isSuccess = code == 0 || code == '0';
      if (isSuccess && data['record'] != null) {
        final record = data['record'];
        final token = record['access_token']?.toString() ?? '';
        final expRaw = record['expires_in'];
        final int expiresIn = expRaw is num
            ? expRaw.toInt()
            : (expRaw is String ? int.tryParse(expRaw.trim()) ?? 7200 : 7200);

        _account = effectiveAccount;
        _password = effectivePassword;
        _accessToken = token;
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: max(60, expiresIn - 60)));

        return {
          'success': true,
          'account': maskedAccount,
          'expiresIn': expiresIn,
          'message': 'Protrack account successfully connect ho gaya!',
        };
      } else {
        final errorMsg =
            _getProtrackErrorMessage(code, data['message']?.toString());
        return {
          'success': false,
          'code': code,
          'message': errorMsg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Protrack connection failed: $e',
      };
    } finally {
      if (client == null) httpClient.close();
    }
    */
  }

  /// Fetches real-time GPS track position for a list of IMEIs with structured diagnostics.
  Future<ProtrackFetchResult> fetchLiveTrackingResult({
    List<String>? imeis,
    http.Client? client,
    bool autoRetryOnExpiry = true,
  }) async {
    if (imeis != null && imeis.isEmpty) {
      return const ProtrackFetchResult(
        success: true,
        positions: [],
      );
    }
    if (!isAuthenticated) {
      if (!isConfigured) {
        return const ProtrackFetchResult(
          success: false,
          errorMessage: 'Protrack credentials not configured.',
        );
      }
      final authResult = await login(client: client);
      if (authResult['success'] != true) {
        return ProtrackFetchResult(
          success: false,
          errorMessage: authResult['message']?.toString() ?? 'Login failed',
        );
      }
    }

    final targetImeis = (imeis ??
            _vehicleImeiMap.values.where((v) => v.trim().isNotEmpty).toList())
        .map((i) => i.trim())
        .where((i) => i.isNotEmpty)
        .toSet()
        .toList();

    if (targetImeis.isEmpty) {
      return const ProtrackFetchResult(
        success: true,
        positions: [],
      );
    }

    final httpClient = client ?? http.Client();
    final allPositions = <ProtrackDevicePosition>[];
    final idToken = await FirebaseAuthService.instance.idToken();
    if (idToken == null || idToken.isEmpty) {
      if (client == null) httpClient.close();
      return const ProtrackFetchResult(
        success: false,
        errorMessage: 'Authenticated Firebase session required for GPS proxy.',
      );
    }

    final pendingPositions = <String, ProtrackDevicePosition>{};

    try {
      // Protrack Open API max 100 IMEIs per track request
      for (var i = 0; i < targetImeis.length; i += 100) {
        final batch = targetImeis.sublist(i, min(i + 100, targetImeis.length));
        final imeiString = batch.join(',');
        final url = Uri.parse('$_baseUrl/track?imeis=$imeiString');

        final response = await httpClient.get(
          url,
          headers: {'Authorization': 'Bearer $idToken'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          return ProtrackFetchResult(
            success: false,
            errorMessage: 'HTTP ${response.statusCode} from Protrack server',
          );
        }

        final dynamic data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          return const ProtrackFetchResult(
            success: false,
            errorMessage: 'Invalid JSON response received from Protrack API',
          );
        }

        final code = data['code'];
        final bool isSuccess = code == 0 || code == '0';
        if (isSuccess && data['record'] != null) {
          final records = data['record'];
          final List list = records is List ? records : [records];

          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final itemImei = item['imei']?.toString().trim() ?? '';
              final vCode = _vehicleImeiMap.entries
                  .firstWhere(
                    (e) => e.value == itemImei,
                    orElse: () => const MapEntry('', ''),
                  )
                  .key;

              final pos =
                  ProtrackDevicePosition.fromJson(item, vehicleCode: vCode);
              allPositions.add(pos);
              if (vCode.isNotEmpty) {
                pendingPositions[vCode] = pos;
              }
              if (itemImei.isNotEmpty) {
                pendingPositions[itemImei] = pos;
              }
            }
          }
        } else if (code == 10011 ||
            code == 10012 ||
            code == '10011' ||
            code == '10012') {
          _accessToken = null;
          return ProtrackFetchResult(
            success: false,
            errorCode: code is int ? code : int.tryParse(code.toString()),
            errorMessage:
                _getProtrackErrorMessage(code, data['message']?.toString()),
            isTokenExpired: true,
          );
        } else {
          return ProtrackFetchResult(
            success: false,
            errorCode: code is int ? code : int.tryParse(code.toString()),
            errorMessage:
                _getProtrackErrorMessage(code, data['message']?.toString()),
          );
        }
      }

      // Commit cached positions only after all batches succeed atomically
      _latestPositions.addAll(pendingPositions);

      return ProtrackFetchResult(
        success: true,
        positions: allPositions,
      );
    } catch (e) {
      debugPrint('Protrack live tracking polling error: $e');
      return ProtrackFetchResult(
        success: false,
        errorMessage: 'Network error communicating with Protrack API: $e',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<List<ProtrackDevice>> fetchDeviceList({http.Client? client}) async {
    if (!isConfigured) {
      throw StateError('Secure Protrack proxy is not configured.');
    }
    final idToken = await FirebaseAuthService.instance.idToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
          'Authenticated Firebase session required for GPS proxy.');
    }
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(
        Uri.parse('$_baseUrl/devices'),
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        String detail = '';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map) detail = errorBody['error']?.toString() ?? '';
        } catch (_) {}
        final message = switch (detail) {
          'PROTRACK_OPEN_API_DISABLED' =>
            'Protrack Open API disabled hai. Dealer/support se Open API enable karwayein.',
          'PROTRACK_INVALID_CREDENTIALS' =>
            'Protrack account ya password galat hai.',
          _ => 'Device list server error (HTTP ${response.statusCode}).',
        };
        throw StateError(message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          (decoded['code'] != 0 && decoded['code'] != '0')) {
        throw StateError(_getProtrackErrorMessage(
          decoded is Map ? decoded['code'] : null,
          decoded is Map ? decoded['message']?.toString() : null,
        ));
      }
      final records = decoded['record'];
      final list =
          records is List ? records : (records == null ? const [] : [records]);
      return list
          .whereType<Map>()
          .map((item) =>
              ProtrackDevice.fromJson(Map<String, dynamic>.from(item)))
          .where((device) => isValidImei(device.imei))
          .toList(growable: false);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Fetches real-time GPS track position for a list of IMEIs.
  Future<List<ProtrackDevicePosition>> fetchLiveTracking({
    List<String>? imeis,
    http.Client? client,
  }) async {
    final result = await fetchLiveTrackingResult(
      imeis: imeis,
      client: client,
    );
    return result.positions;
  }

  static String _getProtrackErrorMessage(Object? code, String? serverMsg) {
    final parsed = code is int ? code : int.tryParse(code?.toString() ?? '');
    return switch (parsed) {
      10001 => 'Protrack parameter error: Anugya nahi hai',
      10003 => 'Protrack session expired: Kripya login karein',
      10004 => 'Protrack signature galat hai: Password ya time check karein',
      10005 => 'Protrack account ya password galat hai',
      10007 =>
        'Protrack Open API access disabled hai. GPS Dealer se "Enable Open API" on karwayein.',
      10011 => 'Protrack access token invalid hai',
      10012 => 'Protrack access token expire ho gaya hai',
      10013 => 'IMEI number is account par authorized nahi hai',
      _ => serverMsg ?? 'Protrack error code: $code',
    };
  }
}
