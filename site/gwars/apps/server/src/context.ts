import { resolveWorldSettings, type WorldInfo } from '@geowars/rules';
import { one, pool } from './db';
import type { Engine } from './engine/engine';
import type { Realtime } from './realtime';

export interface AppContext {
  world: WorldInfo;
  realtime: Realtime;
  engine: Engine;
}

export async function loadWorld(id: number): Promise<WorldInfo> {
  const row = await one<{ id: number; name: string; h3_res: number; settings: string }>(
    pool,
    'SELECT id, name, h3_res, settings FROM worlds WHERE id = ?',
    [id],
  );
  if (!row) throw new Error(`World ${id} does not exist. Run: npm run db:migrate && npm run db:seed`);
  return { id: row.id, name: row.name, h3Res: row.h3_res, settings: resolveWorldSettings(JSON.parse(row.settings)) };
}
