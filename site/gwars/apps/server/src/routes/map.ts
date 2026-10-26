import type { HexRow, MapHexesResponse, MapSettlementsResponse } from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import { worldFrom, type AppContext } from '../context';
import { pool, rows } from '../db';

export function registerMapRoutes(app: FastifyInstance, ctx: AppContext): void {
  // Hex data never changes during a world, so each world's list is built once and served from memory.
  const hexesJson = new Map<number, string>();

  app.get('/api/w/:worldId/map/hexes', async (req, reply) => {
    const { info } = worldFrom(ctx, req.params);
    let body = hexesJson.get(info.id);
    if (!body) {
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
        info.id,
      ]);
      const countries = await rows<{ code: string; name: string }>(
        pool,
        'SELECT DISTINCT c.code, c.name FROM countries c JOIN hexes h ON h.country_code = c.code WHERE h.world_id = ?',
        [info.id],
      );
      const response: MapHexesResponse = {
        res: info.h3Res,
        countries: Object.fromEntries(countries.map((c) => [c.code, c.name])),
        hexes: hexes.map((h): HexRow => [h.h3, h.country_code, h.name, h.food_mult, h.steel_mult, h.oil_mult, h.rare_mult, h.uranium_mult]),
      };
      body = JSON.stringify(response);
      hexesJson.set(info.id, body);
    }
    reply.header('content-type', 'application/json').header('cache-control', 'public, max-age=3600');
    return body;
  });

  app.get('/api/w/:worldId/map/settlements', async (req): Promise<MapSettlementsResponse> => {
    const { info } = worldFrom(ctx, req.params);
    const list = await rows<{ idx: number; id: number; owner_id: number | null; points: number; nation: string | null }>(
      pool,
      `SELECT h.idx, s.id, s.owner_id, s.points, wp.nation
       FROM settlements s
       JOIN hexes h ON h.world_id = s.world_id AND h.h3 = s.h3
       LEFT JOIN world_players wp ON wp.world_id = s.world_id AND wp.account_id = s.owner_id
       WHERE s.world_id = ?`,
      [info.id],
    );
    const players: Record<number, string> = {};
    for (const s of list) if (s.owner_id && s.nation) players[s.owner_id] = s.nation;
    return { settlements: list.map((s) => [s.idx, s.id, s.owner_id ?? 0, s.points]), players };
  });
}
