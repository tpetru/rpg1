import type {
  ApiErrorBody,
  BuildingId,
  MapHexesResponse,
  MapSettlementsResponse,
  MeResponse,
  OwnSettlementDto,
  PublicSettlementDto,
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
  /** name = null resets to the map's default name. */
  renameSettlement: (worldId: number, id: number, name: string | null) =>
    request<OwnSettlementDto>('PATCH', `${w(worldId)}/settlements/${id}/name`, { name }),
  cancelBuild: (worldId: number, id: number, queueId: number) =>
    request<OwnSettlementDto>('DELETE', `${w(worldId)}/settlements/${id}/queue/${queueId}`),
};
