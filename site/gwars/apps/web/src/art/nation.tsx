import { useId, type ReactNode } from 'react';

// Every nation gets a coat of arms and a flag drawn from its name. The same name always gives the
// same design (letter case ignored, as names are unique that way), so nobody has to store or upload
// anything. Designs follow heraldry's main rule of contrast: colour next to metal, never colour on colour.

const COLORS = ['#c8312b', '#1f4fa3', '#1f8a4c', '#6a3a96', '#222a33', '#e07b22', '#16929b'] as const;
const METALS = ['#f4f7fa', '#f2c14e'] as const;
const OUTLINE = '#0b1219';

const PATTERNS = ['solid', 'pale', 'fess', 'bend', 'quarterly', 'cross', 'saltire', 'chevron', 'pales', 'fesses'] as const;
const CHARGES = ['star', 'sun', 'crescent', 'tower', 'wheat', 'wave', 'mountain', 'crown', 'diamond'] as const;
export type Pattern = (typeof PATTERNS)[number];
export type Charge = (typeof CHARGES)[number];

export interface NationDesign {
  pattern: Pattern;
  charge: Charge;
  /** Main colour of the field */
  primary: string;
  /** Second tincture used by the pattern */
  secondary: string;
  /** Colour of the symbol */
  symbol: string;
}

function hash(text: string): number {
  let h = 2166136261;
  for (const ch of text.toLowerCase()) {
    h ^= ch.codePointAt(0)!;
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

/** Small seeded generator (mulberry32): a stream of repeatable numbers in [0, 1). */
function rng(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function nationDesign(name: string): NationDesign {
  const next = rng(hash(name));
  const pick = <T,>(list: readonly T[]) => list[Math.floor(next() * list.length)];

  const primary = pick(COLORS);
  const pattern = pick(PATTERNS);
  const charge = pick(CHARGES);
  // Pattern stripes: mostly a metal against the colour; sometimes a second colour.
  const secondColor = pick(COLORS.filter((c) => c !== primary));
  const secondary = next() < 0.72 ? pick(METALS) : secondColor;
  // The symbol is a metal that differs from the second tincture whenever possible.
  const otherMetals = METALS.filter((m) => m !== secondary);
  const symbol = pick(otherMetals.length > 0 ? otherMetals : METALS);
  return { pattern, charge, primary, secondary, symbol };
}

/** Pattern drawn inside a w x h box. Returns the shapes and where the symbol should sit. */
function field(d: NationDesign, w: number, h: number): { shapes: ReactNode; cx: number; cy: number } {
  const { pattern, primary: A, secondary: B } = d;
  const base = <rect width={w} height={h} fill={A} />;
  const mid = { cx: w / 2, cy: h / 2 };
  const band = Math.min(w, h) * 0.2;

  switch (pattern) {
    case 'solid':
      return { shapes: base, ...mid };
    case 'pale':
      return { shapes: <>{base}<rect x={w / 2} width={w / 2} height={h} fill={B} /></>, ...mid };
    case 'fess':
      return { shapes: <>{base}<rect y={h / 2} width={w} height={h / 2} fill={B} /></>, ...mid };
    case 'bend':
      return { shapes: <>{base}<polygon points={`${w},0 ${w},${h} 0,${h}`} fill={B} /></>, ...mid };
    case 'quarterly':
      return {
        shapes: (
          <>
            {base}
            <rect x={w / 2} width={w / 2} height={h / 2} fill={B} />
            <rect y={h / 2} width={w / 2} height={h / 2} fill={B} />
          </>
        ),
        ...mid,
      };
    case 'cross': {
      const x = w * 0.4;
      return {
        shapes: (
          <>
            {base}
            <rect x={x - band / 2} width={band} height={h} fill={B} />
            <rect y={h / 2 - band / 2} width={w} height={band} fill={B} />
          </>
        ),
        cx: x,
        cy: h / 2,
      };
    }
    case 'saltire':
      return {
        shapes: (
          <>
            {base}
            <path d={`M0 0 L${w} ${h} M${w} 0 L0 ${h}`} stroke={B} strokeWidth={band * 1.05} />
          </>
        ),
        ...mid,
      };
    case 'chevron':
      return {
        shapes: (
          <>
            {base}
            <polygon points={`0,${h * 0.64} ${w / 2},${h * 0.2} ${w},${h * 0.64} ${w},${h * 0.86} ${w / 2},${h * 0.42} 0,${h * 0.86}`} fill={B} />
          </>
        ),
        cx: w / 2,
        cy: h * 0.62,
      };
    case 'pales':
      return { shapes: <>{base}<rect x={w / 3} width={w / 3} height={h} fill={B} /></>, ...mid };
    case 'fesses':
      return { shapes: <>{base}<rect y={h / 3} width={w} height={h / 3} fill={B} /></>, ...mid };
  }
}

/** Symbols are drawn in a unit box (radius 1) so one outline width fits them all. */
function symbol(charge: Charge, fill: string): ReactNode {
  const line = { stroke: OUTLINE, strokeWidth: 0.12, strokeLinejoin: 'round' as const, paintOrder: 'stroke' as const };
  switch (charge) {
    case 'star': {
      const pts = Array.from({ length: 10 }, (_, i) => {
        const a = (Math.PI / 5) * i - Math.PI / 2;
        const r = i % 2 === 0 ? 1 : 0.42;
        return `${(Math.cos(a) * r).toFixed(3)},${(Math.sin(a) * r).toFixed(3)}`;
      }).join(' ');
      return <polygon points={pts} fill={fill} {...line} />;
    }
    case 'sun': {
      const rays = Array.from({ length: 12 }, (_, i) => {
        const a = (Math.PI / 6) * i;
        const p = (r: number, da: number) => `${(Math.cos(a + da) * r).toFixed(3)},${(Math.sin(a + da) * r).toFixed(3)}`;
        return <polygon key={i} points={`${p(0.55, -0.13)} ${p(1, 0)} ${p(0.55, 0.13)}`} fill={fill} {...line} />;
      });
      return (
        <>
          {rays}
          <circle r="0.5" fill={fill} {...line} />
        </>
      );
    }
    case 'crescent':
      return <path d="M0.15 -0.95 A1 1 0 1 0 0.15 0.95 A0.74 0.74 0 1 1 0.15 -0.95 Z" fill={fill} {...line} />;
    case 'tower':
      return (
        <>
          <path d="M-0.6 1 V-0.35 H-0.72 V-0.95 H-0.45 V-0.72 H-0.17 V-0.95 H0.17 V-0.72 H0.45 V-0.95 H0.72 V-0.35 H0.6 V1 Z" fill={fill} {...line} />
          <path d="M-0.2 1 V0.3 Q-0.2 0 0 0 Q0.2 0 0.2 0.3 V1 Z" fill={OUTLINE} />
        </>
      );
    case 'wheat':
      return (
        <>
          <path d="M0 1 V-0.9" stroke={OUTLINE} strokeWidth="0.34" strokeLinecap="round" />
          <path d="M0 1 V-0.9" stroke={fill} strokeWidth="0.14" strokeLinecap="round" />
          {[-0.55, -0.15, 0.25].map((y) => (
            <g key={y}>
              <ellipse cx="-0.3" cy={y} rx="0.34" ry="0.14" transform={`rotate(-38 -0.3 ${y})`} fill={fill} {...line} />
              <ellipse cx="0.3" cy={y} rx="0.34" ry="0.14" transform={`rotate(38 0.3 ${y})`} fill={fill} {...line} />
            </g>
          ))}
          <ellipse cx="0" cy="-0.88" rx="0.13" ry="0.24" fill={fill} {...line} />
        </>
      );
    case 'wave':
      return (
        <>
          {[-0.55, 0, 0.55].map((y) => (
            <path key={y} d={`M-1 ${y} Q-0.5 ${y - 0.4} 0 ${y} T1 ${y}`} fill="none" stroke={OUTLINE} strokeWidth="0.38" strokeLinecap="round" />
          ))}
          {[-0.55, 0, 0.55].map((y) => (
            <path key={y} d={`M-1 ${y} Q-0.5 ${y - 0.4} 0 ${y} T1 ${y}`} fill="none" stroke={fill} strokeWidth="0.18" strokeLinecap="round" />
          ))}
        </>
      );
    case 'mountain':
      return (
        <>
          <polygon points="-1,0.85 -0.3,-0.55 0.15,0.2 0.4,-0.2 1,0.85" fill={fill} {...line} />
          <polygon points="-0.46,-0.25 -0.3,-0.55 -0.14,-0.25 -0.3,-0.12" fill={OUTLINE} opacity=".35" />
        </>
      );
    case 'crown':
      return (
        <>
          <path d="M-0.9 0.75 L-0.95 -0.45 L-0.45 0.05 L0 -0.75 L0.45 0.05 L0.95 -0.45 L0.9 0.75 Z" fill={fill} {...line} />
          <rect x="-0.9" y="0.5" width="1.8" height="0.34" fill={fill} {...line} />
          {[-0.95, 0, 0.95].map((x, i) => (
            <circle key={x} cx={x} cy={i === 1 ? -0.8 : -0.5} r="0.14" fill={fill} {...line} />
          ))}
        </>
      );
    case 'diamond':
      return <polygon points="0,-1 0.75,0 0,1 -0.75,0" fill={fill} {...line} />;
  }
}

interface EmblemProps {
  name: string;
  /** Height in px; the shield is 5:6. */
  size?: number;
  className?: string;
  title?: string;
}

const SHIELD = 'M6 6 H74 V50 Q74 78 40 93 Q6 78 6 50 Z';

/** Coat of arms: a shield with the nation's pattern and symbol. */
export function NationEmblem({ name, size = 40, className, title }: EmblemProps) {
  const id = useId().replace(/[^a-zA-Z0-9]/g, '');
  const design = nationDesign(name);
  const { shapes, cx, cy } = field(design, 80, 96);
  return (
    <svg
      viewBox="0 0 80 96"
      width={(size * 80) / 96}
      height={size}
      className={className}
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {title && <title>{title}</title>}
      <defs>
        <clipPath id={`shield${id}`}>
          <path d={SHIELD} />
        </clipPath>
      </defs>
      <path d={SHIELD} fill="#000" opacity=".3" transform="translate(1.5 2.5)" />
      <g clipPath={`url(#shield${id})`}>
        {shapes}
        <path d="M6 6 H74 V30 Q40 40 6 30 Z" fill="#fff" opacity=".1" />
      </g>
      <g transform={`translate(${cx} ${cy}) scale(17)`}>{symbol(design.charge, design.symbol)}</g>
      <path d={SHIELD} fill="none" stroke={OUTLINE} strokeWidth="3" strokeLinejoin="round" />
      <path d="M8.5 8.5 H71.5" stroke="#fff" strokeWidth="1" opacity=".35" />
    </svg>
  );
}

interface FlagProps {
  name: string;
  /** Width in px; the flag is 3:2. */
  width?: number;
  className?: string;
  title?: string;
}

/** Flag with the same pattern and symbol as the coat of arms. */
export function NationFlag({ name, width = 90, className, title }: FlagProps) {
  const id = useId().replace(/[^a-zA-Z0-9]/g, '');
  const design = nationDesign(name);
  const { shapes, cx, cy } = field(design, 90, 60);
  return (
    <svg
      viewBox="0 0 90 60"
      width={width}
      height={(width * 60) / 90}
      className={className}
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {title && <title>{title}</title>}
      <defs>
        <clipPath id={`flag${id}`}>
          <rect x="2" y="2" width="86" height="56" rx="3" />
        </clipPath>
      </defs>
      <rect x="3" y="4" width="86" height="56" rx="3" fill="#000" opacity=".3" />
      <g clipPath={`url(#flag${id})`}>
        <g transform="translate(2 2) scale(0.9556 0.9333)">{shapes}</g>
        <rect x="2" y="2" width="86" height="12" fill="#fff" opacity=".1" />
      </g>
      <g transform={`translate(${2 + cx * 0.9556} ${2 + cy * 0.9333}) scale(13.5)`}>{symbol(design.charge, design.symbol)}</g>
      <rect x="2" y="2" width="86" height="56" rx="3" fill="none" stroke={OUTLINE} strokeWidth="2.4" />
    </svg>
  );
}
