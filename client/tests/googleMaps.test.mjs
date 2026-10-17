import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { normalizeGoogleRoute, resolveGoogleSuggestion, loadGoogleMaps } from '../src/maps/googleMaps.js';

// Test fixtures only. The app never loads seeded locations or simulated GPS.
const routeFixture = () => ({
  path: [{ lat: 20, lng: 70 }, { lat: 21, lng: 71 }],
  distanceMeters: 1200,
  durationMillis: 180000,
  legs: [{ steps: [{ instructions: 'Continue straight', distanceMeters: 1200, maneuver: 'STRAIGHT' }] }],
});

test('normalizes Google route units and coordinates for the existing UI', () => {
  const route = normalizeGoogleRoute(routeFixture());
  assert.equal(route.provider, 'google');
  assert.equal(route.distance, 1200);
  assert.equal(route.duration, 180);
  assert.deepEqual(route.geometry.coordinates, [[70, 20], [71, 21]]);
  assert.equal(route.legs[0].steps[0].instruction, 'Continue straight');
});

test('accepts Google LatLng objects and absent optional steps', () => {
  const route = normalizeGoogleRoute({
    ...routeFixture(), legs: undefined,
    path: [{ lat: () => 20, lng: () => 70 }, { lat: () => 21, lng: () => 71 }],
  });
  assert.deepEqual(route.geometry.coordinates, [[70, 20], [71, 21]]);
  assert.deepEqual(route.legs, []);
});

test('rejects incomplete routes instead of inventing a distance or route', () => {
  for (const patch of [{ path: [] }, { durationMillis: undefined }, { distanceMeters: NaN }, { path: [{ lat: NaN, lng: 70 }, { lat: 21, lng: 71 }] }]) {
    assert.throws(() => normalizeGoogleRoute({ ...routeFixture(), ...patch }), /complete drivable route/);
  }
});

test('resolves the clicked prediction and preserves its place ID', async () => {
  let fieldRequest;
  const place = {
    id: 'test-selected-place', displayName: 'Selected village', formattedAddress: 'Selected district',
    location: { toJSON: () => ({ lat: 20, lng: 70 }) },
    fetchFields: async (request) => { fieldRequest = request; },
  };
  const selected = await resolveGoogleSuggestion({ prediction: { toPlace: () => place } });
  assert.deepEqual(selected.point, { lat: 20, lng: 70, placeId: 'test-selected-place' });
  assert.equal(selected.label, 'Selected village, Selected district');
  assert.deepEqual(fieldRequest.fields, ['location', 'formattedAddress', 'displayName']);
});

test('does not substitute a nearby point when Google has no coordinates', async () => {
  await assert.rejects(resolveGoogleSuggestion({ prediction: { toPlace: () => ({ fetchFields: async () => {} }) } }), /no map coordinates/);
});

test('a missing key fails clearly before any browser or network request', async () => {
  await assert.rejects(loadGoogleMaps(), /key is missing/);
});

// Replace only Vite's build-time env expression, with a nonfunctional test key.
// No real .env files or credentials are read by this test suite.
async function isolatedGoogleModule() {
  const source = await readFile(new URL('../src/maps/googleMaps.js', import.meta.url), 'utf8');
  const testSource = source.replace('import.meta.env || {}', JSON.stringify({ VITE_GOOGLE_MAPS_API_KEY: 'test-only-nonfunctional', VITE_MAP_PROVIDER: 'google' }));
  return import(`data:text/javascript;base64,${Buffer.from(testSource).toString('base64')}`);
}

test('Google services use place IDs, separate autocomplete sessions and native route requests', async () => {
  const service = await isolatedGoogleModule();
  let searchRequest;
  let routeRequest;
  class Place { constructor({ id }) { this.id = id; } }
  class AutocompleteSessionToken {}
  const prediction = { placeId: 'test-selected-place', text: { toString: () => 'Village, District' }, mainText: { toString: () => 'Village' } };
  const previousWindow = globalThis.window;
  globalThis.window = { google: { maps: { importLibrary: async (library) => {
    if (library === 'places') return {
      Place, AutocompleteSessionToken,
      AutocompleteSuggestion: { fetchAutocompleteSuggestions: async (request) => {
        searchRequest = request;
        return { suggestions: [{ placePrediction: prediction }, { queryPrediction: {} }] };
      } },
    };
    if (library === 'routes') return { Route: { computeRoutes: async (request) => {
      routeRequest = request;
      return { routes: [routeFixture()] };
    } } };
    throw new Error(`Unexpected library: ${library}`);
  } } } };
  try {
    const originSession = {};
    const destinationSession = {};
    const suggestions = await service.googleSuggestions('Village', { lat: 20, lng: 70 }, originSession);
    assert.equal(suggestions.length, 1);
    assert.equal(suggestions[0].prediction, prediction);
    assert.equal(searchRequest.sessionToken, originSession.token);
    assert.equal(searchRequest.locationRestriction, undefined);
    await service.googleSuggestions('Other village', undefined, destinationSession);
    assert.notEqual(originSession.token, destinationSession.token);
    assert.equal(searchRequest.locationBias, undefined);

    const route = await service.calculateGoogleRoute({ lat: 20, lng: 70, placeId: 'test-selected-place' }, { lat: 21, lng: 71 });
    assert.ok(routeRequest.origin instanceof Place);
    assert.equal(routeRequest.origin.id, 'test-selected-place');
    assert.deepEqual(routeRequest.destination, { lat: 21, lng: 71 });
    assert.equal(routeRequest.travelMode, 'DRIVING');
    assert.equal(routeRequest.routingPreference, 'TRAFFIC_UNAWARE');
    assert.equal(route.duration, 180);
  } finally {
    if (previousWindow === undefined) delete globalThis.window;
    else globalThis.window = previousWindow;
  }
});

test('dynamically decreases remaining distance and remaining ETA as vehicle travels along route', () => {
  const totalDistanceMeters = 145000; // 145 km
  const totalDurationSeconds = 12180; // 3 hr 23 min
  const totalSteps = 100;

  // Simulate vehicle advancing from step 0 to step 100
  const snapshots = [0, 25, 50, 75, 100].map((step) => {
    const fraction = step / totalSteps;
    const covered = Math.round(fraction * totalDistanceMeters);
    const remainingDist = Math.max(0, totalDistanceMeters - covered);
    const remainingDur = Math.max(0, Math.round((1 - fraction) * totalDurationSeconds));
    const percent = Math.round(fraction * 100);
    return { step, remainingDist, remainingDur, percent };
  });

  // At start
  assert.equal(snapshots[0].remainingDist, 145000);
  assert.equal(snapshots[0].remainingDur, 12180);
  assert.equal(snapshots[0].percent, 0);

  // Monotonically decreasing distance and duration
  for (let i = 1; i < snapshots.length; i++) {
    assert.ok(snapshots[i].remainingDist < snapshots[i - 1].remainingDist, 'Distance must decrease as vehicle moves forward');
    assert.ok(snapshots[i].remainingDur < snapshots[i - 1].remainingDur, 'Duration must decrease as vehicle moves forward');
    assert.ok(snapshots[i].percent > snapshots[i - 1].percent, 'Progress percent must increase');
  }

  // At destination
  assert.equal(snapshots[4].remainingDist, 0);
  assert.equal(snapshots[4].remainingDur, 0);
  assert.equal(snapshots[4].percent, 100);
});
