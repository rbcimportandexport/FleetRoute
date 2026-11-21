import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/controllers/planner_controller.dart';
import 'src/services/firebase_bootstrap_service.dart';
import 'src/widgets/animated_truck_splash.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Keep decoded image/tile memory conservative on low-RAM Android devices.
    // The cache is only an optimization; retaining dozens of map tiles can
    // otherwise push the native graphics heap over the device limit.
    PaintingBinding.instance.imageCache.maximumSize = 40;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024;

    // Catch any synchronous Flutter widget/rendering error and prevent app crash
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint(
          '[CRASH_GUARD] FlutterError caught: ${details.exceptionAsString()}');
    };

    // Keep an isolated widget failure from taking down the whole navigation
    // tree. This is especially useful on older devices where a single
    // platform view or image can fail while the rest of the app is healthy.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Material(
        color: Color(0xFFF8FAFC),
        child: Center(
          child: Text(
            'This section is temporarily unavailable. Please retry.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    };

    // Catch any platform/engine level asynchronous exception and prevent app crash/auto-cut
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint(
          '[CRASH_GUARD] PlatformDispatcher caught error: $error\n$stack');
      return true; // Returns true to mark error as handled so Android OS does not kill/close app!
    };

    runApp(const _TransportLauncher());
  }, (error, stack) {
    debugPrint('[CRASH_GUARD] Root Zone error caught: $error\n$stack');
  });
}

class _TransportLauncher extends StatefulWidget {
  const _TransportLauncher();

  @override
  State<_TransportLauncher> createState() => _TransportLauncherState();
}

class _TransportLauncherState extends State<_TransportLauncher>
    with WidgetsBindingObserver {
  late final Future<void> _bootstrap;
  late final PlannerController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PlannerController();
    _bootstrap = _initializeApp();
  }

  @override
  void didHaveMemoryPressure() {
    // Release decoded images immediately when Android signals pressure. This
    // prevents a recoverable cache spike from becoming a native OOM kill.
    final cache = PaintingBinding.instance.imageCache;
    cache.clearLiveImages();
    cache.clear();
  }

  Future<void> _initializeApp() async {
    // Firebase must be ready before the controller attempts to restore an
    // authenticated session. Running both concurrently caused a valid server
    // session to be cleared whenever controller.load() won the race.
    final splashDelay =
        Future<void>.delayed(const Duration(milliseconds: 2600));
    await FirebaseBootstrapService.initialize();
    await _controller.load();
    await splashDelay;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return TransportApp(controller: _controller);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          home: const AnimatedTruckSplash(),
        );
      },
    );
  }
}
