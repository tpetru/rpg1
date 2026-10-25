import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { config } from './config';
import { exec, one, pool } from './db';
import { GameError } from './errors';

export const SESSION_COOKIE = 'gw_session';
const SESSION_TTL_MS = 30 * 24 * 3600 * 1000;
const KEY_LEN = 64;

declare module 'fastify' {
  interface FastifyRequest {
    account?: { id: number; username: string };
  }
}

function scryptKey(password: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(password, salt, KEY_LEN, { N: 16384, r: 8, p: 1 }, (err, key) => (err ? reject(err) : resolve(key))),
  );
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await scryptKey(password, salt);
  return `scrypt$${salt.toString('base64')}$${key.toString('base64')}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [alg, salt, key] = stored.split('$');
  if (alg !== 'scrypt' || !salt || !key) return false;
  const expected = Buffer.from(key, 'base64');
  const actual = await scryptKey(password, Buffer.from(salt, 'base64'));
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

export async function startSession(reply: FastifyReply, accountId: number): Promise<void> {
  const token = randomBytes(32).toString('base64url');
  const expiresAt = Date.now() + SESSION_TTL_MS;
  await exec(pool, 'INSERT INTO sessions (token_hash, account_id, expires_at) VALUES (?, ?, ?)', [sha256(token), accountId, expiresAt]);
  reply.setCookie(SESSION_COOKIE, token, {
    path: '/',
    httpOnly: true,
    sameSite: 'lax',
    secure: config.cookieSecure,
    maxAge: SESSION_TTL_MS / 1000,
  });
}

export async function endSession(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const token = request.cookies[SESSION_COOKIE];
  if (token) await exec(pool, 'DELETE FROM sessions WHERE token_hash = ?', [sha256(token)]);
  reply.clearCookie(SESSION_COOKIE, { path: '/' });
}

/** preHandler: rejects the request unless it carries a valid session cookie. */
export async function requireAuth(request: FastifyRequest): Promise<void> {
  const token = request.cookies[SESSION_COOKIE];
  if (!token) throw new GameError('Not logged in', 401);
  const account = await one<{ id: number; username: string }>(
    pool,
    `SELECT a.id, a.username FROM sessions s JOIN accounts a ON a.id = s.account_id
     WHERE s.token_hash = ? AND s.expires_at > ?`,
    [sha256(token), Date.now()],
  );
  if (!account) throw new GameError('Session expired', 401);
  request.account = account;
}
