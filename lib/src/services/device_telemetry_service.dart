import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads hardware device battery and power telemetry directly from native Android/iOS
/// platform channels using sticky broadcasts without external dependencies or background services.
class DeviceTelemetryService {
  DeviceTelemetryService._();
  static final DeviceTelemetryService instance = DeviceTelemetryService._();

  static const _channel =
      MethodChannel('com.transportone.transport_one/device_telemetry');
  static const _streamChannel =
      EventChannel('com.transportone.transport_one/battery_stream');

  Stream<Map<String, dynamic>>? _batteryStream;

  /// Real-time stream of hardware battery updates (triggers immediately when charger is plugged/unplugged
  /// or when battery percentage changes).
  Stream<Map<String, dynamic>> get batteryStream {
    if (kIsWeb) return const Stream.empty();
    _batteryStream ??= _streamChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) {
            final level = (event['batteryLevel'] as num?)?.toInt() ?? -1;
            final isCharging = event['isCharging'] == true;
            return {
              'batteryLevel': level,
              'isCharging': isCharging,
            };
          }
          return {'batteryLevel': -1, 'isCharging': false};
        })
        .where((data) => (data['batteryLevel'] as int) >= 0);
    return _batteryStream!;
  }

  /// Fetches real device battery percentage (0-100) and whether the phone is plugged into a charger.
  Future<Map<String, dynamic>?> getBatteryInfo() async {
    if (kIsWeb) return null;
    try {
      final res =
          await _channel.invokeMethod<Map<Object?, Object?>>('getBatteryInfo');
      if (res != null) {
        final level = (res['batteryLevel'] as num?)?.toInt() ?? -1;
        final isCharging = res['isCharging'] == true;
        if (level >= 0) {
          return {
            'batteryLevel': level,
            'isCharging': isCharging,
          };
        }
      }
    } catch (e) {
      debugPrint('[DeviceTelemetry] Error reading native battery info: $e');
    }
    return null;
  }
}

