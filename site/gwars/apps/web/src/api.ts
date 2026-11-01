import type {
  ApiErrorBody,
  AttackPreviewDto,
  BuildingId,
  CommandDto,
  IncomingCommandDto,
  MapHexesResponse,
  MapSettlementsResponse,
  MeResponse,
  RankingResponse,
  RankingType,
  OwnSettlementDto,
  PublicSettlementDto,
  ReportDto,
  UnitCounts,
  UnitId,
  WorldMeResponse,
  WorldSummary,
} from '@geowars/rules';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    /** Full error response; the UI translates it by `body.code`. */
    public body?: ApiErrorBody,
  ) {
    super(message);
  }
}

async function request<T>(method: string, url: string, body?: unknown): Promise<T> {
  const res = await fetch(url, {
    method,
    credentials: 'same-origin',
    headers: body === undefined ? undefined : { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const body = data as Partial<ApiErrorBody>;
    throw new ApiError(body.error ?? res.statusText, res.status, body.error ? (body as ApiErrorBody) : undefined);
  }
  return data as T;
}

const w = (worldId: number) => `/api/w/${worldId}`;

export const api = {
  me: () => request<MeResponse>('GET', '/api/auth/me'),
  login: (login: string, password: string) => request('POST', '/api/auth/login', { login, password }),
  register: (username: string, email: string, password: string) => request('POST', '/api/auth/register', { username, email, password }),
  logout: () => request('POST', '/api/auth/logout'),

  worlds: () => request<WorldSummary[]>('GET', '/api/worlds'),
  worldMe: (worldId: number) => request<WorldMeResponse>('GET', `${w(worldId)}/me`),
  join: (worldId: number, nation: string) => request<{ settlementId: number }>('POST', `${w(worldId)}/join`, { nation }),

  hexes: (worldId: number) => request<MapHexesResponse>('GET', `${w(worldId)}/map/hexes`),
  mapSettlements: (worldId: number) => request<MapSettlementsResponse>('GET', `${w(worldId)}/map/settlements`),

  mySettlements: (worldId: number) => request<OwnSettlementDto[]>('GET', `${w(worldId)}/settlements/mine`),
  settlement: (worldId: number, id: number) => request<OwnSettlementDto | PublicSettlementDto>('GET', `${w(worldId)}/settlements/${id}`),
  build: (worldId: number, id: number, building: BuildingId) =>
    request<OwnSettlementDto>('POST', `${w(worldId)}/settlements/${id}/build`, { building }),
  downgrade: (worldId: number, id: number, building: BuildingId) =>
    request<OwnSettlementDto>('POST', `${w(worldId)}/settlements/${id}/downgrade`, { building }),
  train: (worldId: number, id: number, unit: UnitId, count: number) =>
    request<OwnSettlementDto>('POST', `${w(worldId)}/settlements/${id}/train`, { unit, count }),
  cancelTraining: (worldId: number, id: number, trainId: number) =>
    request<OwnSettlementDto>('DELETE', `${w(worldId)}/settlements/${id}/training/${trainId}`),
  research: (worldId: number, id: number, unit: UnitId) =>
    request<OwnSettlementDto>('POST', `${w(worldId)}/settlements/${id}/research`, { unit }),
  cancelResearch: (worldId: number, id: number, researchId: number) =>
    request<OwnSettlementDto>('DELETE', `${w(worldId)}/settlements/${id}/research/${researchId}`),
  attack: (worldId: number, id: number, targetId: number, units: Partial<UnitCounts>, bombTarget?: BuildingId) =>
    request<CommandDto>('POST', `${w(worldId)}/settlements/${id}/attack`, { targetId, units, bombTarget }),
  attackPreview: (worldId: number, id: number, targetId: number, units: Partial<UnitCounts>) =>
    request<AttackPreviewDto>('POST', `${w(worldId)}/settlements/${id}/attack/preview`, { targetId, units }),
  commands: (worldId: number) => request<CommandDto[]>('GET', `${w(worldId)}/commands`),
  incomingCommands: (worldId: number) => request<IncomingCommandDto[]>('GET', `${w(worldId)}/commands/incoming`),
  ranking: (worldId: number, type: RankingType, page: number, continent?: string) =>
    request<RankingResponse>('GET', `${w(worldId)}/ranking?type=${type}&page=${page}${continent ? `&continent=${encodeURIComponent(continent)}` : ''}`),
  reports: (worldId: number) => request<ReportDto[]>('GET', `${w(worldId)}/reports`),
  readReport: (worldId: number, id: number) => request('POST', `${w(worldId)}/reports/${id}/read`),
  readAllReports: (worldId: number) => request('POST', `${w(worldId)}/reports/read-all`),
  abandon: (worldId: number, id: number) => request('POST', `${w(worldId)}/settlements/${id}/abandon`),
  /** name = null resets to the map's default name. */
  renameSettlement: (worldId: number, id: number, name: string | null) =>
    request<OwnSettlementDto>('PATCH', `${w(worldId)}/settlements/${id}/name`, { name }),
  cancelBuild: (worldId: number, id: number, queueId: number) =>
    request<OwnSettlementDto>('DELETE', `${w(worldId)}/settlements/${id}/queue/${queueId}`),
};
