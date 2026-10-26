import 'dart:convert';
import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/app_localization_service.dart';
import '../theme/app_theme.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({
    required this.controller,
    super.key,
  });

  final PlannerController controller;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String _selectedTab = 'all'; // all, direct, indirect
  String _selectedStatusFilter = 'all'; // all, pending, approved, rejected
  String _selectedCategoryFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseRecord> _filterExpenses(List<ExpenseRecord> expenses) {
    final query = _searchController.text.trim().toLowerCase();

    return expenses.where((exp) {
      if (_selectedTab == 'direct' && !exp.isDirect) return false;
      if (_selectedTab == 'indirect' && exp.isDirect) return false;

      if (_selectedStatusFilter != 'all' &&
          exp.status != _selectedStatusFilter) {
        return false;
      }

      if (_selectedCategoryFilter != 'all' &&
          exp.category.toLowerCase() != _selectedCategoryFilter.toLowerCase()) {
        return false;
      }

      if (query.isNotEmpty) {
        final match = exp.category.toLowerCase().contains(query) ||
            exp.tripId.toLowerCase().contains(query) ||
            exp.vehicleNumber.toLowerCase().contains(query) ||
            exp.driverName.toLowerCase().contains(query) ||
            exp.notes.toLowerCase().contains(query);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  void _showReceiptDialog(String receiptBase64, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const AppIconBadge(
                        icon: Icons.receipt_long_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: AppColors.slate),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Builder(
                      builder: (_) {
                        try {
                          String clean = receiptBase64;
                          if (clean.contains(',')) {
                            clean = clean.split(',').last;
                          }
                          final bytes = base64Decode(clean.trim());
                          return Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                              'Unable to render image. Invalid file format.',
                              style: TextStyle(color: AppColors.slate),
                            ),
                          );
                        } catch (_) {
                          return const Text(
                            'Unable to decode receipt preview.',
                            style: TextStyle(color: AppColors.slate),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddExpenseDialog() async {
    final trips = widget.controller.trips;
    final trucks = widget.controller.truckModels;
    final drivers = widget.controller.drivers;

    bool isDirect = true;
    String category = 'Diesel';
    String selectedTripId =
        trips.isNotEmpty ? trips.first.effectiveTripNumber : '';
    String vehicleNumber = trucks.isNotEmpty ? trucks.first.code : '';
    String driverName = drivers.isNotEmpty ? drivers.first.name : '';
    String date = DateTime.now().toIso8601String().substring(0, 10);
    double amount = 0.0;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<ExpenseRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                AppIconBadge(icon: Icons.receipt_long_outlined, size: 20),
                SizedBox(width: 10),
                Text(
                  'Record Fleet Expense',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Direct vs Indirect toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => isDirect = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDirect
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isDirect
                                      ? const [
                                          BoxShadow(
                                              color: Color(0x11000000),
                                              blurRadius: 4)
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Direct (Trip-linked)',
                                  style: TextStyle(
                                    fontWeight: isDirect
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                    color: isDirect
                                        ? AppColors.primaryDark
                                        : AppColors.slate,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => isDirect = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isDirect
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !isDirect
                                      ? const [
                                          BoxShadow(
                                              color: Color(0x11000000),
                                              blurRadius: 4)
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Indirect (Fleet / Admin)',
                                  style: TextStyle(
                                    fontWeight: !isDirect
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                    color: !isDirect
                                        ? AppColors.primaryDark
                                        : AppColors.slate,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                          labelText: 'Expense Category', isDense: true),
                      items: const [
                        DropdownMenuItem(
                            value: 'Diesel', child: Text('Diesel / Fuel')),
                        DropdownMenuItem(
                            value: 'Toll', child: Text('Toll Plaza')),
                        DropdownMenuItem(
                            value: 'Parking', child: Text('Parking Fee')),
                        DropdownMenuItem(
                            value: 'Driver Allowance',
                            child: Text('Driver Allowance / Bhatta')),
                        DropdownMenuItem(
                            value: 'Maintenance',
                            child: Text('Vehicle Repair / Maintenance')),
                        DropdownMenuItem(
                            value: 'Tyres', child: Text('Tyres & Parts')),
                        DropdownMenuItem(
                            value: 'Insurance',
                            child: Text('Insurance & Taxes')),
                        DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Office / Administrative')),
                        DropdownMenuItem(
                            value: 'Other', child: Text('Other Miscellaneous')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Trip selection (if direct)
                    if (isDirect && trips.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedTripId,
                        decoration: const InputDecoration(
                            labelText: 'Associated Trip', isDense: true),
                        items: trips.map((t) {
                          return DropdownMenuItem(
                            value: t.effectiveTripNumber,
                            child: Text(
                              'Trip #${t.effectiveTripNumber} (${t.origin} -> ${t.destination})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => selectedTripId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: vehicleNumber,
                            decoration: const InputDecoration(
                                labelText: 'Vehicle', isDense: true),
                            items: trucks.map((truck) {
                              return DropdownMenuItem(
                                  value: truck.code, child: Text(truck.code));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => vehicleNumber = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: driverName,
                            decoration: const InputDecoration(
                                labelText: 'Driver', isDense: true),
                            items: drivers.map((driver) {
                              return DropdownMenuItem(
                                  value: driver.name, child: Text(driver.name));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => driverName = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount (INR)',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: date,
                            decoration: const InputDecoration(
                              labelText: 'Date (YYYY-MM-DD)',
                              isDense: true,
                            ),
                            onChanged: (val) => date = val.trim(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Fuel Bill No.',
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid expense amount.'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                    return;
                  }

                  final newExpense = ExpenseRecord(
                    id: 'EXP-${DateTime.now().millisecondsSinceEpoch}',
                    tripId: isDirect ? selectedTripId : '',
                    vehicleNumber: vehicleNumber,
                    driverName: driverName,
                    category: category,
                    isDirect: isDirect,
                    amount: amount,
                    date: date,
                    notes: notesController.text.trim(),
                    status: widget.controller.isAdmin ? 'approved' : 'pending',
                    approvedBy: widget.controller.isAdmin ? 'Admin' : '',
                    approvedAt: widget.controller.isAdmin
                        ? DateTime.now().toIso8601String()
                        : '',
                    createdAt: DateTime.now().toIso8601String(),
                  );

                  Navigator.pop(ctx, newExpense);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Expense'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await widget.controller.addExpense(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Expense of ₹${result.amount.toStringAsFixed(0)} logged successfully'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _approveExpense(ExpenseRecord expense) async {
    await widget.controller.approveExpense(expense.id, 'Admin');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense approved successfully'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    }
  }

  Future<void> _rejectExpense(ExpenseRecord expense) async {
    await widget.controller
        .rejectExpense(expense.id, 'Admin', 'Administrative rejection');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense marked as rejected'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allExpenses = widget.controller.expenses;
        final filteredExpenses = _filterExpenses(allExpenses);

        // Profit and Loss calculations
        final totalRevenue = widget.controller.trips.fold<double>(
          0.0,
          (sum, t) => sum + t.freightAmount,
        );

        final totalDirectExp = allExpenses
            .where((e) => e.isDirect && e.status != 'rejected')
            .fold<double>(0.0, (sum, e) => sum + e.amount);

        final totalIndirectExp = allExpenses
            .where((e) => !e.isDirect && e.status != 'rejected')
            .fold<double>(0.0, (sum, e) => sum + e.amount);

        final totalExpenses = totalDirectExp + totalIndirectExp;
        final netProfit = totalRevenue - totalExpenses;
        final marginPercent =
            totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

        final pendingCount =
            allExpenses.where((e) => e.status == 'pending').length;

        return ColoredBox(
          color: AppColors.canvas,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
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
                        _buildHeader(isMobile),
                        const SizedBox(height: 16),
                        _buildProfitAndLossBar(
                          totalRevenue: totalRevenue,
                          totalExpenses: totalExpenses,
                          netProfit: netProfit,
                          marginPercent: marginPercent,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildKpiSummary(
                          totalDirectExp: totalDirectExp,
                          totalIndirectExp: totalIndirectExp,
                          pendingCount: pendingCount,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildFilterBar(isMobile),
                        const SizedBox(height: 16),
                        if (filteredExpenses.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredExpenses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final expense = filteredExpenses[index];
                              return _buildExpenseCard(expense);
                            },
                          ),
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

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const AppIconBadge(
              icon: Icons.receipt_long_outlined, size: 24, padding: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizationService.instance.tr('expenses'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Direct trip costs, fleet indirect expenses, and real-time net profit ledger',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openAddExpenseDialog,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              isMobile ? 'Add' : 'Add Expense',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontFamily: 'sans-serif',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitAndLossBar({
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required double marginPercent,
    required bool isMobile,
  }) {
    final isProfitable = netProfit >= 0;
    final profitColor =
        isProfitable ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final profitBg =
        isProfitable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            profitBg.withValues(alpha: 0.5),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: profitColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: profitColor),
              const SizedBox(width: 8),
              const Text(
                'Fleet Profit & Loss Overview (Financial Health)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.navy,
                  fontFamily: 'sans-serif',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: profitBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Margin: ${marginPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: profitColor,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFinancialMetric(
                  'Total Revenue',
                  '₹${totalRevenue.toStringAsFixed(0)}',
                  const Color(0xFF0284C7),
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _buildFinancialMetric(
                  'Total Expenses',
                  '₹${totalExpenses.toStringAsFixed(0)}',
                  const Color(0xFFDC2626),
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(
                child: _buildFinancialMetric(
                  'Net Profit / Loss',
                  '₹${netProfit.toStringAsFixed(0)}',
                  profitColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'sans-serif',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
            fontFamily: 'sans-serif',
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSummary({
    required double totalDirectExp,
    required double totalIndirectExp,
    required int pendingCount,
    required bool isMobile,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 650 ? 1 : 3;
        final itemWidth =
            (constraints.maxWidth - (crossCount - 1) * 10) / crossCount;

        final items = [
          (
            'Direct Trip Costs',
            '₹${totalDirectExp.toStringAsFixed(0)}',
            Icons.local_gas_station_outlined,
            AppColors.primary,
          ),
          (
            'Indirect Fleet Costs',
            '₹${totalIndirectExp.toStringAsFixed(0)}',
            Icons.build_outlined,
            const Color(0xFF7C3AED),
          ),
          (
            'Pending Manager Approval',
            '$pendingCount requests',
            Icons.pending_actions_outlined,
            pendingCount > 0
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
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
                      backgroundColor: item.$4.withValues(alpha: 0.12),
                      foregroundColor: item.$4,
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
    return Container(
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
            width: isMobile ? double.infinity : 220,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search category, trip, driver...',
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
            value: _selectedTab,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Costs')),
              DropdownMenuItem(value: 'direct', child: Text('Direct (Trip)')),
              DropdownMenuItem(
                  value: 'indirect', child: Text('Indirect (Fleet)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedTab = val);
            },
          ),
          DropdownButton<String>(
            value: _selectedStatusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Approvals')),
              DropdownMenuItem(
                  value: 'pending', child: Text('Pending Approval')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatusFilter = val);
            },
          ),
          DropdownButton<String>(
            value: _selectedCategoryFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Categories')),
              DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
              DropdownMenuItem(value: 'toll', child: Text('Toll')),
              DropdownMenuItem(value: 'parking', child: Text('Parking')),
              DropdownMenuItem(
                  value: 'driver allowance', child: Text('Driver Allowance')),
              DropdownMenuItem(
                  value: 'maintenance', child: Text('Maintenance')),
              DropdownMenuItem(value: 'tyres', child: Text('Tyres')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategoryFilter = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 10),
          Text(
            'No expense records found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontFamily: 'sans-serif',
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Click "Add Expense" above to record diesel slips, tolls, and maintenance bills.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              fontFamily: 'sans-serif',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseRecord expense) {
    final statusColor = switch (expense.status) {
      'approved' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };
    final statusBg = statusColor.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: expense.isDirect
                ? Icons.local_shipping_outlined
                : Icons.business_outlined,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      expense.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: expense.isDirect
                            ? AppColors.primarySoft
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.isDirect ? 'DIRECT' : 'INDIRECT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: expense.isDirect
                              ? AppColors.primaryDark
                              : AppColors.slate,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${expense.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (expense.tripId.isNotEmpty)
                      _buildChip(
                          Icons.route_outlined, 'Trip: ${expense.tripId}'),
                    if (expense.vehicleNumber.isNotEmpty)
                      _buildChip(
                          Icons.local_shipping_outlined, expense.vehicleNumber),
                    if (expense.driverName.isNotEmpty)
                      _buildChip(Icons.person_outline, expense.driverName),
                    _buildChip(Icons.calendar_today_outlined, expense.date),
                    if (expense.approvedBy.isNotEmpty)
                      _buildChip(
                          Icons.verified_outlined, 'By: ${expense.approvedBy}'),
                  ],
                ),
                if (expense.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Notes: ${expense.notes}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.slate,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (expense.receiptBase64.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.receipt_outlined,
                  size: 18, color: AppColors.primary),
              tooltip: 'View Receipt',
              onPressed: () => _showReceiptDialog(
                  expense.receiptBase64, '${expense.category} Receipt'),
            ),
          ],
          if (widget.controller.isAdmin && expense.isPending) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.check_circle_outline,
                  size: 20, color: Color(0xFF16A34A)),
              tooltip: 'Approve Expense',
              onPressed: () => _approveExpense(expense),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined,
                  size: 20, color: Color(0xFFDC2626)),
              tooltip: 'Reject Expense',
              onPressed: () => _rejectExpense(expense),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.slate),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
            fontFamily: 'sans-serif',
          ),
        ),
      ],
    );
  }
}
