import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import {
  BUILDINGS,
  STARTING_LEVELS,
  isBuildingId,
  normalizeLevels,
  settlementPoints,
  mapBag,
  type AdminPlayerDto,
  type AdminSettlementDto,
  type AdminWorldDto,
} from '@geowars/rules';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { config } from '../config';
import { worldFrom, type AppContext } from '../context';
import { exec, isDuplicateKey, pool, rows, tx, type Db } from '../db';
import { GameError } from '../errors';
import { loadQueue, loadSettlement, refreshPlayerPoints, saveSettlement, stockAt, storageCap } from '../game/settlements';

const ADMIN_COOKIE = 'gw_admin';
const SESSION_MS = 8 * 3600 * 1000;
const MAX_FAILURES = 5;
const LOCKOUT_MS = 15 * 60 * 1000;

const sha256 = (s: string) => createHash('sha256').update(s).digest();

/** Constant-time comparison, so response timing reveals nothing about the password. */
function passwordMatches(given: string): boolean {
  return timingSafeEqual(sha256(given), sha256(config.adminPassword));
}

// Admin sessions live in memory: restarting the server logs the admin out, which is acceptable.
const sessions = new Map<string, number>();
const failures = new Map<string, { count: number; resetAt: number }>();

function isAdmin(request: FastifyRequest): boolean {
  const token = request.cookies[ADMIN_COOKIE];
  if (!token) return false;
  const key = sha256(token).toString('hex');
  const expires = sessions.get(key);
  if (!expires || expires < Date.now()) {
    sessions.delete(key);
    return false;
  }
  return true;
}

async function requireAdmin(request: FastifyRequest): Promise<void> {
  if (!config.adminPassword) throw new GameError('The admin page is not enabled', 404, 'admin_disabled');
  if (!isAdmin(request)) throw new GameError('Admin login required', 401, 'admin_required');
}

async function logAdmin(db: Db, worldId: number, settlementId: number, action: string, details: unknown, ip: string): Promise<void> {
  await exec(db, 'INSERT INTO admin_log (at, world_id, settlement_id, action, details, ip) VALUES (?, ?, ?, ?, ?, ?)', [
    Date.now(),
    worldId,
    settlementId,
    action,
    JSON.stringify(details),
    ip,
  ]);
}

const LoginBody = z.object({ password: z.string().max(200) });
const ListQuery = z.object({ q: z.string().trim().max(60).optional() });
const IdParams = z.object({ id: z.coerce.number().int().positive() });
const OwnerBody = z.object({ accountId: z.number().int().positive().nullable() });
const BuildingBody = z.object({ building: z.string().refine(isBuildingId, 'Unknown building'), level: z.number().int().min(0).max(100) });

interface SettlementRow {
  id: number;
  idx: number;
  name: string;
  custom_name: string | null;
  country_code: string;
  owner_id: number | null;
  username: string | null;
  nation: string | null;
  points: number;
  buildings: string;
}

export function registerAdminRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.post('/api/admin/login', async (req, reply) => {
    if (!config.adminPassword) throw new GameError('The admin page is not enabled', 404, 'admin_disabled');
    const now = Date.now();
    const record = failures.get(req.ip);
    if (record && record.resetAt > now && record.count >= MAX_FAILURES) {
      throw new GameError('Too many wrong passwords. Try again later.', 429, 'admin_rate_limited', {
        minutes: Math.ceil((record.resetAt - now) / 60000),
      });
    }

    const { password } = LoginBody.parse(req.body);
    if (!passwordMatches(password)) {
      const fresh = record && record.resetAt > now ? record : { count: 0, resetAt: now + LOCKOUT_MS };
      fresh.count++;
      failures.set(req.ip, fresh);
      req.log.warn({ ip: req.ip }, 'admin login failed');
      throw new GameError('Wrong admin password', 401, 'admin_wrong_password');
    }

    failures.delete(req.ip);
    const token = randomBytes(32).toString('base64url');
    sessions.set(sha256(token).toString('hex'), now + SESSION_MS);
    reply.setCookie(ADMIN_COOKIE, token, {
      path: '/api/admin',
      httpOnly: true,
      sameSite: 'strict',
      secure: config.cookieSecure,
      maxAge: SESSION_MS / 1000,
    });
    req.log.info({ ip: req.ip }, 'admin login');
    return { ok: true };
  });

  app.post('/api/admin/logout', async (req, reply) => {
    const token = req.cookies[ADMIN_COOKIE];
    if (token) sessions.delete(sha256(token).toString('hex'));
    reply.clearCookie(ADMIN_COOKIE, { path: '/api/admin' });
    return { ok: true };
  });

  /** Lets the page know whether to show the login form or the tools. */
  app.get('/api/admin/me', async (req) => ({ enabled: !!config.adminPassword, loggedIn: !!config.adminPassword && isAdmin(req) }));

  app.get('/api/admin/worlds', { preHandler: requireAdmin }, async (): Promise<AdminWorldDto[]> =>
    [...ctx.worlds.values()].map(({ info }) => ({ id: info.id, number: info.number, name: info.name })),
  );

  app.get('/api/admin/w/:worldId/players', { preHandler: requireAdmin }, async (req): Promise<AdminPlayerDto[]> => {
    const { info } = worldFrom(ctx, req.params);
    return rows<AdminPlayerDto>(
      pool,
      `SELECT wp.account_id AS accountId, a.username, wp.nation, wp.points
       FROM world_players wp JOIN accounts a ON a.id = wp.account_id
       WHERE wp.world_id = ? ORDER BY wp.nation`,
      [info.id],
    );
  });

  app.get('/api/admin/w/:worldId/settlements', { preHandler: requireAdmin }, async (req): Promise<AdminSettlementDto[]> => {
    const { info } = worldFrom(ctx, req.params);
    const { q } = ListQuery.parse(req.query);
    const like = q ? `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%` : null;
    const list = await rows<SettlementRow>(
      pool,
      `SELECT s.id, h.idx, h.name, s.custom_name, h.country_code, s.owner_id, a.username, wp.nation, s.points, s.buildings
       FROM settlements s
       JOIN hexes h ON h.world_id = s.world_id AND h.h3 = s.h3
       LEFT JOIN accounts a ON a.id = s.owner_id
       LEFT JOIN world_players wp ON wp.world_id = s.world_id AND wp.account_id = s.owner_id
       WHERE s.world_id = ?
         ${like ? 'AND (s.custom_name LIKE ? OR h.name LIKE ? OR wp.nation LIKE ? OR a.username LIKE ?)' : ''}
       ORDER BY wp.nation IS NULL, wp.nation, s.id
       LIMIT 300`,
      like ? [info.id, like, like, like, like] : [info.id],
    );
    return list.map((r) => ({
      id: r.id,
      idx: r.idx,
      name: r.name,
      customName: r.custom_name,
      countryCode: r.country_code,
      ownerId: r.owner_id,
      ownerUsername: r.username,
      ownerNation: r.nation,
      points: r.points,
      levels: normalizeLevels(JSON.parse(r.buildings)),
    }));
  });

  /** Gives a settlement to another player of the same world, or sets it free (independent). */
  app.patch('/api/admin/w/:worldId/settlements/:id/owner', { preHandler: requireAdmin }, async (req): Promise<{ ok: true }> => {
    const { info } = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const { accountId } = OwnerBody.parse(req.body);

    const result = await tx(async (c) => {
      const s = await loadSettlement(c, id, true);
      if (!s || s.worldId !== info.id) throw new GameError('Settlement not found', 404, 'settlement_not_found');

      let nation: string | null = null;
      if (accountId !== null) {
        const player = await rows<{ nation: string }>(c, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [info.id, accountId]);
        if (player.length === 0) throw new GameError('That account does not play in this world', 400, 'admin_not_a_player');
        nation = player[0].nation;
      }

      const previous = s.ownerId;
      await exec(c, 'UPDATE settlements SET owner_id = ? WHERE id = ?', [accountId, s.id]);
      for (const owner of new Set([previous, accountId])) if (owner) await refreshPlayerPoints(c, info.id, owner);
      await logAdmin(c, info.id, s.id, 'set_owner', { from: previous, to: accountId }, req.ip);
      return { s, previous, nation };
    });

    // Tell everyone watching the map, and both players so their lists refresh.
    ctx.realtime.broadcast(info.id, { t: 'map', row: [result.s.idx, result.s.id, accountId ?? 0, result.s.points], ownerName: result.nation });
    for (const owner of new Set([result.previous, accountId])) if (owner) ctx.realtime.sendTo(info.id, owner, { t: 'settlement', id: result.s.id });
    return { ok: true };
  });

  /**
   * Sets one building to any level from 0 to its maximum, ignoring requirements and housing.
   * Queued upgrades of that building are removed (and refunded), since their target level no longer fits.
   */
  app.patch('/api/admin/w/:worldId/settlements/:id/building', { preHandler: requireAdmin }, async (req): Promise<AdminSettlementDto['levels']> => {
    const { info } = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const body = BuildingBody.parse(req.body);
    const building = body.building as keyof typeof BUILDINGS;
    const def = BUILDINGS[building];
    if (body.level > def.maxLevel) {
      throw new GameError(`${def.name} cannot go above level ${def.maxLevel}`, 400, 'admin_invalid_level', { max: def.maxLevel });
    }

    const result = await tx(async (c) => {
      const s = await loadSettlement(c, id, true);
      if (!s || s.worldId !== info.id) throw new GameError('Settlement not found', 404, 'settlement_not_found');

      const now = Date.now();
      // Production up to now uses the old levels; from now on, the new ones.
      s.stock = stockAt(s, now, info.settings);
      s.resourcesAt = now;

      const queue = (await loadQueue(c, s.id)).filter((q) => q.building === building);
      if (queue.length > 0) {
        const cap = storageCap(s);
        s.stock = mapBag((r) => Math.max(s.stock[r], Math.min(cap, s.stock[r] + queue.reduce((sum, q) => sum + q.cost[r], 0))));
        await exec(c, 'DELETE FROM build_queue WHERE id IN (?)', [queue.map((q) => q.id)]);
        await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'BUILD_COMPLETE' AND ref_id IN (?) AND status = 'pending'`, [
          now,
          queue.map((q) => q.id),
        ]);
      }

      const before = s.levels[building];
      s.levels = { ...s.levels, [building]: body.level };
      s.points = settlementPoints(s.levels);
      await saveSettlement(c, s);
      if (s.ownerId) await refreshPlayerPoints(c, info.id, s.ownerId);
      await logAdmin(c, info.id, s.id, 'set_building', { building, from: before, to: body.level, removedQueued: queue.length }, req.ip);
      return s;
    });

    ctx.realtime.broadcast(info.id, { t: 'map', row: [result.idx, result.id, result.ownerId ?? 0, result.points], ownerName: null });
    if (result.ownerId) ctx.realtime.sendTo(info.id, result.ownerId, { t: 'settlement', id: result.id });
    return result.levels;
  });

  /**
   * Claims an unclaimed hex: creates a starter settlement there (same as a new player's first one)
   * and gives it to a player of this world. A player may own any number of settlements.
   */
  app.post('/api/admin/w/:worldId/hexes/:idx/claim', { preHandler: requireAdmin }, async (req): Promise<{ settlementId: number }> => {
    const { info } = worldFrom(ctx, req.params);
    const { idx } = z.object({ idx: z.coerce.number().int().nonnegative() }).parse(req.params);
    const { accountId } = z.object({ accountId: z.number().int().positive() }).parse(req.body);

    let created: { id: number; nation: string; points: number };
    try {
      created = await tx(async (c) => {
        const hex = (await rows<{ h3: string; name: string }>(c, 'SELECT h3, name FROM hexes WHERE world_id = ? AND idx = ? FOR UPDATE', [info.id, idx]))[0];
        if (!hex) throw new GameError('Hex not found', 404, 'admin_hex_not_found');

        const player = (await rows<{ nation: string }>(c, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [info.id, accountId]))[0];
        if (!player) throw new GameError('That account does not play in this world', 400, 'admin_not_a_player');

        const taken = await rows<{ id: number }>(c, 'SELECT id FROM settlements WHERE world_id = ? AND h3 = ?', [info.id, hex.h3]);
        if (taken.length > 0) throw new GameError('This hex already has a settlement', 409, 'admin_hex_taken');

        const start = info.settings.startingResources;
        const points = settlementPoints(STARTING_LEVELS);
        const result = await exec(
          c,
          `INSERT INTO settlements (world_id, h3, owner_id, name, buildings, food, steel, oil, resources_at, points)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [info.id, hex.h3, accountId, hex.name, JSON.stringify(STARTING_LEVELS), start.food, start.steel, start.oil, Date.now(), points],
        );
        await refreshPlayerPoints(c, info.id, accountId);
        await logAdmin(c, info.id, result.insertId, 'claim_hex', { idx, h3: hex.h3, name: hex.name, owner: accountId }, req.ip);
        return { id: result.insertId, nation: player.nation, points };
      });
    } catch (err) {
      // Two admins (or an admin and a spawning player) took the same hex at once.
      if (isDuplicateKey(err)) throw new GameError('This hex already has a settlement', 409, 'admin_hex_taken');
      throw err;
    }

    ctx.realtime.broadcast(info.id, { t: 'map', row: [idx, created.id, accountId, created.points], ownerName: created.nation });
    ctx.realtime.sendTo(info.id, accountId, { t: 'settlement', id: created.id });
    return { settlementId: created.id };
  });
}
