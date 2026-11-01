import { createRoot } from 'react-dom/client';
import { latLngToCell } from 'h3-js';
import { STARTING_LEVELS, type BuildingId, type CommandDto, type CountryRef, type HexRow, type OwnSettlementDto, type UnitCounts, type UnitId } from '@geowars/rules';
import { NationEmblem } from './art/nation';
import { CountryView } from './components/CountryView';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the order-of-battle country view with mock data, so the muster, the
// garrison cards and the field/training rolls can be reviewed without a database.
const RES = 3;

const levels = (over: Partial<Record<string, number>>) => ({ ...STARTING_LEVELS, ...over });

const u = (p: Partial<UnitCounts>): UnitCounts => ({ rifleman: 0, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0, ...p });

const mk = (
  i: number,
  name: string,
  country: string,
  lat: number,
  lng: number,
  lv: Record<string, number>,
  queue = 0,
  units: UnitCounts = u({}),
  training: OwnSettlementDto['training'] = [],
): OwnSettlementDto => ({
  id: 100 + i,
  idx: i,
  h3: latLngToCell(lat, lng, RES),
  name,
  customName: i === 0 ? null : name,
  countryCode: country,
  points: 320 + i * 145,
  loyalty: 90 + i,
  units,
  researched: [],
  researching: null,
  training,
  troopPop: 0,
  levels: lv as OwnSettlementDto['levels'],
  stock: { food: 4200, steel: 3100, oil: 1900 },
  resourcesAt: Date.now(),
  profile: { food: 1.4, steel: 1.1, oil: 2.1, rare: 0, uranium: 0 },
  coastal: true,
  queue: Array.from({ length: queue }, (_, q) => ({
    id: 900 + i * 10 + q,
    building: (q === 0 ? 'farm' : 'warehouse') as BuildingId,
    targetLevel: 6 + q,
    startsAt: Date.now() - 60_000,
    finishesAt: Date.now() + 240_000,
  })),
});

const train = (id: number, unit: UnitId, count: number, minutes: number) => ({
  id,
  unit,
  count,
  total: count * 2,
  startsAt: Date.now() - 60_000,
  finishesAt: Date.now() + minutes * 60_000,
});

const settlements: OwnSettlementDto[] = [
  mk(0, 'East Brașov', 'RO', 45.65, 25.6, levels({ cityhall: 4, farm: 6, steelmill: 5, oilfield: 4, warehouse: 2, housing: 5, barracks: 3, researchcenter: 1, fortifications: 2 }), 2, u({ rifleman: 500, assault: 220, veteran: 40, tank: 24, spy: 2, president: 1 }), [train(11, 'assault', 60, 12)]),
  mk(1, 'Ghimbav', 'RO', 45.72, 25.51, levels({ cityhall: 3, farm: 4, steelmill: 3, oilfield: 2, warehouse: 1, housing: 3, barracks: 1 }), 0, u({ rifleman: 120, guardian: 30, drone: 6 }), [train(12, 'guardian', 18, 40)]),
  mk(2, 'Săcele', 'RO', 45.58, 25.71, levels({ cityhall: 2, farm: 3, steelmill: 2, oilfield: 1, warehouse: 1, housing: 2 })),
  mk(3, 'Râșnov', 'RO', 45.51, 25.44, levels({ cityhall: 2, farm: 2, steelmill: 1, oilfield: 1, warehouse: 1, housing: 2 }), 0, u({ bomber: 12 })),
  mk(4, 'Ruse', 'BG', 43.85, 25.95, levels({ cityhall: 1, farm: 1, steelmill: 1, oilfield: 1, warehouse: 1, housing: 1 }), 1, u({ rifleman: 45 })),
  mk(5, 'Giza', 'EG', 29.98, 31.24, levels({ cityhall: 2, farm: 2, housing: 2, barracks: 1 }), 0, u({ rifleman: 200, guardian: 15, tank: 5 })),
];

const mkCommand = (id: number, type: 'attack' | 'return', originId: number, targetIdx: number, units: UnitCounts, minutes: number): CommandDto => ({
  id,
  type,
  originId,
  originIdx: settlements.find((s) => s.id === originId)!.idx,
  targetId: 999,
  targetIdx,
  units,
  sentAt: Date.now() - 20 * 60_000,
  arrivesAt: Date.now() + minutes * 60_000,
});

const commands: CommandDto[] = [
  mkCommand(1, 'attack', 100, 4, u({ rifleman: 300, tank: 12 }), 34),
  mkCommand(2, 'return', 101, 0, u({ rifleman: 80 }), 9),
];

const hexes: HexRow[] = settlements.map((s) => [s.h3, s.countryCode, s.name, 1.4, 1.1, 2.1, 0, 0, null]);

const countries: Record<string, CountryRef> = {
  RO: { name: 'Romania', a2: 'RO', continent: 'Europe' },
  BG: { name: 'Bulgaria', a2: 'BG', continent: 'Europe' },
  EG: { name: 'Egypt', a2: 'EG', continent: 'Africa' },
};

const settings = { speed: 1, constructionSpeed: 1, recruitSpeed: 1, warSpeed: 1, buildQueueSlots: 3, startingResources: { food: 500, steel: 500, oil: 500 }, cancelRefund: 0.5 };

function Shell() {
  const points = settlements.reduce((sum, s) => sum + s.points, 0);
  return (
    <div className="game view-open">
      <header className="topbar">
        <span className="wordmark">GeoWars</span>
        <button className="world-button">World 0</button>
        <span className="topbar-sep" />
        <div className="view-switch">
          <button>Hartă</button>
          <button className="active">Țară</button>
        </div>
        <nav className="settlement-tabs">
          <button className="active">East Brașov</button>
          <button>Ghimbav</button>
          <button>Săcele</button>
        </nav>
        <span className="spacer" />
        <div className="account">
          <NationEmblem name="Dacia" size={34} />
          <div className="account-text">
            <strong>Dacia</strong>
            <span>tanas</span>
          </div>
          <span className="points mono">{points} points</span>
        </div>
      </header>
      <CountryView
        nation="Dacia"
        settlements={settlements}
        commands={commands}
        hexes={hexes}
        countries={countries}
        settings={settings}
        clockOffset={0}
        onOpen={() => undefined}
      />
    </div>
  );
}

try {
  if (!localStorage.getItem('gw.theme')) localStorage.setItem('gw.theme', 'light');
} catch {
  // storage unavailable
}

createRoot(document.getElementById('root')!).render(
  <ThemeProvider>
    <I18nProvider>
      <Shell />
    </I18nProvider>
  </ThemeProvider>,
);
