import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  FORTIFICATION_BONUS,
  LUCK_RANGE,
  OVERSEAS_SPEED_FACTOR,
  UNITS,
  airUnits,
  groundUnits,
  levelsBombed,
  researchTimeSec,
  distanceKm,
  luckFromSeed,
  normalizeUnits,
  resolveBattle,
  slowestSpeed,
  subtractUnits,
  trainTimeSec,
  travelTimeMs,
  troopPop,
  unitTotal,
  zeroUnits,
} from './index';

const army = (o: Partial<ReturnType<typeof zeroUnits>>) => ({ ...zeroUnits(), ...o });

test('unit helpers', () => {
  assert.deepEqual(normalizeUnits({ rifleman: 3.9, tank: -2, ghost: 7 }), { rifleman: 3, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0 });
  assert.equal(unitTotal(army({ rifleman: 2, tank: 3 })), 5);
  assert.equal(troopPop(army({ rifleman: 2, tank: 3 })), 2 + 12);
  assert.deepEqual(subtractUnits(army({ rifleman: 5 }), army({ rifleman: 9 })), zeroUnits());
  assert.equal(slowestSpeed(army({ tank: 4 })), UNITS.tank.speedKmh);
  assert.equal(slowestSpeed(army({ tank: 4, assault: 1 })), UNITS.assault.speedKmh);
  assert.equal(slowestSpeed(zeroUnits()), 0);
});

test('training gets faster with the building level and the world speed', () => {
  const slow = trainTimeSec(UNITS.rifleman, 10, 1, 1);
  assert.equal(slow, 900);
  assert.ok(trainTimeSec(UNITS.rifleman, 10, 10, 1) < slow);
  assert.equal(trainTimeSec(UNITS.rifleman, 10, 1, 10), 90);
});

test('distance and travel time', () => {
  const bucharest = { lat: 44.43, lng: 26.1 };
  const paris = { lat: 48.86, lng: 2.35 };
  const km = distanceKm(bucharest, paris);
  assert.ok(km > 1750 && km < 1900, `Bucharest-Paris ${km}`);
  assert.equal(distanceKm(paris, paris), 0);
  assert.ok(Math.abs(distanceKm(paris, bucharest) - km) < 1e-9);
  const walk = travelTimeMs(400, army({ assault: 5 }), 1, false);
  assert.equal(walk, 10 * 3_600_000);
  assert.equal(travelTimeMs(400, army({ assault: 5 }), 10, false), 1 * 3_600_000);
  assert.equal(travelTimeMs(400, army({ assault: 5 }), 1, true), Math.round(walk / OVERSEAS_SPEED_FACTOR));
  assert.equal(travelTimeMs(400, army({ assault: 5, tank: 1 }), 1, false), walk, 'the slowest unit sets the pace');
  assert.equal(travelTimeMs(400, zeroUnits(), 1, false), Infinity);
});

test('luck is repeatable and bounded', () => {
  assert.equal(luckFromSeed(42), luckFromSeed(42));
  assert.notEqual(luckFromSeed(42), luckFromSeed(43));
  for (let i = 1; i < 2000; i++) {
    const luck = luckFromSeed(i);
    assert.ok(luck >= -LUCK_RANGE && luck <= LUCK_RANGE, `${i}: ${luck}`);
  }
});

test('attacker wins: defenders wiped out, a narrow win costs more than a crushing one', () => {
  const defenders = army({ rifleman: 10 }); // defence 250
  const narrow = resolveBattle({ attackers: army({ assault: 7 }), defenders, fortificationLevel: 0, luck: 0 }); // attack 280
  assert.equal(narrow.winner, 'attacker');
  assert.deepEqual(narrow.defenderSurvivors, zeroUnits());
  assert.deepEqual(narrow.defenderLosses, defenders);
  const crushing = resolveBattle({ attackers: army({ assault: 70 }), defenders, fortificationLevel: 0, luck: 0 });
  assert.ok(narrow.attackerLosses.assault / 7 > crushing.attackerLosses.assault / 70);
  assert.equal(narrow.attackerSurvivors.assault + narrow.attackerLosses.assault, 7);
});

test('defender wins: attackers wiped out, ties go to the defender', () => {
  const lost = resolveBattle({ attackers: army({ assault: 3 }), defenders: army({ rifleman: 10 }), fortificationLevel: 0, luck: 0 });
  assert.equal(lost.winner, 'defender');
  assert.deepEqual(lost.attackerSurvivors, zeroUnits());
  assert.ok(lost.defenderSurvivors.rifleman > 0 && lost.defenderSurvivors.rifleman <= 10);
  const tie = resolveBattle({ attackers: army({ assault: 25 }), defenders: army({ rifleman: 40 }), fortificationLevel: 0, luck: 0 }); // 1000 vs 1000
  assert.equal(tie.winner, 'defender');
});

test('fortifications and luck move the result', () => {
  const attackers = army({ assault: 7 });
  const defenders = army({ rifleman: 10 });
  assert.equal(resolveBattle({ attackers, defenders, fortificationLevel: 0, luck: 0 }).winner, 'attacker');
  assert.equal(resolveBattle({ attackers, defenders, fortificationLevel: 5, luck: 0 }).winner, 'defender');
  assert.ok(Math.abs(resolveBattle({ attackers, defenders, fortificationLevel: 3, luck: 0 }).defensePower - 250 * FORTIFICATION_BONUS ** 3) < 1e-9);
  assert.equal(resolveBattle({ attackers, defenders, fortificationLevel: 0, luck: -LUCK_RANGE }).winner, 'defender');
});

test('empty sides', () => {
  const noDefenders = resolveBattle({ attackers: army({ assault: 1 }), defenders: zeroUnits(), fortificationLevel: 0, luck: 0 });
  assert.equal(noDefenders.winner, 'attacker');
  assert.deepEqual(noDefenders.attackerLosses, zeroUnits());
  const noAttackers = resolveBattle({ attackers: zeroUnits(), defenders: army({ rifleman: 2 }), fortificationLevel: 0, luck: 0 });
  assert.equal(noAttackers.winner, 'defender');
  assert.deepEqual(noAttackers.defenderLosses, zeroUnits());
});

test('air units: spies are fast, bombers slow, both stay out of ground battles', () => {
  assert.ok(UNITS.spy.speedKmh > UNITS.tank.speedKmh * 3);
  assert.ok(UNITS.bomber.speedKmh < UNITS.rifleman.speedKmh);
  assert.equal(UNITS.spy.trainedAt, 'airbase');
  assert.equal(UNITS.bomber.trainedAt, 'airbase');
  const mixed = { rifleman: 2, assault: 5, spy: 3, bomber: 4, president: 0 };
  assert.deepEqual(airUnits(mixed), { rifleman: 0, assault: 0, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 3, bomber: 4, president: 0 });
  assert.deepEqual(groundUnits(mixed), { rifleman: 2, assault: 5, veteran: 0, guardian: 0, tank: 0, drone: 0, spy: 0, bomber: 0, president: 0 });
  // an army with a bomber moves at the bomber's pace
  assert.equal(slowestSpeed({ spy: 5, bomber: 1, tank: 2 }), UNITS.bomber.speedKmh);
  assert.equal(slowestSpeed({ spy: 5 }), UNITS.spy.speedKmh);
});

test('bombing: at least one level, one more per five bombers', () => {
  assert.equal(levelsBombed(0), 0);
  assert.equal(levelsBombed(1), 1);
  assert.equal(levelsBombed(5), 1);
  assert.equal(levelsBombed(10), 2);
  assert.equal(levelsBombed(23), 4);
});

test('every unit needs a research, and it gets faster with the Research Center', () => {
  for (const def of Object.values(UNITS)) {
    assert.ok(def.research.level >= 1 && def.research.baseTime > 0, def.id);
  }
  assert.ok(researchTimeSec(UNITS.tank, 10, 1) < researchTimeSec(UNITS.tank, 5, 1));
  assert.equal(researchTimeSec(UNITS.tank, 1, 2), Math.round(UNITS.tank.research.baseTime / 2));
});

test('the President comes from the Bunker at level 10 and fights with nothing', () => {
  assert.equal(UNITS.president.trainedAt, 'bunker');
  assert.deepEqual(UNITS.president.requires, { bunker: 10 });
  assert.equal(UNITS.president.attack + UNITS.president.defense, 0);
  assert.equal(UNITS.president.air, false);
});
