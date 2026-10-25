import type { WorldInfo } from '@geowars/rules';
import { exec, one, pool, rows, tx } from '../db';
import type { Realtime } from '../realtime';
import { HANDLERS, type GameEvent } from './handlers';

const BATCH = 200;
/** Upper bound on sleep, so events inserted by another process are still picked up. */
const IDLE_POLL_MS = 1000;

/**
 * The single, strictly ordered event loop of one world. Events run one at a time
 * in (execute_at, id) order, which is what makes arrival-time races (snipes, governor trains)
 * deterministic. Scale by running more worlds, never more engines per world.
 */
export class Engine {
  private timer: NodeJS.Timeout | null = null;
  private running = false;
  private again = false;
  private stopped = false;

  constructor(
    private world: WorldInfo,
    private realtime: Realtime,
  ) {}

  start(): void {
    this.wake();
  }

  stop(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
  }

  /** Call after inserting an event so it runs on time even if it is due before the next poll. */
  wake(): void {
    if (this.stopped) return;
    if (this.running) {
      this.again = true;
      return;
    }
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    void this.run();
  }

  private async run(): Promise<void> {
    this.running = true;
    let delay = IDLE_POLL_MS;
    try {
      for (;;) {
        this.again = false;
        const due = await rows<GameEvent>(
          pool,
          `SELECT id, type, ref_id, execute_at FROM game_events
           WHERE world_id = ? AND status = 'pending' AND execute_at <= ?
           ORDER BY execute_at, id LIMIT ?`,
          [this.world.id, Date.now(), BATCH],
        );
        for (const ev of due) await this.process({ ...ev, execute_at: Number(ev.execute_at) });
        if (due.length === BATCH || this.again) continue;

        const next = await one<{ at: number | null }>(
          pool,
          `SELECT MIN(execute_at) AS at FROM game_events WHERE world_id = ? AND status = 'pending'`,
          [this.world.id],
        );
        if (next?.at != null) delay = Math.min(IDLE_POLL_MS, Math.max(0, Number(next.at) - Date.now()));
        break;
      }
    } catch (err) {
      console.error('[engine] loop error', err);
      delay = 2000;
    } finally {
      this.running = false;
    }
    if (this.again) delay = 0;
    if (!this.stopped) this.timer = setTimeout(() => this.wake(), delay);
  }

  private async process(ev: GameEvent): Promise<void> {
    const handler = HANDLERS[ev.type];
    let afterCommit: (() => void) | void = undefined;
    try {
      afterCommit = await tx(async (conn) => {
        // Handlers lock their entities first and the event row last, the same order the API uses.
        const result = handler ? await handler(conn, ev, { world: this.world, realtime: this.realtime }) : undefined;
        await exec(conn, `UPDATE game_events SET status = 'done', processed_at = ? WHERE id = ? AND status = 'pending'`, [
          Date.now(),
          ev.id,
        ]);
        return result;
      });
      if (!handler) console.warn(`[engine] no handler for event type ${ev.type} (#${ev.id})`);
    } catch (err) {
      // A broken event must not stall the whole world; park it for inspection.
      console.error(`[engine] event #${ev.id} ${ev.type} failed`, err);
      await exec(pool, `UPDATE game_events SET status = 'failed', processed_at = ? WHERE id = ?`, [Date.now(), ev.id]);
      return;
    }
    afterCommit?.();
  }
}
