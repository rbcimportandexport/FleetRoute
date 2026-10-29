import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/app_localization_service.dart';
import '../theme/app_theme.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({
    required this.controller,
    super.key,
  });

  final PlannerController controller;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  String _selectedStatusFilter = 'all'; // all, pending, partially_paid, paid
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BillingRecord> _filterRecords(List<BillingRecord> records) {
    final query = _searchController.text.trim().toLowerCase();

    return records.where((b) {
      if (_selectedStatusFilter != 'all') {
        if (_selectedStatusFilter == 'unpaid' && b.paymentStatus != 'pending') {
          return false;
        }
        if (_selectedStatusFilter == 'partially_paid' &&
            b.paymentStatus != 'partially_paid') {
          return false;
        }
        if (_selectedStatusFilter == 'paid' && b.paymentStatus != 'paid') {
          return false;
        }
      }

      if (query.isNotEmpty) {
        final match = b.invoiceNumber.toLowerCase().contains(query) ||
            b.customerName.toLowerCase().contains(query) ||
            b.tripId.toLowerCase().contains(query) ||
            b.tripNumber.toLowerCase().contains(query) ||
            b.notes.toLowerCase().contains(query);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  void _showInvoiceDialog(BillingRecord bill) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const AppIconBadge(
                        icon: Icons.receipt_long_rounded, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tax Invoice #${bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : bill.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Date: ${bill.invoiceDate.isNotEmpty ? bill.invoiceDate : "Standard"} · Trip #${bill.tripNumber.isNotEmpty ? bill.tripNumber : bill.tripId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ],
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

              // Invoice Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company & Customer info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRANSPORTER:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'FleetRoute Logistics Pvt Ltd',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                                Text(
                                  'Company GSTIN/address not configured',
                                  style: TextStyle(
                                      fontSize: 11.5, color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BILLED TO:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bill.customerName.isNotEmpty
                                      ? bill.customerName
                                      : 'Direct Customer',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const Text(
                                  'Customer GSTIN/address not configured',
                                  style: TextStyle(
                                      fontSize: 11.5, color: AppColors.slate),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      // Itemized Charges
                      const Text(
                        'Freight & Ancillary Charges Breakdown',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildInvoiceRow('Base Freight Rate', bill.freightRate),
                      if (bill.deliveryCharge > 0)
                        _buildInvoiceRow('Delivery / Local Drop Charge',
                            bill.deliveryCharge),
                      if (bill.loadingUnloadingCharge > 0)
                        _buildInvoiceRow('Loading & Unloading Hamali',
                            bill.loadingUnloadingCharge),
                      if (bill.waitingCharge > 0)
                        _buildInvoiceRow(
                            'Halting / Detention Charge', bill.waitingCharge),
                      if (bill.parkingCharge > 0)
                        _buildInvoiceRow(
                            'Parking & Toll Surcharge', bill.parkingCharge),
                      if (bill.otherCharges > 0)
                        _buildInvoiceRow(
                            'Other Ancillary Charges', bill.otherCharges),

                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 8),

                      // Total & Balance summary
                      _buildSummaryRow(
                          'Total Invoiced Amount', bill.totalAmount,
                          isBold: true),
                      const SizedBox(height: 6),
                      _buildSummaryRow(
                        'Total Payments Received',
                        bill.totalPaid,
                        color: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 6),
                      _buildSummaryRow(
                        'Outstanding Balance Due',
                        bill.balanceDue,
                        color: bill.balanceDue > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                        isBold: true,
                      ),

                      if (bill.payments.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 10),
                        const Text(
                          'Payment Audit Ledger',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final p in bill.payments)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 14, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.paymentDate} · ${p.paymentMethod.toUpperCase()}${p.referenceNumber.isNotEmpty ? " · Ref: ${p.referenceNumber}" : ""}',
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.slate),
                                  ),
                                ),
                                Text(
                                  '₹${p.amount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Tax invoice printed / sent to customer WhatsApp'),
                            backgroundColor: AppColors.primaryDark,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print / Share'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String item, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item,
              style: const TextStyle(fontSize: 12, color: AppColors.slate)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.navy),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.navy,
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateBillDialog() async {
    final trips = widget.controller.trips;
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trips available. Please create a trip first.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    TripRecord selectedTrip = trips.first;
    String customerName = selectedTrip.customerName;
    double freightRate = selectedTrip.freightAmount;
    double deliveryCharge = 0.0;
    double loadingCharge = 0.0;
    double waitingCharge = 0.0;
    double parkingCharge = 0.0;
    String invoiceNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    String invoiceDate = DateTime.now().toIso8601String().substring(0, 10);
    final notesController = TextEditingController();

    final result = await showDialog<BillingRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                AppIconBadge(icon: Icons.payments_outlined, size: 20),
                SizedBox(width: 10),
                Text(
                  'Generate Customer Invoice',
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
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedTrip.effectiveTripNumber,
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
                          final match = trips
                              .firstWhere((t) => t.effectiveTripNumber == val);
                          setDlgState(() {
                            selectedTrip = match;
                            customerName = match.customerName;
                            freightRate = match.freightAmount;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: customerName,
                      decoration: const InputDecoration(
                          labelText: 'Customer / Consignee Name',
                          isDense: true),
                      onChanged: (val) => customerName = val.trim(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: invoiceNumber,
                            decoration: const InputDecoration(
                                labelText: 'Invoice #', isDense: true),
                            onChanged: (val) => invoiceNumber = val.trim(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: invoiceDate,
                            decoration: const InputDecoration(
                                labelText: 'Invoice Date', isDense: true),
                            onChanged: (val) => invoiceDate = val.trim(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: freightRate.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Base Freight (INR)',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onChanged: (val) =>
                                freightRate = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: deliveryCharge.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Delivery Charge (INR)',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onChanged: (val) =>
                                deliveryCharge = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: loadingCharge.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Loading/Hamali (INR)',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onChanged: (val) =>
                                loadingCharge = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: waitingCharge.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Detention / Halting',
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onChanged: (val) =>
                                waitingCharge = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                          labelText: 'Payment Terms / Notes', isDense: true),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final newBill = BillingRecord(
                    id: 'BILL-${DateTime.now().millisecondsSinceEpoch}',
                    tripId: selectedTrip.effectiveTripNumber,
                    tripNumber: selectedTrip.effectiveTripNumber,
                    customerName: customerName,
                    freightRate: freightRate,
                    deliveryCharge: deliveryCharge,
                    loadingUnloadingCharge: loadingCharge,
                    waitingCharge: waitingCharge,
                    parkingCharge: parkingCharge,
                    invoiceNumber: invoiceNumber,
                    invoiceDate: invoiceDate,
                    notes: notesController.text.trim(),
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  Navigator.pop(ctx, newBill);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Invoice'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await widget.controller.addBillingRecord(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Invoice #${result.invoiceNumber} created for ${result.customerName}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _openRecordPaymentDialog(BillingRecord bill) async {
    double paymentAmount = bill.balanceDue > 0 ? bill.balanceDue : 5000.0;
    String paymentMode = 'bank_transfer';
    String reference =
        'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const AppIconBadge(
                    icon: Icons.account_balance_wallet_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Record Payment: ${bill.customerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Total Bill: ₹${bill.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(
                            'Balance Due: ₹${bill.balanceDue.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: paymentAmount.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment Received (INR)',
                      prefixText: '₹ ',
                      isDense: true,
                    ),
                    onChanged: (val) =>
                        paymentAmount = double.tryParse(val) ?? 0.0,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMode,
                    decoration: const InputDecoration(
                        labelText: 'Payment Mode', isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(
                          value: 'upi',
                          child: Text('UPI (GooglePay / PhonePe)')),
                      DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => paymentMode = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: reference,
                    decoration: const InputDecoration(
                        labelText: 'Transaction / Cheque Reference #',
                        isDense: true),
                    onChanged: (val) => reference = val.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        labelText: 'Receipt Notes', isDense: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (paymentAmount <= 0) return;
                  Navigator.pop(ctx, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Payment'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await widget.controller.recordPayment(
        billId: bill.id,
        payment: PaymentTransaction(
          id: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
          amount: paymentAmount,
          paymentDate: DateTime.now().toIso8601String().substring(0, 10),
          paymentMethod: paymentMode,
          referenceNumber: reference,
          notes: notesController.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payment of ₹${paymentAmount.toStringAsFixed(0)} recorded for ${bill.customerName}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final allRecords = widget.controller.billingRecords;
        final filteredRecords = _filterRecords(allRecords);

        final totalBilled =
            allRecords.fold<double>(0.0, (sum, b) => sum + b.totalAmount);
        final totalCollected =
            allRecords.fold<double>(0.0, (sum, b) => sum + b.totalPaid);
        final totalOutstanding =
            allRecords.fold<double>(0.0, (sum, b) => sum + b.balanceDue);

        final unpaidCount = allRecords.where((b) => b.balanceDue > 0).length;

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
                        _buildKpiSummary(
                          totalBilled: totalBilled,
                          totalCollected: totalCollected,
                          totalOutstanding: totalOutstanding,
                          unpaidCount: unpaidCount,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildFilterBar(isMobile),
                        const SizedBox(height: 16),
                        if (filteredRecords.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredRecords.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final bill = filteredRecords[index];
                              return _buildBillingCard(bill);
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
              icon: Icons.payments_outlined, size: 24, padding: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizationService.instance.tr('billing'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.navy,
                    fontFamily: 'sans-serif',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Commercial invoicing, payment collection, and customer receivables aging',
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
            onPressed: _openCreateBillDialog,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              isMobile ? 'Invoice' : 'Create Bill',
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

  Widget _buildKpiSummary({
    required double totalBilled,
    required double totalCollected,
    required double totalOutstanding,
    required int unpaidCount,
    required bool isMobile,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 650 ? 1 : 3;
        final itemWidth =
            (constraints.maxWidth - (crossCount - 1) * 10) / crossCount;

        final items = [
          (
            'Total Invoiced',
            '₹${totalBilled.toStringAsFixed(0)}',
            Icons.receipt_outlined,
            const Color(0xFF0284C7),
          ),
          (
            'Collected / Paid',
            '₹${totalCollected.toStringAsFixed(0)}',
            Icons.check_circle_outline,
            const Color(0xFF16A34A),
          ),
          (
            'Outstanding Receivables',
            '₹${totalOutstanding.toStringAsFixed(0)} ($unpaidCount pending)',
            Icons.pending_actions_outlined,
            totalOutstanding > 0
                ? const Color(0xFFDC2626)
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
            width: isMobile ? double.infinity : 240,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customer, invoice #, trip...',
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
            value: _selectedStatusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                  value: 'all', child: Text('All Payment Statuses')),
              DropdownMenuItem(
                  value: 'unpaid', child: Text('Unpaid / Pending')),
              DropdownMenuItem(
                  value: 'partially_paid', child: Text('Partially Paid')),
              DropdownMenuItem(value: 'paid', child: Text('Fully Paid')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatusFilter = val);
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
          Icon(Icons.payments_outlined, size: 44, color: AppColors.muted),
          SizedBox(height: 10),
          Text(
            'No billing records found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontFamily: 'sans-serif',
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Click "Create Bill" to invoice customer shipments and track payments.',
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

  Widget _buildBillingCard(BillingRecord bill) {
    final statusColor = switch (bill.paymentStatus) {
      'paid' => const Color(0xFF16A34A),
      'partially_paid' => const Color(0xFFD97706),
      _ => const Color(0xFFDC2626),
    };
    final statusBg = statusColor.withValues(alpha: 0.1);

    final progress = bill.totalAmount > 0
        ? (bill.totalPaid / bill.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(icon: Icons.description_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bill.customerName.isNotEmpty
                                ? bill.customerName
                                : 'Direct Logistics',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.navy,
                              fontFamily: 'sans-serif',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bill.paymentStatus
                                .toUpperCase()
                                .replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              fontFamily: 'sans-serif',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Invoice #${bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : bill.id} · Trip #${bill.tripNumber.isNotEmpty ? bill.tripNumber : bill.tripId}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${bill.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  if (bill.balanceDue > 0)
                    Text(
                      'Bal: ₹${bill.balanceDue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                        fontFamily: 'sans-serif',
                      ),
                    )
                  else
                    const Text(
                      'Paid in Full',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                        fontFamily: 'sans-serif',
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Collection progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),

          // Actions & Payment History
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showInvoiceDialog(bill),
                icon: const Icon(Icons.receipt_long_outlined, size: 14),
                label: const Text('View Invoice',
                    style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const Spacer(),
              if (bill.balanceDue > 0)
                FilledButton.icon(
                  onPressed: () => _openRecordPaymentDialog(bill),
                  icon: const Icon(Icons.add_card_rounded, size: 14),
                  label: const Text('Record Payment',
                      style: TextStyle(fontSize: 11.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
