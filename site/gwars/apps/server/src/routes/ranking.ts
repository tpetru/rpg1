import type { RankingResponse, RankingRow, RankingType } from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../auth';
import { worldFrom, type AppContext } from '../context';
import { pool, rows } from '../db';

/** Players on one page of the ranking. */
const RANKING_PAGE_SIZE = 20;

const Query = z.object({
  type: z.enum(['points', 'cities', 'continent']).default('points'),
  continent: z.string().max(40).optional(),
  page: z.coerce.number().int().min(1).default(1),
});

interface PlayerRow {
  account_id: number;
  nation: string;
  points: number;
  cities: number;
  settlement?: string;
}

export function registerRankingRoutes(app: FastifyInstance, ctx: AppContext): void {
  /** The players of a world, best first: by points, by number of settlements, or by points on one continent. */
  app.get('/api/w/:worldId/ranking', { preHandler: requireAuth }, async (req): Promise<RankingResponse> => {
    const { info } = worldFrom(ctx, req.params);
    const q = Query.parse(req.query);
    const type: RankingType = q.type;

    const continents = (
      await rows<{ continent: string }>(
        pool,
        'SELECT DISTINCT c.continent FROM hexes h JOIN countries c ON c.code = h.country_code WHERE h.world_id = ? ORDER BY c.continent',
        [info.id],
      )
    ).map((r) => r.continent);
    const continent = type === 'continent' ? (q.continent && continents.includes(q.continent) ? q.continent : (continents[0] ?? null)) : null;

    let list: PlayerRow[];
    if (type === 'continent') {
      list = continent
        ? await rows<PlayerRow>(
            pool,
            `SELECT wp.account_id, wp.nation, SUM(s.points) AS points, COUNT(s.id) AS cities
             FROM settlements s
             JOIN world_players wp ON wp.world_id = s.world_id AND wp.account_id = s.owner_id
             JOIN hexes h ON h.world_id = s.world_id AND h.h3 = s.h3
             JOIN countries c ON c.code = h.country_code
             WHERE s.world_id = ? AND c.continent = ?
             GROUP BY wp.account_id, wp.nation
             ORDER BY points DESC, cities DESC, wp.nation`,
            [info.id, continent],
          )
        : [];
    } else if (type === 'cities') {
      // One row per settlement a player holds, best first.
      list = await rows<PlayerRow>(
        pool,
        `SELECT wp.account_id, wp.nation, s.points, 1 AS cities, COALESCE(s.custom_name, s.name) AS settlement
         FROM settlements s
         JOIN world_players wp ON wp.world_id = s.world_id AND wp.account_id = s.owner_id
         WHERE s.world_id = ?
         ORDER BY s.points DESC, s.id`,
        [info.id],
      );
    } else {
      list = await rows<PlayerRow>(
        pool,
        `SELECT wp.account_id, wp.nation, wp.points, COUNT(s.id) AS cities
         FROM world_players wp
         LEFT JOIN settlements s ON s.world_id = wp.world_id AND s.owner_id = wp.account_id
         WHERE wp.world_id = ?
         GROUP BY wp.account_id, wp.nation, wp.points
         ORDER BY wp.points DESC, cities DESC, wp.nation`,
        [info.id],
      );
    }

    const pages = Math.max(1, Math.ceil(list.length / RANKING_PAGE_SIZE));
    const page = Math.min(q.page, pages);
    const start = (page - 1) * RANKING_PAGE_SIZE;
    const slice: RankingRow[] = list.slice(start, start + RANKING_PAGE_SIZE).map((r, i) => ({
      rank: start + i + 1,
      accountId: Number(r.account_id),
      nation: r.nation,
      points: Number(r.points),
      cities: Number(r.cities),
      ...(type === 'cities' ? { settlement: r.settlement } : {}),
    }));
    return { type, continent, continents, page, pages, total: list.length, rows: slice };
  });
}
