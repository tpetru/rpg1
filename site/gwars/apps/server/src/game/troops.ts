import {
  UNITS,
  UNIT_IDS,
  addUnits,
  normalizeUnits,
  troopPop,
  zeroUnits,
  type OwnSettlementDto,
  type ResearchItemDto,
  type ResourceBag,
  type TrainItemDto,
  type UnitCounts,
  type UnitId,
} from '@geowars/rules';
import { exec, rows, type Db } from '../db';
import { GameError } from '../errors';
import { loadQueue, toOwnDto, type Settlement } from './settlements';

export interface TrainItem extends TrainItemDto {
  cost: ResourceBag;
}

/** Troops standing in a settlement. */
export async function loadUnits(db: Db, settlementId: number): Promise<UnitCounts> {
  const list = await rows<{ unit: string; amount: number }>(db, 'SELECT unit, amount FROM settlement_units WHERE settlement_id = ?', [settlementId]);
  return normalizeUnits(Object.fromEntries(list.map((r) => [r.unit, r.amount])));
}

/** Adds troops to a settlement. */
export async function addTroops(db: Db, settlementId: number, units: Partial<UnitCounts>): Promise<void> {
  for (const id of UNIT_IDS) {
    const amount = units[id] ?? 0;
    if (amount <= 0) continue;
    await exec(
      db,
      'INSERT INTO settlement_units (settlement_id, unit, amount) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)',
      [settlementId, id, amount],
    );
  }
}

/** Takes troops out of a settlement; fails if it does not have that many. */
export async function removeTroops(db: Db, settlementId: number, units: Partial<UnitCounts>): Promise<void> {
  for (const id of UNIT_IDS) {
    const amount = units[id] ?? 0;
    if (amount <= 0) continue;
    const result = await exec(db, 'UPDATE settlement_units SET amount = amount - ? WHERE settlement_id = ? AND unit = ? AND amount >= ?', [
      amount,
      settlementId,
      id,
      amount,
    ]);
    if (result.affectedRows !== 1) throw new GameError('Not enough troops at home', 400, 'not_enough_troops');
  }
}

/** Replaces the whole garrison of a settlement. */
export async function setTroops(db: Db, settlementId: number, units: UnitCounts): Promise<void> {
  await exec(db, 'DELETE FROM settlement_units WHERE settlement_id = ?', [settlementId]);
  await addTroops(db, settlementId, units);
}

/** Units researched in this settlement. */
export async function loadResearched(db: Db, settlementId: number): Promise<UnitId[]> {
  const list = await rows<{ unit: string }>(db, 'SELECT unit FROM settlement_research WHERE settlement_id = ?', [settlementId]);
  return UNIT_IDS.filter((id) => list.some((r) => r.unit === id));
}

export interface ResearchItem extends ResearchItemDto {
  cost: ResourceBag;
}

export async function loadResearching(db: Db, settlementId: number): Promise<ResearchItem | null> {
  const [r] = await rows<{ id: number; unit: UnitId; cost_food: number; cost_steel: number; cost_oil: number; starts_at: number; finishes_at: number }>(
    db,
    'SELECT * FROM research_queue WHERE settlement_id = ?',
    [settlementId],
  );
  if (!r) return null;
  return { id: Number(r.id), unit: r.unit, startsAt: Number(r.starts_at), finishesAt: Number(r.finishes_at), cost: { food: r.cost_food, steel: r.cost_steel, oil: r.cost_oil } };
}

export async function loadTraining(db: Db, settlementId: number): Promise<TrainItem[]> {
  const list = await rows<{
    id: number;
    unit: UnitId;
    amount: number;
    total: number;
    cost_food: number;
    cost_steel: number;
    cost_oil: number;
    starts_at: number;
    finishes_at: number;
  }>(db, 'SELECT * FROM train_queue WHERE settlement_id = ? ORDER BY finishes_at, id', [settlementId]);
  return list.map((t) => ({
    id: Number(t.id),
    unit: t.unit,
    count: t.amount,
    total: t.total,
    startsAt: Number(t.starts_at),
    finishesAt: Number(t.finishes_at),
    // What is still to come is what a cancel gives back.
    cost: { food: (t.cost_food * t.amount) / t.total, steel: (t.cost_steel * t.amount) / t.total, oil: (t.cost_oil * t.amount) / t.total },
  }));
}

/** Armies this settlement sent out that have not arrived yet. */
export async function loadAway(db: Db, settlementId: number): Promise<UnitCounts> {
  const list = await rows<{ units: string | UnitCounts }>(db, `SELECT units FROM commands WHERE origin_id = ? AND status = 'travelling'`, [settlementId]);
  return list.reduce((sum, c) => addUnits(sum, normalizeUnits(typeof c.units === 'string' ? JSON.parse(c.units) : c.units)), zeroUnits());
}

/** Population all of a settlement's troops take: at home, in training and away. */
export async function loadTroopPop(db: Db, settlementId: number): Promise<number> {
  const [home, training, away] = await Promise.all([loadUnits(db, settlementId), loadTraining(db, settlementId), loadAway(db, settlementId)]);
  return troopPop(home) + troopPop(away) + training.reduce((sum, t) => sum + t.count * UNITS[t.unit].pop, 0);
}

/** The settlement as its owner sees it: buildings, resources, build queue and military. */
export async function ownDto(db: Db, s: Settlement): Promise<OwnSettlementDto> {
  const [queue, units, training, away, researched, researching] = await Promise.all([
    loadQueue(db, s.id),
    loadUnits(db, s.id),
    loadTraining(db, s.id),
    loadAway(db, s.id),
    loadResearched(db, s.id),
    loadResearching(db, s.id),
  ]);
  const pop = troopPop(units) + troopPop(away) + training.reduce((sum, t) => sum + t.count * UNITS[t.unit].pop, 0);
  return toOwnDto(s, queue, { units, training: training.map(({ cost: _cost, ...dto }) => dto), troopPop: pop,
    researched,
    researching: researching ? { id: researching.id, unit: researching.unit, startsAt: researching.startsAt, finishesAt: researching.finishesAt } : null,
  });
}
