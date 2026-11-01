// The hex action glyphs — modern line icons: 2px strokes, round caps, open geometry.
// A faint duotone fill sits behind the working part of each tool (blade, lenses) so the
// glyphs stay readable on the map without going solid. Colour comes from the button:
// enemy red for the axe, overlay cream for the binoculars.

const base = {
  width: 20,
  height: 20,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  'aria-hidden': true,
  focusable: false,
} as const;

const duotone = { fill: 'currentColor', fillOpacity: 0.2, stroke: 'none' } as const;

/** Battle axe: a flared maul head with a curved cutting edge, hafted to the lower left. */
export function AxeIcon() {
  const head = 'M11.9 9.9 15.1 3.2Q19.8 3.6 20.8 8.9L14.1 12.1Z';
  return (
    <svg {...base}>
      <path {...duotone} d={head} />
      <path d={head} />
      <path d="M4.5 19.5 13 11" />
    </svg>
  );
}

/** Field glasses: two barrels joined at a bridge, lens rims as full circles. */
export function BinocularsIcon() {
  return (
    <svg {...base}>
      <circle {...duotone} cx="6.5" cy="15.5" r="3.2" />
      <circle {...duotone} cx="17.5" cy="15.5" r="3.2" />
      <path d="M8.5 12.8V6.6a1.6 1.6 0 0 0-3.2 0v6.2" />
      <path d="M18.7 12.8V6.6a1.6 1.6 0 0 0-3.2 0v6.2" />
      <path d="M8.5 13.5h7" />
      <path d="M10.5 9.2h3" />
      <circle cx="6.5" cy="15.5" r="3.2" />
      <circle cx="17.5" cy="15.5" r="3.2" />
    </svg>
  );
}

export function SwordsIcon() {
  return (
    <svg {...base}>
      <path d="M5 5l9 9M5 5v4l2 .5M5 5h4l.5 2" />
      <path d="M19 5l-9 9M19 5v4l-2 .5M19 5h-4l-.5 2" />
      <path d="M13 15l3 3M11 15l-3 3M7 19l2-2M17 19l-2-2" />
    </svg>
  );
}

export function ShieldIcon() {
  return (
    <svg {...base}>
      <path d="M12 3l7 2.5v5.5c0 4.5-3 7.6-7 9-4-1.4-7-4.5-7-9V5.5z" fill="currentColor" fillOpacity={0.25} />
    </svg>
  );
}

export function EyeIcon() {
  return (
    <svg {...base}>
      <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z" />
      <circle cx="12" cy="12" r="3" fill="currentColor" fillOpacity={0.25} />
    </svg>
  );
}

export function BombIcon() {
  return (
    <svg {...base}>
      <circle cx="10" cy="14.5" r="6" fill="currentColor" fillOpacity={0.25} />
      <path d="M14.5 10l3-3M17 4.5l2.5 1M18.5 3l1 2.5M20 7l-1.5-.5" />
    </svg>
  );
}

export function FlagIcon() {
  return (
    <svg {...base}>
      <path d="M6 21V4" />
      <path d="M6 5h12l-2.5 4 2.5 4H6" fill="currentColor" fillOpacity={0.25} />
    </svg>
  );
}

export function WallIcon() {
  return (
    <svg {...base}>
      <rect x="3" y="5" width="18" height="14" rx="1" fill="currentColor" fillOpacity={0.25} />
      <path d="M3 9.7h18M3 14.3h18M9 5v4.7M15 9.7v4.6M9 14.3V19" />
    </svg>
  );
}
