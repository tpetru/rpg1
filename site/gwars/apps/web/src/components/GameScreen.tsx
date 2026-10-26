import { useCallback, useEffect, useMemo, useState } from 'react';
import type { BuildingId, MapHexesResponse, MeResponse, OwnSettlementDto, PlayerInfo, ServerMessage, WorldInfo } from '@geowars/rules';
import { api } from '../api';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import { prefs, useServerEvents } from '../util';
import { CityView } from './CityView';
import { CountryView } from './CountryView';
import { HexPanel } from './HexPanel';
import { LanguageSwitch } from './LanguageSwitch';
import { ThemeToggle } from './ThemeToggle';
import { MapControls, type SearchTarget } from './MapControls';
import { MapView, type HexOwner, type MapMode } from './MapView';
import { SettlementPanel } from './SettlementPanel';

const MAP_MODES: MapMode[] = ['owners', 'countries', 'food', 'steel', 'oil', 'rare', 'uranium'];

/** Three ways to look at the world: the hex map, the nation at once, or one settlement as a plan. */
type View = 'map' | 'country' | 'city';

interface Props {
  world: WorldInfo;
  player: PlayerInfo;
  account: MeResponse['account'];
  clockOffset: number;
  onLeave: () => void;
  onLogout: () => void;
}

export function GameScreen({ world, player, account, clockOffset, onLeave, onLogout }: Props) {
  const { t, errorText, hexName, countryName } = useI18n();
  const [map, setMap] = useState<MapHexesResponse | null>(null);
  const [owners, setOwners] = useState(new Map<number, HexOwner>());
  const [players, setPlayers] = useState<Record<number, string>>({});
  const [mine, setMine] = useState<OwnSettlementDto[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [focus, setFocus] = useState<{ idx: number; seq: number } | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [panelOpen, setPanelOpen] = useState(true);
  /** Set when a parcel on the city plan is picked: the hub opens on that building. */
  const [focusBuilding, setFocusBuilding] = useState<{ id: BuildingId; seq: number } | null>(null);
  const [view, setViewState] = useState<View>(() => {
    const saved = prefs.get('gw.view');
    return saved === 'country' || saved === 'city' ? saved : 'map';
  });
  const setView = useCallback((next: View) => {
    prefs.set('gw.view', next);
    setViewState(next);
  }, []);
  const [mode, setModeState] = useState<MapMode>(() => (MAP_MODES.includes(prefs.get('gw.mapmode') as MapMode) ? (prefs.get('gw.mapmode') as MapMode) : 'owners'));
  const setMode = useCallback((next: MapMode) => {
    prefs.set('gw.mapmode', next);
    setModeState(next);
  }, []);
  const pickTarget = useCallback((target: SearchTarget) => {
    if (target.select) setSelected(target.idx);
    setFocus({ idx: target.idx, seq: Date.now() });
  }, []);

  const loadMine = useCallback(async () => {
    try {
      setMine(await api.mySettlements(world.id));
    } catch (err) {
      setError(err);
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
      setError,
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

  const customNames = useMemo(() => mine.flatMap((s) => (s.customName ? [{ idx: s.idx, name: s.customName }] : [])), [mine]);
  const totalPoints = useMemo(() => mine.reduce((sum, s) => sum + s.points, 0), [mine]);
  const selectedOwn = mine.find((s) => s.idx === selected);

  if (error != null && !map) return <div className="splash">{t('app.worldLoadError', { message: errorText(error) })}</div>;
  if (!map) return <div className="splash">{t('app.loadingWorld')}</div>;

  return (
    <div className={`game ${panelOpen ? '' : 'panel-closed'} ${view === 'map' ? '' : 'view-open'}`}>
      <header className="topbar">
        <span className="wordmark">GeoWars</span>
        <button className="world-button" onClick={onLeave} title={t('game.switchWorld')}>
          {world.name}
        </button>
        <span className="topbar-sep" />
        <div className="view-switch" role="group" aria-label={t('view.map')}>
          <button className={view === 'map' ? 'active' : ''} aria-pressed={view === 'map'} onClick={() => setView('map')}>
            {t('view.map')}
          </button>
          <button className={view === 'country' ? 'active' : ''} aria-pressed={view === 'country'} onClick={() => setView('country')}>
            {t('view.overview')}
          </button>
          <button className={view === 'city' ? 'active' : ''} aria-pressed={view === 'city'} onClick={() => setView('city')}>
            {t('view.city')}
          </button>
        </div>
        <nav className="settlement-tabs">
          {mine.map((s) => (
            <button
              key={s.id}
              className={s.idx === selected ? 'active' : ''}
              onClick={() => {
                setSelected(s.idx);
                setFocus({ idx: s.idx, seq: Date.now() });
                // In the city view, a tab switches the town being looked at rather than leaving it.
                setView(view === 'city' ? 'city' : 'map');
              }}
            >
              {s.customName ?? hexName(map.hexes[s.idx], map.countries)}
            </button>
          ))}
        </nav>
        <span className="spacer" />
        <div className="account">
          <NationEmblem name={player.nation} size={34} title={player.nation} />
          <div className="account-text">
            <strong>{player.nation}</strong>
            <span>{account.username}</span>
          </div>
          <span className="points mono">{t('points', { n: fmtInt(totalPoints) })}</span>
        </div>
        <span className="topbar-sep" />
        <LanguageSwitch />
        <ThemeToggle />
        <button className="link" onClick={onLogout}>
          {t('auth.logout')}
        </button>
      </header>

      {view === 'country' ? (
        <CountryView
          nation={player.nation}
          settlements={mine}
          hexes={map.hexes}
          countries={map.countries}
          settings={world.settings}
          onOpen={(s) => {
            setSelected(s.idx);
            setFocus({ idx: s.idx, seq: Date.now() });
            setView('map');
          }}
        />
      ) : view === 'city' ? (
        selectedOwn ? (
          <CityView
            settlement={selectedOwn}
            defaultName={hexName(map.hexes[selectedOwn.idx], map.countries)}
            countryName={countryName(selectedOwn.countryCode, map.countries)}
            onOpenBuilding={(id) => {
              setFocusBuilding({ id, seq: Date.now() });
              setSelected(selectedOwn.idx);
              setPanelOpen(true);
              setView('map');
            }}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : (
        <>
          <MapView
            hexes={map.hexes}
            countries={map.countries}
            owners={owners}
            players={players}
            mode={mode}
            myId={account.id}
            selected={selected}
            focus={focus}
            onSelect={setSelected}
          >
            <MapControls
              mode={mode}
              onMode={setMode}
              hexes={map.hexes}
              countries={map.countries}
              owners={owners}
              players={players}
              customNames={customNames}
              onPick={pickTarget}
            />
            {!panelOpen && (
              <button className="panel-open-button" onClick={() => setPanelOpen(true)}>
                {t('panel.open')} ›
              </button>
            )}
          </MapView>

          <aside className="panel">
            {selectedOwn ? (
              <SettlementPanel
                key={selectedOwn.id}
                worldId={world.id}
                settlement={selectedOwn}
                defaultName={hexName(map.hexes[selectedOwn.idx], map.countries)}
                countryName={countryName(selectedOwn.countryCode, map.countries)}
                settings={world.settings}
                clockOffset={clockOffset}
                focusBuilding={focusBuilding}
                onUpdate={updateSettlement}
                onStale={loadMine}
                onCollapse={() => setPanelOpen(false)}
              />
            ) : selected !== null ? (
              <HexPanel hex={map.hexes[selected]} countries={map.countries} owner={owners.get(selected)} players={players} />
            ) : (
              <div className="muted">{t('game.clickHex')}</div>
            )}
          </aside>
        </>
      )}
    </div>
  );
}
