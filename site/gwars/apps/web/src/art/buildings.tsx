import type { ReactNode } from 'react';
import type { BuildingId } from '@geowars/rules';
import { useTheme } from '../theme';
import { LIGHT_SPRITES } from './sprites-light';

// Building illustrations: one drafting-plate system for all 18.
//
// Every building is a flat front elevation on a 96x96 canvas with its ground line at y = 84. The
// masses are monochrome and lit from the upper left (pale lit face, mid wall, deep recess) and a
// single ink outline separates the silhouette from the dark panel behind it. There are no
// gradients, no cast shadows and no category colours, because at 28px in the build queue only the
// outline is legible.
//
// The one chromatic element per building is an accent green detail on the part that does the
// building's work: the furnace mouth, the pump, the dock light, the observation slit. So the
// accent means "this is where the building acts", and a building that is not built yet — already
// greyed out by the .unbuilt class — loses it.
//
// Recognition lives in the roofline: no two buildings share one. Nothing thinner than 2 units.

const C = {
  ground: '#2b455c', // baseline every building stands on
  ink: '#081620', // outline, apertures, recesses
  shell: '#dfe9f1', // lit face — the brightest mass
  face: '#b7c8d8', // second lit plane: roofs, awnings, wings
  wall: '#8ba3b8', // shaded wall, masonry
  deep: '#5b7391', // deepest lit plane: windows, glazing
  accent: 'var(--accent)', // the working part
} as const;

const STROKE = 2.5;

/** The baseline. Kept short so a wide silhouette does not read as a box. */
const Ground = () => <rect x="8" y="84.6" width="80" height="1.4" fill={C.ground} />;

interface WinProps {
  x: number;
  y: number;
  cols: number;
  rows: number;
  w?: number;
  h?: number;
  gapX?: number;
  gapY?: number;
  fill?: string;
}

/** Grid of windows. Each building passes its own counts so no two share a pattern. */
function Win({ x, y, cols, rows, w = 5, h = 6, gapX = 3.5, gapY = 3.5, fill = C.deep }: WinProps) {
  const out: ReactNode[] = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      out.push(<rect key={`${c}-${r}`} x={x + c * (w + gapX)} y={y + r * (h + gapY)} width={w} height={h} fill={fill} />);
    }
  }
  return <>{out}</>;
}

const ART: Record<BuildingId, () => ReactNode> = {
  // Pediment on four columns, clock in the tympanum, three steps. The most civic roofline.
  cityhall: () => (
    <>
      <Ground />
      <g fill={C.wall} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="10" y="78" width="76" height="6" />
        <rect x="16" y="72" width="64" height="6" fill={C.deep} />
        <rect x="20" y="44" width="56" height="28" />
        <polygon points="14,44 48,22 82,44" fill={C.face} />
      </g>
      <polygon points="20,44 48,27 76,44" fill={C.wall} />
      <polygon points="14,44 48,22 48,44" fill={C.face} opacity=".55" />
      {[24, 34, 58, 68].map((x) => (
        <rect key={x} x={x} y="48" width="5" height="24" fill={C.shell} />
      ))}
      <rect x="43" y="58" width="10" height="14" fill={C.accent} />
      <circle cx="48" cy="35" r="5.5" fill={C.shell} stroke={C.ink} strokeWidth="2" />
      <path d="M48 35V31.6M48 35l2.6 1.6" stroke={C.ink} strokeLinecap="round" strokeWidth="1.6" />
      <rect x="47.2" y="9" width="1.6" height="13" fill={C.wall} />
    </>
  ),

  // Barn gable, silo and three crop rows. The only building with an open field on its ground line.
  farm: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="10" y="50" width="40" height="34" fill={C.shell} />
        <polygon points="6,50 30,26 54,50" fill={C.face} />
        <rect x="58" y="42" width="18" height="42" fill={C.shell} />
        <path d="M56 42a11 10 0 0 1 22 0z" fill={C.face} />
      </g>
      <polygon points="6,50 30,26 30,50" fill={C.face} opacity=".55" />
      <rect x="58" y="54" width="18" height="2" fill={C.wall} />
      <rect x="58" y="66" width="18" height="2" fill={C.wall} />
      <rect x="23" y="60" width="14" height="24" fill={C.accent} />
      <path d="M23 60L37 84M37 60L23 84" stroke={C.shell} strokeWidth="2" />
      <path d="M78 80L92 80M78 76L92 76M78 72L92 72" stroke={C.deep} strokeLinecap="round" strokeWidth="2" />
    </>
  ),

  // Blast furnace under two unequal stacks: the only round opening in the set.
  steelmill: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="6" y="52" width="50" height="32" fill={C.shell} />
        <rect x="62" y="20" width="10" height="64" fill={C.shell} />
        <rect x="78" y="36" width="8" height="48" fill={C.face} />
      </g>
      <rect x="60" y="16" width="14" height="4" fill={C.wall} />
      <rect x="76" y="33" width="12" height="3" fill={C.wall} />
      <rect x="62" y="30" width="10" height="2" fill={C.wall} />
      <path d="M18 84V66a11 11 0 0 1 22 0v18z" fill={C.accent} />
      <path d="M18 84V66a11 11 0 0 1 22 0v18" fill="none" stroke={C.ink} strokeWidth={STROKE} />
      <path d="M24 52h20M24 60h14" stroke={C.deep} strokeLinecap="round" strokeWidth="2" />
      <rect x="60" y="58" width="10" height="26" fill={C.deep} />
    </>
  ),

  // Walking-beam pump beside a tank with a product-level window.
  oilfield: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="62" y="52" width="26" height="32" fill={C.shell} />
        <path d="M62 52a13 5 0 0 1 26 0z" fill={C.face} />
        <path d="M20 84L30 40L40 84Z" fill={C.face} />
        <rect x="8" y="80" width="44" height="4" fill={C.wall} />
      </g>
      <rect x="70" y="60" width="8" height="18" fill={C.accent} />
      <rect x="66" y="66" width="18" height="2" fill={C.wall} />
      <rect x="6" y="66" width="6" height="18" fill={C.deep} />
      <rect x="3" y="62" width="12" height="4" fill={C.wall} />
      <g transform="rotate(-9 34 40)">
        <rect x="4" y="37" width="52" height="6" fill={C.shell} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
        <path d="M4 34q-7 6 0 12z" fill={C.face} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
        <circle cx="46" cy="40" r="7" fill={C.deep} stroke={C.ink} strokeWidth="2" />
      </g>
      <path d="M34 46V62" stroke={C.deep} strokeWidth="2" />
    </>
  ),

  // Barrel roof over a full-width roller door: the widest silhouette, sheeted all the way down.
  warehouse: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="8" y="52" width="80" height="32" fill={C.shell} />
        <path d="M4 54Q48 18 92 54Z" fill={C.face} />
      </g>
      <path d="M4 54Q48 20 48 54Z" fill={C.shell} opacity=".45" />
      <rect x="32" y="56" width="32" height="3" fill={C.accent} />
      <rect x="32" y="59" width="32" height="25" fill={C.ink} />
      <path d="M32 66h32M32 72h32M32 78h32" stroke={C.wall} strokeWidth="1.6" />
      <rect x="14" y="68" width="12" height="16" fill={C.deep} />
      <path d="M14 68l12 16M26 68L14 84" stroke={C.wall} strokeWidth="1.6" />
    </>
  ),

  // Three blocks of unequal height: the only stepped skyline in the set.
  housing: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="6" y="52" width="24" height="32" fill={C.face} />
        <rect x="32" y="30" width="26" height="54" fill={C.shell} />
        <rect x="60" y="54" width="26" height="30" fill={C.wall} />
      </g>
      <rect x="4" y="49" width="28" height="3" fill={C.deep} />
      <rect x="30" y="27" width="30" height="3" fill={C.deep} />
      <rect x="58" y="51" width="30" height="3" fill={C.deep} />
      <Win x={10} y={57} cols={2} rows={3} w={6} h={6} fill={C.deep} />
      <Win x={37} y={35} cols={2} rows={4} w={6} h={6} fill={C.deep} />
      <Win x={65} y={59} cols={2} rows={2} w={6} h={6} fill={C.ink} />
      <rect x="40" y="70" width="10" height="14" fill={C.accent} />
    </>
  ),

  // Low armoured shell, one horizontal observation slit, blast door.
  bunker: () => (
    <>
      <Ground />
      <path d="M6 84V68Q8 42 48 42Q88 42 90 68V84Z" fill={C.shell} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
      <path d="M6 84V68Q8 42 48 42Q36 50 32 84Z" fill={C.face} opacity=".6" />
      <rect x="22" y="55" width="52" height="8" rx="2" fill={C.ink} />
      <rect x="26" y="57.5" width="18" height="3" fill={C.accent} />
      <path d="M38 84V73q0-7 10-7t10 7v11z" fill={C.ink} />
      <path d="M48 66v18" stroke={C.wall} strokeWidth="1.6" />
    </>
  ),

  // Tiered block with a mast: the only silhouette with something above the roofline that is not a
  // stack, a dome or a dish.
  commandcenter: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="8" y="54" width="80" height="30" fill={C.shell} />
        <rect x="24" y="42" width="48" height="12" fill={C.face} />
      </g>
      <path d="M43.5 42L46.5 13M52.5 42L49.5 13" stroke={C.wall} strokeWidth="1.8" />
      <path d="M44.6 34h6.8M45.6 25h4.8M46.6 18h2.8" stroke={C.wall} strokeWidth="1.6" />
      <circle cx="48" cy="10" r="3" fill={C.accent} />
      <ellipse cx="72" cy="46" rx="10" ry="5" transform="rotate(-24 72 46)" fill={C.deep} stroke={C.ink} strokeWidth="2" />
      <rect x="16" y="62" width="26" height="8" fill={C.deep} />
      <rect x="54" y="68" width="10" height="16" fill={C.ink} />
      <path d="M16 74h26" stroke={C.wall} strokeWidth="1.6" />
    </>
  ),

  // Two dormitory sheds behind a parade door — pitched roofs with no wall above them.
  barracks: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="4" y="58" width="40" height="26" fill={C.shell} />
        <polygon points="0,58 24,38 48,58" fill={C.face} />
        <rect x="52" y="64" width="40" height="20" fill={C.wall} />
        <polygon points="48,64 72,44 96,64" fill={C.face} />
      </g>
      <polygon points="0,58 24,38 24,58" fill={C.face} opacity=".5" />
      <rect x="18" y="70" width="12" height="14" fill={C.accent} />
      <path d="M18 70l12 14M30 70L18 84" stroke={C.shell} strokeWidth="2" />
      <Win x={58} y={70} cols={2} rows={1} w={7} h={7} fill={C.deep} />
      <Win x={76} y={70} cols={2} rows={1} w={7} h={7} fill={C.deep} />
    </>
  ),

  // Stepped laboratory with an observatory dome and an instrument mast.
  researchcenter: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="10" y="54" width="76" height="30" fill={C.shell} />
        <rect x="32" y="42" width="32" height="12" fill={C.face} />
        <path d="M36 42a12 11 0 0 1 24 0z" fill={C.wall} />
      </g>
      <rect x="47" y="18" width="2.5" height="13" fill={C.wall} />
      <circle cx="48.2" cy="16" r="3" fill={C.accent} />
      <rect x="16" y="60" width="64" height="10" fill={C.deep} />
      <path d="M32 60v10M48 60v10M64 60v10" stroke={C.shell} strokeWidth="2" />
      <rect x="44" y="74" width="8" height="10" fill={C.ink} />
    </>
  ),

  // Open canopy on two posts over two goods counters — the only silhouette you can see through.
  market: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <polygon points="2,42 94,42 86,28 10,28" fill={C.face} />
        <rect x="8" y="42" width="4" height="42" fill={C.wall} />
        <rect x="84" y="42" width="4" height="42" fill={C.wall} />
        <rect x="14" y="64" width="30" height="20" fill={C.shell} />
        <rect x="52" y="64" width="30" height="20" fill={C.shell} />
      </g>
      <rect x="2" y="42" width="92" height="3" fill={C.wall} />
      <rect x="14" y="62" width="30" height="3" fill={C.deep} />
      <rect x="52" y="62" width="30" height="3" fill={C.deep} />
      {[19, 26, 33].map((x) => (
        <circle key={x} cx={x} cy="57" r="3" fill={C.deep} />
      ))}
      {[57, 64, 71].map((x) => (
        <circle key={x} cx={x} cy="57" r="3" fill={C.deep} />
      ))}
      <rect x="17" y="68" width="8" height="12" fill={C.accent} />
    </>
  ),

  // Two crenellated towers, a curtain wall and a portcullis: the only fully symmetrical silhouette.
  fortifications: () => (
    <>
      <Ground />
      <g fill={C.wall} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="8" y="62" width="80" height="22" />
        <rect x="2" y="42" width="20" height="42" fill={C.shell} />
        <rect x="74" y="42" width="20" height="42" fill={C.shell} />
      </g>
      {[12, 28, 44, 60, 76].map((x) => (
        <rect key={x} x={x} y="56" width="8" height="7" fill={C.wall} stroke={C.ink} strokeWidth="2" />
      ))}
      {[4, 12, 18].map((x) => (
        <rect key={x} x={x} y="36" width="5" height="7" fill={C.shell} stroke={C.ink} strokeWidth="2" />
      ))}
      {[76, 84, 90].map((x) => (
        <rect key={x} x={x} y="36" width="5" height="7" fill={C.shell} stroke={C.ink} strokeWidth="2" />
      ))}
      <path d="M8 70h80M8 78h80M28 62v22M48 62v22M68 62v22" stroke={C.deep} strokeWidth="1.6" />
      <path d="M38 84V72q0-10 10-10t10 10v12z" fill={C.ink} />
      <path d="M40 70v14M44 68v16M48 67v17M52 68v16M56 70v14" stroke={C.accent} strokeWidth="1.6" />
    </>
  ),

  // Ward block with a plain cross sign on a plate: the only cross in the set.
  hospital: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="14" y="50" width="68" height="34" fill={C.shell} />
        <rect x="10" y="46" width="76" height="4" fill={C.face} />
      </g>
      <rect x="45" y="54" width="6" height="20" fill={C.accent} />
      <rect x="38" y="61" width="20" height="6" fill={C.accent} />
      <rect x="20" y="58" width="12" height="10" fill={C.deep} />
      <rect x="64" y="58" width="12" height="10" fill={C.deep} />
      <rect x="44" y="74" width="8" height="10" fill={C.ink} />
      <path d="M40 76h16" stroke={C.accent} strokeWidth="2" />
    </>
  ),

  // Sawtooth assembly hall beside one tall stack — distinct from Steel Mill's round furnace mouth.
  factory: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="6" y="50" width="62" height="34" fill={C.shell} />
        <path d="M6 50V36l11 14V36l11 14V36l11 14V36l11 14V36l11 14V50Z" fill={C.face} />
        <rect x="74" y="22" width="10" height="62" fill={C.shell} />
      </g>
      <rect x="72" y="19" width="14" height="4" fill={C.wall} />
      <rect x="74" y="34" width="10" height="2" fill={C.wall} />
      <rect x="12" y="62" width="26" height="2.5" fill={C.accent} />
      <rect x="12" y="64.5" width="26" height="19.5" fill={C.ink} />
      <path d="M12 71h26M12 77h26" stroke={C.wall} strokeWidth="1.6" />
      <Win x={46} y={58} cols={2} rows={2} w={7} h={6} fill={C.deep} />
    </>
  ),

  // Hangar arch, control tower and a marked runway along the ground line.
  airbase: () => (
    <>
      <Ground />
      <polygon points="0,84 96,84 84,75 12,75" fill={C.wall} />
      <path d="M48 84v-3M48 77v-2" stroke={C.shell} strokeWidth="2" />
      <path d="M14 76V58Q14 38 40 38Q66 38 66 58V76Z" fill={C.shell} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
      <path d="M23 76V60Q23 49 40 49Q57 49 57 60V76Z" fill={C.ink} />
      <path d="M28 58h20" stroke={C.accent} strokeWidth="2.5" />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="72" y="46" width="10" height="30" fill={C.shell} />
        <rect x="68" y="36" width="18" height="10" fill={C.face} />
      </g>
      <rect x="70" y="38" width="14" height="4" fill={C.deep} />
      <rect x="76.6" y="28" width="2" height="8" fill={C.wall} />
      <circle cx="77.6" cy="26" r="2.6" fill={C.wall} />
    </>
  ),

  // Quay crane over a berthed vessel: the only silhouette that is two separate objects.
  port: () => (
    <>
      <Ground />
      <rect x="0" y="78" width="96" height="6" fill={C.deep} />
      <path d="M4 88q6-4 12 0M24 88q6-4 12 0M44 88q6-4 12 0" stroke={C.wall} strokeLinecap="round" strokeWidth="1.6" />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="2" y="68" width="40" height="10" fill={C.wall} />
        <rect x="12" y="22" width="4" height="46" fill={C.shell} />
        <rect x="8" y="20" width="44" height="4" fill={C.face} />
      </g>
      <path d="M12 32L44 22M12 44l10-9" stroke={C.wall} strokeWidth="1.6" />
      <path d="M46 24v18" stroke={C.wall} strokeWidth="1.6" />
      <rect x="38" y="42" width="16" height="10" fill={C.accent} />
      <path d="M56 78L94 78L88 66L62 66Z" fill={C.face} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
      <rect x="64" y="56" width="10" height="10" fill={C.shell} />
      <rect x="78" y="58" width="8" height="8" fill={C.wall} />
    </>
  ),

  // Angled dish on a braced mast over an equipment hut: the only silhouetted dish.
  radar: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="8" y="64" width="22" height="20" fill={C.shell} />
        <rect x="6" y="61" width="26" height="3" fill={C.face} />
      </g>
      <rect x="12" y="68" width="7" height="6" fill={C.deep} />
      <rect x="22" y="68" width="6" height="6" fill={C.deep} />
      <path d="M40 84L48 54M58 84L50 54M42 71h14" stroke={C.wall} strokeWidth="3" />
      <rect x="44" y="46" width="8" height="9" fill={C.face} stroke={C.ink} strokeWidth="2" />
      <g transform="rotate(-20 48 34)">
        <path d="M22 36a26 14 0 0 0 52 0z" fill={C.shell} stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE} />
        <path d="M29 36a19 9 0 0 0 38 0" fill="none" stroke={C.wall} strokeWidth="2" />
        <path d="M48 36V20" stroke={C.wall} strokeWidth="2" />
        <circle cx="48" cy="18" r="3" fill={C.accent} />
      </g>
    </>
  ),

  // Domed chamber with symmetrical wings: monumental but still a different roofline to City Hall.
  parliament: () => (
    <>
      <Ground />
      <g stroke={C.ink} strokeLinejoin="round" strokeWidth={STROKE}>
        <rect x="8" y="80" width="80" height="4" fill={C.wall} />
        <rect x="2" y="60" width="24" height="20" fill={C.face} />
        <rect x="70" y="60" width="24" height="20" fill={C.wall} />
        <rect x="26" y="52" width="44" height="28" fill={C.shell} />
        <rect x="34" y="44" width="28" height="8" fill={C.face} />
        <path d="M32 44a16 14 0 0 1 32 0z" fill={C.face} />
      </g>
      <path d="M32 44a16 14 0 0 1 16 14V44z" fill={C.shell} opacity=".5" />
      <path d="M48 30V20" stroke={C.wall} strokeWidth="2" />
      <circle cx="48" cy="18" r="3" fill={C.accent} />
      {[32, 42, 54, 64].map((x) => (
        <rect key={x} x={x} y="58" width="4" height="22" fill={C.face} />
      ))}
      <rect x="16" y="66" width="7" height="9" fill={C.deep} />
      <rect x="73" y="66" width="7" height="9" fill={C.deep} />
    </>
  ),
};

interface Props {
  id: BuildingId;
  size?: number;
  title?: string;
  className?: string;
}

/**
 * Illustration of a building; scales to any size. Decorative unless a title is given.
 * The light theme uses the Kombai "Build hub" sprites (dark masses for cream surfaces); the dark
 * theme keeps the drafting-plate elevations drawn above (pale masses for dark panels).
 */
export function BuildingIcon({ id, size = 48, title, className }: Props) {
  const { theme } = useTheme();
  return (
    <svg
      viewBox="0 0 96 96"
      width={size}
      height={size}
      className={className}
      role={title ? 'img' : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : true}
      focusable="false"
    >
      {title && <title>{title}</title>}
      {theme === 'light' ? <g dangerouslySetInnerHTML={{ __html: LIGHT_SPRITES[id] }} /> : ART[id]()}
    </svg>
  );
}
