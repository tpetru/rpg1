import { UNITS, UNIT_IDS, unitTotal, zeroUnits, type UnitCounts } from './units';

/** Each level of Fortifications multiplies the defence of everything stationed there. */
export const FORTIFICATION_BONUS = 1.05;
/** The attacker's strength is multiplied by 1 + luck, with luck between -0.25 and +0.25. */
export const LUCK_RANGE = 0.25;

/** Repeatable luck for one battle: the same seed (the command id) always gives the same value. */
export function luckFromSeed(seed: number): number {
  let a = Math.imul(seed, 2654435761) >>> 0;
  a = (a + 0x6d2b79f5) >>> 0;
  let t = a;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  const unit = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  return (unit - 0.5) * 2 * LUCK_RANGE;
}

export interface BattleInput {
  attackers: UnitCounts;
  defenders: UnitCounts;
  fortificationLevel: number;
  luck: number;
}

export interface BattleResult {
  winner: 'attacker' | 'defender';
  attackPower: number;
  defensePower: number;
  luck: number;
  attackerLosses: UnitCounts;
  defenderLosses: UnitCounts;
  attackerSurvivors: UnitCounts;
  defenderSurvivors: UnitCounts;
}

function power(units: UnitCounts, stat: 'attack' | 'defense'): number {
  return UNIT_IDS.reduce((sum, id) => sum + units[id] * UNITS[id][stat], 0);
}

/**
 * The loser is wiped out. The winner loses the share (loser power / winner power) ^ 1.5 of its
 * units, so a narrow win is costly and a crushing one nearly free. A tie goes to the defender.
 */
export function resolveBattle({ attackers, defenders, fortificationLevel, luck }: BattleInput): BattleResult {
  const attackPower = power(attackers, 'attack') * (1 + luck);
  const defensePower = power(defenders, 'defense') * FORTIFICATION_BONUS ** Math.max(0, fortificationLevel);
  const winner = attackPower > defensePower ? 'attacker' : 'defender';

  const winning = winner === 'attacker' ? attackers : defenders;
  const share = winner === 'attacker' ? defensePower / attackPower : attackPower / defensePower;
  const lossRatio = unitTotal(winning) === 0 ? 0 : Math.min(1, Math.max(0, share) ** 1.5);

  const survivorsOf = (units: UnitCounts, wins: boolean): UnitCounts => {
    const out = zeroUnits();
    for (const id of UNIT_IDS) out[id] = wins ? Math.floor(units[id] * (1 - lossRatio) + 1e-9) : 0;
    return out;
  };
  const lossesOf = (units: UnitCounts, survivors: UnitCounts): UnitCounts => {
    const out = zeroUnits();
    for (const id of UNIT_IDS) out[id] = units[id] - survivors[id];
    return out;
  };

  const attackerSurvivors = survivorsOf(attackers, winner === 'attacker');
  const defenderSurvivors = survivorsOf(defenders, winner === 'defender');
  return {
    winner,
    attackPower,
    defensePower,
    luck,
    attackerSurvivors,
    defenderSurvivors,
    attackerLosses: lossesOf(attackers, attackerSurvivors),
    defenderLosses: lossesOf(defenders, defenderSurvivors),
  };
}
