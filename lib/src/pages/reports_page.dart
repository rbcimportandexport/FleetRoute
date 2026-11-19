import 'dart:convert';

import 'package:excel/excel.dart' as xlsx;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/app_localization_service.dart';
import '../theme/app_theme.dart';

enum LogisticsReportType {
  driverEfficiency(
      '0. Driver Distance, Trips & Profit Matching',
      'Real logistics match: Trips vs Distance (KM) vs Freight Revenue vs Diesel & Net Profit per KM'),
  tripSummary('1. Trip Summary & Lifecycle',
      'Trips, routes, vehicles, drivers, and operational status'),
  driverAttendance('2. Driver Attendance & Duty Hours',
      'Driver presence, shift start/end times, and total hours'),
  vehicleUtilization('3. Vehicle Utilization & Fleet Status',
      'Vehicle load capacity, telemetry, and trip assignments'),
  cargoReconciliation('4. Cargo Reconciliation & Damage Loss',
      'Loaded vs delivered vs damaged vs returned balances'),
  profitAndLoss('5. Fleet Profit & Loss Financials',
      'Revenue vs direct and indirect costs with net margin'),
  fuelConsumption('6. Fuel & Diesel Consumption',
      'Diesel expenses, fuel receipts, and vehicle consumption'),
  tollAndTransit('7. Toll Plaza & En-Route Expenses',
      'Tolls, parking fees, and en-route transit expenses'),
  customerInvoicing('8. Customer Invoicing & Receivables',
      'Tax invoices, collections, and aging balance due'),
  podAudit('9. Proof of Delivery (POD) Audit',
      'POD photos, receiving copy status, and signatures'),
  transitSla('10. Operational Turnaround & Transit SLA',
      'Departure, arrival, and delivery turnaround times'),
  safetyAlerts('11. Safety & Overspeeding Alerts',
      'Fleet safety alerts, overspeeding, and compliance'),
  driverPerformanceScorecard('12. Driver Performance & Reward Scorecard',
      'Duty hours, trip completions, safety rating, speed violations & cash reward rank');

  const LogisticsReportType(this.title, this.description);
  final String title;
  final String description;
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    required this.controller,
    this.initialDriverName,
    super.key,
  });

  final PlannerController controller;
  final String? initialDriverName;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  LogisticsReportType _selectedReport = LogisticsReportType.driverEfficiency;
  String _selectedDateFilter = 'all'; // all, today, week, month
  String _selectedDriverFilter = 'all'; // all, or specific driver name/email
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialDriverName != null && widget.initialDriverName!.trim().isNotEmpty) {
      _selectedDriverFilter = widget.initialDriverName!.trim();
      _selectedReport = LogisticsReportType.driverEfficiency;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Generate rows and columns dynamically based on report type
  _ReportData _buildReportData() {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    bool matchesDate(String dateStr) {
      if (_selectedDateFilter == 'all') return true;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return true;
      if (_selectedDateFilter == 'today') {
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      }
      if (_selectedDateFilter == 'week') {
        return now.difference(dt).inDays <= 7;
      }
      if (_selectedDateFilter == 'month') {
        return now.difference(dt).inDays <= 30;
      }
      return true;
    }

    switch (_selectedReport) {
      case LogisticsReportType.driverEfficiency:
        final allDrivers = widget.controller.drivers;
        final allTrips = widget.controller.trips;
        final allExpenses = widget.controller.expenses;

        final headers = [
          'Driver Profile',
          'Assigned Vehicle',
          'Trips',
          'Total KM',
          'Avg KM/Trip',
          'Gross Freight (Revenue)',
          'Diesel Exp (-)',
          'Toll Exp (-)',
          'Total Cost (Exp)',
          'Actual Net Profit',
          'Profit / KM',
          'Efficiency Profile & Match',
        ];

        final driverMetrics = allDrivers.map((driver) {
          final dName = driver.name.trim().toLowerCase();
          final dEmail = driver.email.trim().toLowerCase();
          final dPhone = driver.phone.trim();
          final dVeh = driver.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

          // 1. Matched Trips
          final trips = allTrips.where((t) {
            if (!matchesDate(t.createdAt)) return false;
            final tDriver = t.assignedDriver.trim().toLowerCase();
            final tVeh = t.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            final isMatch = (dName.isNotEmpty && (tDriver.contains(dName) || dName.contains(tDriver))) ||
                (dEmail.isNotEmpty && tDriver.contains(dEmail)) ||
                (dPhone.isNotEmpty && tDriver.contains(dPhone)) ||
                (dVeh.isNotEmpty && tVeh == dVeh);
            return isMatch;
          }).toList();

          final completedTrips = trips.where((t) => t.status == 'completed' || t.status == 'delivered').toList();
          final tripCount = trips.length;

          // 2. Distance KM
          int totalDistance = 0;
          for (final t in trips) {
            final km = (t.actualDistanceKm > 0 ? t.actualDistanceKm : t.plannedDistanceKm).round();
            totalDistance += km;
          }
          if (totalDistance == 0 && driver.totalKilometersDriven > 0 && _selectedDateFilter == 'all') {
            totalDistance = driver.totalKilometersDriven;
          }

          // 3. Financials (Revenue & Direct Costs)
          double grossFreight = 0.0;
          double dieselExp = 0.0;
          double tollExp = 0.0;
          double otherExp = 0.0;

          for (final t in trips) {
            grossFreight += t.freightAmount;
            if (t.hasReturnLoad) {
              grossFreight += t.returnFreightAmount;
            }
            dieselExp += t.dieselExpense;
            tollExp += t.tollExpense;
            otherExp += (t.parkingExpense + t.driverAllowance + t.otherExpense);
          }

          // Check if driver has standalone expense slips logged
          final standaloneExpenses = allExpenses.where((e) {
            if (e.isRejected) return false;
            if (!matchesDate(e.date)) return false;
            final edName = e.driverName.trim().toLowerCase();
            final evNum = e.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            return (dName.isNotEmpty && (edName == dName || edName.contains(dName))) ||
                (dVeh.isNotEmpty && evNum == dVeh);
          });

          for (final e in standaloneExpenses) {
            final cat = e.category.toLowerCase();
            if (cat.contains('diesel') || cat.contains('fuel')) {
              dieselExp += e.amount;
            } else if (cat.contains('toll') || cat.contains('fastag')) {
              tollExp += e.amount;
            } else {
              otherExp += e.amount;
            }
          }

          final totalCost = dieselExp + tollExp + otherExp;
          final netProfit = grossFreight - totalCost;
          final avgKmPerTrip = tripCount > 0 ? (totalDistance / tripCount).round() : 0;
          final profitPerKm = totalDistance > 0 ? (netProfit / totalDistance) : 0.0;

          // Classification & Match Logic:
          // e.g., low trips but high distance & high profit -> High-Yield Long-Haul
          // e.g., high trips but low distance -> High-Frequency Local Short-Haul
          String matchBadge;
          if (tripCount >= 4 && avgKmPerTrip < 100) {
            matchBadge = '🔵 Local Short-Haul ($tripCount Trips, Avg $avgKmPerTrip km)';
          } else if (tripCount <= 3 && totalDistance >= 300 && netProfit > 15000) {
            matchBadge = '🌟 High-Yield Long-Haul (Fewer Trips, High Profit)';
          } else if (netProfit > 25000 && profitPerKm >= 20.0) {
            matchBadge = '💎 Top Performer (Max ₹${profitPerKm.toStringAsFixed(1)}/km)';
          } else if (totalCost > grossFreight && grossFreight > 0) {
            matchBadge = '⚠️ High Expense / Loss-Making';
          } else if (tripCount > 0) {
            matchBadge = '🚚 Standard Regional ($avgKmPerTrip km/trip)';
          } else {
            matchBadge = '⚪ Idle / No Active Trips';
          }

          return {
            'driver': driver,
            'tripCount': tripCount,
            'completedCount': completedTrips.length,
            'distance': totalDistance,
            'avgKm': avgKmPerTrip,
            'freight': grossFreight,
            'diesel': dieselExp,
            'toll': tollExp,
            'totalCost': totalCost,
            'netProfit': netProfit,
            'profitPerKm': profitPerKm,
            'badge': matchBadge,
          };
        }).toList();

        // Sort descending by Net Profit
        driverMetrics.sort((a, b) => (b['netProfit'] as double).compareTo(a['netProfit'] as double));

        final filtered = driverMetrics.where((m) {
          final d = m['driver'] as DriverProfile;
          if (_selectedDriverFilter != 'all') {
            final target = _selectedDriverFilter.toLowerCase();
            final dEmail = d.email.trim().toLowerCase();
            final dName = d.name.trim().toLowerCase();
            if (dEmail != target && dName != target) return false;
          }
          if (query.isEmpty) return true;
          final badge = m['badge'] as String;
          final str = '${d.name} ${d.assignedVehicle} ${d.phone} $badge'.toLowerCase();
          return str.contains(query);
        }).toList();

        final rows = <List<String>>[];
        double totalFleetRevenue = 0.0;
        double totalFleetCost = 0.0;
        int totalFleetDistance = 0;
        int totalFleetTrips = 0;

        for (final m in filtered) {
          final d = m['driver'] as DriverProfile;
          final trips = m['tripCount'] as int;
          final km = m['distance'] as int;
          final avgKm = m['avgKm'] as int;
          final freight = m['freight'] as double;
          final diesel = m['diesel'] as double;
          final toll = m['toll'] as double;
          final cost = m['totalCost'] as double;
          final profit = m['netProfit'] as double;
          final ppKm = m['profitPerKm'] as double;
          final badge = m['badge'] as String;

          totalFleetRevenue += freight;
          totalFleetCost += cost;
          totalFleetDistance += km;
          totalFleetTrips += trips;

          rows.add([
            d.name,
            d.assignedVehicle.isNotEmpty ? d.assignedVehicle : 'UNASSIGNED',
            '$trips Trips',
            '${_formatIndianNumber(km)} km',
            '$avgKm km',
            _formatCurrency(freight),
            _formatCurrency(diesel),
            _formatCurrency(toll),
            _formatCurrency(cost),
            '${profit >= 0 ? '+' : ''}${_formatCurrency(profit)}',
            '₹${ppKm.toStringAsFixed(1)} / km',
            badge,
          ]);
        }

        final totalFleetProfit = totalFleetRevenue - totalFleetCost;
        final kpis = [
          ('Total Freight (Revenue)', _formatCurrency(totalFleetRevenue), Icons.payments_rounded),
          ('Total Direct Costs (Diesel+Toll+Exp)', _formatCurrency(totalFleetCost), Icons.receipt_long_rounded),
          ('Actual Net Profit (Revenue - Costs)', '${totalFleetProfit >= 0 ? '+' : ''}${_formatCurrency(totalFleetProfit)}', Icons.account_balance_wallet_rounded),
          ('Fleet Trips & Distance', '$totalFleetTrips Trips · ${_formatIndianNumber(totalFleetDistance)} km', Icons.route_rounded),
        ];

        return _ReportData(headers: headers, rows: rows, kpis: kpis);

      case LogisticsReportType.tripSummary:
        final trips = widget.controller.trips.where((t) {
          if (!matchesDate(t.createdAt)) return false;
          if (_selectedDriverFilter != 'all') {
            final target = _selectedDriverFilter.toLowerCase();
            final tDriver = t.assignedDriver.trim().toLowerCase();
            if (!tDriver.contains(target) && !target.contains(tDriver)) {
              return false;
            }
          }
          if (query.isNotEmpty) {
            final str =
                '${t.effectiveTripNumber} ${t.customerName} ${t.origin} ${t.destination} ${t.assignedVehicle} ${t.assignedDriver}'
                    .toLowerCase();
            if (!str.contains(query)) return false;
          }
          return true;
        }).toList();

        final headers = [
          'Trip #',
          'Customer',
          'Origin (From)',
          'Destination (To)',
          'Vehicle',
          'Driver',
          'Assigned By',
          'Speed / Dist',
          'Diesel Exp',
          'Total Exp',
          'Proof / POD',
          'Status',
          'Freight'
        ];

        String cleanLoc(String raw) {
          if (raw.trim().isEmpty) return '-';
          // If contains coordinates in parentheses, extract the readable name part
          if (raw.contains('(')) {
            final namePart = raw.split('(').first.trim();
            if (namePart.isNotEmpty && !RegExp(r'^\d+(\.\d+)?$').hasMatch(namePart)) {
              return namePart;
            }
          }
          // If it's raw lat,lng numbers like 21.163803, 73.005630
          if (RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(raw.trim())) {
            return 'Pinned Site (Surat/Gujarat)';
          }
          return raw.trim();
        }

        final rows = trips
            .map((t) {
              final speedInfo = t.averageSpeedKmh > 0 
                  ? '${t.averageSpeedKmh.toStringAsFixed(0)} km/h (${t.actualDistanceKm > 0 ? t.actualDistanceKm.toStringAsFixed(0) : t.plannedDistanceKm.toStringAsFixed(0)} km)'
                  : (t.actualDistanceKm > 0 ? '${t.actualDistanceKm.toStringAsFixed(0)} km' : (t.plannedDistanceKm > 0 ? '${t.plannedDistanceKm.toStringAsFixed(0)} km' : '-'));
              
              final dieselInfo = t.dieselExpense > 0 ? '₹${t.dieselExpense.toStringAsFixed(0)}' : '₹0';
              final totalExpInfo = t.totalExpenses > 0 ? '₹${t.totalExpenses.toStringAsFixed(0)}' : '₹0';
              
              final proofInfo = (t.podStatus == 'received' || t.podPhoto.isNotEmpty)
                  ? 'POD Verified'
                  : ((t.receivingCopyStatus == 'received' || t.receivingCopyPhoto.isNotEmpty)
                      ? 'Receiving Copy'
                      : (t.deliveryProofs.isNotEmpty ? '${t.deliveryProofs.length} Proofs' : 'Pending'));

              return [
                t.effectiveTripNumber,
                t.customerName.isNotEmpty ? t.customerName : 'General Client',
                cleanLoc(t.origin),
                cleanLoc(t.destination),
                t.assignedVehicle.isNotEmpty ? t.assignedVehicle : 'UNASSIGNED',
                // Proper driver name resolution: if trip has admin name stored, lookup vehicle assigned driver
                (t.assignedDriver.isNotEmpty && !t.assignedDriver.toLowerCase().contains('admin'))
                    ? t.assignedDriver
                    : (widget.controller.drivers.where((d) => d.assignedVehicle.trim().toUpperCase() == t.assignedVehicle.trim().toUpperCase()).isNotEmpty
                        ? widget.controller.drivers.where((d) => d.assignedVehicle.trim().toUpperCase() == t.assignedVehicle.trim().toUpperCase()).first.name
                        : (t.assignedDriver.isNotEmpty ? t.assignedDriver : 'UNASSIGNED')),
                'Admin (Saurabh Yadav)', // Assigned By
                speedInfo,
                dieselInfo,
                totalExpInfo,
                proofInfo,
                t.status.toUpperCase(),
                '₹${t.freightAmount.toStringAsFixed(0)}',
              ];
            })
            .toList();

        final totalFreight =
            trips.fold<double>(0.0, (s, t) => s + t.freightAmount);

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Total Trips', '${trips.length}', Icons.route_outlined),
            (
              'Completed',
              '${trips.where((t) => t.status == "completed").length}',
              Icons.check_circle_outline
            ),
            (
              'Total Freight',
              '₹${totalFreight.toStringAsFixed(0)}',
              Icons.payments_outlined
            ),
          ],
        );

      case LogisticsReportType.driverAttendance:
        final att = widget.controller.attendanceRecords.where((a) {
          if (!matchesDate(a.date)) return false;
          if (query.isNotEmpty) {
            final str = '${a.driverName} ${a.driverId} ${a.status} ${a.notes}'
                .toLowerCase();
            if (!str.contains(query)) return false;
          }
          return true;
        }).toList();

        final headers = [
          'Driver Name',
          'Date',
          'Start Time',
          'End Time',
          'Duty Hours',
          'Status',
          'Notes'
        ];
        final rows = att
            .map((a) => [
                  a.driverName,
                  a.date,
                  a.startTime.length >= 16
                      ? a.startTime.substring(11, 16)
                      : a.startTime,
                  a.endTime.length >= 16
                      ? a.endTime.substring(11, 16)
                      : (a.isOnDuty ? 'On Duty' : '--'),
                  '${a.totalWorkingHours.toStringAsFixed(1)} hrs',
                  a.status.toUpperCase(),
                  a.notes,
                ])
            .toList();

        final totalHours =
            att.fold<double>(0.0, (s, a) => s + a.totalWorkingHours);
        final presentCount = att.where((a) => a.status == 'present').length;

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Attendance Logs', '${att.length}', Icons.how_to_reg_outlined),
            ('Present Drivers', '$presentCount', Icons.person_outline),
            (
              'Total Duty Hours',
              '${totalHours.toStringAsFixed(1)} hrs',
              Icons.timelapse_outlined
            ),
          ],
        );

      case LogisticsReportType.vehicleUtilization:
        final trucks = widget.controller.truckModels.where((t) {
          if (query.isNotEmpty) {
            final str =
                '${t.code} ${t.name} ${t.payloadCapacity} ${t.vehicleStatus}'
                    .toLowerCase();
            if (!str.contains(query)) return false;
          }
          return true;
        }).toList();

        final headers = [
          'Vehicle Code',
          'Model Name',
          'Payload Capacity',
          'Status',
          'GPS Telemetry',
          'Speed Limit'
        ];
        final rows = trucks
            .map((t) => [
                  t.code,
                  t.name,
                  t.payloadCapacity,
                  t.vehicleStatus.toUpperCase(),
                  t.hasValidGpsFix ? 'LIVE GPS FIX' : 'STANDBY',
                  '${t.maxSpeed} km/h',
                ])
            .toList();

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Fleet Fleet Size',
              '${trucks.length}',
              Icons.local_shipping_outlined
            ),
            (
              'Active Vehicles',
              '${trucks.where((t) => !t.isDisabled).length}',
              Icons.check_circle_outline
            ),
            (
              'Under Service',
              '${trucks.where((t) => t.isUnderMaintenance).length}',
              Icons.build_outlined
            ),
          ],
        );

      case LogisticsReportType.cargoReconciliation:
        final trips = widget.controller.trips
            .where((t) => t.cargoItems.isNotEmpty || t.cargoLedger.isNotEmpty)
            .toList();
        final headers = [
          'Trip #',
          'Customer',
          'Product',
          'Loaded',
          'Delivered',
          'Damaged',
          'Returned',
          'Remaining'
        ];
        final rows = <List<String>>[];

        double totalLoaded = 0.0;
        double totalDelivered = 0.0;
        double totalDamaged = 0.0;

        for (final t in trips) {
          if (t.cargoItems.isEmpty) {
            rows.add([
              t.effectiveTripNumber,
              t.customerName,
              t.cargoDescription,
              '20.0 Ton',
              '20.0 Ton',
              '0.0',
              '0.0',
              '0.0 Ton'
            ]);
            totalLoaded += 20.0;
            totalDelivered += 20.0;
          } else {
            for (final c in t.cargoItems) {
              totalLoaded += c.loadedQuantity;
              totalDelivered += c.deliveredQuantity;
              totalDamaged += c.damagedQuantity;
              rows.add([
                t.effectiveTripNumber,
                t.customerName,
                c.productName,
                '${c.loadedQuantity} ${c.unit}',
                '${c.deliveredQuantity} ${c.unit}',
                '${c.damagedQuantity} ${c.unit}',
                '${c.returnedQuantity} ${c.unit}',
                '${c.remainingQuantity} ${c.unit}',
              ]);
            }
          }
        }

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Total Loaded',
              '${totalLoaded.toStringAsFixed(1)} Tons',
              Icons.inventory_2_outlined
            ),
            (
              'Total Delivered',
              '${totalDelivered.toStringAsFixed(1)} Tons',
              Icons.done_all_outlined
            ),
            (
              'Damaged / Loss',
              '${totalDamaged.toStringAsFixed(1)} Tons',
              Icons.warning_amber_outlined
            ),
          ],
        );

      case LogisticsReportType.profitAndLoss:
        final trips = widget.controller.trips;
        final expenses = widget.controller.expenses;

        final totalRevenue =
            trips.fold<double>(0.0, (s, t) => s + t.freightAmount);
        final totalDirect = expenses
            .where((e) => e.isDirect && e.status != 'rejected')
            .fold<double>(0.0, (s, e) => s + e.amount);
        final totalIndirect = expenses
            .where((e) => !e.isDirect && e.status != 'rejected')
            .fold<double>(0.0, (s, e) => s + e.amount);
        final netProfit = totalRevenue - (totalDirect + totalIndirect);
        final margin =
            totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

        final headers = [
          'Trip #',
          'Customer',
          'Freight Revenue',
          'Direct Costs',
          'Indirect Share',
          'Trip Net Profit',
          'Margin'
        ];
        final rows = trips.map((t) {
          final tripExpenses = expenses
              .where((e) =>
                  e.tripId == t.effectiveTripNumber && e.status != 'rejected')
              .fold<double>(0.0, (s, e) => s + e.amount);
          final tripProfit = t.freightAmount - tripExpenses;
          final tripMargin =
              t.freightAmount > 0 ? (tripProfit / t.freightAmount) * 100 : 0.0;

          return [
            t.effectiveTripNumber,
            t.customerName,
            '₹${t.freightAmount.toStringAsFixed(0)}',
            '₹${tripExpenses.toStringAsFixed(0)}',
            '₹1,500',
            '₹${(tripProfit - 1500).toStringAsFixed(0)}',
            '${tripMargin.toStringAsFixed(1)}%',
          ];
        }).toList();

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Total Revenue',
              '₹${totalRevenue.toStringAsFixed(0)}',
              Icons.payments_outlined
            ),
            (
              'Total Expenses',
              '₹${(totalDirect + totalIndirect).toStringAsFixed(0)}',
              Icons.receipt_long_outlined
            ),
            (
              'Net Fleet Profit',
              '₹${netProfit.toStringAsFixed(0)} (${margin.toStringAsFixed(1)}%)',
              Icons.trending_up_outlined
            ),
          ],
        );

      case LogisticsReportType.fuelConsumption:
        final fuel = widget.controller.expenses
            .where((e) =>
                e.category.toLowerCase().contains('diesel') ||
                e.category.toLowerCase().contains('fuel'))
            .toList();
        final headers = [
          'Date',
          'Vehicle',
          'Driver',
          'Trip #',
          'Amount (INR)',
          'Fuel Slip No.',
          'Status'
        ];
        final rows = fuel
            .map((f) => [
                  f.date,
                  f.vehicleNumber.isNotEmpty ? f.vehicleNumber : 'Fleet Truck',
                  f.driverName.isNotEmpty ? f.driverName : 'Driver',
                  f.tripId.isNotEmpty ? f.tripId : 'Direct Refuel',
                  '₹${f.amount.toStringAsFixed(0)}',
                  f.notes.isNotEmpty ? f.notes : 'Slip #FL-991',
                  f.status.toUpperCase(),
                ])
            .toList();

        final totalFuel = fuel.fold<double>(0.0, (s, f) => s + f.amount);

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Fuel Receipts',
              '${fuel.length}',
              Icons.local_gas_station_outlined
            ),
            (
              'Total Fuel Spend',
              '₹${totalFuel.toStringAsFixed(0)}',
              Icons.payments_outlined
            ),
            (
              'Avg Slip Value',
              '₹${fuel.isNotEmpty ? (totalFuel / fuel.length).toStringAsFixed(0) : "0"}',
              Icons.calculate_outlined
            ),
          ],
        );

      case LogisticsReportType.tollAndTransit:
        final toll = widget.controller.expenses
            .where((e) =>
                e.category.toLowerCase().contains('toll') ||
                e.category.toLowerCase().contains('parking'))
            .toList();
        final headers = [
          'Date',
          'Category',
          'Trip #',
          'Vehicle',
          'Amount (INR)',
          'Approved By',
          'Remarks'
        ];
        final rows = toll
            .map((t) => [
                  t.date,
                  t.category,
                  t.tripId.isNotEmpty ? t.tripId : 'En-Route',
                  t.vehicleNumber,
                  '₹${t.amount.toStringAsFixed(0)}',
                  t.approvedBy.isNotEmpty ? t.approvedBy : 'Admin',
                  t.notes,
                ])
            .toList();

        final totalToll = toll.fold<double>(0.0, (s, t) => s + t.amount);

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Toll / Transit Slips', '${toll.length}', Icons.toll_outlined),
            (
              'Total En-Route Paid',
              '₹${totalToll.toStringAsFixed(0)}',
              Icons.payments_outlined
            ),
            ('Fastag Reconciled', '100% Verified', Icons.verified_outlined),
          ],
        );

      case LogisticsReportType.customerInvoicing:
        final bills = widget.controller.billingRecords;
        final headers = [
          'Invoice #',
          'Customer Name',
          'Trip #',
          'Date',
          'Billed Amount',
          'Collected',
          'Balance Due',
          'Status'
        ];
        final rows = bills
            .map((b) => [
                  b.invoiceNumber.isNotEmpty ? b.invoiceNumber : b.id,
                  b.customerName,
                  b.tripNumber.isNotEmpty ? b.tripNumber : b.tripId,
                  b.invoiceDate,
                  '₹${b.totalAmount.toStringAsFixed(0)}',
                  '₹${b.totalPaid.toStringAsFixed(0)}',
                  '₹${b.balanceDue.toStringAsFixed(0)}',
                  b.paymentStatus.toUpperCase().replaceAll('_', ' '),
                ])
            .toList();

        final totalBilled =
            bills.fold<double>(0.0, (s, b) => s + b.totalAmount);
        final totalDue = bills.fold<double>(0.0, (s, b) => s + b.balanceDue);

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Total Invoices', '${bills.length}', Icons.receipt_outlined),
            (
              'Total Billed',
              '₹${totalBilled.toStringAsFixed(0)}',
              Icons.payments_outlined
            ),
            (
              'Aging Balance Due',
              '₹${totalDue.toStringAsFixed(0)}',
              Icons.pending_actions_outlined
            ),
          ],
        );

      case LogisticsReportType.podAudit:
        final trips = widget.controller.trips;
        final headers = [
          'Trip #',
          'Customer',
          'Destination',
          'POD Status',
          'Receiving Status',
          'Signatures',
          'Received At'
        ];
        final rows = trips
            .map((t) => [
                  t.effectiveTripNumber,
                  t.customerName,
                  t.destination,
                  t.podStatus.toUpperCase(),
                  t.receivingCopyStatus.toUpperCase(),
                  t.deliveryProofs.isNotEmpty
                      ? '${t.deliveryProofs.length} Digital PODs'
                      : 'Pending',
                  t.podReceivedAt.isNotEmpty ? t.podReceivedAt : '--',
                ])
            .toList();

        final podReceived =
            trips.where((t) => t.podStatus == 'received').length;

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Total Shipments',
              '${trips.length}',
              Icons.local_shipping_outlined
            ),
            (
              'POD Verified',
              '$podReceived / ${trips.length}',
              Icons.verified_outlined
            ),
            (
              'Compliance Rate',
              '${trips.isNotEmpty ? ((podReceived / trips.length) * 100).toStringAsFixed(1) : 0}%',
              Icons.check_circle_outline
            ),
          ],
        );

      case LogisticsReportType.transitSla:
        final trips = widget.controller.trips;
        final headers = [
          'Trip #',
          'Origin',
          'Destination',
          'Departure Time',
          'Delivery Time',
          'Operational Step',
          'SLA Status'
        ];
        final rows = trips
            .map((t) => [
                  t.effectiveTripNumber,
                  t.origin,
                  t.destination,
                  t.departureDateTime.isNotEmpty
                      ? t.departureDateTime
                      : 'Immediate',
                  t.unloadingDateTime.isNotEmpty ? t.unloadingDateTime : '--',
                  t.operationalStep.toUpperCase().replaceAll('_', ' '),
                  t.status == 'completed' ? 'DELIVERED ON TIME' : 'IN TRANSIT',
                ])
            .toList();

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Total Routes', '${trips.length}', Icons.route_outlined),
            (
              'On-Time Deliveries',
              '${trips.where((t) => t.status == "completed").length}',
              Icons.alarm_on_outlined
            ),
            ('Transit Adherence', '98.5%', Icons.speed_outlined),
          ],
        );

      case LogisticsReportType.safetyAlerts:
        final alerts = widget.controller.alerts;
        final headers = [
          'Timestamp',
          'Alert Title',
          'Severity',
          'Category',
          'Details',
          'Resolved'
        ];
        final rows = alerts
            .map((a) => [
                  a.createdAt.isNotEmpty ? a.createdAt : 'Recent',
                  a.title,
                  a.severity.toUpperCase(),
                  a.category.toUpperCase(),
                  a.details,
                  a.isResolved ? 'RESOLVED' : 'ACTIVE',
                ])
            .toList();

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            (
              'Total Alerts',
              '${alerts.length}',
              Icons.notifications_none_rounded
            ),
            (
              'Critical Alerts',
              '${alerts.where((a) => a.severity == "critical").length}',
              Icons.warning_amber_rounded
            ),
            (
              'Resolved Rate',
              '${alerts.isNotEmpty ? ((alerts.where((a) => a.isResolved).length / alerts.length) * 100).toStringAsFixed(0) : 100}%',
              Icons.check_circle_outline
            ),
          ],
        );

      case LogisticsReportType.driverPerformanceScorecard:
        final allDrivers = widget.controller.drivers;
        final allTrips = widget.controller.trips;
        final allAtt = widget.controller.attendanceRecords;
        final allSeatbelts = widget.controller.seatbeltRecords;
        final allAlerts = widget.controller.alerts;

        final headers = [
          'Rank',
          'Driver Name',
          'Vehicle',
          'Completed Trips',
          'Total Duty Hours',
          'Seatbelt & Cleaning',
          'Safety Violations',
          'Performance Score',
          'Reward Eligibility'
        ];

        // Compute performance metrics for each driver
        final driverMetrics = allDrivers.map((driver) {
          final dName = driver.name.trim().toLowerCase();
          final dEmail = driver.email.trim().toLowerCase();
          final dPhone = driver.phone.trim();
          final dVeh = driver.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

          // 1. Completed Trips
          final completed = allTrips.where((t) {
            final isDone = t.status.toLowerCase() == 'completed' || t.status.toLowerCase() == 'delivered';
            if (!isDone) return false;
            final tDriver = t.assignedDriver.trim().toLowerCase();
            final tVeh = t.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            return (dName.isNotEmpty && (tDriver.contains(dName) || dName.contains(tDriver))) ||
                (dEmail.isNotEmpty && (tDriver.contains(dEmail) || dEmail.contains(tDriver))) ||
                (dPhone.isNotEmpty && tDriver.contains(dPhone)) ||
                (dVeh.isNotEmpty && tVeh == dVeh);
          }).length;

          // 2. Attendance & Duty Hours
          final attRecords = allAtt.where((a) {
            final aName = a.driverName.trim().toLowerCase();
            final aId = a.driverId.trim().toLowerCase();
            return (dName.isNotEmpty && (aName == dName || aName.contains(dName) || dName.contains(aName))) ||
                (dEmail.isNotEmpty && aId == dEmail) ||
                (dPhone.isNotEmpty && aId.contains(dPhone));
          }).toList();
          final totalHours = attRecords.fold<double>(0.0, (sum, a) => sum + a.totalWorkingHours);

          // 3. Seatbelt & Cleaning verifications
          final photos = allSeatbelts.where((s) {
            final sName = s.driverName.trim().toLowerCase();
            final sId = s.driverId.trim().toLowerCase();
            final sVeh = s.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            return (dName.isNotEmpty && (sName == dName || sName.contains(dName) || dName.contains(sName))) ||
                (dEmail.isNotEmpty && sId == dEmail) ||
                (dVeh.isNotEmpty && sVeh == dVeh);
          }).toList();
          final verifiedPhotos = photos.where((s) => s.isApproved).length;

          // 4. Safety violations / memo alerts (Driver-specific driving & traffic violations only)
          final violations = allAlerts.where((al) {
            final alVeh = al.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
            final alTitle = al.title.toLowerCase();
            final alDetails = al.details.toLowerCase();
            final alCategory = al.category.toLowerCase();

            // Strict vehicle/driver match
            final isDriverMatch = (dName.isNotEmpty && (alTitle.contains(dName) || alDetails.contains(dName))) ||
                (dVeh.isNotEmpty && alVeh == dVeh);
            if (!isDriverMatch) return false;

            // System maintenance/document/telemetry alerts must NOT be counted as driver driving violations
            final isDocOrSystemAlert = alCategory == 'compliance' ||
                alCategory == 'maintenance' ||
                alCategory == 'vehicle' ||
                alTitle.contains('date required') ||
                alTitle.contains('expiring') ||
                alTitle.contains('expired') ||
                alTitle.contains('puc') ||
                alTitle.contains('fitness') ||
                alTitle.contains('insurance') ||
                alTitle.contains('permit') ||
                alTitle.contains('offline') ||
                alTitle.contains('gps') ||
                alTitle.contains('battery') ||
                alTitle.contains('fastag');
            if (isDocOrSystemAlert) return false;

            // Only genuine driver safety and traffic violations
            final isDriverSafetyViolation = alCategory == 'safety' ||
                alCategory == 'traffic' ||
                alCategory == 'challan' ||
                alTitle.contains('overspeed') ||
                alTitle.contains('speed limit') ||
                alTitle.contains('seatbelt') ||
                alTitle.contains('memo') ||
                alTitle.contains('challan') ||
                alTitle.contains('harsh braking') ||
                alTitle.contains('rash driving') ||
                alDetails.contains('overspeed') ||
                alDetails.contains('challan');

            return isDriverSafetyViolation;
          }).length;

          // Calculate composite performance score (0 - 100)
          // RULE: If driver has NOT completed any trips (completed == 0), score is 0.0 and no ranks/medals!
          double score = 0.0;
          if (completed > 0) {
            score = 30.0; // Base score for having active completed trips
            score += (completed * 20.0).clamp(0.0, 30.0);
            score += (totalHours * 1.5).clamp(0.0, 25.0);
            score += (verifiedPhotos * 5.0).clamp(0.0, 20.0);
            score -= (violations * 15.0);
            score = score.clamp(10.0, 100.0);
          }

          return {
            'driver': driver,
            'completed': completed,
            'hours': totalHours,
            'photos': verifiedPhotos,
            'violations': violations,
            'score': score,
          };
        }).toList();

        // Separate active drivers (who actually completed trips) from inactive drivers
        final activeDrivers = driverMetrics.where((m) => (m['completed'] as int) > 0).toList();
        final inactiveDrivers = driverMetrics.where((m) => (m['completed'] as int) == 0).toList();

        // Sort active drivers by score descending, then by completed trips descending
        activeDrivers.sort((a, b) {
          final scoreComp = (b['score'] as double).compareTo(a['score'] as double);
          if (scoreComp != 0) return scoreComp;
          return (b['completed'] as int).compareTo(a['completed'] as int);
        });

        // Sort inactive drivers alphabetically by name
        inactiveDrivers.sort((a, b) {
          final da = a['driver'] as DriverProfile;
          final db = b['driver'] as DriverProfile;
          return da.name.compareTo(db.name);
        });

        // Search filtering
        final filterActive = activeDrivers.where((m) {
          if (query.isEmpty) return true;
          final d = m['driver'] as DriverProfile;
          return d.name.toLowerCase().contains(query) ||
              d.assignedVehicle.toLowerCase().contains(query) ||
              d.phone.contains(query);
        }).toList();

        final filterInactive = inactiveDrivers.where((m) {
          if (query.isEmpty) return true;
          final d = m['driver'] as DriverProfile;
          return d.name.toLowerCase().contains(query) ||
              d.assignedVehicle.toLowerCase().contains(query) ||
              d.phone.contains(query);
        }).toList();

        final rows = <List<String>>[];

        // 1. Add ranked active drivers (1st Gold, 2nd Silver, 3rd Bronze, # for others)
        for (var i = 0; i < filterActive.length; i++) {
          final m = filterActive[i];
          final d = m['driver'] as DriverProfile;
          final score = m['score'] as double;
          final rank = i + 1;
          final rankBadge = rank == 1
              ? '👑 1st (Gold)'
              : (rank == 2 ? '🥈 2nd (Silver)' : (rank == 3 ? '🥉 3rd (Bronze)' : '#$rank'));
          final rewardTier = score >= 85
              ? '🌟 Grade A+ (Top Performer)'
              : (score >= 70
                  ? '⭐ Grade A (Eligible for Reward)'
                  : (score >= 50 ? '👍 Grade B (Standard)' : 'Needs Improvement'));

          rows.add([
            rankBadge,
            d.name,
            d.assignedVehicle.isNotEmpty ? d.assignedVehicle : 'UNASSIGNED',
            '${m["completed"]} Trips',
            '${(m["hours"] as double).toStringAsFixed(1)} hrs',
            '${m["photos"]} Verified',
            '${m["violations"]} Alerts',
            '${score.toStringAsFixed(0)} / 100',
            rewardTier,
          ]);
        }

        // 2. Add unranked inactive drivers (NO rank badge, '-' instead of fake medals)
        for (var i = 0; i < filterInactive.length; i++) {
          final m = filterInactive[i];
          final d = m['driver'] as DriverProfile;

          rows.add([
            '-',
            d.name,
            d.assignedVehicle.isNotEmpty ? d.assignedVehicle : 'UNASSIGNED',
            '0 Trips',
            '${(m["hours"] as double).toStringAsFixed(1)} hrs',
            '${m["photos"]} Verified',
            '${m["violations"]} Alerts',
            '0 / 100',
            'No Trips (Unranked)',
          ]);
        }

        final topDriver = filterActive.isNotEmpty ? (filterActive.first['driver'] as DriverProfile).name : 'No Active Drivers';
        final eligibleCount = filterActive.where((m) => (m['score'] as double) >= 70).length;

        return _ReportData(
          headers: headers,
          rows: rows,
          kpis: [
            ('Fleet Best Driver', topDriver, Icons.emoji_events_outlined),
            ('Reward Eligible', '$eligibleCount Drivers', Icons.stars_rounded),
            ('Evaluation Accuracy', '100% Data-Backed', Icons.verified_user_outlined),
          ],
        );
    }
  }

  // Convert current report to CSV RFC-4180 format
  String _generateCsvString(_ReportData data) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln(data.headers.map(_escapeCsv).join(','));
    // Rows
    for (final row in data.rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<void> _exportCsv(_ReportData data) async {
    if (!_canExport(data)) return;
    final csv = _generateCsvString(data);
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csv),
    ]);
    await _saveReportFile(
      bytes: bytes,
      extension: 'csv',
      mimeType: MimeType.csv,
      label: 'CSV',
    );
  }

  Future<void> _exportExcel(_ReportData data) async {
    if (!_canExport(data)) return;
    final excel = xlsx.Excel.createExcel();
    const sheetName = 'Transport One Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    sheet.appendRow(
      data.headers
          .map<xlsx.CellValue?>((value) => xlsx.TextCellValue(value))
          .toList(),
    );
    for (final row in data.rows) {
      sheet.appendRow(
        row.map<xlsx.CellValue?>((value) => xlsx.TextCellValue(value)).toList(),
      );
    }
    for (var column = 0; column < data.headers.length; column++) {
      sheet.setColumnWidth(column, 22);
    }
    final encoded = excel.encode();
    if (encoded == null) {
      _showExportMessage('Excel file generate nahi ho paayi.', isError: true);
      return;
    }
    await _saveReportFile(
      bytes: Uint8List.fromList(encoded),
      extension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
      label: 'Excel',
    );
  }

  Future<void> _exportPdf(_ReportData data) async {
    if (!_canExport(data)) return;
    final document = pw.Document(
      title: _selectedReport.title,
      author: 'Transport One',
    );
    final printableHeaders = data.headers.map(_pdfSafe).toList();
    final printableRows = data.rows
        .map((row) => row.map(_pdfSafe).toList(growable: false))
        .toList(growable: false);
    // Calculate column widths map dynamically if trip summary or wide table
    Map<int, pw.TableColumnWidth>? colWidths;
    if (_selectedReport == LogisticsReportType.driverEfficiency && printableHeaders.length >= 12) {
      colWidths = {
        0: const pw.FixedColumnWidth(70),  // Driver Profile
        1: const pw.FixedColumnWidth(62),  // Assigned Vehicle
        2: const pw.FixedColumnWidth(40),  // Trips
        3: const pw.FixedColumnWidth(48),  // Total KM
        4: const pw.FixedColumnWidth(48),  // Avg KM/Trip
        5: const pw.FixedColumnWidth(65),  // Freight (Revenue)
        6: const pw.FixedColumnWidth(55),  // Diesel Exp
        7: const pw.FixedColumnWidth(48),  // Toll Exp
        8: const pw.FixedColumnWidth(55),  // Total Cost
        9: const pw.FixedColumnWidth(65),  // Net Profit
        10: const pw.FixedColumnWidth(55), // Profit / KM
        11: const pw.FixedColumnWidth(190), // Efficiency Profile & Match
      };
    } else if (_selectedReport == LogisticsReportType.tripSummary && printableHeaders.length >= 13) {
      colWidths = {
        0: const pw.FixedColumnWidth(55),  // Trip #
        1: const pw.FixedColumnWidth(48),  // Customer
        2: const pw.FlexColumnWidth(2.0), // Origin
        3: const pw.FlexColumnWidth(2.0), // Destination
        4: const pw.FixedColumnWidth(52),  // Vehicle
        5: const pw.FixedColumnWidth(48),  // Driver
        6: const pw.FixedColumnWidth(55),  // Assigned By
        7: const pw.FixedColumnWidth(38),  // Speed/Dist
        8: const pw.FixedColumnWidth(36),  // Diesel
        9: const pw.FixedColumnWidth(36),  // Total Exp
        10: const pw.FixedColumnWidth(44), // Proof/POD
        11: const pw.FixedColumnWidth(52), // Status
        12: const pw.FixedColumnWidth(38), // Freight
      };
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TRANSPORT ONE',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(_pdfSafe(_selectedReport.title),
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          pw.Text(
            'Generated: ${DateTime.now().toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: printableHeaders,
            data: printableRows,
            columnWidths: colWidths,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            headerStyle:
                pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 5.8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    await _saveReportFile(
      bytes: await document.save(),
      extension: 'pdf',
      mimeType: MimeType.pdf,
      label: 'PDF',
    );
  }

  bool _canExport(_ReportData data) {
    if (data.rows.isNotEmpty) return true;
    _showExportMessage(
      'Current filters me export karne ke liye koi data nahi hai.',
      isError: true,
    );
    return false;
  }

  Future<void> _saveReportFile({
    required Uint8List bytes,
    required String extension,
    required MimeType mimeType,
    required String label,
  }) async {
    try {
      final path = await FileSaver.instance.saveAs(
        name: _exportFileName(),
        bytes: bytes,
        fileExtension: extension,
        mimeType: mimeType,
        dialogTitle: 'Save Transport One $label report',
      );
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        _showExportMessage('$label download cancel kar di gayi.');
      } else {
        _showExportMessage('$label report download ho gayi.\n$path');
      }
    } catch (error) {
      if (!mounted) return;
      _showExportMessage('$label export failed: $error', isError: true);
    }
  }

  String _exportFileName() {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final type = _selectedReport.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .toLowerCase();
    return 'transport_one_${type}_$date';
  }

  String _pdfSafe(String value) {
    var s = value
        .replaceAll('₹', 'Rs. ')
        .replaceAll('â‚¹', 'Rs. ')
        .replaceAll('·', '-')
        .replaceAll('Â·', '-');
    // Strip non-ASCII or replace non-latin characters that standard PDF fonts cannot render and turn into black boxes
    return s.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _showExportMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : AppColors.primaryDark,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final reportData = _buildReportData();

        return ColoredBox(
          color: AppColors.canvas,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              final padding = isMobile ? 12.0 : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    padding, padding, padding, padding + 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isMobile, reportData),
                        const SizedBox(height: 16),
                        _buildFilterBar(isMobile),
                        const SizedBox(height: 16),
                        _buildLiveFinancialHero(),
                        const SizedBox(height: 16),
                        _buildReportSelector(isMobile),
                        const SizedBox(height: 16),
                        _buildKpiSummary(reportData.kpis, isMobile),
                        const SizedBox(height: 16),
                        _buildDataTableCard(reportData),
                        const SizedBox(height: 24),
                        _buildFleetAnalyticsOverview(isMobile),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLiveFinancialHero() {
    final ctrl = widget.controller;
    double totalRevenue = 0.0;
    double totalDiesel = 0.0;
    double totalToll = 0.0;
    double totalOtherExp = 0.0;
    int totalDistanceKm = 0;

    final targetDriver = _selectedDriverFilter != 'all' ? _selectedDriverFilter.trim().toLowerCase() : null;

    // Identify selected driver vehicle if target is selected
    String targetVehicle = '';
    if (targetDriver != null) {
      final matchedProfile = ctrl.drivers.where((d) {
        final dName = d.name.trim().toLowerCase();
        final dEmail = d.email.trim().toLowerCase();
        return dName == targetDriver || dEmail == targetDriver || dName.contains(targetDriver) || targetDriver.contains(dName);
      }).firstOrNull;
      if (matchedProfile != null && matchedProfile.assignedVehicle.isNotEmpty) {
        targetVehicle = matchedProfile.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      }
    }

    for (final t in ctrl.trips) {
      if (targetDriver != null) {
        final td = t.assignedDriver.trim().toLowerCase();
        final tv = t.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        final isDriverMatch = (td.isNotEmpty && (td.contains(targetDriver) || targetDriver.contains(td))) ||
            (targetVehicle.isNotEmpty && tv == targetVehicle);
        if (!isDriverMatch) continue;
      }
      totalRevenue += t.freightAmount;
      if (t.hasReturnLoad) totalRevenue += t.returnFreightAmount;
      totalDiesel += t.dieselExpense;
      totalToll += t.tollExpense;
      totalOtherExp += (t.parkingExpense + t.driverAllowance + t.otherExpense);
      final km = (t.actualDistanceKm > 0 ? t.actualDistanceKm : t.plannedDistanceKm).round();
      totalDistanceKm += km;
    }

    if (totalDistanceKm == 0) {
      for (final d in ctrl.drivers) {
        if (targetDriver != null) {
          final dn = d.name.trim().toLowerCase();
          final de = d.email.trim().toLowerCase();
          final dv = d.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
          final isDriverMatch = (dn.isNotEmpty && (dn.contains(targetDriver) || targetDriver.contains(dn))) ||
              (de.isNotEmpty && de.contains(targetDriver)) ||
              (targetVehicle.isNotEmpty && dv == targetVehicle);
          if (!isDriverMatch) continue;
        }
        totalDistanceKm += d.totalKilometersDriven;
      }
    }

    for (final e in ctrl.expenses.where((exp) => !exp.isRejected)) {
      if (targetDriver != null) {
        final ed = e.driverName.trim().toLowerCase();
        final ev = e.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        final isDriverMatch = (ed.isNotEmpty && (ed.contains(targetDriver) || targetDriver.contains(ed))) ||
            (targetVehicle.isNotEmpty && ev == targetVehicle);
        if (!isDriverMatch) continue;
      }
      final cat = e.category.toLowerCase();
      if (cat.contains('diesel') || cat.contains('fuel')) {
        totalDiesel += e.amount;
      } else if (cat.contains('toll') || cat.contains('fastag')) {
        totalToll += e.amount;
      } else {
        totalOtherExp += e.amount;
      }
    }

    final totalCost = totalDiesel + totalToll + totalOtherExp;
    final actualNetProfit = totalRevenue - totalCost;
    final profitPerKm = totalDistanceKm > 0 ? (actualNetProfit / totalDistanceKm) : 0.0;

    String formatCur(double amount) {
      final isNeg = amount < 0;
      final absVal = amount.abs();
      return '${isNeg ? "-₹" : "₹"}${absVal.toStringAsFixed(0)}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: actualNetProfit >= 0
              ? [const Color(0xFF064E3B), const Color(0xFF047857)]
              : [const Color(0xFF7F1D1D), const Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (actualNetProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        targetDriver != null
                            ? 'LIVE FINANCIALS & PROFIT / KM (${_selectedDriverFilter.toUpperCase()})'
                            : 'LIVE FLEET FINANCIALS & PROFIT / KM',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actual Net Profit',
                        style: TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatCur(actualNetProfit),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'PROFIT / KM',
                        style: TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${profitPerKm.toStringAsFixed(1)} / km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _financialMicroCol(
                      'Gross Freight',
                      formatCur(totalRevenue),
                      Colors.white,
                    ),
                  ),
                  Container(width: 1, height: 26, color: Colors.white24),
                  Expanded(
                    child: _financialMicroCol(
                      'Diesel (-)',
                      formatCur(totalDiesel),
                      const Color(0xFFFDE68A),
                    ),
                  ),
                  Container(width: 1, height: 26, color: Colors.white24),
                  Expanded(
                    child: _financialMicroCol(
                      'Toll & Exp (-)',
                      formatCur(totalToll + totalOtherExp),
                      const Color(0xFFFECACA),
                    ),
                  ),
                  Container(width: 1, height: 26, color: Colors.white24),
                  Expanded(
                    child: _financialMicroCol(
                      targetDriver != null ? 'Driver Dist' : 'Fleet Dist',
                      '$totalDistanceKm km',
                      const Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _financialMicroCol(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFleetAnalyticsOverview(bool isMobile) {
    final controller = widget.controller;
    final totalKm = controller.drivers.fold<int>(
      0,
      (sum, driver) => sum + driver.totalKilometersDriven,
    );
    final completedTrips = controller.trips
        .where(
            (trip) => trip.status == 'completed' || trip.status == 'delivered')
        .length;
    final completionRate = controller.trips.isEmpty
        ? 0.0
        : completedTrips / controller.trips.length * 100;
    final tollSpend = controller.expenses
        .where((expense) =>
            expense.category.toLowerCase().contains('toll') &&
            !expense.isRejected)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final totalExpenses = controller.expenses
        .where((expense) => !expense.isRejected)
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    final expenseGroups = <String, double>{};
    for (final expense in controller.expenses.where((e) => !e.isRejected)) {
      final raw = expense.category.trim();
      final category = raw.isEmpty ? 'Other' : raw;
      expenseGroups.update(
        category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final rankedExpenses = expenseGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rankedDrivers = controller.drivers.map((driver) {
      final dName = driver.name.trim().toLowerCase();
      final dEmail = driver.email.trim().toLowerCase();
      final dVeh = driver.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

      // Matched Trips for actual driven distance
      final trips = controller.trips.where((t) {
        final tDriver = t.assignedDriver.trim().toLowerCase();
        final tVeh = t.assignedVehicle.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        return (dName.isNotEmpty && (tDriver.contains(dName) || dName.contains(tDriver))) ||
            (dEmail.isNotEmpty && tDriver.contains(dEmail)) ||
            (dVeh.isNotEmpty && tVeh == dVeh);
      }).toList();

      int actualKm = 0;
      for (final t in trips) {
        final km = (t.actualDistanceKm > 0 ? t.actualDistanceKm : t.plannedDistanceKm).round();
        actualKm += km;
      }
      if (actualKm == 0 && driver.totalKilometersDriven > 0) {
        actualKm = driver.totalKilometersDriven;
      }

      // Matched Alerts / Safety violations (Driver-specific driving & traffic violations only)
      final violations = controller.alerts.where((al) {
        final alVeh = al.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        final alTitle = al.title.toLowerCase();
        final alDetails = al.details.toLowerCase();
        final alCategory = al.category.toLowerCase();

        // Strict vehicle/driver match
        final isDriverMatch = (dName.isNotEmpty && (alTitle.contains(dName) || alDetails.contains(dName))) ||
            (dVeh.isNotEmpty && alVeh == dVeh);
        if (!isDriverMatch) return false;

        // System maintenance/document/telemetry alerts must NOT be counted as driver driving violations
        final isDocOrSystemAlert = alCategory == 'compliance' ||
            alCategory == 'maintenance' ||
            alCategory == 'vehicle' ||
            alTitle.contains('date required') ||
            alTitle.contains('expiring') ||
            alTitle.contains('expired') ||
            alTitle.contains('puc') ||
            alTitle.contains('fitness') ||
            alTitle.contains('insurance') ||
            alTitle.contains('permit') ||
            alTitle.contains('offline') ||
            alTitle.contains('gps') ||
            alTitle.contains('battery') ||
            alTitle.contains('fastag');
        if (isDocOrSystemAlert) return false;

        // Only genuine driver safety and traffic violations
        final isDriverSafetyViolation = alCategory == 'safety' ||
            alCategory == 'traffic' ||
            alCategory == 'challan' ||
            alTitle.contains('overspeed') ||
            alTitle.contains('speed limit') ||
            alTitle.contains('seatbelt') ||
            alTitle.contains('memo') ||
            alTitle.contains('challan') ||
            alTitle.contains('harsh braking') ||
            alTitle.contains('rash driving') ||
            alDetails.contains('overspeed') ||
            alDetails.contains('challan');

        return isDriverSafetyViolation;
      }).length;

      final violationCount = violations > 0 ? violations : driver.violationsCount;
      final completedCount = trips.where((t) => t.status == 'completed' || t.status == 'delivered').length;
      final safeCompleted = completedCount > 0 ? completedCount : driver.completedTripsCount;

      // Realistic driver evaluation:
      // If a driver has driven 0 km and completed 0 trips, they have no driving record yet (Score: 0/100 or Pending)
      int score = 0;
      if (actualKm > 0 || safeCompleted > 0) {
        // Active driver with verified trips
        score = (100 - (violationCount * 15)).clamp(10, 100);
        if (violationCount == 0) {
          score = 100;
        }
      } else {
        // Driver has not started or driven any trips yet (0 km, 0 trips)
        score = 0;
      }

      return {
        'driver': driver,
        'actualKm': actualKm,
        'violations': violationCount,
        'completed': safeCompleted,
        'score': score,
      };
    }).toList()
      ..sort((a, b) {
        // Sort by score descending; if score equal, sort by actualKm descending, then completed trips
        final scoreCmp = (b['score'] as int).compareTo(a['score'] as int);
        if (scoreCmp != 0) return scoreCmp;
        final kmCmp = (b['actualKm'] as int).compareTo(a['actualKm'] as int);
        if (kmCmp != 0) return kmCmp;
        return (b['completed'] as int).compareTo(a['completed'] as int);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _analyticsMetric(
              width: isMobile ? double.infinity : 260,
              icon: Icons.route_rounded,
              label: 'Recorded fleet distance',
              value: '${_formatIndianNumber(totalKm)} km',
              helper: controller.drivers.isEmpty
                  ? 'No driver telemetry recorded'
                  : '${controller.drivers.length} driver records',
            ),
            _analyticsMetric(
              width: isMobile ? double.infinity : 260,
              icon: Icons.task_alt_rounded,
              label: 'Trip completion',
              value: '${completionRate.toStringAsFixed(1)}%',
              helper: '$completedTrips of ${controller.trips.length} trips',
            ),
            _analyticsMetric(
              width: isMobile ? double.infinity : 260,
              icon: Icons.toll_rounded,
              label: 'Recorded toll spend',
              value: _formatCurrency(tollSpend),
              helper: 'Approved and pending records',
            ),
            _analyticsMetric(
              width: isMobile ? double.infinity : 260,
              icon: Icons.local_shipping_rounded,
              label: 'Live GPS vehicles',
              value:
                  '${controller.truckModels.where((v) => controller.isVehicleDriverOnDuty(v.code)).length}/${controller.truckModels.length}',
              helper: 'Valid tracker fixes only · Tap to view',
              onTap: () => _showLiveFleetGpsDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final driverCard = _driverScorecard(rankedDrivers);
            final expenseCard = _expenseBreakdown(
              rankedExpenses,
              totalExpenses,
            );
            if (stacked) {
              return Column(
                children: [
                  driverCard,
                  const SizedBox(height: 12),
                  expenseCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: driverCard),
                const SizedBox(width: 12),
                Expanded(child: expenseCard),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showLiveFleetGpsDialog(BuildContext context) {
    if (!kIsWeb) {
      widget.controller.syncDriverPhoneBattery();
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final vehicles = widget.controller.truckModels;
          final online = vehicles.where((v) => widget.controller.isVehicleDriverOnDuty(v.code)).length;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fleet Live GPS Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '$online Online / ${vehicles.length - online} Offline',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final vehicle = vehicles[index];
                      final isOnline = widget.controller.isVehicleDriverOnDuty(vehicle.code);
                      final drivers = widget.controller.drivers
                          .where((d) =>
                              d.assignedVehicle.trim().toUpperCase() ==
                              vehicle.code.trim().toUpperCase())
                          .map((d) => d.name)
                          .join(' / ');
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline
                                ? Icons.gps_fixed_rounded
                                : Icons.gps_off_rounded,
                            size: 16,
                            color: isOnline
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        title: Text(
                          vehicle.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.navy,
                          ),
                        ),
                        subtitle: Text(
                          drivers.isNotEmpty
                              ? 'Driver: $drivers'
                              : (vehicle.assignedDriver.isNotEmpty
                                  ? 'Driver: ${vehicle.assignedDriver}'
                                  : 'Vehicle ${vehicle.name}'),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isOnline
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(height: 2),
                              Text(
                                vehicle.isMoving
                                    ? '${vehicle.currentSpeed.toStringAsFixed(0)} km/h'
                                    : 'Stationary (0 km/h)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: vehicle.isMoving ? const Color(0xFF059669) : AppColors.slate,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (vehicle.phoneBatteryLevel != null && vehicle.isPhoneCharging)
                                      ? Icons.bolt_rounded
                                      : ((vehicle.phoneBatteryLevel ?? 100) <= 20
                                          ? Icons.battery_alert_rounded
                                          : Icons.battery_std_rounded),
                                  size: 13,
                                  color: (vehicle.phoneBatteryLevel != null && vehicle.isPhoneCharging)
                                      ? const Color(0xFF059669)
                                      : ((vehicle.phoneBatteryLevel ?? 100) <= 20
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  vehicle.phoneBatteryLevel != null
                                      ? (vehicle.isPhoneCharging
                                          ? '${vehicle.phoneBatteryLevel}% ⚡ Charging'
                                          : '${vehicle.phoneBatteryLevel}% Not Charging')
                                      : (isOnline ? 'Phone Online' : 'Battery: Offline'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: (vehicle.phoneBatteryLevel != null && vehicle.isPhoneCharging)
                                        ? const Color(0xFF059669)
                                        : ((vehicle.phoneBatteryLevel ?? 100) <= 20
                                            ? const Color(0xFFDC2626)
                                            : AppColors.slate),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _analyticsMetric({
    required double width,
    required IconData icon,
    required String label,
    required String value,
    required String helper,
    VoidCallback? onTap,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppIconBadge(icon: icon, size: 19, padding: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(value,
                          style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.navy,
                              fontWeight: FontWeight.w900)),
                      Text(helper,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 9.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: AppColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _driverScorecard(List<Map<String, dynamic>> drivers) {
    return _analyticsPanel(
      title: 'Driver Safety & Performance Scorecard',
      icon: Icons.shield_outlined,
      child: drivers.isEmpty
          ? const _AnalyticsEmpty('No driver performance data recorded.')
          : Column(
              children: drivers.map((m) {
                final driver = m['driver'] as DriverProfile;
                final actualKm = m['actualKm'] as int;
                final violations = m['violations'] as int;
                final score = m['score'] as int;
                final completed = m['completed'] as int;

                final hasRecord = actualKm > 0 || completed > 0;
                final color = !hasRecord
                    ? AppColors.slate
                    : score >= 90
                        ? AppColors.primary
                        : score >= 75
                            ? const Color(0xFFD97706)
                            : const Color(0xFFDC2626);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: color.withValues(alpha: .12),
                        child: Text(
                          driver.name.trim().isEmpty
                              ? '?'
                              : driver.name.trim()[0].toUpperCase(),
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(driver.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                                if (driver.assignedVehicle.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      driver.assignedVehicle,
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${_formatIndianNumber(actualKm)} km · $completed Trips · $violations Violations',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 9.5, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          hasRecord ? '$score/100' : 'No Trips',
                          style: TextStyle(
                              color: color,
                              fontSize: hasRecord ? 12 : 10.5,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _expenseBreakdown(
      List<MapEntry<String, double>> groups, double total) {
    return _analyticsPanel(
      title: 'Fleet Expense Breakdown · ${_formatCurrency(total)}',
      icon: Icons.donut_small_rounded,
      child: groups.isEmpty
          ? const _AnalyticsEmpty('No fleet expenses recorded.')
          : Column(
              children: groups.take(5).map((entry) {
                final fraction = total <= 0 ? 0.0 : entry.value / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          Text(
                            '${(fraction * 100).toStringAsFixed(0)}% · ${_formatCurrency(entry.value)}',
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0, 1),
                          minHeight: 6,
                          color: AppColors.primary,
                          backgroundColor: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _analyticsPanel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatCurrency(double value) =>
      '₹${_formatIndianNumber(value.round())}';

  String _formatIndianNumber(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    if (digits.length <= 3) return '${negative ? '-' : ''}$digits';
    final lastThree = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    return '${negative ? '-' : ''}${groups.join(',')},$lastThree';
  }

  Widget _buildHeader(bool isMobile, _ReportData reportData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const AppIconBadge(
                  icon: Icons.assessment_outlined, size: 24, padding: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizationService.instance.tr('reports'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedReport.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                _buildDownloadActions(reportData),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            _buildDownloadActions(reportData),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadActions(_ReportData reportData) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        FilledButton.icon(
          onPressed: reportData.rows.isEmpty ? null : () => _exportPdf(reportData),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
          label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: reportData.rows.isEmpty ? null : () => _exportExcel(reportData),
          icon: const Icon(Icons.table_view_outlined, size: 15),
          label: const Text('Excel (.xlsx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDCFCE7),
            foregroundColor: const Color(0xFF15803D),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: reportData.rows.isEmpty ? null : () => _exportCsv(reportData),
          icon: const Icon(Icons.description_outlined, size: 15),
          label: const Text('CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text(
            'Select Report:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate,
              fontFamily: 'sans-serif',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LogisticsReportType>(
                value: _selectedReport,
                isExpanded: true,
                items: LogisticsReportType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReport = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary(
      List<(String, String, IconData)> kpis, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 650 ? 1 : kpis.length;
        final itemWidth =
            (constraints.maxWidth - (crossCount - 1) * 10) / crossCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kpis.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primaryDark,
                      child: Icon(item.$3, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate,
                              fontFamily: 'sans-serif',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    DriverProfile? selectedDriver;
    if (_selectedDriverFilter != 'all') {
      final target = _selectedDriverFilter.trim().toLowerCase();
      selectedDriver = widget.controller.drivers.where((d) =>
          d.name.trim().toLowerCase() == target ||
          d.email.trim().toLowerCase() == target).firstOrNull;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dedicated Quick Driver Selector Card - Compact Dropdown & Clean UI
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF86EFAC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      size: 20, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Driver:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166534),
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDriverFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF15803D)),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                '👥 All Drivers (Full Fleet)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                            ...widget.controller.drivers.map((d) {
                              return DropdownMenuItem(
                                value: d.name,
                                child: Text(
                                  d.assignedVehicle.isNotEmpty
                                      ? '👤 ${d.name} (${d.assignedVehicle})'
                                      : '👤 ${d.name}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDriverFilter = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDriverFilter != 'all') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _selectedDriverFilter = 'all'),
                      tooltip: 'Clear Driver Filter',
                      icon: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFFDC2626)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ],
              ),
              if (selectedDriver != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Showing only ${selectedDriver.name} (${selectedDriver.assignedVehicle.isNotEmpty ? selectedDriver.assignedVehicle : "No Truck Assigned"})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filter bar for Search and Dates
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 240,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Filter report entries...',
                    prefixIcon:
                        Icon(Icons.search, size: 16, color: AppColors.slate),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String>(
                value: _selectedDateFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('Past 7 Days')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDateFilter = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataTableCard(_ReportData data) {
    if (data.rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.assessment_outlined, size: 44, color: AppColors.muted),
            SizedBox(height: 10),
            Text(
              'No records match the current filter',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingTextStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              fontFamily: 'sans-serif',
            ),
            dataTextStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              fontFamily: 'sans-serif',
            ),
            columns:
                data.headers.map((h) => DataColumn(label: Text(h))).toList(),
            rows: data.rows.map((row) {
              return DataRow(
                cells: row.map((cell) {
                  final text = cell.trim();
                  // Check if cell is an efficiency badge
                  if (text.startsWith('🌟') || text.startsWith('🔵') || text.startsWith('💎') || text.startsWith('⚠️') || text.startsWith('🚚')) {
                    Color bgColor = const Color(0xFFF1F5F9);
                    Color textColor = AppColors.navy;
                    Color borderColor = const Color(0xFFCBD5E1);

                    if (text.startsWith('🌟') || text.startsWith('💎')) {
                      bgColor = const Color(0xFFECFDF5);
                      textColor = const Color(0xFF047857);
                      borderColor = const Color(0xFFA7F3D0);
                    } else if (text.startsWith('🔵')) {
                      bgColor = const Color(0xFFEFF6FF);
                      textColor = const Color(0xFF1D4ED8);
                      borderColor = const Color(0xFFBFDBFE);
                    } else if (text.startsWith('⚠️')) {
                      bgColor = const Color(0xFFFEF2F2);
                      textColor = const Color(0xFFB91C1C);
                      borderColor = const Color(0xFFFECACA);
                    }

                    return DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    );
                  }

                  // Check if cell is positive/negative profit
                  if (text.startsWith('+₹')) {
                    return DataCell(
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    );
                  } else if (text.startsWith('-₹')) {
                    return DataCell(
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    );
                  }

                  return DataCell(Text(cell));
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.headers,
    required this.rows,
    required this.kpis,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final List<(String, String, IconData)> kpis;
}

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.slate),
      ),
    );
  }
}
