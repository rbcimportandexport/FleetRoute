import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/controllers/planner_controller.dart';
import 'src/services/firebase_bootstrap_service.dart';
import 'src/widgets/animated_truck_splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TransportLauncher());
}

class _TransportLauncher extends StatefulWidget {
  const _TransportLauncher();

  @override
  State<_TransportLauncher> createState() => _TransportLauncherState();
}

class _TransportLauncherState extends State<_TransportLauncher> {
  late final Future<void> _bootstrap;
  late final PlannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PlannerController();
    _bootstrap = _initializeApp();
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
