// Loads packages/geo/out/world-r{res}.json into the DB as a new world.
//   npm run db:seed -- --res 3 --speed 1 --name "World 1"
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import type { WorldFile } from '@geowars/geo';
import { DEFAULT_WORLD_SETTINGS, type WorldSettings } from '@geowars/rules';
import { REPO_ROOT, config } from './config';
import { exec, one, pool, tx } from './db';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const res = Number(arg('--res') ?? 3);
const settings: WorldSettings = { ...DEFAULT_WORLD_SETTINGS, speed: Number(arg('--speed') ?? DEFAULT_WORLD_SETTINGS.speed) };
const name = arg('--name') ?? `World ${config.worldId}`;

const file = path.join(REPO_ROOT, 'packages', 'geo', 'out', `world-r${res}.json`);
const world = JSON.parse(await readFile(file, 'utf8')) as WorldFile;

try {
  const existing = await one<{ n: number }>(pool, 'SELECT COUNT(*) AS n FROM hexes WHERE world_id = ?', [config.worldId]);
  if (existing && existing.n > 0) {
    console.log(`World ${config.worldId} already has ${existing.n} hexes; nothing to do.`);
  } else {
    await tx(async (c) => {
      await exec(
        c,
        `INSERT INTO countries (code, name, continent) VALUES ?
         ON DUPLICATE KEY UPDATE name = VALUES(name), continent = VALUES(continent)`,
        [world.countries.map((k) => [k.code, k.name, k.continent])],
      );
      await exec(c, 'INSERT INTO worlds (id, name, h3_res, settings) VALUES (?, ?, ?, ?)', [
        config.worldId,
        name,
        world.res,
        JSON.stringify(settings),
      ]);
      for (let i = 0; i < world.hexes.length; i += 1000) {
        const chunk = world.hexes.slice(i, i + 1000).map((h, j) => [config.worldId, h.h, i + j, h.lat, h.lng, h.c, h.lm, h.n, ...h.p]);
        await exec(
          c,
          `INSERT INTO hexes (world_id, h3, idx, lat, lng, country_code, landmass, name,
             food_mult, steel_mult, oil_mult, rare_mult, uranium_mult) VALUES ?`,
          [chunk],
        );
      }
    });
    console.log(`Created world ${config.worldId} "${name}" (res ${world.res}, speed ${settings.speed}) with ${world.hexes.length} hexes`);
  }
} finally {
  await pool.end();
}
