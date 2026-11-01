// Outcome emblems for the battle reports. One silhouette family, drawn in the app's line
// language (2px round-cap strokes, a 20% duotone fill) so a row reads its outcome from the
// shape alone at 20px, and the inner detail — the check, the crack, the fallen sand —
// becomes legible at 44px in the dialog header. Colour comes from the CSS class:
// only the duotone fill and the line take the outcome hue, so both themes work.

export type ReportOutcome = 'won' | 'lost' | 'conquered' | 'spy' | 'air' | 'late';

const plate = { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true, focusable: false } as const;
const duotone = { fill: 'currentColor', fillOpacity: 0.2, stroke: 'none' } as const;

const SHIELD = 'M12 3l7 2.4v5.6c0 4.6-3 7.6-7 9.2-4-1.6-7-4.6-7-9.2V5.4Z';

/** The emblem for one outcome, at any size. */
export function ReportEmblem({ outcome, size }: { outcome: ReportOutcome; size: number }) {
  return (
    <svg {...plate} width={size} height={size} className={`emb emb-${outcome}`}>
      {outcome === 'won' && (
        <>
          <path {...duotone} d={SHIELD} />
          <path d={SHIELD} />
          <path d="M9 11l3 3 3-5" />
        </>
      )}
      {outcome === 'lost' && (
        <>
          <path d={SHIELD} />
          <path d="M10.2 6.2l2.6 2.6-2 2.4 2.6 2.8" />
        </>
      )}
      {outcome === 'conquered' && (
        <>
          <path {...duotone} d="M6 4h13l-3.5 3.5L19 11H6Z" />
          <path d="M6 21V3" />
          <path d="M6 4h13l-3.5 3.5L19 11H6" />
        </>
      )}
      {outcome === 'spy' && (
        <>
          <circle {...duotone} cx="7.5" cy="15.5" r="2.8" />
          <circle {...duotone} cx="16.5" cy="15.5" r="2.8" />
          <path d="M9.2 12.6V7.4a1.5 1.5 0 0 0-3 0v5.2" />
          <path d="M17.8 12.6V7.4a1.5 1.5 0 0 0-3 0v5.2" />
          <path d="M9.2 13h5.6" />
          <circle cx="7.5" cy="15.5" r="2.8" />
          <circle cx="16.5" cy="15.5" r="2.8" />
        </>
      )}
      {outcome === 'air' && (
        <>
          <path
            {...duotone}
            d="M12 3c.9 0 1.5 1.6 1.5 3.5v2.2l6.5 4v1.8l-6.5-2v3.3l1.8 1.5v1.2L12 19.5l-3.3 1v-1.2l1.8-1.5v-3.3l-6.5 2v-1.8l6.5-4V6.5C10.5 4.6 11.1 3 12 3Z"
          />
          <path
            d="M12 3c.9 0 1.5 1.6 1.5 3.5v2.2l6.5 4v1.8l-6.5-2v3.3l1.8 1.5v1.2L12 19.5l-3.3 1v-1.2l1.8-1.5v-3.3l-6.5 2v-1.8l6.5-4V6.5C10.5 4.6 11.1 3 12 3Z"
          />
        </>
      )}
      {outcome === 'late' && (
        <>
          <path {...duotone} d="M8 21h8l-4-6.5Z" />
          <path d="M7 3h10" />
          <path d="M7 21h10" />
          <path d="M8 3v1.5c0 3 4 4 4 6.5s-4 3.5-4 6.5V21" />
          <path d="M16 3v1.5c0 3-4 4-4 6.5s4 3.5 4 6.5V21" />
        </>
      )}
    </svg>
  );
}
