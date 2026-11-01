import { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { NationEmblem } from './art/nation';
import { I18nProvider } from './i18n';
import { SettlementPicker, type PickerItem } from './components/SettlementPicker';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the settlement picker with mock data, so the ledger can be reviewed
// without a database. Mirrors the real top bar order from GameScreen.

const ITEMS: PickerItem[] = [
  { idx: 12, label: 'East Brașov', sub: 'România', points: 480 },
  { idx: 13, label: 'Ghimbav', sub: 'România', points: 310 },
  { idx: 14, label: 'Săcele', sub: 'România', points: 120 },
  { idx: 15, label: 'Ploiești', sub: 'România', points: 950 },
  { idx: 16, label: 'Craiova', sub: 'România', points: 640 },
  { idx: 21, label: 'Debrecen', sub: 'Ungaria', points: 520 },
  { idx: 22, label: 'Szeged', sub: 'Ungaria', points: 210 },
  { idx: 23, label: 'Miskolc', sub: 'Ungaria', points: 340 },
  { idx: 31, label: 'Varna', sub: 'Bulgaria', points: 415 },
  { idx: 32, label: 'Burgas', sub: 'Bulgaria', points: 180 },
  { idx: 41, label: 'Niš', sub: 'Serbia', points: 260 },
  { idx: 42, label: 'Subotica', sub: 'Serbia', points: 95 },
  { idx: 51, label: 'Lviv', sub: 'Ucraina', points: 720 },
  { idx: 52, label: 'Chișinău', sub: 'Moldova', points: 150 },
];

function Shell() {
  const [selected, setSelected] = useState<number | null>(12);
  const current = ITEMS.find((i) => i.idx === selected);
  return (
    <div className="game view-open">
      <header className="topbar">
        <span className="wordmark">GeoWars</span>
        <SettlementPicker items={ITEMS} selected={selected} onPick={setSelected} />
        <div className="view-switch" role="group">
          <button className="active">Hartă</button>
          <button>Privire generală</button>
          <button>Așezare</button>
        </div>
        <span className="spacer-grow" />
        <div className="account">
          <NationEmblem name="Dacia" size={34} />
          <div className="account-text">
            <strong>Dacia</strong>
            <span>tanas</span>
          </div>
          <span className="points mono">4.585 points</span>
        </div>
      </header>
      <main className="preview-stage">
        <p className="muted">
          Selected: <strong>{current ? `${current.label} — ${current.sub}` : 'nothing'}</strong> · try searching{' '}
          <code>chisinau</code> (no diacritics), arrow keys, Home/End, Esc.
        </p>
      </main>
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
