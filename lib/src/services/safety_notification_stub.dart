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
int _nextNotificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);

Future<void> _ensureNotificationsInitialized() async {
  if (_notificationsInitialized) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Use '@mipmap/ic_launcher' as rock-solid default Android icon
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );
    final initialized = await _notificationsPlugin?.initialize(
      settings: initSettings,
    );
    if (initialized == true) {
      _notificationsInitialized = true;
    }
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
  // A handler may unregister itself while processing the event.
  for (final handler in List<NotificationHandler>.of(_notificationHandlers)) {
    try {
      handler(title: title, body: body, isRejected: isRejected);
    } catch (_) {}
  }

  // Trigger native system tray notification on Android/desktop
  () async {
    try {
      await _ensureNotificationsInitialized();
      if (!_notificationsInitialized || _notificationsPlugin == null) return;
      final androidDetails = AndroidNotificationDetails(
        'transport_safety_channel_v2',
        'Transport One Alerts & Reminders',
        channelDescription:
            'Trip, safety, compliance, maintenance, and cleaning reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      );
      final details = NotificationDetails(android: androidDetails);
      // A seconds-based ID caused alerts created together (for example several
      // compliance reminders at startup) to replace one another in the tray.
      _nextNotificationId = (_nextNotificationId + 1) & 0x7fffffff;
      await _notificationsPlugin!.show(
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

void Function(String base64Data)? _pendingPhotoCallback;

/// Checks for and consumes any lost photo data returned by the Android system after
/// an Activity recreation caused by low-memory camera destruction.
Future<void> consumePendingLostPhotoData({
  void Function(String base64Data)? onPhotoRecovered,
}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final picker = ImagePicker();
    final LostDataResponse response = await picker.retrieveLostData();
    if (response.isEmpty) return;

    final file = response.file;
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final base64Data = base64Encode(bytes);
        debugPrint('[SafetyNotification] Successfully recovered lost photo: ${bytes.length} bytes');
        final targetCallback = onPhotoRecovered ?? _pendingPhotoCallback;
        targetCallback?.call(base64Data);
      }
    } else if (response.exception != null) {
      debugPrint('[SafetyNotification] Lost photo response error: ${response.exception}');
    }
  } catch (e) {
    debugPrint('[SafetyNotification] retrieveLostData check error: $e');
  }
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

  _pendingPhotoCallback = onPhotoSelected;

  () async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: useCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
        requestFullMetadata: false,
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
