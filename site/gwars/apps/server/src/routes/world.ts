import { STARTING_LEVELS, settlementPoints, type CountryInfo } from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import { gridDisk } from 'h3-js';
import { z } from 'zod';
import { requireAuth } from '../auth';
import type { AppContext } from '../context';
import { exec, isDuplicateKey, one, pool, rows, tx } from '../db';
import { GameError } from '../errors';

const JoinBody = z.object({ country: z.string().length(3) });

export function registerWorldRoutes(app: FastifyInstance, ctx: AppContext): void {
  const worldId = ctx.world.id;

  app.get('/api/world/countries', async (): Promise<CountryInfo[]> => {
    return rows<CountryInfo>(
      pool,
      `SELECT c.code, c.name, c.continent,
              COUNT(*) AS hexes,
              CAST(SUM(s.id IS NULL) AS UNSIGNED) AS free,
              AVG(h.food_mult) AS food, AVG(h.steel_mult) AS steel, AVG(h.oil_mult) AS oil,
              AVG(h.rare_mult > 0) AS rareShare, AVG(h.uranium_mult > 0) AS uraniumShare
       FROM hexes h
       JOIN countries c ON c.code = h.country_code
       LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3
       WHERE h.world_id = ?
       GROUP BY c.code, c.name, c.continent
       ORDER BY c.name`,
      [worldId],
    );
  });

  /** Claims a starting settlement in the chosen country, away from other players when possible. */
  app.post('/api/world/join', { preHandler: requireAuth }, async (req) => {
    const account = req.account!;
    const { country } = JoinBody.parse(req.body);

    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const spawned = await tx(async (c) => {
          const joined = await one(c, 'SELECT 1 FROM world_players WHERE world_id = ? AND account_id = ?', [worldId, account.id]);
          if (joined) throw new GameError('You already play in this world', 409);

          const free = await rows<{ h3: string; idx: number; name: string }>(
            c,
            `SELECT h.h3, h.idx, h.name FROM hexes h
             LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3
             WHERE h.world_id = ? AND h.country_code = ? AND s.id IS NULL`,
            [worldId, country],
          );
          if (free.length === 0) throw new GameError('No free land left in this country. Pick another one.', 409);

          const taken = new Set((await rows<{ h3: string }>(c, 'SELECT h3 FROM settlements WHERE world_id = ?', [worldId])).map((r) => r.h3));
          const isolated = free.filter((h) => gridDisk(h.h3, 1).every((n) => !taken.has(n)));
          const candidates = isolated.length > 0 ? isolated : free;
          const hex = candidates[Math.floor(Math.random() * candidates.length)];

          const now = Date.now();
          const start = ctx.world.settings.startingResources;
          const points = settlementPoints(STARTING_LEVELS);
          await exec(c, 'INSERT INTO world_players (world_id, account_id, nationality, points) VALUES (?, ?, ?, ?)', [
            worldId,
            account.id,
            country,
            points,
          ]);
          const result = await exec(
            c,
            `INSERT INTO settlements (world_id, h3, owner_id, name, buildings, food, steel, oil, resources_at, points)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [worldId, hex.h3, account.id, hex.name, JSON.stringify(STARTING_LEVELS), start.food, start.steel, start.oil, now, points],
          );
          return { id: result.insertId, idx: hex.idx, points };
        });

        ctx.realtime.broadcast({ t: 'map', row: [spawned.idx, spawned.id, account.id, spawned.points], ownerName: account.username });
        return { settlementId: spawned.id };
      } catch (err) {
        // Someone grabbed the same hex at the same moment; pick again.
        if (isDuplicateKey(err) && attempt < 2) continue;
        throw err;
      }
    }
    throw new GameError('Could not find a free hex, try again', 503);
  });
}
