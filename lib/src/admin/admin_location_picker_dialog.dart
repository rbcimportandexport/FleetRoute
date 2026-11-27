import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/map_tile_service.dart';
import '../services/reverse_geocoding_service.dart';

class AdminLocationPickerDialog extends StatefulWidget {
  const AdminLocationPickerDialog({
    required this.title,
    this.initialPosition,
    super.key,
  });

  final String title;
  final LatLng? initialPosition;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    LatLng? initialPosition,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => AdminLocationPickerDialog(
        title: title,
        initialPosition: initialPosition,
      ),
    );
  }

  @override
  State<AdminLocationPickerDialog> createState() => _AdminLocationPickerDialogState();
}

class _AdminLocationPickerDialogState extends State<AdminLocationPickerDialog> {
  final MapController _mapController = MapController();
  late LatLng _selectedPos;
  String _locationName = 'स्थान खोज रहे हैं...';
  bool _isLoadingName = false;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _selectedPos = widget.initialPosition ?? const LatLng(21.17065, 73.00425);
    _resolveAddress(_selectedPos);
  }

  Future<void> _resolveAddress(LatLng pos) async {
    setState(() => _isLoadingName = true);
    try {
      final name = await ReverseGeocodingService.addressFor(pos);
      if (mounted) {
        setState(() {
          _locationName = (name != null && name.isNotEmpty)
              ? name
              : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationName = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: 520,
        child: Stack(
          children: [
            // FlutterMap interactive picker
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPos,
                initialZoom: 14.5,
                onTap: (_, latlng) {
                  setState(() => _selectedPos = latlng);
                  _resolveAddress(latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite ? MapTileService.satelliteTileUrl : MapTileService.roadTileUrl,
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.transportone.transport_one',
                  maxZoom: 20,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPos,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFDC2626),
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top Header Bar
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded, color: const Color(0xFF2563EB)),
                      onPressed: () => setState(() => _isSatellite = !_isSatellite),
                      tooltip: 'मैप स्टाइल बदलें',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Confirm Location Card
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'मैप पर चुनी गई लोकेशन:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoadingName ? 'स्थान पता लोड हो रहा है...' : _locationName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(_locationName),
                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                        label: const Text(
                          'यह लोकेशन सेट करें',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
