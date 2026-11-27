import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planner_models.dart';
import 'firebase_backend_service.dart';
import 'safety_notification_service.dart';

class ExpiryDocItem {
  const ExpiryDocItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.expiryDate,
    required this.icon,
    required this.color,
    this.targetVehicle = 'GJ19Y2720',
    this.targetDriver = 'Sandeep',
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime expiryDate;
  final IconData icon;
  final Color color;
  final String targetVehicle;
  final String targetDriver;

  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysLeft <= 0;
  bool get isDueWithinMonth => daysLeft <= 30;
}

class DocumentExpiryReminderService {
  DocumentExpiryReminderService._();
  static final DocumentExpiryReminderService instance = DocumentExpiryReminderService._();

  Timer? _dailyTimer;

  // Track document expiry dates (saved in SharedPreferences)
  static final List<ExpiryDocItem> defaultDocuments = [
    ExpiryDocItem(
      id: 'driver_license',
      title: 'ड्राइविंग लाइसेंस (DL)',
      subtitle: 'ड्राइवर Sandeep का ड्राइविंग लाइसेंस',
      expiryDate: DateTime.now().add(const Duration(days: 22)), // 22 din baaki
      icon: Icons.badge_rounded,
      color: const Color(0xFF2563EB),
      targetDriver: 'Sandeep',
    ),
    ExpiryDocItem(
      id: 'vehicle_fitness',
      title: 'गाड़ी फिटनेस प्रमाण पत्र (Fitness)',
      subtitle: 'गाड़ी GJ19Y2720 का RTO फिटनेस',
      expiryDate: DateTime.now().add(const Duration(days: 15)), // 15 din baaki
      icon: Icons.verified_rounded,
      color: const Color(0xFF16A34A),
      targetVehicle: 'GJ19Y2720',
    ),
    ExpiryDocItem(
      id: 'vehicle_insurance',
      title: 'गाड़ी इंश्योरेंस (Insurance Policy)',
      subtitle: 'पॉलिसी New India Assurance (#POL-849201)',
      expiryDate: DateTime.now().add(const Duration(days: 9)), // 9 din baaki
      icon: Icons.security_rounded,
      color: const Color(0xFFEA580C),
      targetVehicle: 'GJ19Y2720',
    ),
    ExpiryDocItem(
      id: 'vehicle_puc',
      title: 'प्रदूषण जांच (PUC Certificate)',
      subtitle: 'गाड़ी GJ19Y2720 का पर्यावरण प्रदूषण प्रमाण पत्र',
      expiryDate: DateTime.now().add(const Duration(days: 18)), // 18 din baaki
      icon: Icons.eco_rounded,
      color: const Color(0xFF0D9488),
      targetVehicle: 'GJ19Y2720',
    ),
    ExpiryDocItem(
      id: 'national_permit',
      title: 'नेशनल परमिट (All India Permit)',
      subtitle: 'गाड़ी GJ19Y2720 नेशनल गुड्स परमिट',
      expiryDate: DateTime.now().add(const Duration(days: 28)), // 28 din baaki
      icon: Icons.document_scanner_rounded,
      color: const Color(0xFF7C3AED),
      targetVehicle: 'GJ19Y2720',
    ),
    ExpiryDocItem(
      id: 'rc_registration',
      title: 'गाड़ी आरसी (RC Registration)',
      subtitle: 'गाड़ी GJ19Y2720 स्मार्ट रजिस्ट्रेशन कार्ड',
      expiryDate: DateTime.now().add(const Duration(days: 45)), // 45 din baaki
      icon: Icons.credit_card_rounded,
      color: const Color(0xFF0284C7),
      targetVehicle: 'GJ19Y2720',
    ),
  ];

  /// Initialize and start the daily 3-time notification schedule
  Future<void> initialize() async {
    await SafetyNotificationService.requestPermission();
    _checkAndSendNotifications();
    // Check every 4 hours in app lifecycle to ensure 3 times daily alerts
    _dailyTimer?.cancel();
    _dailyTimer = Timer.periodic(const Duration(hours: 4), (_) {
      _checkAndSendNotifications();
    });
  }

  /// Check all documents and trigger notifications for anything expiring in <= 30 days
  Future<void> _checkAndSendNotifications() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    final slot = now.hour < 12 ? 'morning' : (now.hour < 17 ? 'afternoon' : 'evening');
    final sentKey = 'notif_sent_${todayStr}_$slot';

    if (prefs.getBool(sentKey) == true) {
      return; // Already sent for this time slot today
    }

    final docs = await getAllDocuments();
    for (final doc in docs) {
      if (doc.isDueWithinMonth) {
        final days = doc.daysLeft;
        final urgency = days <= 5 ? '🚨 अंतिम चेतावनी (Urgent):' : '⚠️ ध्यान दें (Reminder):';
        final title = '$urgency ${doc.title} रिन्यूअल बाक़ी!';
        final body = '${doc.subtitle}\n'
            'यह दस्तावेज़ ${days <= 0 ? 'आज समाप्त हो चुका है' : '$days दिन में समाप्त हो जाएगा'}। कृपया तुरंत रिन्यू या अपडेट करें।';
        SafetyNotificationService.notifyDriverSafety(
          title: title,
          body: body,
          isRejected: days <= 5,
        );
      }
    }
    await prefs.setBool(sentKey, true);
  }

  /// Get current documents list (with any user updated dates)
  Future<List<ExpiryDocItem>> getAllDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <ExpiryDocItem>[];
    for (final doc in defaultDocuments) {
      final savedEpoch = prefs.getInt('doc_expiry_${doc.id}');
      if (savedEpoch != null) {
        list.add(ExpiryDocItem(
          id: doc.id,
          title: doc.title,
          subtitle: doc.subtitle,
          expiryDate: DateTime.fromMillisecondsSinceEpoch(savedEpoch),
          icon: doc.icon,
          color: doc.color,
          targetVehicle: doc.targetVehicle,
          targetDriver: doc.targetDriver,
        ));
      } else {
        list.add(doc);
      }
    }
    return list;
  }

  /// Update document expiry date (e.g. after uploading new doc or manual update)
  Future<void> updateDocumentExpiry(String docId, DateTime newExpiryDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('doc_expiry_$docId', newExpiryDate.millisecondsSinceEpoch);
  }

  /// Trail / Test Notifications: Fires all notifications right now so user can see them
  Future<int> fireTrailNotifications() async {
    await SafetyNotificationService.requestPermission();
    final docs = await getAllDocuments();
    int count = 0;
    for (final doc in docs) {
      if (doc.isDueWithinMonth) {
        count++;
        final days = doc.daysLeft;
        final title = '🔔 [ट्रायल] ${doc.title} - $days दिन बाक़ी!';
        final body = '${doc.subtitle}\n'
            'एक्सपायरी: ${doc.expiryDate.day}/${doc.expiryDate.month}/${doc.expiryDate.year} | रोज़ाना 3 बार नोटिफिकेशन अलार्म सेट है।';
        SafetyNotificationService.notifyDriverSafety(
          title: title,
          body: body,
          isRejected: days <= 10,
        );

        // Broadcast to Firestore 'operations_alerts' so EVERY phone & admin console receives it live!
        unawaited(FirebaseBackendService.instance.syncOperationsAlert(
          alert: OperationsAlert(
            id: 'TRIAL-DOC-${doc.id}-${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            details: body,
            severity: days <= 10 ? 'critical' : 'warning',
            createdAt: DateTime.now().toIso8601String(),
            category: 'compliance',
            vehicleNumber: doc.targetVehicle,
          ),
        ));

        // Small stagger to let Android notification tray show all of them
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return count;
  }
}
