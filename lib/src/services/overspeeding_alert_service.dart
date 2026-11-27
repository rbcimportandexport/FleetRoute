import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planner_models.dart';
import 'reverse_geocoding_service.dart';
import 'safety_notification_service.dart';
import 'firebase_backend_service.dart';

class OverspeedingAlertService {
  OverspeedingAlertService._();
  static final OverspeedingAlertService instance = OverspeedingAlertService._();

  DateTime? _lastAlertTime;
  String _lastRoadType = 'गली/लोकल रोड (City/Street)';
  int _consecutiveOverspeedCount = 0;
  DateTime? _lastOverspeedCheckTime;

  /// Evaluates current speed against contextual road limits:
  /// - Highway (NH/SH/Expressway): Limit is 110 km/h (Alert at 110+)
  /// - Gali/City/Local Road: Limit is 90 km/h (Alert at 90+)
  ///
  /// Sends instant push notification to driver & registers high-priority overspeed alert for Admin!
  Future<void> checkSpeed({
    required double speedKmh,
    required LatLng location,
    required String vehicleCode,
    required String driverName,
  }) async {
    // Discard glitch speeds (> 120 km/h is impossible/glitch for a loaded commercial truck, and < 75 km/h is normal)
    if (speedKmh < 75.0 || speedKmh > 120.0) {
      _consecutiveOverspeedCount = 0;
      return; // Ignore normal or glitch speeds
    }

    // 1. Determine road type (Highway vs Gali/City Road)
    bool isHighway = false;
    try {
      final address = await ReverseGeocodingService.addressFor(location);
      if (address != null && address.isNotEmpty) {
        final lower = address.toLowerCase();
        if (lower.contains('nh-') ||
            lower.contains('national highway') ||
            lower.contains('highway') ||
            lower.contains('expressway') ||
            lower.contains('sh-') ||
            lower.contains('state highway') ||
            lower.contains('bypass') ||
            lower.contains('toll plaza')) {
          isHighway = true;
          _lastRoadType = 'हाईवे / एक्सप्रेसवे (Highway)';
        } else {
          isHighway = false;
          _lastRoadType = 'गली / लोकल रोड (Street/City)';
        }
      }
    } catch (_) {}

    final speedLimit = isHighway ? 110.0 : 90.0;

    if (speedKmh >= speedLimit) {
      final now = DateTime.now();
      
      // Must sustain overspeeding over at least 3 consecutive telemetry readings
      // spaced over at least 6-8 seconds to eliminate GPS single/double-spike glitches
      if (_lastOverspeedCheckTime != null &&
          now.difference(_lastOverspeedCheckTime!).inSeconds <= 8 &&
          now.difference(_lastOverspeedCheckTime!).inSeconds >= 1) {
        _consecutiveOverspeedCount++;
      } else {
        _consecutiveOverspeedCount = 1;
      }
      _lastOverspeedCheckTime = now;

      if (_consecutiveOverspeedCount < 3) {
        // Wait for 3 sustained consecutive readings to confirm genuine high speed
        return;
      }

      // Throttle alerts so driver/admin phone isn't flooded (at most once every 60 seconds)
      if (_lastAlertTime != null && now.difference(_lastAlertTime!).inSeconds < 60) {
        return;
      }
      _lastAlertTime = now;

      final roundedSpeed = speedKmh.toStringAsFixed(1);
      final roadLabel = isHighway ? 'हाईवे (NH/Expressway)' : 'गली / लोकल एरिया';
      const title = '🚨 ओवरस्पीडिंग चेतावनी (Overspeeding Alert)!';
      final body = 'गाड़ी: $vehicleCode | ड्राइवर: $driverName\n'
          'स्पीड: $roundedSpeed km/h ($roadLabel पर लिमिट: ${speedLimit.toInt()} km/h)\n'
          '⚠️ गाड़ी की गति तुरंत धीमी करें! यह अलर्ट एडमिन को भेज दिया गया है।';

      // 1. Send native push notification with sound & vibration to Driver & Admin
      SafetyNotificationService.notifyDriverSafety(
        title: title,
        body: body,
        isRejected: true,
      );

      // 2. Broadcast and save alert in Firebase and local storage so Admin Dashboard receives live alert immediately
      try {
        final alert = OperationsAlert(
          id: 'OVERSPEED_${now.millisecondsSinceEpoch}',
          title: '🚨 ओवरस्पीडिंग अलर्ट: $vehicleCode ($roundedSpeed km/h)',
          details: 'ड्राइवर $driverName ने $_lastRoadType पर ${speedLimit.toInt()} km/h की गति सीमा पार की! तुरंत गति नियंत्रित करें।',
          category: 'safety',
          createdAt: now.toIso8601String(),
          severity: 'critical',
          vehicleNumber: vehicleCode,
          location: roadLabel,
        );

        await FirebaseBackendService.instance.syncOperationsAlert(alert: alert);

        // Store latest overspeed alert in SharedPreferences for instant UI display
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('latest_overspeed_alert', 
            'गाड़ी $vehicleCode ने $_lastRoadType पर $roundedSpeed km/h (लिमिट ${speedLimit.toInt()} km/h) पार की!');
      } catch (e) {
        debugPrint('[OverspeedingAlertService] Error logging to Firebase: $e');
      }
    }
  }

  /// Trail / Test button trigger to let Admin or Driver test the exact 110+ and 90+ notifications
  Future<void> fireTestOverspeedAlerts() async {
    await SafetyNotificationService.requestPermission();

    final now = DateTime.now();

    // 1. Test Highway 110+ Alert
    const title1 = '🚨 [टेस्ट] ओवरस्पीडिंग अलर्ट (हाईवे 110+ km/h)';
    const body1 = 'गाड़ी: GJ19Y2720 | ड्राइवर: Sandeep\n'
        'स्पीड: 114.5 km/h (हाईवे NH-48 पर लिमिट 110 km/h पार!)\n'
        '⚠️ एडमिन को तुरंत सूचना भेजी गई।';
    SafetyNotificationService.notifyDriverSafety(
      title: title1,
      body: body1,
      isRejected: true,
    );

    unawaited(FirebaseBackendService.instance.syncOperationsAlert(
      alert: OperationsAlert(
        id: 'TEST-SPEED-HW-${now.millisecondsSinceEpoch}',
        title: title1,
        details: body1,
        severity: 'critical',
        createdAt: now.toIso8601String(),
        category: 'overspeeding',
        vehicleNumber: 'GJ19Y2720',
      ),
    ));

    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Test Gali / Local Road 90+ Alert
    const title2 = '🚨 [टेस्ट] ओवरस्पीडिंग अलर्ट (गली/लोकल रोड 90+ km/h)';
    const body2 = 'गाड़ी: GJ19Y2720 | ड्राइवर: Sandeep\n'
        'स्पीड: 94.2 km/h (लोकल रोड पर लिमिट 90 km/h पार!)\n'
        '⚠️ तुरंत गति धीमी करें। एडमिन को अलर्ट भेजा गया।';
    SafetyNotificationService.notifyDriverSafety(
      title: title2,
      body: body2,
      isRejected: true,
    );

    unawaited(FirebaseBackendService.instance.syncOperationsAlert(
      alert: OperationsAlert(
        id: 'TEST-SPEED-LOC-${now.millisecondsSinceEpoch + 1}',
        title: title2,
        details: body2,
        severity: 'critical',
        createdAt: now.toIso8601String(),
        category: 'overspeeding',
        vehicleNumber: 'GJ19Y2720',
      ),
    ));
  }
}
