import { useCallback, useEffect, useState } from 'react';
import type { MeResponse, WorldMeResponse } from '@geowars/rules';
import { ApiError, api } from './api';
import { AuthScreen } from './components/AuthScreen';
import { GameScreen } from './components/GameScreen';
import { NationScreen } from './components/NationScreen';
import { WorldSelectScreen } from './components/WorldSelectScreen';
import { prefs } from './util';

type Account = MeResponse['account'];
type Session = { kind: 'loading' } | { kind: 'guest' } | { kind: 'error'; message: string } | { kind: 'user'; account: Account };

const WORLD_KEY = 'gw.world';

export function App() {
  const [session, setSession] = useState<Session>({ kind: 'loading' });
  // The chosen world survives page reloads, but every login starts at the world list.
  const [worldId, setWorldId] = useState<number | null>(() => {
    const saved = prefs.get(WORLD_KEY);
    return saved === null ? null : Number(saved);
  });

  const pickWorld = useCallback((id: number | null) => {
    prefs.set(WORLD_KEY, id === null ? null : String(id));
    setWorldId(id);
  }, []);

  const leaveWorld = useCallback(() => pickWorld(null), [pickWorld]);

  const loadAccount = useCallback(async () => {
    try {
      const me = await api.me();
      setSession({ kind: 'user', account: me.account });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) setSession({ kind: 'guest' });
      else setSession({ kind: 'error', message: (err as Error).message });
    }
  }, []);

  useEffect(() => {
    void loadAccount();
  }, [loadAccount]);

  const onAuthenticated = () => {
    pickWorld(null);
    void loadAccount();
  };

  const logout = async () => {
    await api.logout();
    pickWorld(null);
    setSession({ kind: 'guest' });
  };

  switch (session.kind) {
    case 'loading':
      return <div className="splash">Loading…</div>;
    case 'error':
      return <div className="splash">Server unavailable: {session.message}</div>;
    case 'guest':
      return <AuthScreen onAuthenticated={onAuthenticated} />;
    case 'user':
      return worldId === null ? (
        <WorldSelectScreen account={session.account} onPick={pickWorld} onLogout={logout} />
      ) : (
        <WorldEntry key={worldId} worldId={worldId} account={session.account} onLeave={leaveWorld} onLogout={logout} />
      );
  }
}

interface WorldEntryProps {
  worldId: number;
  account: Account;
  onLeave: () => void;
  onLogout: () => void;
}

/** Loads the player's state in one world, then shows nation creation or the game. */
function WorldEntry({ worldId, account, onLeave, onLogout }: WorldEntryProps) {
  const [state, setState] = useState<{ me: WorldMeResponse; clockOffset: number } | { error: string } | null>(null);

  const load = useCallback(async () => {
    try {
      const me = await api.worldMe(worldId);
      setState({ me, clockOffset: me.serverTime - Date.now() });
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) onLeave();
      else setState({ error: (err as Error).message });
    }
  }, [worldId, onLeave]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!state) return <div className="splash">Entering world…</div>;
  if ('error' in state) return <div className="splash">Could not open this world: {state.error}</div>;

  const { me, clockOffset } = state;
  return me.player ? (
    <GameScreen world={me.world} player={me.player} account={account} clockOffset={clockOffset} onLeave={onLeave} onLogout={onLogout} />
  ) : (
    <NationScreen world={me.world} onJoined={load} onBack={onLeave} />
  );
}
