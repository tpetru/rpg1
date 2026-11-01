import { useEffect, useMemo, useState } from 'react';
import { BUILDING_IDS, UNITS, UNIT_IDS, zeroUnits, type AttackPreviewDto, type BuildingId, type OwnSettlementDto, type UnitCounts } from '@geowars/rules';
import type { HexRow, CountryRef } from '@geowars/rules';
import { api } from '../api';
import { UnitIcon } from '../art/units';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtDuration } from '../util';

interface Props {
  worldId: number;
  /** Settlement id of the abandoned settlement. */
  targetId: number;
  mine: OwnSettlementDto[];
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  /** Called after an army has been sent, so movements and troops are reloaded. */
  onSent: () => void;
  /** When set, the army always leaves from this settlement and the choice is not offered. */
  fixedOriginId?: number;
  /** The target belongs to nobody, so it can be conquered; another player's can only be raided. */
  abandoned?: boolean;
  /** The target is one of the player's own settlements. */
  own?: boolean;
  /** When set, a Cancel button is shown beside Attack (the panel lives in a dialog). */
  onCancel?: () => void;
}

/** Sends an army from one of the player's settlements against an abandoned one. */
export function AttackPanel({ worldId, targetId, mine, hexes, countries, onSent, fixedOriginId, abandoned = true, own = false, onCancel }: Props) {
  const { t, errorText, hexName, buildingName } = useI18n();
  const candidates = fixedOriginId === undefined ? mine : mine.filter((s) => s.id === fixedOriginId);
  const withTroops = candidates.filter((s) => UNIT_IDS.some((u) => s.units[u] > 0));
  const [originId, setOriginId] = useState<number | null>(null);
  const [picked, setPicked] = useState<UnitCounts>(zeroUnits());
  const [preview, setPreview] = useState<AttackPreviewDto | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [note, setNote] = useState<string | null>(null);
  const [bombTarget, setBombTarget] = useState<BuildingId | ''>('');

  // Default to the settlement with the biggest army.
  const origin = useMemo(() => {
    const chosen = candidates.find((s) => s.id === originId);
    if (chosen) return chosen;
    return [...candidates].sort((a, b) => UNIT_IDS.reduce((x, u) => x + b.units[u], 0) - UNIT_IDS.reduce((x, u) => x + a.units[u], 0))[0] ?? null;
  }, [candidates, originId]);

  const total = UNIT_IDS.reduce((sum, u) => sum + picked[u], 0);
  const pickedKey = JSON.stringify(picked);

  useEffect(() => {
    setNote(null);
    setError(null);
  }, [targetId]);

  // Ask the server what the trip would take; it knows about the sea and the real distance.
  useEffect(() => {
    if (!origin) return;
    const timer = setTimeout(() => {
      api.attackPreview(worldId, origin.id, targetId, picked).then(setPreview, () => setPreview(null));
    }, 250);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- pickedKey stands for picked
  }, [worldId, origin?.id, targetId, pickedKey]);

  if (!origin) return null;
  const name = (s: OwnSettlementDto) => s.customName ?? hexName(hexes[s.idx], countries);

  const setAmount = (unit: (typeof UNIT_IDS)[number], value: string) => {
    const n = Math.max(0, Math.min(origin.units[unit], Math.floor(Number(value) || 0)));
    setPicked((prev) => ({ ...prev, [unit]: n }));
  };

  const send = async () => {
    setBusy(true);
    setError(null);
    setNote(null);
    try {
      const command = await api.attack(worldId, origin.id, targetId, picked, picked.bomber > 0 && bombTarget ? bombTarget : undefined);
      setNote(t('attack.sent', { time: fmtDuration((command.arrivesAt - Date.now()) / 1000) }));
      setPicked(zeroUnits());
      onSent();
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };

  const blocked = preview?.needsPort ?? false;

  return (
    <div className="attack">
      <p className="muted small">{t(own ? 'attack.infoOwn' : abandoned ? 'attack.info' : 'attack.infoPlayer')}</p>

      {withTroops.length === 0 ? (
        <p className="muted">{t('attack.noTroops')}</p>
      ) : (
        <>
          {fixedOriginId === undefined && (
          <label className="admin-owner">
            <span className="muted small">{t('attack.from')}</span>
            <select
              value={origin.id}
              onChange={(e) => {
                setOriginId(Number(e.target.value));
                setPicked(zeroUnits());
              }}
            >
              {mine.map((s) => (
                <option key={s.id} value={s.id}>
                  {name(s)}
                </option>
              ))}
            </select>
          </label>
          )}

          <div className="attack-units">
            <span className="muted small">{t('attack.units')}</span>
            {UNIT_IDS.filter((u) => origin.units[u] > 0 && !UNITS[u].homeOnly).map((u) => (
              <label key={u} className="attack-unit">
                <UnitIcon unit={u} size={24} />
                <span>{t(`unit.${u}.name` as TextKey)}</span>
                <input type="number" min={0} max={origin.units[u]} value={picked[u] || ''} placeholder="0" onChange={(e) => setAmount(u, e.target.value)} />
                <button type="button" className="link" onClick={() => setAmount(u, String(origin.units[u]))}>
                  {t('attack.available', { n: fmtInt(origin.units[u]) })}
                </button>
              </label>
            ))}
          </div>

          {picked.bomber > 0 && (
            <label className="admin-owner">
              <span className="muted small">{t('attack.bombTarget')}</span>
              <select value={bombTarget} onChange={(e) => setBombTarget(e.target.value as BuildingId | '')}>
                <option value="">{t('attack.bombAuto')}</option>
                {BUILDING_IDS.map((id) => (
                  <option key={id} value={id}>
                    {buildingName(id)}
                  </option>
                ))}
              </select>
            </label>
          )}

          {preview && (
            <div className="attack-trip small">
              <span className="mono">{t('attack.distance', { km: fmtInt(preview.distanceKm) })}</span>
              {preview.travelMs !== null && <span className="mono"> · {t('attack.travel', { time: fmtDuration(preview.travelMs / 1000) })}</span>}
              {preview.overseas && <div className={preview.needsPort ? 'blocked' : 'muted'}>{preview.needsPort ? t('attack.needsPort') : t('attack.overseas')}</div>}
            </div>
          )}

          <div className="attack-buttons">
            <button className="primary" disabled={busy || total === 0 || blocked} onClick={() => void send()}>
              {t('attack.send')}
            </button>
            {onCancel && <button onClick={onCancel}>{t('attack.cancel')}</button>}
          </div>
        </>
      )}
      {note && <div className="admin-ok">{note}</div>}
      {error != null && <div className="error">{errorText(error)}</div>}
    </div>
  );
}
