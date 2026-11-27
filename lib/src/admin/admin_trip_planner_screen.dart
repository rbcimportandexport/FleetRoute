import 'package:flutter/material.dart';
import '../controllers/planner_controller.dart';
import '../models/planner_models.dart';
import 'admin_location_picker_dialog.dart';

class AdminTripPlannerScreen extends StatefulWidget {
  const AdminTripPlannerScreen({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<AdminTripPlannerScreen> createState() => _AdminTripPlannerScreenState();
}

class _AdminTripPlannerScreenState extends State<AdminTripPlannerScreen> {
  final _originController = TextEditingController();
  final _destController = TextEditingController();
  final _cargoController = TextEditingController();

  String? _selectedVehicle;
  String? _selectedDriver;

  @override
  void initState() {
    super.initState();
    if (widget.controller.truckModels.isNotEmpty) {
      _selectedVehicle = widget.controller.truckModels.first.code;
    }
    if (widget.controller.drivers.isNotEmpty) {
      _selectedDriver = widget.controller.drivers.first.name;
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  void _assignTrip() {
    final origin = _originController.text.trim();
    final dest = _destController.text.trim();
    final cargo = _cargoController.text.trim();

    if (origin.isEmpty || dest.isEmpty || _selectedVehicle == null || _selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सभी फ़ील्ड और ड्राइवर चुनें')),
      );
      return;
    }

    final newTrip = TripRecord(
      reference: 'TRIP-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      tripNumber: 'TRIP-${DateTime.now().millisecondsSinceEpoch % 1000000}',
      origin: origin,
      destination: dest,
      assignedVehicle: _selectedVehicle!,
      assignedDriver: _selectedDriver!,
      customerName: cargo.isNotEmpty ? cargo : 'General Cargo',
      cargoDescription: cargo,
      status: 'pending',
      operationalStep: 'assigned',
      pickupStatus: 'pending',
      deliveryStatus: 'pending',
      createdAt: DateTime.now().toIso8601String(),
    );

    widget.controller.trips.insert(0, newTrip);
    widget.controller.saveTrips();
    widget.controller.notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text('ट्रिप सफलतापूर्वक बनाई गई और $_selectedDriver को असाइन कर दी गई!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.controller.truckModels;
    final drivers = widget.controller.drivers;
    final trips = widget.controller.trips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ट्रिप प्लान व ड्राइवर असाइन (Trip Planner)'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trip Creation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'नई ट्रिप बनाएं (Assign New Trip)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Vehicle Selector Dropdown
                const Text('गाड़ी चुनें (Vehicle):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedVehicle,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: vehicles.map((v) {
                    return DropdownMenuItem(value: v.code, child: Text('${v.code} (${v.name})'));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedVehicle = val),
                ),
                const SizedBox(height: 14),

                // Driver Selector Dropdown
                const Text('ड्राइवर चुनें (Driver):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedDriver,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: drivers.map((d) {
                    return DropdownMenuItem(value: d.name, child: Text('${d.name} (${d.phone})'));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDriver = val),
                ),
                const SizedBox(height: 14),

                // Origin
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कहाँ से (Pickup Location):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () async {
                        final picked = await AdminLocationPickerDialog.show(
                          context,
                          title: 'पिकअप लोकेशन मैप से चुनें',
                        );
                        if (picked != null && picked.isNotEmpty) {
                          _originController.text = picked;
                        }
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.map_rounded, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'मैप से चुनें',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _originController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.trip_origin_rounded, color: Colors.green, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB)),
                      tooltip: 'मैप से लोकेशन चुनें',
                      onPressed: () async {
                        final picked = await AdminLocationPickerDialog.show(
                          context,
                          title: 'पिकअप लोकेशन मैप से चुनें',
                        );
                        if (picked != null && picked.isNotEmpty) {
                          _originController.text = picked;
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Destination
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('कहाँ तक (Delivery Location):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () async {
                        final picked = await AdminLocationPickerDialog.show(
                          context,
                          title: 'डिलीवरी लोकेशन मैप से चुनें',
                        );
                        if (picked != null && picked.isNotEmpty) {
                          _destController.text = picked;
                        }
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.map_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 4),
                          Text(
                            'मैप से चुनें',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _destController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFFDC2626)),
                      tooltip: 'मैप से लोकेशन चुनें',
                      onPressed: () async {
                        final picked = await AdminLocationPickerDialog.show(
                          context,
                          title: 'डिलीवरी लोकेशन मैप से चुनें',
                        );
                        if (picked != null && picked.isNotEmpty) {
                          _destController.text = picked;
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Cargo
                const Text('माल का विवरण (Cargo Details):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _cargoController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _assignTrip,
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: const Text(
                      'ट्रिप असाइन करें (Assign Trip to Driver)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active / Planned Trips List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'हाल की ट्रिप्स (Recent Trips List)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (trips.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    widget.controller.trips.clear();
                    widget.controller.saveTrips();
                    widget.controller.notifyListeners();
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFDC2626)),
                  label: const Text(
                    'सभी साफ़ करें',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (trips.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 42, color: Color(0xFF94A3B8)),
                  SizedBox(height: 10),
                  Text(
                    'कोई ट्रिप नहीं है (Zero Trips)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ऊपर दिए गए फॉर्म से नई असली ट्रिप प्लान करें',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else
            ...trips.take(10).map((trip) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trip.tripNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: trip.status == 'completed' ? Colors.green.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                trip.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: trip.status == 'completed' ? Colors.green.shade700 : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                widget.controller.trips.remove(trip);
                                widget.controller.saveTrips();
                                widget.controller.notifyListeners();
                              },
                              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'गाड़ी: ${trip.assignedVehicle} • ड्राइवर: ${trip.assignedDriver}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.origin} ➔ ${trip.destination}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
