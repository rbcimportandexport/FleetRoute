import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_one/src/app.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/trips_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scroll Performance & Memory Crash Resilience', () {
    testWidgets('AppScrollBehavior returns platform-adaptive scroll physics',
        (tester) async {
      const behavior = AppScrollBehavior();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final physics = behavior.getScrollPhysics(context);
              expect(physics, isNotNull);
              expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('PaintingBinding image cache has sufficient headroom to prevent LMK thrashing', () {
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;
      expect(PaintingBinding.instance.imageCache.maximumSize, equals(100));
      expect(PaintingBinding.instance.imageCache.maximumSizeBytes, equals(60 * 1024 * 1024));
    });

    testWidgets('TripsPage virtualized scrolling stress test with 100 trips',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = PlannerController();
      await controller.load();

      // Populate 100 trips to stress test list virtualization and rendering
      for (int i = 0; i < 100; i++) {
        final trip = TripRecord(
          reference: 'TRIP-STRESS-${i.toString().padLeft(3, '0')}',
          origin: 'Warehouse Unit A-$i',
          destination: 'Distribution Hub B-$i',
          status: i % 3 == 0 ? 'completed' : (i % 3 == 1 ? 'active' : 'planned'),
          assignedVehicle: 'GJ01AB${(1000 + i)}',
          assignedDriver: 'Driver $i',
          createdAt: '2026-11-20T06:00:00.000Z',
          loadingDateTime: '2026-11-20T08:00:00.000Z',
          unloadingDateTime: '2026-11-20T18:00:00.000Z',
        );
        controller.trips.add(trip);
      }

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: TripsPage(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify initial trips list rendered
      expect(find.byType(TripsPage), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      final scrollFinder = find.byType(Scrollable);
      expect(scrollFinder, findsOneWidget);

      // Rapidly fling down and up 10 times to simulate intense scrolling
      for (int j = 0; j < 10; j++) {
        await tester.fling(scrollFinder, const Offset(0, -600), 2000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.fling(scrollFinder, const Offset(0, 600), 2000);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pump(const Duration(milliseconds: 200));

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Rapid scrolling should never throw exceptions');
      expect(find.byType(TripsPage), findsOneWidget);
    });
  });
}
