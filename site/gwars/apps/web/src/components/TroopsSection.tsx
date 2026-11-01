import { useState } from 'react';
import {
  UNITS,
  UNIT_IDS,
  canAfford,
  housingCapacity,
  plannedLevels,
  populationUsed,
  trainTimeSec,
  unitCost,
  type BuildingId,
  type OwnSettlementDto,
  type ResourceBag,
  type UnitId,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { UnitIcon } from '../art/units';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtBuildTime, fmtDuration } from '../util';
import { UnitDialog } from './UnitDialog';

interface Props {
  worldId: number;
  settlement: OwnSettlementDto;
  /** The training building whose page this is: only its units can be trained here. */
  building: BuildingId;
  /** Resources right now (the panel ticks them locally). */
  stock: ResourceBag;
  settings: WorldSettings;
  now: number;
  onUpdate: (s: OwnSettlementDto) => void;
}

/** Troops at home, and the training form and queue. */
export function TroopsSection({ worldId, settlement: s, building, stock, settings, now, onUpdate }: Props) {
  const { t, errorText, codeText, buildingName } = useI18n();
  const units = UNIT_IDS.filter((id) => UNITS[id].trainedAt === building);
  const [counts, setCounts] = useState<Partial<Record<UnitId, string>>>({});
  const [info, setInfo] = useState<UnitId | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const popRoom = housingCapacity(s.levels.housing) - populationUsed(plannedLevels(s.levels, s.queue)) - s.troopPop;
  const amountOf = (unit: UnitId) => Number(counts[unit] || 0);
  const validAmount = (n: number) => Number.isInteger(n) && n >= 1 && n <= 5000;

  /** The most of this unit that resources and housing allow right now. */
  const maxAffordable = (unit: UnitId) => {
    const def = UNITS[unit];
    const byResources = Math.min(...(['food', 'steel', 'oil'] as const).map((r) => (def.cost[r] > 0 ? Math.floor(stock[r] / def.cost[r]) : Infinity)));
    return Math.max(0, Math.min(5000, byResources, Math.floor(popRoom / def.pop)));
  };

  /** What keeps this unit from being trained at all in this settlement, or null. */
  const lockedReason = (unit: UnitId): string | null => {
    const def = UNITS[unit];
    const unmet = (Object.entries(def.requires) as [BuildingId, number][]).find(([b, level]) => s.levels[b] < level);
    if (unmet) return t('troops.needs', { building: buildingName(unmet[0]), level: unmet[1] });
    if (!s.researched.includes(unit)) return t('troops.notResearched');
    return null;
  };

  // One order for everything typed in: a batch per unit with an amount.
  const chosen = units.filter((u) => amountOf(u) > 0);
  const total = chosen.reduce(
    (sum, u) => {
      const c = unitCost(UNITS[u], amountOf(u));
      return { food: sum.food + c.food, steel: sum.steel + c.steel, oil: sum.oil + c.oil, pop: sum.pop + amountOf(u) * UNITS[u].pop, time: sum.time + trainTimeSec(UNITS[u], amountOf(u), s.levels[UNITS[u].trainedAt], settings.recruitSpeed) };
    },
    { food: 0, steel: 0, oil: 0, pop: 0, time: 0 },
  );
  const orderReason: string | null =
    chosen.map((u) => lockedReason(u)).find((r) => r !== null) ??
    (chosen.some((u) => !validAmount(amountOf(u)))
      ? t('troops.badAmount')
      : s.training.length + chosen.length > 5
        ? codeText('train_queue_full')
        : !canAfford(stock, total)
          ? codeText('train_resources')
          : total.pop > popRoom
            ? codeText('train_housing')
            : null);

  const trainAll = async () => {
    setBusy(true);
    setError(null);
    try {
      for (const u of chosen) onUpdate(await api.train(worldId, s.id, u, amountOf(u)));
      setCounts({});
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  const run = async (action: () => Promise<OwnSettlementDto>) => {
    setBusy(true);
    setError(null);
    try {
      onUpdate(await action());
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  const homeUnits = units.filter((id) => s.units[id] > 0);

  return (
    <section className="troops">
      <div className="catalogue-head">
        <h3>{t('troops.title')}</h3>
        {s.troopPop > 0 && <span className="faint small">{t('troops.pop', { n: fmtInt(s.troopPop) })}</span>}
      </div>

      {homeUnits.length === 0 ? (
        <p className="muted small troops-none">{t('troops.none')}</p>
      ) : (
        <ul className="troops-home">
          {homeUnits.map((id) => (
            <li key={id} title={t(`unit.${id}.desc` as TextKey)}>
              <UnitIcon unit={id} size={30} />
              <span>{t(`unit.${id}.name` as TextKey)}</span>
              <strong className="mono">{fmtInt(s.units[id])}</strong>
            </li>
          ))}
        </ul>
      )}

      {s.training.some((item) => units.includes(item.unit)) && (
        <div className="troops-queue">
          <div className="faint small">{t('troops.training')}</div>
          {s.training.filter((item) => units.includes(item.unit)).map((item, i, mine) => (
            <div key={item.id} className="troops-queue-row">
              <UnitIcon unit={item.unit} size={22} />
              <span>
                {fmtInt(item.count)} × {t(`unit.${item.unit}.name` as TextKey)}
              </span>
              <span className="mono muted">
                {item.count > 1 && `${t('troops.nextUnit', { time: fmtDuration((item.startsAt + ((item.finishesAt - item.startsAt) / item.total) * (item.total - item.count + 1) - now) / 1000) })} · `}
                {t('troops.batchLeft', { time: fmtDuration((item.finishesAt - now) / 1000) })}
              </span>
              {item.id === s.training.at(-1)?.id && (
                <button className="link" disabled={busy} onClick={() => run(() => api.cancelTraining(worldId, s.id, item.id))}>
                  {t('panel.cancel')}
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      <div className="hall-body troops-list">
        {units.map((unit) => {
          const def = UNITS[unit];
          const amount = amountOf(unit);
          const valid = validAmount(amount);
          const cost = unitCost(def, valid ? amount : 0);
          const reason = lockedReason(unit);
          const timeSec = valid ? trainTimeSec(def, amount, s.levels[def.trainedAt], settings.recruitSpeed) : 0;
          return (
            <div key={unit} className={`hall-row ${s.researched.includes(unit) ? '' : 'unbuilt'}`}>
              <button type="button" className="unit-open" onClick={() => setInfo(unit)} aria-label={t(`unit.${unit}.name` as TextKey)}>
                <UnitIcon unit={unit} size={40} />
              </button>
              <div className="hall-name">
                <button type="button" className="link plain unit-open-name" onClick={() => setInfo(unit)}>
                  <strong>{t(`unit.${unit}.name` as TextKey)}</strong>
                </button>
                <span className="costs">
                  {(['food', 'steel', 'oil'] as const).map((r) => (
                    <span key={r} className="cost">
                      <span className={`dot ${r}`} />
                      {fmtInt(def.cost[r])}
                    </span>
                  ))}
                  <span className="cost" title={t('unit.pop')}>
                    <span aria-hidden="true">👥</span> {fmtInt(def.pop)}
                  </span>
                </span>
              </div>
              <div className="hall-info">
                <span className="hall-line">
                  <span className="costs">
                    {(['food', 'steel', 'oil'] as const).map((r) => (
                      <span key={r} className={`cost ${stock[r] < cost[r] ? 'short' : ''}`}>
                        <span className={`dot ${r}`} />
                        {fmtInt(cost[r])}
                      </span>
                    ))}
                  </span>
                  <span className="mono small hall-time">{valid ? fmtBuildTime(timeSec) : ''}</span>
                </span>
                <span className="faint small mono">{t('troops.atHome', { n: fmtInt(s.units[unit]) })}</span>
              </div>
              <div className="hall-act">
                <div className="troops-order">
                  <div className="qty">
                    <input
                      type="number"
                      min={1}
                      max={5000}
                      step={1}
                      inputMode="numeric"
                      value={counts[unit] ?? ''}
                      placeholder="0"
                      disabled={reason !== null}
                      onChange={(e) => setCounts((prev) => ({ ...prev, [unit]: e.target.value }))}
                      aria-label={t('troops.train')}
                    />
                    <button type="button" className="qty-max" disabled={reason !== null} onClick={() => setCounts((prev) => ({ ...prev, [unit]: String(Math.max(1, maxAffordable(unit))) }))}>
                      Max
                    </button>
                  </div>
                </div>
                {reason && <span className="hall-why">{reason}</span>}
              </div>
            </div>
          );
        })}
      </div>

      <div className="troops-footer">
        {chosen.length > 0 && (
          <span className="troops-total">
            <span className="costs">
              {(['food', 'steel', 'oil'] as const).map((r) => (
                <span key={r} className={`cost ${stock[r] < total[r] ? 'short' : ''}`}>
                  <span className={`dot ${r}`} />
                  {fmtInt(total[r])}
                </span>
              ))}
            </span>
            <span className="mono small muted">{fmtBuildTime(total.time)}</span>
          </span>
        )}
        {orderReason && chosen.length > 0 && <span className="hall-why">{orderReason}</span>}
        <button className="primary" disabled={busy || chosen.length === 0 || orderReason !== null} onClick={() => void trainAll()}>
          {t('troops.train')}
        </button>
      </div>
      {error != null && <div className="error">{errorText(error)}</div>}

      {info && <UnitDialog unit={info} buildingLevel={s.levels[UNITS[info].trainedAt]} settings={settings} onClose={() => setInfo(null)} />}
    </section>
  );
}
