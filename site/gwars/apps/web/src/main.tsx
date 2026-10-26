import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import 'maplibre-gl/dist/maplibre-gl.css';
import './styles.css';
import { AdminApp } from './admin/AdminApp';
import { App } from './App';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ThemeProvider>
      <I18nProvider>
        {location.pathname.replace(/\/+$/, '') === '/admin' ? <AdminApp /> : <App />}
      </I18nProvider>
    </ThemeProvider>
  </StrictMode>,
);
