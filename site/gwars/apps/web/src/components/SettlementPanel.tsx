import { useEffect, useRef, useState } from 'react';
import {
  BUILDINGS,
  BUILDING_IDS,
  RESOURCES,
  SETTLEMENT_NAME_MAX,
  SETTLEMENT_NAME_MIN,
  buildingPop,
  checkBuild,
  housingCapacity,
  materialize,
  plannedLevels,
  populationUsed,
  productionRates,
  settlementNameIssue,
  warehouseCapacity,
  type BuildCheck,
  type BuildingId,
  type OwnSettlementDto,
  type ResourceBag,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { BuildingIcon } from '../art/buildings';
import { CATALOGUE } from '../catalogue';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtBuildTime, fmtDuration, useNow } from '../util';
import { Multiplier } from './Multiplier';

interface Props {
  worldId: number;
  settlement: OwnSettlementDto;
  /** The map's name for this hex in the player's language (used when no custom name is set). */
  defaultName: string;
  countryName: string;
  settings: WorldSettings;
  clockOffset: number;
  /** A building picked elsewhere (a parcel on the city plan); the hub opens on it. */
  focusBuilding?: { id: BuildingId; seq: number } | null;
  onUpdate: (s: OwnSettlementDto) => void;
  /** Called when local state is known to be out of date (a build should have finished). */
  onStale: () => void;
  /** Hides the panel so the map takes the whole screen. */
  onCollapse: () => void;
}

const COST_ORDER = RESOURCES;

function Costs({ cost, stock }: { cost: ResourceBag; stock: ResourceBag }) {
  return (
    <>
      {COST_ORDER.map((r) => (
        <span key={r} className={`cost ${stock[r] < cost[r] ? 'short' : ''}`}>
          <span className={`dot ${r}`} />
          {fmtInt(cost[r])}
        </span>
      ))}
    </>
  );
}

export function SettlementPanel({
  worldId,
  settlement: s,
  defaultName,
  countryName,
  settings,
  clockOffset,
  focusBuilding,
  onUpdate,
  onStale,
  onCollapse,
}: Props) {
  const { t, codeText, errorText, buildingName } = useI18n();
  const now = useNow(1000) + clockOffset;
  const name = s.customName ?? defaultName;
  const [selected, setSelected] = useState<BuildingId>('cityhall');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const lastStale = useRef(0);
  const draftIssue = draft.length > 0 ? settlementNameIssue(draft) : null;

  // Picking a parcel on the city plan hands the hub that building; a new seq means a new pick.
  useEffect(() => {
    if (focusBuilding) setSelected(focusBuilding.id);
  }, [focusBuilding]);

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

  const run = async (action: () => Promise<OwnSettlementDto>): Promise<boolean> => {
    setBusy(true);
    setError(null);
    try {
      onUpdate(await action());
      return true;
    } catch (err) {
      setError(err);
      return false;
    } finally {
      setBusy(false);
    }
  };

  const saveName = async (newName: string | null) => {
    if (await run(() => api.renameSettlement(worldId, s.id, newName))) setEditing(false);
  };

  const checks = Object.fromEntries(BUILDING_IDS.map((id) => [id, checkBuild({ levels: s.levels, queue: s.queue, stock }, id, settings)])) as Record<
    BuildingId,
    BuildCheck
  >;
  const unmet = (id: BuildingId) =>
    Object.entries(BUILDINGS[id].requires).filter(([req, lvl]) => s.levels[req as BuildingId] < lvl!) as [BuildingId, number][];
  const requirementText = (id: BuildingId) =>
    t('panel.requires', { list: unmet(id).map(([req, lvl]) => `${buildingName(req)} ${lvl}`).join(' · ') });
  const queuedTo = (id: BuildingId) => s.queue.filter((q) => q.building === id).at(-1)?.targetLevel;
  const buildable = BUILDING_IDS.filter((id) => checks[id].ok).length;

  const def = BUILDINGS[selected];
  const check = checks[selected];
  const selectedLocked = unmet(selected).length > 0;
  const selectedMaxed = !check.ok && check.code === 'max_level';
  const selectedQueued = queuedTo(selected);
  const extraPop = check.targetLevel <= def.maxLevel ? buildingPop(def, check.targetLevel) - buildingPop(def, check.targetLevel - 1) : 0;
  const blockReason = check.ok ? undefined : codeText(`build_${check.code}`, check.params, check.reason);

  return (
    <div>
      <div className="panel-top">
        <button className="link" onClick={onCollapse}>
          ‹ {t('panel.collapse')}
        </button>
      </div>

      <header>
        {editing ? (
          <form
            className="rename-form"
            onSubmit={(e) => {
              e.preventDefault();
              if (!settlementNameIssue(draft)) void saveName(draft);
            }}
          >
            <input
              value={draft}
              onChange={(e) => {
                setDraft(e.target.value);
                setError(null);
              }}
              maxLength={SETTLEMENT_NAME_MAX}
              autoFocus
              aria-label={t('panel.rename')}
            />
            <div className="rename-actions">
              <button className="primary small" disabled={busy || draft.length === 0 || !!draftIssue}>
                {t('panel.renameSave')}
              </button>
              <button type="button" className="small" onClick={() => setEditing(false)}>
                {t('panel.cancel')}
              </button>
              {s.customName && (
                <button type="button" className="link" disabled={busy} onClick={() => void saveName(null)}>
                  {t('panel.renameReset')}
                </button>
              )}
            </div>
            <div className={`hint small ${draftIssue ? 'bad' : ''}`}>
              {draftIssue ? codeText(draftIssue, { min: SETTLEMENT_NAME_MIN, max: SETTLEMENT_NAME_MAX }) : t('panel.renameHint')}
            </div>
          </form>
        ) : (
          <h1 className="settlement-name">
            {name}
            <button
              className="icon-button"
              onClick={() => {
                setDraft(name);
                setError(null);
                setEditing(true);
              }}
              title={t('panel.rename')}
              aria-label={t('panel.rename')}
            >
              ✎
            </button>
          </h1>
        )}
        <div className="meta-row">
          <span>{countryName}</span>
          <span className="sep">/</span>
          <span className="mono">{t('points', { n: fmtInt(s.points) })}</span>
          <span className="sep">/</span>
          <span>{t('panel.loyalty', { n: s.loyalty })}</span>
        </div>
      </header>

      <div className="settlement-body">
        <section>
          <div className="meters">
            {RESOURCES.map((r) => (
              <div key={r}>
                <div className="meter-label">
                  <span className={`dot ${r}`} />
                  {t(`res.${r}` as TextKey)}
                </div>
                <div className={`meter-value ${stock[r] >= cap ? 'full' : ''}`}>{fmtInt(stock[r])}</div>
                <div className="meter-rate">{t('panel.perHour', { n: fmtInt(rates[r]) })}</div>
              </div>
            ))}
          </div>
          <div className="stats-row">
            <span>
              {t('panel.storage')} <span className="mono">{fmtInt(cap)}</span>
            </span>
            <span>
              {t('panel.population')}{' '}
              <span className={`mono ${popUsed >= popCap ? 'full' : ''}`}>
                {fmtInt(popUsed)} / {fmtInt(popCap)}
              </span>{' '}
              <span className="pop-bar">
                <span style={{ width: `${Math.min(100, (popUsed / popCap) * 100)}%` }} />
              </span>
            </span>
          </div>
        </section>

        <section className="queue-card" aria-label={t('panel.queue')}>
          <div className="queue-head">
            <span>{t('panel.queue')}</span>
            <span>{t('panel.queueSlots', { n: s.queue.length, max: settings.buildQueueSlots })}</span>
          </div>
          {s.queue.length === 0 && <div className="queue-empty">{t('panel.queueEmpty')}</div>}
          {s.queue.map((q, i) => {
            const isLast = i === s.queue.length - 1;
            const cancel = isLast && (
              <button className="link" disabled={busy} onClick={() => run(() => api.cancelBuild(worldId, s.id, q.id))}>
                {t('panel.cancel')}
              </button>
            );
            if (i === 0) {
              const progress = Math.min(1, Math.max(0, (now - q.startsAt) / (q.finishesAt - q.startsAt)));
              return (
                <div key={q.id} className="queue-active">
                  <span className="queue-tile">
                    <BuildingIcon id={q.building} size={32} />
                  </span>
                  <div className="queue-info">
                    <div className="queue-line">
                      <span>
                        {buildingName(q.building)} <span className="to">{t('panel.toLevel', { n: q.targetLevel })}</span>
                      </span>
                      <span className="queue-time">
                        {fmtDuration((q.finishesAt - now) / 1000)} {cancel}
                      </span>
                    </div>
                    <div className="progress">
                      <div style={{ width: `${progress * 100}%` }} />
                    </div>
                  </div>
                </div>
              );
            }
            return (
              <div key={q.id} className="queue-next">
                <span className="with-icon">
                  <span className="queue-tile small">
                    <BuildingIcon id={q.building} size={20} />
                  </span>
                  <span>
                    {buildingName(q.building)} {t('panel.toLevel', { n: q.targetLevel })}
                    <span className="wait">{fmtBuildTime((q.finishesAt - now) / 1000)}</span>
                  </span>
                </span>
                {cancel}
              </div>
            );
          })}
        </section>

        {error != null && <div className="error">{errorText(error)}</div>}

        <section className="inspector" aria-live="polite">
          <div className="inspector-head">
            <BuildingIcon id={selected} size={92} />
            <div>
              <h2 className="inspector-title">{buildingName(selected)}</h2>
              <div className="inspector-meta">
                <span className="mono">{t('panel.levelOf', { n: s.levels[selected], max: def.maxLevel })}</span>
                <span className="sep">/</span>
                <span>{selectedQueued ? t('panel.queuedTo', { n: selectedQueued }) : t('panel.notInQueue')}</span>
              </div>
              <p className="inspector-desc">{t(`building.${selected}.desc` as TextKey)}</p>
            </div>
          </div>
          <div className="inspector-foot">
            <div>
              {check.cost && (
                <div className="costs">
                  <Costs cost={check.cost} stock={stock} />
                </div>
              )}
              <div className={`build-note ${blockReason && !check.cost ? 'blocked' : ''}`}>
                {selectedLocked
                  ? requirementText(selected)
                  : selectedMaxed
                    ? t('panel.maxLevelOf', { n: def.maxLevel })
                    : [
                        t('panel.toBuild', { time: fmtBuildTime(check.timeSec ?? 0) }),
                        extraPop > 0 ? t('panel.popNeeded', { n: extraPop }) : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                {blockReason && !selectedLocked && !selectedMaxed && <div className="blocked">{blockReason}</div>}
              </div>
            </div>
            {!selectedMaxed && (
              <button className="primary" disabled={busy || !check.ok} title={blockReason} onClick={() => run(() => api.build(worldId, s.id, selected))}>
                {check.targetLevel === 1 ? t('panel.build') : t('panel.upgradeTo', { n: check.targetLevel })}
              </button>
            )}
          </div>
        </section>

        <section>
          <div className="catalogue-head">
            <h3>{t('panel.allBuildings')}</h3>
            <span className="faint small">{t('panel.buildable', { n: buildable, total: BUILDING_IDS.length })}</span>
          </div>
          {CATALOGUE.map((group) => (
            <div key={group.title} className="cat-group">
              <div className="cat-label">
                <h4>{t(group.title)}</h4>
              </div>
              <div className="cat-grid">
                {group.ids.map((id) => {
                  const c = checks[id];
                  const locked = unmet(id).length > 0;
                  const maxed = !c.ok && c.code === 'max_level';
                  const queued = queuedTo(id);
                  const built = s.levels[id];
                  return (
                    <button
                      key={id}
                      className={`cat-item ${selected === id ? 'selected' : ''} ${queued ? 'queued' : ''} ${locked ? 'locked' : ''}`}
                      onClick={() => setSelected(id)}
                      aria-pressed={selected === id}
                    >
                      <BuildingIcon id={id} size={44} className={built > 0 ? '' : 'unbuilt'} />
                      <span className="cat-text">
                        <span className="cat-title">
                          <span className="cat-name">{buildingName(id)}</span>
                          {locked ? <span className="lock-icon">🔒︎</span> : built > 0 && <span className="cat-level">{built}</span>}
                          {!locked && !maxed && c.timeSec != null && (
                            <span className="cat-time">
                              {queued ? fmtDuration(((s.queue.find((q) => q.building === id)?.finishesAt ?? now) - now) / 1000) : fmtBuildTime(c.timeSec)}
                            </span>
                          )}
                        </span>
                        {locked ? (
                          <span className="cat-sub">{requirementText(id)}</span>
                        ) : maxed ? (
                          <span className="cat-sub">{t('panel.maxLevelOf', { n: BUILDINGS[id].maxLevel })}</span>
                        ) : queued ? (
                          <span className="cat-sub">{t('panel.queuedTo', { n: queued })}</span>
                        ) : (
                          c.cost && (
                            <span className="cat-costs">
                              <Costs cost={c.cost} stock={stock} />
                            </span>
                          )
                        )}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </section>

        <section className="land-block">
          <h3>{t('panel.land')}</h3>
          <div className="land-grid">
            <Multiplier resource="food" value={s.profile.food} />
            <Multiplier resource="steel" value={s.profile.steel} />
            <Multiplier resource="oil" value={s.profile.oil} />
          </div>
          <div className="badges">
            {s.profile.rare > 0 && (
              <span className="badge rare">
                {t('res.rare')} ×{s.profile.rare.toFixed(2)}
              </span>
            )}
            {s.profile.uranium > 0 && (
              <span className="badge uranium">
                {t('res.uranium')} ×{s.profile.uranium.toFixed(2)}
              </span>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
