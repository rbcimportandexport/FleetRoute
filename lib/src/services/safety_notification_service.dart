import 'safety_notification_stub.dart'
    if (dart.library.js_interop) 'safety_notification_web.dart'
    as platform_impl;

class SafetyNotificationService {
  static void notifyDriverSafety({
    required String title,
    required String body,
    required bool isRejected,
  }) {
    platform_impl.triggerExternalSafetyNotification(
      title: title,
      body: body,
      isRejected: isRejected,
    );
  }

  /// Instantly alerts driver about newly assigned trip or route dispatch
  static void notifyDriverNewTrip({
    required String driverName,
    required String vehicleNumber,
    required String origin,
    required String destination,
    required String cargoSummary,
  }) {
    platform_impl.triggerExternalSafetyNotification(
      title: '🚨 New Trip Assigned: $origin ➔ $destination',
      body: 'Driver: $driverName | Vehicle: $vehicleNumber\nCargo: $cargoSummary\nKripya trip details check karein aur start karein.',
      isRejected: false,
    );
  }

  static void requestPermission() {
    platform_impl.requestExternalNotificationPermission();
  }

  static void pickDriverPhoto({
    required bool useCamera,
    required void Function(String base64Data) onPhotoSelected,
    void Function(String errorMessage)? onError,
  }) {
    platform_impl.pickDriverPhotoWeb(
      useCamera: useCamera,
      onPhotoSelected: onPhotoSelected,
      onError: onError,
    );
  }

  static void registerCustomPhotoPicker(
      platform_impl.PhotoPickerHandler? handler) {
    platform_impl.registerCustomPhotoPicker(handler);
  }

  static void addNotificationHandler(
      platform_impl.NotificationHandler handler) {
    platform_impl.registerNotificationHandler(handler);
  }

  static void removeNotificationHandler(
      platform_impl.NotificationHandler handler) {
    platform_impl.unregisterNotificationHandler(handler);
  }
}
