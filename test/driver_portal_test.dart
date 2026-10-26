import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/driver_portal_page.dart';

import 'package:transport_one/src/services/app_security_service.dart';
import 'package:transport_one/src/services/firebase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AppSecurityService.resetFailedAttempts();
    AppSecurityService.resetDeviceSecretForTesting();
    FirebaseAuthService.instance.testAuthHandler = (email, password) async {
      return AuthenticatedFleetUser(
        uid: 'sandeep_test_uid',
        email: email,
        name: 'SANDEEP',
        role: 'driver',
        assignedVehicle: 'GJ19Y2720',
      );
    };
  });

  tearDown(() {
    FirebaseAuthService.instance.testAuthHandler = null;
  });

  testWidgets(
      'DriverPortalPage renders all notifications, memo banner and photo actions',
      (tester) async {
    final controller = PlannerController();
    await controller.load();
    controller.setAdminSessionForTesting();
    await controller.addDriver(
      const DriverProfile(
        'SANDEEP',
        'sandeep@example.com',
        assignedVehicle: 'GJ19Y2720',
        password: 'TestPassword123!',
      ),
    );

    controller.setDriverSessionForTesting(
      email: 'sandeep@example.com',
      name: 'SANDEEP',
      assignedVehicle: 'GJ19Y2720',
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverPortalPage(
            controller: controller,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Verify Driver Profile Header
    expect(find.text('SANDEEP'), findsOneWidget);
    expect(find.text('GJ19Y2720'), findsOneWidget);
    expect(find.text('ON DUTY'), findsOneWidget);

    // 2. Verify Sunday Cleaning Banner
    expect(find.textContaining('Sunday'), findsWidgets);
    expect(find.textContaining('Cleaning'), findsWidgets);

    // 3. Verify Police / RTO Memo Quick Banner
    expect(find.text('Police / RTO Memo Mila?'), findsOneWidget);
    expect(find.text('PHOTO LO'), findsOneWidget);

    // 4. Verify Maintenance & Insurance Notifications
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Insurance & PUC'), findsOneWidget);

    // 5. Verify 6 Quick Photo Action Cards
    expect(find.text('Seatbelt Pehno & Photo Lo'), findsOneWidget);
    expect(find.text('Gaadi Saaf Safai Photo'), findsOneWidget);
    expect(find.text('Police Memo / Challan Photo'), findsOneWidget);
    expect(find.text('Maintenance / Meter Photo'), findsOneWidget);
    expect(find.text('Insurance & PUC Kagaz'), findsOneWidget);
    expect(find.text('Bilty / Petrol-Diesel Slip'), findsOneWidget);

    // 6. Verify GPS Route Navigation Launcher
    expect(find.text('Route Map & Live GPS'), findsOneWidget);
    expect(find.text('MAP KHOLO'), findsOneWidget);

    // 7. Test submitting a driver memo photo record
    await controller.submitDriverPhotoRecord(
      category: 'Police & RTO Memo',
      photoBase64: 'mock_memo_img',
      notes: 'Highway RTO checking memo photo',
    );
    await tester.pump();

    // Verify record appears in recent photos
    expect(find.textContaining('Police & RTO Memo'), findsWidgets);
    expect(find.text('SAVED'), findsWidgets);

    // Verify critical memo alert was logged in controller
    expect(
      controller.alerts
          .any((a) => a.category == 'memo' && a.vehicleNumber == 'GJ19Y2720'),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
