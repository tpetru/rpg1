import type { ReactNode } from 'react';
import type { UnitId } from '@geowars/rules';

// Unit glyphs: one modern line family — 2px round-cap strokes, a duotone body and a single
// accent detail (the weapon, the goggle slit, the coat lapel, the bomb, the tie) — the same
// language as the map action icons and the report emblems. The accent takes --accent, so it
// shifts coral in the light theme and green in the dark one. The nine silhouettes are built
// to stay apart at 18px: round helmet + upright rifle vs flat helmet + canted gun vs beret,
// shield, quadcopter, fedora vs tie, and so on.

const tone = { fill: 'currentColor', fillOpacity: 0.18, stroke: 'none' } as const;
const acc = { stroke: 'var(--accent)' } as const;

const ART: Record<UnitId, ReactNode> = {
  /** Round helmet, brim, and a rifle held upright at the shoulder. */
  rifleman: (
    <>
      <path {...tone} d="M6 13.5c0-1.4 1.8-2.4 4-2.4s4 1 4 2.4v6.5H6z" />
      <path d="M5.5 10a5 5 0 0 1 10 0" />
      <path d="M4.5 10h12" />
      <path d="M6 13.5c0-1.4 1.8-2.4 4-2.4s4 1 4 2.4v6.5H6z" />
      <path {...acc} d="M15.5 4.5v14.5" />
      <path {...acc} d="M14 8.5h3" />
    </>
  ),
  /** Flat tactical helmet with a goggle slit, weapon canted across the chest. */
  assault: (
    <>
      <path d="M7 10l1-4.5h8L17 10" />
      <path d="M6 10h12" />
      <path {...acc} d="M8.5 8h7" />
      <path {...tone} d="M7.5 13.5c0-1.4 2-2.4 4.5-2.4s4.5 1 4.5 2.4v6.5h-9z" />
      <path d="M7.5 13.5c0-1.4 2-2.4 4.5-2.4s4.5 1 4.5 2.4v6.5h-9z" />
      <path {...acc} d="M9 18.5l7-6.5" />
    </>
  ),
  /** Soft beret with a stub, rifle with a bayonet held upright. */
  veteran: (
    <>
      <path d="M6.5 9.5c0-3 2.3-4.6 5.5-4.6s5.5 1.6 5.5 4.6" />
      <path d="M6.5 9.5h11" />
      <path {...tone} d="M7.5 13.5c0-1.4 2-2.4 4.5-2.4s4.5 1 4.5 2.4v6.5h-9z" />
      <path d="M7.5 13.5c0-1.4 2-2.4 4.5-2.4s4.5 1 4.5 2.4v6.5h-9z" />
      <path {...acc} d="M16 8v11" />
      <path {...acc} d="M14.5 12h3" />
      <path {...acc} d="M16 8l1.6-2.6" />
    </>
  ),
  /** Helmet with a visor slit, standing behind a full riot shield. */
  guardian: (
    <>
      <path d="M7 10a5 5 0 0 1 10 0" />
      <path d="M6 10h12" />
      <path {...acc} d="M12 6.6V10" />
      <path {...tone} d="M7.5 13h9a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z" />
      <path d="M7.5 13h9a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z" />
    </>
  ),
  /** Hull, turret and barrel over a tracked bogie. */
  tank: (
    <>
      <path {...acc} d="M13 10h7" />
      <path {...tone} d="M9 8h5.5a1 1 0 0 1 1 1v2.5H9z" />
      <path d="M9 8h5.5a1 1 0 0 1 1 1v2.5H9z" />
      <path d="M4 12h15v3.5H4z" />
      <path d="M3.5 15.5h17a2.2 2.2 0 0 1 0 4.4H3.5a2.2 2.2 0 0 1 0-4.4z" />
      <path {...acc} d="M7.5 16.8v1.8M12 16.8v1.8M16.5 16.8v1.8" strokeWidth={1.6} />
    </>
  ),
  /** Quadcopter: body, four arms, spinning rotor bars. */
  drone: (
    <>
      <path d="M9.9 9.9 7 7M14.1 9.9 17 7M9.9 14.1 7 17M14.1 14.1 17 17" />
      <circle {...tone} cx="12" cy="12" r="2.6" />
      <circle cx="12" cy="12" r="2.6" />
      <path {...acc} d="M4.5 6.5h5M14.5 6.5h5M4.5 17.5h5M14.5 17.5h5" />
    </>
  ),
  /** Fedora over a trench-coat collar. */
  spy: (
    <>
      <path d="M8.5 9V6.8A1.8 1.8 0 0 1 10.3 5h3.4a1.8 1.8 0 0 1 1.8 1.8V9" />
      <path d="M5 9.5h14" />
      <path {...tone} d="M7.5 20.5c0-3.5 2-5.8 4.5-5.8s4.5 2.3 4.5 5.8" />
      <path d="M7.5 20.5c0-3.5 2-5.8 4.5-5.8s4.5 2.3 4.5 5.8" />
      <path {...acc} d="M9.5 15l2.5 2.5 2.5-2.5" />
    </>
  ),
  /** Swept-wing airframe with a bomb falling clear of it. */
  bomber: (
    <>
      <path {...tone} d="M3 12c4-1.2 12-1.2 16 0l1.5.4-1.5.5c-4 1.2-12 1.2-16 0z" />
      <path d="M3 12c4-1.2 12-1.2 16 0l1.5.4-1.5.5c-4 1.2-12 1.2-16 0z" />
      <path d="M9 11.5 7 6h2l3 5.3" />
      <path d="M9 13 7 18.5h2l3-5.3" />
      <path {...acc} d="M17.5 15.6a2.4 2.4 0 1 1 0 4.8 2.4 2.4 0 0 1 0-4.8Z" />
    </>
  ),
  /** Bust with a tie. */
  president: (
    <>
      <circle {...tone} cx="12" cy="7.5" r="3.6" />
      <circle cx="12" cy="7.5" r="3.6" />
      <path d="M6 20.5c0-3.6 2.6-6 6-6s6 2.4 6 6" />
      <path {...acc} d="M12 14.5l-1.3 1.6L12 20l1.3-3.9z" />
    </>
  ),
};

interface Props {
  unit: UnitId;
  size?: number;
  className?: string;
  title?: string;
}

export function UnitIcon({ unit, size = 28, className, title }: Props) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {title && <title>{title}</title>}
      {ART[unit]}
    </svg>
  );
}
