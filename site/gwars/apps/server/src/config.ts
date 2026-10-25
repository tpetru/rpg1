import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { config as loadEnv } from 'dotenv';

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
loadEnv({ path: path.join(REPO_ROOT, '.env'), quiet: true });

function env(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined) throw new Error(`Missing env var ${name} (copy .env.example to .env)`);
  return value;
}

export const config = {
  port: Number(env('PORT', '3000')),
  worldId: Number(env('WORLD_ID', '1')),
  cookieSecure: env('COOKIE_SECURE', 'false') === 'true',
  db: {
    host: env('DB_HOST', '127.0.0.1'),
    port: Number(env('DB_PORT', '3306')),
    user: env('DB_USER'),
    password: env('DB_PASSWORD', ''),
    database: env('DB_NAME', 'geowars'),
  },
};
