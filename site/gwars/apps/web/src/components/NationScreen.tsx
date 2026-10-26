import { useState, type FormEvent } from 'react';
import { NATION_NAME_MAX, nationNameError, type WorldInfo } from '@geowars/rules';
import { api } from '../api';

interface Props {
  world: WorldInfo;
  onJoined: () => void;
  onBack: () => void;
}

export function NationScreen({ world, onJoined, onBack }: Props) {
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const invalid = name.length > 0 ? nationNameError(name) : null;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const problem = nationNameError(name);
    if (problem) return setError(problem);
    setBusy(true);
    setError(null);
    try {
      await api.join(world.id, name);
      onJoined();
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  };

  return (
    <div className="auth">
      <div className="auth-card">
        <h1 className="logo">{world.name}</h1>
        <p className="tagline">Found your nation. You start with one settlement somewhere in the world.</p>

        <form onSubmit={submit}>
          <label>
            Nation name
            <input
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setError(null);
              }}
              maxLength={NATION_NAME_MAX}
              placeholder="e.g. Dacia"
              autoFocus
              required
            />
          </label>
          <div className={`hint small ${invalid ? 'bad' : ''}`}>{invalid ?? 'Letters and digits only, starting with a letter.'}</div>
          {error && <div className="error">{error}</div>}
          <button className="primary" disabled={busy || !!invalid || name.length === 0}>
            Found nation
          </button>
          <button type="button" onClick={onBack}>
            Back to worlds
          </button>
        </form>
      </div>
    </div>
  );
}
