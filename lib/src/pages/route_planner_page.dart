import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../widgets/map_workspace.dart';

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          final compact = viewport.maxWidth < 600;
          return SafeArea(
            child: Padding(
              padding: compact ? EdgeInsets.zero : const EdgeInsets.all(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 0 : 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: compact
                        ? null
                        : Border.all(color: const Color(0xFFD5DEEA)),
                    borderRadius: BorderRadius.circular(compact ? 0 : 12),
                    boxShadow: compact
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x140F2440),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Live Route is intentionally map-only. Trip planning,
                      // driver assignment and vehicle setup live in their own
                      // modules so they never cover the active route.
                      return MapWorkspace(controller: widget.controller);
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
// end of  the  page
