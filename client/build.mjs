import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';

if (!existsSync('public/index.html')) {
  throw new Error('Flutter web bundle is missing from client/public.');
}

rmSync('dist', { recursive: true, force: true });
mkdirSync('dist', { recursive: true });
cpSync('public', 'dist', { recursive: true });
console.log('Flutter web bundle copied to dist.');
