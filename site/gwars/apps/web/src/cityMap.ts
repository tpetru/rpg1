import type { BuildingId } from '@geowars/rules';

/*
 * The settlement scene: one meadow for every settlement, so a building keeps its address and a
 * player learns any city in the nation at a glance.
 *
 * The ground is drawn (see art/cityGround.tsx) and the buildings standing on it are the app's own
 * drafting-plate illustrations, so the map needs no image files at all. Site coordinates are
 * fractions of the scene: x across, y down to the ground line the building stands on.
 */

export const SCENE_ASPECT = 1000 / 750;

export interface CitySite {
  id: BuildingId;
  /** Ground line of the building, as fractions of the scene. */
  x: number;
  y: number;
  /** Width of the illustration, as a fraction of the scene width. */
  w: number;
}

/** Where each building stands, laid out like a small town: industry west, civic centre, works south. */
export const CITY_SITES: CitySite[] = [
  // The middle of town.
  { id: 'cityhall', x: 0.514, y: 0.491, w: 0.112 },
  { id: 'housing', x: 0.626, y: 0.378, w: 0.11 },
    { id: 'researchcenter', x: 0.487, y: 0.276, w: 0.105 },
  { id: 'market', x: 0.639, y: 0.589, w: 0.115 },

  // South of town, down to the gate.
  { id: 'fortifications', x: 0.557, y: 0.949, w: 0.125 },
  { id: 'barracks', x: 0.421, y: 0.669, w: 0.115 },
  { id: 'bunker', x: 0.355, y: 0.828, w: 0.105 },
  { id: 'radar', x: 0.572, y: 0.779, w: 0.105 },

  // The works yard in the west.
  { id: 'oilfield', x: 0.135, y: 0.367, w: 0.115 },
  { id: 'steelmill', x: 0.308, y: 0.288, w: 0.115 },
  { id: 'factory', x: 0.301, y: 0.46, w: 0.115 },
  { id: 'warehouse', x: 0.109, y: 0.583, w: 0.115 },

  // The edges: fields, the harbour, the airfield.
  { id: 'farm', x: 0.235, y: 0.755, w: 0.115 },
  { id: 'airbase', x: 0.755, y: 0.264, w: 0.135 },
  { id: 'port', x: 0.845, y: 0.688, w: 0.125 },
  { id: 'commandcenter', x: 0.8, y: 0.47, w: 0.105 },
];

/** The town's quarters, as the scene lays them out. A finding aid for the map, not a game rule. */
export type CityDistrictKey = 'citadel' | 'garrison' | 'works' | 'outer';

export const CITY_DISTRICTS: { key: CityDistrictKey; ids: BuildingId[] }[] = [
  { key: 'citadel', ids: ['cityhall', 'market', 'housing', 'researchcenter'] },
  { key: 'garrison', ids: ['fortifications', 'barracks', 'bunker', 'radar'] },
  { key: 'works', ids: ['oilfield', 'steelmill', 'factory', 'warehouse'] },
  { key: 'outer', ids: ['farm', 'port', 'airbase', 'commandcenter'] },
];

export const DISTRICT_OF = Object.fromEntries(
  CITY_DISTRICTS.flatMap((district) => district.ids.map((id) => [id, district.key])),
) as Record<BuildingId, CityDistrictKey>;

/** A site's box in percentages of the scene. */
export function siteBox(site: CitySite) {
  return { left: site.x * 100, top: site.y * 100, width: site.w * 100 };
}
