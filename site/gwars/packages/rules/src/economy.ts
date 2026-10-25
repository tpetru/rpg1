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

export function buildingPoints(def: BuildingDef, level: number): number {
  let total = 0;
  for (let l = 1; l <= level; l++) total += Math.round(def.basePoints * 1.2 ** (l - 1));
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

/** Levels as they will be once everything in the queue has finished. */
export function plannedLevels(levels: BuildingLevels, queue: readonly { building: BuildingId }[]): BuildingLevels {
  const planned = { ...levels };
  for (const item of queue) planned[item.building]++;
  return planned;
}

export interface BuildState {
  levels: BuildingLevels;
  queue: readonly { building: BuildingId }[];
  stock: ResourceBag;
}

export type BuildCheck =
  | { ok: true; targetLevel: number; cost: ResourceBag; timeSec: number }
  | { ok: false; reason: string; targetLevel: number; cost?: ResourceBag; timeSec?: number };

/** Validates queueing the next level of a building. Used by the server to enforce and by the client to preview. */
export function checkBuild(state: BuildState, id: BuildingId, settings: WorldSettings): BuildCheck {
  const def = BUILDINGS[id];
  const planned = plannedLevels(state.levels, state.queue);
  const targetLevel = planned[id] + 1;

  if (targetLevel > def.maxLevel) return { ok: false, reason: 'Maximum level reached', targetLevel };

  for (const [req, level] of Object.entries(def.requires) as [BuildingId, number][]) {
    if (state.levels[req] < level) {
      return { ok: false, reason: `Requires ${BUILDINGS[req].name} level ${level}`, targetLevel };
    }
  }

  const cost = levelCost(def, targetLevel);
  const timeSec = buildTimeSec(def, targetLevel, state.levels.cityhall, settings.speed);
  const fail = (reason: string): BuildCheck => ({ ok: false, reason, targetLevel, cost, timeSec });

  if (state.queue.length >= settings.buildQueueSlots) return fail('Build queue is full');
  if (RESOURCES.some((r) => cost[r] > warehouseCapacity(state.levels.warehouse))) return fail('Warehouse too small');

  const extraPop = buildingPop(def, targetLevel) - buildingPop(def, targetLevel - 1);
  if (extraPop > 0 && populationUsed(planned) + extraPop > housingCapacity(state.levels.housing)) {
    return fail('Not enough housing');
  }

  if (!canAfford(state.stock, cost)) return fail('Not enough resources');

  return { ok: true, targetLevel, cost, timeSec };
}
