import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'src/controllers/planner_controller.dart';
import 'src/pages/driver_main_scaffold.dart';
import 'src/admin/admin_main_scaffold.dart';
import 'src/pages/login_page.dart';
import 'src/services/firebase_bootstrap_service.dart';
import 'src/services/offline_sync_service.dart';
import 'src/services/document_expiry_reminder_service.dart';
import 'src/theme/app_theme.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Limit image cache to prevent OOM crash on Android
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;

    // Start offline queue & auto-reconnect sync service (100% crash proof)
    OfflineSyncService.instance.initialize();

    // Start Document Expiry Daily 3x Notification Reminder Schedule
    DocumentExpiryReminderService.instance.initialize();

    // Flutter widget error guard
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[CRASH_GUARD] FlutterError: ${details.exceptionAsString()}');
    };

    // Global error widget fallback
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Material(
        color: Color(0xFFF8FAFC),
        child: Center(
          child: Text(
            'लोड हो रहा है...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    };

    // Platform error guard to prevent Android OS auto-kill
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[CRASH_GUARD] PlatformDispatcher error: $error\n$stack');
      return true; // Mark as handled so app never closes unexpectedly
    };

    runApp(const FreshDriverApp());
  }, (error, stack) {
    debugPrint('[CRASH_GUARD] Root Zone error: $error\n$stack');
  });
}

class FreshDriverApp extends StatefulWidget {
  const FreshDriverApp({super.key});

  @override
  State<FreshDriverApp> createState() => _FreshDriverAppState();
}

class _FreshDriverAppState extends State<FreshDriverApp>
    with WidgetsBindingObserver {
  late final PlannerController controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = PlannerController();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Safe Firebase initialization
      await FirebaseBootstrapService.initialize();
    } catch (e) {
      debugPrint('[INIT] Firebase init skipped/error: $e');
    }

    try {
      await controller.load();
    } catch (e) {
      debugPrint('[INIT] Controller load error: $e');
    }

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  void didHaveMemoryPressure() {
    // Release images when phone has low memory
    final cache = PaintingBinding.instance.imageCache;
    cache.clearLiveImages();
    cache.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_rounded, size: 48, color: Color(0xFF16A34A)),
                SizedBox(height: 16),
                CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2.5),
                SizedBox(height: 12),
                Text(
                  'Transport 1 Driver Portal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Transport 1 Driver Portal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: controller.isLoggedIn
              ? (controller.isAdmin
                  ? AdminMainScaffold(controller: controller)
                  : DriverMainScaffold(controller: controller))
              : LoginPage(
                  controller: controller,
                  onLoginSuccess: () {
                    controller.isLoggedIn = true;
                    controller.notifyListeners();
                  },
                ),
        );
      },
    );
  }
}
