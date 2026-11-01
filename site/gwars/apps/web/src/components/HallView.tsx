import { useState } from 'react';
import {
  BUILDINGS,
  checkBuild,
  checkDowngrade,
  materialize,
  plannedLevels,
  productionRates,
  warehouseCapacity,
  type BuildingId,
  type OwnSettlementDto,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { BuildingIcon } from '../art/buildings';
import { CATALOGUE } from '../catalogue';
import { useI18n } from '../i18n';
import { fmtBuildTime, fmtDuration, useNow } from '../util';
import { BackButton } from './BackButton';
import { Costs } from './SettlementPanel';

interface Props {
  worldId: number;
  settlement: OwnSettlementDto;
  name: string;
  settings: WorldSettings;
  clockOffset: number;
  onUpdate: (s: OwnSettlementDto) => void;
  onBack: () => void;
}

/** The City Hall page: every building of the settlement with its upgrade and downgrade. */
export function HallView({ worldId, settlement: s, name, settings, clockOffset, onUpdate, onBack }: Props) {
  const { t, lang, codeText, errorText, buildingName } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  // Same formulas as the server, so what the buttons promise is what the server will accept.
  const rates = productionRates(s.levels, s.profile, settings.speed);
  const stock = materialize(s.stock, rates, warehouseCapacity(s.levels.warehouse), s.resourcesAt, now);
  const state = { levels: s.levels, queue: s.queue, stock, troopPop: s.troopPop, coastal: s.coastal };
  const planned = plannedLevels(s.levels, s.queue);

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

  const downgrade = (id: BuildingId, to: number) => {
    if (!window.confirm(t('hall.confirmDowngrade', { building: buildingName(id), n: to }))) return;
    void run(() => api.downgrade(worldId, s.id, id));
  };

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id="cityhall" size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t('hall.title')}</h1>
          <span className="muted small">
            {t('panel.queueSlots', { n: s.queue.length, max: settings.buildQueueSlots })} · {t('hall.note')}
          </span>
        </div>
      </header>

      {error != null && <div className="error">{errorText(error)}</div>}

      <section className="hall-queue" aria-label={t('panel.queue')}>
        <h3>{t('panel.queue')}</h3>
        {s.queue.length === 0 ? (
          <p className="muted small">{t('panel.queueEmpty')}</p>
        ) : (
          <table className="hall-queue-table">
            <thead>
              <tr>
                <th>{t('hall.q.building')}</th>
                <th className="num">{t('hall.q.current')}</th>
                <th className="num">{t('hall.q.upgrade')}</th>
                <th className="num">{t('hall.q.left')}</th>
                <th>{t('hall.q.finishes')}</th>
              </tr>
            </thead>
            <tbody>
              {(() => {
                const running = { ...s.levels };
                return s.queue.map((q) => {
                  const current = running[q.building];
                  running[q.building] = q.targetLevel;
                  return (
                    <tr key={q.id}>
                      <td>
                        <span className="hall-queue-name">
                          <BuildingIcon id={q.building} size={24} />
                          {buildingName(q.building)}
                        </span>
                      </td>
                      <td className="num mono">{current}</td>
                      <td className="num mono">{q.targetLevel}</td>
                      <td className="num mono">{fmtDuration(Math.max(0, (q.finishesAt - now) / 1000))}</td>
                      <td className="mono small">{new Date(q.finishesAt).toLocaleString(lang === 'ro' ? 'ro-RO' : 'en-GB', { dateStyle: 'short', timeStyle: 'medium' })}</td>
                    </tr>
                  );
                });
              })()}
            </tbody>
          </table>
        )}
      </section>

      <div className="hall-body">
        {CATALOGUE.map((group) => (
          <section key={group.title} className="hall-group">
            <h3>{t(group.title)}</h3>
            {group.ids.map((id) => {
              const up = checkBuild(state, id, settings);
              const down = checkDowngrade(state, id, settings);
              const maxed = !up.ok && up.code === 'max_level';
              const built = s.levels[id];
              const upReason = up.ok || maxed ? undefined : codeText(`build_${up.code}`, up.params, up.reason);
              const downReason = down.ok || down.code === 'min_level' ? undefined : codeText(`downgrade_${down.code}`, down.params, down.reason);
              return (
                <div key={id} className={`hall-row ${built > 0 ? '' : 'unbuilt'}`}>
                  <BuildingIcon id={id} size={40} className={built > 0 ? '' : 'unbuilt'} />
                  <div className="hall-name">
                    <strong>{buildingName(id)}</strong>
                    <span className="mono small">
                      {t('panel.levelOf', { n: built, max: BUILDINGS[id].maxLevel })}
                      {planned[id] !== built && <span className="hall-queued"> → {planned[id]}</span>}
                    </span>
                  </div>

                  <div className="hall-info">
                    {maxed ? (
                      <span className="muted small">{t('panel.maxLevelOf', { n: BUILDINGS[id].maxLevel })}</span>
                    ) : (
                      <span className="hall-line">
                        <span className="costs">{up.cost && <Costs cost={up.cost} stock={stock} />}</span>
                        <span className="mono small hall-time">{up.timeSec != null && `▲ ${fmtBuildTime(up.timeSec)}`}</span>
                      </span>
                    )}
                    {down.timeSec != null && (down.ok || down.code !== 'min_level') && (
                      <span className="hall-line">
                        <span />
                        <span className="mono small hall-time">▼ {fmtBuildTime(down.timeSec)}</span>
                      </span>
                    )}
                  </div>

                  <div className="hall-act">
                    <div className="hall-buttons">
                      {maxed ? (
                        <span />
                      ) : (
                        <button className="primary small" disabled={busy || !up.ok} title={upReason} onClick={() => void run(() => api.build(worldId, s.id, id))}>
                          ▲ {up.targetLevel === 1 ? t('panel.build') : t('panel.upgradeTo', { n: up.targetLevel })}
                        </button>
                      )}
                      <button className="small" disabled={busy || !down.ok} title={downReason} onClick={() => downgrade(id, down.targetLevel)}>
                        ▼ {t('hall.downgradeTo', { n: Math.max(0, down.targetLevel) })}
                      </button>

                    </div>
                    {upReason && <span className="hall-why">{upReason}</span>}
                    {downReason && <span className="hall-why">{downReason}</span>}
                  </div>
                </div>
              );
            })}
          </section>
        ))}
      </div>
    </section>
  );
}
