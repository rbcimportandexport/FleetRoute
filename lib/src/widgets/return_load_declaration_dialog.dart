import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../services/safety_notification_service.dart';
import '../theme/app_theme.dart';

/// Dialog allowing driver to log return journey:
/// Either returning Empty (Khali Gadi) or with Return Load (Wapsi Maal with Incentive)
class ReturnLoadDeclarationDialog extends StatefulWidget {
  const ReturnLoadDeclarationDialog({
    required this.trip,
    required this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController controller;

  static Future<bool?> show(
    BuildContext context, {
    required TripRecord trip,
    required PlannerController controller,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReturnLoadDeclarationDialog(trip: trip, controller: controller),
    );
  }

  @override
  State<ReturnLoadDeclarationDialog> createState() =>
      _ReturnLoadDeclarationDialogState();
}

class _ReturnLoadDeclarationDialogState
    extends State<ReturnLoadDeclarationDialog> {
  bool _hasLoad = false;
  final _goodsController = TextEditingController();
  final _partyController = TextEditingController();
  final _freightController = TextEditingController();
  final _incentiveController = TextEditingController();
  
  Uint8List? _biltyPhotoBytes;
  String _biltyBase64 = '';
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hasLoad = widget.trip.hasReturnLoad;
    _goodsController.text = widget.trip.returnGoodsDescription;
    _partyController.text = widget.trip.returnPartyName;
    if (widget.trip.returnFreightAmount > 0) {
      _freightController.text = widget.trip.returnFreightAmount.toStringAsFixed(0);
    }
    if (widget.trip.driverIncentiveAmount > 0) {
      _incentiveController.text = widget.trip.driverIncentiveAmount.toStringAsFixed(0);
    }
    if (widget.trip.returnBiltyPhoto.isNotEmpty) {
      _biltyBase64 = widget.trip.returnBiltyPhoto;
      try {
        _biltyPhotoBytes = base64Decode(_biltyBase64);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _goodsController.dispose();
    _partyController.dispose();
    _freightController.dispose();
    _incentiveController.dispose();
    super.dispose();
  }

  void _calculateAutoIncentive(String freightText) {
    final freight = double.tryParse(freightText) ?? 0.0;
    if (freight > 0 && _incentiveController.text.isEmpty) {
      // Standard return load incentive: 10% of freight or ₹500 minimum
      final autoIncentive = (freight * 0.10).clamp(500.0, 5000.0);
      setState(() {
        _incentiveController.text = autoIncentive.toStringAsFixed(0);
      });
    }
  }

  void _captureBilty() {
    SafetyNotificationService.pickDriverPhoto(
      useCamera: true,
      onPhotoSelected: (base64Data) {
        try {
          final clean = base64Data.contains(',')
              ? base64Data.split(',').last.trim()
              : base64Data.trim();
          final bytes = base64Decode(clean);
          if (mounted) {
            setState(() {
              _biltyBase64 = clean;
              _biltyPhotoBytes = bytes;
            });
          }
        } catch (_) {}
      },
      onError: (err) {
        if (mounted) setState(() => _error = err);
      },
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_hasLoad) {
      if (_goodsController.text.trim().isEmpty) {
        setState(() => _error = 'Kripya wapsi maal ka naam/detail bharein.');
        return;
      }
      if (_partyController.text.trim().isEmpty) {
        setState(() => _error = 'Kripya party ya factory ka naam bharein.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final freight = double.tryParse(_freightController.text.trim()) ?? 0.0;
    final incentive = double.tryParse(_incentiveController.text.trim()) ?? 0.0;

    await widget.controller.recordReturnLoad(
      tripReference: widget.trip.reference,
      hasReturnLoad: _hasLoad,
      goodsDescription: _hasLoad ? _goodsController.text.trim() : 'Khali Gadi (Empty Return)',
      partyName: _hasLoad ? _partyController.text.trim() : '',
      returnFreight: _hasLoad ? freight : 0.0,
      driverIncentive: _hasLoad ? incentive : 0.0,
      biltyPhoto: _hasLoad ? _biltyBase64 : '',
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_hasLoad
            ? '🎉 Wapsi Maal Darj Hua! Aapka Incentive ₹${incentive.toStringAsFixed(0)} approve hoga.'
            : '✅ Khali gadi wapsi (Empty Return) record ho gayi.'),
        backgroundColor: _hasLoad ? const Color(0xFF16A34A) : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.swap_calls_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wapsi Safar (Return Journey)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          'Surat se Wapsi • Trip #${widget.trip.effectiveTripNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Question banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.help_outline_rounded,
                        size: 20, color: Color(0xFF0284C7)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Wapsi me koi maal bhara hai ya truck khali aa raha hai?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2 Choice Selector Buttons
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _hasLoad = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: !_hasLoad
                              ? const Color(0xFFF1F5F9)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_hasLoad
                                ? AppColors.navy
                                : const Color(0xFFCBD5E1),
                            width: !_hasLoad ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.no_transfer_rounded,
                              size: 26,
                              color: !_hasLoad ? AppColors.navy : AppColors.slate,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Khali Gadi\n(Empty Return)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: !_hasLoad ? AppColors.navy : AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _hasLoad = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _hasLoad
                              ? const Color(0xFFECFDF5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasLoad
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFCBD5E1),
                            width: _hasLoad ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 26,
                              color: _hasLoad
                                  ? const Color(0xFF16A34A)
                                  : AppColors.slate,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Wapsi Maal Bhara\n(+ Driver Incentive 💰)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _hasLoad
                                  ? const Color(0xFF16A34A)
                                  : AppColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // If has return load: Show full cargo + incentive input form
              if (_hasLoad) ...[
                // Incentive Highlight Badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Text('🎁', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Driver Reward: Kisi aur party ka wapsi maal lane par aapko company ki taraf se alag se Incentive/Bonus diya jayega!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Goods Name Input
                TextField(
                  controller: _goodsController,
                  decoration: InputDecoration(
                    labelText: 'Wapsi Maal / Goods Description *',
                    hintText: 'e.g. 50 Cartons, Salon Pipes, Furniture Fabric',
                    prefixIcon: const Icon(Icons.inventory_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Party Name Input
                TextField(
                  controller: _partyController,
                  decoration: InputDecoration(
                    labelText: 'Party / Factory Ka Naam *',
                    hintText: 'e.g. Ramesh Textiles, Surat',
                    prefixIcon: const Icon(Icons.business_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Freight & Incentive Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _freightController,
                        keyboardType: TextInputType.number,
                        onChanged: _calculateAutoIncentive,
                        decoration: InputDecoration(
                          labelText: 'Bhadha / Freight (₹)',
                          hintText: 'e.g. 3000',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _incentiveController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Driver Incentive (₹) *',
                          hintText: 'e.g. 500',
                          prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bilty / Loading Photo Capture
                OutlinedButton.icon(
                  onPressed: _captureBilty,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(_biltyBase64.isNotEmpty
                      ? 'Bilty / Slip Photo Attached (Change)'
                      : 'Bilty / Receipt Photo Khinchein'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _biltyBase64.isNotEmpty
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF4F46E5),
                    side: BorderSide(
                      color: _biltyBase64.isNotEmpty
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF4F46E5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_biltyPhotoBytes != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _biltyPhotoBytes!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],

              const SizedBox(height: 18),
              // Submit Button
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSaving
                      ? 'Saving Return Info...'
                      : (_hasLoad ? 'Confirm Return Load (+ Incentive)' : 'Confirm Empty Return (Khali Gadi)'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _hasLoad ? const Color(0xFF16A34A) : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
