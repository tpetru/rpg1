import { useState, type FormEvent } from 'react';
import { NATION_NAME_MAX, NATION_NAME_MIN, nationNameIssue, type WorldInfo } from '@geowars/rules';
import { api } from '../api';
import { NationEmblem, NationFlag } from '../art/nation';
import { useI18n } from '../i18n';
import { LanguageSwitch } from './LanguageSwitch';
import { ThemeToggle } from './ThemeToggle';

interface Props {
  world: WorldInfo;
  onJoined: () => void;
  onBack: () => void;
}

export function NationScreen({ world, onJoined, onBack }: Props) {
  const { t, codeText, errorText } = useI18n();
  const [name, setName] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const issue = name.length > 0 ? nationNameIssue(name) : null;
  const issueText = issue && codeText(issue, { min: NATION_NAME_MIN, max: NATION_NAME_MAX });

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (nationNameIssue(name)) return;
    setBusy(true);
    setError(null);
    try {
      await api.join(world.id, name);
      onJoined();
    } catch (err) {
      setError(err);
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
        <h1 className="logo">{world.name}</h1>
        <p className="tagline">{t('nation.tagline')}</p>

        <div className="nation-preview" aria-hidden={issue ? true : undefined}>
          {name.length > 0 && !issue ? (
            <>
              <NationEmblem name={name} size={96} />
              <NationFlag name={name} width={132} />
            </>
          ) : (
            <span className="muted small">{t('nation.previewHint')}</span>
          )}
        </div>

        <form onSubmit={submit}>
          <label>
            {t('nation.label')}
            <input
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setError(null);
              }}
              maxLength={NATION_NAME_MAX}
              placeholder={t('nation.placeholder')}
              autoFocus
              required
            />
          </label>
          <div className={`hint small ${issue ? 'bad' : ''}`}>{issueText ?? t('nation.hint')}</div>
          {error != null && <div className="error">{errorText(error)}</div>}
          <button className="primary" disabled={busy || !!issue || name.length === 0}>
            {t('nation.found')}
          </button>
          <button type="button" onClick={onBack}>
            {t('nation.back')}
          </button>
        </form>
      </div>
    </div>
  );
}
