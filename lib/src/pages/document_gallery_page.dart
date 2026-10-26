import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import '../theme/app_theme.dart';

enum DocumentGalleryMode { driver, vehicle }

class DocumentGalleryPage extends StatelessWidget {
  const DocumentGalleryPage({required this.controller, required this.mode, super.key});

  final PlannerController controller;
  final DocumentGalleryMode mode;

  bool get _isDriver => mode == DocumentGalleryMode.driver;

  Uint8List? _bytes(String source) {
    try {
      return base64Decode(source.contains(',') ? source.split(',').last : source);
    } catch (_) {
      return null;
    }
  }

  List<SeatbeltRecord> _recordsFor(String key) {
    final normalized = key.trim().toLowerCase();
    return controller.seatbeltRecords.where((record) {
      final value = _isDriver ? record.driverName : record.vehicleNumber;
      return value.trim().toLowerCase() == normalized && record.photoBase64.trim().isNotEmpty;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  String _category(SeatbeltRecord record) {
    final notes = record.notes.trim();
    if (notes.isEmpty) return 'Uploaded Photo';
    final separator = notes.indexOf(':');
    return separator > 0 ? notes.substring(0, separator).trim() : notes;
  }

  void _openGallery(BuildContext context, String title, List<SeatbeltRecord> records) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          maxChildSize: .96,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 10, 12),
                child: Row(
                  children: [
                    Icon(_isDriver ? Icons.badge_outlined : Icons.local_shipping_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('No document photo uploaded yet.', style: TextStyle(color: AppColors.slate)))
                    : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(14),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisExtent: 230,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final bytes = _bytes(record.photoBase64);
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: bytes == null
                                      ? const ColoredBox(color: Color(0xFFF1F5F9), child: Icon(Icons.broken_image_outlined))
                                      : Image.memory(bytes, fit: BoxFit.cover),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_category(record), maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 3),
                                      Text('${record.vehicleNumber} • ${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                                    ],
                                  ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = <({String key, String subtitle})>[];
    if (_isDriver) {
      for (final driver in controller.drivers) {
        entries.add((key: driver.name, subtitle: driver.phone));
      }
    } else {
      for (final vehicle in controller.truckModels) {
        final driver = controller.drivers.where((d) =>
            d.assignedVehicle.trim().toLowerCase() == vehicle.code.trim().toLowerCase());
        entries.add((key: vehicle.code, subtitle: driver.isEmpty ? 'Driver not assigned' : driver.first.name));
      }
    }

    return ColoredBox(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Text(_isDriver ? 'Driver Documents' : 'Vehicle Documents',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Tap any ${_isDriver ? 'driver' : 'vehicle'} to see uploaded document photos.',
              style: const TextStyle(color: AppColors.slate, fontSize: 12)),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No records found.')))
          else
            for (final entry in entries) ...[
              Builder(builder: (context) {
                final records = _recordsFor(entry.key);
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFD1FAE5)),
                  ),
                  child: ListTile(
                    onTap: () => _openGallery(context, entry.key, records),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Icon(_isDriver ? Icons.person_outline : Icons.local_shipping_outlined, color: AppColors.primary),
                    ),
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${entry.subtitle} • ${records.length} photo${records.length == 1 ? '' : 's'}'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ),
                );
              }),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }
}
