import { useMemo, useState } from 'react';
import { BUILDINGS, type BuildingId, type OwnSettlementDto } from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import { CityGround } from '../art/cityGround';
import { NationEmblem } from '../art/nation';
import { CITY_SITES, siteBox, type CitySite } from '../cityMap';
import { fmtInt, useI18n } from '../i18n';
import { fmtDuration, useNow } from '../util';

// The settlement view: a small sticker-book town. The map does the talking — every building is a
// sticker with its level on a chip — and the panel says only three things: which town this is, how
// big it has grown, and what is being built next. Read-only: a building, or the build line, opens
// that building in the settlement hub.

interface Props {
  settlement: OwnSettlementDto;
  /** The map's name for the hex, used when the owner has not renamed the settlement. */
  defaultName: string;
  countryName: string;
  /** The nation holding this settlement, for its coat of arms. */
  nation: string;
  /** Client clock correction, so the countdown matches the server's clock. */
  clockOffset: number;
  onOpenBuilding: (id: BuildingId) => void;
}

export function CityView({ settlement: s, defaultName, countryName, nation, clockOffset, onOpenBuilding }: Props) {
  const { t, buildingName } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [active, setActive] = useState<BuildingId | null>(null);

  const name = s.customName ?? defaultName;

  /** The next thing being built — the one line this screen says about the town's future. */
  const building = s.queue[0] ?? null;
  const remaining = building ? (building.finishesAt - now) / 1000 : 0;

  /** Where each queued building is heading, so a chip can read `level → target`. */
  const queued = useMemo(() => {
    const map = new Map<BuildingId, number>();
    for (const item of s.queue) map.set(item.building, item.targetLevel);
    return map;
  }, [s.queue]);

  return (
    <section className="city" aria-label={`${t('view.city')}: ${name}`}>
      <div className="city-map">
        <div className="city-scroll">
          <div className="city-scene" onMouseLeave={() => setActive(null)}>
            <CityGround />

            {CITY_SITES.map((site) => {
              const level = s.levels[site.id];
              const max = BUILDINGS[site.id].maxLevel;
              const target = queued.get(site.id);
              const built = level > 0;
              const box = siteBox(site);
              const label = built
                ? `${buildingName(site.id)} — ${t('panel.levelOf', { n: level, max })}`
                : `${buildingName(site.id)} — ${t('city.notBuilt')}`;
              return (
                <button
                  key={site.id}
                  type="button"
                  className={`site ${built ? 'built' : 'reserved'} ${active === site.id ? 'active' : ''}`}
                  style={{
                    left: `${box.left}%`,
                    top: `${box.top}%`,
                    width: `${box.width.toFixed(3)}cqw`,
                    zIndex: Math.round(site.y * 1000),
                  }}
                  onMouseEnter={() => setActive(site.id)}
                  onFocus={() => setActive(site.id)}
                  onBlur={() => setActive((current) => (current === site.id ? null : current))}
                  onClick={() => onOpenBuilding(site.id)}
                  aria-label={target ? `${label}, ${t('panel.queuedTo', { n: target })}` : label}
                >
                  <span className="site-ring" aria-hidden="true" />

                  <span className="site-icon">
                    <BuildingIcon id={site.id} size={96} className={built ? undefined : 'unbuilt'} />
                  </span>

                  <span className="site-lv" aria-hidden="true">
                    <span className="site-lv-name">{buildingName(site.id)}</span>
                    <span className="site-lv-sep">|</span>
                    <span className="mono">{level}</span>
                    {target != null && <span className="site-lv-next">→{target}</span>}
                  </span>

                </button>
              );
            })}
          </div>
        </div>
        <p className="city-scrollnote">{t('city.scroll')}</p>
      </div>
    </section>
  );
}
