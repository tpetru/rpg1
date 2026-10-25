import { useEffect, useRef, useState } from 'react';
import {
  BUILDINGS,
  BUILDING_IDS,
  RESOURCES,
  RESOURCE_LABELS,
  checkBuild,
  housingCapacity,
  materialize,
  plannedLevels,
  populationUsed,
  productionRates,
  warehouseCapacity,
  type BuildingId,
  type OwnSettlementDto,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { fmtDuration, fmtInt, useNow } from '../util';
import { Multiplier } from './Multiplier';

interface Props {
  settlement: OwnSettlementDto;
  countryName: string;
  settings: WorldSettings;
  clockOffset: number;
  onUpdate: (s: OwnSettlementDto) => void;
  /** Called when local state is known to be out of date (a build should have finished). */
  onStale: () => void;
}

export function SettlementPanel({ settlement: s, countryName, settings, clockOffset, onUpdate, onStale }: Props) {
  const now = useNow(1000) + clockOffset;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const lastStale = useRef(0);

  // Same formulas as the server, so the numbers tick locally without polling.
  const rates = productionRates(s.levels, s.profile, settings.speed);
  const cap = warehouseCapacity(s.levels.warehouse);
  const stock = materialize(s.stock, rates, cap, s.resourcesAt, now);
  const popUsed = populationUsed(plannedLevels(s.levels, s.queue));
  const popCap = housingCapacity(s.levels.housing);

  // The server pushes completions over WebSocket; this is the fallback if a message was missed.
  const overdue = s.queue.length > 0 && s.queue[0].finishesAt < now - 3000;
  useEffect(() => {
    if (overdue && Date.now() - lastStale.current > 5000) {
      lastStale.current = Date.now();
      onStale();
    }
  }, [overdue, onStale]);

  const run = async (action: () => Promise<OwnSettlementDto>) => {
    setBusy(true);
    setError(null);
    try {
      onUpdate(await action());
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const unlocked = BUILDING_IDS.filter((id) => Object.entries(BUILDINGS[id].requires).every(([req, lvl]) => s.levels[req as BuildingId] >= lvl!));
  const locked = BUILDING_IDS.filter((id) => !unlocked.includes(id));

  return (
    <div className="stack">
      <div>
        <h2>{s.name}</h2>
        <div className="muted">
          {countryName} · {fmtInt(s.points)} points · loyalty {s.loyalty}
        </div>
      </div>

      <section className="resources">
        {RESOURCES.map((r) => (
          <div key={r} className={`res ${stock[r] >= cap ? 'full' : ''}`}>
            <span className={`dot ${r}`} />
            <span className="res-label">{RESOURCE_LABELS[r]}</span>
            <strong>{fmtInt(stock[r])}</strong>
            <span className="muted small">+{fmtInt(rates[r])}/h</span>
          </div>
        ))}
        <div className="res">
          <span className="dot storage" />
          <span className="res-label">Storage</span>
          <strong>{fmtInt(cap)}</strong>
        </div>
        <div className={`res ${popUsed >= popCap ? 'full' : ''}`}>
          <span className="dot pop" />
          <span className="res-label">Population</span>
          <strong>
            {fmtInt(popUsed)}/{fmtInt(popCap)}
          </strong>
        </div>
      </section>

      {s.queue.length > 0 && (
        <section className="card">
          <h3>Construction</h3>
          {s.queue.map((q, i) => {
            const active = i === 0;
            const total = q.finishesAt - q.startsAt;
            const progress = active ? Math.min(1, Math.max(0, (now - q.startsAt) / total)) : 0;
            return (
              <div key={q.id} className="queue-item">
                <div className="queue-row">
                  <span>
                    {BUILDINGS[q.building].name} <span className="muted">→ {q.targetLevel}</span>
                  </span>
                  <span className="mono">{fmtDuration((q.finishesAt - now) / 1000)}</span>
                  {i === s.queue.length - 1 && (
                    <button className="link" disabled={busy} onClick={() => run(() => api.cancelBuild(s.id, q.id))}>
                      Cancel
                    </button>
                  )}
                </div>
                {active && (
                  <div className="progress">
                    <div style={{ width: `${progress * 100}%` }} />
                  </div>
                )}
              </div>
            );
          })}
        </section>
      )}

      {error && <div className="error">{error}</div>}

      <section className="card">
        <h3>Buildings</h3>
        {unlocked.map((id) => {
          const def = BUILDINGS[id];
          const check = checkBuild({ levels: s.levels, queue: s.queue, stock }, id, settings);
          const cost = check.cost;
          return (
            <div key={id} className="building">
              <div className="building-head">
                <span title={def.description}>
                  {def.name} <span className="level">{s.levels[id] > 0 ? `lvl ${s.levels[id]}` : 'not built'}</span>
                </span>
                <button
                  className="primary small"
                  disabled={busy || !check.ok}
                  title={check.ok ? undefined : check.reason}
                  onClick={() => run(() => api.build(s.id, id))}
                >
                  {check.targetLevel > def.maxLevel ? 'Max' : `→ ${check.targetLevel}`}
                </button>
              </div>
              {cost && (
                <div className="building-cost small">
                  {RESOURCES.map((r) => (
                    <span key={r} className={stock[r] < cost[r] ? 'short' : ''}>
                      <span className={`dot ${r}`} />
                      {fmtInt(cost[r])}
                    </span>
                  ))}
                  <span className="muted">{fmtDuration(check.timeSec ?? 0)}</span>
                  {!check.ok && <span className="reason">{check.reason}</span>}
                </div>
              )}
            </div>
          );
        })}
      </section>

      {locked.length > 0 && (
        <section className="card">
          <h3>Locked</h3>
          {locked.map((id) => (
            <div key={id} className="building locked small">
              <span>{BUILDINGS[id].name}</span>
              <span className="muted">
                {Object.entries(BUILDINGS[id].requires)
                  .map(([req, lvl]) => `${BUILDINGS[req as BuildingId].name} ${lvl}`)
                  .join(', ')}
              </span>
            </div>
          ))}
        </section>
      )}

      <section className="card">
        <h3>Land</h3>
        <Multiplier label="Food" value={s.profile.food} kind="food" />
        <Multiplier label="Steel" value={s.profile.steel} kind="steel" />
        <Multiplier label="Oil" value={s.profile.oil} kind="oil" />
        <div className="badges">
          {s.profile.rare > 0 && <span className="badge rare">Rare earths ×{s.profile.rare.toFixed(2)}</span>}
          {s.profile.uranium > 0 && <span className="badge uranium">Uranium ×{s.profile.uranium.toFixed(2)}</span>}
        </div>
      </section>
    </div>
  );
}
