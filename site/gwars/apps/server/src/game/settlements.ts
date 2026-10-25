import {
  materialize,
  normalizeLevels,
  productionRates,
  warehouseCapacity,
  type BuildingId,
  type BuildingLevels,
  type OwnSettlementDto,
  type PublicSettlementDto,
  type QueueItemDto,
  type ResourceBag,
  type ResourceProfile,
  type WorldSettings,
} from '@geowars/rules';
import { exec, one, rows, type Db } from '../db';

export interface Settlement {
  id: number;
  worldId: number;
  h3: string;
  idx: number;
  name: string;
  countryCode: string;
  ownerId: number | null;
  levels: BuildingLevels;
  stock: ResourceBag;
  resourcesAt: number;
  points: number;
  loyalty: number;
  profile: ResourceProfile;
}

interface SettlementRow {
  id: number;
  world_id: number;
  h3: string;
  idx: number;
  name: string;
  country_code: string;
  owner_id: number | null;
  buildings: string;
  food: number;
  steel: number;
  oil: number;
  resources_at: number;
  points: number;
  loyalty: number;
  food_mult: number;
  steel_mult: number;
  oil_mult: number;
  rare_mult: number;
  uranium_mult: number;
}

interface QueueRow {
  id: number;
  settlement_id: number;
  building: BuildingId;
  target_level: number;
  cost_food: number;
  cost_steel: number;
  cost_oil: number;
  starts_at: number;
  finishes_at: number;
}

export interface QueueItem extends QueueItemDto {
  cost: ResourceBag;
}

const SELECT_SETTLEMENT = `
  SELECT s.id, s.world_id, s.h3, s.name, s.owner_id, s.buildings, s.food, s.steel, s.oil,
         s.resources_at, s.points, s.loyalty, h.idx, h.country_code,
         h.food_mult, h.steel_mult, h.oil_mult, h.rare_mult, h.uranium_mult
  FROM settlements s JOIN hexes h ON h.world_id = s.world_id AND h.h3 = s.h3`;

function fromRow(r: SettlementRow): Settlement {
  return {
    id: r.id,
    worldId: r.world_id,
    h3: r.h3,
    idx: r.idx,
    name: r.name,
    countryCode: r.country_code,
    ownerId: r.owner_id,
    levels: normalizeLevels(JSON.parse(r.buildings)),
    stock: { food: r.food, steel: r.steel, oil: r.oil },
    resourcesAt: Number(r.resources_at),
    points: r.points,
    loyalty: r.loyalty,
    profile: { food: r.food_mult, steel: r.steel_mult, oil: r.oil_mult, rare: r.rare_mult, uranium: r.uranium_mult },
  };
}

/** Loads a settlement; with forUpdate it is row-locked until the transaction ends. */
export async function loadSettlement(db: Db, id: number, forUpdate = false): Promise<Settlement | undefined> {
  const row = await one<SettlementRow>(db, `${SELECT_SETTLEMENT} WHERE s.id = ?${forUpdate ? ' FOR UPDATE' : ''}`, [id]);
  return row && fromRow(row);
}

export async function loadOwnedSettlements(db: Db, worldId: number, ownerId: number): Promise<Settlement[]> {
  const list = await rows<SettlementRow>(db, `${SELECT_SETTLEMENT} WHERE s.world_id = ? AND s.owner_id = ? ORDER BY s.id`, [
    worldId,
    ownerId,
  ]);
  return list.map(fromRow);
}

export async function loadQueue(db: Db, settlementId: number): Promise<QueueItem[]> {
  const list = await rows<QueueRow>(db, 'SELECT * FROM build_queue WHERE settlement_id = ? ORDER BY finishes_at, id', [settlementId]);
  return list.map((q) => ({
    id: Number(q.id),
    building: q.building,
    targetLevel: q.target_level,
    startsAt: Number(q.starts_at),
    finishesAt: Number(q.finishes_at),
    cost: { food: q.cost_food, steel: q.cost_steel, oil: q.cost_oil },
  }));
}

export function storageCap(s: Settlement): number {
  return warehouseCapacity(s.levels.warehouse);
}

/** Resources at time `at`, given the buildings the settlement had since its last update. */
export function stockAt(s: Settlement, at: number, settings: WorldSettings): ResourceBag {
  return materialize(s.stock, productionRates(s.levels, s.profile, settings.speed), storageCap(s), s.resourcesAt, at);
}

export async function saveSettlement(db: Db, s: Settlement): Promise<void> {
  await exec(db, 'UPDATE settlements SET buildings = ?, food = ?, steel = ?, oil = ?, resources_at = ?, points = ? WHERE id = ?', [
    JSON.stringify(s.levels),
    s.stock.food,
    s.stock.steel,
    s.stock.oil,
    s.resourcesAt,
    s.points,
    s.id,
  ]);
}

export async function refreshPlayerPoints(db: Db, worldId: number, accountId: number): Promise<void> {
  await exec(
    db,
    `UPDATE world_players SET points = (
       SELECT COALESCE(SUM(points), 0) FROM settlements WHERE world_id = ? AND owner_id = ?
     ) WHERE world_id = ? AND account_id = ?`,
    [worldId, accountId, worldId, accountId],
  );
}

export function toOwnDto(s: Settlement, queue: QueueItem[]): OwnSettlementDto {
  return {
    id: s.id,
    idx: s.idx,
    h3: s.h3,
    name: s.name,
    countryCode: s.countryCode,
    points: s.points,
    loyalty: s.loyalty,
    levels: s.levels,
    stock: s.stock,
    resourcesAt: s.resourcesAt,
    profile: s.profile,
    queue: queue.map(({ cost: _cost, ...dto }) => dto),
  };
}

export function toPublicDto(s: Settlement, ownerName: string | null): PublicSettlementDto {
  return { id: s.id, idx: s.idx, h3: s.h3, name: s.name, countryCode: s.countryCode, ownerId: s.ownerId, ownerName, points: s.points };
}
