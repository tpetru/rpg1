import { useEffect } from 'react';
import { UNITS, trainTimeSec, type UnitId, type WorldSettings } from '@geowars/rules';
import { UnitIcon } from '../art/units';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtBuildTime } from '../util';

interface Props {
  unit: UnitId;
  /** Level of the training building, for the time of one unit. */
  buildingLevel: number;
  settings: WorldSettings;
  onClose: () => void;
}

/** What one unit is: what it does, how strong and fast it is, the population it takes and its price. */
export function UnitDialog({ unit, buildingLevel, settings, onClose }: Props) {
  const { t, buildingName } = useI18n();
  const def = UNITS[unit];

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className="modal unit-dialog" role="dialog" aria-modal="true" aria-label={t(`unit.${unit}.name` as TextKey)} onMouseDown={(e) => e.stopPropagation()}>
        <header className="modal-head">
          <UnitIcon unit={unit} size={56} />
          <div className="modal-title">
            <h2>{t(`unit.${unit}.name` as TextKey)}</h2>
            <span className="muted small">{t('troops.trainedIn', { building: buildingName(def.trainedAt) })}</span>
          </div>
          <button className="link modal-close" onClick={onClose} aria-label={t('hall.close')}>
            ×
          </button>
        </header>

        <p className="unit-desc">{t(`unit.${unit}.desc` as TextKey)}</p>

        <dl className="unit-stats">
          <div>
            <dt>{t('unit.attack')}</dt>
            <dd className="mono">{fmtInt(def.attack)}</dd>
          </div>
          <div>
            <dt>{t('unit.defense')}</dt>
            <dd className="mono">{fmtInt(def.defense)}</dd>
          </div>
          <div>
            <dt>{t('unit.speed')}</dt>
            <dd className="mono">{fmtInt(def.speedKmh)} km/h</dd>
          </div>
          <div>
            <dt>{t('unit.pop')}</dt>
            <dd className="mono">{fmtInt(def.pop)}</dd>
          </div>
          <div>
            <dt>{t('unit.time')}</dt>
            <dd className="mono">{fmtBuildTime(trainTimeSec(def, 1, buildingLevel, settings.recruitSpeed))}</dd>
          </div>
        </dl>

        <h3 className="unit-cost-title">{t('unit.cost')}</h3>
        <div className="costs unit-cost">
          {(['food', 'steel', 'oil'] as const).map((r) => (
            <span key={r} className="cost">
              <span className={`dot ${r}`} />
              {fmtInt(def.cost[r])}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}
