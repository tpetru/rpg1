// Creates a world from packages/geo/out/world-r{res}.json, or refreshes reference data
// (country codes, name keys) of a world that already exists.
//   npm run db:seed -- --number 0 --speed 1 --name "World 0"
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { WorldFile } from '@geowars/geo';
import { DEFAULT_WORLD_SETTINGS, type WorldSettings } from '@geowars/rules';
import type { PoolConnection } from 'mysql2/promise';
import { REPO_ROOT } from './config';
import { exec, one, pool, tx } from './db';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const res = Number(arg('--res') ?? 3);
const number = Number(arg('--number') ?? 0);
const name = arg('--name') ?? `World ${number}`;
const settings: WorldSettings = { ...DEFAULT_WORLD_SETTINGS, speed: Number(arg('--speed') ?? DEFAULT_WORLD_SETTINGS.speed) };

const file = path.join(REPO_ROOT, 'packages', 'geo', 'out', `world-r${res}.json`);
const world = JSON.parse(await readFile(file, 'utf8')) as WorldFile;

async function upsertCountries(c: PoolConnection): Promise<void> {
  await exec(
    c,
    `INSERT INTO countries (code, iso_a2, name, continent) VALUES ?
     ON DUPLICATE KEY UPDATE iso_a2 = VALUES(iso_a2), name = VALUES(name), continent = VALUES(continent)`,
    [world.countries.map((k) => [k.code, k.a2, k.name, k.continent])],
  );
}

/** Copies name keys onto an existing world's hexes, matched by H3 index. */
async function backfillNameKeys(c: PoolConnection, worldId: number): Promise<number> {
  await exec(c, 'CREATE TEMPORARY TABLE seed_name_keys (h3 VARCHAR(16) NOT NULL PRIMARY KEY, name_key VARCHAR(140) NULL)');
  for (let i = 0; i < world.hexes.length; i += 2000) {
    await exec(c, 'INSERT INTO seed_name_keys (h3, name_key) VALUES ?', [world.hexes.slice(i, i + 2000).map((h) => [h.h, h.k])]);
  }
  const result = await exec(
    c,
    `UPDATE hexes h JOIN seed_name_keys k ON k.h3 = h.h3
     SET h.name_key = k.name_key
     WHERE h.world_id = ? AND NOT (h.name_key <=> k.name_key)`,
    [worldId],
  );
  await exec(c, 'DROP TEMPORARY TABLE seed_name_keys');
  return result.affectedRows;
}

try {
  const existing = await one<{ id: number; name: string }>(pool, 'SELECT id, name FROM worlds WHERE number = ?', [number]);
  if (existing) {
    const updated = await tx(async (c) => {
      await upsertCountries(c);
      return backfillNameKeys(c, existing.id);
    });
    console.log(`World ${number} already exists ("${existing.name}", id ${existing.id}); refreshed countries, ${updated} hex name keys updated.`);
  } else {
    const worldId = await tx(async (c) => {
      await upsertCountries(c);
      const created = await exec(c, 'INSERT INTO worlds (number, name, h3_res, settings) VALUES (?, ?, ?, ?)', [
        number,
        name,
        world.res,
        JSON.stringify(settings),
      ]);
      for (let i = 0; i < world.hexes.length; i += 1000) {
        const chunk = world.hexes
          .slice(i, i + 1000)
          .map((h, j) => [created.insertId, h.h, i + j, h.lat, h.lng, h.c, h.lm, h.n, h.k, ...h.p]);
        await exec(
          c,
          `INSERT INTO hexes (world_id, h3, idx, lat, lng, country_code, landmass, name, name_key,
             food_mult, steel_mult, oil_mult, rare_mult, uranium_mult) VALUES ?`,
          [chunk],
        );
      }
      return created.insertId;
    });
    console.log(`Created "${name}" (id ${worldId}, res ${world.res}, speed ${settings.speed}) with ${world.hexes.length} hexes`);
  }
} finally {
  await pool.end();
}
