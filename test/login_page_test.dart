import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/login_page.dart';
import 'package:transport_one/src/services/firebase_auth_service.dart';
import 'package:transport_one/src/services/whatsapp_otp_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    // Intercept Firebase calls so tests run offline without real Firebase config.
    FirebaseAuthService.instance.testAuthHandler = (email, password) async {
      final norm = email.trim().toLowerCase();
      if (password == 'wrong_pin' || password == 'wrongpassword') {
        throw const FormatException('Invalid credentials. Access denied.');
      }
      // Admin by email
      if (norm == 'rbcsaurabhyadav@gmail.com') {
        return const AuthenticatedFleetUser(
          uid: 'admin_uid',
          email: 'rbcsaurabhyadav@gmail.com',
          name: 'Saurabh Yadav (Admin)',
          role: 'admin',
        );
      }
      // Phone-number login — treat 10+ digit strings as admin for test
      final digits = norm.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        return const AuthenticatedFleetUser(
          uid: 'admin_phone_uid',
          email: 'rbcsaurabhyadav@gmail.com',
          name: 'Saurabh Yadav (Admin)',
          role: 'admin',
        );
      }
      // Driver PIN login
      if (password.startsWith('PIN-')) {
        return AuthenticatedFleetUser(
          uid: 'driver_uid',
          email: norm.contains('@') ? norm : '$norm@transport.com',
          name: 'Driver User',
          role: 'driver',
        );
      }
      return AuthenticatedFleetUser(
        uid: 'generic_uid',
        email: norm.contains('@') ? norm : '$norm@transport.com',
        name: 'Generic User',
        role: 'driver',
      );
    };
  });

  tearDown(() {
    FirebaseAuthService.instance.testAuthHandler = null;
    FirebaseAuthService.instance.testSignUpHandler = null;
    FirebaseAuthService.instance.testSendPhoneOtpHandler = null;
    FirebaseAuthService.instance.testVerifyPhoneOtpHandler = null;
    WhatsAppOtpService.instance.testSendOtpHandler = null;
    WhatsAppOtpService.instance.testVerifyOtpHandler = null;
    WhatsAppOtpService.instance.testVerifyOtpAndGetProofHandler = null;
    WhatsAppOtpService.instance.testVerifyProofTokenHandler = null;
  });

  // ---------------------------------------------------------------------------
  testWidgets('User can switch to Register tab, enter details and sign up',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();
    bool successCalled = false;

    FirebaseAuthService.instance.testSignUpHandler =
        (email, password, name, role, phone) async {
      return AuthenticatedFleetUser(
        uid: 'new_registered_uid',
        email: email,
        name: name,
        role: role,
        assignedVehicle: 'MH-12-RN-8841',
      );
    };

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          controller: controller,
          onLoginSuccess: () => successCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Register link at bottom
    await tester.ensureVisible(find.text('Naya account banana hai? Register karein'));
    await tester.tap(find.text('Naya account banana hai? Register karein'));
    await tester.pumpAndSettle();

    expect(find.text('Full Name (पूरा नाम)'), findsOneWidget);
    expect(find.text('Create Password (नया पासवर्ड)'), findsOneWidget);

    // Enter registration fields
    await tester.enterText(find.byType(TextField).at(0), 'Ramesh Kumar');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.enterText(find.byType(TextField).at(2), 'MH-12-RN-8841');
    await tester.enterText(find.byType(TextField).at(3), 'ramesh@transport.com');
    await tester.enterText(find.byType(TextField).at(4), 'password123');

    await tester.ensureVisible(find.text('Register & Sign In'));
    await tester.tap(find.text('Register & Sign In'));

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Account ban gaya! Kripya Login karein.'), findsOneWidget);
    expect(find.text('Password / PIN'), findsOneWidget);
    final phoneField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneField.controller?.text, 'ramesh@transport.com');

    // Now sign in with the prefilled credentials
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(controller.isLoggedIn, isTrue);
    expect(controller.isDriver, isTrue);
    expect(successCalled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets('LoginPage renders branding, phone field and WhatsApp OTP mode',
      (tester) async {
    final controller = PlannerController();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(controller: controller, initialUseOtpMode: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRANSPORT ONE'), findsOneWidget);
    expect(find.text('Fleet Operations & Route Intelligence'), findsOneWidget);
    expect(find.text('WhatsApp OTP'), findsOneWidget);
    expect(find.text('Password / PIN'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Send WhatsApp OTP'), findsOneWidget);

    final phoneField = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneField.controller?.text, '');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets(
      'Admin logs in via Password mode and onLoginSuccess callback fires',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();
    bool successCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          controller: controller,
          onLoginSuccess: () => successCalled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password / PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'rbcsaurabhyadav@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'admin123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(controller.isLoggedIn, isTrue);
    expect(controller.isAdmin, isTrue);
    expect(controller.loggedInEmail, 'rbcsaurabhyadav@gmail.com');
    expect(successCalled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets('Super Admin logs in with phone +91 9157661886 and password',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password / PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '+91 9157661886');
    await tester.enterText(find.byType(TextField).at(1), 'admin123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(controller.isLoggedIn, isTrue);
    expect(controller.isAdmin, isTrue);
    expect(controller.loggedInRole, 'admin');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets('Wrong password shows error banner and keeps user logged out',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password / PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'rbcsaurabhyadav@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong_pin');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Invalid credentials. Access denied.'), findsOneWidget);
    expect(controller.isLoggedIn, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets('Driver created by Admin can log in via Password / PIN mode',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();

    // Must be admin to addDriver
    controller.setAdminSessionForTesting();
    await controller.addDriver(const DriverProfile(
      'Suresh Yadav',
      'suresh101',
      phone: '9822001122',
      password: 'passwordSuresh1',
      assignedVehicle: 'MH-12-RN-8841',
    ));
    await controller.logout();

    // Allow driver passwordSuresh1 to authenticate
    FirebaseAuthService.instance.testAuthHandler = (email, password) async {
      if (password == 'passwordSuresh1') {
        return const AuthenticatedFleetUser(
          uid: 'driver_suresh_uid',
          email: 'suresh101',
          name: 'Suresh Yadav',
          role: 'driver',
          assignedVehicle: 'MH-12-RN-8841',
        );
      }
      throw const FormatException('Invalid credentials. Access denied.');
    };

    await tester.pumpWidget(
      MaterialApp(home: LoginPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password / PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '9822001122');
    await tester.enterText(find.byType(TextField).at(1), 'passwordSuresh1');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(controller.isLoggedIn, isTrue);
    expect(controller.isDriver, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  testWidgets(
      'Interakt WhatsApp OTP flow: send succeeds, wrong OTP shows error',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = PlannerController();

    WhatsAppOtpService.instance.testSendOtpHandler = (phone) async {
      return {'success': true, 'message': 'WhatsApp OTP bheja gaya.'};
    };
    WhatsAppOtpService.instance.testVerifyOtpHandler = (phone, otp) async {
      return {
        'success': false,
        'message': 'WhatsApp OTP galat ya expire ho gaya hai.'
      };
    };

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(controller: controller, initialUseOtpMode: true),
      ),
    );
    await tester.pump();

    // Enter phone and send OTP
    await tester.enterText(find.byType(TextField).first, '9822001122');
    await tester.ensureVisible(find.text('Send WhatsApp OTP'));
    await tester.tap(find.text('Send WhatsApp OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('WhatsApp OTP Code'), findsOneWidget);
    expect(find.text('Verify & Sign In'), findsOneWidget);

    // Enter wrong OTP
    await tester.enterText(find.byType(TextField).at(1), '000000');
    await tester.ensureVisible(find.text('Verify & Sign In'));
    await tester.tap(find.text('Verify & Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('WhatsApp OTP galat ya expire ho gaya hai.'),
      findsOneWidget,
    );
    // Unmount widget so its State and periodic timer are disposed
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  test('loginWithPhoneOtp with fake token is rejected (client-side disabled)',
      () async {
    final controller = PlannerController();
    final rejected = await controller.loginWithPhoneOtp(
      phone: '9157661886',
      otpProofToken: 'fake_unverified_token',
    );
    // The method is disabled client-side; any call must return a non-null error.
    expect(rejected, isNotNull);
    expect(controller.isLoggedIn, isFalse);
    controller.dispose();
  });

  // ---------------------------------------------------------------------------
  test('getTenDigitPhone extracts exactly 10 digits from varied formats', () {
    final svc = WhatsAppOtpService.instance;
    expect(svc.getTenDigitPhone('9157661886'), '9157661886');
    expect(svc.getTenDigitPhone('+919157661886'), '9157661886');
    expect(svc.getTenDigitPhone('09157661886'), '9157661886');
    expect(svc.getTenDigitPhone('+91 91576 61886'), '9157661886');
    expect(svc.getTenDigitPhone('+91-91576-61886'), '9157661886');
  });

  // ---------------------------------------------------------------------------
  testWidgets('Switching between WhatsApp OTP and Password mode updates text field cleanly',
      (tester) async {
    final controller = PlannerController();
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(controller: controller, initialUseOtpMode: false)),
    );
    await tester.pumpAndSettle();

    // Switch to WhatsApp OTP
    await tester.tap(find.text('WhatsApp OTP'));
    await tester.pumpAndSettle();

    final phoneFieldInOtp = tester.widget<TextField>(find.byType(TextField).first);
    expect(phoneFieldInOtp.controller?.text.contains('@'), isFalse);
    expect(phoneFieldInOtp.controller?.text, '9157661886');

    // Switch back to Password / PIN
    await tester.tap(find.text('Password / PIN'));
    await tester.pumpAndSettle();

    final emailFieldInPwd = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailFieldInPwd.controller?.text, 'rbcsaurabhyadav@gmail.com');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

