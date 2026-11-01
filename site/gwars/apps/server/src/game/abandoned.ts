import { STARTING_LEVELS, normalizeLevels, settlementPoints, type BuildingId, type BuildingLevels, type UnitCounts, zeroUnits } from '@geowars/rules';
import { gridDisk } from 'h3-js';
import type { PoolConnection } from 'mysql2/promise';
import { exec, rows } from '../db';

/** Small repeatable random stream, so the same world always gets the same abandoned settlements. */
function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** [min, max] level per building for each tier; missing buildings stay at 0. */
const TIERS: Record<1 | 2 | 3, Partial<Record<BuildingId, [number, number]>>> = {
  1: { cityhall: [1, 2], farm: [1, 2], steelmill: [1, 2], oilfield: [1, 2], warehouse: [1, 1], housing: [1, 2] },
  2: {
    cityhall: [3, 5], farm: [3, 5], steelmill: [3, 4], oilfield: [3, 4], warehouse: [3, 3], housing: [3, 4],
    barracks: [1, 2], fortifications: [0, 1], market: [0, 1],
  },
  3: {
    cityhall: [6, 8], farm: [5, 7], steelmill: [5, 6], oilfield: [5, 6], warehouse: [5, 5], housing: [5, 7],
    barracks: [3, 4], fortifications: [2, 3], market: [2, 2], commandcenter: [1, 1], researchcenter: [1, 1],
  },
};

export interface AbandonedPlan {
  tier: 1 | 2 | 3;
  levels: BuildingLevels;
  points: number;
  garrison: UnitCounts;
  stock: number;
}

/** Buildings, garrison and stored resources of one abandoned settlement. The garrison scales with its points. */
export function planAbandoned(random: () => number, forceTier?: 1 | 2 | 3): AbandonedPlan {
  const roll = random();
  const tier: 1 | 2 | 3 = forceTier ?? (roll < 0.55 ? 1 : roll < 0.85 ? 2 : 3);
  const partial: Partial<Record<BuildingId, number>> = {};
  for (const [id, [min, max]] of Object.entries(TIERS[tier]) as [BuildingId, [number, number]][]) {
    partial[id] = min + Math.floor(random() * (max - min + 1));
  }
  const levels = normalizeLevels({ ...STARTING_LEVELS, ...partial });
  const points = settlementPoints(levels);
  const garrison = zeroUnits();
  garrison.rifleman = Math.max(1, Math.floor(points * (0.28 + random() * 0.1)));
  return { tier, levels, points, garrison, stock: 200 * tier };
}

/** Creates one abandoned settlement on a hex. The caller has already checked that the hex is free. */
export async function insertAbandoned(conn: PoolConnection, worldId: number, hex: { h3: string; name: string }, plan: AbandonedPlan, now = Date.now()): Promise<number> {
  const result = await exec(
    conn,
    `INSERT INTO settlements (world_id, h3, owner_id, name, buildings, food, steel, oil, resources_at, points)
     VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)`,
    [worldId, hex.h3, hex.name, JSON.stringify(plan.levels), plan.stock, plan.stock, plan.stock, now, plan.points],
  );
  await exec(conn, 'INSERT INTO settlement_units (settlement_id, unit, amount) VALUES (?, ?, ?)', [result.insertId, 'rifleman', plan.garrison.rifleman]);
  return result.insertId;
}

/**
 * Tops a world up to `percent` of its hexes held by abandoned settlements. Hexes that touch another
 * settlement are skipped so nobody starts next to a prize. Returns how many were created.
 */
export async function seedAbandoned(conn: PoolConnection, worldId: number, percent: number, now = Date.now()): Promise<number> {
  const [{ total }] = await rows<{ total: number }>(conn, 'SELECT COUNT(*) AS total FROM hexes WHERE world_id = ?', [worldId]);
  const [{ have }] = await rows<{ have: number }>(conn, 'SELECT COUNT(*) AS have FROM settlements WHERE world_id = ? AND owner_id IS NULL', [worldId]);
  const wanted = Math.round((total * percent) / 100) - have;
  if (wanted <= 0) return 0;

  const taken = new Set((await rows<{ h3: string }>(conn, 'SELECT h3 FROM settlements WHERE world_id = ?', [worldId])).map((r) => r.h3));
  const free = await rows<{ h3: string; name: string }>(
    conn,
    `SELECT h.h3, h.name FROM hexes h LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3
     WHERE h.world_id = ? AND s.id IS NULL ORDER BY h.idx`,
    [worldId],
  );

  // Shuffle with the world's own seed, then take hexes that keep clear of every other settlement.
  const random = rng(worldId * 7919 + have);
  for (let i = free.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [free[i], free[j]] = [free[j], free[i]];
  }

  let created = 0;
  for (const hex of free) {
    if (created >= wanted) break;
    if (gridDisk(hex.h3, 1).some((n) => taken.has(n))) continue;
    taken.add(hex.h3);

    await insertAbandoned(conn, worldId, hex, planAbandoned(random), now);
    created++;
  }
  return created;
}
