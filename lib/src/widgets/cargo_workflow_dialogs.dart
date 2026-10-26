import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';

/// Dialog to record loading event and set loaded quantities per product
class CargoLoadingDialog extends StatefulWidget {
  const CargoLoadingDialog({
    required this.trip,
    required this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController controller;

  @override
  State<CargoLoadingDialog> createState() => _CargoLoadingDialogState();
}

class _CargoLoadingDialogState extends State<CargoLoadingDialog> {
  late final List<TextEditingController> _qtyControllers;
  late final List<CargoItem> _items;
  final _productNameController = TextEditingController();
  final _singleQtyController = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List<CargoItem>.from(widget.trip.cargoItems);
    if (_items.isEmpty) {
      _singleQtyController.text = '100';
      _productNameController.text = widget.trip.cargoDescription.isNotEmpty
          ? widget.trip.cargoDescription
          : 'Industrial Goods';
    }
    _qtyControllers = _items
        .map((item) => TextEditingController(
              text: item.loadedQuantity > 0
                  ? item.loadedQuantity.toStringAsFixed(0)
                  : '50',
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _qtyControllers) {
      c.dispose();
    }
    _productNameController.dispose();
    _singleQtyController.dispose();
    super.dispose();
  }

  Future<void> _submitLoading() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_items.isEmpty) {
        final pName = _productNameController.text.trim();
        final qty = double.tryParse(_singleQtyController.text.trim()) ?? 0;
        if (pName.isEmpty || qty <= 0) {
          setState(() {
            _isSaving = false;
            _errorMessage =
                'Please enter a valid product name and loaded quantity.';
          });
          return;
        }

        final err = await widget.controller.recordCargoAction(
          tripReference: widget.trip.reference,
          stopIndex: 0,
          stopLocation: widget.trip.origin,
          product: pName,
          action: 'load',
          quantity: qty,
          recordedBy:
              widget.controller.loggedInName ?? widget.trip.assignedDriver,
          notes: 'Initial cargo loaded at origin depot',
        );

        if (err != null) {
          setState(() {
            _isSaving = false;
            _errorMessage = err;
          });
          return;
        }
      } else {
        for (int i = 0; i < _items.length; i++) {
          final qty = double.tryParse(_qtyControllers[i].text.trim()) ?? 0;
          if (qty > 0) {
            await widget.controller.recordCargoAction(
              tripReference: widget.trip.reference,
              stopIndex: 0,
              stopLocation: widget.trip.origin,
              product: _items[i].productName,
              action: 'load',
              quantity: qty,
              recordedBy:
                  widget.controller.loggedInName ?? widget.trip.assignedDriver,
              notes: 'Loaded at origin',
            );
          }
        }
      }

      final now = DateTime.now();
      final timeStr =
          '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final tripIndex = widget.controller.trips.indexOf(widget.trip);
      if (tripIndex >= 0) {
        await widget.controller.updateTripMilestones(
          index: tripIndex,
          pickupStatus: 'loaded',
          status: 'in_transit',
          loadingDateTime: timeStr,
        );
      }

      await widget.controller.updateTripOperationalStep(
        tripReference: widget.trip.reference,
        step: 'loaded',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maal loading entry saved successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.inventory_2_outlined,
                    size: 20,
                    padding: 8,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finish Loading (माल लोड करें)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verify loaded cargo quantities before transit',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_items.isEmpty) ...[
                      TextField(
                        controller: _productNameController,
                        decoration: InputDecoration(
                          labelText: 'Product / Item Name (सामान का नाम)',
                          hintText: 'e.g. Steel Rods / Cement Bags',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _singleQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Loaded Quantity (मात्रा)',
                          hintText: '100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      for (int i = 0; i < _items.length; i++) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _items[i].productName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                    Text(
                                      'Unit: ${_items[i].unit}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slate,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _qtyControllers[i],
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'sans-serif',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _submitLoading,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'CONFIRM LOADING (लोडिंग पूरी करें)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to record unloading, delivered quantities, damages, and returns
class CargoUnloadingDialog extends StatefulWidget {
  const CargoUnloadingDialog({
    required this.trip,
    required this.controller,
    super.key,
  });

  final TripRecord trip;
  final PlannerController controller;

  @override
  State<CargoUnloadingDialog> createState() => _CargoUnloadingDialogState();
}

class _CargoUnloadingDialogState extends State<CargoUnloadingDialog> {
  final _deliveredController = TextEditingController();
  final _damagedController = TextEditingController(text: '0');
  final _returnedController = TextEditingController(text: '0');
  final _reasonController = TextEditingController();

  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.trip.totalRemainingCargo > 0
        ? widget.trip.totalRemainingCargo
        : (widget.trip.totalLoadedCargo > 0
            ? widget.trip.totalLoadedCargo
            : 100);
    _deliveredController.text = remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _deliveredController.dispose();
    _damagedController.dispose();
    _returnedController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitUnloading() async {
    final delivered = double.tryParse(_deliveredController.text.trim()) ?? 0;
    final damaged = double.tryParse(_damagedController.text.trim()) ?? 0;
    final returned = double.tryParse(_returnedController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();

    final remaining = widget.trip.totalRemainingCargo > 0
        ? widget.trip.totalRemainingCargo
        : widget.trip.totalLoadedCargo;

    if (delivered + damaged + returned > remaining && remaining > 0) {
      setState(() {
        _errorMessage =
            'Delivered + damaged + returned (${(delivered + damaged + returned).toStringAsFixed(0)}) cannot exceed remaining loaded cargo (${remaining.toStringAsFixed(0)}).';
      });
      return;
    }

    if ((damaged > 0 || returned > 0) && reason.isEmpty) {
      setState(() {
        _errorMessage =
            'Please provide a reason for damaged or returned cargo.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final productName = widget.trip.cargoItems.isNotEmpty
        ? widget.trip.cargoItems.first.productName
        : widget.trip.cargoDescription;
    final recordedBy =
        widget.controller.loggedInName ?? widget.trip.assignedDriver;
    final stopIdx = widget.trip.stops.length + 1;

    if (delivered > 0) {
      await widget.controller.recordCargoAction(
        tripReference: widget.trip.reference,
        stopIndex: stopIdx,
        stopLocation: widget.trip.destination,
        product: productName,
        action: 'deliver',
        quantity: delivered,
        recordedBy: recordedBy,
        notes: 'Delivered to customer',
      );
    }

    if (damaged > 0) {
      await widget.controller.recordCargoAction(
        tripReference: widget.trip.reference,
        stopIndex: stopIdx,
        stopLocation: widget.trip.destination,
        product: productName,
        action: 'damage',
        quantity: damaged,
        recordedBy: recordedBy,
        notes: reason,
      );
    }

    if (returned > 0) {
      await widget.controller.recordCargoAction(
        tripReference: widget.trip.reference,
        stopIndex: stopIdx,
        stopLocation: widget.trip.destination,
        product: productName,
        action: 'return',
        quantity: returned,
        recordedBy: recordedBy,
        notes: reason,
      );
    }

    final now = DateTime.now();
    final timeStr =
        '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final tripIndex = widget.controller.trips.indexOf(widget.trip);
    if (tripIndex >= 0) {
      await widget.controller.updateTripMilestones(
        index: tripIndex,
        deliveryStatus: 'unloaded',
        status: 'in_progress',
        unloadingDateTime: timeStr,
      );
    }

    await widget.controller.updateTripOperationalStep(
      tripReference: widget.trip.reference,
      step: 'unloaded',
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Unloading recorded successfully! Ready for delivery proof.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.done_all_rounded,
                    size: 20,
                    padding: 8,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finish Unloading (अनलोडिंग पूरी करें)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Record delivered, damaged, and returned quantities',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _deliveredController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Delivered Quantity (ग्राहक को दिया गया माल)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _damagedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Damaged (टूटा/खराब)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _returnedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Returned (वापस)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText:
                            'Damage / Return Reason (खराबी या वापसी का कारण)',
                        hintText:
                            'e.g. Broken seal, damaged carton during transit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _submitUnloading,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    'SUBMIT UNLOADING (अनलोडिंग सबमिट करें)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog displaying the full cargo stop ledger and audit history
class CargoLedgerDialog extends StatelessWidget {
  const CargoLedgerDialog({
    required this.trip,
    super.key,
  });

  final TripRecord trip;

  @override
  Widget build(BuildContext context) {
    final ledger = trip.cargoLedger;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.history_rounded,
                    size: 20,
                    padding: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cargo Stop Ledger · Trip ${trip.effectiveTripNumber}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Complete chain of custody & movement audit',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Ledger Entries List
            Expanded(
              child: ledger.isEmpty
                  ? const Center(
                      child: Text(
                        'No cargo ledger entries recorded yet.',
                        style: TextStyle(color: AppColors.slate, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ledger.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final entry = ledger[i];
                        final isLoaded =
                            entry.action == 'load' || entry.action == 'loaded';
                        final isDelivered = entry.action == 'deliver' ||
                            entry.action == 'delivered';
                        final isDamaged = entry.action == 'damage' ||
                            entry.action == 'damaged';
                        final isReturned = entry.action == 'return' ||
                            entry.action == 'returned';

                        final chipColor = isLoaded
                            ? const Color(0xFFEFF6FF)
                            : isDelivered
                                ? AppColors.primarySoft
                                : isDamaged
                                    ? const Color(0xFFFEF2F2)
                                    : (isReturned
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFF1F5F9));
                        final chipBorder = isLoaded
                            ? const Color(0xFFBFDBFE)
                            : isDelivered
                                ? AppColors.primaryBorder
                                : isDamaged
                                    ? const Color(0xFFFECACA)
                                    : (isReturned
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFCBD5E1));
                        final chipTextColor = isLoaded
                            ? const Color(0xFF1E40AF)
                            : isDelivered
                                ? AppColors.primaryDark
                                : isDamaged
                                    ? const Color(0xFFDC2626)
                                    : (isReturned
                                        ? const Color(0xFFD97706)
                                        : AppColors.slate);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: chipColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: chipBorder),
                                    ),
                                    child: Text(
                                      entry.action.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: chipTextColor,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${entry.productName} · Qty: ${entry.quantity.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  ),
                                  Text(
                                    entry.timestamp,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.slate,
                                      fontFamily: 'sans-serif',
                                    ),
                                  ),
                                ],
                              ),
                              if (entry.stopLocation.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13, color: AppColors.slate),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        entry.stopLocation,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.navy,
                                          fontFamily: 'sans-serif',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (entry.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Notes: ${entry.notes}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog displaying driver attendance history
class DriverAttendanceHistoryDialog extends StatelessWidget {
  const DriverAttendanceHistoryDialog({
    required this.driverId,
    required this.driverName,
    required this.controller,
    super.key,
  });

  final String driverId;
  final String driverName;
  final PlannerController controller;

  @override
  Widget build(BuildContext context) {
    final records = controller.getDriverAttendance(driverId);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.access_time_rounded,
                    size: 20,
                    padding: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$driverName · Duty Attendance',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'sans-serif',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Duty start/end timestamps & calculated hours',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.slate),
                  ),
                ],
              ),
            ),

            // Records List
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'No attendance records found for this driver.',
                        style: TextStyle(color: AppColors.slate, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final rec = records[i];
                        final isPresent = rec.status == 'present';
                        final isLate = rec.status == 'late';
                        final isHalfDay = rec.status == 'half_day';
                        final isOnLeave = rec.status == 'on_leave';

                        final statusColor = isPresent
                            ? AppColors.primarySoft
                            : isLate
                                ? const Color(0xFFFEF3C7)
                                : isHalfDay
                                    ? const Color(0xFFEFF6FF)
                                    : isOnLeave
                                        ? const Color(0xFFF3E8FF)
                                        : const Color(0xFFFEF2F2);
                        final statusBorder = isPresent
                            ? AppColors.primaryBorder
                            : isLate
                                ? const Color(0xFFFDE68A)
                                : isHalfDay
                                    ? const Color(0xFFBFDBFE)
                                    : isOnLeave
                                        ? const Color(0xFFE9D5FF)
                                        : const Color(0xFFFECACA);
                        final statusTextColor = isPresent
                            ? AppColors.primaryDark
                            : isLate
                                ? const Color(0xFFB45309)
                                : isHalfDay
                                    ? const Color(0xFF1E40AF)
                                    : isOnLeave
                                        ? const Color(0xFF6B21A8)
                                        : const Color(0xFFDC2626);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rec.date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.navy,
                                      fontFamily: 'sans-serif',
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusBorder),
                                    ),
                                    child: Text(
                                      rec.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: statusTextColor,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Start: ${rec.startTime.isNotEmpty ? rec.startTime : "Pending"}',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.slate),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'End: ${rec.endTime.isNotEmpty ? rec.endTime : "In Progress"}',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.slate),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Hours: ${rec.totalWorkingHours > 0 ? "${rec.totalWorkingHours.toStringAsFixed(1)} hrs" : (rec.endTime.isEmpty ? "Active" : "-")}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  if (rec.notes.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '· ${rec.notes}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.slate,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}
