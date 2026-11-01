import { useCallback, useEffect, useMemo, useState } from 'react';
import type { BuildingId, CommandDto, IncomingCommandDto, MapHexesResponse, MeResponse, OwnSettlementDto, PlayerInfo, ReportDto, ServerMessage, WorldInfo } from '@geowars/rules';
import { api } from '../api';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import { prefs, useServerEvents } from '../util';
import { CityView } from './CityView';
import { HallView } from './HallView';
import { CapacityView } from './CapacityView';
import { FortView } from './FortView';
import { CommandView } from './CommandView';
import { RadarView } from './RadarView';
import { ResearchView } from './ResearchView';
import { TrainView } from './TrainView';
import { CountryView } from './CountryView';
import { AxeIcon, BinocularsIcon } from '../art/actionIcons';
import { AttackPanel } from './AttackPanel';
import { HexPanel } from './HexPanel';
import { LanguageSwitch } from './LanguageSwitch';
import { ThemeToggle } from './ThemeToggle';
import { MapControls, type SearchTarget } from './MapControls';
import { MapView, type HexOwner, type MapMode } from './MapView';
import { RankingView } from './RankingView';
import { ReportsView } from './ReportsView';
import { SettlementPicker } from './SettlementPicker';
import { SettlementPanel } from './SettlementPanel';

const MAP_MODES: MapMode[] = ['owners', 'countries', 'food', 'steel', 'oil', 'rare', 'uranium'];

/** Ways to look at the world: the hex map, the nation at once, one settlement as a plan, or armies and reports. */
type View = 'map' | 'country' | 'city' | 'hall' | 'train' | 'research' | 'fort' | 'warehouse' | 'housing' | 'farm' | 'steelmill' | 'oilfield' | 'radar' | 'commandcenter' | 'reports' | 'ranking';

/** The views that belong to the Settlement tab: the plan and the page of each building. */
const CITY_VIEWS: View[] = ['city', 'hall', 'train', 'research', 'fort', 'warehouse', 'housing', 'farm', 'steelmill', 'oilfield', 'radar', 'commandcenter'];

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
  const [commands, setCommands] = useState<CommandDto[]>([]);
  const [incoming, setIncoming] = useState<IncomingCommandDto[]>([]);
  const [reports, setReports] = useState<ReportDto[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  /** The abandoned settlement the attack dialog is open for. */
  const [attackTarget, setAttackTarget] = useState<{ id: number; idx: number; originId: number } | null>(null);
  const [focus, setFocus] = useState<{ idx: number; seq: number } | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [panelOpen, setPanelOpen] = useState(true);
  const [trainAt, setTrainAtState] = useState<BuildingId>(() => {
    const saved = prefs.get('gw.trainAt');
    return saved === 'factory' || saved === 'airbase' || saved === 'bunker' ? saved : 'barracks';
  });
  const setTrainAt = useCallback((next: BuildingId) => {
    prefs.set('gw.trainAt', next);
    setTrainAtState(next);
  }, []);
  /** Set when a parcel on the city plan is picked: the hub opens on that building. */
  const [focusBuilding, setFocusBuilding] = useState<{ id: BuildingId; seq: number } | null>(null);
  const [view, setViewState] = useState<View>(() => {
    const saved = prefs.get('gw.view');
    return saved === 'country' || saved === 'reports' || saved === 'ranking' || CITY_VIEWS.includes(saved as View) ? (saved as View) : 'map';
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

  const loadMilitary = useCallback(async () => {
    try {
      const [cmds, inc, reps] = await Promise.all([api.commands(world.id), api.incomingCommands(world.id), api.reports(world.id)]);
      setCommands(cmds);
      setIncoming(inc);
      setReports(reps);
    } catch {
      // the next message or reload tries again
    }
  }, [world.id]);

  useEffect(() => {
    void loadMilitary();
  }, [loadMilitary]);

  const markRead = useCallback(
    (id: number) => {
      setReports((prev) => prev.map((r) => (r.id === id ? { ...r, read: true } : r)));
      void api.readReport(world.id, id);
    },
    [world.id],
  );
  const markAllRead = useCallback(() => {
    setReports((prev) => prev.map((r) => ({ ...r, read: true })));
    void api.readAllReports(world.id);
  }, [world.id]);

  useEffect(() => {
    Promise.all([api.hexes(world.id), api.mapSettlements(world.id), api.mySettlements(world.id)]).then(
      ([hexes, settlements, own]) => {
        setMap(hexes);
        setOwners(new Map(settlements.settlements.map(([idx, id, ownerId, points]) => [idx, { settlementId: id, ownerId, points }])));
        setPlayers(settlements.players);
        setMine(own);
        // A refresh keeps the hex that was selected, as long as it is still on the map.
        const saved = Number(prefs.get(`gw.selected.${world.id}`));
        const restored = prefs.get(`gw.selected.${world.id}`) !== null && Number.isInteger(saved) && saved >= 0 && saved < hexes.hexes.length ? saved : null;
        const start = restored ?? own[0]?.idx ?? null;
        if (start !== null) {
          setSelected(start);
          setFocus({ idx: start, seq: Date.now() });
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
        if (msg.t === 'command' || msg.t === 'report') void loadMilitary();
        if (msg.t === 'map') {
          const [idx, id, ownerId, points] = msg.row;
          setOwners((prev) => new Map(prev).set(idx, { settlementId: id, ownerId, points }));
          if (msg.ownerName) setPlayers((prev) => ({ ...prev, [ownerId]: msg.ownerName! }));
        }
      },
      [loadMine, loadMilitary],
    ),
  );

  const updateSettlement = useCallback((s: OwnSettlementDto) => {
    setMine((prev) => prev.map((x) => (x.id === s.id ? s : x)));
  }, []);

  const customNames = useMemo(() => mine.flatMap((s) => (s.customName ? [{ idx: s.idx, name: s.customName }] : [])), [mine]);
  const totalPoints = useMemo(() => mine.reduce((sum, s) => sum + s.points, 0), [mine]);
  useEffect(() => {
    if (selected !== null) prefs.set(`gw.selected.${world.id}`, String(selected));
  }, [selected, world.id]);

  const selectedOwn = mine.find((s) => s.idx === selected);
  const unreadReports = reports.filter((r) => !r.read).length;

  if (error != null && !map) return <div className="splash">{t('app.worldLoadError', { message: errorText(error) })}</div>;
  if (!map) return <div className="splash">{t('app.loadingWorld')}</div>;

  const hasPanel = view === 'map' || view === 'reports' || (view === 'city' && !!selectedOwn);

  /** The side panel, on the map, the settlement page and the reports; a chevron at its top closes it. */
  const renderPanel = () => (
    <aside className="panel">
      <div className="panel-top">
        <button className="panel-toggle" onClick={() => setPanelOpen(false)} aria-label={t('panel.collapse')} title={t('panel.collapse')}>
          ›
        </button>
      </div>
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
            />
          ) : selected !== null ? (
            <HexPanel
              hex={map.hexes[selected]}
              hexes={map.hexes}
              countries={map.countries}
              owner={owners.get(selected)}
              players={players}
              worldId={world.id}
              mine={mine}
              onSent={() => {
                void loadMine();
                void loadMilitary();
              }}
            />
          ) : (
            <div className="muted">{t('game.clickHex')}</div>
          )}
    </aside>
  );

  return (
    <div className={`game ${panelOpen ? '' : 'panel-closed'} ${view === 'map' ? '' : 'view-open'} ${hasPanel && view !== 'map' ? 'with-panel' : ''}`}>
      <header className="topbar">
        <span className="wordmark">GeoWars</span>
        <SettlementPicker
          items={mine.map((s) => ({
            idx: s.idx,
            label: s.customName ?? hexName(map.hexes[s.idx], map.countries),
            sub: countryName(s.countryCode, map.countries),
            points: s.points,
          }))}
          selected={selected}
          onPick={(idx) => {
            setSelected(idx);
            setFocus({ idx, seq: Date.now() });
            // In the city view, the dropdown switches the town being looked at rather than leaving it.
            setView(CITY_VIEWS.includes(view) ? view : 'map');
          }}
        />
        <div className="view-switch" role="group" aria-label={t('view.map')}>
          <button className={view === 'map' ? 'active' : ''} aria-pressed={view === 'map'} onClick={() => setView('map')}>
            {t('view.map')}
          </button>
          <button className={view === 'country' ? 'active' : ''} aria-pressed={view === 'country'} onClick={() => setView('country')}>
            {t('view.overview')}
          </button>
          <button className={CITY_VIEWS.includes(view) ? 'active' : ''} aria-pressed={CITY_VIEWS.includes(view)} onClick={() => setView('city')}>
            {t('view.city')}
          </button>
          <button className={view === 'reports' ? 'active' : ''} aria-pressed={view === 'reports'} onClick={() => setView('reports')}>
            {t('view.reports')}
            {unreadReports > 0 && <span className="badge-count">{unreadReports}</span>}
          </button>
          <button className={view === 'ranking' ? 'active' : ''} aria-pressed={view === 'ranking'} onClick={() => setView('ranking')}>
            {t('view.ranking')}
          </button>
        </div>
        <span className="spacer-grow" />
        <div className="account">
          <NationEmblem name={player.nation} size={34} title={player.nation} />
          <div className="account-text">
            <strong>{player.nation}</strong>
            <span>{account.username}</span>
          </div>
          <span className="points mono">{t('points', { n: fmtInt(totalPoints) })}</span>
        </div>
        <span className="topbar-sep" />
        <button className="link" onClick={onLogout}>
          {t('auth.logout')}
        </button>
      </header>

      {view === 'country' ? (
        <CountryView
          nation={player.nation}
          settlements={mine}
          commands={commands}
          hexes={map.hexes}
          countries={map.countries}
          settings={world.settings}
          clockOffset={clockOffset}
          onOpen={(s) => {
            setSelected(s.idx);
            setFocus({ idx: s.idx, seq: Date.now() });
            setView('map');
          }}
        />
      ) : view === 'ranking' ? (
        <RankingView worldId={world.id} accountId={account.id} />
      ) : view === 'reports' ? (
        <>
          <ReportsView
            nation={player.nation}
            mine={mine}
            reports={reports}
            hexes={map.hexes}
            countries={map.countries}
            onMarkRead={markRead}
            onMarkAllRead={markAllRead}
            onShow={(idx) => {
              setSelected(idx);
              setFocus({ idx, seq: Date.now() });
              setView('map');
            }}
          />
          {renderPanel()}
        </>
      ) : view === 'hall' ? (
        selectedOwn ? (
          <HallView
            worldId={world.id}
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'warehouse' || view === 'housing' || view === 'farm' || view === 'steelmill' || view === 'oilfield' ? (
        selectedOwn ? (
          <CapacityView
            building={view}
            worldId={world.id}
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'commandcenter' ? (
        selectedOwn ? (
          <CommandView
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            outgoing={commands}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'radar' ? (
        selectedOwn ? (
          <RadarView
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            outgoing={commands}
            incoming={incoming}
            hexes={map.hexes}
            countries={map.countries}
            clockOffset={clockOffset}
            onShow={(idx) => {
              setSelected(idx);
              setFocus({ idx, seq: Date.now() });
              setView('map');
            }}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'fort' ? (
        selectedOwn ? (
          <FortView
            worldId={world.id}
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'research' ? (
        selectedOwn ? (
          <ResearchView
            worldId={world.id}
            settlement={selectedOwn}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'train' ? (
        selectedOwn ? (
          <TrainView
            worldId={world.id}
            settlement={selectedOwn}
            building={trainAt}
            name={selectedOwn.customName ?? hexName(map.hexes[selectedOwn.idx], map.countries)}
            settings={world.settings}
            clockOffset={clockOffset}
            onUpdate={updateSettlement}
            onBack={() => setView('city')}
          />
        ) : (
          <div className="city">
            <p className="city-empty">{t('city.empty')}</p>
          </div>
        )
      ) : view === 'city' ? (
        selectedOwn ? (
          <>
          <CityView
            settlement={selectedOwn}
            defaultName={hexName(map.hexes[selectedOwn.idx], map.countries)}
            countryName={countryName(selectedOwn.countryCode, map.countries)}
            nation={player.nation}
            clockOffset={clockOffset}
            onOpenBuilding={(id) => {
              setFocusBuilding({ id, seq: Date.now() });
              setSelected(selectedOwn.idx);
              // A building that is not built yet has no page to enter; the side panel offers to build it.
              if (selectedOwn.levels[id] < 1) return;
              if (id === 'cityhall') setView('hall');
              if (id === 'barracks' || id === 'factory' || id === 'airbase' || id === 'bunker') {
                setTrainAt(id);
                setView('train');
              }
              if (id === 'researchcenter') setView('research');
              if (id === 'fortifications') setView('fort');
              if (id === 'radar') setView('radar');
              if (id === 'commandcenter') setView('commandcenter');
              if (id === 'warehouse' || id === 'housing' || id === 'farm' || id === 'steelmill' || id === 'oilfield') setView(id);
            }}
          />
          {renderPanel()}
          </>
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
            onSelect={(idx) => {
              // Clicking the map never moves me off my current settlement; only Visit does (from the menu).
              if (selectedOwn) return;
              setSelected(idx);
            }}
            actions={(idx) => {
              const owner = owners.get(idx);
              if (!owner) return [];
              const isMine = mine.some((m) => m.idx === idx);
              const visit = {
                id: 'visit',
                label: t('map.actionVisit'),
                icon: <BinocularsIcon />,
                tone: 'neutral' as const,
                onClick: () => {
                  setSelected(idx);
                  if (isMine) setView('city');
                },
              };
              const here = selectedOwn?.idx === idx;
              const canAttack = !!selectedOwn && !here;
              const attack = {
                id: 'attack',
                label: t('map.actionAttack'),
                icon: <AxeIcon />,
                tone: 'danger' as const,
                disabled: !canAttack,
                onClick: () => selectedOwn && setAttackTarget({ id: owner.settlementId, idx, originId: selectedOwn.id }),
              };
              // Only my own settlements can be visited; any other settlement can be attacked, mine included.
              // The harmless handle sits left of the axe, like a telegraph's order lever.
              const canVisit = isMine;
              return [...(canVisit ? [visit] : []), ...(here ? [] : [attack])];
            }}
            commands={commands}
            incoming={incoming}
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
          </MapView>

          {renderPanel()}
        </>
      )}
      {attackTarget && (
        <div className="modal-backdrop" onMouseDown={() => setAttackTarget(null)}>
          <div className="modal attack-dialog" role="dialog" aria-modal="true" onMouseDown={(e) => e.stopPropagation()}>
            <header className="modal-head">
              <div className="modal-title">
                <h2>{hexName(map.hexes[attackTarget.idx], map.countries)}</h2>
                <span className="faint small">{t('attack.title')}</span>
              </div>
            </header>
            <AttackPanel
              worldId={world.id}
              targetId={attackTarget.id}
              fixedOriginId={attackTarget.originId}
              abandoned={owners.get(attackTarget.idx)?.ownerId === 0}
              own={mine.some((m) => m.idx === attackTarget.idx)}
              mine={mine}
              hexes={map.hexes}
              countries={map.countries}
              onCancel={() => setAttackTarget(null)}
              onSent={() => {
                setAttackTarget(null);
                void loadMine();
                void loadMilitary();
              }}
            />
          </div>
        </div>
      )}
      {hasPanel && !panelOpen && (
        <button className="panel-open-button" onClick={() => setPanelOpen(true)} aria-label={t('panel.open')} title={t('panel.open')}>
          ‹
        </button>
      )}
      <footer className="bottombar">
        <span className="bottombar-label">{t('game.world')}</span>
        <button className="world-button" onClick={onLeave} title={t('game.switchWorld')}>
          {world.name}
        </button>
        <span className="spacer-grow" />
        <LanguageSwitch />
        <ThemeToggle />
      </footer>
    </div>
  );
}
