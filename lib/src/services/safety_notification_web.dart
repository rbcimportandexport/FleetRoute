import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe' as js_util;

typedef PhotoPickerHandler = void Function({
  required bool useCamera,
  required void Function(String base64Data) onPhotoSelected,
});

typedef NotificationHandler = void Function({
  required String title,
  required String body,
  required bool isRejected,
});

void registerCustomPhotoPicker(PhotoPickerHandler? handler) {}
void registerNotificationHandler(NotificationHandler handler) {}
void unregisterNotificationHandler(NotificationHandler handler) {}

void triggerExternalSafetyNotification({
  required String title,
  required String body,
  required bool isRejected,
}) {
  try {
    final global = js.globalContext;
    if (global.has('TransportSafety')) {
      final safety = global['TransportSafety'] as js.JSObject;
      safety.callMethod(
        'showNotification'.toJS,
        title.toJS,
        body.toJS,
        isRejected.toJS,
      );
    }
  } catch (_) {}
}

void requestExternalNotificationPermission() {
  try {
    final global = js.globalContext;
    if (global.has('TransportSafety')) {
      final safety = global['TransportSafety'] as js.JSObject;
      safety.callMethod('requestPermission'.toJS);
    }
  } catch (_) {}
}

void pickDriverPhotoWeb({
  required bool useCamera,
  required void Function(String base64Data) onPhotoSelected,
  void Function(String errorMessage)? onError,
}) {
  try {
    final global = js.globalContext;
    if (global.has('TransportSafety')) {
      final safety = global['TransportSafety'] as js.JSObject;
      final jsCallback = ((js.JSString data) {
        onPhotoSelected(data.toDart);
      }).toJS;
      safety.callMethod(
        'pickDriverPhoto'.toJS,
        useCamera.toJS,
        jsCallback,
      );
    } else {
      if (onError != null) {
        onError('Web camera / photo interface is initializing.');
      }
    }
  } catch (e) {
    if (onError != null) {
      onError('Photo capture error: $e');
    }
  }
}
//end  of the  page
