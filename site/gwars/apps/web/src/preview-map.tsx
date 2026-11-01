import { createRoot } from 'react-dom/client';
import { latLngToCell } from 'h3-js';
import type { CommandDto, CountryRef, HexRow, IncomingCommandDto } from '@geowars/rules';
import { MapControls } from './components/MapControls';
import { MapView, type HexOwner } from './components/MapView';
import { AxeIcon, BinocularsIcon } from './art/actionIcons';
import { I18nProvider, useI18n } from './i18n';
import { MAX_SETTLEMENT_POINTS } from './art/mapMarkers';
import { ThemeProvider } from './theme';
import './styles.css';

// Dev-only preview of the world map with synthetic settlements, so the four marker sizes can be
// reviewed without a database. Towns stand on a ring around Romania at 5%, 30%, 65% and 92% of
// the largest possible settlement, plus one held by another nation and one independent.

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

const pct = (p: number) => Math.round(MAX_SETTLEMENT_POINTS * p);

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

const OWNERS = new Map<number, HexOwner>([
  [0, { settlementId: 1, ownerId: 1, points: pct(0.92) }], // my capital
  [1, { settlementId: 2, ownerId: 1, points: pct(0.65) }],
  [2, { settlementId: 3, ownerId: 1, points: pct(0.3) }],
  [3, { settlementId: 4, ownerId: 1, points: pct(0.05) }],
  [4, { settlementId: 5, ownerId: 2, points: pct(0.5) }], // another nation's town
  [5, { settlementId: 6, ownerId: 2, points: pct(0.08) }],
  [6, { settlementId: 7, ownerId: 0, points: pct(0.2) }], // independent
]);

const NO_UNITS = { rifleman: 0, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0 };

/** My army off to conquer the independent town, and one heading home. */
const COMMANDS: CommandDto[] = [
  { id: 1, type: 'attack', originId: 1, originIdx: 0, targetId: 7, targetIdx: 6, units: NO_UNITS, sentAt: Date.now() - 600_000, arrivesAt: Date.now() + 1_800_000 },
  { id: 2, type: 'return', originId: 3, originIdx: 2, targetId: 2, targetIdx: 1, units: NO_UNITS, sentAt: Date.now() - 200_000, arrivesAt: Date.now() + 900_000 },
];

/** A rival's army marching on my village. */
const INCOMING: IncomingCommandDto[] = [
  { id: 3, type: 'attack', originId: 5, originIdx: 4, targetId: 3, targetIdx: 2, units: NO_UNITS, sentAt: Date.now() - 300_000, arrivesAt: Date.now() + 2_400_000, attackerName: 'Nyx', unitsHidden: false, timeHidden: false },
];

function Shell() {
  const { t } = useI18n();
  return (
    <div className="game">
      <MapView
        hexes={HEXES}
        countries={COUNTRIES}
        owners={OWNERS}
        players={{ 1: 'Dacia', 2: 'Nyx' }}
        mode="owners"
        myId={1}
        selected={0}
        focus={{ idx: 0, seq: 1 }}
        onSelect={() => undefined}
        commands={COMMANDS}
        incoming={INCOMING}
        actions={(idx) => {
          if (!OWNERS.has(idx)) return [];
          return [
            { id: 'visit', label: t('map.actionVisit'), tone: 'neutral' as const, icon: <BinocularsIcon />, onClick: () => undefined },
            // The independent town shows the blunted (disabled) axe state.
            { id: 'attack', label: t('map.actionAttack'), tone: 'danger' as const, icon: <AxeIcon />, disabled: idx === 6, onClick: () => undefined },
          ];
        }}
      >
        <MapControls
          mode="owners"
          onMode={() => undefined}
          hexes={HEXES}
          countries={COUNTRIES}
          owners={OWNERS}
          players={{ 1: 'Dacia', 2: 'Nyx' }}
          customNames={[{ idx: 0, name: 'Pitanga' }]}
          onPick={() => undefined}
        />
      </MapView>
    </div>
  );
}

try {
  if (!localStorage.getItem('gw.theme')) localStorage.setItem('gw.theme', 'light');
} catch {
  // storage unavailable
}

createRoot(document.getElementById('root')!).render(
  <ThemeProvider>
    <I18nProvider>
      <Shell />
    </I18nProvider>
  </ThemeProvider>,
);
