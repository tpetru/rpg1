import { useState } from 'react';
import {
  BUILDINGS,
  FORTIFICATION_BONUS,
  checkBuild,
  materialize,
  plannedLevels,
  productionRates,
  warehouseCapacity,
  type OwnSettlementDto,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { BuildingIcon } from '../art/buildings';
import { fmtInt, useI18n } from '../i18n';
import { fmtBuildTime, useNow } from '../util';
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

/** Extra defence in percent that a level of Fortifications gives. */
const bonusPct = (level: number) => (FORTIFICATION_BONUS ** Math.max(0, level) - 1) * 100;
const fmtPct = (n: number) => `+${n.toFixed(1)}%`;

/** The Fortifications page: what the building does, the bonus now and the bonus of the next level. */
export function FortView({ worldId, settlement: s, name, settings, clockOffset, onUpdate, onBack }: Props) {
  const { t, codeText, errorText } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const def = BUILDINGS.fortifications;
  const level = s.levels.fortifications;
  const rates = productionRates(s.levels, s.profile, settings.speed);
  const stock = materialize(s.stock, rates, warehouseCapacity(s.levels.warehouse), s.resourcesAt, now);
  const planned = plannedLevels(s.levels, s.queue).fortifications;
  const up = checkBuild({ levels: s.levels, queue: s.queue, stock, troopPop: s.troopPop, coastal: s.coastal }, 'fortifications', settings);
  const maxed = level >= def.maxLevel;
  const upReason = up.ok || up.code === 'max_level' ? undefined : codeText(`build_${up.code}`, up.params, up.reason);

  const upgrade = async () => {
    setBusy(true);
    setError(null);
    try {
      onUpdate(await api.build(worldId, s.id, 'fortifications'));
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  const nextLevel = level + 1;

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id="fortifications" size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t('building.fortifications.name')}</h1>
          <span className="muted small">{t('fort.desc')}</span>
        </div>
      </header>

      {error != null && <div className="error">{errorText(error)}</div>}

      <div className="fort-grid">
        <div className="fort-card">
          <span className="fort-label">{t('fort.current')}</span>
          <strong className="fort-level">{t('panel.levelOf', { n: level, max: def.maxLevel })}</strong>
          <span className="fort-bonus mono">{level > 0 ? fmtPct(bonusPct(level)) : '—'}</span>
          <span className="muted small">{level > 0 ? t('fort.example', { n: fmtInt(Math.round(100 * FORTIFICATION_BONUS ** level)) }) : t('fort.none')}</span>
          {planned !== level && <span className="small fort-queued">{t('fort.queued', { n: planned })}</span>}
        </div>

        <div className="fort-card next">
          <span className="fort-label">{t('fort.next')}</span>
          {maxed ? (
            <strong className="fort-level">{t('panel.maxLevelOf', { n: def.maxLevel })}</strong>
          ) : (
            <>
              <strong className="fort-level">{t('panel.levelOf', { n: nextLevel, max: def.maxLevel })}</strong>
              <span className="fort-bonus mono">{fmtPct(bonusPct(nextLevel))}</span>
              <span className="muted small">{t('fort.gain', { n: (bonusPct(nextLevel) - bonusPct(level)).toFixed(1) })}</span>
              <div className="fort-up">
                <span className="hall-line">
                  <span className="costs">{up.cost && <Costs cost={up.cost} stock={stock} />}</span>
                  <span className="mono small hall-time">{up.timeSec != null ? `▲ ${fmtBuildTime(up.timeSec)}` : ''}</span>
                </span>
                <button className="primary small" disabled={busy || !up.ok} title={upReason} onClick={() => void upgrade()}>
                  ▲ {t('panel.upgradeTo', { n: up.targetLevel })}
                </button>
                {upReason && <span className="hall-why">{upReason}</span>}
              </div>
            </>
          )}
        </div>
      </div>
    </section>
  );
}
