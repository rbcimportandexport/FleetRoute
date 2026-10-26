import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ReverseGeocodingService {
  ReverseGeocodingService._();

  static Future<String?> addressFor(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: const {
        'User-Agent': 'TransportOne/1.2 (support@rbcsalonfurniture.com)',
        'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map) return null;
      final name = json['display_name']?.toString().trim();
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  static Future<String> labelFor(LatLng point) async {
    final coordinates =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    final address = await addressFor(point);
    return address == null ? coordinates : '$address ($coordinates)';
  }

  /// Geocodes a text query / place name (e.g. "Krishna textile hub", "Surat", etc.) to LatLng.
  static Future<LatLng?> searchCoordinates(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': clean,
        'limit': '1',
      });
      final response = await http.get(uri, headers: const {
        'User-Agent': 'TransportOne/1.2 (support@rbcsalonfurniture.com)',
        'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is List && json.isNotEmpty) {
        final first = json.first;
        if (first is Map) {
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
