import { useEffect, useMemo, useState } from 'react';
import type { CountryInfo, MeResponse } from '@geowars/rules';
import { api } from '../api';
import { Multiplier } from './Multiplier';

export function JoinScreen({ me, onJoined, onLogout }: { me: MeResponse; onJoined: () => void; onLogout: () => void }) {
  const [countries, setCountries] = useState<CountryInfo[]>([]);
  const [query, setQuery] = useState('');
  const [continent, setContinent] = useState('All');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api.countries().then(setCountries, (err: Error) => setError(err.message));
  }, []);

  const continents = useMemo(() => ['All', ...new Set(countries.map((c) => c.continent))].sort(), [countries]);
  const visible = countries.filter(
    (c) => (continent === 'All' || c.continent === continent) && c.name.toLowerCase().includes(query.trim().toLowerCase()),
  );

  const join = async (code: string) => {
    setBusy(true);
    setError(null);
    try {
      await api.join(code);
      onJoined();
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  };

  const joinRandom = () => {
    const open = countries.filter((c) => c.free > 0);
    if (open.length) void join(open[Math.floor(Math.random() * open.length)].code);
  };

  return (
    <div className="join">
      <header className="join-header">
        <div>
          <h1 className="logo">GeoWars</h1>
          <p className="tagline">
            {me.world.name}: choose where your nation begins, {me.account.username}.
          </p>
        </div>
        <button onClick={onLogout}>Log out</button>
      </header>

      <div className="join-tools">
        <input placeholder="Search country…" value={query} onChange={(e) => setQuery(e.target.value)} />
        <select value={continent} onChange={(e) => setContinent(e.target.value)}>
          {continents.map((c) => (
            <option key={c}>{c}</option>
          ))}
        </select>
        <button className="primary" onClick={joinRandom} disabled={busy || countries.length === 0}>
          Random country
        </button>
      </div>
      {error && <div className="error">{error}</div>}

      <div className="country-grid">
        {visible.map((c) => (
          <button key={c.code} className="country-card" disabled={busy || c.free === 0} onClick={() => join(c.code)}>
            <div className="country-name">{c.name}</div>
            <div className="muted small">
              {c.continent} · {c.free}/{c.hexes} hexes free
            </div>
            <div className="country-res">
              <Multiplier label="Food" value={c.food} kind="food" />
              <Multiplier label="Steel" value={c.steel} kind="steel" />
              <Multiplier label="Oil" value={c.oil} kind="oil" />
            </div>
            <div className="badges">
              {c.rareShare > 0 && <span className="badge rare">Rare earths {Math.round(c.rareShare * 100)}%</span>}
              {c.uraniumShare > 0 && <span className="badge uranium">Uranium {Math.round(c.uraniumShare * 100)}%</span>}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
