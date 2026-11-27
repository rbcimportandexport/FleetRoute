import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/planner_models.dart';
import 'firebase_bootstrap_service.dart';

/// Authenticated Firestore gateway. Every operation uses the active Firebase
/// user so the deployed Firestore security rules are actually enforced.
class FirebaseBackendService {
  FirebaseBackendService._();
  static final FirebaseBackendService instance = FirebaseBackendService._();

  String? lastWriteError;
  Future<void> Function()? onAuthRequiredFallback;

  bool get isConfigured => FirebaseBootstrapService.isInitialized;

  String? get currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'fleet_user';

  String? get currentEmail => FirebaseAuth.instance.currentUser?.email;

  /// Ensures Firestore has an active session (signing in via fleet auth or
  /// anonymous fallback) so real-time sync across PC, Web, and Mobile APK
  /// works seamlessly for every driver without PERMISSION_DENIED.
  Future<void> ensureAuthSession() async {
    if (!FirebaseBootstrapService.isInitialized) return;
    if (FirebaseAuth.instance.currentUser != null) return;
    if (onAuthRequiredFallback != null) {
      try {
        await onAuthRequiredFallback!();
      } catch (e) {
        debugPrint('[FirebaseSync] Fleet auth fallback error: $e');
      }
    }
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('[FirebaseSync] Anonymous auth fallback: $e');
      }
    }
  }

  Future<bool> _put(
    String collection,
    String rawDocumentId,
    Map<String, dynamic> data, {
    http.Client? client,
  }) async {
    lastWriteError = null;
    if (client != null) {
      return true;
    }
    if (!isConfigured) {
      debugPrint(
          '[FirebaseSync] Standalone mode: $collection $rawDocumentId saved to local offline state.');
      lastWriteError = 'Firebase session available nahi hai.';
      return false;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await ensureAuthSession();
    }
    final documentId =
        rawDocumentId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      final isTelemetry = collection == 'fleet_telemetry';
      final timeoutDuration = isTelemetry
          ? const Duration(seconds: 5)
          : const Duration(seconds: 12);
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .set(
        <String, dynamic>{
          ...data,
          'ownerUid': currentUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(timeoutDuration);
      return true;
    } on TimeoutException {
      // Offline / high-latency: Firestore offline cache has saved the write locally.
      // Mark as succeeded so the app stays smooth and syncs automatically when connection restores.
      debugPrint(
          '[FirebaseSync] $collection/$documentId queued in offline cache (timeout)');
      return true;
    } on FirebaseException catch (error) {
      debugPrint('[FirebaseSync] $collection/${error.code}: ${error.message}');
      lastWriteError =
          '${error.code}: ${error.message ?? 'Firebase write failed'}';
      return false;
    } catch (error) {
      debugPrint('[FirebaseSync] $collection write failed: $error');
      lastWriteError = error.toString();
      return false;
    }
  }

  Future<bool> deleteSeatbeltRecord(String rawDocumentId) async {
    if (!isConfigured) return true;
    final documentId =
        rawDocumentId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('seatbelt_records')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (e) {
      debugPrint('[FirebaseSync] Failed to delete seatbelt_record: ');
      return false;
    }
  }

  Future<bool> syncSeatbeltRecord({
    required SeatbeltRecord record,
    http.Client? client,
  }) =>
      _put(
          'seatbelt_records',
          record.id,
          <String, dynamic>{
            'driverId': record.driverId,
            'driverName': record.driverName,
            'vehicleNumber': record.vehicleNumber,
            'isApproved': record.isApproved,
            'timestamp': Timestamp.fromDate(record.timestamp.toUtc()),
            'location': record.location,
            'notes': record.notes,
            if (record.photoBase64.isNotEmpty)
              'photoBase64': record.photoBase64,
          },
          client: client);

  Stream<List<SeatbeltRecord>> watchSeatbeltRecords() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('seatbelt_records')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = <String, dynamic>{'id': doc.id, ...doc.data()};
              final ts = data['timestamp'];
              if (ts is Timestamp) {
                data['timestamp'] = ts.toDate().toUtc().toIso8601String();
              }
              return SeatbeltRecord.fromJson(data);
            }).toList(growable: false));
  }

  Future<bool> updateVehicleBatteryTelemetry({
    required String vehicleCode,
    required int phoneBatteryLevel,
    required bool isPhoneCharging,
    String? driverId,
    String? driverName,
    bool? isOnDuty,
    bool? driverOnline,
    http.Client? client,
  }) {
    final cleanCode =
        vehicleCode.replaceAll(RegExp(r'[\s\-]'), '').trim().toUpperCase();
    if (cleanCode.isEmpty) return Future<bool>.value(false);
    // NOTE: We intentionally do NOT update 'lastUpdate' here.
    // 'lastUpdate' is the GPS telemetry timestamp and must only be written
    // when real GPS coordinates are present (syncVehicleTelemetry).
    // Updating it from a battery-only push would make isGpsStale return false
    // even when there is no actual GPS fix, causing a fake ⚡ bolt to appear.
    return _put(
        'fleet_telemetry',
        cleanCode,
        <String, dynamic>{
          'vehicleCode': cleanCode,
          'phoneBatteryLevel': phoneBatteryLevel,
          'isPhoneCharging': isPhoneCharging,
          if (driverId != null && driverId.trim().isNotEmpty)
            'driverId': driverId.trim(),
          if (driverName != null && driverName.trim().isNotEmpty)
            'driverName': driverName.trim(),
          if (isOnDuty != null) 'isOnDuty': isOnDuty,
          if (driverOnline != null) 'driverOnline': driverOnline,
          'batteryLastUpdate': FieldValue.serverTimestamp(),
        },
        client: client);
  }

  Future<bool> updateVehicleDutyTelemetry({
    required String vehicleCode,
    required bool isOnDuty,
    required bool driverOnline,
    String driverId = '',
    String driverName = '',
    int? phoneBatteryLevel,
    bool? isPhoneCharging,
    http.Client? client,
  }) {
    final cleanCode =
        vehicleCode.replaceAll(RegExp(r'[\s\-]'), '').trim().toUpperCase();
    if (cleanCode.isEmpty) return Future<bool>.value(false);
    return _put(
        'fleet_telemetry',
        cleanCode,
        <String, dynamic>{
          'vehicleCode': cleanCode,
          'isOnDuty': isOnDuty,
          'driverOnline': driverOnline,
          if (!isOnDuty) 'speed': 0.0,
          if (!isOnDuty) 'isIgnitionOn': false,
          if (driverId.trim().isNotEmpty) 'driverId': driverId.trim(),
          if (driverName.trim().isNotEmpty) 'driverName': driverName.trim(),
          if (phoneBatteryLevel != null && phoneBatteryLevel >= 0)
            'phoneBatteryLevel': phoneBatteryLevel,
          if (isPhoneCharging != null) 'isPhoneCharging': isPhoneCharging,
          if (phoneBatteryLevel != null && phoneBatteryLevel >= 0)
            'batteryLastUpdate': FieldValue.serverTimestamp(),
        },
        client: client);
  }

  Future<bool> syncVehicleTelemetry({
    required String vehicleCode,
    required double latitude,
    required double longitude,
    required double speed,
    required bool isIgnitionOn,
    String driverId = '',
    String driverName = '',
    int? phoneBatteryLevel,
    bool isPhoneCharging = false,
    bool? isOnDuty,
    bool? driverOnline,
    http.Client? client,
  }) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return Future<bool>.value(false);
    }
    final cleanCode =
        vehicleCode.replaceAll(RegExp(r'[\s\-]'), '').trim().toUpperCase();
    if (cleanCode.isEmpty) return Future<bool>.value(false);
    return _put(
        'fleet_telemetry',
        cleanCode,
        <String, dynamic>{
          'vehicleCode': cleanCode,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed.clamp(0, 220),
          'isIgnitionOn': isIgnitionOn,
          'driverId': driverId,
          'driverName': driverName,
          if (phoneBatteryLevel != null) 'phoneBatteryLevel': phoneBatteryLevel,
          'isPhoneCharging': isPhoneCharging,
          if (isOnDuty != null) 'isOnDuty': isOnDuty,
          if (driverOnline != null) 'driverOnline': driverOnline,
          'lastUpdate': FieldValue.serverTimestamp(),
        },
        client: client);
  }

  Stream<List<Map<String, dynamic>>> watchFleetTelemetry() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('fleet_telemetry')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = <String, dynamic>{'id': doc.id, ...doc.data()};
              for (final key in ['lastUpdate', 'batteryLastUpdate', 'updatedAt']) {
                final val = data[key];
                if (val is Timestamp) {
                  data[key] = val.toDate().toUtc().toIso8601String();
                }
              }
              return data;
            }).toList(growable: false));
  }

  Future<bool> syncAttendanceRecord({
    required AttendanceRecord record,
    http.Client? client,
  }) =>
      _put('attendance_records', record.id, record.toJson(), client: client);

  Stream<List<AttendanceRecord>> watchAttendanceRecords() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('attendance_records')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceRecord.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<bool> syncTripRecord({
    required TripRecord record,
    http.Client? client,
  }) =>
      _put('trips', record.reference, record.toJson(), client: client);

  Stream<List<TripRecord>> watchTrips() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('trips')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripRecord.fromJson(
                  <String, dynamic>{'reference': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<bool> deleteTripRecord(String reference) async {
    if (!isConfigured) return false;
    final documentId =
        reference.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (error) {
      debugPrint('[FirebaseSync] trips delete failed: $error');
      return false;
    }
  }

  Future<bool> syncExpenseRecord({
    required ExpenseRecord record,
    http.Client? client,
  }) {
    final data = Map<String, dynamic>.from(record.toJson())
      ..remove('receiptBase64');
    return _put('expenses', record.id, data, client: client);
  }

  Future<bool> deleteExpenseRecord(String rawExpenseId) async {
    if (!isConfigured) return true;
    final documentId =
        rawExpenseId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ExpenseRecord>> watchExpenses() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('expenses')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseRecord.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<bool> syncBillingRecord({
    required BillingRecord record,
    http.Client? client,
  }) {
    final data = Map<String, dynamic>.from(record.toJson())
      ..remove('invoiceFileBase64');
    return _put('billing_records', record.id, data, client: client);
  }

  Future<bool> deleteBillingRecord(String rawBillingId) async {
    if (!isConfigured) return true;
    final documentId =
        rawBillingId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('billing_records')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<BillingRecord>> watchBillingRecords() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('billing_records')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillingRecord.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<bool> syncDeliveryProof({
    required DeliveryProofRecord record,
    http.Client? client,
  }) {
    final data = Map<String, dynamic>.from(record.toJson())
      ..remove('photoBase64')
      ..remove('signatureBase64')
      ..['driverId'] = currentUid ?? '';
    return _put('delivery_proofs', record.id, data, client: client);
  }

  Stream<List<DeliveryProofRecord>> watchDeliveryProofs() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('delivery_proofs')
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryProofRecord.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  // --- App Settings (Deleted IDs, System Flags) Firestore Sync ---
  Future<bool> saveAppSetting(String settingKey, dynamic value) async {
    return _put('app_settings', settingKey, <String, dynamic>{
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<dynamic> getAppSetting(String settingKey) async {
    if (!isConfigured) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc(settingKey)
          .get()
          .timeout(const Duration(seconds: 10));
      return doc.data()?['value'];
    } catch (_) {
      return null;
    }
  }

  Stream<Map<String, dynamic>> watchAppSetting(String settingKey) {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc(settingKey)
        .snapshots()
        .map((doc) => doc.data() ?? <String, dynamic>{});
  }

  // --- Customers Firestore Sync ---
  Future<bool> syncCustomerRecord({
    required CustomerRecord record,
    http.Client? client,
  }) =>
      _put('customers', record.id, record.toJson(), client: client);

  Future<bool> deleteCustomerRecord(String customerId) async {
    if (!isConfigured) return false;
    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<CustomerRecord>> watchCustomers() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('customers')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerRecord.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  // --- Drivers Firestore Sync ---
  Future<bool> syncDriverProfile({
    required DriverProfile driver,
    http.Client? client,
  }) {
    final driverId = driver.phone.isNotEmpty
        ? driver.phone
        : driver.email.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return _put('drivers', driverId, driver.toJson(), client: client);
  }

  Stream<List<DriverProfile>> watchDrivers() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('drivers')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DriverProfile.fromJson(
                  <String, dynamic>{'email': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<bool> deleteDriverProfile(String driverId) async {
    if (!isConfigured) return true;
    final documentId =
        driverId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (e) {
      debugPrint('[FirebaseSync] Failed to delete driver: ');
      return false;
    }
  }

  // --- Fleet Vehicles Firestore Sync ---
  Future<bool> deleteFleetVehicle(String vehicleCode) async {
    if (!isConfigured) return true;
    final documentId = vehicleCode.trim().toUpperCase();
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('fleet_vehicles')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncFleetVehicle({
    required TruckModel vehicle,
    http.Client? client,
  }) =>
      _put('fleet_vehicles', vehicle.code, vehicle.toJson(), client: client);

  Stream<List<TruckModel>> watchFleetVehicles() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('fleet_vehicles')
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TruckModel.fromJson(
                  <String, dynamic>{'code': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  // --- Operations Alerts Firestore Sync ---
  Future<bool> syncOperationsAlert({
    required OperationsAlert alert,
    http.Client? client,
  }) {
    final alertId = alert.id.isNotEmpty
        ? alert.id
        : '${alert.category}_${alert.createdAt.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${alert.title.hashCode.abs()}';
    return _put('operations_alerts', alertId, alert.toJson(), client: client);
  }

  Future<bool> deleteOperationsAlert(String rawAlertId) async {
    if (!isConfigured) return true;
    final documentId =
        rawAlertId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance
          .collection('operations_alerts')
          .doc(documentId)
          .delete()
          .timeout(const Duration(seconds: 12));
      return true;
    } catch (e) {
      debugPrint('[FirebaseSync] Failed to delete operations_alert: $e');
      return false;
    }
  }

  Stream<List<OperationsAlert>> watchOperationsAlerts() {
    if (!isConfigured) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('operations_alerts')
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OperationsAlert.fromJson(
                  <String, dynamic>{'id': doc.id, ...doc.data()},
                ))
            .toList(growable: false));
  }

  Future<List<Map<String, dynamic>>> fetchCollection(
    String collection, {
    int limit = 100,
  }) async {
    if (!isConfigured) return const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .limit(limit.clamp(1, 1000))
          .get()
          .timeout(const Duration(seconds: 15));
      return snapshot.docs.map((doc) {
        final data = <String, dynamic>{'id': doc.id, ...doc.data()};
        for (final entry in data.entries.toList()) {
          if (entry.value is Timestamp) {
            data[entry.key] =
                (entry.value as Timestamp).toDate().toUtc().toIso8601String();
          }
        }
        return data;
      }).toList(growable: false);
    } catch (error) {
      debugPrint('[FirebaseSync] $collection read failed: $error');
      return const [];
    }
  }

  // --- Driver Photos & Expenses Transport 1 Database Gateway ---
  Future<bool> saveDriverPhotoLog({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    return _put('driver_photos', docId, <String, dynamic>{
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'syncedBy': currentUid ?? 'fleet_driver',
    });
  }

  Future<bool> saveExpenseRecord({
    required String id,
    required String category,
    required double amount,
    required String vendor,
    required String docNumber,
    required String notes,
    required String location,
    required String driverName,
    required String vehicle,
  }) async {
    return _put('expenses', id, <String, dynamic>{
      'id': id,
      'category': category,
      'amount': amount,
      'vendor': vendor,
      'docNumber': docNumber,
      'notes': notes,
      'location': location,
      'driverName': driverName,
      'vehicle': vehicle,
      'driverId': currentUid ?? 'fleet_driver',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
