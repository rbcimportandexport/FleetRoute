import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrapService {
  FirebaseBootstrapService._();

  static bool _initialized = false;
  static Object? _initializationError;

  static bool get isInitialized => _initialized && Firebase.apps.isNotEmpty;
  static Object? get initializationError => _initializationError;

  static Future<void> initialize() async {
    if (_initialized || Firebase.apps.isNotEmpty) {
      _initialized = true;
      return;
    }
    // Android reads the generated native resource from google-services.json.
    // Web has no native resource bundle, so it must receive a Web App config
    // through dart-defines. Other platforms may use generated options when
    // supplied, or their native Firebase configuration files.
    if (kIsWeb && !DefaultFirebaseOptions.isConfigured) {
      _initializationError =
          StateError('Firebase Web App build configuration missing.');
      return;
    }
    try {
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
      // FlutterFire normally uses local persistence on web, but setting it
      // explicitly prevents browser/session defaults from logging the user
      // out whenever the page is refreshed or the tab is reopened.
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      _initialized = true;
      _initializationError = null;
    } catch (error, stackTrace) {
      _initializationError = error;
      debugPrint('Firebase initialization failed: $error\n$stackTrace');
    }
  }
}
