import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class FastagBankIssuer {
  final String id;
  final String name;
  final String bbpsBillerId;
  final String upiHandle;

  const FastagBankIssuer({
    required this.id,
    required this.name,
    required this.bbpsBillerId,
    required this.upiHandle,
  });
}

class RealFastagService {
  RealFastagService._();
  static final RealFastagService instance = RealFastagService._();

  static const List<FastagBankIssuer> supportedIssuers = [
    FastagBankIssuer(
      id: 'icici',
      name: 'ICICI Bank FASTag',
      bbpsBillerId: 'ICIC00000FST',
      upiHandle: 'netc', // e.g. netc.GJ19Y2720@icici
    ),
    FastagBankIssuer(
      id: 'idfc',
      name: 'IDFC FIRST Bank FASTag',
      bbpsBillerId: 'IDFC00000FST',
      upiHandle: 'idfcbank',
    ),
    FastagBankIssuer(
      id: 'axis',
      name: 'Axis Bank FASTag',
      bbpsBillerId: 'UTIB00000FST',
      upiHandle: 'axisbank',
    ),
    FastagBankIssuer(
      id: 'sbi',
      name: 'State Bank of India (SBI) FASTag',
      bbpsBillerId: 'SBIN00000FST',
      upiHandle: 'sbi',
    ),
    FastagBankIssuer(
      id: 'kotak',
      name: 'Kotak Mahindra Bank FASTag',
      bbpsBillerId: 'KKBK00000FST',
      upiHandle: 'kotak',
    ),
    FastagBankIssuer(
      id: 'paytm',
      name: 'Paytm / HDFC FASTag',
      bbpsBillerId: 'HDFC00000FST',
      upiHandle: 'hdfcbank',
    ),
  ];

  /// Standard NETC NPCI VPA format for direct FASTag UPI payment:
  /// netc.<VehicleNumber>@<BankHandle>
  /// Example: netc.GJ19Y2720@icici or netc.GJ19Y2720@axisbank
  String buildNetcUpiVpa({
    required String vehicleNumber,
    required String bankId,
  }) {
    final cleanVehicle = vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final issuer = supportedIssuers.firstWhere(
      (i) => i.id == bankId,
      orElse: () => supportedIssuers.first,
    );
    return 'netc.$cleanVehicle@${issuer.upiHandle}';
  }

  /// Launches real UPI payment apps (GPay, PhonePe, Paytm, BHIM, Cred)
  /// directly paying into the vehicle's NPCI NETC FASTag account.
  Future<bool> initiateRealUpiPayment({
    required String vehicleNumber,
    required String bankId,
    required double amount,
    required String vehicleName,
  }) async {
    final vpa = buildNetcUpiVpa(vehicleNumber: vehicleNumber, bankId: bankId);
    final cleanVehicle = vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final amtStr = amount.toStringAsFixed(2);
    final note = 'FASTag Recharge for $cleanVehicle';

    // Standard NPCI UPI Deep Link specification
    final upiUrl = 'upi://pay?pa=$vpa&pn=NETC%20FASTag%20$cleanVehicle&am=$amtStr&cu=INR&tn=${Uri.encodeComponent(note)}';
    final uri = Uri.parse(upiUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback web intent / GPay intent
      final webFallback = 'https://paytm.com/fastag-recharge?vehicle=$cleanVehicle';
      final webUri = Uri.parse(webFallback);
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return false;
    }
  }

  /// Fetches real-time FASTag balance and recent toll plaza transaction logs
  /// via NPCI NETC / Bharat Bill Payment System (BBPS) API.
  Future<Map<String, dynamic>?> fetchLiveFastagBalance({
    required String vehicleNumber,
    required String bankId,
  }) async {
    final cleanVehicle = vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    try {
      // Endpoint connects to NETC NPCI gateway / BBPS bill fetch
      final uri = Uri.parse('https://api.transportone.in/v1/fastag/fetch-balance');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicleNumber': cleanVehicle,
          'bankId': bankId,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[RealFastagService] Live fetch error: $e');
    }
    return null;
  }
}

