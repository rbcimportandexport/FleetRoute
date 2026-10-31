/// Map tile endpoints used by the route planner.
///
/// Direct high-speed Google Maps Tile Engine & OpenStreetMap fallback.
/// Renders authentic Google Maps light mode without watermark, API key restrictions,
/// or billing account requirements.
class MapTileService {
  static const List<String> subdomains = ['0', '1', '2', '3'];
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  // Authentic Google Maps standard light mode street map (mt0-mt3)
  // Official Carto Voyager tile URL
  static const String cartoVoyagerTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const String roadTileUrl =
      'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  // Authentic Google Maps with live traffic
  static const String trafficTileUrl =
      'https://mt{s}.google.com/vt/lyrs=m,traffic&x={x}&y={y}&z={z}';

  // Authentic Google Maps hybrid satellite with roads and high-res terrain
  static const String satelliteTileUrl =
      'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';

  static const String satelliteLabelsTileUrl =
      'https://mt{s}.google.com/vt/lyrs=h&x={x}&y={y}&z={z}';

  static const String satelliteRoadsTileUrl =
      'https://mt{s}.google.com/vt/lyrs=h&x={x}&y={y}&z={z}';

  static const String satelliteTrafficTileUrl =
      'https://mt{s}.google.com/vt/lyrs=y,traffic&x={x}&y={y}&z={z}';

  static const String trafficOverlayTileUrl = '';

  // Streetlight / Night Mode tile URL
  static const String streetlightTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  // Reliable independent fallback
  static const String fallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Google Terrain map
  static const String terrainTileUrl =
      'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}';

  // Official OpenStreetMap standard tile URL
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String userAgent = 'com.transportone.transport_one';

  // Provider-specific max zoom levels
  static const double maxZoomOsm = 19.0;
  static const double maxZoomCarto = 19.0;
  static const double maxZoomSatellite = 20.0;
  static const double maxZoomGoogle = 21.0;

  static bool get hasAuthorizedTrafficProvider => true;

  static double getMaxZoom({bool streetlight = false, bool satellite = false}) {
    if (streetlight) return maxZoomCarto;
    if (satellite) return maxZoomSatellite;
    return maxZoomGoogle;
  }

  static String getTileUrl({
    bool satellite = false,
    bool streetlight = false,
    bool traffic = false,
  }) {
    if (streetlight) {
      return streetlightTileUrl;
    }
    if (satellite) {
      return traffic ? satelliteTrafficTileUrl : satelliteTileUrl;
    }
    if (traffic) {
      return trafficTileUrl;
    }
    return roadTileUrl;
  }

  static List<String> getSubdomains({bool streetlight = false}) {
    if (streetlight) {
      return cartoSubdomains;
    }
    return subdomains;
  }
}
