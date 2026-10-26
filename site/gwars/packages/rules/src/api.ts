// HTTP and WebSocket contract between apps/server and apps/web.
import type { BuildingId, BuildingLevels } from './buildings';
import type { ResourceBag, ResourceProfile } from './resources';
import type { WorldSettings } from './world';

export interface WorldInfo {
  id: number;
  /** Public number: "World 0", "World 1", ... */
  number: number;
  name: string;
  h3Res: number;
  settings: WorldSettings;
}

export type WorldStatus = 'open' | 'running' | 'ended';

export interface PlayerInfo {
  nation: string;
  points: number;
}

export interface WorldSummary extends WorldInfo {
  status: WorldStatus;
  players: number;
  /** The logged-in account's nation in this world, if it joined. */
  you: PlayerInfo | null;
}

export interface MeResponse {
  account: { id: number; username: string };
}

export interface WorldMeResponse {
  world: WorldInfo;
  player: PlayerInfo | null;
  serverTime: number;
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
  /** ownerId -> nation name */
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
  /** Owner's nation name in this world. */
  ownerName: string | null;
  points: number;
}

export type ServerMessage =
  | { t: 'settlement'; id: number }
  | { t: 'map'; row: MapSettlementRow; ownerName: string | null };
