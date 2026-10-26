import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/seatbelt_gallery_page.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
      'selected driver never falls back to another driver and opens vehicle report',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController()..setAdminSessionForTesting();
    await controller.addTruckModel(const TruckModel(
      code: 'GJ19Y2720',
      name: 'Tata Fleet Truck',
      axles: '2',
      capacity: '12 Ton',
      ownerName: 'Transport One',
    ));
    await controller.addDriver(const DriverProfile(
      'DADARAO',
      'dadarao@transport.one',
      phone: '8007755389',
      password: 'dadarao123',
      assignedVehicle: 'GJ19Y2720',
    ));
    await controller.addDriver(const DriverProfile(
      'SANDEEP',
      'sandeep@transport.one',
      phone: '6355583474',
      password: 'sandeep123',
    ));
    await controller.addSeatbeltRecord(SeatbeltRecord(
      id: 'dadarao-record',
      driverName: 'DADARAO',
      driverId: '8007755389',
      vehicleNumber: 'GJ19Y2720',
      photoBase64: '',
      timestamp: DateTime(2026, 10, 26, 16, 3),
      isApproved: true,
    ));
    await controller.addSeatbeltRecord(SeatbeltRecord(
      id: 'sandeep-record',
      driverName: 'SANDEEP',
      driverId: 'sandeep@transport.one',
      vehicleNumber: 'OTHER-TRUCK',
      photoBase64: '',
      timestamp: DateTime(2026, 10, 26, 16, 4),
      isApproved: true,
    ));

    await tester.pumpWidget(MaterialApp(
      home: SeatbeltGalleryPage(
        controller: controller,
        initialDriverEmail: 'dadarao@transport.one',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DADARAO'), findsWidgets);
    expect(find.text('SANDEEP'), findsNothing);
    expect(find.text('1 Total Logs'), findsOneWidget);

    await tester.tap(find.text('Driver & Vehicle'));
    await tester.pumpAndSettle();

    expect(find.text('Assigned Vehicle & Telemetry'), findsOneWidget);
    expect(find.text('ID / Phone: 8007755389'), findsOneWidget);
    expect(find.textContaining('GJ19Y2720'), findsWidgets);
    expect(find.textContaining('Tata Fleet Truck'), findsWidgets);
  });
}
