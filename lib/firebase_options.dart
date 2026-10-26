// Firebase Configuration for Transport One Fleet Management
// This file provides platform configuration options for Firebase initialization.
// In production, configure through Firebase CLI or dart-define flags:
//   --dart-define=FIREBASE_API_KEY=...
//   --dart-define=FIREBASE_PROJECT_ID=...
//   --dart-define=FIREBASE_APP_ID=...

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY',
      defaultValue: 'AIzaSyC_vjgR6DCUIg2IvrXhkrJ1ybgsjWrLCNU');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID',
      defaultValue: '1:839976327049:android:d90aa8ba5dd0d001f8b358');
  static const String messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '839976327049');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID',
      defaultValue: 'transport-one');
  static const String storageBucket = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'transport-one.firebasestorage.app');

  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Supply FIREBASE_API_KEY, '
        'FIREBASE_APP_ID and FIREBASE_PROJECT_ID at build time.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS)
          ? null
          : 'com.transportone.transportOne',
    );
  }

  static Map<String, dynamic> get currentPlatformOptions {
    if (kIsWeb) {
      return {
        'apiKey': apiKey,
        'appId': appId,
        'messagingSenderId': messagingSenderId,
        'projectId': projectId,
        'storageBucket': storageBucket,
      };
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return {
          'apiKey': apiKey,
          'appId': appId,
          'messagingSenderId': messagingSenderId,
          'projectId': projectId,
          'storageBucket': storageBucket,
        };
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return {
          'apiKey': apiKey,
          'appId': appId,
          'messagingSenderId': messagingSenderId,
          'projectId': projectId,
          'storageBucket': storageBucket,
          'iosBundleId': 'com.transportone.transportOne',
        };
      default:
        return {
          'apiKey': apiKey,
          'appId': appId,
          'messagingSenderId': messagingSenderId,
          'projectId': projectId,
          'storageBucket': storageBucket,
        };
    }
  }
}
