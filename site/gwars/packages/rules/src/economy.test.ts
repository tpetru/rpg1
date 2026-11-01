import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BUILDINGS,
  DEFAULT_WORLD_SETTINGS,
  BUILDING_IDS,
  STARTING_LEVELS,
  normalizeLevels,
  checkBuild,
  checkDowngrade,
  plannedLevels,
  housingCapacity,
  levelCost,
  materialize,
  populationUsed,
  productionPerHour,
  warehouseCapacity,
} from './index';

const rich = { food: 1e6, steel: 1e6, oil: 1e6 };

test('production curve matches Tribal Wars scale', () => {
  assert.equal(productionPerHour(0, 1, 1), 5);
  assert.equal(productionPerHour(1, 1, 1), 30);
  assert.ok(Math.abs(productionPerHour(30, 1, 1) - 2400) < 50);
  assert.equal(productionPerHour(1, 2, 3), 180);
});

test('storage and housing curves', () => {
  assert.equal(warehouseCapacity(1), 1000);
  assert.ok(Math.abs(warehouseCapacity(30) - 400_000) < 1000);
  assert.equal(housingCapacity(1), 240);
  assert.ok(Math.abs(housingCapacity(30) - 24_000) < 100);
});

test('starting settlement fits in its housing', () => {
  assert.ok(populationUsed(STARTING_LEVELS) <= housingCapacity(STARTING_LEVELS.housing));
});

test('materialize grows linearly and respects the cap', () => {
  const rates = { food: 100, steel: 50, oil: 0 };
  const out = materialize({ food: 0, steel: 990, oil: 1200 }, rates, 1000, 0, 3_600_000);
  assert.deepEqual(out, { food: 100, steel: 1000, oil: 1200 });
  assert.deepEqual(materialize({ food: 5, steel: 5, oil: 5 }, rates, 1000, 10, 0), { food: 5, steel: 5, oil: 5 });
});

test('checkBuild enforces requirements, queue slots and cost', () => {
  const base = { levels: { ...STARTING_LEVELS }, queue: [], stock: rich };

  const barracks = checkBuild(base, 'barracks', DEFAULT_WORLD_SETTINGS);
  assert.equal(barracks.ok, false);
  assert.equal(!barracks.ok && barracks.reason, 'Requires City Hall level 3');
  assert.deepEqual(!barracks.ok && [barracks.code, barracks.params], ['requires', { building: 'cityhall', level: 3 }]);

  const farm = checkBuild(base, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.ok(farm.ok);
  assert.equal(farm.targetLevel, 2);
  assert.deepEqual(farm.cost, levelCost(BUILDINGS.farm, 2));

  const queued = checkBuild({ ...base, queue: [{ building: 'farm' }] }, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.ok(queued.ok && queued.targetLevel === 3);

  const full = checkBuild({ ...base, queue: [{ building: 'farm' }, { building: 'oilfield' }] }, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.equal(!full.ok && full.reason, 'Build queue is full');

  const poor = checkBuild({ ...base, stock: { food: 0, steel: 0, oil: 0 } }, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.equal(!poor.ok && poor.reason, 'Not enough resources');
});

test('checkBuild blocks levels that do not fit in the warehouse', () => {
  const levels = { ...STARTING_LEVELS, cityhall: 25 };
  const check = checkBuild({ levels, queue: [], stock: rich }, 'cityhall', DEFAULT_WORLD_SETTINGS);
  assert.equal(!check.ok && check.reason, 'Warehouse too small');
});

test('Parliament is not part of the game', () => {
  assert.equal(BUILDING_IDS.length, 16);
  for (const gone of ['parliament', 'hospital']) {
    assert.ok(!(BUILDING_IDS as readonly string[]).includes(gone), gone);
    assert.ok(!(gone in BUILDINGS), gone);
  }
});

test('stored data of a removed building is dropped when read', () => {
  const levels = normalizeLevels({ cityhall: 3, parliament: 1, hospital: 1, nonsense: 9 });
  assert.equal(levels.cityhall, 3);
  assert.deepEqual(Object.keys(levels).sort(), [...BUILDING_IDS].sort());
});

test('each speed setting affects only its own thing', () => {
  const base = { levels: { ...STARTING_LEVELS }, queue: [], stock: rich };
  const slow = checkBuild(base, 'farm', DEFAULT_WORLD_SETTINGS);
  const fast = checkBuild(base, 'farm', { ...DEFAULT_WORLD_SETTINGS, constructionSpeed: 4 });
  const prodOnly = checkBuild(base, 'farm', { ...DEFAULT_WORLD_SETTINGS, speed: 4, recruitSpeed: 4, warSpeed: 4 });
  assert.ok(slow.timeSec && fast.timeSec && prodOnly.timeSec);
  assert.ok(Math.abs(fast.timeSec * 4 - slow.timeSec) <= 4);
  assert.equal(prodOnly.timeSec, slow.timeSec);
  assert.equal(DEFAULT_WORLD_SETTINGS.constructionSpeed, 1);
});

test('downgrades: a level at a time, free, with limits', () => {
  const levels = { ...STARTING_LEVELS, cityhall: 5, barracks: 2, housing: 3, farm: 4 };
  const base = { levels, queue: [], stock: rich };
  const farm = checkDowngrade(base, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.ok(farm.ok && farm.targetLevel === 3 && farm.timeSec > 0);
  // half the time of building that level
  const up = checkBuild({ ...base, levels: { ...levels, farm: 3 } }, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.ok(up.ok && farm.ok && Math.abs(farm.timeSec * 2 - up.timeSec) <= 2);
  // the fixed ones keep level 1, the others can go to 0
  const hall = checkDowngrade({ levels: { ...STARTING_LEVELS }, queue: [], stock: rich }, 'cityhall', DEFAULT_WORLD_SETTINGS);
  assert.ok(!hall.ok && hall.code === 'min_level');
  assert.ok(checkDowngrade({ levels: { ...STARTING_LEVELS, bunker: 1 }, queue: [], stock: rich }, 'bunker', DEFAULT_WORLD_SETTINGS).ok);
  // barracks (needs City Hall 3) stops City Hall from falling below 3
  const low = checkDowngrade({ ...base, levels: { ...levels, cityhall: 3 } }, 'cityhall', DEFAULT_WORLD_SETTINGS);
  assert.ok(!low.ok && low.code === 'required' && low.params?.building === 'barracks');
  assert.ok(checkDowngrade(base, 'cityhall', DEFAULT_WORLD_SETTINGS).ok);
  // the queue is shared
  const full = checkDowngrade({ ...base, queue: [{ building: 'farm' }, { building: 'farm' }] }, 'steelmill', DEFAULT_WORLD_SETTINGS);
  assert.ok(!full.ok && full.code === 'queue_full');
  // housing cannot fall below what is in use
  const crowded = { levels: { ...STARTING_LEVELS, housing: 2, farm: 30 }, queue: [], stock: rich, troopPop: 0 };
  const h = checkDowngrade(crowded, 'housing', DEFAULT_WORLD_SETTINGS);
  assert.ok(!h.ok && h.code === 'housing');
});

test('the queue can hold downgrades, and later checks see the planned levels', () => {
  const levels = { ...STARTING_LEVELS, farm: 4 };
  const planned = plannedLevels(levels, [{ building: 'farm', targetLevel: 3 }, { building: 'farm', targetLevel: 2 }, { building: 'steelmill' }]);
  assert.equal(planned.farm, 2);
  assert.equal(planned.steelmill, 2);
  // a second downgrade queued behind the first goes to the level after it
  const next = checkDowngrade({ levels, queue: [{ building: 'farm', targetLevel: 3 }], stock: rich }, 'farm', DEFAULT_WORLD_SETTINGS);
  assert.ok(next.ok && next.targetLevel === 2);
  // a requirement that a queued downgrade is about to break no longer counts
  const state = { levels: { ...STARTING_LEVELS, cityhall: 3 }, queue: [{ building: 'cityhall' as const, targetLevel: 2 }], stock: rich };
  const barracks = checkBuild(state, 'barracks', DEFAULT_WORLD_SETTINGS);
  assert.ok(!barracks.ok && barracks.code === 'requires');
});

test('a Port can only be built on the coast', () => {
  const levels = { ...STARTING_LEVELS, cityhall: 10, warehouse: 10 };
  const inland = checkBuild({ levels, queue: [], stock: rich, coastal: false }, 'port', DEFAULT_WORLD_SETTINGS);
  assert.ok(!inland.ok && inland.code === 'coastal');
  const coast = checkBuild({ levels, queue: [], stock: rich, coastal: true }, 'port', DEFAULT_WORLD_SETTINGS);
  assert.ok(coast.ok || coast.code !== 'coastal');
});
