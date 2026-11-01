// Fills a world with demo players (no one can log in as them) and independent settlements of random size.
//   npm run seed-demo -w @geowars/server -- --number 0 [--players 100] [--abandoned-each 2]
import { randomBytes } from 'node:crypto';
import { gridDisk } from 'h3-js';
import { hashPassword } from './auth';
import { exec, one, pool, rows, tx } from './db';
import { insertAbandoned, planAbandoned } from './game/abandoned';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const number = Number(arg('--number') ?? 0);
const players = Number(arg('--players') ?? 100);
const each = Number(arg('--abandoned-each') ?? 2);

const FIRST = ['Iron', 'Red', 'Black', 'Golden', 'Silver', 'Storm', 'Frost', 'Ember', 'Stone', 'Wild', 'Royal', 'Dark', 'Swift', 'Grand', 'Northern', 'Southern', 'Eastern', 'Western', 'Crimson', 'Azure'];
const SECOND = ['Legion', 'Empire', 'Union', 'Realm', 'Pact', 'Order', 'Horde', 'Front', 'Dominion', 'League'];

const world = await one<{ id: number }>(pool, 'SELECT id FROM worlds WHERE number = ?', [number]);
if (!world) throw new Error(`World ${number} does not exist`);
if (await one(pool, `SELECT 1 AS x FROM accounts WHERE username = 'demo001'`)) throw new Error('Demo players already exist; nothing done');

const created = await tx(async (c) => {
  const accountIds: number[] = [];
  for (let i = 1; i <= players; i++) {
    const n = String(i).padStart(3, '0');
    const hash = await hashPassword(randomBytes(24).toString('hex'));
    const r = await exec(c, 'INSERT INTO accounts (username, email, password_hash) VALUES (?, ?, ?)', [`demo${n}`, `demo${n}@demo.invalid`, hash]);
    const nation = `${FIRST[(i - 1) % FIRST.length]} ${SECOND[Math.floor((i - 1) / FIRST.length) % SECOND.length]}`.slice(0, 20);
    await exec(c, 'INSERT INTO world_players (world_id, account_id, nation, points) VALUES (?, ?, ?, 0)', [world.id, r.insertId, nation]);
    accountIds.push(r.insertId);
  }

  // Free hexes that touch no other settlement, in random order.
  const taken = new Set((await rows<{ h3: string }>(c, 'SELECT h3 FROM settlements WHERE world_id = ?', [world.id])).map((r) => r.h3));
  const free = await rows<{ h3: string; name: string }>(
    c,
    `SELECT h.h3, h.name FROM hexes h LEFT JOIN settlements s ON s.world_id = h.world_id AND s.h3 = h.h3 WHERE h.world_id = ? AND s.id IS NULL`,
    [world.id],
  );
  for (let i = free.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [free[i], free[j]] = [free[j], free[i]];
  }
  const wanted = players * each;
  const settlementIds: number[] = [];
  for (const hex of free) {
    if (settlementIds.length >= wanted) break;
    if (gridDisk(hex.h3, 1).some((n) => taken.has(n))) continue;
    taken.add(hex.h3);
    settlementIds.push(await insertAbandoned(c, world.id, hex, planAbandoned(Math.random)));
  }
  return { accounts: accountIds.length, settlements: settlementIds };
});

console.log(JSON.stringify({ world: number, players: created.accounts, abandoned: created.settlements.length, settlementIds: created.settlements }));
await pool.end();
