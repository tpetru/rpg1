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

/**
 * Row index = hex idx. [h3, countryCode, name, food, steel, oil, rare, uranium, nameKey]
 * `name` is English. `nameKey` describes generated names so clients can translate them:
 * null = real city name, "dir:NE:Paris" = area next to a city, "frontier:3" = numbered frontier hex.
 */
export type HexRow = [string, string, string, number, number, number, number, number, string | null];

export interface CountryRef {
  /** English name */
  name: string;
  /** ISO 3166-1 alpha-2, for localized names (Intl.DisplayNames); null when there is none. */
  a2: string | null;
}

export interface MapHexesResponse {
  res: number;
  countries: Record<string, CountryRef>;
  hexes: HexRow[];
}

/** Body of every error response. Clients translate `code` (with `params`) and fall back to `error`. */
export interface ApiErrorBody {
  error: string;
  code?: string;
  params?: Record<string, string | number>;
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
  /** Default name from the map (English). */
  name: string;
  /** Name chosen by the owner; null = use the map's name. */
  customName: string | null;
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
  customName: string | null;
  countryCode: string;
  ownerId: number | null;
  /** Owner's nation name in this world. */
  ownerName: string | null;
  points: number;
}

export type ServerMessage =
  | { t: 'settlement'; id: number }
  | { t: 'map'; row: MapSettlementRow; ownerName: string | null };

// Admin page. Everything here is only served to a logged-in admin session.
export interface AdminPlayerDto {
  accountId: number;
  username: string;
  nation: string;
  points: number;
}

export interface AdminSettlementDto {
  id: number;
  idx: number;
  /** Default name from the map (English) */
  name: string;
  customName: string | null;
  countryCode: string;
  ownerId: number | null;
  ownerUsername: string | null;
  ownerNation: string | null;
  points: number;
  levels: BuildingLevels;
}

export interface AdminWorldDto {
  id: number;
  number: number;
  name: string;
}
