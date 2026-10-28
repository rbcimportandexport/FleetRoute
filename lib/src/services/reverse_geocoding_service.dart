import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'incoming_intent_service.dart';
import 'route_traffic_service.dart';

class GeocodedPlace {
  final LatLng coordinates;
  final String displayName;
  final String shortName;

  const GeocodedPlace({
    required this.coordinates,
    required this.displayName,
    required this.shortName,
  });

  String get formattedLabel {
    final name = shortName.isNotEmpty ? shortName : displayName;
    return '$name (${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)})';
  }
}

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
    final place = await resolveLocationQueryOrLink(query);
    return place?.coordinates;
  }

  /// Comprehensive resolver that handles:
  /// 1. Google Maps / WhatsApp shared URLs (maps.app.goo.gl, goo.gl/maps, google.com/maps)
  /// 2. Explicit Coordinates ("21.1702, 72.8311" or "Mota (21.17, 72.83)")
  /// 3. Predefined city names (Surat, Bardoli, Mumbai, Delhi, etc.)
  /// 4. Freeform address / landmark search via OpenStreetMap Nominatim
  static Future<GeocodedPlace?> resolveLocationQueryOrLink(String rawInput) async {
    final clean = rawInput.trim();
    if (clean.isEmpty) return null;

    // 1. Check if the text contains a URL (Google Maps link, maps.app.goo.gl, etc.)
    final urlRegex = RegExp(r'https?://[^\s]+');
    if (urlRegex.hasMatch(clean)) {
      try {
        final incoming = await IncomingIntentService.resolveAndParseLocation(clean);
        if (incoming.coordinates != null) {
          final coords = incoming.coordinates!;
          String? address;
          if (incoming.addressQuery != null && incoming.addressQuery!.isNotEmpty) {
            address = incoming.addressQuery;
          } else {
            address = await addressFor(coords);
          }
          final shortName = address?.split(',').first.trim() ??
              incoming.addressQuery ??
              'Pinned Location';
          return GeocodedPlace(
            coordinates: coords,
            displayName: address ?? '${coords.latitude}, ${coords.longitude}',
            shortName: shortName,
          );
        }
        if (incoming.addressQuery != null && incoming.addressQuery!.isNotEmpty) {
          return await resolveLocationQueryOrLink(incoming.addressQuery!);
        }
      } catch (_) {}
    }

    // 2. Direct coordinate pattern e.g. "21.170245, 72.831122" or "(21.1702, 72.8311)"
    final coordRegex = RegExp(
      r'([-+]?\d{1,2}(?:\.\d{3,}))[,\s]+([-+]?\d{1,3}(?:\.\d{3,}))',
    );
    final coordMatch = coordRegex.firstMatch(clean);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        final coords = LatLng(lat, lng);
        final labelWithoutCoords =
            clean.replaceAll(coordRegex, '').replaceAll('()', '').trim();
        final address = labelWithoutCoords.isNotEmpty
            ? labelWithoutCoords
            : await addressFor(coords);
        final shortName = address?.split(',').first.trim() ??
            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        return GeocodedPlace(
          coordinates: coords,
          displayName: address ?? '${coords.latitude}, ${coords.longitude}',
          shortName: shortName,
        );
      }
    }

    // 3. Fast city match from RouteTrafficService
    final fastCityCoord = RouteTrafficService.parseLocation(clean);
    if (fastCityCoord != null) {
      return GeocodedPlace(
        coordinates: fastCityCoord,
        displayName: clean,
        shortName: clean.split(',').first.trim(),
      );
    }

    // 4. Online Nominatim geocoding for addresses, markets, towns, landmarks
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': clean,
        'limit': '1',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: const {
        'User-Agent': 'TransportOne/1.2 (support@rbcsalonfurniture.com)',
        'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is List && json.isNotEmpty) {
          final first = json.first;
          if (first is Map) {
            final lat = double.tryParse(first['lat']?.toString() ?? '');
            final lon = double.tryParse(first['lon']?.toString() ?? '');
            if (lat != null && lon != null) {
              final displayName = first['display_name']?.toString() ?? clean;
              final shortName = first['name']?.toString() ??
                  displayName.split(',').first.trim();
              return GeocodedPlace(
                coordinates: LatLng(lat, lon),
                displayName: displayName,
                shortName: shortName,
              );
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Searches for multiple matching places for autocomplete and suggestions
  static Future<List<GeocodedPlace>> searchPlaces(String query,
      {int limit = 5}) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];

    // If it's a URL or direct coords, resolve single place
    if (clean.startsWith('http') || clean.contains('goo.gl')) {
      final single = await resolveLocationQueryOrLink(clean);
      return single != null ? [single] : const [];
    }

    final results = <GeocodedPlace>[];

    // Check predefined cities first
    for (final entry in RouteTrafficService.cityCoordinates.entries) {
      if (entry.key.toLowerCase().contains(clean.toLowerCase())) {
        results.add(
          GeocodedPlace(
            coordinates: entry.value,
            displayName:
                '${entry.key[0].toUpperCase()}${entry.key.substring(1)}, India',
            shortName:
                '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
          ),
        );
        if (results.length >= limit) return results;
      }
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': clean,
        'limit': '$limit',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: const {
        'User-Agent': 'TransportOne/1.2 (support@rbcsalonfurniture.com)',
        'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is List) {
          for (final item in json) {
            if (item is Map) {
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');
              if (lat != null && lon != null) {
                final displayName = item['display_name']?.toString() ?? clean;
                final shortName = item['name']?.toString() ??
                    displayName.split(',').first.trim();
                results.add(
                  GeocodedPlace(
                    coordinates: LatLng(lat, lon),
                    displayName: displayName,
                    shortName: shortName,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    return results;
  }
}

