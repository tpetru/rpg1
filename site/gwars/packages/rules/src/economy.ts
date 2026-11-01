import { BUILDINGS, BUILDING_IDS, type BuildingDef, type BuildingId, type BuildingLevels } from './buildings';
import { RESOURCES, canAfford, mapBag, type ResourceBag, type ResourceProfile } from './resources';
import type { WorldSettings } from './world';

/** Hourly output of a production building at level 0 (every settlement produces a trickle). */
export const BASE_PRODUCTION = 5;

export function productionPerHour(level: number, multiplier: number, speed: number): number {
  const base = level <= 0 ? BASE_PRODUCTION : 30 * 1.163118 ** (level - 1);
  return base * multiplier * speed;
}

export function warehouseCapacity(level: number): number {
  return Math.round(1000 * 1.2294934 ** (Math.max(1, level) - 1));
}

export function housingCapacity(level: number): number {
  return level <= 0 ? 0 : Math.round(240 * 1.172103 ** (level - 1));
}

export function levelCost(def: BuildingDef, level: number): ResourceBag {
  return mapBag((r) => Math.round(def.baseCost[r] * def.costFactor ** (level - 1)));
}

export function buildTimeSec(def: BuildingDef, level: number, cityhallLevel: number, speed: number): number {
  const sec = (def.baseTime * def.timeFactor ** (level - 1) * 1.05 ** -cityhallLevel) / speed;
  return Math.max(1, Math.round(sec));
}

/** Total population a building uses at a given level. */
export function buildingPop(def: BuildingDef, level: number): number {
  return level <= 0 ? 0 : Math.round(def.basePop * def.popFactor ** (level - 1));
}

/** Share of the old point values that buildings give. */
const BUILDING_POINTS_SCALE = 0.5;

export function buildingPoints(def: BuildingDef, level: number): number {
  let total = 0;
  for (let l = 1; l <= level; l++) total += Math.round(def.basePoints * BUILDING_POINTS_SCALE * 1.2 ** (l - 1));
  return total;
}

export function populationUsed(levels: BuildingLevels): number {
  return BUILDING_IDS.reduce((sum, id) => sum + buildingPop(BUILDINGS[id], levels[id]), 0);
}

export function settlementPoints(levels: BuildingLevels): number {
  return BUILDING_IDS.reduce((sum, id) => sum + buildingPoints(BUILDINGS[id], levels[id]), 0);
}

export function productionRates(levels: BuildingLevels, profile: ResourceProfile, speed: number): ResourceBag {
  const rates = mapBag(() => 0);
  for (const id of BUILDING_IDS) {
    const res = BUILDINGS[id].produces;
    if (res) rates[res] += productionPerHour(levels[id], profile[res], speed);
  }
  return rates;
}

/**
 * Lazy resource evaluation: stock grows linearly between state changes, capped by the warehouse.
 * Stock already above the cap (e.g. after a refund) is kept but does not grow.
 */
export function materialize(stock: ResourceBag, rates: ResourceBag, cap: number, fromMs: number, toMs: number): ResourceBag {
  const hours = Math.max(0, toMs - fromMs) / 3_600_000;
  return mapBag((r) => (stock[r] >= cap ? stock[r] : Math.min(cap, stock[r] + rates[r] * hours)));
}

/** An entry of the build queue. Upgrades and downgrades share the queue; `targetLevel` says which. */
export interface QueuedBuild {
  building: BuildingId;
  targetLevel?: number;
}

/** Levels as they will be once everything in the queue has finished. */
export function plannedLevels(levels: BuildingLevels, queue: readonly QueuedBuild[]): BuildingLevels {
  const planned = { ...levels };
  for (const item of queue) planned[item.building] = item.targetLevel ?? planned[item.building] + 1;
  return planned;
}

export interface BuildState {
  /** Population the settlement's troops take (home, training and away), which housing must also hold. */
  troopPop?: number;
  /** Whether the hex borders the sea; unknown (undefined) is treated as coastal. */
  coastal?: boolean;
  levels: BuildingLevels;
  queue: readonly QueuedBuild[];
  stock: ResourceBag;
}

/** Why a building level cannot be queued. Clients translate the code; `reason` is the English text. */
export type BuildBlock = 'max_level' | 'requires' | 'queue_full' | 'warehouse' | 'housing' | 'resources' | 'coastal';

export type BuildBlockParams = {
  building?: BuildingId;
  level?: number;
};

export type BuildCheck =
  | { ok: true; targetLevel: number; cost: ResourceBag; timeSec: number }
  | {
      ok: false;
      code: BuildBlock;
      params?: BuildBlockParams;
      reason: string;
      targetLevel: number;
      cost?: ResourceBag;
      timeSec?: number;
    };

/** Validates queueing the next level of a building. Used by the server to enforce and by the client to preview. */
export function checkBuild(state: BuildState, id: BuildingId, settings: WorldSettings): BuildCheck {
  const def = BUILDINGS[id];
  const planned = plannedLevels(state.levels, state.queue);
  const targetLevel = planned[id] + 1;

  if (targetLevel > def.maxLevel) return { ok: false, code: 'max_level', reason: 'Maximum level reached', targetLevel };

  if (def.coastal && state.coastal === false) return { ok: false, code: 'coastal', reason: 'Can only be built on the coast', targetLevel };

  for (const [req, level] of Object.entries(def.requires) as [BuildingId, number][]) {
    if (Math.min(state.levels[req], planned[req]) < level) {
      return {
        ok: false,
        code: 'requires',
        params: { building: req, level },
        reason: `Requires ${BUILDINGS[req].name} level ${level}`,
        targetLevel,
      };
    }
  }

  const cost = levelCost(def, targetLevel);
  const timeSec = buildTimeSec(def, targetLevel, state.levels.cityhall, settings.constructionSpeed);
  const fail = (code: BuildBlock, reason: string): BuildCheck => ({ ok: false, code, reason, targetLevel, cost, timeSec });

  if (state.queue.length >= settings.buildQueueSlots) return fail('queue_full', 'Build queue is full');
  if (RESOURCES.some((r) => cost[r] > warehouseCapacity(state.levels.warehouse))) return fail('warehouse', 'Warehouse too small');

  const extraPop = buildingPop(def, targetLevel) - buildingPop(def, targetLevel - 1);
  if (extraPop > 0 && populationUsed(planned) + (state.troopPop ?? 0) + extraPop > housingCapacity(state.levels.housing)) {
    return fail('housing', 'Not enough housing');
  }

  if (!canAfford(state.stock, cost)) return fail('resources', 'Not enough resources');

  return { ok: true, targetLevel, cost, timeSec };
}

/** Taking a building down is quicker than putting it up: this share of the build time of the level removed. */
export const DOWNGRADE_TIME_FACTOR = 0.5;

/** The buildings a settlement cannot lose entirely. */
export function minBuildingLevel(id: BuildingId): number {
  return id === 'cityhall' || id === 'warehouse' || id === 'housing' ? 1 : 0;
}

export type DowngradeBlock = 'min_level' | 'required' | 'queue_full' | 'housing';

export type DowngradeCheck =
  | { ok: true; targetLevel: number; timeSec: number }
  | { ok: false; code: DowngradeBlock; params?: BuildBlockParams; reason: string; targetLevel: number; timeSec?: number };

/** Validates queueing one level less of a building. A downgrade costs nothing and refunds nothing, only time. */
export function checkDowngrade(state: BuildState, id: BuildingId, settings: WorldSettings): DowngradeCheck {
  const def = BUILDINGS[id];
  const planned = plannedLevels(state.levels, state.queue);
  const current = planned[id];
  const targetLevel = current - 1;

  if (current <= minBuildingLevel(id)) return { ok: false, code: 'min_level', reason: 'Cannot go any lower', targetLevel: current };

  const timeSec = Math.max(1, Math.round(buildTimeSec(def, current, state.levels.cityhall, settings.constructionSpeed) * DOWNGRADE_TIME_FACTOR));
  const fail = (code: DowngradeBlock, reason: string, params?: BuildBlockParams): DowngradeCheck => ({ ok: false, code, params, reason, targetLevel, timeSec });

  for (const other of BUILDING_IDS) {
    const needs = BUILDINGS[other].requires[id];
    if (needs !== undefined && planned[other] > 0 && needs > targetLevel) {
      return fail('required', `${BUILDINGS[other].name} needs ${def.name} level ${needs}`, { building: other, level: needs });
    }
  }
  if (state.queue.length >= settings.buildQueueSlots) return fail('queue_full', 'Build queue is full');
  if (id === 'housing' && populationUsed(planned) + (state.troopPop ?? 0) > housingCapacity(targetLevel)) {
    return fail('housing', 'The population would no longer fit');
  }
  return { ok: true, targetLevel, timeSec };
}
