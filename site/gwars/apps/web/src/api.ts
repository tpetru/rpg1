import type {
  BuildingId,
  CountryInfo,
  MapHexesResponse,
  MapSettlementsResponse,
  MeResponse,
  OwnSettlementDto,
  PublicSettlementDto,
} from '@geowars/rules';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
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
  if (!res.ok) throw new ApiError((data as { error?: string }).error ?? res.statusText, res.status);
  return data as T;
}

export const api = {
  me: () => request<MeResponse>('GET', '/api/auth/me'),
  login: (login: string, password: string) => request('POST', '/api/auth/login', { login, password }),
  register: (username: string, email: string, password: string) => request('POST', '/api/auth/register', { username, email, password }),
  logout: () => request('POST', '/api/auth/logout'),

  countries: () => request<CountryInfo[]>('GET', '/api/world/countries'),
  join: (country: string) => request<{ settlementId: number }>('POST', '/api/world/join', { country }),

  hexes: () => request<MapHexesResponse>('GET', '/api/map/hexes'),
  mapSettlements: () => request<MapSettlementsResponse>('GET', '/api/map/settlements'),

  mySettlements: () => request<OwnSettlementDto[]>('GET', '/api/settlements/mine'),
  settlement: (id: number) => request<OwnSettlementDto | PublicSettlementDto>('GET', `/api/settlements/${id}`),
  build: (id: number, building: BuildingId) => request<OwnSettlementDto>('POST', `/api/settlements/${id}/build`, { building }),
  cancelBuild: (id: number, queueId: number) => request<OwnSettlementDto>('DELETE', `/api/settlements/${id}/queue/${queueId}`),
};
