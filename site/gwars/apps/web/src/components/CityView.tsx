import { useMemo, useState } from 'react';
import { BUILDINGS, BUILDING_IDS, type BuildingId, type OwnSettlementDto } from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import {
  CITY_AXES,
  CITY_PATHS,
  CITY_PLAZA,
  CITY_PLOTS,
  CITY_ROADS,
  PARCEL_H,
  PLAN_H,
  PLAN_W,
  plotBox,
  type CityPlot,
} from '../cityPlan';
import { fmtInt, useI18n } from '../i18n';

// The city view: one settlement, drawn as a town plan. Every settlement shares the same sheet, so
// a building's address is learned once. Read-only: a parcel opens that building in the hub.

interface Props {
  settlement: OwnSettlementDto;
  /** The map's name for the hex, used when the owner has not renamed the settlement. */
  defaultName: string;
  countryName: string;
  onOpenBuilding: (id: BuildingId) => void;
}

/** The outer parcels are too close to the sheet's edge to centre a tooltip on. */
function tipEdge(plot: CityPlot): string {
  if (plot.x <= 320) return 'tip-left';
  if (plot.x >= 920) return 'tip-right';
  return '';
}

export function CityView({ settlement: s, defaultName, countryName, onOpenBuilding }: Props) {
  const { t, buildingName } = useI18n();
  const [active, setActive] = useState<BuildingId | null>(null);

  const name = s.customName ?? defaultName;
  const builtCount = useMemo(() => BUILDING_IDS.filter((id) => s.levels[id] > 0).length, [s.levels]);
  /** Where each queued building is heading; the parcel shows the completed level and this target. */
  const queuedTo = useMemo(() => {
    const map = new Map<BuildingId, number>();
    for (const item of s.queue) map.set(item.building, item.targetLevel);
    return map;
  }, [s.queue]);

  const activePlot = CITY_PLOTS.find((plot) => plot.id === active);

  return (
    <section className="city" aria-label={`${t('view.city')}: ${name}`}>
      <header className="city-head">
        <div>
          <h1 className="city-name">{name}</h1>
          <div className="meta-row">
            <span>{countryName}</span>
            <span className="sep">/</span>
            <span className="mono">{t('points', { n: fmtInt(s.points) })}</span>
            <span className="sep">/</span>
            <span>{t('city.built', { n: builtCount, total: BUILDING_IDS.length })}</span>
          </div>
        </div>
        <p className="city-note">{t('city.sharedPlan')}</p>
      </header>

      <div className="city-scroll">
        <div className="city-plan" onMouseLeave={() => setActive(null)}>
          <svg className="city-map" viewBox={`0 0 ${PLAN_W} ${PLAN_H}`} aria-hidden="true" focusable="false">
            <defs>
              <pattern id="city-paving" width="14" height="14" patternUnits="userSpaceOnUse">
                <circle className="city-paving-dot" cx="2" cy="2" r="1" />
              </pattern>
            </defs>

            {CITY_ROADS.map((road, index) => (
              <rect
                key={`road-${index}`}
                className="city-road"
                x={road.x}
                y={road.y}
                width={road.w}
                height={road.h}
              />
            ))}

            <rect
              className="city-plaza"
              x={CITY_PLAZA.x}
              y={CITY_PLAZA.y}
              width={CITY_PLAZA.w}
              height={CITY_PLAZA.h}
            />
            <rect
              className="city-plaza-floor"
              x={CITY_PLAZA.x}
              y={CITY_PLAZA.y}
              width={CITY_PLAZA.w}
              height={CITY_PLAZA.h}
              fill="url(#city-paving)"
            />

            {CITY_AXES.map((d) => (
              <path key={d} className="city-axis" d={d} />
            ))}
            {CITY_PATHS.map((d) => (
              <path key={d} className="city-foot" d={d} />
            ))}
          </svg>

          {CITY_PLOTS.map((plot) => {
            const level = s.levels[plot.id];
            const queued = queuedTo.get(plot.id);
            const box = plotBox(plot);
            const built = level > 0;
            const label = built
              ? `${buildingName(plot.id)} — ${t('panel.levelOf', { n: level, max: BUILDINGS[plot.id].maxLevel })}`
              : `${buildingName(plot.id)} — ${t('city.notBuilt')}`;
            return (
              <button
                key={plot.id}
                type="button"
                className={`plot ${built ? 'built' : 'reserved'} ${active === plot.id ? 'active' : ''}`}
                style={{ left: `${box.left}%`, top: `${box.top}%`, width: `${box.width}%`, height: `${box.height}%` }}
                onMouseEnter={() => setActive(plot.id)}
                onFocus={() => setActive(plot.id)}
                onBlur={() => setActive((current) => (current === plot.id ? null : current))}
                onClick={() => onOpenBuilding(plot.id)}
                aria-label={label}
              >
                <span className="plot-art">
                  <BuildingIcon id={plot.id} size={86} className={built ? '' : 'unbuilt'} />
                  {/* The level sits on the building, the way a plan annotates its masses. */}
                  <span className="plot-lv mono">
                    {level}
                    {queued != null && <span className="plot-lv-next">→{queued}</span>}
                  </span>
                </span>
                <span className="plot-name">{buildingName(plot.id)}</span>
              </button>
            );
          })}

          {activePlot && (
            <div
              className={`plot-tip ${activePlot.y < 300 ? 'tip-below' : 'tip-above'} ${tipEdge(activePlot)}`}
              style={{
                left: `${(activePlot.x / PLAN_W) * 100}%`,
                top: `${(((activePlot.y < 300 ? activePlot.y + PARCEL_H / 2 : activePlot.y - PARCEL_H / 2) / PLAN_H) * 100).toFixed(3)}%`,
              }}
              aria-hidden="true"
            >
              <span className="plot-tip-name">{buildingName(activePlot.id)}</span>
              <span className="plot-tip-meta mono">
                {s.levels[activePlot.id] > 0
                  ? t('panel.levelOf', { n: s.levels[activePlot.id], max: BUILDINGS[activePlot.id].maxLevel })
                  : t('city.notBuilt')}
              </span>
              {queuedTo.get(activePlot.id) != null && (
                <span className="plot-tip-queued">{t('panel.queuedTo', { n: queuedTo.get(activePlot.id)! })}</span>
              )}
              <span className="plot-tip-go">{t('city.openHint')}</span>
            </div>
          )}
        </div>
      </div>

      <p className="city-scrollnote">{t('city.scroll')}</p>
    </section>
  );
}
