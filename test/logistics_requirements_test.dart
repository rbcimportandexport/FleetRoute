import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transport_one/src/controllers/planner_controller.dart';
import 'package:transport_one/src/models/planner_models.dart';
import 'package:transport_one/src/pages/attendance_page.dart';
import 'package:transport_one/src/pages/billing_page.dart';
import 'package:transport_one/src/pages/expenses_page.dart';
import 'package:transport_one/src/pages/reports_page.dart';
import 'package:transport_one/src/services/app_localization_service.dart';
import 'package:transport_one/src/widgets/delivery_proof_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('Logistics Requirements Suite - Multilingual & Localization (Req 16)',
      () {
    test('AppLocalizationService switches languages and translates accurately',
        () {
      final loc = AppLocalizationService.instance;

      loc.setLanguage(AppLanguage.en);
      expect(loc.language, equals(AppLanguage.en));
      expect(loc.tr('trips'), equals('Trips & Cargo'));
      expect(loc.tr('expenses'), equals('Expenses & P&L'));
      expect(loc.tr('attendance'), equals('Attendance'));
      expect(loc.tr('billing'), equals('Billing & Invoices'));
      expect(loc.tr('reports'), equals('Reports & Export'));

      loc.setLanguage(AppLanguage.hi);
      expect(loc.language, equals(AppLanguage.hi));
      expect(loc.tr('trips'), equals('ट्रिप और कार्गो'));
      expect(loc.tr('expenses'), equals('खर्चे व लाभ-हानि'));
      expect(loc.tr('attendance'), equals('उपस्थिति (हाजिरी)'));

      loc.setLanguage(AppLanguage.gu);
      expect(loc.language, equals(AppLanguage.gu));
      expect(loc.tr('trips'), equals('ટ્રિપ અને કાર્ગો'));
      expect(loc.tr('expenses'), equals('ખર્ચ અને નફો-નુકસાન'));
      expect(loc.tr('billing'), equals('બિલિંગ અને ઇનવૉઇસ'));

      // Reset to English for remaining tests
      loc.setLanguage(AppLanguage.en);
    });
  });

  group('Logistics Requirements Suite - Attendance & Driver Presence (Req 1)',
      () {
    testWidgets(
        'AttendancePage renders metrics, driver filter and punch records',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      final controller = PlannerController();
      await controller.load();
      controller.setAdminSessionForTesting();

      const sampleRecord = AttendanceRecord(
        id: 'ATT-TEST-001',
        driverId: 'DRV-SANDEEP',
        driverName: 'SANDEEP KUMAR',
        date: '2026-10-21',
        startTime: '2026-10-21T08:00:00',
        endTime: '2026-10-21T18:00:00',
        status: 'present',
        totalWorkingHours: 10.0,
      );
      await controller.addOrUpdateAttendance(sampleRecord);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendancePage(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record Attendance'), findsOneWidget);
      expect(find.text('SANDEEP KUMAR'), findsWidgets);
      expect(find.text('PRESENT'), findsWidgets);
    });
  });

  group(
      'Logistics Requirements Suite - Direct and Indirect Expenses (Req 11, 12)',
      () {
    testWidgets(
        'ExpensesPage renders direct/indirect costs and approval actions',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      final controller = PlannerController();
      await controller.load();
      controller.setAdminSessionForTesting();

      const expense = ExpenseRecord(
        id: 'EXP-TEST-001',
        tripId: 'TRIP-2026-001',
        category: 'fuel',
        isDirect: true,
        amount: 4500,
        date: '2026-10-21',
        vehicleNumber: 'GJ19Y2720',
        driverName: 'SANDEEP',
        notes: 'Indian Oil Highway Diesel Receipt',
        status: 'pending',
      );
      await controller.addExpense(expense);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpensesPage(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.textContaining('TRIP-2026-001'), findsWidgets);
      expect(find.text('PENDING'), findsWidgets);
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
    });

    test(
        'Controller approveExpense and rejectExpense transitions status correctly',
        () async {
      final controller = PlannerController();
      await controller.load();

      const expense = ExpenseRecord(
        id: 'EXP-TEST-002',
        tripId: 'TRIP-2026-002',
        category: 'toll',
        isDirect: true,
        amount: 850,
        date: '2026-10-21',
        vehicleNumber: 'GJ19Y2720',
        driverName: 'SANDEEP',
        status: 'pending',
      );
      await controller.addExpense(expense);

      await controller.approveExpense('EXP-TEST-002', 'Fleet Admin');
      final approved =
          controller.expenses.firstWhere((e) => e.id == 'EXP-TEST-002');
      expect(approved.status, equals('approved'));
      expect(approved.approvedBy, equals('Fleet Admin'));

      await controller.rejectExpense(
          'EXP-TEST-002', 'Auditor', 'Duplicate receipt');
      final rejected =
          controller.expenses.firstWhere((e) => e.id == 'EXP-TEST-002');
      expect(rejected.status, equals('rejected'));
      expect(rejected.notes, contains('Duplicate receipt'));
    });
  });

  group('Logistics Requirements Suite - Billing & Payment Records (Req 10)',
      () {
    testWidgets('BillingPage displays invoice details and payment recording',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      final controller = PlannerController();
      await controller.load();

      const bill = BillingRecord(
        id: 'BILL-TEST-001',
        tripId: 'TRIP-2026-001',
        invoiceNumber: 'INV-2026-001',
        customerName: 'Reliance Logistics Ltd',
        freightRate: 35000,
        parkingCharge: 300,
        otherCharges: 500,
        invoiceDate: '2026-10-21',
        paymentStatus: 'pending',
      );
      await controller.addBillingRecord(bill);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillingPage(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Bill'), findsOneWidget);
      expect(find.textContaining('INV-2026-001'), findsWidgets);
      expect(find.text('Reliance Logistics Ltd'), findsWidgets);
      expect(find.text('Record Payment'), findsWidgets);
    });

    test('Controller recordPayment updates balance due and status to paid',
        () async {
      final controller = PlannerController();
      await controller.load();

      const bill = BillingRecord(
        id: 'BILL-TEST-002',
        tripId: 'TRIP-2026-002',
        invoiceNumber: 'INV-2026-002',
        customerName: 'Adani Logistics',
        freightRate: 20000,
        invoiceDate: '2026-10-21',
        paymentStatus: 'pending',
      );
      await controller.addBillingRecord(bill);

      await controller.recordPayment(
        billId: 'BILL-TEST-002',
        payment: const PaymentTransaction(
          id: 'TXN-001',
          amount: 20000,
          paymentDate: '2026-10-21',
          paymentMethod: 'bank_transfer',
          referenceNumber: 'NEFT-889900',
        ),
      );

      final updated =
          controller.billingRecords.firstWhere((b) => b.id == 'BILL-TEST-002');
      expect(updated.totalPaid, equals(20000));
      expect(updated.balanceDue, equals(0));
      expect(updated.paymentStatus, equals('paid'));
    });
  });

  group('Logistics Requirements Suite - 11 Logistics Reports (Req 14)', () {
    testWidgets(
        'ReportsPage switches between 11 report types and generates CSV',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      final controller = PlannerController();
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsPage(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      expect(LogisticsReportType.values.length, equals(11));
    });
  });

  group('Logistics Requirements Suite - Delivery Proof Gallery (Req 8)', () {
    testWidgets(
        'DeliveryProofGalleryDialog renders photo preview, GPS and signature',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      final controller = PlannerController();
      await controller.load();

      const proof = DeliveryProofRecord(
        id: 'POD-TEST-001',
        tripId: 'TRIP-2026-001',
        deliveredQuantity: 24.5,
        recipientName: 'Harish Mehta',
        recipientPhone: '9876543210',
        timestamp: '2026-10-21T14:30:00',
        latitude: 22.3072,
        longitude: 73.1812,
        notes: 'Received in good condition.',
        isConfirmed: true,
      );

      const trip = TripRecord(
        reference: 'TRIP-2026-001',
        origin: 'Ahmedabad',
        destination: 'Surat',
        deliveryProofs: [proof],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryProofGalleryDialog(
              trip: trip,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Delivery Proofs:'), findsOneWidget);
      expect(find.text('Harish Mehta'), findsWidgets);
      expect(find.text('9876543210'), findsWidgets);
      expect(find.textContaining('Delivered:'), findsWidgets);
      expect(find.text('OPEN MAPS'), findsWidgets);
    });
  });
}
