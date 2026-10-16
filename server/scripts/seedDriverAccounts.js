// server/scripts/seedDriverAccounts.js
// Provisions login accounts for all 8 drivers in MongoDB
// STRICTLY ZERO EMOJIS.

const db = require('../db');
const { hashPassword } = require('../auth');
const crypto = require('crypto');

async function seedDriverAccounts() {
  await db.connect();
  console.log('[FleetRoute Seed] Connected to database');

  const drivers = await db.collection('drivers').find();
  const existingUsers = await db.collection('users').find();
  console.log(`[FleetRoute Seed] Found ${drivers.length} drivers, ${existingUsers.length} existing users`);

  let added = 0;
  const createdCredentials = [];
  for (const drv of drivers) {
    const hasAccount = existingUsers.some(u => u.driverId === drv.id || (u.phone && drv.phone && u.phone === drv.phone));
    if (!hasAccount) {
      const nameClean = drv.name.toLowerCase().replace(/[^a-z0-9]/g, '');
      const email = `${nameClean}.${drv.id.toLowerCase()}@fleetroute.com`;
      const temporaryPassword = `${crypto.randomBytes(18).toString('base64url')}!aA1`;
      const passwordHash = await hashPassword(temporaryPassword);

      await db.collection('users').insertOne({
        email,
        phone: drv.phone || '',
        name: drv.name,
        role: 'driver',
        driverId: drv.id,
        status: 'active',
        mustChangePassword: true,
        passwordHash,
        isDemo: false
      });
      console.log(`[FleetRoute Seed] Created user for ${drv.name} (${drv.id}) -> ${email}`);
      createdCredentials.push({ email, temporaryPassword });
      added++;
    } else {
      console.log(`[FleetRoute Seed] Driver ${drv.name} already has an account.`);
    }
  }

  console.log(`[FleetRoute Seed] Successfully added ${added} driver user accounts.`);
  if (createdCredentials.length) {
    console.log('[FleetRoute Seed] One-time credentials (store securely; they will not be shown again):');
    for (const credential of createdCredentials) {
      console.log(`${credential.email} | ${credential.temporaryPassword}`);
    }
  }
  await db.disconnect();
}

seedDriverAccounts().catch(err => {
  console.error('[FleetRoute Seed ERROR]', err);
  process.exit(1);
});
