import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BUILDINGS,
  DEFAULT_WORLD_SETTINGS,
  STARTING_LEVELS,
  checkBuild,
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
