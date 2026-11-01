// Gives every demo player that has no settlement one of random size.
//   npm run seed-demo-homes -w @geowars/server -- --number 0
import { gridDisk } from 'h3-js';
import { exec, one, pool, rows, tx } from './db';
import { insertAbandoned, planAbandoned } from './game/abandoned';
import { refreshPlayerPoints } from './game/settlements';

const i = process.argv.indexOf('--number');
const number = Number(i >= 0 ? process.argv[i + 1] : 0);

const world = await one<{ id: number }>(pool, 'SELECT id FROM worlds WHERE number = ?', [number]);
if (!world) throw new Error(`World ${number} does not exist`);

const result = await tx(async (c) => {
  const players = await rows<{ account_id: number }>(
    c,
    `SELECT wp.account_id FROM world_players wp JOIN accounts a ON a.id = wp.account_id
     WHERE wp.world_id = ? AND a.username LIKE 'demo%'
       AND NOT EXISTS (SELECT 1 FROM settlements s WHERE s.world_id = wp.world_id AND s.owner_id = wp.account_id)
     ORDER BY wp.account_id`,
    [world.id],
  );
  const taken = new Set((await rows<{ h3: string }>(c, 'SELECT h3 FROM settlements WHERE world_id = ?', [world.id])).map((r) => r.h3));
  const free = await rows<{ h3: string; name: string }>(
    c,
    `SELECT h.h3, h.name FROM hexes h LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3 WHERE h.world_id = ? AND s.id IS NULL`,
    [world.id],
  );
  for (let k = free.length - 1; k > 0; k--) {
    const j = Math.floor(Math.random() * (k + 1));
    [free[k], free[j]] = [free[j], free[k]];
  }
  let given = 0;
  for (const p of players) {
    const hex = free.find((h) => !taken.has(h.h3) && gridDisk(h.h3, 1).every((n) => !taken.has(n)));
    if (!hex) break;
    taken.add(hex.h3);
    const id = await insertAbandoned(c, world.id, hex, planAbandoned(Math.random));
    await exec(c, 'UPDATE settlements SET owner_id = ? WHERE id = ?', [p.account_id, id]);
    await refreshPlayerPoints(c, world.id, p.account_id);
    given++;
  }
  return { players: players.length, given };
});

console.log(JSON.stringify({ world: number, ...result }));
await pool.end();
