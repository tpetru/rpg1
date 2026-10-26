import { useState, type FormEvent } from 'react';
import { api } from '../api';
import { useI18n } from '../i18n';
import { LanguageSwitch } from './LanguageSwitch';
import { ThemeToggle } from './ThemeToggle';

export function AuthScreen({ onAuthenticated }: { onAuthenticated: () => void }) {
  const { t, errorText } = useI18n();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      if (mode === 'login') await api.login(username, password);
      else await api.register(username, email, password);
      onAuthenticated();
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth">
      <div className="auth-card">
        <div className="auth-tools">
          <LanguageSwitch />
          <ThemeToggle />
        </div>
        <h1 className="logo">GeoWars</h1>
        <p className="tagline">{t('auth.tagline')}</p>

        <div className="tabs">
          <button className={mode === 'login' ? 'active' : ''} onClick={() => setMode('login')} type="button">
            {t('auth.tabLogin')}
          </button>
          <button className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')} type="button">
            {t('auth.tabRegister')}
          </button>
        </div>

        <form onSubmit={submit}>
          <label>
            {mode === 'login' ? t('auth.usernameOrEmail') : t('auth.username')}
            <input value={username} onChange={(e) => setUsername(e.target.value)} autoComplete="username" required />
          </label>
          {mode === 'register' && (
            <label>
              {t('auth.email')}
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
            </label>
          )}
          <label>
            {t('auth.password')}
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              minLength={mode === 'register' ? 8 : undefined}
              required
            />
          </label>
          {error != null && <div className="error">{errorText(error)}</div>}
          <button className="primary" disabled={busy}>
            {mode === 'login' ? t('auth.tabLogin') : t('auth.tabRegister')}
          </button>
        </form>
      </div>
    </div>
  );
}
