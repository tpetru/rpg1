import { createRoot } from 'react-dom/client';
import { latLngToCell } from 'h3-js';
import type { BattleReportData, CountryRef, HexRow, OwnSettlementDto, ReportDto, UnitCounts } from '@geowars/rules';
import { ReportsView } from './components/ReportsView';
import { I18nProvider } from './i18n';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the battle reports and their dialog, so the clash bars, emblems and the
// power scale can be reviewed without a database. One report per outcome, plus a defender copy.

const COUNTRIES: Record<string, CountryRef> = {
  RO: { name: 'Romania', a2: 'RO', continent: 'Europe' },
  HU: { name: 'Hungary', a2: 'HU', continent: 'Europe' },
  BG: { name: 'Bulgaria', a2: 'BG', continent: 'Europe' },
};

const PLACES: [number, number, string, string][] = [
  [46.77, 23.59, 'RO', 'Cluj'],
  [45.94, 24.97, 'RO', 'Brasov'],
  [44.43, 26.1, 'RO', 'Bucuresti'],
  [47.16, 27.58, 'RO', 'Iasi'],
  [45.75, 21.23, 'RO', 'Timisoara'],
  [43.98, 15.43, 'HU', 'Szekesfehervar'],
  [42.14, 24.74, 'BG', 'Plovdiv'],
];

const HEXES: HexRow[] = PLACES.map(([lat, lng, country, name]) => [
  latLngToCell(lat, lng, 3),
  country,
  name,
  1,
  1,
  1,
  0,
  0,
  null,
]);

const MINE = [{ id: 1, idx: 0, customName: 'Pitanga' }] as unknown as OwnSettlementDto[];

const u = (p: Partial<UnitCounts>): UnitCounts => ({ rifleman: 0, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0, ...p });

const HOUR = 3_600_000;
const now = Date.now();

const battle = (over: Partial<BattleReportData>): BattleReportData => ({
  outcome: 'victory',
  originId: 1,
  originIdx: 0,
  targetId: 2,
  targetIdx: 1,
  attackers: u({}),
  attackerLosses: u({}),
  defenders: u({}),
  defenderLosses: u({}),
  attackPower: 0,
  defensePower: 0,
  luck: 0.5,
  fortificationLevel: 0,
  ...over,
});

const REPORTS: ReportDto[] = [
  {
    id: 1,
    createdAt: now - HOUR,
    read: false,
    type: 'battle',
    data: battle({
      outcome: 'conquered',
      targetId: 3,
      targetIdx: 2,
      attackers: u({ rifleman: 500, assault: 220, veteran: 40, tank: 24, spy: 2, president: 1 }),
      attackerLosses: u({ rifleman: 130, assault: 60, veteran: 5, tank: 3 }),
      defenders: u({ rifleman: 380, guardian: 30, tank: 10, drone: 6 }),
      defenderLosses: u({ rifleman: 380, guardian: 12, tank: 10 }),
      attackPower: 4120,
      defensePower: 2680,
      luck: 0.62,
      fortificationLevel: 4,
      defenderName: 'Nyx',
    }),
  },
  {
    id: 2,
    createdAt: now - 2 * HOUR,
    read: false,
    type: 'battle',
    data: battle({
      outcome: 'victory',
      attackers: u({ rifleman: 400, assault: 80 }),
      attackerLosses: u({ rifleman: 210, assault: 40 }),
      defenders: u({ rifleman: 350 }),
      defenderLosses: u({ rifleman: 350 }),
      attackPower: 2400,
      defensePower: 2100,
      luck: 0.55,
      fortificationLevel: 6,
      defenderName: 'Nyx',
    }),
  },
  {
    id: 3,
    createdAt: now - 26 * HOUR,
    read: true,
    type: 'battle',
    data: battle({
      outcome: 'defeat',
      targetId: 4,
      targetIdx: 3,
      attackers: u({ rifleman: 300, tank: 12 }),
      attackerLosses: u({ rifleman: 300, tank: 12 }),
      defenders: u({ rifleman: 520, assault: 90 }),
      defenderLosses: u({ rifleman: 90, assault: 15 }),
      attackPower: 1900,
      defensePower: 3400,
      luck: 0.4,
      fortificationLevel: 8,
      defenderName: 'Thrax',
    }),
  },
  {
    id: 4,
    createdAt: now - 30 * HOUR,
    read: true,
    type: 'battle',
    data: battle({
      outcome: 'air',
      targetId: 5,
      targetIdx: 4,
      attackers: u({ bomber: 28 }),
      attackerLosses: u({ bomber: 4 }),
      defenders: u({ rifleman: 60 }),
      defenderLosses: u({}),
      attackPower: 640,
      defensePower: 420,
      luck: 0.5,
      defenderName: 'Nyx',
      bombed: { building: 'factory', from: 6, to: 3 },
    }),
  },
  {
    id: 5,
    createdAt: now - 47 * HOUR,
    read: true,
    type: 'battle',
    data: battle({
      outcome: 'victory',
      attackers: u({ spy: 2 }),
      defenders: u({}),
      attackPower: 8,
      defensePower: 0,
      luck: 0.5,
      defenderName: 'Thrax',
      intel: { cityhall: 7, market: 5, barracks: 4, fortifications: 6, factory: 3, steelmill: 2 } as BattleReportData['intel'],
    }),
  },
  {
    id: 6,
    createdAt: now - 50 * HOUR,
    read: true,
    type: 'battle',
    data: battle({ outcome: 'fizzled', targetId: 6, targetIdx: 5, attackers: u({ rifleman: 250 }), attackPower: 900 }),
  },
  {
    id: 8,
    createdAt: now - 55 * HOUR,
    read: true,
    type: 'battle',
    data: battle({
      outcome: 'victory',
      targetId: 6,
      targetIdx: 5,
      // A row written before Veteran, Guardian and Drone existed: keys missing on purpose,
      // so the dialog proves it normalises old data without a single NaN.
      attackers: { rifleman: 320, assault: 60, tank: 8, spy: 2 } as unknown as UnitCounts,
      attackerLosses: { rifleman: 100 } as unknown as UnitCounts,
      defenders: { rifleman: 280 } as unknown as UnitCounts,
      defenderLosses: { rifleman: 280 } as unknown as UnitCounts,
      attackPower: 2900,
      defensePower: 2400,
      luck: 0.58,
      fortificationLevel: 3,
      defenderName: 'Thrax',
    }),
  },
  {
    id: 7,
    createdAt: now - 52 * HOUR,
    read: false,
    type: 'battle',
    data: battle({
      outcome: 'defeat',
      asDefender: true,
      originId: 2,
      originIdx: 1,
      targetId: 1,
      targetIdx: 0,
      attackers: u({ rifleman: 420, tank: 18 }),
      attackerLosses: u({ rifleman: 420, tank: 18 }),
      defenders: u({ rifleman: 260, assault: 40 }),
      defenderLosses: u({ rifleman: 70 }),
      attackPower: 2600,
      defensePower: 3100,
      luck: 0.48,
      fortificationLevel: 9,
      attackerName: 'Nyx',
    }),
  },
];

try {
  if (!localStorage.getItem('gw.theme')) localStorage.setItem('gw.theme', 'light');
} catch {
  // storage unavailable
}

createRoot(document.getElementById('root')!).render(
  <ThemeProvider>
    <I18nProvider>
      <div className="reports-preview">
        <ReportsView
          nation="Dacia"
          mine={MINE}
          reports={REPORTS}
          hexes={HEXES}
          countries={COUNTRIES}
          onMarkRead={() => undefined}
          onMarkAllRead={() => undefined}
          onShow={() => undefined}
        />
      </div>
    </I18nProvider>
  </ThemeProvider>,
);
