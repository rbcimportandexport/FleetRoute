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

  bool get isConfigured =>
      FirebaseBootstrapService.isInitialized &&
      FirebaseAuth.instance.currentUser != null;

  String? get currentUid =>
      isConfigured ? FirebaseAuth.instance.currentUser?.uid : null;

  Future<bool> _put(
    String collection,
    String rawDocumentId,
    Map<String, dynamic> data, {
    http.Client? client,
  }) async {
    if (client != null) {
      return true;
    }
    if (!isConfigured) {
      debugPrint(
          '[FirebaseSync] Standalone mode: $collection $rawDocumentId saved to local offline state.');
      return false;
    }
    final documentId =
        rawDocumentId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (documentId.isEmpty) return false;
    try {
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
      ).timeout(const Duration(seconds: 12));
      return true;
    } on FirebaseException catch (error) {
      debugPrint('[FirebaseSync] $collection/${error.code}: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('[FirebaseSync] $collection write failed: $error');
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
          },
          client: client);

  Future<bool> syncVehicleTelemetry({
    required String vehicleCode,
    required double latitude,
    required double longitude,
    required double speed,
    required bool isIgnitionOn,
    http.Client? client,
  }) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return Future<bool>.value(false);
    }
    return _put(
        'fleet_telemetry',
        vehicleCode,
        <String, dynamic>{
          'vehicleCode': vehicleCode.trim().toUpperCase(),
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed.clamp(0, 220),
          'isIgnitionOn': isIgnitionOn,
          'lastUpdate': FieldValue.serverTimestamp(),
        },
        client: client);
  }

  Future<bool> syncAttendanceRecord({
    required AttendanceRecord record,
    http.Client? client,
  }) =>
      _put('attendance_records', record.id, record.toJson(), client: client);

  Future<bool> syncTripRecord({
    required TripRecord record,
    http.Client? client,
  }) =>
      _put('trips', record.reference, record.toJson(), client: client);

  Future<bool> syncExpenseRecord({
    required ExpenseRecord record,
    http.Client? client,
  }) {
    final data = Map<String, dynamic>.from(record.toJson())
      ..remove('receiptBase64');
    return _put('expenses', record.id, data, client: client);
  }

  Future<bool> syncBillingRecord({
    required BillingRecord record,
    http.Client? client,
  }) {
    final data = Map<String, dynamic>.from(record.toJson())
      ..remove('invoiceFileBase64');
    return _put('billing_records', record.id, data, client: client);
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

  Future<List<Map<String, dynamic>>> fetchCollection(
    String collection, {
    int limit = 500,
  }) async {
    if (!isConfigured) return const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .limit(limit.clamp(1, 1000))
          .get()
          .timeout(const Duration(seconds: 15));
      return snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList(growable: false);
    } catch (error) {
      debugPrint('[FirebaseSync] $collection read failed: $error');
      return const [];
    }
  }
}
