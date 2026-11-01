import { useEffect, useState } from 'react';
import type { RankingResponse, RankingType } from '@geowars/rules';
import { api } from '../api';
import { NationEmblem } from '../art/nation';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';

interface Props {
  worldId: number;
  accountId: number;
}

const TYPES: RankingType[] = ['points', 'cities', 'continent'];

/** The ranking: the kinds of ranking on the left, the players (20 to a page) on the right. */
export function RankingView({ worldId, accountId }: Props) {
  const { t, errorText } = useI18n();
  const [type, setType] = useState<RankingType>('points');
  const [continent, setContinent] = useState<string | undefined>(undefined);
  const [page, setPage] = useState(1);
  const [data, setData] = useState<RankingResponse | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    let live = true;
    api.ranking(worldId, type, page, continent).then(
      (res) => {
        if (!live) return;
        setData(res);
        setError(null);
        if (res.page !== page) setPage(res.page);
        if (type === 'continent' && res.continent && res.continent !== continent) setContinent(res.continent);
      },
      (err) => live && setError(err),
    );
    return () => {
      live = false;
    };
  }, [worldId, type, page, continent]);

  const pick = (next: RankingType) => {
    setType(next);
    setPage(1);
  };
  const continentName = (name: string) => t(`continent.${name}` as TextKey) ?? name;

  return (
    <section className="ranking" aria-label={t('view.ranking')}>
      <nav className="ranking-types" aria-label={t('ranking.types')}>
        {TYPES.map((k) => (
          <button key={k} className={type === k ? 'active' : ''} aria-pressed={type === k} onClick={() => pick(k)}>
            {t(`ranking.type.${k}` as TextKey)}
          </button>
        ))}
        {type === 'continent' && data && (
          <ul className="ranking-continents">
            {data.continents.map((c) => (
              <li key={c}>
                <button
                  className={data.continent === c ? 'active' : ''}
                  onClick={() => {
                    setContinent(c);
                    setPage(1);
                  }}
                >
                  {continentName(c)}
                </button>
              </li>
            ))}
          </ul>
        )}
      </nav>

      <div className="ranking-main">
        <h2 className="reports-title">
          {t(`ranking.type.${type}` as TextKey)}
          {type === 'continent' && data?.continent && <span className="muted"> · {continentName(data.continent)}</span>}
        </h2>
        {error != null && <div className="error">{errorText(error)}</div>}
        {data && data.rows.length === 0 ? (
          <p className="muted">{t('ranking.empty')}</p>
        ) : (
          <table className="ranking-table">
            <thead>
              <tr>
                <th className="num">#</th>
                {type === 'cities' && <th>{t('ranking.settlement')}</th>}
                <th>{t('ranking.player')}</th>
                {type !== 'cities' && <th className="num">{t('ranking.cities')}</th>}
                <th className="num">{t('ranking.pointsTotal')}</th>
                {type !== 'cities' && <th className="num">{t('ranking.perCity')}</th>}
              </tr>
            </thead>
            <tbody>
              {data?.rows.map((r) => (
                <tr key={`${r.accountId}-${r.rank}`} className={r.accountId === accountId ? 'me' : ''}>
                  <td className="num mono">{r.rank}</td>
                  {type === 'cities' && <td>{r.settlement}</td>}
                  <td>
                    <span className="ranking-player">
                      <NationEmblem name={r.nation} size={22} title={r.nation} />
                      {r.nation}
                    </span>
                  </td>
                  {type !== 'cities' && <td className="num mono">{fmtInt(r.cities)}</td>}
                  <td className="num mono">{fmtInt(r.points)}</td>
                  {type !== 'cities' && <td className="num mono">{r.cities > 0 ? fmtInt(Math.round(r.points / r.cities)) : '—'}</td>}
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {data && data.pages > 1 && (
          <div className="ranking-pager">
            <button disabled={data.page <= 1} onClick={() => setPage(data.page - 1)}>
              ‹
            </button>
            <span className="mono small">{t('ranking.page', { page: data.page, pages: data.pages })}</span>
            <button disabled={data.page >= data.pages} onClick={() => setPage(data.page + 1)}>
              ›
            </button>
            <span className="muted small">{t('ranking.total', { n: data.total })}</span>
          </div>
        )}
      </div>
    </section>
  );
}
