import type { HexRow } from '@geowars/rules';
import { fmtInt } from '../util';
import type { HexOwner } from './MapView';
import { Multiplier } from './Multiplier';

interface Props {
  hex: HexRow;
  countries: Record<string, string>;
  owner: HexOwner | undefined;
  players: Record<number, string>;
}

export function HexPanel({ hex, countries, owner, players }: Props) {
  const [, country, name, food, steel, oil, rare, uranium] = hex;
  return (
    <div className="stack">
      <div>
        <h2>{name}</h2>
        <div className="muted">{countries[country] ?? country}</div>
      </div>

      <section className="card">
        {owner ? (
          <>
            <div>
              Ruled by <strong>{owner.ownerId ? (players[owner.ownerId] ?? 'Unknown') : 'Independent'}</strong>
            </div>
            <div className="muted">{fmtInt(owner.points)} points</div>
          </>
        ) : (
          <div className="muted">Unclaimed land. Governors will be able to settle or conquer hexes in a later milestone.</div>
        )}
      </section>

      <section className="card">
        <h3>Land</h3>
        <Multiplier label="Food" value={food} kind="food" />
        <Multiplier label="Steel" value={steel} kind="steel" />
        <Multiplier label="Oil" value={oil} kind="oil" />
        <div className="badges">
          {rare > 0 && <span className="badge rare">Rare earths ×{rare.toFixed(2)}</span>}
          {uranium > 0 && <span className="badge uranium">Uranium ×{uranium.toFixed(2)}</span>}
          {rare === 0 && uranium === 0 && <span className="muted small">No strategic resources</span>}
        </div>
      </section>
    </div>
  );
}
