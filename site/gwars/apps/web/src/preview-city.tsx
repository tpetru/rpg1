import { createRoot } from 'react-dom/client';
import { latLngToCell } from 'h3-js';
import { STARTING_LEVELS, type BuildingId, type OwnSettlementDto } from '@geowars/rules';
import { NationEmblem } from './art/nation';
import { CityView } from './components/CityView';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the city view with mock data, so the plan can be reviewed without a database.

const settlement: OwnSettlementDto = {
  id: 100,
  idx: 12,
  h3: latLngToCell(45.65, 25.6, 3),
  name: 'East Brașov',
  customName: 'East Brașov',
  countryCode: 'RO',
  points: 480,
  loyalty: 92,
  levels: {
    ...STARTING_LEVELS,
    cityhall: 4,
    farm: 6,
    steelmill: 5,
    oilfield: 3,
    warehouse: 2,
    housing: 5,
    market: 1,
    barracks: 2,
    fortifications: 1,
    port: 1,
    hospital: 2,
  } as OwnSettlementDto['levels'],
  stock: { food: 4200, steel: 3100, oil: 1900 },
  resourcesAt: Date.now(),
  profile: { food: 1.4, steel: 1.1, oil: 2.1, rare: 0, uranium: 0 },
  queue: [
    {
      id: 1,
      building: 'steelmill' as BuildingId,
      targetLevel: 6,
      startsAt: Date.now() - 60_000,
      finishesAt: Date.now() + 240_000,
    },
  ],
};

function Shell() {
  return (
    <div className="game view-open">
      <header className="topbar">
        <span className="wordmark">GeoWars</span>
        <button className="world-button">World 0</button>
        <span className="topbar-sep" />
        <div className="view-switch">
          <button>Hartă</button>
          <button>Privire generală</button>
          <button className="active">Așezare</button>
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
          <span className="points mono">3.050 points</span>
        </div>
      </header>
      <CityView
        settlement={settlement}
        defaultName="East Brașov"
        countryName="România"
        onOpenBuilding={() => undefined}
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
