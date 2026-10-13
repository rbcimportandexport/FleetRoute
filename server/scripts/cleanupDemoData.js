#!/usr/bin/env node
// server/scripts/cleanupDemoData.js
// Auditable Demo Data Cleanup Tool for FleetRoute
// STRICTLY ZERO EMOJIS. DEFAULTS TO DRY-RUN. PRESERVES REAL RECORDS.

require('dotenv').config();
const db = require('../db');

// Explicit seed identifiers known from original initial scenario
const SEED_IDENTIFIERS = {
  users: [
    'USR-ADMIN-01',
    'USR-DRV-101', 'USR-DRV-102', 'USR-DRV-103', 'USR-DRV-104',
    'USR-DRV-105', 'USR-DRV-106', 'USR-DRV-107', 'USR-DRV-108'
  ],
  drivers: [
    'DRV-101', 'DRV-102', 'DRV-103', 'DRV-104',
    'DRV-105', 'DRV-106', 'DRV-107', 'DRV-108'
  ],
  vehicles: [
    'VEH-201', 'VEH-202', 'VEH-203', 'VEH-204',
    'VEH-205', 'VEH-206', 'VEH-207', 'VEH-208'
  ],
  products: [
    'PRD-301', 'PRD-302', 'PRD-303', 'PRD-304',
    'PRD-305', 'PRD-306', 'PRD-307', 'PRD-308'
  ],
  locations: [
    'LOC-01', 'LOC-02', 'LOC-03', 'LOC-04',
    'LOC-05', 'LOC-06', 'LOC-07', 'LOC-08'
  ],
  trips: [
    'TRIP-DEMO-01', 'TRIP-PARTIAL-02', 'TRIP-MUM-03', 'TRIP-BLR-04', 'TRIP-COMPLETED-05'
  ],
  safetyEvents: [
    'VIO-01', 'VIO-02'
  ]
};

async function auditAndCleanupDemoData(options = {}) {
  const isApplyMode = Boolean(options.apply !== undefined ? options.apply : process.argv.includes('--apply'));
  const shouldDisconnect = options.disconnect !== undefined ? options.disconnect : (require.main === module);

  console.log('================================================================');
  console.log(`FleetRoute Demo Data Cleanup [MODE: ${isApplyMode ? 'APPLY (DELETION)' : 'DRY-RUN (AUDIT ONLY)'}]`);
  console.log('================================================================');

  if (!db.connected) {
    try {
      await db.connect();
    } catch (err) {
      console.error('[Cleanup ERROR] Unable to connect to MongoDB:', err.message);
      if (require.main === module) process.exit(1);
      throw err;
    }
  }

  const collections = ['users', 'drivers', 'vehicles', 'products', 'locations', 'trips', 'safetyEvents', 'deliveryProofs'];
  const auditReport = {};

  for (const colName of collections) {
    const col = db.collection(colName);
    const allRecords = await col.find({});
    const knownSeedIds = SEED_IDENTIFIERS[colName] || [];

    const demoRecords = [];
    const realRecords = [];
    const ambiguousRecords = [];

    for (const rec of allRecords) {
      const isExplicitDemo = rec.isDemo === true || (rec.source && rec.source === 'simulation');
      const isKnownSeedId = knownSeedIds.includes(rec.id);
      
      // Special check for seed trip references in deliveryProofs
      const isSeedTripRef = colName === 'deliveryProofs' && SEED_IDENTIFIERS.trips.includes(rec.tripId);

      if (isExplicitDemo || isKnownSeedId || isSeedTripRef) {
        demoRecords.push(rec);
      } else if (rec.name && rec.name.toLowerCase().includes('demo') && !isExplicitDemo && !isKnownSeedId) {
        // Name mentions demo but ID does not match known seed: REFUSE and treat as ambiguous
        ambiguousRecords.push(rec);
      } else {
        realRecords.push(rec);
      }
    }

    auditReport[colName] = {
      total: allRecords.length,
      demoCount: demoRecords.length,
      demoIds: demoRecords.map(r => r.id),
      realCount: realRecords.length,
      ambiguousCount: ambiguousRecords.length,
      ambiguousIds: ambiguousRecords.map(r => r.id)
    };

    if (isApplyMode && demoRecords.length > 0) {
      for (const demoRec of demoRecords) {
        await col.deleteOne({ id: demoRec.id });
      }
    }
  }

  console.log('\n--- AUDIT SUMMARY BY COLLECTION ---');
  let totalDemoIdentified = 0;
  let totalRealPreserved = 0;
  let totalAmbiguous = 0;

  for (const [col, report] of Object.entries(auditReport)) {
    console.log(`[${col.toUpperCase()}]`);
    console.log(`  - Total in Database:   ${report.total}`);
    console.log(`  - Confirmed Demo:      ${report.demoCount} ${report.demoCount > 0 ? `(${report.demoIds.slice(0, 5).join(', ')}${report.demoIds.length > 5 ? '...' : ''})` : ''}`);
    console.log(`  - Real (Preserved):    ${report.realCount}`);
    if (report.ambiguousCount > 0) {
      console.warn(`  - Ambiguous (Untouched): ${report.ambiguousCount} (IDs: ${report.ambiguousIds.join(', ')})`);
    }

    totalDemoIdentified += report.demoCount;
    totalRealPreserved += report.realCount;
    totalAmbiguous += report.ambiguousCount;
  }

  console.log('----------------------------------------------------------------');
  console.log(`TOTALS: ${totalDemoIdentified} demo records identified | ${totalRealPreserved} real records preserved | ${totalAmbiguous} ambiguous records left untouched`);

  if (!isApplyMode) {
    console.log('\n[DRY-RUN NOTICE] No changes were made to the database.');
    console.log('To apply these deletions, re-run with:');
    console.log('  node server/scripts/cleanupDemoData.js --apply\n');
  } else {
    console.log(`\n[APPLY NOTICE] Successfully deleted ${totalDemoIdentified} confirmed demo records.`);
    console.log('Real operational users, records, and cargo balances remain intact.\n');
  }

  if (shouldDisconnect) {
    await db.disconnect();
  }

  return {
    identifiedCount: totalDemoIdentified,
    deletedCount: isApplyMode ? totalDemoIdentified : 0,
    preservedCount: totalRealPreserved,
    ambiguousCount: totalAmbiguous,
    auditReport
  };
}

if (require.main === module) {
  auditAndCleanupDemoData().catch(err => {
    console.error('Unexpected error during cleanup:', err);
    process.exit(1);
  });
}

module.exports = {
  cleanup: auditAndCleanupDemoData,
  auditAndCleanupDemoData
};
