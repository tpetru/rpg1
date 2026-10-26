import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import {
  BUILDINGS,
  BUILDING_IDS,
  settlementPoints,
  type AdminPlayerDto,
  type AdminSettlementDto,
  type AdminWorldDto,
  type BuildingId,
} from '@geowars/rules';
import { BuildingIcon } from '../art/buildings';
import { LanguageSwitch } from '../components/LanguageSwitch';
import { ThemeToggle } from '../components/ThemeToggle';
import { fmtInt, useI18n } from '../i18n';
import { AdminMap } from './AdminMap';
import { adminApi } from './adminApi';

type Session = 'loading' | 'disabled' | 'guest' | 'admin';

/** Admin tools: give a settlement to another player, or set any building to any level. */
export function AdminApp() {
  const { t, errorText } = useI18n();
  const [session, setSession] = useState<Session>('loading');

  const refresh = useCallback(async () => {
    try {
      const me = await adminApi.me();
      setSession(!me.enabled ? 'disabled' : me.loggedIn ? 'admin' : 'guest');
    } catch {
      setSession('guest');
    }
  }, []);
  useEffect(() => {
    void refresh();
  }, [refresh]);

  if (session === 'loading') return <div className="splash">{t('app.loading')}</div>;
  if (session === 'disabled') return <div className="splash">{t('admin.disabled')}</div>;
  if (session === 'guest') return <Login onDone={refresh} errorText={errorText} />;
  return (
    <Tools
      onLogout={async () => {
        await adminApi.logout();
        setSession('guest');
      }}
    />
  );
}

function Login({ onDone, errorText }: { onDone: () => void; errorText: (e: unknown) => string }) {
  const { t } = useI18n();
  const [password, setPassword] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await adminApi.login(password);
      onDone();
    } catch (err) {
      setError(err);
      setPassword('');
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
        <h1 className="logo">{t('admin.title')}</h1>
        <form onSubmit={submit}>
          <label>
            {t('admin.password')}
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" autoFocus required />
          </label>
          {error != null && <div className="error">{errorText(error)}</div>}
          <button className="primary" disabled={busy || password.length === 0}>
            {t('admin.signIn')}
          </button>
        </form>
      </div>
    </div>
  );
}

function Tools({ onLogout }: { onLogout: () => void }) {
  const { t, errorText, buildingName } = useI18n();
  const [worlds, setWorlds] = useState<AdminWorldDto[]>([]);
  const [worldId, setWorldId] = useState<number | null>(null);
  const [players, setPlayers] = useState<AdminPlayerDto[]>([]);
  const [settlements, setSettlements] = useState<AdminSettlementDto[]>([]);
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState<number | null>(null);
  const [tab, setTab] = useState<'list' | 'map'>('list');
  const [notice, setNotice] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null);

  const fail = useCallback((err: unknown) => setNotice({ kind: 'error', text: errorText(err) }), [errorText]);

  useEffect(() => {
    adminApi.worlds().then((list) => {
      setWorlds(list);
      setWorldId((current) => current ?? list[0]?.id ?? null);
    }, fail);
  }, [fail]);

  const load = useCallback(
    async (world: number, q: string) => {
      try {
        const [list, who] = await Promise.all([adminApi.settlements(world, q), adminApi.players(world)]);
        setSettlements(list);
        setPlayers(who);
      } catch (err) {
        fail(err);
      }
    },
    [fail],
  );

  // Search as you type, without hammering the server on every key.
  useEffect(() => {
    if (worldId === null) return;
    const timer = setTimeout(() => void load(worldId, query.trim()), 250);
    return () => clearTimeout(timer);
  }, [worldId, query, load]);

  const patch = (id: number, change: Partial<AdminSettlementDto>) =>
    setSettlements((list) => list.map((s) => (s.id === id ? { ...s, ...change } : s)));

  const displayName = (s: AdminSettlementDto) => s.customName ?? s.name;

  const changeOwner = async (s: AdminSettlementDto, value: string) => {
    if (worldId === null) return;
    const accountId = value === '' ? null : Number(value);
    const player = players.find((p) => p.accountId === accountId);
    const ownerLabel = player ? `${player.nation} (${player.username})` : t('admin.independent');
    if (!window.confirm(t('admin.confirmOwner', { name: displayName(s), owner: ownerLabel }))) return;
    try {
      await adminApi.setOwner(worldId, s.id, accountId);
      patch(s.id, { ownerId: accountId, ownerUsername: player?.username ?? null, ownerNation: player?.nation ?? null });
      setNotice({ kind: 'ok', text: t('admin.ownerSaved', { name: displayName(s), owner: ownerLabel }) });
    } catch (err) {
      fail(err);
    }
  };

  const saveLevel = async (s: AdminSettlementDto, building: BuildingId, level: number) => {
    if (worldId === null) return;
    try {
      const levels = await adminApi.setBuilding(worldId, s.id, building, level);
      patch(s.id, { levels, points: settlementPoints(levels) });
      setNotice({ kind: 'ok', text: t('admin.levelSaved', { building: buildingName(building), n: level }) });
    } catch (err) {
      fail(err);
    }
  };

  const ownerOptions = useMemo(
    () => players.map((p) => ({ value: String(p.accountId), label: `${p.nation} (${p.username})` })),
    [players],
  );

  return (
    <div className={`admin ${tab === 'map' ? 'wide' : ''}`}>
      <header className="admin-head">
        <h1 className="logo small">{t('admin.title')}</h1>
        <label className="admin-world">
          {t('admin.world')}
          <select value={worldId ?? ''} onChange={(e) => setWorldId(Number(e.target.value))}>
            {worlds.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name}
              </option>
            ))}
          </select>
        </label>
        <div className="view-switch" role="group">
          <button className={tab === 'list' ? 'active' : ''} aria-pressed={tab === 'list'} onClick={() => setTab('list')}>
            {t('admin.tabList')}
          </button>
          <button className={tab === 'map' ? 'active' : ''} aria-pressed={tab === 'map'} onClick={() => setTab('map')}>
            {t('admin.tabMap')}
          </button>
        </div>
        <span className="spacer" />
        <LanguageSwitch />
        <ThemeToggle />
        <a className="admin-link" href="/">
          {t('admin.backToGame')}
        </a>
        <button className="link" onClick={onLogout}>
          {t('admin.signOut')}
        </button>
      </header>

      {notice && (
        <div className={notice.kind === 'ok' ? 'admin-ok' : 'error'} role="status">
          {notice.text}
          <button className="link" onClick={() => setNotice(null)} aria-label="×">
            ×
          </button>
        </div>
      )}

      {tab === 'map' && worldId !== null && (
        <AdminMap
          worldId={worldId}
          players={players}
          notify={setNotice}
          onChanged={() => void load(worldId, query.trim())}
          onOpenInList={(q) => {
            setQuery(q);
            setTab('list');
          }}
        />
      )}

      {tab === 'list' && (
      <>
      <div className="admin-tools">
        <input className="admin-search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('admin.search')} aria-label={t('admin.search')} />
        <span className="muted small">{t('admin.count', { n: settlements.length })}</span>
      </div>
      {settlements.length >= 300 && <div className="muted small">{t('admin.limit')}</div>}
      {settlements.length === 0 && <div className="muted">{t('admin.noResults')}</div>}

      <ul className="admin-list">
        {settlements.map((s) => (
          <li key={s.id} className="admin-row">
            <div className="admin-main">
              <div className="admin-id">
                <strong className="admin-name">{displayName(s)}</strong>
                <span className="muted small mono">
                  #{s.id} · {s.countryCode} · {t('points', { n: fmtInt(s.points) })}
                </span>
              </div>
              <label className="admin-owner">
                <span className="muted small">{t('admin.owner')}</span>
                <select value={s.ownerId ?? ''} onChange={(e) => void changeOwner(s, e.target.value)}>
                  <option value="">{t('admin.independent')}</option>
                  {ownerOptions.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </label>
              <button className="small" onClick={() => setOpen(open === s.id ? null : s.id)} aria-expanded={open === s.id}>
                {open === s.id ? t('admin.hideBuildings') : t('admin.showBuildings')}
              </button>
            </div>
            {open === s.id && (
              <div className="admin-buildings">
                <p className="muted small">{t('admin.levelNote')}</p>
                <div className="admin-grid">
                  {BUILDING_IDS.map((id) => (
                    <LevelEditor key={`${s.id}-${id}-${s.levels[id]}`} id={id} level={s.levels[id]} onSave={(level) => saveLevel(s, id, level)} />
                  ))}
                </div>
              </div>
            )}
          </li>
        ))}
      </ul>
      </>
      )}
    </div>
  );
}

function LevelEditor({ id, level, onSave }: { id: BuildingId; level: number; onSave: (level: number) => void }) {
  const { t, buildingName } = useI18n();
  const max = BUILDINGS[id].maxLevel;
  const [value, setValue] = useState(String(level));
  const number = Number(value);
  const valid = value !== '' && Number.isInteger(number) && number >= 0 && number <= max;
  const changed = valid && number !== level;

  return (
    <form
      className={`admin-level ${level > 0 ? '' : 'off'}`}
      onSubmit={(e) => {
        e.preventDefault();
        if (changed) onSave(number);
      }}
    >
      <BuildingIcon id={id} size={32} className={level > 0 ? '' : 'unbuilt'} />
      <span className="admin-level-name">
        {buildingName(id)}
        <span className="faint small"> {t('admin.maxLevel', { n: max })}</span>
      </span>
      <input type="number" min={0} max={max} step={1} value={value} onChange={(e) => setValue(e.target.value)} aria-label={`${buildingName(id)} — ${t('admin.level')}`} />
      <button className="primary small" disabled={!changed}>
        {t('admin.save')}
      </button>
    </form>
  );
}
