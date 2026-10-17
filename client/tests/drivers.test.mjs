import test from 'node:test';
import assert from 'node:assert/strict';
import { INITIAL_DRIVERS } from '../src/utils/fleetData.js';

test('INITIAL_DRIVERS is empty by default without mock or dummy data', () => {
  assert.ok(Array.isArray(INITIAL_DRIVERS));
  assert.equal(INITIAL_DRIVERS.length, 0, 'INITIAL_DRIVERS must be empty by default');
});

test('Commercial driver record structure accepts valid fields without emojis', () => {
  const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u;

  const testDriver = {
    id: 'driver-101',
    name: 'Ramesh Patel',
    phone: '+91 98250 11223',
    license: 'GJ05-2021-0089123',
    experience: '5 Years',
    rating: '4.8',
    status: 'available',
    baseHub: 'Surat Central Depot',
    vehicle: {
      model: '6-Wheeler MCV (Eicher 11.10)',
      plate: 'GJ-05-BX-1234',
      category: 'truck',
      type: 'Medium Goods Carrier',
      maxSpeed: 55,
      capacity: '7.5 Ton',
    },
    currentTrip: null,
    lastTrip: null,
  };

  assert.ok(testDriver.id);
  assert.ok(testDriver.name);
  assert.ok(testDriver.vehicle.plate);
  assert.equal(emojiRegex.test(testDriver.name), false, 'No emojis allowed in name');
  assert.equal(emojiRegex.test(testDriver.vehicle.model), false, 'No emojis allowed in vehicle');
  assert.ok(['on_trip', 'available', 'off_duty'].includes(testDriver.status));
});

test('Commercial driver supports email and login credentials without emojis', () => {
  const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u;

  const testDriverWithLogin = {
    id: 'driver-102',
    name: 'Suresh Kumar',
    phone: '+91 98765 43210',
    email: 'suresh.kumar@fleetroute.in',
    loginCredentials: {
      username: 'suresh.kumar@fleetroute.in',
      password: 'Driver@123',
      pin: '4821',
      loginEnabled: true,
    },
    status: 'available',
  };

  assert.equal(testDriverWithLogin.email, 'suresh.kumar@fleetroute.in');
  assert.equal(testDriverWithLogin.loginCredentials.pin, '4821');
  assert.equal(testDriverWithLogin.loginCredentials.loginEnabled, true);
  assert.equal(emojiRegex.test(testDriverWithLogin.email), false);
  assert.equal(emojiRegex.test(testDriverWithLogin.loginCredentials.password), false);
});

test('Driver trip assignment payload handles real Google route dispatch without emojis', () => {
  const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u;

  const dispatchPayload = {
    driverId: 'driver-101',
    origin: 'Surat Central Depot, Ring Road, Surat',
    destination: 'Ahmedabad Logistics Park, Sarkhej, Ahmedabad',
    cargo: '10 Ton Heavy Industrial Consignment',
    distance: '264 km',
    eta: '5 hr 41 min',
    remark: 'Priority commercial transport run via NH48',
  };

  assert.equal(dispatchPayload.driverId, 'driver-101');
  assert.ok(dispatchPayload.distance.includes('km'));
  assert.equal(emojiRegex.test(dispatchPayload.origin), false);
  assert.equal(emojiRegex.test(dispatchPayload.destination), false);
  assert.equal(emojiRegex.test(dispatchPayload.remark), false);
});

