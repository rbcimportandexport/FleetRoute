import { loadEnv } from 'vite';

const mode = process.argv[2] || 'development';
const env = loadEnv(mode, process.cwd(), 'VITE_');
const key = (env.VITE_GOOGLE_MAPS_API_KEY || '').trim();
const present = Boolean(key && !/your[_ -]?key|replace|example/i.test(key));
const enabled = env.VITE_MAP_PROVIDER === 'google'
  || (env.VITE_MAP_PROVIDER !== 'open' && present);

// Never print a key, a credential, or the full environment.
console.log(`Mode: ${mode}`);
console.log(`Provider: ${enabled ? 'Google Maps' : 'Open map (not Google)'}`);
console.log(`Google browser key: ${present ? 'present (value hidden)' : 'MISSING'}`);
console.log(`Map language: ${env.VITE_GOOGLE_MAPS_LANGUAGE || 'en'}`);
console.log(`Region: ${env.VITE_GOOGLE_MAPS_REGION || 'IN'}`);
console.log('Local check only. Billing, API activation and website restrictions must be verified in the browser / Google Cloud.');
if (!present || !enabled) process.exitCode = 1;
