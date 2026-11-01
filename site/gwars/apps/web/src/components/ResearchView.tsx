import { useState } from 'react';
import {
  UNITS,
  UNIT_IDS,
  canAfford,
  materialize,
  productionRates,
  researchTimeSec,
  warehouseCapacity,
  type OwnSettlementDto,
  type UnitId,
  type WorldSettings,
} from '@geowars/rules';
import { api } from '../api';
import { BuildingIcon } from '../art/buildings';
import { UnitIcon } from '../art/units';
import { useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
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

/** The Research Center page: every unit has to be researched here before it can be trained. */
export function ResearchView({ worldId, settlement: s, name, settings, clockOffset, onUpdate, onBack }: Props) {
  const { t, errorText } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const rates = productionRates(s.levels, s.profile, settings.speed);
  const stock = materialize(s.stock, rates, warehouseCapacity(s.levels.warehouse), s.resourcesAt, now);

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

  const reasonFor = (unit: UnitId): string | null => {
    const def = UNITS[unit];
    if (s.levels.researchcenter < def.research.level) return t('research.needs', { level: def.research.level });
    if (s.researching) return t('research.busy');
    if (!canAfford(stock, def.research.cost)) return t('err.research_resources');
    return null;
  };

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id="researchcenter" size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t('research.title')}</h1>
          <span className="muted small">{t('research.note')}</span>
        </div>
      </header>

      {error != null && <div className="error">{errorText(error)}</div>}

      <div className="hall-body">
        {UNIT_IDS.map((unit) => {
          const def = UNITS[unit];
          const done = s.researched.includes(unit);
          const running = s.researching?.unit === unit ? s.researching : null;
          const reason = done || running ? null : reasonFor(unit);
          return (
            <div key={unit} className={`hall-row ${done ? '' : 'unbuilt'}`}>
              <UnitIcon unit={unit} size={40} />
              <div className="hall-name">
                <strong>{t(`unit.${unit}.name` as TextKey)}</strong>
                <span className="mono small">{t('troops.stats', { attack: def.attack, defense: def.defense, speed: def.speedKmh, pop: def.pop })}</span>
              </div>
              <div className="hall-info">
                {!done && (
                  <span className="hall-line">
                    <span className="costs">
                      <Costs cost={def.research.cost} stock={stock} />
                    </span>
                    <span className="mono small hall-time">{fmtBuildTime(researchTimeSec(def, s.levels.researchcenter, settings.recruitSpeed))}</span>
                  </span>
                )}
              </div>
              <div className="hall-act">
                {done ? (
                  <span className="muted small">✓ {t('research.done')}</span>
                ) : running ? (
                  <div className="hall-buttons">
                    <span className="mono small">{t('research.left', { time: fmtDuration((running.finishesAt - now) / 1000) })}</span>
                    <button className="small" disabled={busy} onClick={() => void run(() => api.cancelResearch(worldId, s.id, running.id))}>
                      {t('research.cancel')}
                    </button>
                  </div>
                ) : (
                  <div className="hall-buttons">
                    <button className="primary small" disabled={busy || reason !== null} title={reason ?? undefined} onClick={() => void run(() => api.research(worldId, s.id, unit))}>
                      {t('research.start')}
                    </button>
                  </div>
                )}
                {reason && <span className="hall-why">{reason}</span>}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
