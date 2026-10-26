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
