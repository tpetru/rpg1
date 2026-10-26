import type { BuildingId } from '@geowars/rules';

/*
 * The town plan: one authored template, identical in every settlement, so a player learns where
 * things are once and can read any city in the nation at a glance.
 *
 * It is drawn as a cadastral sheet: three belts of parcels (works to the north, civic and daily
 * life on the middle square, garrison around the south gate), carried by two avenues joined into
 * a ring, with a road entering the town from the north and from the south. Every parcel is served
 * by a footpath from the nearest avenue; the two civic parcels open onto the square itself.
 *
 * Coordinates are plan units on a PLAN_W x PLAN_H sheet. The view renders them as percentages, so
 * the whole sheet scales with its container and never breaks apart.
 */

export const PLAN_W = 1240;
export const PLAN_H = 664;

/** Parcel box, identical for every building: room for the elevation, its level tag and its name. */
export const PARCEL_W = 172;
export const PARCEL_H = 132;

export type PlotAccess = 'north' | 'south' | 'square';

export interface CityPlot {
  id: BuildingId;
  /** Parcel centre, in plan units. */
  x: number;
  y: number;
  access: PlotAccess;
}

/** Six parcels per belt, west to east. */
const COLUMNS = [120, 320, 520, 720, 920, 1120] as const;

const NORTH_Y = 120;
const MIDDLE_Y = 352;
const SOUTH_Y = 560;

/** Where each belt's footpaths meet its avenue. */
const NORTH_STUB = { from: NORTH_Y + PARCEL_H / 2, to: 200 } as const;
const MIDDLE_STUB = { from: MIDDLE_Y + PARCEL_H / 2, to: 438 } as const;
const SOUTH_STUB = { from: SOUTH_Y - PARCEL_H / 2, to: 464 } as const;

const NORTH_BELT: BuildingId[] = ['oilfield', 'steelmill', 'factory', 'warehouse', 'port', 'airbase'];
const MIDDLE_BELT: BuildingId[] = ['housing', 'hospital', 'cityhall', 'parliament', 'market', 'researchcenter'];
const SOUTH_BELT: BuildingId[] = ['farm', 'commandcenter', 'barracks', 'fortifications', 'bunker', 'radar'];

/** The two parcels that stand on the civic square instead of beside an avenue. */
const ON_SQUARE = new Set<BuildingId>(['cityhall', 'parliament']);

function belt(ids: BuildingId[], y: number, access: PlotAccess): CityPlot[] {
  return ids.map((id, col) => ({ id, x: COLUMNS[col], y, access: ON_SQUARE.has(id) ? 'square' : access }));
}

export const CITY_PLOTS: CityPlot[] = [
  ...belt(NORTH_BELT, NORTH_Y, 'north'),
  ...belt(MIDDLE_BELT, MIDDLE_Y, 'south'),
  ...belt(SOUTH_BELT, SOUTH_Y, 'south'),
];

/** Two avenues run the length of the sheet; one road enters from the north and from the south. */
export const CITY_ROADS = [
  { x: 20, y: 200, w: 1200, h: 26 }, // north avenue, serving the works belt
  { x: 20, y: 438, w: 1200, h: 26 }, // south avenue, serving the civic block and the garrison
  { x: 606, y: 0, w: 26, h: 200 }, // north approach, between the two inner works parcels
  { x: 606, y: 464, w: 26, h: 200 }, // south approach, between the inner garrison parcels
];

/** Dashed centre lines: the drafting convention that makes a band read as a road. */
export const CITY_AXES = ['M20 213H1220', 'M20 451H1220', 'M619 0V200', 'M619 464V664'];

/** Footpaths from each served parcel to its avenue. */
export const CITY_PATHS = CITY_PLOTS.flatMap((plot) => {
  if (plot.access === 'square') return [];
  const stub = plot.access === 'north' ? NORTH_STUB : plot.y === MIDDLE_Y ? MIDDLE_STUB : SOUTH_STUB;
  return [`M${plot.x} ${Math.min(stub.from, stub.to)}V${Math.max(stub.from, stub.to)}`];
});

/** The paved square the two civic parcels stand on, held tight to their parcels. */
export const CITY_PLAZA = { x: 424, y: 274, w: 384, h: 154 };

/** A plot's box as percentages of the sheet, so the layout survives any container width. */
export function plotBox(plot: CityPlot) {
  return {
    left: ((plot.x - PARCEL_W / 2) / PLAN_W) * 100,
    top: ((plot.y - PARCEL_H / 2) / PLAN_H) * 100,
    width: (PARCEL_W / PLAN_W) * 100,
    height: (PARCEL_H / PLAN_H) * 100,
  };
}
