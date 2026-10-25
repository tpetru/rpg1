import { settlementPoints, type WorldInfo } from '@geowars/rules';
import type { PoolConnection } from 'mysql2/promise';
import { exec, one } from '../db';
import { loadSettlement, refreshPlayerPoints, saveSettlement, stockAt } from '../game/settlements';
import type { Realtime } from '../realtime';

export interface GameEvent {
  id: number;
  type: string;
  ref_id: number;
  execute_at: number;
}

export interface HandlerContext {
  world: WorldInfo;
  realtime: Realtime;
}

/** Runs inside the event's transaction. May return a callback to run after commit (notifications). */
export type EventHandler = (conn: PoolConnection, ev: GameEvent, ctx: HandlerContext) => Promise<(() => void) | void>;

async function eventStillPending(conn: PoolConnection, id: number): Promise<boolean> {
  const row = await one<{ status: string }>(conn, 'SELECT status FROM game_events WHERE id = ? FOR UPDATE', [id]);
  return row?.status === 'pending';
}

const buildComplete: EventHandler = async (conn, ev, { world, realtime }) => {
  const ref = await one<{ settlement_id: number }>(conn, 'SELECT settlement_id FROM build_queue WHERE id = ?', [ev.ref_id]);
  if (!ref) return; // cancelled

  const s = await loadSettlement(conn, ref.settlement_id, true);
  if (!s || !(await eventStillPending(conn, ev.id))) return;
  const item = await one<{ building: string; target_level: number }>(conn, 'SELECT building, target_level FROM build_queue WHERE id = ?', [
    ev.ref_id,
  ]);
  if (!item) return;

  // Production up to the moment of completion uses the old levels; from then on, the new ones.
  s.stock = stockAt(s, ev.execute_at, world.settings);
  s.resourcesAt = Math.max(s.resourcesAt, ev.execute_at);
  s.levels = { ...s.levels, [item.building]: item.target_level };
  s.points = settlementPoints(s.levels);
  await saveSettlement(conn, s);
  await exec(conn, 'DELETE FROM build_queue WHERE id = ?', [ev.ref_id]);
  if (s.ownerId) await refreshPlayerPoints(conn, s.worldId, s.ownerId);

  return () => {
    if (s.ownerId) realtime.sendTo(s.ownerId, { t: 'settlement', id: s.id });
    realtime.broadcast({ t: 'map', row: [s.idx, s.id, s.ownerId ?? 0, s.points], ownerName: null });
  };
};

export const HANDLERS: Record<string, EventHandler> = {
  BUILD_COMPLETE: buildComplete,
};
