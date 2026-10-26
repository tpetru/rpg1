import { useMemo, useState } from 'react';
import type { CountryRef, HexRow } from '@geowars/rules';
import { useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { MAP_PALETTES, useTheme } from '../theme';
import { resourceRamp, type HexOwner, type MapMode } from './MapView';

const MODES: { id: MapMode; label: TextKey }[] = [
  { id: 'owners', label: 'map.layer.owners' },
  { id: 'countries', label: 'map.layer.countries' },
  { id: 'food', label: 'res.food' },
  { id: 'steel', label: 'res.steel' },
  { id: 'oil', label: 'res.oil' },
  { id: 'rare', label: 'res.rare' },
  { id: 'uranium', label: 'res.uranium' },
];

/** A place the search can jump to. `select` opens the hex panel; countries only move the camera. */
export interface SearchTarget {
  idx: number;
  select: boolean;
}

interface Result {
  key: string;
  title: string;
  detail: string;
  target: SearchTarget;
}

interface Props {
  mode: MapMode;
  onMode: (mode: MapMode) => void;
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  owners: Map<number, HexOwner>;
  players: Record<number, string>;
  /** Names the player gave to their own settlements. */
  customNames: { idx: number; name: string }[];
  onPick: (target: SearchTarget) => void;
}

const MAX_RESULTS = 8;
const fold = (s: string) => s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

export function MapControls({ mode, onMode, hexes, countries, owners, players, customNames, onPick }: Props) {
  const { t, hexName, countryName } = useI18n();
  const { theme } = useTheme();
  const palette = MAP_PALETTES[theme];
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(true);
  const needle = fold(query.trim());

  // Names are searched without diacritics or case: "bucuresti" finds "București".
  const results = useMemo<Result[]>(() => {
    if (needle.length < 2) return [];
    const out: Result[] = [];
    const seen = new Set<number>();
    const add = (r: Result) => {
      if (out.length < MAX_RESULTS) out.push(r);
    };

    for (const [idx, owner] of owners) {
      const nation = owner.ownerId ? players[owner.ownerId] : undefined;
      if (nation && fold(nation).includes(needle) && !seen.has(owner.ownerId)) {
        seen.add(owner.ownerId);
        add({ key: `n${owner.ownerId}`, title: nation, detail: `${t('map.search.nation')} · ${hexName(hexes[idx], countries)}`, target: { idx, select: true } });
      }
    }
    for (const c of customNames) {
      if (fold(c.name).includes(needle)) {
        add({ key: `c${c.idx}`, title: c.name, detail: `${t('map.search.settlement')} · ${countryName(hexes[c.idx][1], countries)}`, target: { idx: c.idx, select: true } });
      }
    }
    // Countries: jump to the first hex of the country.
    const firstOfCountry = new Map<string, number>();
    hexes.forEach((h, idx) => {
      if (!firstOfCountry.has(h[1])) firstOfCountry.set(h[1], idx);
    });
    for (const [code, idx] of firstOfCountry) {
      const name = countryName(code, countries);
      if (fold(name).includes(needle)) add({ key: `k${code}`, title: name, detail: t('map.search.country'), target: { idx, select: false } });
    }
    for (let idx = 0; idx < hexes.length && out.length < MAX_RESULTS; idx++) {
      const name = hexName(hexes[idx], countries);
      if (fold(name).includes(needle)) {
        add({ key: `h${idx}`, title: name, detail: `${t('map.search.place')} · ${countryName(hexes[idx][1], countries)}`, target: { idx, select: true } });
      }
    }
    return out;
  }, [needle, owners, players, customNames, hexes, countries, t, hexName, countryName]);

  const ramp = mode === 'owners' || mode === 'countries' ? null : resourceRamp(mode, palette);

  return (
    <div className={`map-controls ${open ? '' : 'collapsed'}`}>
      <button className="map-controls-toggle" onClick={() => setOpen(!open)} aria-expanded={open} title={t('map.layers')}>
        {open ? '×' : '☰'}
      </button>
      {open && (
        <>
          <div className="map-search">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t('map.search.placeholder')}
              aria-label={t('map.search.placeholder')}
            />
            {needle.length >= 2 && (
              <ul className="map-results">
                {results.length === 0 && <li className="muted small">{t('map.search.none')}</li>}
                {results.map((r) => (
                  <li key={r.key}>
                    <button
                      onClick={() => {
                        onPick(r.target);
                        setQuery('');
                      }}
                    >
                      <strong>{r.title}</strong>
                      <span className="muted small">{r.detail}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="layer-list" role="radiogroup" aria-label={t('map.layers')}>
            {MODES.map((m) => (
              <button key={m.id} role="radio" aria-checked={mode === m.id} className={mode === m.id ? 'active' : ''} onClick={() => onMode(m.id)}>
                {t(m.label)}
              </button>
            ))}
          </div>

          <div className="legend">
            {mode === 'owners' && (
              <>
                <span><i style={{ background: palette.mine }} />{t('map.legend.mine')}</span>
                <span><i style={{ background: palette.player }} />{t('map.legend.player')}</span>
                <span><i style={{ background: palette.independent }} />{t('map.independent')}</span>
                <span><i style={{ background: palette.free }} />{t('map.unclaimed')}</span>
              </>
            )}
            {mode === 'countries' && <span className="muted small">{t('map.legend.countries')}</span>}
            {ramp && (
              <div className="ramp">
                <div className="ramp-bar" style={{ background: `linear-gradient(90deg, ${ramp[0]}, ${ramp[1]}, ${ramp[2]})` }} />
                <div className="ramp-labels muted small">
                  <span>{mode === 'rare' || mode === 'uranium' ? t('map.legend.none') : t('map.legend.poor')}</span>
                  <span>{t('map.legend.rich')}</span>
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
