import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class UpiScanAndPayDialog extends StatefulWidget {
  const UpiScanAndPayDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const UpiScanAndPayDialog(),
    );
  }

  @override
  State<UpiScanAndPayDialog> createState() => _UpiScanAndPayDialogState();
}

class _UpiScanAndPayDialogState extends State<UpiScanAndPayDialog> {
  final MobileScannerController _cameraController = MobileScannerController();
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _isCameraActive = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _upiIdCtrl.dispose();
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final val = barcode.rawValue;
      if (val != null && val.isNotEmpty) {
        _isProcessing = true;
        _parseUpiString(val);
        break;
      }
    }
  }

  void _parseUpiString(String raw) {
    setState(() {
      _isCameraActive = false;
    });
    try {
      if (raw.startsWith('upi://pay')) {
        final uri = Uri.parse(raw);
        final pa = uri.queryParameters['pa'] ?? '';
        final pn = uri.queryParameters['pn'] ?? '';
        final am = uri.queryParameters['am'] ?? '';
        final tn = uri.queryParameters['tn'] ?? '';

        if (pa.isNotEmpty) _upiIdCtrl.text = pa;
        if (pn.isNotEmpty) _nameCtrl.text = Uri.decodeComponent(pn);
        if (am.isNotEmpty) _amountCtrl.text = am;
        if (tn.isNotEmpty) _noteCtrl.text = Uri.decodeComponent(tn);
      } else if (raw.contains('@')) {
        _upiIdCtrl.text = raw.trim();
      }
    } catch (_) {}
  }

  Future<void> _launchPayment() async {
    final pa = _upiIdCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (pa.isEmpty || !pa.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID (e.g. name@upi)'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final pn = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Payee';
    final tn = _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : 'Payment via FleetRoute';
    final amtStr = amt.toStringAsFixed(2);

    final upiUrl = 'upi://pay?pa=' + pa + '&pn=' + Uri.encodeComponent(pn) + '&am=' + amtStr + '&cu=INR&tn=' + Uri.encodeComponent(tn);
    final uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not trigger UPI intent directly. Please open GPay/PhonePe to pay to this UPI ID.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan UPI QR & Pay Real',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          'Scan any Shop / Toll / Person QR code',
                          style: TextStyle(fontSize: 11, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isCameraActive) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _cameraController,
                          onDetect: _onDetect,
                        ),
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.greenAccent, width: 2.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isCameraActive = false),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Enter UPI ID Manually'),
                  ),
                ),
              ] else ...[
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _isProcessing = false;
                      setState(() => _isCameraActive = true);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Scan QR with Camera'),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _upiIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Receiver UPI ID (VPA)',
                  hintText: 'e.g. merchant@paytm / 9876543210@upi',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payee Name / Shop Name (Optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payment Note / Remark',
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _launchPayment,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'Proceed to Real UPI App',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
