import { slowestSpeed, type UnitCounts } from './units';

export interface LatLng {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_KM = 6371;
/** Crossing water takes a Port and is slower. */
export const OVERSEAS_SPEED_FACTOR = 0.6;

/** Great-circle distance between two points, in kilometres. */
export function distanceKm(a: LatLng, b: LatLng): number {
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Milliseconds for an army to cover `km`, or Infinity when there is no army. */
export function travelTimeMs(km: number, units: Partial<UnitCounts>, worldSpeed: number, overseas: boolean): number {
  const speed = slowestSpeed(units) * worldSpeed * (overseas ? OVERSEAS_SPEED_FACTOR : 1);
  if (speed <= 0) return Infinity;
  return Math.max(1000, Math.round((km / speed) * 3_600_000));
}
