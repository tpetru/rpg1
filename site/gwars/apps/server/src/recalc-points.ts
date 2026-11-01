// Recomputes the stored points of every settlement (from its buildings) and every player (from their settlements),
// for after the point values of buildings change.
//   npm run recalc-points -w @geowars/server
import { normalizeLevels, settlementPoints } from '@geowars/rules';
import { exec, pool, rows } from './db';

const list = await rows<{ id: number; buildings: string | object }>(pool, 'SELECT id, buildings FROM settlements');
let changed = 0;
for (const s of list) {
  const points = settlementPoints(normalizeLevels(typeof s.buildings === 'string' ? JSON.parse(s.buildings) : s.buildings));
  const result = await exec(pool, 'UPDATE settlements SET points = ? WHERE id = ? AND points <> ?', [points, s.id, points]);
  changed += result.affectedRows;
}
await exec(
  pool,
  `UPDATE world_players wp SET points = (SELECT COALESCE(SUM(s.points), 0) FROM settlements s WHERE s.world_id = wp.world_id AND s.owner_id = wp.account_id)`,
);
console.log(JSON.stringify({ settlements: list.length, changed }));
await pool.end();
