import type { AdminPlayerDto, AdminSettlementDto, AdminWorldDto, ApiErrorBody, BuildingId, BuildingLevels, SpeedKey, WorldSettings } from '@geowars/rules';
import { ApiError } from '../api';

async function request<T>(method: string, url: string, body?: unknown): Promise<T> {
  const res = await fetch(url, {
    method,
    credentials: 'same-origin',
    headers: body === undefined ? undefined : { 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = data as Partial<ApiErrorBody>;
    throw new ApiError(err.error ?? res.statusText, res.status, err.error ? (err as ApiErrorBody) : undefined);
  }
  return data as T;
}

const w = (worldId: number) => `/api/admin/w/${worldId}`;

export const adminApi = {
  me: () => request<{ enabled: boolean; loggedIn: boolean }>('GET', '/api/admin/me'),
  login: (password: string) => request('POST', '/api/admin/login', { password }),
  logout: () => request('POST', '/api/admin/logout'),
  worlds: () => request<AdminWorldDto[]>('GET', '/api/admin/worlds'),
  saveSettings: (worldId: number, speeds: Record<SpeedKey, number>) => request<WorldSettings>('PATCH', `${w(worldId)}/settings`, speeds),
  players: (worldId: number) => request<AdminPlayerDto[]>('GET', `${w(worldId)}/players`),
  settlements: (worldId: number, q: string) =>
    request<AdminSettlementDto[]>('GET', `${w(worldId)}/settlements${q ? `?q=${encodeURIComponent(q)}` : ''}`),
  setOwner: (worldId: number, id: number, accountId: number | null) => request('PATCH', `${w(worldId)}/settlements/${id}/owner`, { accountId }),
  claimHex: (worldId: number, idx: number, accountId: number) =>
    request<{ settlementId: number }>('POST', `${w(worldId)}/hexes/${idx}/claim`, { accountId }),
  createAbandoned: (worldId: number, idx: number, size: 1 | 2 | 3) =>
    request<{ settlementId: number }>('POST', `${w(worldId)}/hexes/${idx}/abandoned`, { size }),
  setBuilding: (worldId: number, id: number, building: BuildingId, level: number) =>
    request<BuildingLevels>('PATCH', `${w(worldId)}/settlements/${id}/building`, { building, level }),
};
