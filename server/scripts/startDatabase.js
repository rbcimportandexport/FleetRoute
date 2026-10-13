// server/scripts/startDatabase.js
// Runs a persistent local MongoDB daemon on standard port 27017
const path = require('path');
const fs = require('fs');
const { MongoMemoryServer } = require('mongodb-memory-server');

async function start() {
  const dbDir = path.join(__dirname, '../.data/db');
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  console.log('Starting persistent local MongoDB service on port 27017...');
  const mongod = await MongoMemoryServer.create({
    instance: {
      port: 27017,
      dbName: 'fleetroute',
      dbPath: dbDir,
      storageEngine: 'wiredTiger'
    }
  });

  const uri = mongod.getUri();
  console.log(`[MongoDB Engine] Active and listening at: ${uri}`);
  console.log(`[MongoDB Engine] Persistent data directory: ${dbDir}`);

  process.on('SIGINT', async () => {
    console.log('\nStopping MongoDB service...');
    await mongod.stop();
    process.exit(0);
  });
}

start().catch(err => {
  console.error('[MongoDB Startup Error]', err);
  process.exit(1);
});
