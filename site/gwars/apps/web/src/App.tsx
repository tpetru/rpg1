import { useCallback, useEffect, useState } from 'react';
import type { MeResponse } from '@geowars/rules';
import { ApiError, api } from './api';
import { AuthScreen } from './components/AuthScreen';
import { GameScreen } from './components/GameScreen';
import { JoinScreen } from './components/JoinScreen';

type Session = { kind: 'loading' } | { kind: 'guest' } | { kind: 'error'; message: string } | { kind: 'user'; me: MeResponse; clockOffset: number };

export function App() {
  const [session, setSession] = useState<Session>({ kind: 'loading' });

  const refresh = useCallback(async () => {
    try {
      const me = await api.me();
      setSession({ kind: 'user', me, clockOffset: me.serverTime - Date.now() });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) setSession({ kind: 'guest' });
      else setSession({ kind: 'error', message: (err as Error).message });
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const logout = async () => {
    await api.logout();
    setSession({ kind: 'guest' });
  };

  switch (session.kind) {
    case 'loading':
      return <div className="splash">Loading…</div>;
    case 'error':
      return <div className="splash">Server unavailable: {session.message}</div>;
    case 'guest':
      return <AuthScreen onAuthenticated={refresh} />;
    case 'user':
      return session.me.player ? (
        <GameScreen me={session.me} clockOffset={session.clockOffset} onLogout={logout} />
      ) : (
        <JoinScreen me={session.me} onJoined={refresh} onLogout={logout} />
      );
  }
}
