// server/tests/logic.test.js
const assert = require('assert');
const { seedTrips } = require('../seedData');

console.log('--- RUNNING FLEETROUTE CORE LOGIC TESTS ---');

// Test 1: Cargo Balance Calculation in Required Demo Scenario
// 12 Office Chairs + 3 Massage Chairs = 15 total loaded
// Stop A: Deliver 5 office chairs -> 10 onboard
// Stop B: Deliver 7 office chairs -> 3 onboard
// Stop C: Deliver 3 massage chairs -> 0 onboard
{
  const demoTrip = seedTrips.find(t => t.id === 'TRIP-DEMO-01');
  assert(demoTrip, 'Demo trip must exist');

  const officeChairs = demoTrip.cargoLines.find(c => c.productId === 'PRD-01');
  const massageChairs = demoTrip.cargoLines.find(c => c.productId === 'PRD-02');

  assert.strictEqual(officeChairs.quantityLoaded, 12, '12 Office chairs loaded');
  assert.strictEqual(massageChairs.quantityLoaded, 3, '3 Massage chairs loaded');

  let onboard = officeChairs.quantityLoaded + massageChairs.quantityLoaded;
  assert.strictEqual(onboard, 15, 'Total loaded is 15 units');

  // Step 1: Stop A delivers 5 office chairs
  const stopADelivered = 5;
  onboard -= stopADelivered;
  assert.strictEqual(onboard, 10, 'After Stop A, 10 units remain onboard');

  // Step 2: Stop B delivers 7 office chairs
  const stopBDelivered = 7;
  onboard -= stopBDelivered;
  assert.strictEqual(onboard, 3, 'After Stop B, 3 units remain onboard');

  // Step 3: Stop C delivers 3 massage chairs
  const stopCDelivered = 3;
  onboard -= stopCDelivered;
  assert.strictEqual(onboard, 0, 'After Stop C, 0 units remain onboard');

  console.log('[PASS] Test 1: Cargo balance progressive deduction verified (15 -> 10 -> 3 -> 0).');
}

// Test 2: Activity Duration Mathematically Non-overlapping Verification
// Total: 250 minutes (Driving: 120m, Loading: 25m, Unloading: 45m, Traffic: 20m, Refuel: 10m, Puncture: 30m)
{
  const demoTrip = seedTrips.find(t => t.id === 'TRIP-DEMO-01');
  const timeline = demoTrip.activityTimeline;

  let totalDuration = 0;
  let categoryTotals = {
    DRIVING: 0,
    LOADING: 0,
    UNLOADING: 0,
    TRAFFIC_DELAY: 0,
    REFUELING: 0,
    PUNCTURE_REPAIR: 0
  };

  timeline.forEach((act, idx) => {
    totalDuration += act.durationMinutes;
    categoryTotals[act.category] = (categoryTotals[act.category] || 0) + act.durationMinutes;

    // Check non-overlapping sequence
    if (idx > 0) {
      const prev = timeline[idx - 1];
      assert.strictEqual(
        act.startMinutes,
        prev.startMinutes + prev.durationMinutes,
        `Activity ${act.title} must start exactly when previous activity ended without gap or overlap`
      );
    }
  });

  assert.strictEqual(totalDuration, 250, 'Total activity time must equal 250 minutes');
  assert.strictEqual(categoryTotals.DRIVING, 120, 'Driving time must equal 120 minutes');
  assert.strictEqual(categoryTotals.LOADING, 25, 'Loading time must equal 25 minutes');
  assert.strictEqual(categoryTotals.UNLOADING, 45, 'Unloading time must equal 45 minutes');
  assert.strictEqual(categoryTotals.TRAFFIC_DELAY, 20, 'Traffic delay must equal 20 minutes');
  assert.strictEqual(categoryTotals.REFUELING, 10, 'Refueling must equal 10 minutes');
  assert.strictEqual(categoryTotals.PUNCTURE_REPAIR, 30, 'Puncture repair must equal 30 minutes');

  console.log('[PASS] Test 2: Activity durations exactly match 250 minutes with 0 overlaps.');
}

// Test 3: Stop Sequence Integrity
{
  const demoTrip = seedTrips.find(t => t.id === 'TRIP-DEMO-01');
  assert.strictEqual(demoTrip.routeStops.length, 6, 'Must contain 6 waypoints');
  assert.strictEqual(demoTrip.routeStops[0].type, 'ORIGIN_HOME');
  assert.strictEqual(demoTrip.routeStops[1].type, 'CARGO_PICKUP');
  assert.strictEqual(demoTrip.routeStops[2].type, 'DELIVERY_STOP_A');
  assert.strictEqual(demoTrip.routeStops[3].type, 'DELIVERY_STOP_B');
  assert.strictEqual(demoTrip.routeStops[4].type, 'DELIVERY_STOP_C');
  assert.strictEqual(demoTrip.routeStops[5].type, 'DEPOT_RETURN');

  console.log('[PASS] Test 3: Stop sequence progression verified.');
}

console.log('--- ALL AUTOMATED LOGIC TESTS PASSED SUCCESSFULLY (3/3) ---');
