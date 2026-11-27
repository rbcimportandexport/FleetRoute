import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';

class BackgroundTrackingService {
  BackgroundTrackingService._();
  static final BackgroundTrackingService instance = BackgroundTrackingService._();

  bool _isInitialized = false;

  Future<void> enableBackgroundExecution() async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) {
        const androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: 'ट्रिप नेविगेशन व लाइव GPS चालू है',
          notificationText: 'स्क्रीन लॉक होने पर भी स्पीड, रूट और लाइव ट्रैकिंग सक्रिय है',
          notificationImportance: AndroidNotificationImportance.high,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWifiLock: true,
        );
        _isInitialized = await FlutterBackground.initialize(androidConfig: androidConfig);
      }

      if (_isInitialized && !FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
        debugPrint('[BackgroundTrackingService] Background execution ENABLED successfully');
      }
    } catch (e) {
      debugPrint('[BackgroundTrackingService] Error enabling background execution: $e');
    }
  }

  Future<void> disableBackgroundExecution() async {
    if (kIsWeb) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
        debugPrint('[BackgroundTrackingService] Background execution DISABLED');
      }
    } catch (e) {
      debugPrint('[BackgroundTrackingService] Error disabling background execution: $e');
    }
  }
}
