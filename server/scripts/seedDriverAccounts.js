// server/scripts/seedDriverAccounts.js
// Provisions login accounts for all 8 drivers in MongoDB
// STRICTLY ZERO EMOJIS.

const db = require('../db');
const { hashPassword } = require('../auth');

async function seedDriverAccounts() {
  await db.connect();
  console.log('[FleetRoute Seed] Connected to database');

  const drivers = await db.collection('drivers').find();
  const existingUsers = await db.collection('users').find();
  console.log(`[FleetRoute Seed] Found ${drivers.length} drivers, ${existingUsers.length} existing users`);

  let added = 0;
  for (const drv of drivers) {
    const hasAccount = existingUsers.some(u => u.driverId === drv.id || (u.phone && drv.phone && u.phone === drv.phone));
    if (!hasAccount) {
      const nameClean = drv.name.toLowerCase().replace(/[^a-z0-9]/g, '');
      const email = `${nameClean}.${drv.id.toLowerCase()}@fleetroute.com`;
      const defaultPassword = 'Driver1234!';
      const passwordHash = await hashPassword(defaultPassword);

      await db.collection('users').insertOne({
        email,
        phone: drv.phone || '',
        name: drv.name,
        role: 'driver',
        driverId: drv.id,
        status: 'active',
        passwordHash,
        isDemo: false
      });
      console.log(`[FleetRoute Seed] Created user for ${drv.name} (${drv.id}) -> ${email}`);
      added++;
    } else {
      console.log(`[FleetRoute Seed] Driver ${drv.name} already has an account.`);
    }
  }

  console.log(`[FleetRoute Seed] Successfully added ${added} driver user accounts.`);
  await db.disconnect();
}

seedDriverAccounts().catch(err => {
  console.error('[FleetRoute Seed ERROR]', err);
  process.exit(1);
});
