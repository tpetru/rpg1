import { useCallback, useEffect, useMemo, useState } from 'react';
import type { MapHexesResponse, MeResponse, OwnSettlementDto, PlayerInfo, ServerMessage, WorldInfo } from '@geowars/rules';
import { api } from '../api';
import { fmtInt, useServerEvents } from '../util';
import { HexPanel } from './HexPanel';
import { MapView, type HexOwner } from './MapView';
import { SettlementPanel } from './SettlementPanel';

interface Props {
  world: WorldInfo;
  player: PlayerInfo;
  account: MeResponse['account'];
  clockOffset: number;
  onLeave: () => void;
  onLogout: () => void;
}

export function GameScreen({ world, player, account, clockOffset, onLeave, onLogout }: Props) {
  const [map, setMap] = useState<MapHexesResponse | null>(null);
  const [owners, setOwners] = useState(new Map<number, HexOwner>());
  const [players, setPlayers] = useState<Record<number, string>>({});
  const [mine, setMine] = useState<OwnSettlementDto[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [focus, setFocus] = useState<{ idx: number; seq: number } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadMine = useCallback(async () => {
    try {
      setMine(await api.mySettlements(world.id));
    } catch (err) {
      setError((err as Error).message);
    }
  }, [world.id]);

  useEffect(() => {
    Promise.all([api.hexes(world.id), api.mapSettlements(world.id), api.mySettlements(world.id)]).then(
      ([hexes, settlements, own]) => {
        setMap(hexes);
        setOwners(new Map(settlements.settlements.map(([idx, id, ownerId, points]) => [idx, { settlementId: id, ownerId, points }])));
        setPlayers(settlements.players);
        setMine(own);
        if (own[0]) {
          setSelected(own[0].idx);
          setFocus({ idx: own[0].idx, seq: Date.now() });
        }
      },
      (err: Error) => setError(err.message),
    );
  }, [world.id]);

  useServerEvents(
    world.id,
    useCallback(
      (msg: ServerMessage) => {
        if (msg.t === 'settlement') void loadMine();
        if (msg.t === 'map') {
          const [idx, id, ownerId, points] = msg.row;
          setOwners((prev) => new Map(prev).set(idx, { settlementId: id, ownerId, points }));
          if (msg.ownerName) setPlayers((prev) => ({ ...prev, [ownerId]: msg.ownerName! }));
        }
      },
      [loadMine],
    ),
  );

  const updateSettlement = useCallback((s: OwnSettlementDto) => {
    setMine((prev) => prev.map((x) => (x.id === s.id ? s : x)));
  }, []);

  const totalPoints = useMemo(() => mine.reduce((sum, s) => sum + s.points, 0), [mine]);
  const selectedOwn = mine.find((s) => s.idx === selected);

  if (error && !map) return <div className="splash">Could not load the world: {error}</div>;
  if (!map) return <div className="splash">Loading world…</div>;

  return (
    <div className="game">
      <header className="topbar">
        <span className="logo small">GeoWars</span>
        <button onClick={onLeave} title="Switch world">
          {world.name}
        </button>
        <div className="settlement-tabs">
          {mine.map((s) => (
            <button
              key={s.id}
              className={s.idx === selected ? 'active' : ''}
              onClick={() => {
                setSelected(s.idx);
                setFocus({ idx: s.idx, seq: Date.now() });
              }}
            >
              {s.name}
            </button>
          ))}
        </div>
        <span className="spacer" />
        <span>
          <strong>{player.nation}</strong> <span className="muted">({account.username})</span> · {fmtInt(totalPoints)} points
        </span>
        <button onClick={onLogout}>Log out</button>
      </header>

      <MapView
        hexes={map.hexes}
        countries={map.countries}
        owners={owners}
        players={players}
        myId={account.id}
        selected={selected}
        focus={focus}
        onSelect={setSelected}
      />

      <aside className="panel">
        {selectedOwn ? (
          <SettlementPanel
            key={selectedOwn.id}
            worldId={world.id}
            settlement={selectedOwn}
            countryName={map.countries[selectedOwn.countryCode] ?? selectedOwn.countryCode}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onStale={loadMine}
          />
        ) : selected !== null ? (
          <HexPanel hex={map.hexes[selected]} countries={map.countries} owner={owners.get(selected)} players={players} />
        ) : (
          <div className="muted">Click a hex on the map.</div>
        )}
      </aside>
    </div>
  );
}
