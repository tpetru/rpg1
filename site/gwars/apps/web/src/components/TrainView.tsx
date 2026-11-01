import {
  materialize,
  productionRates,
  warehouseCapacity,
  type BuildingId,
  type OwnSettlementDto,
  type WorldSettings,
} from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import { useI18n } from '../i18n';
import { useNow } from '../util';
import { BackButton } from './BackButton';
import { TroopsSection } from './TroopsSection';

interface Props {
  worldId: number;
  settlement: OwnSettlementDto;
  building: BuildingId;
  name: string;
  settings: WorldSettings;
  clockOffset: number;
  onUpdate: (s: OwnSettlementDto) => void;
  onBack: () => void;
}

/** The Barracks and Factory page: troops at home, the training queue and the order form. */
export function TrainView({ worldId, settlement: s, building, name, settings, clockOffset, onUpdate, onBack }: Props) {
  const { t, buildingName } = useI18n();
  const now = useNow(1000) + clockOffset;
  const rates = productionRates(s.levels, s.profile, settings.speed);
  const stock = materialize(s.stock, rates, warehouseCapacity(s.levels.warehouse), s.resourcesAt, now);

  return (
    <section className="hall-page train-page">
      <header className="hall-head">
        <BuildingIcon id={building} size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{buildingName(building)}: {t('troops.title').toLowerCase()}</h1>
        </div>
      </header>
      <TroopsSection
        worldId={worldId}
        settlement={s}
        building={building}
        stock={stock}
        settings={settings}
        now={now}
        onUpdate={onUpdate}
      />
    </section>
  );
}
