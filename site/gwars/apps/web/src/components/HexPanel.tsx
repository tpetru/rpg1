import type { CountryRef, HexRow } from '@geowars/rules';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { HexOwner } from './MapView';
import { Multiplier } from './Multiplier';

interface Props {
  hex: HexRow;
  countries: Record<string, CountryRef>;
  owner: HexOwner | undefined;
  players: Record<number, string>;
}

export function HexPanel({ hex, countries, owner, players }: Props) {
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
            {owner.ownerId && players[owner.ownerId] && <NationEmblem name={players[owner.ownerId]} size={44} />}
            <div>
              <div>
                {t('hex.ruledBy')}{' '}
                <strong>{owner.ownerId ? (players[owner.ownerId] ?? t('map.unknownNation')) : t('map.independent')}</strong>
              </div>
              <div className="muted">{t('points', { n: fmtInt(owner.points) })}</div>
            </div>
          </div>
        ) : (
          <div className="muted">{t('hex.unclaimedInfo')}</div>
        )}
      </section>

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
