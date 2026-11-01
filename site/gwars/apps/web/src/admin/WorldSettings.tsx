import { useEffect, useState, type FormEvent } from 'react';
import { SPEED_MAX, SPEED_MIN, type SpeedKey, type WorldSettings } from '@geowars/rules';
import { LanguageSwitch } from '../components/LanguageSwitch';
import { ThemeToggle } from '../components/ThemeToggle';
import { useI18n } from '../i18n';
import { adminApi } from './adminApi';

const FIELDS = [
  { key: 'constructionSpeed', label: 'admin.set.construction', hint: 'admin.set.constructionHint' },
  { key: 'recruitSpeed', label: 'admin.set.recruit', hint: 'admin.set.recruitHint' },
  { key: 'warSpeed', label: 'admin.set.war', hint: 'admin.set.warHint' },
  { key: 'speed', label: 'admin.set.speed', hint: 'admin.set.speedHint' },
] as const satisfies readonly { key: SpeedKey; label: string; hint: string }[];

/** /admin/w/<id>: the speeds of one world. Reached only after the admin login. */
export function WorldSettingsPage({ worldId }: { worldId: number }) {
  const { t, errorText } = useI18n();
  const [name, setName] = useState('');
  const [saved, setSaved] = useState<WorldSettings | null>(null);
  const [form, setForm] = useState<Record<SpeedKey, string> | null>(null);
  const [notice, setNotice] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const fill = (s: WorldSettings) => {
    setSaved(s);
    setForm({ speed: String(s.speed), constructionSpeed: String(s.constructionSpeed), recruitSpeed: String(s.recruitSpeed), warSpeed: String(s.warSpeed) });
  };

  useEffect(() => {
    adminApi.worlds().then(
      (list) => {
        const w = list.find((x) => x.id === worldId);
        if (!w) return setNotice({ kind: 'error', text: t('err.world_not_found') });
        setName(w.name);
        fill(w.settings);
      },
      (err) => setNotice({ kind: 'error', text: errorText(err) }),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps -- load once per world
  }, [worldId]);

  const parsed = form ? (Object.fromEntries(FIELDS.map((f) => [f.key, Number(form[f.key].replace(',', '.'))])) as Record<SpeedKey, number>) : null;
  const valid = parsed !== null && FIELDS.every((f) => Number.isFinite(parsed[f.key]) && parsed[f.key] >= SPEED_MIN && parsed[f.key] <= SPEED_MAX);
  const dirty = !!saved && !!parsed && FIELDS.some((f) => parsed[f.key] !== saved[f.key]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!parsed || !valid) return;
    setBusy(true);
    try {
      fill(await adminApi.saveSettings(worldId, parsed));
      setNotice({ kind: 'ok', text: t('admin.set.saved') });
    } catch (err) {
      setNotice({ kind: 'error', text: errorText(err) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="admin">
      <header className="admin-head">
        <h1 className="logo small">{t('admin.set.title', { world: name })}</h1>
        <span className="spacer" />
        <LanguageSwitch />
        <ThemeToggle />
        <a className="admin-link" href="/admin">
          {t('admin.set.back')}
        </a>
      </header>
      {notice && (
        <div className={notice.kind === 'ok' ? 'admin-ok' : 'error'} role="status">
          {notice.text}
        </div>
      )}
      {form && (
        <form className="card stack" onSubmit={submit} style={{ maxWidth: 520 }}>
          {FIELDS.map((f) => (
            <label key={f.key} className="admin-owner">
              {t(f.label)}
              <input inputMode="decimal" value={form[f.key]} onChange={(e) => setForm({ ...form, [f.key]: e.target.value })} />
              <span className="muted small">{t(f.hint)}</span>
            </label>
          ))}
          <p className="muted small">{t('admin.set.note', { min: SPEED_MIN, max: SPEED_MAX })}</p>
          <button className="primary" disabled={busy || !valid || !dirty}>
            {t('admin.set.save')}
          </button>
        </form>
      )}
    </div>
  );
}
