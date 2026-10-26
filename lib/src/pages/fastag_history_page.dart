import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';

class FastagHistoryPage extends StatelessWidget {
  const FastagHistoryPage(
      {required this.controller, required this.vehicleCode, super.key});

  final PlannerController controller;
  final String vehicleCode;

  static Future<void> open(BuildContext context,
      {required PlannerController controller, required String vehicleCode}) {
    return Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => FastagHistoryPage(
              controller: controller, vehicleCode: vehicleCode),
        ));
  }

  TruckModel? _findVehicle() {
    for (final vehicle in controller.truckModels) {
      if (vehicle.code.trim().toLowerCase() == vehicleCode.trim().toLowerCase())
        return vehicle;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final vehicle = _findVehicle();
          if (vehicle == null) {
            return Scaffold(
                appBar: AppBar(title: const Text('FASTag History')),
                body: const Center(child: Text('Vehicle record not found.')));
          }
          final records = vehicle.fastagRecharges.reversed.toList();
          final total =
              records.fold<double>(0, (sum, item) => sum + item.amount);
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FASTag Recharge History',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Complete vehicle transaction ledger',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ]),
            ),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF16A34A)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const CircleAvatar(
                            backgroundColor: Color(0x33FFFFFF),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.toll_rounded)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(vehicle.code,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900)),
                              Text(vehicle.name,
                                  style: const TextStyle(
                                      color: Color(0xFFD1FAE5), fontSize: 12)),
                            ])),
                        if (vehicle.isFastagLow)
                          const Chip(
                              label: Text('LOW',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900)),
                              backgroundColor: Color(0xFFFEE2E2),
                              side: BorderSide.none),
                      ]),
                      const SizedBox(height: 22),
                      const Text('Available Balance',
                          style: TextStyle(
                              color: Color(0xFFD1FAE5), fontSize: 11)),
                      Text('₹${vehicle.fastagBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900)),
                    ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _Stat(
                        label: 'Transactions', value: '${records.length}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: 'Total Recharged',
                        value: '₹${total.toStringAsFixed(0)}')),
              ]),
              const SizedBox(height: 22),
              const Text('All Recharge Transactions',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 10),
              if (records.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border)),
                  child: const Column(children: [
                    CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFFDCFCE7),
                        foregroundColor: AppColors.primary,
                        child: Icon(Icons.receipt_long_outlined, size: 30)),
                    SizedBox(height: 14),
                    Text('No FASTag recharge transactions yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    SizedBox(height: 6),
                    Text(
                        'Recharge hone ke baad complete history yahan show hogi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ]),
                )
              else
                ...records.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                foregroundColor: AppColors.primary,
                                child: Icon(Icons.toll_rounded)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(item.provider,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800))),
                                    Text('+ ₹${item.amount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary))
                                  ]),
                                  const SizedBox(height: 5),
                                  Text('Date: ${item.date}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate)),
                                  Text('Ref: ${item.rechargeId}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate)),
                                  if (item.notes.isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(item.notes,
                                            style: const TextStyle(
                                                fontSize: 11.5))),
                                ])),
                          ]),
                    )),
            ]),
          );
        },
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy)),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.slate)),
        ]),
      );
}
