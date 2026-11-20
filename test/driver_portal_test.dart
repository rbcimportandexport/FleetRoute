import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/driver_portal_page.dart';
import 'package:transport_one/src/services/app_localization_service.dart';

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
    expect(find.text('GJ19Y2720'), findsWidgets);
    expect(find.textContaining('DUTY'), findsWidgets);

    // 2. Verify Sunday Cleaning Banner
    expect(find.textContaining('Sunday'), findsWidgets);
    expect(find.textContaining('Cleaning'), findsWidgets);

    // 3. Verify Police / RTO Memo Quick Banner
    expect(find.text(AppLocalizationService.instance.tr('memo_banner_title')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('take_photo')), findsWidgets);

    // 4. Verify Maintenance & Insurance Notifications
    expect(find.text(AppLocalizationService.instance.tr('maintenance_and_insurance')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('insurance_puc_title')), findsOneWidget);

    // 5. Verify 6 Quick Photo Action Cards
    expect(find.text(AppLocalizationService.instance.tr('seatbelt_photo')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('sunday_cleaning')), findsWidgets);
    expect(find.text(AppLocalizationService.instance.tr('police_memo')), findsWidgets);
    expect(find.text(AppLocalizationService.instance.tr('meter_photo')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('insurance_puc')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('fuel_receipt')), findsOneWidget);

    // 6. Verify GPS Route Navigation Launcher
    expect(find.text(AppLocalizationService.instance.tr('route_map_live_gps')), findsOneWidget);
    expect(find.text(AppLocalizationService.instance.tr('open_map')), findsOneWidget);

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
