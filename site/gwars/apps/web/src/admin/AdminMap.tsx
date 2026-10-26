import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AdminPlayerDto, MapHexesResponse } from '@geowars/rules';
import { api } from '../api';
import { MapControls, type SearchTarget } from '../components/MapControls';
import { MapView, type HexOwner, type MapMode } from '../components/MapView';
import { fmtInt, useI18n } from '../i18n';
import { adminApi } from './adminApi';

interface Props {
  worldId: number;
  players: AdminPlayerDto[];
  notify: (notice: { kind: 'ok' | 'error'; text: string }) => void;
  /** Called after a claim, so the settlements list can reload. */
  onChanged: () => void;
  /** Opens the settlements tab filtered to this name (the stored, English one, which the list searches). */
  onOpenInList: (query: string) => void;
}

/** The world map for admins: unclaimed land can be claimed for a player, which creates a starter settlement. */
export function AdminMap({ worldId, players, notify, onChanged, onOpenInList }: Props) {
  const { t, errorText, hexName, countryName } = useI18n();
  const [map, setMap] = useState<MapHexesResponse | null>(null);
  const [owners, setOwners] = useState(new Map<number, HexOwner>());
  const [names, setNames] = useState<Record<number, string>>({});
  const [mode, setMode] = useState<MapMode>('owners');
  const [selected, setSelected] = useState<number | null>(null);
  const [focus, setFocus] = useState<{ idx: number; seq: number } | null>(null);
  const [chosen, setChosen] = useState('');
  const [busy, setBusy] = useState(false);

  /** Who holds which hex. Cheap, so it is refreshed after every claim. */
  const refreshOwners = useCallback(async () => {
    try {
      const settled = await api.mapSettlements(worldId);
      setOwners(new Map(settled.settlements.map(([idx, id, ownerId, points]) => [idx, { settlementId: id, ownerId, points }])));
      setNames(settled.players);
    } catch (err) {
      notify({ kind: 'error', text: errorText(err) });
    }
  }, [worldId, errorText, notify]);

  // The hexes themselves never change during a world, so they are loaded once per world.
  useEffect(() => {
    setMap(null);
    setSelected(null);
    api.hexes(worldId).then(setMap, (err) => notify({ kind: 'error', text: errorText(err) }));
    void refreshOwners();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reload only when the world changes
  }, [worldId]);

  const pickTarget = useCallback((target: SearchTarget) => {
    if (target.select) setSelected(target.idx);
    setFocus({ idx: target.idx, seq: Date.now() });
  }, []);

  // The admin sees no "own" nation on this map: every owner is drawn as another nation.
  const nobody = 0;
  const hex = map && selected !== null ? map.hexes[selected] : null;
  const owner = selected !== null ? owners.get(selected) : undefined;
  const ownerLabel = owner ? (owner.ownerId ? (names[owner.ownerId] ?? t('map.unknownNation')) : t('map.independent')) : null;
  const player = useMemo(() => players.find((p) => String(p.accountId) === chosen), [players, chosen]);

  const claim = async () => {
    if (!map || selected === null || !hex || !player) return;
    const label = hexName(hex, map.countries);
    if (!window.confirm(t('admin.claimConfirm', { hex: label, owner: `${player.nation} (${player.username})` }))) return;
    setBusy(true);
    try {
      const { settlementId } = await adminApi.claimHex(worldId, selected, player.accountId);
      setOwners((prev) => new Map(prev).set(selected, { settlementId, ownerId: player.accountId, points: 0 }));
      setNames((prev) => ({ ...prev, [player.accountId]: player.nation }));
      setChosen('');
      notify({ kind: 'ok', text: t('admin.claimed', { hex: label, owner: player.nation }) });
      onChanged();
      void refreshOwners(); // fresh points for the new settlement
    } catch (err) {
      notify({ kind: 'error', text: errorText(err) });
    } finally {
      setBusy(false);
    }
  };

  if (!map) return <div className="muted">{t('app.loadingWorld')}</div>;

  return (
    <div className="admin-map">
      <MapView
        hexes={map.hexes}
        countries={map.countries}
        owners={owners}
        players={names}
        mode={mode}
        myId={nobody}
        selected={selected}
        focus={focus}
        onSelect={setSelected}
      >
        <MapControls
          mode={mode}
          onMode={setMode}
          hexes={map.hexes}
          countries={map.countries}
          owners={owners}
          players={names}
          customNames={[]}
          onPick={pickTarget}
          showMine={false}
        />
      </MapView>

      <aside className="admin-hex">
        {!hex || selected === null ? (
          <div className="muted">{t('admin.pickHex')}</div>
        ) : (
          <div className="stack">
            <div>
              <h2 className="admin-hex-title">{hexName(hex, map.countries)}</h2>
              <div className="muted">{countryName(hex[1], map.countries)}</div>
            </div>
            <section className="card">
              <h3>{t('admin.hex')}</h3>
              {owner ? (
                <>
                  <div>{t('admin.claimedBy', { owner: ownerLabel ?? '' })}</div>
                  <div className="muted small mono">
                    #{owner.settlementId} · {t('points', { n: fmtInt(owner.points) })}
                  </div>
                  <button className="small" style={{ marginTop: 10 }} onClick={() => onOpenInList(hex[2])}>
                    {t('admin.openInList')}
                  </button>
                </>
              ) : (
                <>
                  <div>{t('admin.unclaimed')}</div>
                  <label className="admin-owner" style={{ marginTop: 10 }}>
                    <span className="muted small">{t('admin.claimFor')}</span>
                    <select value={chosen} onChange={(e) => setChosen(e.target.value)}>
                      <option value="">{t('admin.choosePlayer')}</option>
                      {players.map((p) => (
                        <option key={p.accountId} value={p.accountId}>
                          {p.nation} ({p.username})
                        </option>
                      ))}
                    </select>
                  </label>
                  <button className="primary" style={{ marginTop: 10 }} disabled={busy || !player} onClick={() => void claim()}>
                    {t('admin.claim')}
                  </button>
                  <p className="muted small">{t('admin.claimNote')}</p>
                </>
              )}
            </section>
          </div>
        )}
      </aside>
    </div>
  );
}
