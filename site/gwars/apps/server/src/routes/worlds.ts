import {
  STARTING_LEVELS,
  nationNameError,
  settlementPoints,
  type PlayerInfo,
  type WorldMeResponse,
  type WorldStatus,
  type WorldSummary,
} from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import { gridDisk } from 'h3-js';
import { z } from 'zod';
import { optionalAuth, requireAuth } from '../auth';
import { worldFrom, type AppContext } from '../context';
import { exec, isDuplicateKey, one, pool, rows, tx } from '../db';
import { GameError } from '../errors';

const JoinBody = z.object({ nation: z.string().trim() });

export function registerWorldRoutes(app: FastifyInstance, ctx: AppContext): void {
  /** Worlds to choose from, with the caller's nation in each (when logged in). */
  app.get('/api/worlds', { preHandler: optionalAuth }, async (req): Promise<WorldSummary[]> => {
    const stats = await rows<{ id: number; status: WorldStatus; players: number }>(
      pool,
      `SELECT w.id, w.status, COUNT(wp.account_id) AS players
       FROM worlds w LEFT JOIN world_players wp ON wp.world_id = w.id
       GROUP BY w.id, w.status`,
    );
    const mine = req.account
      ? await rows<{ world_id: number; nation: string; points: number }>(
          pool,
          'SELECT world_id, nation, points FROM world_players WHERE account_id = ?',
          [req.account.id],
        )
      : [];
    return [...ctx.worlds.values()].map(({ info }) => {
      const s = stats.find((x) => x.id === info.id);
      const you = mine.find((m) => m.world_id === info.id);
      return {
        ...info,
        status: s?.status ?? 'open',
        players: s?.players ?? 0,
        you: you ? { nation: you.nation, points: you.points } : null,
      };
    });
  });

  app.get('/api/w/:worldId/me', { preHandler: requireAuth }, async (req): Promise<WorldMeResponse> => {
    const { info } = worldFrom(ctx, req.params);
    const player = await one<PlayerInfo>(pool, 'SELECT nation, points FROM world_players WHERE world_id = ? AND account_id = ?', [
      info.id,
      req.account!.id,
    ]);
    return { world: info, player: player ?? null, serverTime: Date.now() };
  });

  /** Founds the player's nation in a world: a starting settlement on a free hex, away from other players. */
  app.post('/api/w/:worldId/join', { preHandler: requireAuth }, async (req) => {
    const { info } = worldFrom(ctx, req.params);
    const account = req.account!;
    const { nation } = JoinBody.parse(req.body);
    const invalid = nationNameError(nation);
    if (invalid) throw new GameError(invalid);

    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const spawned = await tx(async (c) => {
          const joined = await one(c, 'SELECT 1 FROM world_players WHERE world_id = ? AND account_id = ?', [info.id, account.id]);
          if (joined) throw new GameError('You already play in this world', 409);

          const free = await rows<{ h3: string; idx: number; name: string }>(
            c,
            `SELECT h.h3, h.idx, h.name FROM hexes h
             LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3
             WHERE h.world_id = ? AND s.id IS NULL`,
            [info.id],
          );
          if (free.length === 0) throw new GameError('This world is full', 409);

          const taken = new Set((await rows<{ h3: string }>(c, 'SELECT h3 FROM settlements WHERE world_id = ?', [info.id])).map((r) => r.h3));
          const isolated = free.filter((h) => gridDisk(h.h3, 1).every((n) => !taken.has(n)));
          const candidates = isolated.length > 0 ? isolated : free;
          const hex = candidates[Math.floor(Math.random() * candidates.length)];

          const now = Date.now();
          const start = info.settings.startingResources;
          const points = settlementPoints(STARTING_LEVELS);
          await exec(c, 'INSERT INTO world_players (world_id, account_id, nation, points) VALUES (?, ?, ?, ?)', [
            info.id,
            account.id,
            nation,
            points,
          ]);
          const result = await exec(
            c,
            `INSERT INTO settlements (world_id, h3, owner_id, name, buildings, food, steel, oil, resources_at, points)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [info.id, hex.h3, account.id, hex.name, JSON.stringify(STARTING_LEVELS), start.food, start.steel, start.oil, now, points],
          );
          return { id: result.insertId, idx: hex.idx, points };
        });

        ctx.realtime.broadcast(info.id, { t: 'map', row: [spawned.idx, spawned.id, account.id, spawned.points], ownerName: nation });
        return { settlementId: spawned.id };
      } catch (err) {
        if (isDuplicateKey(err)) {
          if (String((err as Error).message).includes('uq_wp_nation')) {
            throw new GameError('This nation name is already taken in this world', 409);
          }
          // Someone grabbed the same hex at the same moment; pick again.
          if (attempt < 2) continue;
        }
        throw err;
      }
    }
    throw new GameError('Could not find a free hex, try again', 503);
  });
}
