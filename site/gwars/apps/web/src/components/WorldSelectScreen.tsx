import { useEffect, useState } from 'react';
import type { MeResponse, WorldSummary } from '@geowars/rules';
import { api } from '../api';
import { fmtInt } from '../util';

interface Props {
  account: MeResponse['account'];
  onPick: (worldId: number) => void;
  onLogout: () => void;
}

export function WorldSelectScreen({ account, onPick, onLogout }: Props) {
  const [worlds, setWorlds] = useState<WorldSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.worlds().then(setWorlds, (err: Error) => setError(err.message));
  }, []);

  return (
    <div className="lobby">
      <header className="lobby-header">
        <div>
          <h1 className="logo">GeoWars</h1>
          <p className="tagline">Welcome, {account.username}. Choose a world to play.</p>
        </div>
        <button onClick={onLogout}>Log out</button>
      </header>

      {error && <div className="error">{error}</div>}
      {worlds && worlds.length === 0 && <div className="muted">No worlds are open right now.</div>}

      <div className="world-list">
        {worlds?.map((w) => (
          <div key={w.id} className="world-card">
            <div className="world-head">
              <h2>{w.name}</h2>
              <span className={`status ${w.status}`}>{w.number === 0 ? 'Testing' : w.status}</span>
            </div>
            <div className="world-facts muted small">
              <span>Speed ×{w.settings.speed}</span>
              <span>{fmtInt(w.players)} {w.players === 1 ? 'nation' : 'nations'}</span>
            </div>
            {w.you ? (
              <div className="world-you">
                Your nation: <strong>{w.you.nation}</strong> · {fmtInt(w.you.points)} points
              </div>
            ) : (
              <div className="world-you muted">You have not founded a nation here yet.</div>
            )}
            <button className="primary" onClick={() => onPick(w.id)}>
              {w.you ? 'Play' : 'Join'}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
