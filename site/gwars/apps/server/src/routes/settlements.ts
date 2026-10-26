import {
  SETTLEMENT_NAME_MAX,
  SETTLEMENT_NAME_MIN,
  checkBuild,
  isBuildingId,
  mapBag,
  settlementNameError,
  settlementNameIssue,
  type OwnSettlementDto,
  type PublicSettlementDto,
  type WorldInfo,
} from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import type { PoolConnection } from 'mysql2/promise';
import { z } from 'zod';
import { requireAuth } from '../auth';
import { worldFrom, type AppContext } from '../context';
import { exec, one, pool, tx } from '../db';
import { GameError } from '../errors';
import {
  loadOwnedSettlements,
  loadQueue,
  loadSettlement,
  saveSettlement,
  stockAt,
  storageCap,
  toOwnDto,
  toPublicDto,
  type Settlement,
} from '../game/settlements';

const IdParams = z.object({ id: z.coerce.number().int().positive() });
const QueueParams = IdParams.extend({ queueId: z.coerce.number().int().positive() });
const RenameBody = z.object({ name: z.string().trim().nullable() });
const BuildBody = z.object({ building: z.string().refine(isBuildingId, 'Unknown building') });

async function lockOwned(c: PoolConnection, world: WorldInfo, id: number, accountId: number): Promise<Settlement> {
  const s = await loadSettlement(c, id, true);
  if (!s || s.worldId !== world.id || s.ownerId !== accountId) throw new GameError('Settlement not found', 404, 'settlement_not_found');
  return s;
}

export function registerSettlementRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get('/api/w/:worldId/settlements/mine', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto[]> => {
    const { info } = worldFrom(ctx, req.params);
    const list = await loadOwnedSettlements(pool, info.id, req.account!.id);
    return Promise.all(list.map(async (s) => toOwnDto(s, await loadQueue(pool, s.id))));
  });

  app.get('/api/w/:worldId/settlements/:id', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto | PublicSettlementDto> => {
    const { info } = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const s = await loadSettlement(pool, id);
    if (!s || s.worldId !== info.id) throw new GameError('Settlement not found', 404, 'settlement_not_found');
    if (s.ownerId === req.account!.id) return toOwnDto(s, await loadQueue(pool, s.id));
    const owner = s.ownerId
      ? await one<{ nation: string }>(pool, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [info.id, s.ownerId])
      : undefined;
    return toPublicDto(s, owner?.nation ?? null);
  });

  app.post('/api/w/:worldId/settlements/:id/build', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const world = worldFrom(ctx, req.params);
    const { settings } = world.info;
    const { id } = IdParams.parse(req.params);
    const { building } = BuildBody.parse(req.body);

    const dto = await tx(async (c) => {
      const s = await lockOwned(c, world.info, id, req.account!.id);
      const queue = await loadQueue(c, s.id);
      const now = Date.now();
      s.stock = stockAt(s, now, settings);
      s.resourcesAt = now;

      const check = checkBuild({ levels: s.levels, queue, stock: s.stock }, building, settings);
      if (!check.ok) throw new GameError(check.reason, 400, `build_${check.code}`, check.params as Record<string, string | number> | undefined);

      const startsAt = Math.max(now, queue.at(-1)?.finishesAt ?? now);
      const finishesAt = startsAt + check.timeSec * 1000;
      s.stock = mapBag((r) => s.stock[r] - check.cost[r]);
      await saveSettlement(c, s);

      const item = await exec(
        c,
        `INSERT INTO build_queue (settlement_id, building, target_level, cost_food, cost_steel, cost_oil, starts_at, finishes_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [s.id, building, check.targetLevel, check.cost.food, check.cost.steel, check.cost.oil, startsAt, finishesAt],
      );
      await exec(c, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'BUILD_COMPLETE', ?, ?)`, [
        world.info.id,
        item.insertId,
        finishesAt,
      ]);
      return toOwnDto(s, await loadQueue(c, s.id));
    });

    world.engine.wake();
    return dto;
  });

  /** Renames a settlement; an empty or null name goes back to the map's default name. */
  app.patch('/api/w/:worldId/settlements/:id/name', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const { info } = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const { name } = RenameBody.parse(req.body);
    const customName = name && name.length > 0 ? name : null;
    if (customName) {
      const issue = settlementNameIssue(customName);
      if (issue) {
        throw new GameError(settlementNameError(customName)!, 400, issue, { min: SETTLEMENT_NAME_MIN, max: SETTLEMENT_NAME_MAX });
      }
    }

    return tx(async (c) => {
      const s = await lockOwned(c, info, id, req.account!.id);
      await exec(c, 'UPDATE settlements SET custom_name = ? WHERE id = ?', [customName, s.id]);
      s.customName = customName;
      return toOwnDto(s, await loadQueue(c, s.id));
    });
  });

  /** Only the last queued item can be cancelled, so the timing of the others never shifts. */
  app.delete('/api/w/:worldId/settlements/:id/queue/:queueId', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const { info } = worldFrom(ctx, req.params);
    const { id, queueId } = QueueParams.parse(req.params);

    return tx(async (c) => {
      const s = await lockOwned(c, info, id, req.account!.id);
      const queue = await loadQueue(c, s.id);
      const last = queue.at(-1);
      if (!last || last.id !== queueId) throw new GameError('Only the last item in the queue can be cancelled', 400, 'cancel_last_only');

      const now = Date.now();
      const cap = storageCap(s);
      const stock = stockAt(s, now, info.settings);
      s.stock = mapBag((r) => Math.max(stock[r], Math.min(cap, stock[r] + last.cost[r] * info.settings.cancelRefund)));
      s.resourcesAt = now;
      await saveSettlement(c, s);
      await exec(c, 'DELETE FROM build_queue WHERE id = ?', [last.id]);
      await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'BUILD_COMPLETE' AND ref_id = ? AND status = 'pending'`, [
        now,
        last.id,
      ]);
      return toOwnDto(s, queue.slice(0, -1));
    });
  });
}
