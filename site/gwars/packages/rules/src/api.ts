// HTTP and WebSocket contract between apps/server and apps/web.
import type { BuildingId, BuildingLevels } from './buildings';
import type { ResourceBag, ResourceProfile } from './resources';
import type { WorldSettings } from './world';

export interface WorldInfo {
  id: number;
  name: string;
  h3Res: number;
  settings: WorldSettings;
}

export interface MeResponse {
  account: { id: number; username: string };
  world: WorldInfo;
  player: { nationality: string; points: number } | null;
  serverTime: number;
}

export interface CountryInfo {
  code: string;
  name: string;
  continent: string;
  hexes: number;
  free: number;
  /** Average multipliers over the country's hexes. */
  food: number;
  steel: number;
  oil: number;
  /** Share of hexes (0..1) holding the strategic resource. */
  rareShare: number;
  uraniumShare: number;
}

/** Row index = hex idx. [h3, countryCode, name, food, steel, oil, rare, uranium] */
export type HexRow = [string, string, string, number, number, number, number, number];

export interface MapHexesResponse {
  res: number;
  countries: Record<string, string>;
  hexes: HexRow[];
}

/** [hexIdx, settlementId, ownerId (0 = none), points] */
export type MapSettlementRow = [number, number, number, number];

export interface MapSettlementsResponse {
  settlements: MapSettlementRow[];
  players: Record<number, string>;
}

export interface QueueItemDto {
  id: number;
  building: BuildingId;
  targetLevel: number;
  startsAt: number;
  finishesAt: number;
}

export interface OwnSettlementDto {
  id: number;
  idx: number;
  h3: string;
  name: string;
  countryCode: string;
  points: number;
  loyalty: number;
  levels: BuildingLevels;
  stock: ResourceBag;
  resourcesAt: number;
  profile: ResourceProfile;
  queue: QueueItemDto[];
}

export interface PublicSettlementDto {
  id: number;
  idx: number;
  h3: string;
  name: string;
  countryCode: string;
  ownerId: number | null;
  ownerName: string | null;
  points: number;
}

export type ServerMessage =
  | { t: 'settlement'; id: number }
  | { t: 'map'; row: MapSettlementRow; ownerName: string | null };
