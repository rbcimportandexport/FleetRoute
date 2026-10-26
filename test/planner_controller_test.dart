import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/services/app_security_service.dart';
import 'package:transport_one/src/services/route_traffic_service.dart';

import 'package:transport_one/src/services/firebase_auth_service.dart';
import 'package:transport_one/src/services/safety_notification_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AppSecurityService.resetFailedAttempts();
    AppSecurityService.resetDeviceSecretForTesting();
    FirebaseAuthService.instance.testAuthHandler = (email, password) async {
      final norm = email.trim().toLowerCase();
      if (password == 'wrongpassword' || password == '999999') {
        throw const FormatException('Invalid credentials. Access denied.');
      }
      if (norm == 'admin' || norm == 'rbcsaurabhyadav@gmail.com') {
        return const AuthenticatedFleetUser(
          uid: 'admin_test_uid',
          email: 'rbcsaurabhyadav@gmail.com',
          name: 'Super Admin',
          role: 'admin',
        );
      }
      // Resolve phone numbers to the known test driver email
      final digits = norm.replaceAll(RegExp(r'\D'), '');
      if (digits == '9876543210') {
        return const AuthenticatedFleetUser(
          uid: 'driver_mahesh_uid',
          email: 'mahesh.yadav@transport.com',
          name: 'Mahesh Yadav',
          role: 'driver',
          assignedVehicle: 'MH-04-TR-4825',
        );
      }
      return AuthenticatedFleetUser(
        uid: 'driver_test_uid',
        email: norm.contains('@') ? norm : '$norm@transport.com',
        name: 'Mahesh Yadav',
        role: 'driver',
        assignedVehicle: 'MH-04-TR-4825',
      );
    };
  });

  tearDown(() {
    FirebaseAuthService.instance.testAuthHandler = null;
  });
  test('route input becomes complete only after both locations are set', () {
    final controller = PlannerController();
    expect(controller.canShowRoute, isFalse);

    controller.setOrigin('Mumbai');
    expect(controller.canShowRoute, isFalse);

    controller.setDestination('Delhi');
    expect(controller.canShowRoute, isTrue);

    expect(controller.canShowRoute, isTrue);
  });

  test('swap reverses origin and destination', () {
    final controller = PlannerController()
      ..setOrigin('Mumbai')
      ..setDestination('Delhi');

    controller.swapLocations();

    expect(controller.origin, 'Delhi');
    expect(controller.destination, 'Mumbai');
  });

  test('invalid saved collections do not prevent other records from loading',
      () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'transport_one.sec_ctx',
      AppSecurityService.activeSecret,
    );
    await preferences.setString(
      'transport_one.drivers',
      AppSecurityService.encryptPayload('{"invalid":"not a list"}'),
    );
    await preferences.setString(
      'transport_one.trips',
      AppSecurityService.encryptPayload(
        jsonEncode([
          const TripRecord(
            reference: 'RECOVERED-1',
            origin: 'Mumbai',
            destination: 'Pune',
          ).toJson(),
        ]),
      ),
    );

    final controller = PlannerController(preferences: preferences);
    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.drivers, isEmpty);
    expect(controller.trips.single.reference, 'RECOVERED-1');
  });

  test('clearAllFleetData removes seatbelt records from memory and storage',
      () async {
    final preferences = SharedPreferencesAsync();
    final controller = PlannerController(preferences: preferences);
    await controller.addSeatbeltRecord(
      SeatbeltRecord(
        id: 'TO-CLEAR',
        driverName: 'Driver',
        driverId: 'driver@example.com',
        vehicleNumber: 'MH-01-AA-0001',
        photoBase64: 'photo',
        timestamp: DateTime(2026, 10, 19),
        isApproved: true,
      ),
    );

    await controller.clearAllFleetData();
    expect(controller.seatbeltRecords, isEmpty);

    final reloaded = PlannerController(preferences: preferences);
    await reloaded.load();
    expect(reloaded.seatbeltRecords, isEmpty);
  });

  test('authenticated drivers cannot promote their role through view state',
      () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();
    await controller.addDriver(
      const DriverProfile(
        'Driver One',
        'driver@example.com',
        password: 'password123',
      ),
    );
    controller.setDriverSessionForTesting(
      email: 'driver@example.com',
      name: 'Driver One',
    );

    controller.setRole('admin');

    expect(controller.currentRole, 'driver');
    expect(controller.isAdmin, isFalse);
  });

  test('driver login selects the matching profile instead of the first driver',
      () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();
    await controller.addDriver(
      const DriverProfile('First Driver', 'first@example.com',
          password: 'password111'),
    );
    await controller.addDriver(
      const DriverProfile(
        'Logged In Driver',
        'logged-in@example.com',
        password: 'password222',
      ),
    );
    controller.setDriverSessionForTesting(
      email: 'logged-in@example.com',
      name: 'Logged In Driver',
    );

    expect(controller.selectedDriver?.email, 'logged-in@example.com');
    expect(controller.selectedDriver?.name, 'Logged In Driver');
  });

  test('alert state changes preserve user-entered alert details', () {
    const alert = OperationsAlert(
      title: 'Tyre pressure warning',
      details: 'Driver reported low pressure.',
      severity: 'warning',
      createdAt: '2026-10-18T10:00:00.000',
    );

    final resolved = alert.copyWith(isRead: true, isResolved: true);

    expect(resolved.title, alert.title);
    expect(resolved.details, alert.details);
    expect(resolved.isRead, isTrue);
    expect(resolved.isResolved, isTrue);
  });

  test('trip status update preserves both pinned coordinates', () {
    const trip = TripRecord(
      reference: 'TRIP-1',
      origin: '19.076000, 72.877700',
      destination: '18.520400, 73.856700',
      stops: ['19.100000, 73.000000'],
    );

    final active = trip.copyWith(status: 'in_progress');

    expect(active.origin, trip.origin);
    expect(active.destination, trip.destination);
    expect(active.stops, trip.stops);
    expect(active.status, 'in_progress');
  });

  test('setRoute replaces stale stops atomically', () {
    final controller = PlannerController()
      ..setRoute(
        newOrigin: 'Surat',
        newDestination: 'Bardoli',
        newStops: ['Kamrej', '  ', 'Navsari'],
      );

    expect(controller.origin, 'Surat');
    expect(controller.destination, 'Bardoli');
    expect(controller.stops, ['Kamrej', 'Navsari']);

    controller.setRoute(
      newOrigin: 'Mumbai',
      newDestination: 'Pune',
    );
    expect(controller.stops, isEmpty);
  });

  test('extending a route preserves the order in which drops were pinned', () {
    final controller = PlannerController()
      ..setRoute(
        newOrigin: 'Surat',
        newDestination: 'Bardoli',
      )
      ..extendRouteTo('Kamrej')
      ..extendRouteTo('Navsari');

    expect(controller.stops, ['Bardoli', 'Kamrej']);
    expect(controller.destination, 'Navsari');
    expect(
      controller.allLocations,
      ['Surat', 'Bardoli', 'Kamrej', 'Navsari'],
    );
  });

  test('TripRecord persists via stops and reads legacy records', () {
    const trip = TripRecord(
      reference: 'WITH-STOPS',
      origin: 'Surat',
      destination: 'Bardoli',
      stops: ['Kamrej', 'Navsari'],
    );
    expect(TripRecord.fromJson(trip.toJson()).stops, trip.stops);

    final legacy = TripRecord.fromJson({
      'reference': 'LEGACY',
      'origin': 'Mumbai',
      'destination': 'Pune',
    });
    expect(legacy.stops, isEmpty);
  });

  test('saved models recover from older numeric and malformed field types', () {
    final truck = TruckModel.fromJson({
      'code': 101,
      'name': 'Legacy Truck',
      'axles': '6x2',
      'capacity': '20T',
      'maxSpeed': 79.8,
    });
    expect(truck.code, '101');
    expect(truck.maxSpeed, 79);

    final trip = TripRecord.fromJson({
      'reference': 42,
      'origin': 'Surat',
      'destination': 'Bardoli',
      'stops': 'not-a-list',
      'status': 1,
    });
    expect(trip.reference, '42');
    expect(trip.stops, isEmpty);
    expect(trip.status, '1');

    final driver = DriverProfile.fromJson({
      'name': 123,
      'phone': 9876543210,
      'role': null,
    });
    expect(driver.name, '123');
    expect(driver.email, '9876543210');
    expect(driver.role, 'driver');

    final alert = OperationsAlert.fromJson({
      'title': 404,
      'details': true,
      'fineAmount': '1250',
      'isRead': 'true',
      'isResolved': 1,
    });
    expect(alert.title, '404');
    expect(alert.details, 'true');
    expect(alert.fineAmount, 1250);
    expect(alert.isRead, isTrue);
    expect(alert.isResolved, isTrue);

    final activity = ActivityEvent.fromJson({
      'id': 7,
      'title': false,
      'timestamp': 123,
      'category': 'unknown',
    });
    expect(activity.id, '7');
    expect(activity.title, 'false');
    expect(activity.category, ActivityCategory.planner);

    final seatbelt = SeatbeltRecord.fromJson({
      'id': 9,
      'driverName': 10,
      'timestamp': '2026-10-20T10:00:00.000',
      'isApproved': 'yes',
    });
    expect(seatbelt.id, '9');
    expect(seatbelt.driverName, '10');
    expect(seatbelt.isApproved, isTrue);
  });

  test('extendRouteTo rejects an empty destination without corrupting route',
      () {
    final controller = PlannerController()
      ..setRoute(newOrigin: 'Surat', newDestination: 'Bardoli');

    controller.extendRouteTo('   ');

    expect(controller.origin, 'Surat');
    expect(controller.destination, 'Bardoli');
    expect(controller.stops, isEmpty);
  });

  test('operations automatically record live activity events', () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();

    await controller.addDriver(const DriverProfile(
        'Rajesh Kumar', 'rajesh@fleetroute.com',
        password: 'passwordRajesh1'));
    expect(controller.activities.length, 1);
    expect(controller.activities.first.title, 'Driver Added');
    expect(controller.activities.first.category, ActivityCategory.driver);
    expect(controller.activities.first.action, 'added');

    await controller.addTruckModel(const TruckModel(
      code: 'TRK-101',
      name: 'Ashok Leyland 2820',
      axles: '6x2',
      capacity: '20T',
      maxSpeed: 80,
    ));
    expect(controller.activities.length, 2);
    expect(controller.activities.first.title, 'Vehicle Added');
    expect(controller.activities.first.category, ActivityCategory.vehicle);

    await controller.addTrip(const TripRecord(
      reference: 'EXP-900',
      origin: 'Mumbai',
      destination: 'Pune',
    ));
    expect(controller.activities.length, 3);
    expect(controller.activities.first.title, 'Trip Created');
    expect(controller.activities.first.category, ActivityCategory.trip);

    await controller.addAlert(const OperationsAlert(
      title: 'Road Blockage NH48',
      details: 'Heavy traffic due to maintenance',
      severity: 'warning',
    ));
    expect(controller.activities.length, 4);
    expect(controller.activities.first.title, 'Alert Created');
    expect(controller.activities.first.category, ActivityCategory.alert);

    await controller.toggleAlertResolved(0);
    expect(controller.activities.length, 5);
    expect(controller.activities.first.title, 'Alert Resolved');

    await controller.clearActivities();
    expect(controller.activities, isEmpty);
  });

  test('RouteTrafficService parses coordinate strings and major hubs', () {
    final p1 = RouteTrafficService.parseLocation('23.217324, 69.775857');
    expect(p1, isNotNull);
    expect(p1!.latitude, closeTo(23.217324, 0.0001));
    expect(p1.longitude, closeTo(69.775857, 0.0001));

    final p2 = RouteTrafficService.parseLocation('Surat');
    expect(p2, isNotNull);
    expect(p2!.latitude, closeTo(21.1702, 0.01));
  });

  test('RouteTrafficService calculates traffic report and vehicle duration',
      () {
    final report = RouteTrafficService.analyzeTraffic(
      distanceKm: 600,
      vehicle: VehicleType.truck,
    );

    expect(report.distanceKm, 600);
    expect(report.duration.inHours, greaterThanOrEqualTo(10));
    expect(report.delayMinutes, greaterThan(0));
    expect(report.summaryHindi, isNotEmpty);
  });

  test('OperationsAlert supports memo, overspeeding, and seatbelt categories',
      () async {
    final controller = PlannerController();

    await controller.logChallanMemo(
      challanNumber: 'MH-CH-2026-9901',
      fineAmount: 2000,
      reason: 'Signal Jumping',
      vehicleNumber: 'MH-12-RN-8841',
      location: 'NH-48 Kamrej',
    );
    expect(controller.alerts.length, 1);
    final memo = controller.alerts.first;
    expect(memo.isMemo, isTrue);
    expect(memo.challanNumber, 'MH-CH-2026-9901');
    expect(memo.fineAmount, 2000);
    expect(memo.category, 'memo');

    await controller.logOverspeedAlert(
      speed: 95.0,
      speedLimit: 80.0,
      vehicleNumber: 'GJ-05-BX-4912',
      location: 'NH-48 Surat',
    );
    expect(controller.alerts.length, 2);
    final overspeed = controller.alerts[1];
    expect(overspeed.isOverspeed, isTrue);
    expect(overspeed.category, 'overspeed');
    expect(overspeed.severity, 'critical');

    await controller.logSeatbeltAlert(
      vehicleNumber: 'GJ-05-BX-4912',
      location: 'Bardoli Corridor',
      driverPhoto: 'data:image/jpeg;base64,samplephoto123',
    );
    expect(controller.alerts.length, 3);
    final seatbelt = controller.alerts[2];
    expect(seatbelt.isSeatbelt, isTrue);
    expect(seatbelt.category, 'seatbelt');
    expect(seatbelt.driverPhoto, 'data:image/jpeg;base64,samplephoto123');

    // Test updateAlertPhoto on an existing alert
    await controller.updateAlertPhoto(
        0, 'data:image/jpeg;base64,attached_memo_receipt');
    expect(controller.alerts[0].driverPhoto,
        'data:image/jpeg;base64,attached_memo_receipt');
  });

  test('DriverProfile supports optional photo attachment', () {
    const driver = DriverProfile('Ramesh Patel', '9876543210',
        photo: 'data:image/jpeg;base64,driverface');
    expect(driver.photo, 'data:image/jpeg;base64,driverface');
    final json = driver.toJson();
    final restored = DriverProfile.fromJson(json);
    expect(restored.photo, 'data:image/jpeg;base64,driverface');
  });

  test('SafetyNotificationService executes without throwing in any environment',
      () {
    expect(
        () => SafetyNotificationService.requestPermission(), returnsNormally);
    expect(
      () => SafetyNotificationService.notifyDriverSafety(
        title: 'Safety Test',
        body: 'Testing notification fallback',
        isRejected: true,
      ),
      returnsNormally,
    );
    expect(
      () => SafetyNotificationService.pickDriverPhoto(
        useCamera: true,
        onPhotoSelected: (_) {},
      ),
      returnsNormally,
    );
  });

  test('SeatbeltRecord serialization and roundtrip test', () {
    final record = SeatbeltRecord(
      id: 'REC-001',
      driverName: 'Rajesh Kumar',
      driverId: 'rajesh@fleetroute.com',
      vehicleNumber: 'MH-12-RN-8841',
      photoBase64: 'data:image/jpeg;base64,samplephoto123',
      timestamp: DateTime(2026, 10, 19, 14, 30),
      isApproved: true,
      location: 'NH-48 Surat Corridor',
      notes: 'Seatbelt fastened properly',
    );

    final json = record.toJson();
    expect(json['id'], 'REC-001');
    expect(json['driverName'], 'Rajesh Kumar');
    expect(json['driverId'], 'rajesh@fleetroute.com');
    expect(json['vehicleNumber'], 'MH-12-RN-8841');
    expect(json['isApproved'], true);
    expect(json['location'], 'NH-48 Surat Corridor');

    final restored = SeatbeltRecord.fromJson(json);
    expect(restored.id, record.id);
    expect(restored.driverName, record.driverName);
    expect(restored.driverId, record.driverId);
    expect(restored.vehicleNumber, record.vehicleNumber);
    expect(restored.photoBase64, record.photoBase64);
    expect(restored.timestamp, record.timestamp);
    expect(restored.isApproved, true);
    expect(restored.location, record.location);
    expect(restored.notes, record.notes);
  });

  test('PlannerController seatbelt records role-based filtering test',
      () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();

    // Add 2 drivers to controller
    await controller.addDriver(const DriverProfile(
        'Rajesh Kumar', 'rajesh@fleetroute.com',
        password: 'passwordRajesh1'));
    await controller.addDriver(const DriverProfile(
        'Suresh Verma', 'suresh@fleetroute.com',
        password: 'passwordSuresh1'));

    // Add seatbelt records for Rajesh
    await controller.addSeatbeltRecord(
      SeatbeltRecord(
        id: 'REC-001',
        driverName: 'Rajesh Kumar',
        driverId: 'rajesh@fleetroute.com',
        vehicleNumber: 'MH-12-RN-8841',
        photoBase64: 'data:image/jpeg;base64,rajesh_photo_1',
        timestamp: DateTime(2026, 10, 19, 10, 0),
        isApproved: true,
        location: 'Mumbai Hub',
      ),
    );
    await controller.addSeatbeltRecord(
      SeatbeltRecord(
        id: 'REC-002',
        driverName: 'Rajesh Kumar',
        driverId: 'rajesh@fleetroute.com',
        vehicleNumber: 'MH-12-RN-8841',
        photoBase64: 'data:image/jpeg;base64,rajesh_photo_2',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        isApproved: false,
        location: 'Thane Toll Plaza',
      ),
    );

    // Add seatbelt record for Suresh
    await controller.addSeatbeltRecord(
      SeatbeltRecord(
        id: 'REC-003',
        driverName: 'Suresh Verma',
        driverId: 'suresh@fleetroute.com',
        vehicleNumber: 'GJ-05-BX-4912',
        photoBase64: 'data:image/jpeg;base64,suresh_photo_1',
        timestamp: DateTime(2026, 10, 19, 11, 0),
        isApproved: true,
        location: 'Surat Ring Road',
      ),
    );

    // Total records stored
    expect(controller.seatbeltRecords.length, 3);

    // 1. Admin Role: Can see ALL records across all drivers
    controller.setAdminSessionForTesting();
    expect(controller.isAdmin, isTrue);
    expect(controller.visibleSeatbeltRecords.length, 3);

    // 2. Driver Role: Rajesh's account
    controller.setDriverSessionForTesting(
      email: 'rajesh@fleetroute.com',
      name: 'Rajesh Kumar',
    );
    expect(controller.isDriver, isTrue);
    expect(controller.activeDriverEmail, 'rajesh@fleetroute.com');

    // Only Rajesh's records are visible (2 records)
    final rajeshVisible = controller.visibleSeatbeltRecords;
    expect(rajeshVisible.length, 2);
    expect(rajeshVisible.every((r) => r.driverId == 'rajesh@fleetroute.com'),
        isTrue);

    // 3. Driver Role: Suresh's account
    controller.setDriverSessionForTesting(
      email: 'suresh@fleetroute.com',
      name: 'Suresh Verma',
    );
    expect(controller.activeDriverEmail, 'suresh@fleetroute.com');

    // Only Suresh's records are visible (1 record)
    final sureshVisible = controller.visibleSeatbeltRecords;
    expect(sureshVisible.length, 1);
    expect(sureshVisible.first.driverName, 'Suresh Verma');
    expect(sureshVisible.first.vehicleNumber, 'GJ-05-BX-4912');

    // 4. Record deletion & clear
    controller.setAdminSessionForTesting();
    final firstId = controller.seatbeltRecords.first.id;
    await controller.removeSeatbeltRecord(firstId);
    expect(controller.seatbeltRecords.length, 2);

    await controller.clearSeatbeltRecords();
    expect(controller.seatbeltRecords, isEmpty);
    expect(controller.visibleSeatbeltRecords, isEmpty);
  });

  test('Super Admin login flow and privileges', () async {
    final controller = PlannerController();
    expect(controller.isLoggedIn, isFalse);

    // 1. Invalid password fails
    final failResult = await controller.login(
      email: 'admin',
      password: 'wrongpassword',
    );
    expect(failResult, isNotNull);
    expect(failResult, contains('Invalid credentials'));
    expect(controller.isLoggedIn, isFalse);

    // 2. Case-insensitive valid explicit admin identifier and default admin password succeeds
    final successResult = await controller.login(
      email: 'ADMIN',
      password: 'admin123',
    );
    expect(successResult, isNull);
    expect(controller.isLoggedIn, isTrue);
    expect(controller.isAdmin, isTrue);
    expect(controller.loggedInRole, 'admin');

    // 3. Logout clears session
    await controller.logout();
    expect(controller.isLoggedIn, isFalse);
    expect(controller.loggedInEmail, isNull);
    expect(controller.loggedInRole, isNull);
  });

  test('Admin directly creates Driver ID and Driver authenticates successfully',
      () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();

    // 1. Admin creates a new driver account
    const newDriver = DriverProfile(
      'Mahesh Yadav',
      'mahesh.yadav@transport.com',
      phone: '9876543210',
      password: 'PIN-9021',
      assignedVehicle: 'MH-04-TR-4825',
      role: 'driver',
    );
    await controller.addDriver(newDriver);
    expect(controller.drivers.length, 1);
    // PIN is salted and hashed - not stored in plaintext
    expect(controller.drivers.first.password, isNot('PIN-9021'));
    expect(controller.drivers.first.password, isNotEmpty);

    // Clear admin test session before testing login
    await controller.logout();

    // 2. Attempt login with wrong password
    final wrongPass = await controller.login(
      email: 'mahesh.yadav@transport.com',
      password: '999999',
    );
    expect(wrongPass, isNotNull);
    expect(wrongPass, contains('Invalid credentials'));
    expect(controller.isLoggedIn, isFalse);

    // 3. Login with driver email and admin-assigned PIN
    final loginSuccess = await controller.login(
      email: 'mahesh.yadav@transport.com',
      password: 'PIN-9021',
    );
    expect(loginSuccess, isNull);
    expect(controller.isLoggedIn, isTrue);
    expect(controller.isDriver, isTrue);
    expect(controller.loggedInEmail, 'mahesh.yadav@transport.com');
    expect(controller.loggedInName, 'Mahesh Yadav');
    expect(controller.activeDriverEmail, 'mahesh.yadav@transport.com');

    // 4. Driver logout
    await controller.logout();
    expect(controller.isLoggedIn, isFalse);

    // 5. Driver can also log in using their phone number
    final phoneLoginSuccess = await controller.login(
      email: '9876543210',
      password: 'PIN-9021',
    );
    expect(phoneLoginSuccess, isNull);
    expect(controller.isLoggedIn, isTrue);
    expect(controller.loggedInEmail, 'mahesh.yadav@transport.com');
  });

  test('multi-stop route management adds, updates, removes, and swaps stops',
      () {
    final controller = PlannerController();
    controller.setOrigin('Bardoli');
    controller.setDestination('Kamrej');

    expect(controller.stops, isEmpty);
    expect(controller.allLocations, ['Bardoli', 'Kamrej']);
    expect(controller.routePathSummary, 'Bardoli -> Kamrej');

    // Add intermediate stop: Surat
    controller.addStop('Surat');
    expect(controller.stops, ['Surat']);
    expect(controller.allLocations, ['Bardoli', 'Surat', 'Kamrej']);
    expect(controller.routePathSummary, 'Bardoli -> Surat -> Kamrej');

    // Add second stop: Navsari
    controller.addStop('Navsari');
    expect(controller.stops, ['Surat', 'Navsari']);
    expect(controller.allLocations, ['Bardoli', 'Surat', 'Navsari', 'Kamrej']);

    // Update stop
    controller.updateStop(1, 'Kim');
    expect(controller.stops, ['Surat', 'Kim']);

    // Swap locations reverses origin, destination, and intermediate stops
    controller.swapLocations();
    expect(controller.origin, 'Kamrej');
    expect(controller.destination, 'Bardoli');
    expect(controller.stops, ['Kim', 'Surat']);
    expect(controller.routePathSummary, 'Kamrej -> Kim -> Surat -> Bardoli');

    // Remove stop
    controller.removeStop(0);
    expect(controller.stops, ['Surat']);

    // Clear route clears stops as well
    controller.clearRoute();
    expect(controller.origin, isEmpty);
    expect(controller.destination, isEmpty);
    expect(controller.stops, isEmpty);
  });

  test('RouteTrafficService parses Bardoli, Kamrej, Surat, and coordinates',
      () {
    final bardoli = RouteTrafficService.parseLocation('Bardoli');
    expect(bardoli, isNotNull);
    expect(bardoli!.latitude, closeTo(21.1215, 0.01));
    expect(bardoli.longitude, closeTo(73.1118, 0.01));

    final kamrej = RouteTrafficService.parseLocation('Kamrej');
    expect(kamrej, isNotNull);
    expect(kamrej!.latitude, closeTo(21.2709, 0.01));

    final surat = RouteTrafficService.parseLocation('Surat');
    expect(surat, isNotNull);
    expect(surat!.latitude, closeTo(21.1702, 0.01));

    // Custom non-fixed coordinate pin tap
    final customPin = RouteTrafficService.parseLocation('21.250000, 73.050000');
    expect(customPin, isNotNull);
    expect(customPin!.latitude, 21.25);
    expect(customPin.longitude, 73.05);
  });

  test(
      'driver role cannot escalate to admin privilege via setRole or currentRole',
      () async {
    final controller = PlannerController();
    await controller.load();

    controller.isLoggedIn = true;
    controller.loggedInRole = 'driver';
    controller.loggedInEmail = 'driver@example.com';
    controller.currentRole = 'driver';

    expect(controller.isAdmin, isFalse);
    expect(controller.isDriver, isTrue);

    // Attempt role elevation via setRole
    controller.setRole('admin');
    expect(controller.currentRole, 'driver');
    expect(controller.isAdmin, isFalse);

    // Even if currentRole is forced to admin in memory, isAdmin getter checks loggedInRole
    controller.currentRole = 'admin';
    expect(controller.isAdmin, isFalse);
  });

  test(
      'retention limits: alerts capped to 100 and seatbelt records capped to 50',
      () async {
    final controller = PlannerController();
    await controller.load();

    // Fill alerts beyond 100
    for (int i = 0; i < 110; i++) {
      await controller.addAlert(
        OperationsAlert(
          title: 'Alert $i',
          details: 'Details $i',
          severity: 'info',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    expect(controller.alerts.length, 100);

    // Fill seatbelt records beyond 50
    for (int i = 0; i < 55; i++) {
      await controller.addSeatbeltRecord(
        SeatbeltRecord(
          id: 'rec_$i',
          driverName: 'Driver $i',
          driverId: 'drv_$i',
          vehicleNumber: 'TRUCK01',
          photoBase64: 'photo_$i',
          timestamp: DateTime.now(),
          isApproved: true,
        ),
      );
    }
    expect(controller.seatbeltRecords.length, 50);
  });

  test(
      'addTruckModel and addDriver throw ArgumentError on duplicate or invalid entries',
      () async {
    final controller = PlannerController();
    await controller.load();
    controller.setAdminSessionForTesting();

    await controller.addTruckModel(
      const TruckModel(
        code: 'GJ19Y2720',
        name: 'Baseline Truck',
        axles: '2 Axles',
        capacity: '10 Ton',
      ),
    );
    await controller.addDriver(
      const DriverProfile('Baseline Driver', 'baseline@transport.com',
          password: 'passwordBaseline1'),
    );

    // Duplicate vehicle code
    expect(
      () => controller.addTruckModel(
        const TruckModel(
          code: 'GJ19Y2720',
          name: 'Duplicate Truck',
          axles: '2 Axles',
          capacity: '10 Ton',
        ),
      ),
      throwsArgumentError,
    );

    // Invalid max speed
    expect(
      () => controller.addTruckModel(
        const TruckModel(
          code: 'NEW01',
          name: 'Speedy Truck',
          axles: '2 Axles',
          capacity: '10 Ton',
          maxSpeed: 200,
        ),
      ),
      throwsArgumentError,
    );

    // Duplicate driver email
    final existingEmail = controller.drivers.first.email;
    expect(
      () => controller.addDriver(
        DriverProfile('Duplicate', existingEmail),
      ),
      throwsArgumentError,
    );

    // Short PIN
    expect(
      () => controller.addDriver(
        const DriverProfile('Short PIN', 'newunique@transport.com',
            password: '12'),
      ),
      throwsArgumentError,
    );
  });

  test('service kilometres reject fake values and never auto-add 10000 km',
      () async {
    final controller = PlannerController();
    controller.setAdminSessionForTesting();
    await controller.addTruckModel(
      const TruckModel(
        code: 'REAL-KM-01',
        name: 'Service Test Truck',
        axles: '2 Axles',
        capacity: '10 Ton',
        currentOdometerKm: 50000,
      ),
    );

    final rollback = await controller.addVehicleServiceLog(
      vehicleCode: 'REAL-KM-01',
      service: const VehicleServiceRecord(
        id: 'SRV-ROLLBACK',
        serviceDate: '2026-10-23',
        odometerKm: 49000,
        garageName: 'Real Garage',
      ),
    );
    expect(rollback, isNotNull);
    expect(controller.truckModels.first.serviceHistory, isEmpty);

    final saved = await controller.addVehicleServiceLog(
      vehicleCode: 'REAL-KM-01',
      service: const VehicleServiceRecord(
        id: 'SRV-REAL',
        serviceDate: '2026-10-23',
        odometerKm: 50500,
        garageName: 'Real Garage',
      ),
    );
    expect(saved, isNull);
    expect(controller.truckModels.first.currentOdometerKm, 50500);
    expect(controller.truckModels.first.nextServiceKm, 0);

    final explicitSchedule = await controller.addVehicleServiceLog(
      vehicleCode: 'REAL-KM-01',
      service: const VehicleServiceRecord(
        id: 'SRV-REAL-2',
        serviceDate: '2026-10-24',
        odometerKm: 50600,
        garageName: 'Real Garage',
      ),
      nextServiceKm: 60000,
    );
    expect(explicitSchedule, isNull);
    expect(controller.truckModels.first.nextServiceKm, 60000);
    controller.dispose();
  });

  test('RBC/RAMA cargo product details and photo survive persistence', () {
    const item = CargoItem(
      id: 'cargo-rbc-419',
      productId: 'rbc-chair-419',
      productName: 'RBC - 419 GOLDEN',
      brand: 'RBC',
      category: 'CHAIR',
      photoAsset: 'assets/product_catalog/rbc/chair/419-golden.jpg',
      loadedQuantity: 4,
      unit: 'Pieces',
    );
    final restored = CargoItem.fromJson(item.toJson());
    expect(restored.brand, 'RBC');
    expect(restored.category, 'CHAIR');
    expect(restored.photoAsset, contains('product_catalog'));
    expect(restored.loadedQuantity, 4);
  });

  test('trip route, traffic and completion metrics survive persistence', () {
    const trip = TripRecord(
      reference: 'TRIP-HISTORY-1',
      origin: '21.1702, 72.8311',
      destination: '21.7051, 72.9959',
      assignedVehicle: 'GJ-01-AA-1001',
      assignedDriver: 'Test Driver',
      cargoDescription: 'RBC Chair',
      createdAt: '2026-10-24T09:00:00',
      startedAt: '2026-10-24T09:15:00',
      completedAt: '2026-10-24T10:45:00',
      plannedDistanceKm: 64.5,
      plannedDurationMinutes: 105,
      trafficSummary: 'Moderate highway traffic',
      actualDistanceKm: 67.2,
      averageSpeedKmh: 44.8,
      status: 'completed',
    );
    final restored = TripRecord.fromJson(trip.toJson());
    expect(restored.plannedDistanceKm, 64.5);
    expect(restored.plannedDurationMinutes, 105);
    expect(restored.trafficSummary, 'Moderate highway traffic');
    expect(restored.actualDistanceKm, 67.2);
    expect(restored.averageSpeedKmh, 44.8);
    expect(restored.actualDuration, const Duration(minutes: 90));
  });
}
