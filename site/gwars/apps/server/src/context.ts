import { resolveWorldSettings, type WorldInfo } from '@geowars/rules';
import { z } from 'zod';
import { pool, rows } from './db';
import type { Engine } from './engine/engine';
import { GameError } from './errors';
import type { Realtime } from './realtime';

export interface WorldRuntime {
  info: WorldInfo;
  engine: Engine;
}

export interface AppContext {
  /** Worlds that are not ended, keyed by world id. */
  worlds: Map<number, WorldRuntime>;
  realtime: Realtime;
}

export async function loadActiveWorlds(): Promise<WorldInfo[]> {
  const list = await rows<{ id: number; number: number; name: string; h3_res: number; settings: string }>(
    pool,
    `SELECT id, number, name, h3_res, settings FROM worlds WHERE status <> 'ended' ORDER BY number`,
  );
  return list.map((w) => ({
    id: w.id,
    number: w.number,
    name: w.name,
    h3Res: w.h3_res,
    settings: resolveWorldSettings(JSON.parse(w.settings)),
  }));
}

const WorldParams = z.object({ worldId: z.coerce.number().int().nonnegative() });

/** Resolves the :worldId route parameter to a running world. */
export function worldFrom(ctx: AppContext, params: unknown): WorldRuntime {
  const { worldId } = WorldParams.parse(params);
  const world = ctx.worlds.get(worldId);
  if (!world) throw new GameError('World not found', 404, 'world_not_found');
  return world;
}
