import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/planner_controller.dart';
import '../services/incoming_intent_service.dart';
import 'driver_dashboard_page.dart';
import 'route_planner_page.dart';

/// Clean 2-Tab Navigation Host
/// Tab 1: Duty & Photos (Zero Typing Smart Photo Logger)
/// Tab 2: Trip & Route (100% Exact Transport 1 Route Planner Map)
class DriverMainScaffold extends StatefulWidget {
  const DriverMainScaffold({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<DriverMainScaffold> createState() => _DriverMainScaffoldState();
}

class _DriverMainScaffoldState extends State<DriverMainScaffold> {
  int _currentIndex = 0; // Start directly on Duty & Photos tab
  StreamSubscription? _incomingLocationSub;

  @override
  void initState() {
    super.initState();
    // 1. Listen for runtime incoming location shares (from WhatsApp, Google Maps, or Browser)
    _incomingLocationSub =
        IncomingIntentService().onLocationReceived.listen((data) {
      if (!mounted) return;
      if (_currentIndex != 1) {
        setState(() => _currentIndex = 1); // Auto switch to Trip & Route map
      }
    });

    // 2. Cold start check: If app was opened by clicking a maps link or share,
    // or if the driver had an active navigation / trip running before app closed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final navActive = prefs.getBool('transport_one.nav_active') ?? false;
        final savedTab = prefs.getInt('transport_one.driver_tab');

        if (navActive || savedTab == 1 || widget.controller.activeTripForCurrentDriver != null) {
          if (mounted && _currentIndex != 1) {
            setState(() => _currentIndex = 1);
          }
        }
      } catch (_) {}

      final initial = await IncomingIntentService().checkInitialLocation();
      if (initial != null && mounted) {
        if (_currentIndex != 1) {
          setState(() => _currentIndex = 1);
        }
      }
    });
  }

  @override
  void dispose() {
    _incomingLocationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DriverDashboardPage(controller: widget.controller),
          RoutePlannerPage(controller: widget.controller),
        ],
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tab 1: Duty & Photos (Electric Royal Blue #2563EB)
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _currentIndex = 0);
                  SharedPreferences.getInstance().then((p) => p.setInt('transport_one.driver_tab', 0));
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 24,
                      color: _currentIndex == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ड्यूटी व फोटो',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _currentIndex == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab 2: Trip & Route (Same Blue #2563EB - No purple!)
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _currentIndex = 1);
                  SharedPreferences.getInstance().then((p) => p.setInt('transport_one.driver_tab', 1));
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.navigation_rounded,
                      size: 24,
                      color: _currentIndex == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ट्रिप व रूट',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _currentIndex == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
