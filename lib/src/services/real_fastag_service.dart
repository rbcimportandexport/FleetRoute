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
      id: 'paytm',
      name: 'Paytm Payments Bank / HDFC FASTag',
      bbpsBillerId: 'HDFC00000FST',
      upiHandle: 'paytm',
    ),
    FastagBankIssuer(
      id: 'icici',
      name: 'ICICI Bank FASTag',
      bbpsBillerId: 'ICIC00000FST',
      upiHandle: 'icici',
    ),
    FastagBankIssuer(
      id: 'sbi',
      name: 'State Bank of India (SBI) FASTag',
      bbpsBillerId: 'SBIN00000FST',
      upiHandle: 'sbi',
    ),
    FastagBankIssuer(
      id: 'axis',
      name: 'Axis Bank FASTag',
      bbpsBillerId: 'UTIB00000FST',
      upiHandle: 'axisbank',
    ),
    FastagBankIssuer(
      id: 'idfc',
      name: 'IDFC FIRST Bank FASTag',
      bbpsBillerId: 'IDFC00000FST',
      upiHandle: 'idfcbank',
    ),
    FastagBankIssuer(
      id: 'kotak',
      name: 'Kotak Mahindra Bank FASTag',
      bbpsBillerId: 'KKBK00000FST',
      upiHandle: 'kotak',
    ),
  ];

  /// Standard NETC NPCI VPA format for direct FASTag UPI payment:
  /// netc.<VehicleNumber>@<BankHandle>
  /// Example: netc.GJ19Y2720@paytm or netc.GJ19Y2720@icici
  String buildNetcUpiVpa({
    required String vehicleNumber,
    required String bankId,
  }) {
    final cleanVehicle =
        vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final issuer = supportedIssuers.firstWhere(
      (i) => i.id == bankId,
      orElse: () => supportedIssuers.first,
    );
    return 'netc.$cleanVehicle@${issuer.upiHandle}';
  }

  /// Builds the real standard NPCI UPI Intent URI string
  String buildUpiPaymentUriString({
    required String vehicleNumber,
    required String bankId,
    required double amount,
    String? payeeName,
  }) {
    final vpa = buildNetcUpiVpa(vehicleNumber: vehicleNumber, bankId: bankId);
    final cleanVehicle =
        vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final amtStr = amount.toStringAsFixed(2);
    final pn = payeeName?.isNotEmpty == true
        ? payeeName!
        : 'NETC FASTag $cleanVehicle';
    final note = 'FASTag Recharge for $cleanVehicle';

    return 'upi://pay?pa=$vpa&pn=${Uri.encodeComponent(pn)}&am=$amtStr&cu=INR&tn=${Uri.encodeComponent(note)}';
  }

  /// Launches real UPI payment apps (GPay, PhonePe, Paytm, BHIM, Cred)
  /// directly paying into the vehicle's NPCI NETC FASTag account.
  Future<bool> initiateRealUpiPayment({
    required String vehicleNumber,
    required String bankId,
    required double amount,
    required String vehicleName,
  }) async {
    final cleanVehicle =
        vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final upiUrl = buildUpiPaymentUriString(
      vehicleNumber: vehicleNumber,
      bankId: bankId,
      amount: amount,
      payeeName: 'NETC FASTag $cleanVehicle',
    );
    final uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[RealFastagService] Error launching UPI: $e');
    }

    // Fallback: Paytm / NETC web recharge portal
    final webFallback =
        'https://paytm.com/fastag-recharge?vehicle=$cleanVehicle';
    final webUri = Uri.parse(webFallback);
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[RealFastagService] Error launching web fallback: $e');
    }
    return false;
  }


  /// Launches a specific UPI App directly (GPay, PhonePe, Paytm, BHIM, Cred)
  Future<bool> launchUpiApp({
    required String appScheme,
    required String vehicleNumber,
    required String bankId,
    required double amount,
    String? payeeName,
  }) async {
    final vpa = buildNetcUpiVpa(vehicleNumber: vehicleNumber, bankId: bankId);
    final cleanVehicle =
        vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final amtStr = amount.toStringAsFixed(2);
    final pn = payeeName?.isNotEmpty == true ? payeeName! : 'NETC FASTag $cleanVehicle';
    final note = 'FASTag Recharge for $cleanVehicle';
    final params = 'pa=$vpa&pn=${Uri.encodeComponent(pn)}&am=$amtStr&cu=INR&tn=${Uri.encodeComponent(note)}';

    Uri? targetUri;
    switch (appScheme.toLowerCase()) {
      case 'gpay':
      case 'googlepay':
        targetUri = Uri.parse('tez://upi/pay?$params');
        break;
      case 'phonepe':
        targetUri = Uri.parse('phonepe://pay?$params');
        break;
      case 'paytm':
        targetUri = Uri.parse('paytmmp://pay?$params');
        break;
      case 'bhim':
        targetUri = Uri.parse('bhim://pay?$params');
        break;
      case 'cred':
        targetUri = Uri.parse('credpay://upi/pay?$params');
        break;
      default:
        targetUri = Uri.parse('upi://pay?$params');
        break;
    }

    try {
      if (await canLaunchUrl(targetUri)) {
        return await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[RealFastagService] Error launching $appScheme: $e');
    }

    // Fallback: try generic upi://
    final genericUri = Uri.parse('upi://pay?$params');
    try {
      if (await canLaunchUrl(genericUri)) {
        return await launchUrl(genericUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback 2: web recharge
    if (appScheme.toLowerCase() == 'paytm') {
      final webUri = Uri.parse('https://paytm.com/fastag-recharge?vehicle=$cleanVehicle');
      try {
        if (await canLaunchUrl(webUri)) {
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
    }

    return false;
  }

  /// Fetches real-time FASTag balance and recent toll plaza transaction logs
  /// via NPCI NETC / Bharat Bill Payment System (BBPS) API.
  Future<Map<String, dynamic>?> fetchLiveFastagBalance({
    required String vehicleNumber,
    required String bankId,
  }) async {
    final cleanVehicle =
        vehicleNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    try {
      final uri =
          Uri.parse('https://api.transportone.in/v1/fastag/fetch-balance');
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
