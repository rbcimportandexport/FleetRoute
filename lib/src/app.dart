import 'dart:ui';

import 'package:flutter/material.dart';

import 'controllers/planner_controller.dart';
import 'pages/fleet_workspace.dart';
import 'pages/login_page.dart';
import 'services/app_localization_service.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_truck_splash.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class TransportApp extends StatefulWidget {
  const TransportApp({this.controller, super.key});

  final PlannerController? controller;

  @override
  State<TransportApp> createState() => _TransportAppState();
}

class _TransportAppState extends State<TransportApp> {
  late final PlannerController controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      controller = widget.controller!;
      _ownsController = false;
    } else {
      controller = PlannerController();
      _ownsController = true;
      controller.load();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizationService.instance.currentLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'Transport One',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: Locale(lang.code.toLowerCase()),
          scrollBehavior: const AppScrollBehavior(),
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.isLoading) {
                return const AnimatedTruckSplash();
              }
              if (!controller.isLoggedIn) {
                return LoginPage(controller: controller);
              }
              return FleetWorkspace(controller: controller);
            },
          ),
        );
      },
    );
  }
}
