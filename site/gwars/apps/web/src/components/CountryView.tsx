import { useMemo } from 'react';
import { cellToLatLng } from 'h3-js';
import {
  BUILDING_IDS,
  RESOURCES,
  housingCapacity,
  plannedLevels,
  populationUsed,
  productionRates,
  type BuildingLevels,
  type CountryRef,
  type HexRow,
  type OwnSettlementDto,
  type ResourceBag,
  type WorldSettings,
} from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';

// The country view: every settlement the nation holds, laid out as a schematic of where they
// actually are. Each card carries the whole building set at a glance (all 18, unbuilt dimmed), so
// the screen answers "what does my nation own and what is built where" without opening settlements
// one at a time. It is read-only: a card opens that settlement in the map view.

const BOX_W = 1060;
const CARD_W = 236;
/** Nominal card height, used to space rows. Cards are allowed to grow a little taller. */
const CARD_H = 186;
const ROW_GAP = 30;
const BOX_PAD_TOP = 30;

interface Node {
  settlement: OwnSettlementDto;
  /** Horizontal position inside the padded box, 0..1. */
  fx: number;
  /** Vertical position in pixels: the top of the card. */
  top: number;
  /** Card centre in pixels, used to draw the neighbour links. */
  cy: number;
}

interface Schematic {
  nodes: Node[];
  edges: [Node, Node][];
  height: number;
}

/**
 * Places each settlement by where it actually is: rows run north to south, and inside a row
 * settlements run west to east. Cards are far bigger than a hex, so a literal projection would pile
 * neighbours on top of each other and push the edge ones out of the box; a geographic lattice keeps
 * the reading of a map and guarantees that no card overlaps another.
 */
function buildSchematic(settlements: OwnSettlementDto[]): Schematic {
  const count = settlements.length;
  if (count === 0) return { nodes: [], edges: [], height: 0 };

  const cols = Math.min(3, count);
  const rows = Math.max(1, Math.ceil(count / cols));

  const geo = settlements.map((settlement) => {
    const [lat, lng] = cellToLatLng(settlement.h3);
    return { settlement, lat, lng };
  });

  // Reading order: northernmost first, westernmost first inside each row.
  const ordered = [...geo].sort((a, b) => b.lat - a.lat || a.lng - b.lng);

  const nodes: Node[] = [];
  for (let row = 0; row < rows; row++) {
    const inRow = ordered.slice(row * cols, row * cols + cols);
    // A short last row is centred under the full rows above it.
    const offset = (cols - inRow.length) / 2;
    const top = BOX_PAD_TOP + row * (CARD_H + ROW_GAP);
    inRow.forEach((item, col) => {
      nodes.push({
        settlement: item.settlement,
        fx: (offset + col + 0.5) / cols,
        top,
        cy: top + CARD_H / 2,
      });
    });
  }

  // Nearest-neighbour spanning tree: which settlements are neighbours is worth seeing.
  const edges: [Node, Node][] = [];
  if (nodes.length > 1) {
    const linked = new Set<number>([0]);
    while (linked.size < nodes.length) {
      let best: { d: number; from: number; to: number } | null = null;
      for (const from of linked) {
        for (let to = 0; to < nodes.length; to++) {
          if (linked.has(to)) continue;
          const a = nodes[from];
          const b = nodes[to];
          const d = Math.hypot((b.fx - a.fx) * BOX_W, b.cy - a.cy);
          if (!best || d < best.d) best = { d, from, to };
        }
      }
      if (!best) break;
      edges.push([nodes[best.from], nodes[best.to]]);
      linked.add(best.to);
    }
  }

  return { nodes, edges, height: BOX_PAD_TOP * 2 + rows * CARD_H + (rows - 1) * ROW_GAP };
}

/** Fixed half-card inset, so a card in a corner always stays inside the box. */
const placeX = (fx: number) => `calc(${CARD_W / 2 + 6}px + (100% - ${CARD_W + 12}px) * ${fx.toFixed(5)})`;

interface Props {
  nation: string;
  settlements: OwnSettlementDto[];
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  settings: WorldSettings;
  onOpen: (settlement: OwnSettlementDto) => void;
}

export function CountryView({ nation, settlements, hexes, countries, settings, onOpen }: Props) {
  const { t, buildingName, countryName, hexName } = useI18n();

  const schematic = useMemo(() => buildSchematic(settlements), [settlements]);

  /** Per-settlement and nation-wide figures, using the same rules the server enforces. */
  const stats = useMemo(() => {
    let points = 0;
    let popUsed = 0;
    let popCap = 0;
    const rates: ResourceBag = { food: 0, steel: 0, oil: 0 };
    const levels = Object.fromEntries(BUILDING_IDS.map((id) => [id, 0])) as BuildingLevels;
    const holders = Object.fromEntries(BUILDING_IDS.map((id) => [id, 0])) as Record<string, number>;

    for (const s of settlements) {
      points += s.points;
      popUsed += populationUsed(plannedLevels(s.levels, s.queue));
      popCap += housingCapacity(s.levels.housing);
      const r = productionRates(s.levels, s.profile, settings.speed);
      for (const resource of RESOURCES) rates[resource] += r[resource];
      for (const id of BUILDING_IDS) {
        levels[id] += s.levels[id];
        if (s.levels[id] > 0) holders[id] += 1;
      }
    }

    return { points, popUsed, popCap, rates, levels, holders };
  }, [settlements, settings.speed]);

  const byCountry = useMemo(() => {
    const map = new Map<string, number>();
    for (const s of settlements) map.set(s.countryCode, (map.get(s.countryCode) ?? 0) + 1);
    return [...map.entries()].sort((a, b) => b[1] - a[1]);
  }, [settlements]);

  return (
    <section className="country" aria-label={t('view.overview')}>
      <header className="country-head">
        <div className="country-id">
          <NationEmblem name={nation} size={54} title={nation} />
          <div>
            <h1 className="country-name">{nation}</h1>
            <div className="meta-row">
              <span>{t('country.settlements', { n: settlements.length })}</span>
              <span className="sep">/</span>
              <span className="mono">{t('points', { n: fmtInt(stats.points) })}</span>
              <span className="sep">/</span>
              <span>
                {t('panel.population')}{' '}
                <span className="mono">
                  {fmtInt(stats.popUsed)} / {fmtInt(stats.popCap)}
                </span>
              </span>
            </div>
          </div>
        </div>

        <div className="country-rates">
          {RESOURCES.map((r) => (
            <div key={r} className="country-rate">
              <span className="meter-label">
                <span className={`dot ${r}`} />
                {t(`res.${r}` as TextKey)}
              </span>
              <span className="meter-value">{t('panel.perHour', { n: fmtInt(stats.rates[r]) })}</span>
            </div>
          ))}
        </div>
      </header>

      {byCountry.length > 1 && (
        <div className="country-groups">
          {byCountry.map(([code, count]) => (
            <span key={code} className="country-chip">
              {countryName(code, countries)} <span className="mono">{count}</span>
            </span>
          ))}
        </div>
      )}

      {settlements.length === 0 ? (
        <p className="country-empty">{t('country.empty')}</p>
      ) : (
        <div className="country-schematic" style={{ height: schematic.height }}>
          <svg className="country-links" aria-hidden="true" focusable="false">
            {schematic.edges.map(([a, b]) => (
              <line
                key={`${a.settlement.id}-${b.settlement.id}`}
                x1={`${a.fx * 100}%`}
                y1={a.cy}
                x2={`${b.fx * 100}%`}
                y2={b.cy}
              />
            ))}
          </svg>

          {schematic.nodes.map(({ settlement: s, fx, top }) => {
            const hex = hexes[s.idx];
            const name = s.customName ?? (hex ? hexName(hex, countries) : s.name);
            const popUsed = populationUsed(plannedLevels(s.levels, s.queue));
            const popCap = housingCapacity(s.levels.housing);
            return (
              <button
                key={s.id}
                className="settle-card"
                style={{ left: placeX(fx), top }}
                onClick={() => onOpen(s)}
                title={t('country.open', { name })}
              >
                <span className="settle-head">
                  <span className="settle-name">{name}</span>
                  <span className="settle-pts mono">{fmtInt(s.points)}</span>
                  {s.queue.length > 0 && <span className="settle-busy" title={t('panel.queue')} />}
                </span>
                <span className="settle-meta">
                  <span>{countryName(s.countryCode, countries)}</span>
                  <span className="sep">/</span>
                  <span className="mono">
                    {fmtInt(popUsed)} / {fmtInt(popCap)}
                  </span>
                  <span className="settle-go" aria-hidden="true">
                    ›
                  </span>
                </span>
                <span className="settle-buildings">
                  {BUILDING_IDS.map((id) => {
                    const level = s.levels[id];
                    return (
                      <span
                        key={id}
                        className={`bp ${level > 0 ? '' : 'off'}`}
                        title={t('country.cellTitle', { building: buildingName(id), n: level })}
                      >
                        <BuildingIcon id={id} size={20} className={level > 0 ? '' : 'unbuilt'} />
                        <span className="bp-level mono">{level > 0 ? level : '–'}</span>
                      </span>
                    );
                  })}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {settlements.length > 0 && (
        <footer className="country-totals">
          <h3>{t('country.totals')}</h3>
          <div className="totals-grid">
            {BUILDING_IDS.map((id) => {
              const level = stats.levels[id];
              return (
                <span
                  key={id}
                  className={`tot ${level > 0 ? '' : 'off'}`}
                  title={`${buildingName(id)} — ${t('country.totalOf', { levels: level, n: stats.holders[id] })}`}
                >
                  <BuildingIcon id={id} size={26} className={level > 0 ? '' : 'unbuilt'} />
                  <span className="tot-level mono">{level > 0 ? level : '–'}</span>
                </span>
              );
            })}
          </div>
        </footer>
      )}
    </section>
  );
}
