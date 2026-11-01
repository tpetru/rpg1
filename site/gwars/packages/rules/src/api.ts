// HTTP and WebSocket contract between apps/server and apps/web.
import type { BuildingId, BuildingLevels } from './buildings';
import type { UnitCounts, UnitId } from './units';
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
  /** Natural Earth continent, e.g. 'Europe' — the same string the continent ranking uses. */
  continent: string;
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

export interface TrainItemDto {
  id: number;
  unit: UnitId;
  /** Units still to come; each one joins the garrison as soon as it is trained. */
  count: number;
  /** Units ordered in this batch. */
  total: number;
  startsAt: number;
  /** When the last unit of the batch is done. */
  finishesAt: number;
}

export interface ResearchItemDto {
  id: number;
  unit: UnitId;
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
  /** The hex borders the sea (a Port can only be built on the coast). */
  coastal: boolean;
  queue: QueueItemDto[];
  /** Troops standing in the settlement right now. */
  units: UnitCounts;
  /** Units being trained, in order. */
  training: TrainItemDto[];
  /** Population all of this settlement's troops take (home, training and away). */
  troopPop: number;
  /** Units researched in this settlement's Research Center: only these can be trained here. */
  researched: UnitId[];
  /** The research in progress (one at a time), or null. */
  researching: ResearchItemDto | null;
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

/** An army on the move. Only attacks on abandoned settlements exist so far. */
export interface CommandDto {
  id: number;
  type: 'attack' | 'return';
  originId: number;
  originIdx: number;
  targetId: number;
  targetIdx: number;
  units: UnitCounts;
  sentAt: number;
  arrivesAt: number;
}

/** An enemy army heading for one of the player's settlements. */
export interface IncomingCommandDto extends CommandDto {
  attackerName: string | null;
  /** The target has no Radar, so the units are not known (and `units` is all zeros). */
  unitsHidden: boolean;
  /** The Radar is too weak to tell when it arrives from that far away; `sentAt` and `arrivesAt` are 0. */
  timeHidden: boolean;
}

/** What sending an army would take, computed by the server so the player sees the real figures. */
export interface AttackPreviewDto {
  distanceKm: number;
  /** null until at least one unit is chosen */
  travelMs: number | null;
  overseas: boolean;
  /** Crossing water needs a Port at the origin and it has none. */
  needsPort: boolean;
}

export interface BattleReportData {
  /** conquered: won and took the settlement. defeat: lost the army. fizzled: the target had become the attacker's own, the army went home. */
  outcome: 'conquered' | 'victory' | 'defeat' | 'fizzled' | 'air';
  originId: number;
  originIdx: number;
  targetId: number;
  targetIdx: number;
  attackers: UnitCounts;
  attackerLosses: UnitCounts;
  defenders: UnitCounts;
  defenderLosses: UnitCounts;
  attackPower: number;
  defensePower: number;
  luck: number;
  fortificationLevel: number;
  /** The nation that held the target; none when it was abandoned. */
  defenderName?: string | null;
  /** The nation that sent the army. */
  attackerName?: string | null;
  /** Bombers brought down by the target's Defence Drones before they could bomb. */
  bombersShot?: number;
  /** Tanks that survived a won battle pulled the Fortifications down: level before and after. */
  wallsDown?: { from: number; to: number } | null;
  /** This copy of the report is the defender's: the attacker's own report has it unset. */
  asDefender?: boolean;
  /** Spies were with the army: the buildings of the town when it arrived. */
  intel?: BuildingLevels | null;
  /** Bombers were with the army: the building they hit and its level before and after. */
  bombed?: { building: BuildingId; from: number; to: number } | null;
}

export interface ReportDto {
  id: number;
  createdAt: number;
  read: boolean;
  type: 'battle';
  data: BattleReportData;
}

export type RankingType = 'points' | 'cities' | 'continent';

export interface RankingRow {
  /** Place in the whole ranking (not in the page). */
  rank: number;
  accountId: number;
  nation: string;
  /** Points: all of the player's, or only those of the settlements on the chosen continent. */
  points: number;
  /** Settlements: all of the player's, or only those on the chosen continent. */
  cities: number;
  /** In the settlements ranking each row is one settlement: its name. */
  settlement?: string;
}

export interface RankingResponse {
  type: RankingType;
  continent: string | null;
  /** Every continent with land in this world, for the continent ranking. */
  continents: string[];
  page: number;
  pages: number;
  total: number;
  rows: RankingRow[];
}

export type ServerMessage =
  | { t: 'settlement'; id: number }
  | { t: 'command' }
  | { t: 'report'; id: number }
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
  settings: WorldSettings;
}
