import { useEffect, useState } from 'react';
import type { MeResponse, WorldSummary } from '@geowars/rules';
import { api } from '../api';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { LanguageSwitch } from './LanguageSwitch';
import { ThemeToggle } from './ThemeToggle';

interface Props {
  account: MeResponse['account'];
  onPick: (worldId: number) => void;
  onLogout: () => void;
}

const STATUS_TEXT: Record<WorldSummary['status'], TextKey> = {
  open: 'lobby.statusOpen',
  running: 'lobby.statusRunning',
  ended: 'lobby.statusEnded',
};

export function WorldSelectScreen({ account, onPick, onLogout }: Props) {
  const { t, errorText } = useI18n();
  const [worlds, setWorlds] = useState<WorldSummary[] | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    api.worlds().then(setWorlds, setError);
  }, []);

  return (
    <div className="lobby">
      <header className="lobby-header">
        <div>
          <h1 className="logo">GeoWars</h1>
          <p className="tagline">{t('lobby.welcome', { name: account.username })}</p>
        </div>
        <div className="header-actions">
          <LanguageSwitch />
          <ThemeToggle />
          <button onClick={onLogout}>{t('auth.logout')}</button>
        </div>
      </header>

      {error != null && <div className="error">{errorText(error)}</div>}
      {worlds && worlds.length === 0 && <div className="muted">{t('lobby.noWorlds')}</div>}

      <div className="world-list">
        {worlds?.map((w) => (
          <div key={w.id} className="world-card">
            <div className="world-head">
              <h2>{w.name}</h2>
              <span className={`status ${w.status}`}>{t(w.number === 0 ? 'lobby.statusTesting' : STATUS_TEXT[w.status])}</span>
            </div>
            <div className="world-facts muted small">
              <span>{t('lobby.speed', { n: w.settings.speed })}</span>
              <span>{t('lobby.nations', { n: fmtInt(w.players) })}</span>
            </div>
            {w.you ? (
              <div className="world-you with-icon">
                <NationEmblem name={w.you.nation} size={44} />
                <span>{t('lobby.yourNation', { nation: w.you.nation, points: t('points', { n: fmtInt(w.you.points) }) })}</span>
              </div>
            ) : (
              <div className="world-you muted">{t('lobby.notFounded')}</div>
            )}
            <button className="primary" onClick={() => onPick(w.id)}>
              {w.you ? t('lobby.play') : t('lobby.join')}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
