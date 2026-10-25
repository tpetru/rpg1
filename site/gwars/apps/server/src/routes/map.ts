import type { HexRow, MapHexesResponse, MapSettlementsResponse } from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import type { AppContext } from '../context';
import { pool, rows } from '../db';

export function registerMapRoutes(app: FastifyInstance, ctx: AppContext): void {
  const worldId = ctx.world.id;
  // Hex data never changes during a world, so it is built once and served from memory.
  let hexesJson: string | null = null;

  app.get('/api/map/hexes', async (_req, reply) => {
    if (!hexesJson) {
      const hexes = await rows<{
        h3: string;
        country_code: string;
        name: string;
        food_mult: number;
        steel_mult: number;
        oil_mult: number;
        rare_mult: number;
        uranium_mult: number;
      }>(pool, 'SELECT h3, country_code, name, food_mult, steel_mult, oil_mult, rare_mult, uranium_mult FROM hexes WHERE world_id = ? ORDER BY idx', [
        worldId,
      ]);
      const countries = await rows<{ code: string; name: string }>(
        pool,
        'SELECT DISTINCT c.code, c.name FROM countries c JOIN hexes h ON h.country_code = c.code WHERE h.world_id = ?',
        [worldId],
      );
      const body: MapHexesResponse = {
        res: ctx.world.h3Res,
        countries: Object.fromEntries(countries.map((c) => [c.code, c.name])),
        hexes: hexes.map((h): HexRow => [h.h3, h.country_code, h.name, h.food_mult, h.steel_mult, h.oil_mult, h.rare_mult, h.uranium_mult]),
      };
      hexesJson = JSON.stringify(body);
    }
    reply.header('content-type', 'application/json').header('cache-control', 'public, max-age=3600');
    return hexesJson;
  });

  app.get('/api/map/settlements', async (): Promise<MapSettlementsResponse> => {
    const list = await rows<{ idx: number; id: number; owner_id: number | null; points: number; username: string | null }>(
      pool,
      `SELECT h.idx, s.id, s.owner_id, s.points, a.username
       FROM settlements s
       JOIN hexes h ON h.world_id = s.world_id AND h.h3 = s.h3
       LEFT JOIN accounts a ON a.id = s.owner_id
       WHERE s.world_id = ?`,
      [worldId],
    );
    const players: Record<number, string> = {};
    for (const s of list) if (s.owner_id && s.username) players[s.owner_id] = s.username;
    return { settlements: list.map((s) => [s.idx, s.id, s.owner_id ?? 0, s.points]), players };
  });
}
