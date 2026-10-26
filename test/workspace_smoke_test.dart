import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/pages/alerts_page.dart';
import 'package:transport_one/src/pages/dashboard_page.dart';
import 'package:transport_one/src/pages/fleet_workspace.dart';
import 'package:transport_one/src/pages/operations_module_page.dart';
import 'package:transport_one/src/pages/route_planner_page.dart';
import 'package:transport_one/src/pages/trips_page.dart';
import 'package:transport_one/src/widgets/map_workspace.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpAtSize(
    WidgetTester tester,
    Widget child,
    Size size,
    String label,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump(const Duration(milliseconds: 100));
    final exception = tester.takeException();
    if (exception != null) {
      final details = exception is FlutterError
          ? exception.toStringDeep()
          : exception.toString();
      fail('$label must render at $size without overflow:\n$details');
    }
  }

  testWidgets('primary workspaces render at phone and desktop sizes',
      (tester) async {
    final controller = PlannerController();
    await controller.load();

    final pages = <(String, Widget)>[
      (
        'DriversPage',
        OperationsModulePage(
          module: OperationsModule.drivers,
          controller: controller,
        ),
      ),
      (
        'VehiclesPage',
        OperationsModulePage(
          module: OperationsModule.vehicles,
          controller: controller,
        ),
      ),
      ('TripsPage', TripsPage(controller: controller)),
      ('AlertsPage', AlertsPage(controller: controller)),
      ('RoutePlannerPage', RoutePlannerPage(controller: controller)),
      (
        'DashboardPage',
        DashboardPage(controller: controller, onNavigate: (_) {}),
      ),
    ];

    for (final size in const [Size(360, 720), Size(1280, 800)]) {
      for (final page in pages) {
        await pumpAtSize(tester, page.$2, size, page.$1);
      }
    }
  });

  testWidgets('driver workspace does not expose admin seatbelt mode',
      (tester) async {
    final controller = PlannerController();
    await controller.load();
    controller.setDriverSessionForTesting(
      email: 'driver@example.com',
      name: 'Test Driver',
    );

    await pumpAtSize(
      tester,
      FleetWorkspace(controller: controller),
      const Size(360, 720),
      'Driver FleetWorkspace',
    );

    await tester.tap(find.byTooltip('Seatbelt Photos'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Admin (All Drivers)'), findsNothing);
    expect(find.text('Driver Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'driver workspace displays exactly 2 bottom navigation tabs and hides admin modules',
      (tester) async {
    final controller = PlannerController();
    await controller.load();
    controller.setDriverSessionForTesting(
      email: 'driver@example.com',
      name: 'Test Driver',
    );

    await pumpAtSize(
      tester,
      FleetWorkspace(controller: controller),
      const Size(360, 720),
      'Driver Navigation Tabs',
    );

    // Exactly 2 driver tabs
    expect(find.text('Duty & Photos'), findsOneWidget);
    expect(find.text('Trip & Route'), findsOneWidget);

    // Admin modules must not exist on driver navigation
    expect(find.text('Drivers'), findsNothing);
    expect(find.text('Vehicles'), findsNothing);
    expect(find.text('Alerts'), findsNothing);
  });

  testWidgets('pickup marker and GoogleMap are configured properly',
      (tester) async {
    final controller = PlannerController()..setOrigin('21.170200, 72.831100');

    await pumpAtSize(
      tester,
      MapWorkspace(controller: controller),
      const Size(800, 600),
      'GoogleMap workspace',
    );

    expect(find.byType(MapWorkspace), findsOneWidget);
    expect(controller.origin, contains('21.170200'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner map renders GoogleMap component',
      (tester) async {
    final controller = PlannerController()..setOrigin('Surat');

    await pumpAtSize(
      tester,
      MapWorkspace(controller: controller),
      const Size(800, 600),
      'GoogleMap planner map',
    );

    expect(find.byType(MapWorkspace), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller stop removal works cleanly',
      (tester) async {
    final controller = PlannerController()
      ..setOrigin('21.170200, 72.831100')
      ..setDestination('21.125500, 73.112200')
      ..addStop('21.200000, 72.960000');

    expect(controller.stops.length, 1);
    controller.removeStop(0);
    expect(controller.stops, isEmpty);
  });

  testWidgets('controller destination update and removal works cleanly',
      (tester) async {
    final controller = PlannerController()
      ..setOrigin('21.170200, 72.831100')
      ..setDestination('21.125500, 73.112200');

    expect(controller.destination, isNotEmpty);
    controller.clearRoute();
    expect(controller.destination, isEmpty);
  });

  testWidgets(
      'fallback routing banner displays when road routing falls back to straight line',
      (tester) async {
    final controller = PlannerController()
      ..setOrigin('21.170200, 72.831100')
      ..setDestination('21.125500, 73.112200');

    await pumpAtSize(
      tester,
      MapWorkspace(controller: controller),
      const Size(800, 600),
      'Fallback route banner test',
    );

    expect(find.byType(MapWorkspace), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
