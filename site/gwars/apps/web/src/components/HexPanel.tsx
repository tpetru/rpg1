import type { CountryRef, HexRow, OwnSettlementDto } from '@geowars/rules';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { HexOwner } from './MapView';
import { AttackPanel } from './AttackPanel';
import { Multiplier } from './Multiplier';

interface Props {
  hex: HexRow;
  /** The whole world's hexes, to name the player's settlements. */
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  owner: HexOwner | undefined;
  players: Record<number, string>;
  worldId: number;
  mine: OwnSettlementDto[];
  /** Called after an army is sent. */
  onSent: () => void;
}

export function HexPanel({ hex, hexes, countries, owner, players, worldId, mine, onSent }: Props) {
  const { t, hexName, countryName } = useI18n();
  const [, country, , food, steel, oil, rare, uranium] = hex;
  return (
    <div className="stack">
      <div>
        <h2>{hexName(hex, countries)}</h2>
        <div className="muted">{countryName(country, countries)}</div>
      </div>

      <section className="card">
        {owner ? (
          <div className="with-icon">
            {owner.ownerId !== 0 && players[owner.ownerId] && <NationEmblem name={players[owner.ownerId]} size={44} />}
            <div>
              <div>
                {owner.ownerId ? (
                  <>
                    {t('hex.ruledBy')} <strong>{players[owner.ownerId] ?? t('map.unknownNation')}</strong>
                  </>
                ) : (
                  <strong>{t('attack.title')}</strong>
                )}
              </div>
              <div className="muted">{t('points', { n: fmtInt(owner.points) })}</div>
            </div>
          </div>
        ) : (
          <div className="muted">{t('hex.unclaimedInfo')}</div>
        )}
      </section>

      {owner && !mine.some((m) => m.id === owner.settlementId) && (
        <section className="card">
          <h3>{owner.ownerId ? t('attack.send') : t('attack.title')}</h3>
          <AttackPanel worldId={worldId} targetId={owner.settlementId} abandoned={!owner.ownerId} mine={mine} hexes={hexes} countries={countries} onSent={onSent} />
        </section>
      )}

      <section className="card">
        <h3>{t('panel.land')}</h3>
        <Multiplier resource="food" value={food} />
        <Multiplier resource="steel" value={steel} />
        <Multiplier resource="oil" value={oil} />
        <div className="badges">
          {rare > 0 && (
            <span className="badge rare">
              {t('res.rare')} ×{rare.toFixed(2)}
            </span>
          )}
          {uranium > 0 && (
            <span className="badge uranium">
              {t('res.uranium')} ×{uranium.toFixed(2)}
            </span>
          )}
          {rare === 0 && uranium === 0 && <span className="muted small">{t('hex.noStrategic')}</span>}
        </div>
      </section>
    </div>
  );
}
