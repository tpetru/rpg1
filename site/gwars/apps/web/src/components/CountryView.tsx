import { useMemo, useState } from 'react';
import { cellToLatLng } from 'h3-js';
import {
  UNIT_IDS,
  unitTotal,
  type CommandDto,
  type CountryRef,
  type HexRow,
  type OwnSettlementDto,
  type UnitId,
  type WorldSettings,
} from '@geowars/rules';
import { UnitIcon } from '../art/units';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtDuration } from '../util';

// The order of battle: how the nation's army reads on a muster sheet. The strength return sits
// at the top — one column per branch, each total split into garrison / field / training. Below
// it the settlements keep their geographic lattice, but every card now lists its garrison.
// The bottom band is what moves: armies on the road and recruits still being trained. Read-only:
// a card opens that settlement on the map.

/** North to south, west to east: the geographic reading order inside a group. */
function geoOrder(a: OwnSettlementDto, b: OwnSettlementDto): number {
  const [latA, lngA] = cellToLatLng(a.h3);
  const [latB, lngB] = cellToLatLng(b.h3);
  return latB - latA || lngA - lngB;
}

interface Props {
  nation: string;
  settlements: OwnSettlementDto[];
  /** My armies on the road, attack and return alike. */
  commands: CommandDto[];
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  settings: WorldSettings;
  clockOffset: number;
  onOpen: (settlement: OwnSettlementDto) => void;
}

export function CountryView({ nation, settlements, commands, hexes, countries, clockOffset, onOpen }: Props) {
  const { t, countryName, hexName } = useI18n();
  /** The branch hovered in the muster row: the whole lattice answers by dimming the others. */
  const [unitHot, setUnitHot] = useState<UnitId | null>(null);

  const now = Date.now() + clockOffset;

  const nameOf = (s: OwnSettlementDto) => s.customName ?? (hexes[s.idx] ? hexName(hexes[s.idx], countries) : s.name);
  /** A point on a march: the name the owner gave it, or the map's. */
  const placeOf = (idx: number) => {
    const own = settlements.find((s) => s.idx === idx);
    return own ? nameOf(own) : hexes[idx] ? hexName(hexes[idx], countries) : '?';
  };
  const homeOf = (s: OwnSettlementDto, u: UnitId) => s.units[u] ?? 0;
  const awayFrom = (id: number) => commands.filter((c) => c.originId === id);

  /** The strength return: one row per branch, counted from the same data the cards show. */
  const muster = useMemo(
    () =>
      UNIT_IDS.map((u) => {
        let home = 0;
        let training = 0;
        for (const s of settlements) {
          home += s.units[u] ?? 0;
          training += s.training.reduce((n, item) => n + (item.unit === u ? item.count : 0), 0);
        }
        let away = 0;
        for (const c of commands) away += c.units[u] ?? 0;
        return { u, home, away, training };
      }),
    [settlements, commands],
  );
  const totals = useMemo(
    () =>
      muster.reduce(
        (acc, m) => ({ home: acc.home + m.home, away: acc.away + m.away, training: acc.training + m.training }),
        { home: 0, away: 0, training: 0 },
      ),
    [muster],
  );

  const points = useMemo(() => settlements.reduce((sum, s) => sum + s.points, 0), [settlements]);
  const troopPop = useMemo(() => settlements.reduce((sum, s) => sum + s.troopPop, 0), [settlements]);

  /** The whole army of one settlement: standing at home plus on the road. */
  const armyOf = (s: OwnSettlementDto) => unitTotal(s.units) + awayFrom(s.id).reduce((n, c) => n + unitTotal(c.units), 0);

  /** Settlements grouped continent over country, each group read north to south, west to east. */
  const groups = useMemo(() => {
    const byContinent = new Map<string, Map<string, OwnSettlementDto[]>>();
    for (const s of settlements) {
      const cont = countries[s.countryCode]?.continent ?? '?';
      const inner = byContinent.get(cont) ?? new Map<string, OwnSettlementDto[]>();
      inner.set(s.countryCode, [...(inner.get(s.countryCode) ?? []), s]);
      byContinent.set(cont, inner);
    }
    // Biggest continent first: the one with the most settlements.
    const count = (inner: Map<string, OwnSettlementDto[]>) => [...inner.values()].reduce((n, l) => n + l.length, 0);
    return [...byContinent.entries()]
      .sort((a, b) => count(b[1]) - count(a[1]) || a[0].localeCompare(b[0]))
      .map(([continent, inner]) => ({
        continent,
        countries: [...inner.entries()]
          .map(([code, list]) => ({ code, name: countryName(code, countries), settlements: list.sort(geoOrder) }))
          .sort((a, b) => a.name.localeCompare(b.name)),
      }));
  }, [settlements, countries, countryName]);

  /** Armies on the road, soonest arrival first. */
  const marches = useMemo(() => [...commands].sort((a, b) => a.arrivesAt - b.arrivesAt), [commands]);
  /** Recruits still forming, soonest finish first. */
  const forming = useMemo(
    () =>
      settlements
        .flatMap((s) => s.training.map((item) => ({ settlement: s, item })))
        .sort((a, b) => a.item.finishesAt - b.item.finishesAt),
    [settlements],
  );

  const chipClass = (u: UnitId, extra = '') =>
    `g-chip${extra}${unitHot && unitHot !== u ? ' cold' : ''}${unitHot === u ? ' hot' : ''}`;

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
              <span className="mono">{t('points', { n: fmtInt(points) })}</span>
              <span className="sep">/</span>
              <span>
                {t('panel.population')} <span className="mono">{fmtInt(troopPop)}</span>
              </span>
            </div>
          </div>
        </div>

        <div className="country-army">
          <div className="ca-split">
            <span>
              <i className="dotseg home" />
              {t('country.garrison')} <span className="mono">{fmtInt(totals.home)}</span>
            </span>
            <span>
              <i className="dotseg away" />
              {t('country.inField')} <span className="mono">{fmtInt(totals.away)}</span>
            </span>
            <span>
              <i className="dotseg train" />
              {t('troops.training')} <span className="mono">{fmtInt(totals.training)}</span>
            </span>
          </div>
          <div className="ca-total">
            <span className="mono">{fmtInt(totals.home + totals.away)}</span>
            <span className="ca-cap">{t('country.statArmy')}</span>
          </div>
        </div>
      </header>

      <div className="muster" role="group" aria-label={t('country.muster')}>
        {muster.map(({ u, home, away, training }) => {
          const sum = home + away + training;
          const pct = (n: number) => (sum > 0 ? (n / sum) * 100 : 0);
          return (
            <button
              type="button"
              key={u}
              className={`muster-unit${sum === 0 ? ' off' : ''}${unitHot === u ? ' hot' : ''}`}
              title={t('country.musterTitle', { name: t(`unit.${u}.name` as TextKey), home, away, training })}
              onMouseEnter={() => setUnitHot(u)}
              onMouseLeave={() => setUnitHot(null)}
              onFocus={() => setUnitHot(u)}
              onBlur={() => setUnitHot(null)}
            >
              <UnitIcon unit={u} size={20} />
              <span className="mono muster-n">{fmtInt(home + away)}</span>
              <span className="muster-bar" aria-hidden="true">
                <i className="seg home" style={{ width: `${pct(home)}%` }} />
                <i className="seg away" style={{ width: `${pct(away)}%` }} />
                <i className="seg train" style={{ width: `${pct(training)}%` }} />
              </span>
            </button>
          );
        })}
      </div>

      {settlements.length === 0 ? (
        <p className="country-empty">{t('country.empty')}</p>
      ) : (
        groups.map((g) => {
          const inContinent = g.countries.reduce((n, c) => n + c.settlements.length, 0);
          const continentArmy = g.countries.reduce((n, c) => n + c.settlements.reduce((m, s) => m + armyOf(s), 0), 0);
          return (
            <section key={g.continent} className="country-continent">
              <h2 className="cont-head">
                {t(`continent.${g.continent}` as TextKey)}
                <span className="cont-meta mono">
                  {t('country.settlements', { n: fmtInt(inContinent) })} · {fmtInt(continentArmy)} {t('country.armyOf')}
                </span>
              </h2>
              {g.countries.map((c) => (
                <div key={c.code} className="country-block">
                  <div className="block-head">
                    <span className="block-name">{c.name}</span>
                    <span className="mono">{c.settlements.length}</span>
                    <span className="sep">/</span>
                    <span className="mono">{fmtInt(c.settlements.reduce((n, s) => n + armyOf(s), 0))}</span>
                  </div>
                  <div className="settle-grid">
                    {c.settlements.map((s) => {
                      const garrison = UNIT_IDS.filter((u) => homeOf(s, u) > 0);
                      const gTotal = unitTotal(s.units);
                      const away = awayFrom(s.id).reduce((n, c) => n + unitTotal(c.units), 0);
                      const training = s.training.reduce((n, item) => n + item.count, 0);
                      return (
                        <button key={s.id} className="settle-card" onClick={() => onOpen(s)} title={t('country.open', { name: nameOf(s) })}>
                <span className="settle-head">
                  <span className="settle-name">{nameOf(s)}</span>
                  <span className="settle-pts mono">{fmtInt(s.points)}</span>
                  {(away > 0 || training > 0) && <span className="settle-busy" title={t('country.inField')} />}
                </span>
                <span className="settle-meta">
                  <span>{countryName(s.countryCode, countries)}</span>
                  <span className="sep">/</span>
                  <span className="mono">{fmtInt(gTotal)}</span>
                  <span>{t('country.garrisonShort')}</span>
                  <span className="settle-go" aria-hidden="true">
                    ›
                  </span>
                </span>
                <span className="settle-units">
                  {garrison.length === 0 ? (
                    <span className="faint small">{t('troops.none')}</span>
                  ) : (
                    garrison.map((u) => (
                      <span key={u} className={chipClass(u)} title={t(`unit.${u}.name` as TextKey)}>
                        <UnitIcon unit={u} size={16} />
                        <span className="mono">{fmtInt(homeOf(s, u))}</span>
                      </span>
                    ))
                  )}
                </span>
                {(away > 0 || training > 0) && (
                  <span className="settle-foot">
                    {away > 0 && <span className="sf away">{t('country.awayN', { n: fmtInt(away) })}</span>}
                    {training > 0 && <span className="sf train">{t('country.trainingN', { n: fmtInt(training) })}</span>}
                  </span>
                )}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ))}
            </section>
          );
        })
      )}

      {(marches.length > 0 || forming.length > 0) && (
        <div className="country-rolls">
          <section className="roll">
            <h3>
              {t('country.inField')}
              {marches.length > 0 && <span className="mono">{marches.length}</span>}
            </h3>
            {marches.length === 0 ? (
              <p className="faint small">{t('country.noField')}</p>
            ) : (
              <ul>
                {marches.map((c) => {
                  // A return keeps the attack's endpoints: the troops travel target → origin.
                  const [from, to] = c.type === 'return' ? [c.targetIdx, c.originIdx] : [c.originIdx, c.targetIdx];
                  return (
                    <li key={c.id}>
                      <span className="roll-units">
                        {UNIT_IDS.filter((u) => (c.units[u] ?? 0) > 0).map((u) => (
                          <span key={u} className={chipClass(u, ' away')} title={t(`unit.${u}.name` as TextKey)}>
                            <UnitIcon unit={u} size={16} />
                            <span className="mono">{fmtInt(c.units[u])}</span>
                          </span>
                        ))}
                      </span>
                      <span className="roll-route">
                        <strong>{placeOf(from)}</strong>
                        <span className="faint"> → </span>
                        {placeOf(to)}
                      </span>
                      <span className="roll-when mono small muted">{t('reports.arrives', { time: fmtDuration((c.arrivesAt - now) / 1000) })}</span>
                    </li>
                  );
                })}
              </ul>
            )}
          </section>

          <section className="roll">
            <h3>
              {t('troops.training')}
              {forming.length > 0 && <span className="mono">{forming.reduce((n, f) => n + f.item.count, 0)}</span>}
            </h3>
            {forming.length === 0 ? (
              <p className="faint small">{t('country.noTraining')}</p>
            ) : (
              <ul>
                {forming.map(({ settlement: s, item }) => (
                  <li key={item.id}>
                    <span className={chipClass(item.unit, ' train')} title={t(`unit.${item.unit}.name` as TextKey)}>
                      <UnitIcon unit={item.unit} size={16} />
                      <span className="mono">×{fmtInt(item.count)}</span>
                    </span>
                    <span className="roll-route">
                      <strong>{nameOf(s)}</strong>
                    </span>
                    <span className="roll-when mono small muted">{fmtDuration((item.finishesAt - now) / 1000)}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
    </section>
  );
}
