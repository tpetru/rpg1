import {
  UNITS,
  UNIT_IDS,
  canAfford,
  distanceKm,
  housingCapacity,
  isBuildingId,
  mapBag,
  normalizeLevels,
  normalizeUnits,
  plannedLevels,
  populationUsed,
  researchTimeSec,
  trainTimeSec,
  travelTimeMs,
  unitCost,
  groundUnits,
  unitTotal,
  zeroUnits,
  type BattleReportData,
  type BuildingId,
  type AttackPreviewDto,
  type CommandDto,
  type IncomingCommandDto,
  type OwnSettlementDto,
  type ReportDto,
  type UnitCounts,
  type UnitId,
  type WorldInfo,
} from '@geowars/rules';
import type { FastifyInstance } from 'fastify';
import type { PoolConnection } from 'mysql2/promise';
import { z } from 'zod';
import { requireAuth } from '../auth';
import { worldFrom, type AppContext } from '../context';
import { type Db, exec, one, pool, rows, tx } from '../db';
import { GameError } from '../errors';
import { loadOwnedSettlements, loadQueue, loadSettlement, refreshPlayerPoints, saveSettlement, stockAt, storageCap, type Settlement } from '../game/settlements';
import { loadAway, loadResearched, loadResearching, loadTraining, loadTroopPop, loadUnits, ownDto, removeTroops } from '../game/troops';

const MAX_TRAIN_QUEUE = 5;
const MAX_BATCH = 5000;

const IdParams = z.object({ id: z.coerce.number().int().positive() });
const TrainParams = IdParams.extend({ trainId: z.coerce.number().int().positive() });
const TrainBody = z.object({ unit: z.string().refine((u): u is keyof typeof UNITS => u in UNITS, 'Unknown unit'), count: z.number().int().min(1).max(MAX_BATCH) });
const ResearchBody = z.object({ unit: z.string().refine((u): u is keyof typeof UNITS => u in UNITS, 'Unknown unit') });
const AttackBody = z.object({ targetId: z.number().int().positive(), bombTarget: z.string().optional(), units: z.record(z.string(), z.number().int().min(0).max(1_000_000)) });

async function lockOwned(c: PoolConnection, world: WorldInfo, id: number, accountId: number): Promise<Settlement> {
  const s = await loadSettlement(c, id, true);
  if (!s || s.worldId !== world.id || s.ownerId !== accountId) throw new GameError('Settlement not found', 404, 'settlement_not_found');
  return s;
}

interface CommandRow {
  id: number;
  type: 'attack' | 'return';
  origin_id: number;
  target_id: number;
  units: string | UnitCounts;
  sent_at: number;
  arrives_at: number;
  origin_idx: number;
  target_idx: number;
}

/** Whether any of the player's settlements has a Port. */
async function ownsPort(db: Db, worldId: number, ownerId: number): Promise<boolean> {
  return (await loadOwnedSettlements(db, worldId, ownerId)).some((s) => s.levels.port >= 1);
}

export function toCommandDto(r: CommandRow): CommandDto {
  return {
    id: Number(r.id),
    type: r.type,
    originId: r.origin_id,
    originIdx: r.origin_idx,
    targetId: r.target_id,
    targetIdx: r.target_idx,
    units: normalizeUnits(typeof r.units === 'string' ? JSON.parse(r.units) : r.units),
    sentAt: Number(r.sent_at),
    arrivesAt: Number(r.arrives_at),
  };
}

export function registerMilitaryRoutes(app: FastifyInstance, ctx: AppContext): void {
  /** Orders troops from the unit's building. They are paid for now and join the garrison one by one as each is trained. */
  app.post('/api/w/:worldId/settlements/:id/train', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const world = worldFrom(ctx, req.params);
    const { settings } = world.info;
    const { id } = IdParams.parse(req.params);
    const { unit, count } = TrainBody.parse(req.body);
    const def = UNITS[unit as keyof typeof UNITS];

    const dto = await tx(async (c) => {
      const s = await lockOwned(c, world.info, id, req.account!.id);
      for (const [building, level] of Object.entries(def.requires) as [BuildingId, number][]) {
        if (s.levels[building] < level) throw new GameError(`Requires ${building} level ${level}`, 400, 'train_requires', { building, level });
      }

      if (!(await loadResearched(c, s.id)).includes(unit as UnitId)) throw new GameError('This unit has not been researched here', 400, 'train_not_researched');

      const now = Date.now();
      s.stock = stockAt(s, now, settings);
      s.resourcesAt = now;
      const cost = unitCost(def, count);
      if (!canAfford(s.stock, cost)) throw new GameError('Not enough resources', 400, 'train_resources');

      const queue = await loadQueue(c, s.id);
      const training = await loadTraining(c, s.id);
      if (training.length >= MAX_TRAIN_QUEUE) throw new GameError('The training queue is full', 400, 'train_queue_full');
      const used = populationUsed(plannedLevels(s.levels, queue)) + (await loadTroopPop(c, s.id)) + count * def.pop;
      if (used > housingCapacity(s.levels.housing)) throw new GameError('Not enough housing', 400, 'train_housing');

      const startsAt = Math.max(now, training.at(-1)?.finishesAt ?? now);
      const finishesAt = startsAt + trainTimeSec(def, count, s.levels[def.trainedAt], settings.recruitSpeed) * 1000;
      s.stock = mapBag((r) => s.stock[r] - cost[r]);
      await saveSettlement(c, s);
      const item = await exec(
        c,
        `INSERT INTO train_queue (settlement_id, unit, amount, total, cost_food, cost_steel, cost_oil, starts_at, finishes_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [s.id, unit, count, count, cost.food, cost.steel, cost.oil, startsAt, finishesAt],
      );
      // One event per unit: the first one is done after a single unit's training time.
      const firstAt = count === 1 ? finishesAt : Math.round(startsAt + (finishesAt - startsAt) / count);
      await exec(c, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'TRAIN_COMPLETE', ?, ?)`, [world.info.id, item.insertId, firstAt]);
      return ownDto(c, s);
    });

    world.engine.wake();
    return dto;
  });

  /** Starts researching a unit in this settlement's Research Center; one research at a time. */
  app.post('/api/w/:worldId/settlements/:id/research', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const world = worldFrom(ctx, req.params);
    const { settings } = world.info;
    const { id } = IdParams.parse(req.params);
    const { unit } = ResearchBody.parse(req.body);
    const def = UNITS[unit as UnitId];

    const dto = await tx(async (c) => {
      const s = await lockOwned(c, world.info, id, req.account!.id);
      if (s.levels.researchcenter < def.research.level) {
        throw new GameError(`Needs Research Center level ${def.research.level}`, 400, 'research_requires', { building: 'researchcenter', level: def.research.level });
      }
      if ((await loadResearched(c, s.id)).includes(unit as UnitId)) throw new GameError('Already researched', 400, 'research_done');
      if (await loadResearching(c, s.id)) throw new GameError('A research is already in progress', 400, 'research_busy');

      const now = Date.now();
      s.stock = stockAt(s, now, settings);
      s.resourcesAt = now;
      const cost = def.research.cost;
      if (!canAfford(s.stock, cost)) throw new GameError('Not enough resources', 400, 'research_resources');

      const finishesAt = now + researchTimeSec(def, s.levels.researchcenter, settings.recruitSpeed) * 1000;
      s.stock = mapBag((r) => s.stock[r] - cost[r]);
      await saveSettlement(c, s);
      const item = await exec(
        c,
        `INSERT INTO research_queue (settlement_id, unit, cost_food, cost_steel, cost_oil, starts_at, finishes_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [s.id, unit, cost.food, cost.steel, cost.oil, now, finishesAt],
      );
      await exec(c, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'RESEARCH_COMPLETE', ?, ?)`, [world.info.id, item.insertId, finishesAt]);
      return ownDto(c, s);
    });

    world.engine.wake();
    return dto;
  });

  /** Cancels the research in progress; part of the cost comes back, like for buildings. */
  app.delete('/api/w/:worldId/settlements/:id/research/:trainId', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const { id, trainId } = TrainParams.parse(req.params);

    return tx(async (c) => {
      const s = await lockOwned(c, worldInfo, id, req.account!.id);
      const current = await loadResearching(c, s.id);
      if (!current || current.id !== trainId) throw new GameError('Research not found', 404, 'research_not_found');

      const now = Date.now();
      const cap = storageCap(s);
      const stock = stockAt(s, now, worldInfo.settings);
      s.stock = mapBag((r) => Math.max(stock[r], Math.min(cap, stock[r] + current.cost[r] * worldInfo.settings.cancelRefund)));
      s.resourcesAt = now;
      await saveSettlement(c, s);
      await exec(c, 'DELETE FROM research_queue WHERE id = ?', [current.id]);
      await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'RESEARCH_COMPLETE' AND ref_id = ? AND status = 'pending'`, [now, current.id]);
      return ownDto(c, s);
    });
  });

  /** Only the last batch can be cancelled, so the timing of the others never shifts. */
  app.delete('/api/w/:worldId/settlements/:id/training/:trainId', { preHandler: requireAuth }, async (req): Promise<OwnSettlementDto> => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const { id, trainId } = TrainParams.parse(req.params);

    return tx(async (c) => {
      const s = await lockOwned(c, worldInfo, id, req.account!.id);
      const training = await loadTraining(c, s.id);
      const last = training.at(-1);
      if (!last || last.id !== trainId) throw new GameError('Only the last batch can be cancelled', 400, 'train_cancel_last_only');

      const now = Date.now();
      const cap = storageCap(s);
      const stock = stockAt(s, now, worldInfo.settings);
      s.stock = mapBag((r) => Math.max(stock[r], Math.min(cap, stock[r] + last.cost[r] * worldInfo.settings.cancelRefund)));
      s.resourcesAt = now;
      await saveSettlement(c, s);
      await exec(c, 'DELETE FROM train_queue WHERE id = ?', [last.id]);
      await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'TRAIN_COMPLETE' AND ref_id = ? AND status = 'pending'`, [now, last.id]);
      return ownDto(c, s);
    });
  });

  /** Sends troops from one of your settlements against an abandoned one. */
  app.post('/api/w/:worldId/settlements/:id/attack', { preHandler: requireAuth }, async (req): Promise<CommandDto> => {
    const world = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const body = AttackBody.parse(req.body);
    const units = normalizeUnits(body.units);
    if (unitTotal(units) === 0) throw new GameError('Choose at least one unit', 400, 'attack_no_units');
    if (UNIT_IDS.some((u) => UNITS[u].homeOnly && units[u] > 0)) throw new GameError('This unit never leaves home', 400, 'attack_home_only');

    const command = await tx(async (c) => {
      // Lock both settlements in id order, the same order the engine uses.
      const [first, second] = id < body.targetId ? [id, body.targetId] : [body.targetId, id];
      const a = await loadSettlement(c, first, true);
      const b = second === first ? a : await loadSettlement(c, second, true);
      const origin = id === first ? a : b;
      const target = body.targetId === first ? a : b;

      if (!origin || origin.worldId !== world.info.id || origin.ownerId !== req.account!.id) throw new GameError('Settlement not found', 404, 'settlement_not_found');
      if (!target || target.worldId !== world.info.id) throw new GameError('Target not found', 404, 'attack_target_invalid');
      if (target.id === origin.id) throw new GameError('A settlement cannot attack itself', 400, 'attack_self');

      const home = await loadUnits(c, origin.id);
      if (UNIT_IDS.some((u) => units[u] > home[u])) throw new GameError('Not enough troops at home', 400, 'not_enough_troops');
      const bombTarget = body.bombTarget !== undefined && isBuildingId(body.bombTarget) ? body.bombTarget : null;

      const spots = await rows<{ h3: string; idx: number; lat: number; lng: number; landmass: number }>(
        c,
        'SELECT h3, idx, lat, lng, landmass FROM hexes WHERE world_id = ? AND h3 IN (?, ?)',
        [world.info.id, origin.h3, target.h3],
      );
      const from = spots.find((h) => h.h3 === origin.h3)!;
      const to = spots.find((h) => h.h3 === target.h3)!;
      const overseas = from.landmass !== to.landmass;
      // Ground troops cross the sea by ship, so they need a Port somewhere in the player's realm; spies and bombers fly.
      if (overseas && unitTotal(groundUnits(units)) > 0 && !(await ownsPort(c, world.info.id, req.account!.id))) throw new GameError('Crossing the sea needs a Port', 400, 'attack_needs_port');

      const now = Date.now();
      const km = distanceKm(from, to);
      const arrivesAt = now + travelTimeMs(km, units, world.info.settings.warSpeed, overseas);
      await removeTroops(c, origin.id, units);
      const result = await exec(
        c,
        `INSERT INTO commands (world_id, owner_id, type, origin_id, target_id, units, sent_at, arrives_at, bomb_target)
         VALUES (?, ?, 'attack', ?, ?, ?, ?, ?, ?)`,
        [world.info.id, req.account!.id, origin.id, target.id, JSON.stringify(units), now, arrivesAt, bombTarget],
      );
      await exec(c, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'ATTACK_ARRIVE', ?, ?)`, [world.info.id, result.insertId, arrivesAt]);
      return toCommandDto({
        id: result.insertId,
        type: 'attack',
        origin_id: origin.id,
        target_id: target.id,
        units,
        sent_at: now,
        arrives_at: arrivesAt,
        origin_idx: from.idx,
        target_idx: to.idx,
      });
    });

    world.engine.wake();
    ctx.realtime.sendTo(world.info.id, req.account!.id, { t: 'command' });
    ctx.realtime.sendTo(world.info.id, req.account!.id, { t: 'settlement', id });
    return command;
  });

  /** Distance and travel time for a planned attack, without sending anything. */
  app.post('/api/w/:worldId/settlements/:id/attack/preview', { preHandler: requireAuth }, async (req): Promise<AttackPreviewDto> => {
    const world = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const body = AttackBody.parse(req.body);
    const units = normalizeUnits(body.units);

    const origin = await loadSettlement(pool, id);
    const target = await loadSettlement(pool, body.targetId);
    if (!origin || origin.worldId !== world.info.id || origin.ownerId !== req.account!.id) throw new GameError('Settlement not found', 404, 'settlement_not_found');
    if (!target || target.worldId !== world.info.id) throw new GameError('Target not found', 404, 'attack_target_invalid');

    const spots = await rows<{ h3: string; lat: number; lng: number; landmass: number }>(
      pool,
      'SELECT h3, lat, lng, landmass FROM hexes WHERE world_id = ? AND h3 IN (?, ?)',
      [world.info.id, origin.h3, target.h3],
    );
    const from = spots.find((h) => h.h3 === origin.h3)!;
    const to = spots.find((h) => h.h3 === target.h3)!;
    const overseas = from.landmass !== to.landmass;
    const km = distanceKm(from, to);
    const travel = unitTotal(units) > 0 ? travelTimeMs(km, units, world.info.settings.warSpeed, overseas) : null;
    return { distanceKm: Math.round(km), travelMs: travel, overseas, needsPort: overseas && unitTotal(groundUnits(units)) > 0 && !(await ownsPort(pool, world.info.id, req.account!.id)) };
  });

  /** Armies of the player that are still on their way. */
  app.get('/api/w/:worldId/commands', { preHandler: requireAuth }, async (req): Promise<CommandDto[]> => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const list = await rows<CommandRow>(
      pool,
      `SELECT c.id, c.type, c.origin_id, c.target_id, c.units, c.sent_at, c.arrives_at, oh.idx AS origin_idx, th.idx AS target_idx
       FROM commands c
       JOIN settlements os ON os.id = c.origin_id JOIN hexes oh ON oh.world_id = os.world_id AND oh.h3 = os.h3
       JOIN settlements ts ON ts.id = c.target_id JOIN hexes th ON th.world_id = ts.world_id AND th.h3 = ts.h3
       WHERE c.world_id = ? AND c.owner_id = ? AND c.status = 'travelling'
       ORDER BY c.arrives_at, c.id`,
      [worldInfo.id, req.account!.id],
    );
    return list.map(toCommandDto);
  });

  /** Armies of other players that are on their way to one of the player's settlements; the units are only known with a Radar. */
  app.get('/api/w/:worldId/commands/incoming', { preHandler: requireAuth }, async (req): Promise<IncomingCommandDto[]> => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const list = await rows<CommandRow & { buildings: string; nation: string | null; origin_country: string; target_country: string; origin_continent: string; target_continent: string }>(
      pool,
      `SELECT c.id, c.type, c.origin_id, c.target_id, c.units, c.sent_at, c.arrives_at, oh.idx AS origin_idx, th.idx AS target_idx,
              ts.buildings, wp.nation, oh.country_code AS origin_country, th.country_code AS target_country,
              oc.continent AS origin_continent, tc.continent AS target_continent
       FROM commands c
       JOIN settlements os ON os.id = c.origin_id JOIN hexes oh ON oh.world_id = os.world_id AND oh.h3 = os.h3
       JOIN settlements ts ON ts.id = c.target_id JOIN hexes th ON th.world_id = ts.world_id AND th.h3 = ts.h3
       JOIN countries oc ON oc.code = oh.country_code JOIN countries tc ON tc.code = th.country_code
       LEFT JOIN world_players wp ON wp.world_id = c.world_id AND wp.account_id = c.owner_id
       WHERE c.world_id = ? AND ts.owner_id = ? AND c.owner_id <> ? AND c.type = 'attack' AND c.status = 'travelling'
       ORDER BY c.arrives_at, c.id`,
      [worldInfo.id, req.account!.id, req.account!.id],
    );
    // Radar 2 sees that an attack is coming; 3, 4 and 5 also tell when, for armies from the same
    // country, the same continent, or anywhere.
    const out: IncomingCommandDto[] = [];
    for (const r of list) {
      const radar = normalizeLevels(JSON.parse(r.buildings)).radar;
      if (radar < 2) continue;
      const timeKnown = radar >= 5 || (radar === 4 && r.origin_continent === r.target_continent) || (radar === 3 && r.origin_country === r.target_country);
      const dto = toCommandDto(r);
      out.push({ ...dto, sentAt: timeKnown ? dto.sentAt : 0, arrivesAt: timeKnown ? dto.arrivesAt : 0, attackerName: r.nation, unitsHidden: false, timeHidden: !timeKnown });
    }
    return out;
  });

  app.get('/api/w/:worldId/reports', { preHandler: requireAuth }, async (req): Promise<ReportDto[]> => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const list = await rows<{ id: number; data: string | BattleReportData; created_at: number; is_read: number }>(
      pool,
      'SELECT id, data, created_at, is_read FROM reports WHERE world_id = ? AND account_id = ? ORDER BY created_at DESC, id DESC LIMIT 60',
      [worldInfo.id, req.account!.id],
    );
    return list.map((r) => ({
      id: Number(r.id),
      createdAt: Number(r.created_at),
      read: r.is_read === 1,
      type: 'battle' as const,
      data: typeof r.data === 'string' ? (JSON.parse(r.data) as BattleReportData) : r.data,
    }));
  });

  app.post('/api/w/:worldId/reports/:id/read', { preHandler: requireAuth }, async (req) => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    await exec(pool, 'UPDATE reports SET is_read = 1 WHERE id = ? AND world_id = ? AND account_id = ?', [id, worldInfo.id, req.account!.id]);
    return { ok: true };
  });

  app.post('/api/w/:worldId/reports/read-all', { preHandler: requireAuth }, async (req) => {
    const { info: worldInfo } = worldFrom(ctx, req.params);
    await exec(pool, 'UPDATE reports SET is_read = 1 WHERE world_id = ? AND account_id = ?', [worldInfo.id, req.account!.id]);
    return { ok: true };
  });

  /**
   * Gives a settlement up: it becomes abandoned, anybody can conquer it, and its troops are disbanded.
   * A player cannot abandon the last settlement, nor one that has an army out.
   */
  app.post('/api/w/:worldId/settlements/:id/abandon', { preHandler: requireAuth }, async (req) => {
    const world = worldFrom(ctx, req.params);
    const { id } = IdParams.parse(req.params);
    const accountId = req.account!.id;

    const s = await tx(async (c) => {
      const s = await lockOwned(c, world.info, id, accountId);
      const [{ owned }] = await rows<{ owned: number }>(c, 'SELECT COUNT(*) AS owned FROM settlements WHERE world_id = ? AND owner_id = ?', [world.info.id, accountId]);
      if (owned < 2) throw new GameError('You cannot abandon your last settlement', 400, 'abandon_last');
      const away = await loadAway(c, s.id);
      if (unitTotal(away) > 0) throw new GameError('Wait for the army to arrive first', 400, 'abandon_busy');

      const now = Date.now();
      const queued = await rows<{ id: number }>(c, 'SELECT id FROM build_queue WHERE settlement_id = ?', [s.id]);
      const training = await rows<{ id: number }>(c, 'SELECT id FROM train_queue WHERE settlement_id = ?', [s.id]);
      if (queued.length > 0) {
        await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'BUILD_COMPLETE' AND status = 'pending' AND ref_id IN (?)`, [now, queued.map((q) => q.id)]);
        await exec(c, 'DELETE FROM build_queue WHERE settlement_id = ?', [s.id]);
      }
      if (training.length > 0) {
        await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'TRAIN_COMPLETE' AND status = 'pending' AND ref_id IN (?)`, [now, training.map((q) => q.id)]);
        await exec(c, 'DELETE FROM train_queue WHERE settlement_id = ?', [s.id]);
      }
      const researching = await loadResearching(c, s.id);
      if (researching) {
        await exec(c, `UPDATE game_events SET status = 'cancelled', processed_at = ? WHERE type = 'RESEARCH_COMPLETE' AND status = 'pending' AND ref_id = ?`, [now, researching.id]);
        await exec(c, 'DELETE FROM research_queue WHERE settlement_id = ?', [s.id]);
      }
      await exec(c, 'DELETE FROM settlement_units WHERE settlement_id = ?', [s.id]);
      await exec(c, 'UPDATE settlements SET owner_id = NULL, custom_name = NULL, resources_at = ? WHERE id = ?', [now, s.id]);
      await refreshPlayerPoints(c, world.info.id, accountId);
      return s;
    });

    ctx.realtime.broadcast(world.info.id, { t: 'map', row: [s.idx, s.id, 0, s.points], ownerName: null });
    ctx.realtime.sendTo(world.info.id, accountId, { t: 'settlement', id: s.id });
    return { ok: true };
  });
}
