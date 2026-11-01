import { BUILDINGS, BUILDING_IDS, settlementPoints, type BuildingLevels } from '@geowars/rules';

/*
 * The world map's settlement markers: four silhouettes, one per size tier, so the map alone
 * tells you whether a hex holds a hamlet or a capital. A settlement's share of the largest
 * possible town picks the silhouette; its owner picks the colour. The same path data draws the
 * map's raster images (canvas) and the legend's glyphs (SVG), so the two always agree.
 */

/** Points of a fully upgraded settlement — the yardstick every town is measured against. */
export const MAX_SETTLEMENT_POINTS = settlementPoints(
  Object.fromEntries(BUILDING_IDS.map((id) => [id, BUILDINGS[id].maxLevel])) as BuildingLevels,
);

/** 1: 0–10% of the largest, 2: 11–50%, 3: 51–80%, 4: 81–100%. */
export function markerTier(points: number): 1 | 2 | 3 | 4 {
  const share = points / MAX_SETTLEMENT_POINTS;
  return share <= 0.1 ? 1 : share <= 0.5 ? 2 : share <= 0.8 ? 3 : 4;
}

/** Share of the largest settlement, rounded — what the tooltip and legend quote. */
export function markerShare(points: number): number {
  return Math.max(1, Math.round((points / MAX_SETTLEMENT_POINTS) * 100));
}

/**
 * The four silhouettes on a 64×64 plate, each one's visual mass centred on the plate's middle
 * (32, 32) so the marker sits dead centre on its hex: one hut, a hut and a tower, a walled
 * town, and a skyline. Each part is its own closed path so the outline strokes read as
 * building joints.
 */
export const MARKER_PATHS: Record<1 | 2 | 3 | 4, string[]> = {
  1: ['M24 30h16v16h-16z', 'M20 30 32 18 44 30 Z'],
  2: [
    'M16 40h16v14h-16z',
    'M13 40 24 30 35 40 Z',
    'M36 22h12v32h-12z',
    'M34 22 42 10 50 22 Z',
  ],
  3: [
    'M10 40h44v10h-44z',
    'M8 24h12v26h-12z',
    'M6 24 14 14 22 24 Z',
    'M44 24h12v26h-12z',
    'M42 24 50 14 58 24 Z',
    'M22 30h20v20h-20z',
    'M19 30 32 18 45 30 Z',
  ],
  4: [
    'M6 28h10v30h-10z',
    'M4 28 11 18 18 28 Z',
    'M48 28h10v30h-10z',
    'M46 28 53 18 60 28 Z',
    'M16 40h12v18h-12z',
    'M14 40 22 32 30 40 Z',
    'M36 40h12v18h-12z',
    'M34 40 42 32 50 40 Z',
    'M26 20h12v38h-12z',
    'M24 20 32 6 40 20 Z',
  ],
};

const PLATE = 64;

/**
 * The four marker images, drawn on a canvas so the map can stamp them. Owner colour is not the
 * marker's job — the hex underneath carries it — so the glyphs are a single cream pictogram on
 * an ink outline, which reads on every hex colour and in both themes.
 */
export function drawMarkerImages(fill: string, ink: string) {
  const canvas = document.createElement('canvas');
  canvas.width = PLATE;
  canvas.height = PLATE;
  const ctx = canvas.getContext('2d')!;
  const out: { id: string; image: ImageData }[] = [];
  for (const tier of [1, 2, 3, 4] as const) {
    ctx.clearRect(0, 0, PLATE, PLATE);
    ctx.lineJoin = 'round';
    ctx.lineWidth = 3;
    for (const d of MARKER_PATHS[tier]) {
      const path = new Path2D(d);
      ctx.fillStyle = fill;
      ctx.fill(path);
      ctx.strokeStyle = ink;
      ctx.stroke(path);
    }
    out.push({ id: `settlement-${tier}`, image: ctx.getImageData(0, 0, PLATE, PLATE) });
  }
  return out;
}

/**
 * Direction chevrons for the march routes: a double chevron pointing along the line, one image
 * per route colour so the arrows always match the line they ride. Placed by MapLibre with
 * `symbol-placement: line`, which rotates them to the route's heading — origin to target.
 */
export function drawArrowImages(colors: { mine: string; foe: string; ret: string }) {
  const PLATE = 24;
  const canvas = document.createElement('canvas');
  canvas.width = PLATE;
  canvas.height = PLATE;
  const ctx = canvas.getContext('2d')!;
  const chevrons = ['M7 5l7 7-7 7', 'M13 5l7 7-7 7'].map((d) => new Path2D(d));
  const out: { id: string; image: ImageData }[] = [];
  for (const [id, stroke] of [
    ['route-arrow-mine', colors.mine],
    ['route-arrow-foe', colors.foe],
    ['route-arrow-return', colors.ret],
  ] as const) {
    ctx.clearRect(0, 0, PLATE, PLATE);
    ctx.lineWidth = 2.2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = stroke;
    for (const path of chevrons) ctx.stroke(path);
    out.push({ id, image: ctx.getImageData(0, 0, PLATE, PLATE) });
  }
  return out;
}

/** The legend's monochrome version of a silhouette. */
export function MarkerGlyph({ tier, size = 22 }: { tier: 1 | 2 | 3 | 4; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      {MARKER_PATHS[tier].map((d) => (
        <path key={d} d={d} fill="currentColor" />
      ))}
    </svg>
  );
}
