import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  bool _showQrCode = false;

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

  String _buildPaymentUri() {
    final pa = _upiIdCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final pn = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Payee';
    final tn = _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : 'Payment via FleetRoute';
    final amtStr = amt > 0 ? amt.toStringAsFixed(2) : '';

    var query = 'pa=$pa&pn=${Uri.encodeComponent(pn)}&cu=INR';
    if (amtStr.isNotEmpty) {
      query += '&am=$amtStr';
    }
    if (tn.isNotEmpty) {
      query += '&tn=${Uri.encodeComponent(tn)}';
    }
    return 'upi://pay?$query';
  }

  Future<void> _launchSpecificApp(String appScheme) async {
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
    final params = 'pa=$pa&pn=${Uri.encodeComponent(pn)}&am=$amtStr&cu=INR&tn=${Uri.encodeComponent(tn)}';

    Uri? targetUri;
    switch (appScheme.toLowerCase()) {
      case 'gpay':
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
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback to generic upi://
    final genericUri = Uri.parse('upi://pay?$params');
    try {
      if (await canLaunchUrl(genericUri)) {
        await launchUrl(genericUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _showQrCode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$appScheme open nahi hua. Aap niche diye gaye QR code ko kisi bhi UPI app se scan kar sakte hain.'),
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
    }
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

    final upiUrl = _buildPaymentUri();
    final uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } else {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _showQrCode = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UPI intent directly launch nahi hua. Niche QR code generate ho gaya hai, kisi bhi app se scan karke pay karein.'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }
    }
  }

  Widget _buildAppQuickButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upiUri = _buildPaymentUri();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
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
                onChanged: (_) => setState(() {}),
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
                onChanged: (_) => setState(() {}),
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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Payment Note / Remark',
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Direct One-Click UPI App Chooser
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Direct Pay via UPI Apps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAppQuickButton(
                          label: 'Google Pay',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFF1A73E8),
                          onTap: () => _launchSpecificApp('gpay'),
                        ),
                        _buildAppQuickButton(
                          label: 'PhonePe',
                          icon: Icons.flash_on_rounded,
                          color: const Color(0xFF5F259F),
                          onTap: () => _launchSpecificApp('phonepe'),
                        ),
                        _buildAppQuickButton(
                          label: 'Paytm',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF00B9F1),
                          onTap: () => _launchSpecificApp('paytm'),
                        ),
                        _buildAppQuickButton(
                          label: 'BHIM',
                          icon: Icons.qr_code_rounded,
                          color: const Color(0xFF00796B),
                          onTap: () => _launchSpecificApp('bhim'),
                        ),
                        _buildAppQuickButton(
                          label: 'CRED',
                          icon: Icons.credit_card_rounded,
                          color: const Color(0xFF1E293B),
                          onTap: () => _launchSpecificApp('cred'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Instant QR Code toggle
              if (_upiIdCtrl.text.trim().isNotEmpty) ...[
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showQrCode = !_showQrCode),
                    icon: Icon(_showQrCode ? Icons.qr_code_rounded : Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(_showQrCode ? 'Hide QR Code' : 'Show Instant Payment QR Code'),
                  ),
                ),
                if (_showQrCode) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: upiUri,
                            version: QrVersions.auto,
                            size: 190,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Scan with any UPI app to pay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),
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
