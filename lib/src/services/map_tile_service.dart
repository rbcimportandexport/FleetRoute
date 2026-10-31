/// Map tile endpoints used by the route planner.
///
/// Keep the familiar road/satellite appearance while avoiding the invalid
/// `m,traffic` layer combination that caused blank maps. Traffic is rendered
/// by the route overlay and every primary style has an independent fallback.
class MapTileService {
  static const List<String> subdomains = [];
  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  // Public labelled street tiles that do not require a separate Carto key.
  // ArcGIS uses {z}/{y}/{x}, unlike the OSM {z}/{x}/{y} ordering.
  static const String roadTileUrl = cartoVoyagerTileUrl;

  // Traffic needs a licensed provider/backend. Until configured, keep the
  // stable base map instead of requesting invalid composite tiles.
  static const String trafficTileUrl = roadTileUrl;

  // Public ArcGIS World Imagery endpoint; limited to its supported zoom.
  static const String satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static const String satelliteLabelsTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  static const String satelliteRoadsTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}';

  // No unauthorized traffic overlay is mixed into satellite imagery.
  static const String satelliteTrafficTileUrl = satelliteTileUrl;

  // A licensed transparent traffic overlay must be supplied at build time.
  // An empty value deliberately disables traffic rather than fabricating it.
  static const String trafficOverlayTileUrl = String.fromEnvironment(
    'TRAFFIC_OVERLAY_TILE_URL',
    defaultValue: '',
  );

  // Streetlight / Night Mode tile URL (dark street navigation view)
  static const String streetlightTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  // Independent provider fallback so a failed primary never leaves a blank map.
  static const String fallbackTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Google Terrain map
  static const String terrainTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';

  // Official OpenStreetMap standard tile URL (open-source, reliable, unblocked)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Official Carto Voyager tile URL (standard vector-rendered street map)
  static const String cartoVoyagerTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const String trafficProviderUrl =
      String.fromEnvironment('TRAFFIC_TILE_URL', defaultValue: '');

  static const String userAgent = 'com.transportone.transport_one';

  // Provider-specific max zoom levels
  static const double maxZoomOsm = 19.0;
  static const double maxZoomCarto = 19.0;
  static const double maxZoomSatellite = 18.0;
  static const double maxZoomArcGis = 18.0;

  /// Returns whether a real-time authorized traffic provider is configured
  static bool get hasAuthorizedTrafficProvider =>
      trafficOverlayTileUrl.trim().isNotEmpty;

  /// Provider-specific max zoom for reliable rendering without 404 tile errors
  static double getMaxZoom({bool streetlight = false, bool satellite = false}) {
    if (streetlight) return maxZoomCarto;
    if (satellite) return maxZoomSatellite;
    return maxZoomOsm;
  }

  /// Returns the appropriate map tile URL based on satellite, streetlight, and traffic toggles.
  static String getTileUrl({
    bool satellite = false,
    bool streetlight = false,
    bool traffic = false,
  }) {
    if (streetlight) {
      return streetlightTileUrl;
    }
    if (satellite) {
      return satelliteTileUrl;
    }
    if (traffic && hasAuthorizedTrafficProvider) {
      return trafficProviderUrl;
    }
    return roadTileUrl;
  }

  static List<String> getSubdomains({bool streetlight = false}) {
    // Both Carto Voyager (default light mode) and Dark All (streetlight) use carto subdomains
    return cartoSubdomains;
  }
}
