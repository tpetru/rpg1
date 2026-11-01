import type { BuildingId, BuildingLevels } from './buildings';
import type { ResourceBag } from './resources';

export const UNIT_IDS = ['rifleman', 'assault', 'veteran', 'guardian', 'tank', 'drone', 'spy', 'bomber', 'president'] as const;
export type UnitId = (typeof UNIT_IDS)[number];
export type UnitCounts = Record<UnitId, number>;

export interface UnitDef {
  id: UnitId;
  name: string;
  description: string;
  cost: ResourceBag;
  /** Population one unit takes in its home settlement, wherever it is. */
  pop: number;
  attack: number;
  defense: number;
  /** Kilometres per hour at world speed 1. */
  speedKmh: number;
  /** Resources one unit can carry home. Reserved for raiding; conquest does not use it yet. */
  carry: number;
  /** Seconds to train one unit at world speed 1 and level 1 of its building. */
  baseTime: number;
  /** Building that trains it, and the levels needed before it can be trained. */
  trainedAt: BuildingId;
  requires: Partial<BuildingLevels>;
  /** Air units do not fight on the ground: they are pulled out of the battle and fly home afterwards. */
  air: boolean;
  /** Never leaves home: it only defends the settlement it is trained in. */
  homeOnly?: boolean;
  /** Every unit has to be researched in a settlement's Research Center before it can be trained there. */
  research: { level: number; cost: ResourceBag; baseTime: number };
}

export const UNITS: Record<UnitId, UnitDef> = {
  rifleman: {
    id: 'rifleman',
    name: 'Recruit',
    description: 'Cheap defender. Holds a settlement well and attacks poorly.',
    cost: { food: 50, steel: 30, oil: 10 },
    pop: 1,
    attack: 10,
    defense: 25,
    speedKmh: 40,
    carry: 10,
    baseTime: 90,
    trainedAt: 'barracks',
    requires: { barracks: 1 },
    air: false,
    research: { level: 1, cost: { food: 100, steel: 80, oil: 60 }, baseTime: 300 },
  },
  assault: {
    id: 'assault',
    name: 'Commando',
    description: 'The basic attacker: strong on offence, weak on defence.',
    cost: { food: 60, steel: 30, oil: 40 },
    pop: 1,
    attack: 40,
    defense: 10,
    speedKmh: 40,
    carry: 25,
    baseTime: 120,
    trainedAt: 'barracks',
    requires: { barracks: 1 },
    air: false,
    research: { level: 2, cost: { food: 150, steel: 120, oil: 100 }, baseTime: 600 },
  },
  veteran: {
    id: 'veteran',
    name: 'Assault Veteran',
    description: 'Elite attacker: much stronger on offence than the Commando, and tougher. Needs a high-level Barracks.',
    cost: { food: 110, steel: 60, oil: 70 },
    pop: 2,
    attack: 85,
    defense: 20,
    speedKmh: 45,
    carry: 40,
    baseTime: 240,
    trainedAt: 'barracks',
    requires: { barracks: 5 },
    air: false,
    research: { level: 6, cost: { food: 300, steel: 240, oil: 220 }, baseTime: 1500 },
  },
  guardian: {
    id: 'guardian',
    name: 'Guardian',
    description: 'Elite defender: more than twice the defence of the Recruit. Needs a high-level Barracks.',
    cost: { food: 100, steel: 70, oil: 30 },
    pop: 2,
    attack: 15,
    defense: 55,
    speedKmh: 40,
    carry: 15,
    baseTime: 200,
    trainedAt: 'barracks',
    requires: { barracks: 5 },
    air: false,
    research: { level: 4, cost: { food: 240, steel: 200, oil: 140 }, baseTime: 1200 },
  },
  tank: {
    id: 'tank',
    name: 'Tank',
    description: 'Fast and hard-hitting. Tanks that survive a won battle tear down the Fortifications for good. Needs a Factory.',
    cost: { food: 130, steel: 120, oil: 150 },
    pop: 4,
    attack: 130,
    defense: 30,
    speedKmh: 90,
    carry: 80,
    baseTime: 360,
    trainedAt: 'factory',
    requires: { factory: 1 },
    air: false,
    research: { level: 5, cost: { food: 400, steel: 350, oil: 400 }, baseTime: 1800 },
  },
  drone: {
    id: 'drone',
    name: 'Defence Drone',
    description: 'Stays at home and shoots down bombers: every 2 drones stop 1 bomber before it drops anything.',
    cost: { food: 90, steel: 110, oil: 80 },
    pop: 2,
    attack: 0,
    defense: 0,
    speedKmh: 120,
    carry: 0,
    baseTime: 300,
    trainedAt: 'factory',
    requires: { factory: 3 },
    air: false,
    homeOnly: true,
    research: { level: 7, cost: { food: 350, steel: 400, oil: 300 }, baseTime: 1800 },
  },
  spy: {
    id: 'spy',
    name: 'Spy',
    description: 'Sent with an attack, it reports the buildings of the town. Extremely fast; flies home afterwards.',
    cost: { food: 40, steel: 20, oil: 60 },
    pop: 1,
    attack: 0,
    defense: 0,
    speedKmh: 400,
    carry: 0,
    baseTime: 120,
    trainedAt: 'airbase',
    requires: { airbase: 1 },
    air: true,
    research: { level: 10, cost: { food: 250, steel: 150, oil: 300 }, baseTime: 1200 },
  },
  bomber: {
    id: 'bomber',
    name: 'Bomber',
    description: 'Destroys levels of a building in the attacked town. Slow; flies home afterwards.',
    cost: { food: 120, steel: 150, oil: 200 },
    pop: 3,
    attack: 0,
    defense: 0,
    speedKmh: 25,
    carry: 0,
    baseTime: 420,
    trainedAt: 'airbase',
    requires: { airbase: 3 },
    air: true,
    research: { level: 12, cost: { food: 500, steel: 450, oil: 600 }, baseTime: 3000 },
  },
  president: {
    id: 'president',
    name: 'President',
    description: 'No abandoned settlement can be conquered without one. Never falls in a battle that is won; stays to govern the conquered settlement.',
    cost: { food: 1000, steel: 800, oil: 800 },
    pop: 10,
    attack: 0,
    defense: 0,
    speedKmh: 50,
    carry: 0,
    baseTime: 3600,
    trainedAt: 'bunker',
    requires: { bunker: 10 },
    air: false,
    research: { level: 8, cost: { food: 800, steel: 700, oil: 700 }, baseTime: 2400 },
  },
};

/** Defence Drones needed to stop one bomber. */
export const DRONES_PER_BOMBER = 2;

/** An army that goes against an abandoned settlement needs at least one of these to take it. */
export const CONQUEST_UNIT: UnitId = 'president';

export function zeroUnits(): UnitCounts {
  return { rifleman: 0, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0 };
}

/** Fills in missing units from stored data and drops unknown ones. */
export function normalizeUnits(partial: Readonly<Record<string, number | undefined>>): UnitCounts {
  const units = zeroUnits();
  for (const id of UNIT_IDS) units[id] = Math.max(0, Math.floor(partial[id] ?? 0));
  return units;
}

export function unitTotal(units: Partial<UnitCounts>): number {
  return UNIT_IDS.reduce((sum, id) => sum + (units[id] ?? 0), 0);
}

export function troopPop(units: Partial<UnitCounts>): number {
  return UNIT_IDS.reduce((sum, id) => sum + (units[id] ?? 0) * UNITS[id].pop, 0);
}

export function addUnits(a: Partial<UnitCounts>, b: Partial<UnitCounts>): UnitCounts {
  const out = zeroUnits();
  for (const id of UNIT_IDS) out[id] = (a[id] ?? 0) + (b[id] ?? 0);
  return out;
}

export function subtractUnits(a: Partial<UnitCounts>, b: Partial<UnitCounts>): UnitCounts {
  const out = zeroUnits();
  for (const id of UNIT_IDS) out[id] = Math.max(0, (a[id] ?? 0) - (b[id] ?? 0));
  return out;
}

/** Seconds to train `count` units; each level of the training building is about 6% faster. */
export function trainTimeSec(def: UnitDef, count: number, buildingLevel: number, worldSpeed: number): number {
  const perUnit = (def.baseTime * 0.94 ** (Math.max(1, buildingLevel) - 1)) / worldSpeed;
  return Math.max(1, Math.round(perUnit * count));
}

export function unitCost(def: UnitDef, count: number): ResourceBag {
  return { food: def.cost.food * count, steel: def.cost.steel * count, oil: def.cost.oil * count };
}

/** An army moves at the pace of its slowest unit. */
export function slowestSpeed(units: Partial<UnitCounts>): number {
  const speeds = UNIT_IDS.filter((id) => (units[id] ?? 0) > 0).map((id) => UNITS[id].speedKmh);
  return speeds.length > 0 ? Math.min(...speeds) : 0;
}

/** Seconds to research a unit; each level of the Research Center is about 6% faster. */
export function researchTimeSec(def: UnitDef, centerLevel: number, worldSpeed: number): number {
  return Math.max(1, Math.round((def.research.baseTime * 0.94 ** (Math.max(1, centerLevel) - 1)) / worldSpeed));
}

/** Bombers needed to destroy one level of a building; any bomber destroys at least one. */
export const BOMBERS_PER_LEVEL = 5;

export function levelsBombed(bombers: number): number {
  return bombers <= 0 ? 0 : Math.max(1, Math.floor(bombers / BOMBERS_PER_LEVEL));
}

/** Tanks that survive a won battle bring the target's Fortifications down by one level for every this many. */
export const TANKS_PER_WALL_LEVEL = 5;

export function wallLevelsDemolished(tanks: number): number {
  return tanks <= 0 ? 0 : Math.max(1, Math.floor(tanks / TANKS_PER_WALL_LEVEL));
}

/** Units that take part in a ground battle (everything but the air units). */
export function groundUnits(units: Partial<UnitCounts>): UnitCounts {
  const out = zeroUnits();
  for (const id of UNIT_IDS) if (!UNITS[id].air) out[id] = units[id] ?? 0;
  return out;
}

export function airUnits(units: Partial<UnitCounts>): UnitCounts {
  const out = zeroUnits();
  for (const id of UNIT_IDS) if (UNITS[id].air) out[id] = units[id] ?? 0;
  return out;
}
