import test from 'node:test';
import assert from 'node:assert/strict';
import {
  FLEET_NOTIFICATION_EVENT,
  INITIAL_NOTIFICATIONS,
  dispatchFleetNotification,
  playNotificationChime,
  sendBrowserNotification,
} from '../src/utils/notifications.js';

test('INITIAL_NOTIFICATIONS is empty by default so no fake dummy alerts are shown on launch', () => {
  assert.ok(Array.isArray(INITIAL_NOTIFICATIONS));
  assert.equal(INITIAL_NOTIFICATIONS.length, 0, 'INITIAL_NOTIFICATIONS should be empty by default');
});

test('dispatchFleetNotification dispatches CustomEvent on window with valid payload', () => {
  let dispatchedEvent = null;
  globalThis.window = {
    dispatchEvent: (event) => {
      dispatchedEvent = event;
    },
  };

  dispatchFleetNotification({
    title: 'Speed Limit Exceeded: Tata Signa',
    message: 'Speed reached 65 km/h in 48 km/h commercial zone.',
    severity: 'critical',
    category: 'Speed',
    vehicleId: 'Signa 2823',
  });

  assert.ok(dispatchedEvent, 'Event should have been dispatched');
  assert.equal(dispatchedEvent.type, FLEET_NOTIFICATION_EVENT);
  assert.equal(dispatchedEvent.detail.title, 'Speed Limit Exceeded: Tata Signa');
  assert.equal(dispatchedEvent.detail.severity, 'critical');
  assert.equal(dispatchedEvent.detail.category, 'Speed');
  assert.equal(dispatchedEvent.detail.read, false);
  assert.equal(dispatchedEvent.detail.resolved, false);
  assert.ok(dispatchedEvent.detail.id.startsWith('alert-'));

  delete globalThis.window;
});

test('playNotificationChime and sendBrowserNotification safely handle headless/node environments', () => {
  assert.doesNotThrow(() => playNotificationChime());
  assert.doesNotThrow(() => sendBrowserNotification('Title', 'Body'));
});



// get the  user  when check  it  with   the  login  page  and  check  it  out  driver  
// when the  user  are  getting  check it  out  and  handle the  things  if i  follow  it  ("now  the  {name :saurabh ,role : admin  }")
// { FALSE : "THE  VLAAFDF"}
// { TRUE : "THE  VVAFDFGDF" }
// TRUE :  {"ROLE" :  "ADMIN" "THE  VVAFDFGDF" }
// FALSE : {"ROLE" :  "DRIVER" "THE  VVAFDFGDF" }
//  FALSE :  ("Now {ROLE :ADMIN  }")
//  TRUE :  ("Now {ROLE :DRIVER  }")
//  IF  TRUE :  ("Now {ROLE :DRIVER  }")
