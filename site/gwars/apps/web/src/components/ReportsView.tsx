import { useEffect, useMemo, useState } from 'react';
import { BUILDING_IDS, UNIT_IDS, normalizeUnits, unitTotal, type BattleReportData, type CommandDto, type CountryRef, type HexRow, type OwnSettlementDto, type ReportDto, type UnitCounts } from '@geowars/rules';
import { UnitIcon } from '../art/units';
import { ReportEmblem, type ReportOutcome } from '../art/reportGlyphs';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { fmtClock, fmtDateTimeMs, fmtDuration, fmtHms } from '../util';

interface Props {
  /** The player's nation: the one who sent every army in the reports. */
  nation: string;
  /** The player's settlements, for the names they gave them. */
  mine: OwnSettlementDto[];
  reports: ReportDto[];
  hexes: HexRow[];
  countries: Record<string, CountryRef>;
  onMarkRead: (id: number) => void;
  onMarkAllRead: () => void;
  /** Jump to a hex on the map. */
  onShow: (idx: number) => void;
}

const present = (units: UnitCounts) => UNIT_IDS.filter((u) => units[u] > 0);

export interface Movement extends CommandDto {
  attackerName?: string | null;
  unitsHidden?: boolean;
  timeHidden?: boolean;
}

/** Armies on the way: the units, from where to where, and when they arrive. */
export function MovementList({ commands, label, now, onShow, exact = false }: { commands: Movement[]; label: (idx: number) => string; now: number; onShow: (idx: number) => void; exact?: boolean }) {
  const { t } = useI18n();
  return (
    <ul className="movements">
      {commands.map((c) => {
        // A return keeps the attack's endpoints: origin is home, target the field the army
        // left — the row reads in the direction the troops actually travel.
        const [from, to] = c.type === 'return' ? [c.targetIdx, c.originIdx] : [c.originIdx, c.targetIdx];
        return (
        <li key={c.id}>
          {c.attackerName && <div className="small muted">{t('radar.from', { name: c.attackerName })}</div>}
          <div className="movement-units">
            {c.unitsHidden ? (
              <span className="muted small">{t('radar.unknownUnits')}</span>
            ) : (
              present(c.units).map((u) => (
                <span key={u} className="chip" title={t(`unit.${u}.name` as TextKey)}>
                  <UnitIcon unit={u} size={18} />
                  <span className="mono">{fmtInt(c.units[u])}</span>
                </span>
              ))
            )}
          </div>
          <div>
            <button className="link plain" onClick={() => onShow(from)}>
              {label(from)}
            </button>
            <span className="faint"> → </span>
            <button className="link plain" onClick={() => onShow(to)}>
              {label(to)}
            </button>
          </div>
          <div className="muted small mono">
            {'timeHidden' in c && c.timeHidden
              ? t('radar.timeUnknown')
              : exact
              ? t(c.type === 'return' ? 'radar.returns' : 'radar.arrives', { left: fmtHms((c.arrivesAt - now) / 1000), at: fmtClock(c.arrivesAt) })
              : t('reports.arrives', { time: fmtDuration((c.arrivesAt - now) / 1000) })}
          </div>
        </li>
        );
      })}
    </ul>
  );
}

type AttackKind = 'attack' | 'bombing' | 'spy';

/** What the army was sent to do, from what it was made of. */
const attackKind = (d: BattleReportData): AttackKind =>
  UNIT_IDS.some((u) => d.attackers[u] > 0 && u !== 'spy' && u !== 'bomber') ? 'attack' : d.attackers.bomber > 0 ? 'bombing' : 'spy';

/** The six outcome emblems, in the order the filter chips show them. */
const OUTCOMES: ReportOutcome[] = ['won', 'conquered', 'lost', 'spy', 'air', 'late'];

/**
 * Which emblem a report carries: how the battle went for its reader. The defender's copy
 * flips the verdict — holding the town is the win. Conquest is its own emblem: it is the
 * outcome the whole game is played for.
 */
const emblemOf = (d: BattleReportData, kind: AttackKind): ReportOutcome => {
  if (d.outcome === 'fizzled') return 'late';
  if (kind === 'spy') return 'spy';
  if (d.outcome === 'air') return 'air';
  if (d.asDefender) return d.outcome === 'defeat' ? 'won' : 'lost';
  return d.outcome === 'conquered' ? 'conquered' : d.outcome === 'defeat' ? 'lost' : 'won';
};

/** The player who sent the army: me, unless I am reading the report as the defender. */
const attackerOf = (d: BattleReportData, nation: string) => (d.asDefender ? (d.attackerName ?? '?') : nation);
/** The player who held the target: me, when I am the defender. */
const defenderOf = (d: BattleReportData, nation: string, abandoned: string) => (d.asDefender ? nation : (d.defenderName ?? abandoned));

/**
 * The heraldic roll: one continuous list, newest first, where the outcome is a gutter of
 * emblems down the left edge — you read the pattern of wins and losses before any word.
 * Rows are ruled, not boxed; unread ones carry a slim accent rail. The filters are a strip
 * of emblem stamps with live counts, plus one search and the settlement the army left.
 */
export function ReportsView({ nation, mine, reports, hexes, countries, onMarkRead, onMarkAllRead, onShow }: Props) {
  const { t, lang, hexName } = useI18n();
  const [openId, setOpenId] = useState<number | null>(null);
  const label = (idx: number) => hexName(hexes[idx], countries);
  const settlementName = (id: number, idx: number) => mine.find((m) => m.id === id)?.customName ?? label(idx);
  const unread = reports.filter((r) => !r.read).length;
  const [kindFilter, setKindFilter] = useState<AttackKind | ''>('');
  const [outcomeFilter, setOutcomeFilter] = useState<ReportOutcome | ''>('');
  const [fromFilter, setFromFilter] = useState('');
  const [q, setQ] = useState('');
  const has = (text: string, query: string) => text.toLowerCase().includes(query.trim().toLowerCase());

  const outcomeOf = (r: ReportDto) => emblemOf(r.data, attackKind(r.data));
  const counts = useMemo(() => {
    const c = new Map<ReportOutcome, number>();
    for (const r of reports) c.set(outcomeOf(r), (c.get(outcomeOf(r)) ?? 0) + 1);
    return c;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reports]);

  const shown = reports.filter((r) => {
    const d = r.data;
    return (
      (kindFilter === '' || attackKind(d) === kindFilter) &&
      (outcomeFilter === '' || outcomeOf(r) === outcomeFilter) &&
      (fromFilter === '' || d.originId === Number(fromFilter)) &&
      (q.trim() === '' ||
        has(attackerOf(d, nation), q) ||
        has(defenderOf(d, nation, t('reports.abandoned')), q) ||
        has(settlementName(d.targetId, d.targetIdx), q) ||
        has(label(d.targetIdx), q))
    );
  });
  const filtering = kindFilter !== '' || outcomeFilter !== '' || fromFilter !== '' || q.trim() !== '';
  const clearFilters = () => {
    setKindFilter('');
    setOutcomeFilter('');
    setFromFilter('');
    setQ('');
  };
  const open = reports.find((r) => r.id === openId) ?? null;

  const outcomeLabel = (o: ReportOutcome) =>
    t(o === 'conquered' ? 'reports.emblem.conquered' : o === 'air' ? 'reports.emblem.air' : (`reports.dot.${o}` as TextKey));

  const dayLabel = (ts: number) => {
    const d = new Date(ts);
    const today = new Date();
    const sameDay = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    if (sameDay(d, today)) return t('reports.today');
    if (sameDay(d, new Date(today.getTime() - 86_400_000))) return t('reports.yesterday');
    return d.toLocaleDateString(lang === 'ro' ? 'ro-RO' : 'en-US', { dateStyle: 'medium' });
  };

  const show = (r: ReportDto) => {
    setOpenId(r.id);
    if (!r.read) onMarkRead(r.id);
  };

  return (
    <section className="reports" aria-label={t('view.reports')}>
      <div className="reports-col">
        <div className="reports-head">
          <h2 className="reports-title">{t('view.reports')}</h2>
          {unread > 0 && (
            <button className="link" onClick={onMarkAllRead}>
              {t('reports.markAllRead')} ({unread})
            </button>
          )}
        </div>
        {reports.length === 0 ? (
          <p className="muted">{t('reports.empty')}</p>
        ) : (
          <>
            <div className="report-filters">
              <div className="report-chips" role="group" aria-label={t('reports.filterOutcome')}>
                {OUTCOMES.filter((o) => (counts.get(o) ?? 0) > 0).map((o) => (
                  <button
                    key={o}
                    type="button"
                    className={`report-chip ${outcomeFilter === o ? 'active' : ''}`}
                    aria-pressed={outcomeFilter === o}
                    title={outcomeLabel(o)}
                    aria-label={outcomeLabel(o)}
                    onClick={() => setOutcomeFilter(outcomeFilter === o ? '' : o)}
                  >
                    <ReportEmblem outcome={o} size={16} />
                    <span className="mono">{counts.get(o)}</span>
                  </button>
                ))}
              </div>
              <label className="report-field">
                <span className="report-field-cap">{t('reports.colType')}</span>
                <select value={kindFilter} onChange={(e) => setKindFilter(e.target.value as AttackKind | '')}>
                  <option value="">{t('reports.filterAll')}</option>
                  <option value="attack">{t('reports.kind.attack')}</option>
                  <option value="bombing">{t('reports.kind.bombing')}</option>
                  <option value="spy">{t('reports.kind.spy')}</option>
                </select>
              </label>
              <label className="report-field">
                <span className="report-field-cap">{t('reports.colFrom')}</span>
                <select value={fromFilter} onChange={(e) => setFromFilter(e.target.value)}>
                  <option value="">{t('reports.filterAll')}</option>
                  {mine.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.customName ?? label(m.idx)}
                    </option>
                  ))}
                </select>
              </label>
              <input aria-label={t('reports.search')} placeholder={t('reports.search')} value={q} onChange={(e) => setQ(e.target.value)} />
              <span className="report-filter-count mono small muted">
                {shown.length} / {reports.length}
                {filtering && (
                  <button className="link" onClick={clearFilters}>
                    {t('reports.filterClear')}
                  </button>
                )}
              </span>
            </div>
            <div className="report-rows" role="table" aria-label={t('view.reports')}>
              <div className="report-row head" role="row">
                <span />
                <span>{t('reports.colType')}</span>
                <span>{t('reports.colAttacker')}</span>
                <span>{t('reports.colFrom')}</span>
                <span>{t('reports.colDefender')}</span>
                <span>{t('reports.colTarget')}</span>
                <span className="when">{t('reports.colWhen')}</span>
              </div>
              {shown.length === 0 && <p className="muted report-nomatch">{t('reports.noMatch')}</p>}
              {shown.map((r, i) => {
                const d = r.data;
                const kind = attackKind(d);
                const o = emblemOf(d, kind);
                const day = dayLabel(r.createdAt);
                const newDay = i === 0 || dayLabel(shown[i - 1].createdAt) !== day;
                return (
                  <div key={r.id} className="report-line">
                    {newDay && (
                      <div className="report-day" role="rowgroup">
                        {day}
                      </div>
                    )}
                    <button
                      className={`report-row ${r.read ? '' : 'unread'}`}
                      role="row"
                      aria-label={`${outcomeLabel(o)} — ${t(`reports.kind.${kind}` as TextKey)}`}
                      onClick={() => show(r)}
                    >
                      <span className="report-emb">
                        <ReportEmblem outcome={o} size={20} />
                      </span>
                      <span className="cell kind">{t(`reports.kind.${kind}` as TextKey)}</span>
                      <span className="cell">{attackerOf(d, nation)}</span>
                      <span className="cell muted">{settlementName(d.originId, d.originIdx)}</span>
                      <span className="cell muted">{defenderOf(d, nation, t('reports.abandoned'))}</span>
                      <span className="cell target">{settlementName(d.targetId, d.targetIdx)}</span>
                      <span className="cell when mono small">{fmtDateTimeMs(r.createdAt)}</span>
                    </button>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>

      {open && (
        <ReportDialog
          report={open}
          nation={nation}
          label={label}
          lang={lang}
          onShow={(idx) => {
            setOpenId(null);
            onShow(idx);
          }}
          onClose={() => setOpenId(null)}
        />
      )}
    </section>
  );
}

function ReportDialog({ report, nation, label, lang, onShow, onClose }: { report: ReportDto; nation: string; label: (idx: number) => string; lang: string; onShow: (idx: number) => void; onClose: () => void }) {
  const { t, buildingName } = useI18n();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const d: BattleReportData = report.data;
  const kind = attackKind(d);
  const o = emblemOf(d, kind);
  const target = label(d.targetIdx);
  const title = d.asDefender
    ? t(d.outcome === 'defeat' ? 'reports.def.held' : d.outcome === 'victory' || d.outcome === 'conquered' ? 'reports.def.raided' : 'reports.def.air', { name: target })
    : t(d.outcome === 'conquered' ? 'reports.conquered' : d.outcome === 'defeat' ? 'reports.defeat' : d.outcome === 'victory' ? 'reports.victory' : d.outcome === 'air' ? 'reports.air' : 'reports.fizzled', { name: target });
  const when = new Date(report.createdAt).toLocaleString(lang === 'ro' ? 'ro-RO' : 'en-US', { dateStyle: 'medium', timeStyle: 'medium' });
  // Reports stored before a unit existed carry no key for it: normalise every count map so
  // the ledger can never do arithmetic with undefined.
  const attackers = normalizeUnits(d.attackers);
  const attackerLosses = normalizeUnits(d.attackerLosses);
  const defenders = normalizeUnits(d.defenders);
  const defenderLosses = normalizeUnits(d.defenderLosses);
  const aSent = unitTotal(attackers);
  const aLost = unitTotal(attackerLosses);
  const bSent = unitTotal(defenders);
  const bLost = unitTotal(defenderLosses);

  return (
    <div className="modal-backdrop" onMouseDown={onClose}>
      <div className={`modal report-dialog report ${d.outcome}`} role="dialog" aria-modal="true" aria-label={title} onMouseDown={(e) => e.stopPropagation()}>
        <header className="report-band">
          <ReportEmblem outcome={o} size={44} />
          <div className="modal-title">
            <h2>{title}</h2>
            <span className="faint small">{when}</span>
          </div>
          <button className="link modal-close" onClick={onClose} aria-label={t('hall.close')}>
            ×
          </button>
        </header>
        <div className="muted small">
          {t('reports.from', { name: label(d.originIdx) })} ·{' '}
          <button className="link plain" onClick={() => onShow(d.targetIdx)}>
            {target}
          </button>
        </div>
        {d.outcome === 'fizzled' ? (
          <>
            <p className="muted small">{t('reports.fizzledNote')}</p>
            <div className="movement-units">
              {present(attackers).map((u) => (
                <span key={u} className="chip" title={t(`unit.${u}.name` as TextKey)}>
                  <UnitIcon unit={u} size={18} />
                  <span className="mono">{fmtInt(attackers[u])}</span>
                </span>
              ))}
            </div>
          </>
        ) : (
          <>
            {/* The battle ledger: every branch of the service on both sides — what marched,
                what fell, and what stands in the settlement afterwards. */}
            <table className="ledger">
              <thead>
                <tr>
                  <th />
                  <th className="side" colSpan={3}>{attackerOf(d, nation)}</th>
                  <th className="side" colSpan={3}>{defenderOf(d, nation, t('reports.abandoned'))}</th>
                </tr>
                <tr className="cols">
                  <th />
                  <th>{t('reports.sent')}</th>
                  <th>{t('reports.lost')}</th>
                  <th>{t('reports.remained')}</th>
                  <th>{t('reports.sent')}</th>
                  <th>{t('reports.lost')}</th>
                  <th>{t('reports.remained')}</th>
                </tr>
              </thead>
              <tbody>
                {UNIT_IDS.map((u) => {
                  const a = attackers[u];
                  const b = defenders[u];
                  return (
                    <tr key={u} className={a === 0 && b === 0 ? 'none' : undefined}>
                      <th scope="row">
                        <UnitIcon unit={u} size={18} />
                        <span>{t(`unit.${u}.name` as TextKey)}</span>
                      </th>
                      <LedgerSide sent={a} lost={attackerLosses[u]} />
                      <LedgerSide sent={b} lost={defenderLosses[u]} />
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr>
                  <th>{t('reports.total')}</th>
                  <LedgerSide sent={aSent} lost={aLost} />
                  <LedgerSide sent={bSent} lost={bLost} />
                </tr>
              </tfoot>
            </table>
            {/* Where the standing troops are: home unless the town was taken; the garrison
                that held on is still in it. */}
            <p className="remain-line">
              <span>
                <strong className="mono">{fmtInt(aSent - aLost)}</strong>{' '}
                {d.outcome === 'conquered' ? t('reports.remainHold', { name: target }) : t('reports.remainReturn', { name: label(d.originIdx) })}
              </span>
              <span>
                <strong className="mono">{fmtInt(bSent - bLost)}</strong>{' '}
                {t('reports.remainGarrison', { name: target })}
              </span>
            </p>
            {d.bombed ? (
              <p className="small">{t('reports.bombed', { building: buildingName(d.bombed.building), from: d.bombed.from, to: d.bombed.to })}</p>
            ) : (
              d.outcome === 'air' && d.attackers.bomber > 0 && !d.bombersShot && <p className="muted small">{t('reports.noBombed')}</p>
            )}
            {d.wallsDown && <p className="small">{t('reports.wallsDown', { from: d.wallsDown.from, to: d.wallsDown.to })}</p>}
            {!!d.bombersShot && <p className="small">{t('reports.shotDown', { n: d.bombersShot })}</p>}
            {d.intel && (
              <div className="report-intel">
                <div className="faint small">{t('reports.intel')}</div>
                <ul className="intel-list">
                  {BUILDING_IDS.filter((id) => d.intel![id] > 0).map((id) => (
                    <li key={id}>
                      <span>{buildingName(id)}</span> <strong className="mono">{d.intel![id]}</strong>
                    </li>
                  ))}
                </ul>
              </div>
            )}
            <div className="report-meta">
              <span>
                {t('reports.attackPower')} <strong className="mono">{fmtInt(d.attackPower)}</strong>
              </span>
              <span>
                {t('reports.defensePower')} <strong className="mono">{fmtInt(d.defensePower)}</strong>
              </span>
              <span>{t('reports.luck', { n: Math.round((d.luck ?? 0) * 100) })}</span>
              {d.fortificationLevel > 0 && <span>{t('reports.fortifications', { n: d.fortificationLevel })}</span>}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/** One side's three ledger cells: marched, fallen, standing. */
function LedgerSide({ sent, lost }: { sent: number; lost: number }) {
  return (
    <>
      <td className="mono">{fmtInt(sent)}</td>
      <td className={`mono lost${lost > 0 ? '' : ' idle'}`}>{lost > 0 ? `−${fmtInt(lost)}` : '·'}</td>
      <td className="mono left">{fmtInt(Math.max(0, sent - lost))}</td>
    </>
  );
}
