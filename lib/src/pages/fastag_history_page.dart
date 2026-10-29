import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/real_fastag_service.dart';
import '../theme/app_theme.dart';
import 'operations_module_page.dart';

class FastagHistoryPage extends StatefulWidget {
  const FastagHistoryPage({
    required this.controller,
    required this.vehicleCode,
    super.key,
  });

  final PlannerController controller;
  final String vehicleCode;

  static Future<void> open(
    BuildContext context, {
    required PlannerController controller,
    required String vehicleCode,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FastagHistoryPage(
          controller: controller,
          vehicleCode: vehicleCode,
        ),
      ),
    );
  }

  @override
  State<FastagHistoryPage> createState() => _FastagHistoryPageState();
}

class _FastagHistoryPageState extends State<FastagHistoryPage> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.vehicleCode;
    if (_selectedCode.isEmpty && widget.controller.truckModels.isNotEmpty) {
      _selectedCode = widget.controller.truckModels.first.code;
    }
  }

  TruckModel? _findVehicle() {
    for (final vehicle in widget.controller.truckModels) {
      if (vehicle.code.trim().toLowerCase() == _selectedCode.trim().toLowerCase()) {
        return vehicle;
      }
    }
    if (widget.controller.truckModels.isNotEmpty) {
      return widget.controller.truckModels.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final vehicle = _findVehicle();
          if (vehicle == null) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                title: const Text('FASTag Wallet & Recharge',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              body: const Center(child: Text('No vehicles found in fleet.')),
            );
          }
          final records = vehicle.fastagRecharges.reversed.toList();
          final total =
              records.fold<double>(0, (sum, item) => sum + item.amount);
          final tIdx = widget.controller.truckModels
              .indexWhere((t) => t.code == vehicle.code);

          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FASTag Wallet & Recharge',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Real NETC NPCI Vehicle UPI Payment',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.controller.truckModels.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedCode,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: widget.controller.truckModels.map((t) {
                          return DropdownMenuItem<String>(
                            value: t.code,
                            child: Text(
                              t.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCode = val);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Real Live Balance Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3316A34A),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0x33FFFFFF),
                            foregroundColor: Colors.white,
                            radius: 22,
                            child: Icon(Icons.toll_rounded, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  vehicle.name,
                                  style: const TextStyle(
                                    color: Color(0xFFD1FAE5),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (vehicle.isFastagLow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LOW BALANCE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available FASTag Balance',
                                style: TextStyle(
                                  color: Color(0xFFD1FAE5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${vehicle.fastagBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => FastagRechargeDialog(
                                vehicle: vehicle,
                                truckIndex: tIdx >= 0 ? tIdx : 0,
                                controller: widget.controller,
                              ),
                            ),
                            icon: const Icon(Icons.send_to_mobile_rounded, size: 16),
                            label: const Text(
                              'Recharge / Send Money',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF065F46),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x26000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFF6EE7B7), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Real VPA: ${RealFastagService.instance.buildNetcUpiVpa(vehicleNumber: vehicle.code, bankId: "paytm")}',
                                style: const TextStyle(
                                  color: Color(0xFFE6FFFA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Direct Recharge Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Pay via UPI',
                        subtitle: 'GPay, PhonePe, Paytm',
                        color: const Color(0xFF2563EB),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => FastagRechargeDialog(
                            vehicle: vehicle,
                            truckIndex: tIdx >= 0 ? tIdx : 0,
                            controller: widget.controller,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Scan QR Code',
                        subtitle: 'Instant NETC VPA',
                        color: const Color(0xFF0D9488),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => FastagRechargeDialog(
                            vehicle: vehicle,
                            truckIndex: tIdx >= 0 ? tIdx : 0,
                            controller: widget.controller,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'Total Recharges',
                        value: '${records.length}',
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(
                        label: 'Total Recharged',
                        value: '₹${total.toStringAsFixed(0)}',
                        icon: Icons.savings_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Recharge & Transaction History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 12),

                if (records.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 50, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFDCFCE7),
                          foregroundColor: AppColors.primary,
                          child: Icon(Icons.toll_rounded, size: 28),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No FASTag recharge transactions recorded yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Click "Recharge / Send Money" above to make a real UPI payment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ],
                    ),
                  )
                else
                  ...records.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFDCFCE7),
                            foregroundColor: AppColors.primary,
                            child: Icon(Icons.toll_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.provider,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '+ ₹${item.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Date: ${item.date}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                  ),
                                ),
                                Text(
                                  'Ref / UTR: ${item.rechargeId}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                  ),
                                ),
                                if (item.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item.notes,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              foregroundColor: color,
              radius: 18,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.slate,
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
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.navy,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
            ),
          ],
        ),
      );
}
