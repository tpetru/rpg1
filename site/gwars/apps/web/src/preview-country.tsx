import { createRoot } from 'react-dom/client';
import { latLngToCell } from 'h3-js';
import { STARTING_LEVELS, type BuildingId, type HexRow, type OwnSettlementDto } from '@geowars/rules';
import { NationEmblem } from './art/nation';
import { CountryView } from './components/CountryView';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the country view with mock data, so it can be reviewed without a database.
const RES = 3;

const levels = (over: Partial<Record<string, number>>) => ({ ...STARTING_LEVELS, ...over });

const mk = (
  i: number,
  name: string,
  country: string,
  lat: number,
  lng: number,
  lv: Record<string, number>,
  queue = 0,
): OwnSettlementDto => ({
  id: 100 + i,
  idx: i,
  h3: latLngToCell(lat, lng, RES),
  name,
  customName: i === 0 ? null : name,
  countryCode: country,
  points: 320 + i * 145,
  loyalty: 90 + i,
  levels: lv as OwnSettlementDto['levels'],
  stock: { food: 4200, steel: 3100, oil: 1900 },
  resourcesAt: Date.now(),
  profile: { food: 1.4, steel: 1.1, oil: 2.1, rare: 0, uranium: 0 },
  queue: Array.from({ length: queue }, (_, q) => ({
    id: 900 + i * 10 + q,
    building: (q === 0 ? 'farm' : 'warehouse') as BuildingId,
    targetLevel: 6 + q,
    startsAt: Date.now() - 60_000,
    finishesAt: Date.now() + 240_000,
  })),
});

const settlements: OwnSettlementDto[] = [
  mk(0, 'East Brașov', 'RO', 45.65, 25.6, levels({ cityhall: 4, farm: 6, steelmill: 5, oilfield: 4, warehouse: 2, housing: 5, barracks: 3, researchcenter: 1, fortifications: 2 }), 2),
  mk(1, 'Ghimbav', 'RO', 45.72, 25.51, levels({ cityhall: 3, farm: 4, steelmill: 3, oilfield: 2, warehouse: 1, housing: 3, barracks: 1 })),
  mk(2, 'Săcele', 'RO', 45.58, 25.71, levels({ cityhall: 2, farm: 3, steelmill: 2, oilfield: 1, warehouse: 1, housing: 2, commandcenter: 1 })),
  mk(3, 'Râșnov', 'RO', 45.51, 25.44, levels({ cityhall: 2, farm: 2, steelmill: 1, oilfield: 1, warehouse: 1, housing: 2 })),
  mk(4, 'Ruse', 'BG', 43.85, 25.95, levels({ cityhall: 1, farm: 1, steelmill: 1, oilfield: 1, warehouse: 1, housing: 1 }), 1),
];

const hexes: HexRow[] = settlements.map((s) => [s.h3, s.countryCode, s.name, 1.4, 1.1, 2.1, 0, 0, null]);

const countries = {
  RO: { name: 'Romania', a2: 'RO' },
  BG: { name: 'Bulgaria', a2: 'BG' },
};

const settings = { speed: 1, buildQueueSlots: 3, startingResources: { food: 500, steel: 500, oil: 500 }, cancelRefund: 0.5 };

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
        hexes={hexes}
        countries={countries}
        settings={settings}
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
