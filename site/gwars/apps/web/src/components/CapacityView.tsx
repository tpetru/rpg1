import { useState } from 'react';
import {
  BUILDINGS,
  checkBuild,
  housingCapacity,
  materialize,
  plannedLevels,
  productionPerHour,
  populationUsed,
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
  building: 'warehouse' | 'housing' | 'farm' | 'steelmill' | 'oilfield';
  worldId: number;
  settlement: OwnSettlementDto;
  name: string;
  settings: WorldSettings;
  clockOffset: number;
  onUpdate: (s: OwnSettlementDto) => void;
  onBack: () => void;
}

/** The Warehouse and Housing pages: what the building holds now, what the next level would hold. */
export function CapacityView({ building, worldId, settlement: s, name, settings, clockOffset, onUpdate, onBack }: Props) {
  const { t, codeText, errorText } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const def = BUILDINGS[building];
  const level = s.levels[building];
  const isStore = building === 'warehouse';
  const produces = def.produces === 'food' || def.produces === 'steel' || def.produces === 'oil' ? def.produces : null;
  /** What the building gives at a level: capacity for the stores, output per hour for the producers. */
  const capacityAt = (n: number) =>
    produces ? Math.round(productionPerHour(n, s.profile[produces], settings.speed)) : isStore ? warehouseCapacity(n) : housingCapacity(n);
  const unitLabel = produces ? t('cap.perHour', { resource: t(`res.${produces}`) }) : t(isStore ? 'cap.perResource' : 'cap.population');
  const rates = productionRates(s.levels, s.profile, settings.speed);
  const stock = materialize(s.stock, rates, warehouseCapacity(s.levels.warehouse), s.resourcesAt, now);
  const planned = plannedLevels(s.levels, s.queue)[building];
  const up = checkBuild({ levels: s.levels, queue: s.queue, stock, troopPop: s.troopPop, coastal: s.coastal }, building, settings);
  const maxed = level >= def.maxLevel;
  const upReason = up.ok || up.code === 'max_level' ? undefined : codeText(`build_${up.code}`, up.params, up.reason);

  const buildingsPop = populationUsed(s.levels);
  const popUsed = buildingsPop + s.troopPop;
  const nextLevel = level + 1;

  const upgrade = async () => {
    setBusy(true);
    setError(null);
    try {
      onUpdate(await api.build(worldId, s.id, building));
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  const nowLines = produces ? (
    <>
      <span className="fort-bonus mono">{t('panel.perHour', { n: fmtInt(capacityAt(level)) })}</span>
      <span className="muted small">{unitLabel}</span>
      <span className="small mono">{t('cap.landMult', { n: s.profile[produces].toFixed(2) })}</span>
    </>
  ) : isStore ? (
    <>
      <span className="fort-bonus mono">{fmtInt(capacityAt(level))}</span>
      <span className="muted small">{t('cap.perResource')}</span>
      <span className="small mono">
        {t('cap.stored', { food: fmtInt(stock.food), steel: fmtInt(stock.steel), oil: fmtInt(stock.oil) })}
      </span>
    </>
  ) : (
    <>
      <span className="fort-bonus mono">{fmtInt(capacityAt(level))}</span>
      <span className="muted small">{t('cap.population')}</span>
      <span className="small mono">{t('cap.popUsed', { used: fmtInt(popUsed), buildings: fmtInt(buildingsPop), troops: fmtInt(s.troopPop), free: fmtInt(Math.max(0, capacityAt(level) - popUsed)) })}</span>
    </>
  );

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id={building} size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t(`building.${building}.name`)}</h1>
          <span className="muted small">{produces ? t(`building.${building}.desc`) : t(isStore ? 'cap.warehouseDesc' : 'cap.housingDesc')}</span>
        </div>
      </header>

      {error != null && <div className="error">{errorText(error)}</div>}

      <div className="fort-grid">
        <div className="fort-card">
          <span className="fort-label">{t('fort.current')}</span>
          <strong className="fort-level">{t('panel.levelOf', { n: level, max: def.maxLevel })}</strong>
          {nowLines}
          {planned !== level && <span className="small fort-queued">{t('fort.queued', { n: planned })}</span>}
        </div>

        <div className="fort-card next">
          <span className="fort-label">{t('fort.next')}</span>
          {maxed ? (
            <strong className="fort-level">{t('panel.maxLevelOf', { n: def.maxLevel })}</strong>
          ) : (
            <>
              <strong className="fort-level">{t('panel.levelOf', { n: nextLevel, max: def.maxLevel })}</strong>
              <span className="fort-bonus mono">{produces ? t('panel.perHour', { n: fmtInt(capacityAt(nextLevel)) }) : fmtInt(capacityAt(nextLevel))}</span>
              <span className="muted small">{unitLabel}</span>
              <span className="small mono">{t('cap.gain', { n: fmtInt(capacityAt(nextLevel) - capacityAt(level)) })}</span>
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
