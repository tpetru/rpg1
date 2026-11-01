import { useState } from 'react';
import type { CommandDto, CountryRef, HexRow, IncomingCommandDto, OwnSettlementDto } from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import { useI18n } from '../i18n';
import { useNow } from '../util';
import { BackButton } from './BackButton';
import { MovementList } from './ReportsView';

interface Props {
  settlement: OwnSettlementDto;
  name: string;
  /** The player's own armies on the move. */
  outgoing: CommandDto[];
  /** Enemy armies heading for the player's settlements. */
  incoming: IncomingCommandDto[];
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  clockOffset: number;
  onShow: (idx: number) => void;
  onBack: () => void;
}

type Mode = 'out' | 'in';

/** The Radar page: switch between the armies the player sent and the ones coming for the player. */
export function RadarView({ settlement: s, name, outgoing: allOutgoing, incoming: allIncoming, hexes, countries, clockOffset, onShow, onBack }: Props) {
  const { t, hexName } = useI18n();
  const now = useNow(1000) + clockOffset;
  const [mode, setMode] = useState<Mode>('out');
  // This Radar watches its own settlement: armies sent from it (and coming home to it), and armies aimed at it.
  const outgoing = allOutgoing.filter((c) => c.originId === s.id);
  const incoming = allIncoming.filter((c) => c.targetId === s.id);
  const list = mode === 'out' ? outgoing : incoming;
  const label = (idx: number) => hexName(hexes[idx], countries);

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id="radar" size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t('building.radar.name')}</h1>
          <span className="muted small">{s.levels.radar > 0 ? t('building.radar.desc') : t('radar.noRadar')}</span>
        </div>
      </header>

      <div className="tabs radar-switch" role="group" aria-label={t('building.radar.name')}>
        <button className={mode === 'out' ? 'active' : ''} aria-pressed={mode === 'out'} onClick={() => setMode('out')}>
          {t('radar.outgoing')} ({outgoing.length})
        </button>
        <button className={mode === 'in' ? 'active' : ''} aria-pressed={mode === 'in'} onClick={() => setMode('in')}>
          {t('radar.incoming')} ({incoming.length})
        </button>
      </div>

      <div className="radar-list">
        {list.length === 0 ? (
          <p className="muted">{mode === 'in' && s.levels.radar < 2 ? t('radar.needLevel2') : t(mode === 'out' ? 'radar.noOutgoing' : 'radar.noIncoming')}</p>
        ) : (
          <MovementList commands={list} label={label} now={now} onShow={onShow} exact />
        )}
      </div>
    </section>
  );
}
