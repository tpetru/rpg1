import { createRoot } from 'react-dom/client';
import { BUILDING_IDS, type BuildingId } from '@geowars/rules';
import { BuildingIcon } from './art/buildings';
import './styles.css';

// Dev-only sheet for reviewing the building illustrations at the sizes the game uses them:
// 96 (inspector), 44 (catalogue), 28 (queue and locked rows) and 21 (dense rows).
// Nothing imports this file; delete it (and preview-buildings.html) whenever you like.
const NAMES: Record<BuildingId, string> = {
  cityhall: 'City Hall',
  farm: 'Farms',
  steelmill: 'Steel Mill',
  oilfield: 'Oil Field',
  warehouse: 'Warehouse',
  housing: 'Housing',
  bunker: 'Bunker',
  commandcenter: 'Command Center',
  barracks: 'Barracks',
  researchcenter: 'Research Center',
  market: 'Market',
  fortifications: 'Fortifications',
  hospital: 'Hospital',
  factory: 'Factory',
  airbase: 'Airbase',
  port: 'Port',
  radar: 'Radar',
  parliament: 'Parliament',
};

const cell: React.CSSProperties = {
  background: 'var(--card)',
  border: '1px solid var(--border)',
  borderRadius: 10,
  padding: 12,
  textAlign: 'center',
};

function App() {
  return (
    <div style={{ padding: 24, display: 'grid', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 20 }}>Building art</h1>
        <p className="muted small" style={{ margin: '4px 0 0' }}>
          18 elevations, one system. Sizes below match the panel: 44px catalogue, 28px queue, 21px dense rows.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 14, marginBottom: 12 }}>96px</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: 12 }}>
          {BUILDING_IDS.map((id) => (
            <figure key={id} style={{ ...cell, margin: 0 }}>
              <BuildingIcon id={id} size={96} title={NAMES[id]} />
              <figcaption className="small muted" style={{ marginTop: 6 }}>
                {NAMES[id]}
              </figcaption>
            </figure>
          ))}
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 14, marginBottom: 12 }}>44 · 28 · 21px</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: 12 }}>
          {BUILDING_IDS.map((id) => (
            <div key={id} style={cell}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center' }}>
                <BuildingIcon id={id} size={44} />
                <BuildingIcon id={id} size={28} />
                <BuildingIcon id={id} size={21} />
              </div>
              <div className="small muted" style={{ marginTop: 4 }}>
                {NAMES[id]}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 14, marginBottom: 12 }}>Not built (the panel's .unbuilt filter)</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          {BUILDING_IDS.map((id) => (
            <BuildingIcon key={id} id={id} size={44} className="unbuilt" />
          ))}
        </div>
      </section>
    </div>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
