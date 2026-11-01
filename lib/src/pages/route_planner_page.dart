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
  bool _loadingAssignedTrip = false;
  String? _tripLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssignedTrip());
  }

  Future<void> _loadAssignedTrip() async {
    if (!mounted || !widget.controller.isDriver) return;
    final trip = widget.controller.activeTripForCurrentDriver;
    if (trip == null) return;
    setState(() {
      _loadingAssignedTrip = true;
      _tripLoadError = null;
    });
    widget.controller.setRoute(
      newOrigin: trip.origin,
      newDestination: trip.destination,
      newStops: trip.stops,
    );
    final loaded = await widget.controller.resolveAndSetRoute(
      origin: trip.origin,
      destination: trip.destination,
      stops: trip.stops,
    );
    if (!mounted) return;
    setState(() {
      _loadingAssignedTrip = false;
      _tripLoadError =
          loaded ? null : 'Assigned trip location load nahi hui. Retry karein.';
    });
  }

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
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: MapWorkspace(controller: widget.controller),
                          ),
                          if (_loadingAssignedTrip)
                            const Positioned(
                              left: 16,
                              right: 16,
                              top: 54,
                              child: _RouteLoadingBanner(),
                            ),
                          if (_tripLoadError != null)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 54,
                              child: Material(
                                color: const Color(0xFFFFF7ED),
                                elevation: 5,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Trip route load nahi hui.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _loadAssignedTrip,
                                        child: const Text('RETRY'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
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

class _RouteLoadingBanner extends StatelessWidget {
  const _RouteLoadingBanner();

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 10),
              Text(
                'Assigned trip route load ho rahi hai...',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}
// end of  the  page
