import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/reverse_geocoding_service.dart';
import '../theme/app_theme.dart';

/// Interactive modal dialog for searching locations by:
/// 1. Typed query / address / area name (e.g. "Ring Road Surat", "Bardoli")
/// 2. Pasted Google Maps link (e.g. "https://maps.app.goo.gl/...", "goo.gl/maps")
/// 3. One-tap current GPS location
/// 4. Quick popular city chips
class LocationSearchDialog extends StatefulWidget {
  const LocationSearchDialog({
    this.initialQuery = '',
    this.title = 'Search Location',
    this.hint = 'Location likhein ya Google Maps link paste karein',
    super.key,
  });

  final String initialQuery;
  final String title;
  final String hint;

  static Future<GeocodedPlace?> show(
    BuildContext context, {
    String initialQuery = '',
    String title = 'Search Location',
    String hint = 'Location likhein ya Google Maps link paste karein',
  }) {
    return showModalBottomSheet<GeocodedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchDialog(
        initialQuery: initialQuery,
        title: title,
        hint: hint,
      ),
    );
  }

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  String? _statusMessage;
  List<GeocodedPlace> _results = [];
  GeocodedPlace? _singleResolvedPlace;

  static const _popularCities = [
    'Surat',
    'Bardoli',
    'Kamrej',
    'Navsari',
    'Bharuch',
    'Ankleshwar',
    'Vapi',
    'Ahmedabad',
    'Mumbai',
    'Delhi',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _performSearch(widget.initialQuery.trim());
    }
    // Auto-focus after bottom sheet animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _singleResolvedPlace = null;
        _isLoading = false;
        _statusMessage = null;
      });
      return;
    }

    // If it's a URL or contains http, resolve immediately
    if (query.startsWith('http') || query.contains('goo.gl') || query.contains('google.com/maps')) {
      _performSearch(query);
      return;
    }

    // Debounce 450ms for typing place names
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = clean.startsWith('http')
          ? 'Google Maps link resolve ho raha hai...'
          : 'Searching places...';
      _singleResolvedPlace = null;
    });

    try {
      // 1. If it's a URL, resolve direct place
      if (clean.startsWith('http') || clean.contains('goo.gl') || clean.contains('google.com/maps')) {
        final place = await ReverseGeocodingService.resolveLocationQueryOrLink(clean);
        if (!mounted) return;
        if (place != null) {
          setState(() {
            _singleResolvedPlace = place;
            _results = [place];
            _isLoading = false;
            _statusMessage = 'Link se location mil gayi!';
          });
          return;
        } else {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Link se coordinates nahi mil paye. Address likhkar try karein.';
          });
          return;
        }
      }

      // 2. Search places by text
      final places = await ReverseGeocodingService.searchPlaces(clean, limit: 6);
      if (!mounted) return;

      setState(() {
        _results = places;
        _isLoading = false;
        _statusMessage = places.isEmpty
            ? '"$clean" ke liye koi location nahi mili. Dusra naam likhein.'
            : '${places.length} locations mili';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Search error: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clipboard khaali hai (No text copied)')),
          );
        }
        return;
      }
      _searchController.text = text;
      _performSearch(text);
    } catch (_) {}
  }

  Future<void> _useCurrentGps() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Current GPS location khoji ja rahi hai...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw Exception('GPS service enable karein.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission allow karein.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final coords = LatLng(pos.latitude, pos.longitude);
      final address = await ReverseGeocodingService.addressFor(coords);
      final short = address?.split(',').first.trim() ?? 'My GPS Location';

      final place = GeocodedPlace(
        coordinates: coords,
        displayName: address ?? '${pos.latitude}, ${pos.longitude}',
        shortName: short,
      );

      if (mounted) {
        Navigator.of(context).pop(place);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'GPS error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD3DCE8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_searching_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                      const Text(
                        'Address likhein ya Google Maps link paste karein',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.slate,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Band karein',
                ),
              ],
            ),
          ),

          // Search Field + Paste Button Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    onSubmitted: (val) => _performSearch(val),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _pasteFromClipboard,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                    ),
                  ),
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text(
                    'Paste',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Shortcuts: Use Current GPS & Popular Cities
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                  label: const Text(
                    'Current GPS Location',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  backgroundColor: const Color(0xFFF0F9FF),
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  onPressed: _useCurrentGps,
                ),
                for (final city in _popularCities.take(5))
                  ActionChip(
                    label: Text(
                      city,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF334155),
                      ),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    onPressed: () {
                      _searchController.text = city;
                      _performSearch(city);
                    },
                  ),
              ],
            ),
          ),

          // Loading Indicator or Status
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _statusMessage ?? 'Searching...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (_statusMessage != null && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

          // Results List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _results[index];
                final isLinkMatch = _singleResolvedPlace == place;

                return InkWell(
                  onTap: () => Navigator.of(context).pop(place),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: isLinkMatch
                        ? BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          )
                        : null,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isLinkMatch
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLinkMatch
                                ? Icons.check_circle_rounded
                                : Icons.place_rounded,
                            size: 18,
                            color: isLinkMatch
                                ? const Color(0xFF16A34A)
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.shortName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  fontFamily: 'sans-serif',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                place.displayName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'sans-serif',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GPS: ${place.coordinates.latitude.toStringAsFixed(5)}, ${place.coordinates.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
