import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';

typedef PhotoPickerHandler = void Function({
  required bool useCamera,
  required void Function(String base64Data) onPhotoSelected,
  void Function(String errorMessage)? onError,
});

typedef NotificationHandler = void Function({
  required String title,
  required String body,
  required bool isRejected,
});

PhotoPickerHandler? _customPhotoPicker;
final List<NotificationHandler> _notificationHandlers = [];
FlutterLocalNotificationsPlugin? _notificationsPlugin;
bool _notificationsInitialized = false;
bool _notificationPermissionRequested = false;
int _nextNotificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);

Future<void> _ensureNotificationsInitialized() async {
  if (_notificationsInitialized) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('ic_stat_transport');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notificationsPlugin?.initialize(settings: initSettings);
    _notificationsInitialized = true;
  } catch (e) {
    debugPrint('[SafetyNotification] Notification init warning: $e');
  }
}

void registerCustomPhotoPicker(PhotoPickerHandler? handler) {
  _customPhotoPicker = handler;
}

void registerNotificationHandler(NotificationHandler handler) {
  _notificationHandlers.add(handler);
}

void unregisterNotificationHandler(NotificationHandler handler) {
  _notificationHandlers.remove(handler);
}

void triggerExternalSafetyNotification({
  required String title,
  required String body,
  required bool isRejected,
}) {
  debugPrint('[SafetyNotification] $title: $body (rejected: $isRejected)');
  for (final handler in _notificationHandlers) {
    try {
      handler(title: title, body: body, isRejected: isRejected);
    } catch (_) {}
  }

  // Trigger native system tray notification on Android/desktop
  () async {
    try {
      await _ensureNotificationsInitialized();
      final androidDetails = AndroidNotificationDetails(
        'transport_safety_channel',
        'Transport One Alerts & Reminders',
        channelDescription:
            'Trip, safety, compliance, maintenance, and cleaning reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_stat_transport',
        color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      );
      final details = NotificationDetails(android: androidDetails);
      // A seconds-based ID caused alerts created together (for example several
      // compliance reminders at startup) to replace one another in the tray.
      _nextNotificationId = (_nextNotificationId + 1) & 0x7fffffff;
      await _notificationsPlugin?.show(
        id: _nextNotificationId,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[SafetyNotification] Native notification dispatch error: $e');
    }
  }();
}

Future<void> requestExternalNotificationPermission() async {
  debugPrint('[SafetyNotification] Notification permission requested');
  try {
    await _ensureNotificationsInitialized();
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    final androidImplementation =
        _notificationsPlugin?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  } catch (e) {
    debugPrint('[SafetyNotification] Permission request warning: $e');
  }
}

Future<void> scheduleWeeklyCleaningReminder({
  required String vehicleNumber,
}) async {
  // Disabled zonedSchedule to prevent Android exact alarm crashes
}

void pickDriverPhotoWeb({
  required bool useCamera,
  required void Function(String base64Data) onPhotoSelected,
  void Function(String errorMessage)? onError,
}) {
  if (_customPhotoPicker != null) {
    _customPhotoPicker!(
      useCamera: useCamera,
      onPhotoSelected: onPhotoSelected,
      onError: onError,
    );
    return;
  }

  () async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: useCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 60,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        onPhotoSelected(base64Data);
      }
    } catch (e) {
      debugPrint('[SafetyNotification] Native ImagePicker error: $e');
      if (onError != null) {
        onError('Unable to open photo picker: ${e.toString()}');
      }
    }
  }();
}
