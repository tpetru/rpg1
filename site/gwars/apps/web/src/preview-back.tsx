import { createRoot } from 'react-dom/client';
import { BuildingIcon } from './art/buildings';
import { BackButton } from './components/BackButton';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the hall pages' back pill, shown in a real hall-head so the chrome
// around it matches the app. No database needed.

function Shell() {
  return (
    <div className="game view-open">
      <main className="hall-page">
        <header className="hall-head">
          <BuildingIcon id="cityhall" size={52} />
          <div className="hall-title">
            <BackButton name="Pitanga" onBack={() => undefined} />
            <h1>City Hall: buildings</h1>
            <span className="muted small">Queue 0 of 2 · every building of the settlement</span>
          </div>
        </header>
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
