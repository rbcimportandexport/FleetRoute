import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class IncomingLocationData {
  final LatLng? coordinates;
  final String? addressQuery;
  final String rawUri;

  const IncomingLocationData({
    this.coordinates,
    this.addressQuery,
    required this.rawUri,
  });

  bool get isValid =>
      coordinates != null || (addressQuery != null && addressQuery!.isNotEmpty);
}

class IncomingIntentService {
  static const MethodChannel _channel =
      MethodChannel('com.transportone.transport_one/location_intent');

  static final IncomingIntentService _instance =
      IncomingIntentService._internal();
  factory IncomingIntentService() => _instance;

  final StreamController<IncomingLocationData> _locationStreamController =
      StreamController<IncomingLocationData>.broadcast();

  Stream<IncomingLocationData> get onLocationReceived =>
      _locationStreamController.stream;

  IncomingLocationData? _latestLocation;
  IncomingLocationData? get latestLocation => _latestLocation;

  IncomingIntentService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onLocationReceived') {
      final payload = call.arguments as String?;
      if (payload != null && payload.isNotEmpty) {
        final parsed = await resolveAndParseLocation(payload);
        if (parsed.isValid) {
          _latestLocation = parsed;
          _locationStreamController.add(parsed);
        }
      }
    }
  }

  /// Checks if the app was launched directly from an external intent (cold start).
  Future<IncomingLocationData?> checkInitialLocation() async {
    try {
      final payload =
          await _channel.invokeMethod<String>('getInitialLocation');
      if (payload != null && payload.isNotEmpty) {
        final parsed = await resolveAndParseLocation(payload);
        if (parsed.isValid) {
          _latestLocation = parsed;
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[IncomingIntentService] Error checking initial location: $e');
    }
    return _latestLocation;
  }

  /// Clears the cached latest location once consumed.
  void clearLatestLocation() {
    _latestLocation = null;
  }

  /// Asynchronously unshortens URLs (e.g. maps.app.goo.gl) if needed and extracts coordinates.
  static Future<IncomingLocationData> resolveAndParseLocation(String raw) async {
    var text = raw.trim();

    // Check if the input contains a URL like https://maps.app.goo.gl/... or https://goo.gl/maps/...
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      var currentUrl = match.group(0)!;
      final client = http.Client();
      try {
        // Follow redirects up to 5 hops
        for (int hop = 0; hop < 5; hop++) {
          if (!currentUrl.contains('goo.gl') &&
              !currentUrl.contains('google.com/maps') &&
              !currentUrl.contains('maps.app.goo.gl')) {
            break;
          }

          final request = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false
            ..headers['User-Agent'] =
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

          final response =
              await client.send(request).timeout(const Duration(seconds: 4));
          final redirectUrl = response.headers['location'];

          if (redirectUrl != null && redirectUrl.isNotEmpty) {
            text = '$text $redirectUrl';
            if (redirectUrl.startsWith('http')) {
              currentUrl = redirectUrl;
            } else {
              final base = Uri.parse(currentUrl);
              currentUrl = base.resolve(redirectUrl).toString();
            }
          } else {
            // If response body is HTML (e.g. 200 OK), read snippet to find meta refresh or canonical
            final bodyBytes = await response.stream.toBytes();
            final body = String.fromCharCodes(bodyBytes);

            // Check for canonical or meta URL
            final metaUrlMatch = RegExp(r"https://(?:www\.)?google\.[a-z.]+/maps/[^\s""'<>]+")
                .firstMatch(body);
            if (metaUrlMatch != null) {
              text = '$text ${metaUrlMatch.group(0)}';
            }

            // Check for lat, lng in HTML or JS
            final htmlCoordMatch = RegExp(
              r'([-+]?\d{1,2}(?:\.\d{4,}))[,\s]+([-+]?\d{1,3}(?:\.\d{4,}))',
            ).firstMatch(body);
            if (htmlCoordMatch != null) {
              text = '$text ${htmlCoordMatch.group(1)},${htmlCoordMatch.group(2)}';
            }
            break;
          }
        }
      } catch (e) {
        debugPrint('[IncomingIntentService] Redirect resolution error: $e');
      } finally {
        client.close();
      }
    }

    return parseLocationUri(text);
  }

  /// Parses various Android geo: URIs, Google Maps URLs, and shared text strings.
  /// Formats handled:
  /// - geo:21.1234,72.5678
  /// - geo:0,0?q=21.1234,72.5678(Label)
  /// - geo:0,0?q=21.1234,72.5678
  /// - geo:0,0?q=Surat,+Gujarat
  /// - https://maps.google.com/?q=21.1234,72.5678
  /// - https://www.google.com/maps/search/?api=1&query=21.1234,72.5678
  /// - https://www.google.com/maps/place/.../@21.1234,72.5678,17z
  /// - https://maps.google.com/maps?daddr=21.1234,72.5678
  /// - WhatsApp shared text containing coordinates or addresses
  static IncomingLocationData parseLocationUri(String raw) {
    final clean = raw.trim();

    String decoded = clean;
    try {
      decoded = Uri.decodeFull(clean);
    } catch (_) {}

    // 1. Direct Lat/Lng search in any part of uri or text
    // Matches 21.12345, 72.87654 or @21.12345,72.87654 or q=21.12345,72.87654
    final latLngPattern = RegExp(
      r'([-+]?\d{1,2}(?:\.\d{3,}))[,\s]+([-+]?\d{1,3}(?:\.\d{3,}))',
    );

    final match = latLngPattern.firstMatch(decoded);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        // Extract query label if present in parentheses e.g. (Krishna textile hub)
        final labelMatch = RegExp(r'\(([^)]+)\)').firstMatch(decoded);
        var label = labelMatch?.group(1)?.trim();

        // If no parentheses label, check if there's a place name in the URL: /place/Place+Name/
        if (label == null || label.isEmpty) {
          final placeMatch = RegExp(r'/place/([^/@]+)').firstMatch(decoded);
          if (placeMatch != null) {
            label = placeMatch.group(1)!.replaceAll('+', ' ').trim();
          }
        }

        return IncomingLocationData(
          coordinates: LatLng(lat, lng),
          addressQuery: (label != null && label.isNotEmpty) ? label : null,
          rawUri: clean,
        );
      }
    }

    // 2. Query string search (e.g. geo:0,0?q=Krishna+textile+hub or maps?q=...)
    final qMatch = RegExp(r'[?&]q=([^&]+)').firstMatch(decoded);
    if (qMatch != null) {
      var query = qMatch.group(1)!.replaceAll('+', ' ').trim();
      query = query.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
      if (query.isNotEmpty) {
        return IncomingLocationData(
          addressQuery: query,
          rawUri: clean,
        );
      }
    }

    // 3. Fallback: If text doesn't contain coords, see if it has a place URL
    final placeMatch = RegExp(r'/place/([^/@]+)').firstMatch(decoded);
    if (placeMatch != null) {
      final label = placeMatch.group(1)!.replaceAll('+', ' ').trim();
      if (label.isNotEmpty) {
        return IncomingLocationData(
          addressQuery: label,
          rawUri: clean,
        );
      }
    }

    // 4. Fallback general coordinate pattern with 2 or more decimals e.g. 21.12, 72.84
    final generalPattern = RegExp(
      r'([-+]?\d{1,2}(?:\.\d+))[,\s]+([-+]?\d{1,3}(?:\.\d+))',
    );
    final generalMatch = generalPattern.firstMatch(decoded);
    if (generalMatch != null) {
      final lat = double.tryParse(generalMatch.group(1)!);
      final lng = double.tryParse(generalMatch.group(2)!);
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        return IncomingLocationData(
          coordinates: LatLng(lat, lng),
          rawUri: clean,
        );
      }
    }

    // 5. If the clean text is not a URL, it might be the shared place name itself
    if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('geo:')) {
      // Remove any trailing URL inside the text
      final textWithoutUrl = clean.replaceAll(RegExp(r'https?://[^\s]+'), '').trim();
      if (textWithoutUrl.isNotEmpty) {
        return IncomingLocationData(
          addressQuery: textWithoutUrl,
          rawUri: clean,
        );
      }
    }

    return IncomingLocationData(rawUri: clean);
  }
}
