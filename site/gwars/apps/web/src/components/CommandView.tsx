import { Fragment, type ReactElement } from 'react';
import type { CommandDto, OwnSettlementDto } from '@geowars/rules';
import { UNITS, UNIT_IDS, zeroUnits, type BuildingId, type UnitId } from '@geowars/rules';
import { BombIcon, EyeIcon, FlagIcon, ShieldIcon, SwordsIcon, WallIcon } from '../art/actionIcons';
import { BuildingIcon } from '../art/buildings';
import { UnitIcon } from '../art/units';
import { fmtInt, useI18n } from '../i18n';
import type { TextKey } from '../i18n/en';
import { BackButton } from './BackButton';

interface Props {
  settlement: OwnSettlementDto;
  name: string;
  /** The player's armies on the move; only the ones sent from this settlement count here. */
  outgoing: CommandDto[];
  onBack: () => void;
}

type Role = 'attack' | 'defense' | 'spy' | 'bombing' | 'walls' | 'antibomb' | 'conquest';
const ROLE_ICON: Record<Role, () => ReactElement> = { attack: SwordsIcon, defense: ShieldIcon, spy: EyeIcon, bombing: BombIcon, walls: WallIcon, antibomb: ShieldIcon, conquest: FlagIcon };

/** What a unit is for, from its stats: spies and bombers by name, the rest by whether it hits harder than it holds. */
function roleOf(u: UnitId): Role {
  if (u === 'spy') return 'spy';
  if (u === 'bomber') return 'bombing';
  if (u === 'tank') return 'walls';
  if (u === 'drone') return 'antibomb';
  if (u === 'president') return 'conquest';
  return UNITS[u].attack > UNITS[u].defense ? 'attack' : 'defense';
}

/** The Command Center: level 1 counts the troops at home, level 2 adds the ones out on the road. */
export function CommandView({ settlement: s, name, outgoing, onBack }: Props) {
  const { t, buildingName } = useI18n();
  const away = zeroUnits();
  for (const c of outgoing) {
    if (c.originId !== s.id) continue;
    for (const u of UNIT_IDS) away[u] += c.units[u];
  }
  const total = zeroUnits();
  for (const u of UNIT_IDS) total[u] = s.units[u] + away[u];

  const full = s.levels.commandcenter >= 2;
  // The units, grouped by the building that trains them.
  const groups = (['barracks', 'factory', 'airbase', 'bunker'] as BuildingId[])
    .map((b) => ({ building: b, units: UNIT_IDS.filter((u) => UNITS[u].trainedAt === b) }))
    .filter((g) => g.units.length > 0);

  return (
    <section className="hall-page">
      <header className="hall-head">
        <BuildingIcon id="commandcenter" size={52} />
        <div className="hall-title">
          <BackButton name={name} onBack={onBack} />
          <h1>{t('building.commandcenter.name')}</h1>
          <span className="muted small">{t('building.commandcenter.desc')}</span>
        </div>
      </header>

      <table className="command-table">
          <thead>
            <tr>
              <th />
              <th>{t('command.role')}</th>
              <th className="num">{t('command.attack')}</th>
              <th className="num">{t('command.defense')}</th>
              <th className="num">{full ? t('command.homeTotal') : t('command.home')}</th>
            </tr>
          </thead>
          <tbody>
            {groups.map((g) => (
              <Fragment key={g.building}>
                <tr className="command-group">
                  <td colSpan={5}>
                    <span className="command-unit">
                      <BuildingIcon id={g.building} size={22} />
                      {buildingName(g.building)}
                    </span>
                  </td>
                </tr>
                {g.units.map((u) => (
                  <tr key={u}>
                    <td>
                      <span className="command-unit command-indent">
                        <UnitIcon unit={u} size={24} />
                        {t(`unit.${u}.name` as TextKey)}
                      </span>
                    </td>
                    <td>
                      <span className="command-role" title={t(`command.role.${roleOf(u)}` as TextKey)}>
                        {(() => {
                          const Icon = ROLE_ICON[roleOf(u)];
                          return <Icon />;
                        })()}
                        <span className="small">{t(`command.role.${roleOf(u)}` as TextKey)}</span>
                      </span>
                    </td>
                    <td className="num mono">{UNITS[u].attack > 0 ? fmtInt(UNITS[u].attack) : '—'}</td>
                    <td className="num mono">{UNITS[u].defense > 0 ? fmtInt(UNITS[u].defense) : '—'}</td>
                    <td className="num mono">
                      {fmtInt(s.units[u])}
                      {full && <span className="muted"> / {fmtInt(total[u])}</span>}
                    </td>
                  </tr>
                ))}
              </Fragment>
            ))}
            <tr className="command-sum">
              <td>{t('command.sum')}</td>
              <td />
              <td />
              <td />
              <td className="num mono">
                {fmtInt(UNIT_IDS.reduce((n, u) => n + s.units[u], 0))}
                {full && <span className="muted"> / {fmtInt(UNIT_IDS.reduce((n, u) => n + total[u], 0))}</span>}
              </td>
            </tr>
          </tbody>
        </table>
      {!full && <p className="muted small">{t('command.needLevel2')}</p>}
    </section>
  );
}
