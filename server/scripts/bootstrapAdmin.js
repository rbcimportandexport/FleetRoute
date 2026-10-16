#!/usr/bin/env node
// server/scripts/bootstrapAdmin.js
// One-Time Administrator Bootstrap Command for FleetRoute
// STRICTLY ZERO EMOJIS. ZERO HARDCODED PASSWORDS. ZERO PASSWORD PRINTING.

require('dotenv').config();
const readline = require('readline');
const db = require('../db');
const { hashPassword } = require('../auth');

const isStrongPassword = value => typeof value === 'string' && value.length >= 12 && value.length <= 128 &&
  /[a-z]/.test(value) && /[A-Z]/.test(value) && /\d/.test(value) && /[^A-Za-z0-9]/.test(value);

function prompt(query, hideInput = false) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    if (hideInput) {
      process.stdout.write(query);
      let input = '';
      process.stdin.setRawMode(true);
      process.stdin.resume();
      process.stdin.setEncoding('utf8');

      const onData = (char) => {
        if (char === '\n' || char === '\r' || char === '\u0004') {
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdin.removeListener('data', onData);
          rl.close();
          console.log();
          resolve(input.trim());
        } else if (char === '\u0003') {
          // Ctrl+C
          process.exit(1);
        } else if (char === '\u0008' || char === '\x7f') {
          // Backspace
          if (input.length > 0) {
            input = input.slice(0, -1);
            process.stdout.write('\b \b');
          }
        } else {
          input += char;
          process.stdout.write('*');
        }
      };

      process.stdin.on('data', onData);
    } else {
      rl.question(query, (ans) => {
        rl.close();
        resolve(ans.trim());
      });
    }
  });
}

function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--email' && args[i + 1]) parsed.email = args[++i];
    if (args[i] === '--password' && args[i + 1]) parsed.password = args[++i];
    if (args[i] === '--name' && args[i + 1]) parsed.name = args[++i];
    if (args[i] === '--phone' && args[i + 1]) parsed.phone = args[++i];
  }
  return parsed;
}

async function bootstrapAdmin(options = {}) {
  if (!db.isConnected()) {
    await db.connect();
  }

  // Check if an administrator already exists
  const existingAdmin = await db.collection('users').findOne({ role: 'admin' });
  if (existingAdmin) {
    return {
      success: false,
      error: `An active administrator account already exists (${existingAdmin.email}).`,
      existingAdmin
    };
  }

  const { email, password, name = 'System Administrator', phone = '' } = options;
  if (!email || !email.includes('@')) {
    throw new Error('A valid administrator email address is required.');
  }
  if (!isStrongPassword(password)) {
    throw new Error('Password must be 12-128 characters and include uppercase, lowercase, number, and symbol.');
  }

  const passwordHash = await hashPassword(password);
  const adminDoc = {
    id: `USR-ADMIN-${Date.now()}`,
    email: email.trim().toLowerCase(),
    phone: phone ? phone.trim() : '',
    name: name.trim(),
    role: 'admin',
    status: 'active',
    passwordHash,
    isDemo: false,
    createdAt: new Date().toISOString()
  };

  const created = await db.collection('users').insertOne(adminDoc);
  return {
    success: true,
    user: created
  };
}

async function bootstrap() {
  console.log('================================================================');
  console.log('FleetRoute - Initial Administrator Account Bootstrap');
  console.log('================================================================');

  try {
    await db.connect();
  } catch (err) {
    console.error('[FleetRoute Bootstrap ERROR] Unable to connect to MongoDB:', err.message);
    process.exit(1);
  }

  const existingAdmin = await db.collection('users').findOne({ role: 'admin' });
  if (existingAdmin) {
    console.warn(`[FleetRoute Bootstrap NOTICE] An active administrator account already exists (${existingAdmin.email}).`);
    console.warn('Bootstrap command cannot overwrite existing administrators.');
    await db.disconnect();
    process.exit(1);
  }

  const cliArgs = parseArgs();
  let email = cliArgs.email || process.env.ADMIN_EMAIL;
  let password = cliArgs.password || process.env.ADMIN_PASSWORD;
  let name = cliArgs.name || process.env.ADMIN_NAME;
  let phone = cliArgs.phone || process.env.ADMIN_PHONE;

  if (!email) {
    email = await prompt('Enter Administrator Email: ');
  }
  if (!name) {
    name = await prompt('Enter Administrator Full Name (e.g. Operations Director): ') || 'System Administrator';
  }
  if (!phone) {
    phone = await prompt('Enter Contact Phone Number (optional): ');
  }
  if (!password) {
    password = await prompt('Enter Secure Administrator Password (12+ chars, upper/lower/number/symbol): ', true);
  }

  try {
    const result = await bootstrapAdmin({ email, password, name, phone });
    if (!result.success) {
      console.warn(`[FleetRoute Bootstrap NOTICE] ${result.error}`);
      process.exit(1);
    }
    console.log('[FleetRoute Bootstrap SUCCESS] Initial administrator account created successfully.');
    console.log(`- User ID: ${result.user.id}`);
    console.log(`- Email:   ${result.user.email}`);
    console.log(`- Role:    ${result.user.role}`);
    console.log('- Status:  Active');
    console.log('You may now start the FleetRoute server and sign in with these credentials.');
  } catch (err) {
    console.error('[FleetRoute Bootstrap ERROR] Failed to create administrator account:', err.message);
    process.exit(1);
  } finally {
    await db.disconnect();
  }
}

if (require.main === module) {
  bootstrap().catch(err => {
    console.error('Unexpected error during bootstrap:', err);
    process.exit(1);
  });
}

module.exports = { bootstrap, bootstrapAdmin };
