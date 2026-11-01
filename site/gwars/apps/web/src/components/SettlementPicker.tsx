import { useCallback, useEffect, useId, useMemo, useRef, useState } from 'react';
import { fmtInt, useI18n } from '../i18n';
import { prefs } from '../util';

export interface PickerItem {
  idx: number;
  label: string;
  /** The country this settlement lies in, already in the reader's language. */
  sub: string;
  points: number;
}

interface Props {
  items: PickerItem[];
  selected: number | null;
  onPick: (idx: number) => void;
}

type Sort = 'points' | 'name';

const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

/** A row of the ledger: either a country heading or a settlement. */
type Row = { kind: 'group'; country: string } | { kind: 'option'; item: PickerItem; n: number };

/**
 * The realm ledger: the player's settlements, grouped by country and searchable at any size.
 * The search box is always there — with a couple of dozen towns it is the main tool, not an
 * extra. One keystroke or arrow press is enough to reach any town; the current one carries an
 * accent rail so it is findable in the scroll. Picking keeps whatever view the player is in —
 * that decision belongs to the caller, not to the picker.
 */
export function SettlementPicker({ items, selected, onPick }: Props) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const [sort, setSortState] = useState<Sort>(() => (prefs.get('gw.picksort') === 'name' ? 'name' : 'points'));
  const [pos, setPos] = useState({ left: 0, top: 0 });
  const button = useRef<HTMLButtonElement>(null);
  const box = useRef<HTMLDivElement>(null);
  const listId = useId();

  const setSort = (next: Sort) => {
    setSortState(next);
    prefs.set('gw.picksort', next);
  };

  const current = items.find((i) => i.idx === selected);

  /** Filter by name or country, group by country, then order groups and rows by the chosen sort. */
  const { options, rows } = useMemo(() => {
    const q = fold(query.trim());
    const shown = q ? items.filter((i) => fold(i.label).includes(q) || fold(i.sub).includes(q)) : items;
    const byCountry = new Map<string, PickerItem[]>();
    for (const item of shown) {
      const list = byCountry.get(item.sub);
      if (list) list.push(item);
      else byCountry.set(item.sub, [item]);
    }
    const groups = [...byCountry.entries()];
    for (const [, list] of groups) {
      list.sort(
        sort === 'points'
          ? (a, b) => b.points - a.points || a.label.localeCompare(b.label)
          : (a, b) => a.label.localeCompare(b.label),
      );
    }
    // A group ranks by its best town, so the realm's heartland surfaces first.
    groups.sort(
      sort === 'points'
        ? (a, b) => b[1][0].points - a[1][0].points || a[0].localeCompare(b[0])
        : (a, b) => a[0].localeCompare(b[0]),
    );
    const options: PickerItem[] = [];
    const rows: Row[] = [];
    for (const [country, list] of groups) {
      rows.push({ kind: 'group', country });
      for (const item of list) {
        rows.push({ kind: 'option', item, n: options.length });
        options.push(item);
      }
    }
    return { options, rows };
  }, [items, query, sort]);

  /** Keep the keyboard cursor on a real row when filtering shrinks the list. */
  useEffect(() => {
    setActive((a) => Math.min(a, Math.max(0, options.length - 1)));
  }, [options.length]);

  const place = useCallback(() => {
    const anchor = button.current?.getBoundingClientRect();
    const pop = box.current;
    if (!anchor || !pop) return;
    const left = Math.max(12, Math.min(anchor.left, window.innerWidth - pop.offsetWidth - 12));
    const below = anchor.bottom + 6;
    const top = below + pop.offsetHeight > window.innerHeight - 12 ? Math.max(12, window.innerHeight - pop.offsetHeight - 12) : below;
    setPos((p) => (p.left === left && p.top === top ? p : { left, top }));
  }, []);

  const toggle = () => {
    if (!open) {
      setQuery('');
      const r = button.current?.getBoundingClientRect();
      if (r) setPos({ left: r.left, top: r.bottom + 6 });
    }
    setOpen(!open);
  };

  /** Open with the current town under the cursor; the input takes focus via autoFocus. */
  useEffect(() => {
    if (!open) return;
    const n = options.findIndex((o) => o.idx === selected);
    setActive(Math.max(0, n));
  }, [open]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!open) return;
    const away = (e: MouseEvent) => {
      if (!box.current?.contains(e.target as Node) && !button.current?.contains(e.target as Node)) setOpen(false);
    };
    const onMove = () => place();
    place();
    document.addEventListener('mousedown', away);
    window.addEventListener('resize', onMove);
    window.addEventListener('scroll', onMove, true);
    return () => {
      document.removeEventListener('mousedown', away);
      window.removeEventListener('resize', onMove);
      window.removeEventListener('scroll', onMove, true);
    };
  }, [open, place]);

  useEffect(() => {
    box.current?.querySelector('[data-active="true"]')?.scrollIntoView({ block: 'nearest' });
  }, [active, open]);

  const pick = (idx: number) => {
    setOpen(false);
    onPick(idx);
    button.current?.focus();
  };

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setOpen(false);
      button.current?.focus();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((a) => Math.min(options.length - 1, a + 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((a) => Math.max(0, a - 1));
    } else if (e.key === 'Home') {
      e.preventDefault();
      setActive(0);
    } else if (e.key === 'End') {
      e.preventDefault();
      setActive(options.length - 1);
    } else if (e.key === 'Enter' && options[active]) {
      e.preventDefault();
      pick(options[active].idx);
    }
  };

  const activeItem = options[active];

  return (
    <div className="settlement-pick">
      <button ref={button} className="pick-button" aria-haspopup="listbox" aria-expanded={open} onClick={toggle}>
        <svg className="pick-glyph" viewBox="0 0 16 16" width="14" height="14" aria-hidden="true" focusable="false">
          <path fill="currentColor" d="M3 3h2v1h1.5V3h3V4H11V3h2v4l-1 1v7h-2.5v-3h-3v3H4V8L3 7V3z" />
        </svg>
        <span className="pick-name">{current ? current.label : t('topbar.settlements')}</span>
        <span className="pick-count mono" aria-hidden="true">
          {items.length}
        </span>
      </button>
      {open && (
        <div ref={box} className="pick-pop" style={{ left: pos.left, top: pos.top }} onKeyDown={onKey}>
          <div className="pick-search">
            <svg viewBox="0 0 16 16" width="13" height="13" aria-hidden="true">
              <path
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                d="M7 2.5a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zM10.5 10.5 14 14"
              />
            </svg>
            <input
              autoFocus
              role="combobox"
              aria-expanded="true"
              aria-controls={listId}
              aria-autocomplete="list"
              aria-activedescendant={activeItem ? `${listId}-${activeItem.idx}` : undefined}
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setActive(0);
              }}
              placeholder={t('topbar.settlementSearch')}
              aria-label={t('topbar.settlementSearch')}
            />
          </div>
          <div className="pick-sort" role="group" aria-label={t('picker.sort')}>
            <span className="pick-sort-label">{t('picker.sort')}</span>
            <button type="button" className={sort === 'points' ? 'active' : ''} aria-pressed={sort === 'points'} onClick={() => setSort('points')}>
              {t('picker.sortPoints')}
            </button>
            <button type="button" className={sort === 'name' ? 'active' : ''} aria-pressed={sort === 'name'} onClick={() => setSort('name')}>
              {t('picker.sortName')}
            </button>
          </div>
          <ul id={listId} role="listbox" aria-label={t('topbar.settlements')} className="pick-list">
            {rows.map((row) =>
              row.kind === 'group' ? (
                <li key={`h-${row.country}`} className="pick-group" role="presentation">
                  {row.country}
                </li>
              ) : (
                <li
                  key={row.item.idx}
                  id={`${listId}-${row.item.idx}`}
                  role="option"
                  aria-selected={row.item.idx === selected}
                  aria-current={row.item.idx === selected ? 'true' : undefined}
                  aria-label={`${row.item.label}, ${row.item.sub}, ${t('points', { n: fmtInt(row.item.points) })}${
                    row.item.idx === selected ? `, ${t('picker.current')}` : ''
                  }`}
                  data-active={row.n === active ? 'true' : undefined}
                  className={`pick-row ${row.n === active ? 'active' : ''} ${row.item.idx === selected ? 'current' : ''}`}
                  onMouseEnter={() => setActive(row.n)}
                  onClick={() => pick(row.item.idx)}
                >
                  <span className="pick-line">
                    <span className="pick-name" title={row.item.label}>
                      {row.item.idx === selected && <span className="pick-dot" aria-hidden="true" />}
                      {row.item.label}
                    </span>
                    <span className="pick-points">{fmtInt(row.item.points)}</span>
                  </span>
                  <span className="pick-sub">{row.item.sub}</span>
                </li>
              ),
            )}
            {options.length === 0 && <li className="pick-none">{t('admin.noResults')}</li>}
          </ul>
        </div>
      )}
    </div>
  );
}
