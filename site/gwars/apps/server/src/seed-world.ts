// Creates a world from packages/geo/out/world-r{res}.json. Skips worlds that already exist.
//   npm run db:seed -- --number 0 --speed 1 --name "World 0"
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { WorldFile } from '@geowars/geo';
import { DEFAULT_WORLD_SETTINGS, type WorldSettings } from '@geowars/rules';
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

try {
  const existing = await one<{ id: number; name: string }>(pool, 'SELECT id, name FROM worlds WHERE number = ?', [number]);
  if (existing) {
    console.log(`World ${number} already exists ("${existing.name}", id ${existing.id}); nothing to do.`);
  } else {
    const file = path.join(REPO_ROOT, 'packages', 'geo', 'out', `world-r${res}.json`);
    const world = JSON.parse(await readFile(file, 'utf8')) as WorldFile;

    const worldId = await tx(async (c) => {
      await exec(
        c,
        `INSERT INTO countries (code, name, continent) VALUES ?
         ON DUPLICATE KEY UPDATE name = VALUES(name), continent = VALUES(continent)`,
        [world.countries.map((k) => [k.code, k.name, k.continent])],
      );
      const created = await exec(c, 'INSERT INTO worlds (number, name, h3_res, settings) VALUES (?, ?, ?, ?)', [
        number,
        name,
        world.res,
        JSON.stringify(settings),
      ]);
      for (let i = 0; i < world.hexes.length; i += 1000) {
        const chunk = world.hexes
          .slice(i, i + 1000)
          .map((h, j) => [created.insertId, h.h, i + j, h.lat, h.lng, h.c, h.lm, h.n, ...h.p]);
        await exec(
          c,
          `INSERT INTO hexes (world_id, h3, idx, lat, lng, country_code, landmass, name,
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
