import { CITY_SITES } from '../cityMap';

// The settlement's ground: a meadow crossed by a ring road and two streets, with trees along the
// edges. It is drawn here rather than painted, so it stays crisp at any width, weighs nothing, and
// follows the theme — the buildings standing on it are the app's own drafting-plate illustrations,
// the same ones the overview shows.

const W = 1000;
const H = 750;

/** Trees are placed by hand so none of them lands on a building. */
const TREES: [number, number, number][] = [
  [70, 150, 1], [160, 118, 0.85], [300, 128, 0.9], [420, 108, 0.8], [600, 140, 0.9], [700, 118, 0.8],
  [880, 190, 0.95], [58, 330, 0.85], [64, 520, 0.9], [150, 452, 0.8], [250, 700, 0.9], [360, 706, 0.8],
  [452, 700, 0.85], [618, 706, 0.9], [706, 668, 0.8], [884, 604, 0.9], [900, 706, 0.85], [72, 640, 0.9],
  [330, 470, 0.75], [660, 372, 0.7],
];

const ROADS = [
  // Ring road.
  'M 210 320 A 80 80 0 0 1 290 240 L 740 240 A 80 80 0 0 1 820 320 L 820 560 A 80 80 0 0 1 740 640 L 290 640 A 80 80 0 0 1 210 560 Z',
  // The street through the middle of town, from the north gate to the south gate.
  'M 520 150 L 520 730',
  // The cross street.
  'M 96 330 L 900 330',
  // Short spurs: the airfield, the harbour and the goods yard.
  'M 700 240 L 780 196 L 860 196',
  'M 820 520 L 884 520',
  'M 120 330 L 120 470',
  'M 290 640 L 250 640 L 250 600',
];

export function CityGround() {
  return (
    <svg className="city-ground" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" aria-hidden="true" focusable="false">
      <rect width={W} height={H} fill="var(--map-grass)" />

      {/* Softer grazing patches, so the meadow is not one flat green. */}
      <g fill="var(--map-grass-2)" opacity="0.55">
        <ellipse cx="240" cy="150" rx="230" ry="120" />
        <ellipse cx="790" cy="140" rx="190" ry="110" />
        <ellipse cx="660" cy="700" rx="250" ry="90" />
        <ellipse cx="140" cy="660" rx="180" ry="95" />
        <ellipse cx="500" cy="470" rx="150" ry="110" />
      </g>

      {/* A plot for each building, so a glyph always has ground to stand on. */}
      <g fill="var(--map-plot)">
        {CITY_SITES.map((site) => (
          <ellipse key={site.id} cx={site.x * W} cy={site.y * H + 5} rx={52} ry={15} />
        ))}
      </g>

      <g fill="none" stroke="var(--map-road)" strokeWidth="26" strokeLinecap="round" strokeLinejoin="round">
        {ROADS.map((d) => (
          <path key={d} d={d} />
        ))}
      </g>

      <g>
        {TREES.map(([x, y, scale]) => (
          <g key={`${x}-${y}`} transform={`translate(${x} ${y}) scale(${scale})`}>
            <rect x="-4" y="0" width="8" height="20" rx="3" fill="var(--map-trunk)" />
            <circle cx="-7" cy="-8" r="16" fill="var(--map-tree)" />
            <circle cx="9" cy="-2" r="13" fill="var(--map-tree)" />
            <circle cx="2" cy="-20" r="12" fill="var(--map-tree-2)" />
          </g>
        ))}
      </g>
    </svg>
  );
}
