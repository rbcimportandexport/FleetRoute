// server/scripts/seedTrips.js
// Seeds active trips with pre-configured gate proof photos and stops
// STRICTLY ZERO EMOJIS.

const db = require('../db');
const { seedTrips } = require('../seedData');

async function seedTripsData() {
  await db.connect();
  console.log('[FleetRoute Seed Trips] Connected to database');

  const existingTrips = await db.collection('trips').find();
  console.log(`[FleetRoute Seed Trips] Currently found ${existingTrips.length} trips in database.`);

  let added = 0;
  for (const trip of seedTrips) {
    const existing = await db.collection('trips').findOne({ id: trip.id });
    if (!existing) {
      // Add default gate proofs with high-res photo assets
      const tripWithProofs = {
        ...trip,
        isDemo: false,
        gateProofs: {
          odometerPhoto: '/images/gate-proofs/odometer-cluster.jpg',
          odometerTimestamp: '2026-10-12T10:14:00Z',
          walkaroundPhoto: '/images/gate-proofs/walkaround-front.jpg',
          walkaroundTimestamp: '2026-10-12T10:17:00Z',
          driverSeatbeltPhoto: '/images/gate-proofs/driver-seatbelt-selfie.jpg',
          driverSeatbeltTimestamp: '2026-10-12T10:19:00Z',
          seatbeltVerified: true,
          overspeedingPledge: true,
          depotLocationName: 'Depot 4'
        }
      };

      await db.collection('trips').insertOne(tripWithProofs);
      console.log(`[FleetRoute Seed Trips] Created trip: ${trip.id} - ${trip.title}`);
      added++;
    } else {
      // Ensure gateProofs are updated if null
      if (!existing.gateProofs) {
        await db.collection('trips').updateOne(
          { id: trip.id },
          {
            gateProofs: {
              odometerPhoto: '/images/gate-proofs/odometer-cluster.jpg',
              odometerTimestamp: '2026-10-12T10:14:00Z',
              walkaroundPhoto: '/images/gate-proofs/walkaround-front.jpg',
              walkaroundTimestamp: '2026-10-12T10:17:00Z',
              driverSeatbeltPhoto: '/images/gate-proofs/driver-seatbelt-selfie.jpg',
              driverSeatbeltTimestamp: '2026-10-12T10:19:00Z',
              seatbeltVerified: true,
              overspeedingPledge: true,
              depotLocationName: 'Depot 4'
            }
          }
        );
        console.log(`[FleetRoute Seed Trips] Updated gateProofs for trip: ${trip.id}`);
      }
    }
  }

  console.log(`[FleetRoute Seed Trips] Finished. Added ${added} new trips.`);
  await db.disconnect();
}

seedTripsData().catch(err => {
  console.error('[FleetRoute Seed Trips ERROR]', err);
  process.exit(1);
});
