const env = import.meta.env || {};
// In Vite browser builds (including Vercel deployment), embed the default Google Maps key.
// In Node test runner, leave empty so unit tests for missing keys pass.
const defaultKey = env.MODE ? 'AIzaSyDn0iBMNUZ3JgXyUSPw_eLhxSveeM17PEY' : '';
const apiKey = (env.VITE_GOOGLE_MAPS_API_KEY || defaultKey).trim();
const hasKey = Boolean(apiKey && !/your[_ -]?key|replace|example/i.test(apiKey));
export const useGoogleMaps = env.VITE_MAP_PROVIDER === 'google'
  || (env.VITE_MAP_PROVIDER !== 'open' && hasKey);
export const googleLanguage = env.VITE_GOOGLE_MAPS_LANGUAGE || 'en';
export const googleRegion = env.VITE_GOOGLE_MAPS_REGION || 'IN';

let loadPromise;
let authError;
export const GOOGLE_AUTH_ERROR_EVENT = 'fleetroute:google-maps-auth-error';

// One official SDK script per page, including React StrictMode remounts.
export function loadGoogleMaps() {
  if (!hasKey) return Promise.reject(new Error('Google Maps key is missing. Add VITE_GOOGLE_MAPS_API_KEY to client/.env.local and restart the local server.'));
  if (authError) return Promise.reject(authError);
  if (window.google?.maps?.importLibrary) return Promise.resolve(window.google.maps);
  if (loadPromise) return loadPromise;

  loadPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    const callback = '__fleetRouteGoogleMapsReady';
    let timer;
    const fail = (message) => {
      window.clearTimeout(timer);
      script.remove();
      // A late SDK response may still invoke its callback after a timeout.
      window[callback] = () => {};
      reject(new Error(message));
    };
    const previousAuthFailure = window.gm_authFailure;
    window.gm_authFailure = () => {
      authError = new Error('Google Maps rejected the key. Check API activation, billing and website restrictions in Google Cloud.');
      window.dispatchEvent(new Event(GOOGLE_AUTH_ERROR_EVENT));
      fail(authError.message);
      previousAuthFailure?.();
    };
    window[callback] = () => {
      window.clearTimeout(timer);
      resolve(window.google.maps);
    };
    script.id = 'fleetroute-google-maps-sdk';
    script.async = true;
    script.src = `https://maps.googleapis.com/maps/api/js?${new URLSearchParams({
      key: apiKey,
      loading: 'async',
      callback,
      v: 'weekly',
      language: googleLanguage,
      region: googleRegion,
    })}`;
    script.onerror = () => fail('Google Maps could not load. Check your internet connection and reload the page.');
    timer = window.setTimeout(() => fail('Google Maps took too long to load. Check your connection and reload the page.'), 20000);
    document.head.appendChild(script);
  });
  return loadPromise;
}

export async function googleSuggestions(input, center, session) {
  const maps = await loadGoogleMaps();
  const { AutocompleteSuggestion, AutocompleteSessionToken } = await maps.importLibrary('places');
  session.token ||= new AutocompleteSessionToken();
  const request = { input, sessionToken: session.token, language: googleLanguage, region: googleRegion.toLowerCase() };
  // Bias, never restrict: addresses outside the current view remain searchable.
  if (center) request.locationBias = { center: { lat: center.lat, lng: center.lng }, radius: 50000 };
  const { suggestions } = await AutocompleteSuggestion.fetchAutocompleteSuggestions(request);
  return suggestions.filter((item) => item.placePrediction).map(({ placePrediction }) => ({
    id: placePrediction.placeId,
    label: placePrediction.text.toString(),
    primary: placePrediction.mainText?.toString() || placePrediction.text.toString(),
    prediction: placePrediction,
    provider: 'google',
  }));
}

export async function resolveGoogleSuggestion(result) {
  // Resolve exactly what the user clicked; do not run another text search.
  const place = result.prediction.toPlace();
  await place.fetchFields({ fields: ['location', 'formattedAddress', 'displayName'] });
  if (!place.location) throw new Error('This place has no map coordinates. Choose another result or pin the location.');
  const address = place.formattedAddress || '';
  const name = place.displayName || '';
  return {
    label: (name && !address.startsWith(name) ? [name, address].filter(Boolean).join(', ') : address || name) || result.label,
    point: { ...place.location.toJSON(), placeId: place.id },
  };
}

export function normalizeGoogleRoute(route) {
  const coordinates = (route.path || []).map((point) => [
    typeof point.lng === 'function' ? point.lng() : point.lng,
    typeof point.lat === 'function' ? point.lat() : point.lat,
  ]);
  if (coordinates.length < 2 || !coordinates.every((point) => point.every(Number.isFinite))
    || !Number.isFinite(route.distanceMeters) || !Number.isFinite(route.durationMillis)) {
    throw new Error('Google did not return a complete drivable route. Try different endpoints.');
  }
  const liveDuration = route.durationMillis / 1000;
  const staticDuration = Number.isFinite(route.staticDurationMillis) ? route.staticDurationMillis / 1000 : null;
  const trafficDelaySeconds = staticDuration && liveDuration > staticDuration ? Math.round(liveDuration - staticDuration) : 0;

  return {
    provider: 'google',
    distance: route.distanceMeters,
    duration: liveDuration,
    staticDuration,
    trafficDelaySeconds,
    warnings: route.warnings || [],
    geometry: { coordinates },
    legs: (route.legs || []).map((leg) => ({ steps: (leg.steps || []).map((step) => ({
      instruction: step.instructions || 'Continue along the route',
      distance: step.distanceMeters,
      maneuver: { location: [], type: step.maneuver },
    })) })),
  };
}

export async function calculateGoogleRoute(origin, destination, options = {}) {
  const maps = await loadGoogleMaps();
  const [{ Route }, { Place }] = await Promise.all([maps.importLibrary('routes'), maps.importLibrary('places')]);
  const waypoint = (point) => point.placeId ? new Place({ id: point.placeId }) : { lat: point.lat, lng: point.lng };
  const travelMode = options.travelMode || 'DRIVING';
  const routingPreference = options.routingPreference || 'TRAFFIC_UNAWARE';
  const { routes } = await Route.computeRoutes({
    origin: waypoint(origin), destination: waypoint(destination),
    travelMode, routingPreference,
    language: googleLanguage, region: googleRegion.toLowerCase(),
    fields: ['path', 'distanceMeters', 'durationMillis', 'staticDurationMillis', 'legs', 'warnings'],
  });
  if (!routes?.length) throw new Error('No drivable route was found between these locations.');
  return normalizeGoogleRoute(routes[0]);
}
