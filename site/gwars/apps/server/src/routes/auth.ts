import type { MeResponse } from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { endSession, hashPassword, requireAuth, startSession, verifyPassword } from '../auth';
import type { AppContext } from '../context';
import { exec, isDuplicateKey, one, pool } from '../db';
import { GameError } from '../errors';

const RegisterBody = z.object({
  username: z.string().regex(/^[A-Za-z0-9_]{3,24}$/, 'Username: 3-24 letters, digits or _'),
  email: z.email().max(190),
  password: z.string().min(8, 'Password must have at least 8 characters').max(200),
});

const LoginBody = z.object({
  login: z.string().min(1).max(190),
  password: z.string().min(1).max(200),
});

export function registerAuthRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post('/api/auth/register', async (req, reply) => {
    const body = RegisterBody.parse(req.body);
    let id: number;
    try {
      const result = await exec(pool, 'INSERT INTO accounts (username, email, password_hash) VALUES (?, ?, ?)', [
        body.username,
        body.email.toLowerCase(),
        await hashPassword(body.password),
      ]);
      id = result.insertId;
    } catch (err) {
      if (isDuplicateKey(err)) throw new GameError('Username or email already in use', 409);
      throw err;
    }
    await startSession(reply, id);
    return { ok: true };
  });

  app.post('/api/auth/login', async (req, reply) => {
    const body = LoginBody.parse(req.body);
    const account = await one<{ id: number; password_hash: string }>(
      pool,
      'SELECT id, password_hash FROM accounts WHERE username = ? OR email = ?',
      [body.login, body.login.toLowerCase()],
    );
    if (!account || !(await verifyPassword(body.password, account.password_hash))) {
      throw new GameError('Wrong username or password', 401);
    }
    await startSession(reply, account.id);
    return { ok: true };
  });

  app.post('/api/auth/logout', async (req, reply) => {
    await endSession(req, reply);
    return { ok: true };
  });

  app.get('/api/auth/me', { preHandler: requireAuth }, async (req): Promise<MeResponse> => {
    const account = req.account!;
    const player = await one<{ nationality: string; points: number }>(
      pool,
      'SELECT nationality, points FROM world_players WHERE world_id = ? AND account_id = ?',
      [ctx.world.id, account.id],
    );
    return { account, world: ctx.world, player: player ?? null, serverTime: Date.now() };
  });
}
