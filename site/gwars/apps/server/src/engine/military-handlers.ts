import {
  BUILDING_IDS,
  addUnits,
  airUnits,
  groundUnits,
  levelsBombed,
  luckFromSeed,
  minBuildingLevel,
  normalizeUnits,
  resolveBattle,
  settlementPoints,
  unitTotal,
  type BattleReportData,
  type BuildingId,
  type UnitCounts, DRONES_PER_BOMBER, wallLevelsDemolished } from '@geowars/rules';
import type { PoolConnection } from 'mysql2/promise';
import { exec, one, rows } from '../db';
import { loadSettlement, refreshPlayerPoints, saveSettlement, stockAt } from '../game/settlements';
import { addTroops, loadUnits, setTroops } from '../game/troops';
import type { EventHandler } from './handlers';

interface CommandRow {
  id: number;
  world_id: number;
  owner_id: number;
  type: 'attack' | 'return';
  origin_id: number;
  target_id: number;
  units: string | UnitCounts;
  sent_at: number;
  arrives_at: number;
  status: 'travelling' | 'done';
  bomb_target: string | null;
}

const parseUnits = (raw: string | UnitCounts): UnitCounts => normalizeUnits(typeof raw === 'string' ? JSON.parse(raw) : raw);

async function eventStillPending(conn: PoolConnection, id: number): Promise<boolean> {
  const row = await one<{ status: string }>(conn, 'SELECT status FROM game_events WHERE id = ? FOR UPDATE', [id]);
  return row?.status === 'pending';
}

/** One unit of a batch is trained: it joins the garrison, and the next one is scheduled until the batch is done. */
export const trainComplete: EventHandler = async (conn, ev, { world, realtime }) => {
  const ref = await one<{ settlement_id: number }>(conn, 'SELECT settlement_id FROM train_queue WHERE id = ?', [ev.ref_id]);
  if (!ref) return; // cancelled

  const s = await loadSettlement(conn, ref.settlement_id, true);
  if (!s || !(await eventStillPending(conn, ev.id))) return;
  const item = await one<{ unit: string; amount: number; total: number; starts_at: number; finishes_at: number }>(
    conn,
    'SELECT unit, amount, total, starts_at, finishes_at FROM train_queue WHERE id = ?',
    [ev.ref_id],
  );
  if (!item) return;

  await addTroops(conn, s.id, normalizeUnits({ [item.unit]: 1 }));
  const left = item.amount - 1;
  if (left <= 0) {
    await exec(conn, 'DELETE FROM train_queue WHERE id = ?', [ev.ref_id]);
  } else {
    await exec(conn, 'UPDATE train_queue SET amount = ? WHERE id = ?', [left, ev.ref_id]);
    const starts = Number(item.starts_at);
    const finishes = Number(item.finishes_at);
    const doneAfter = item.total - left + 1; // the unit that finishes next
    const nextAt = left === 1 ? finishes : Math.round(starts + ((finishes - starts) / item.total) * doneAfter);
    await exec(conn, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'TRAIN_COMPLETE', ?, ?)`, [world.id, ev.ref_id, nextAt]);
  }
  return () => {
    if (s.ownerId) realtime.sendTo(world.id, s.ownerId, { t: 'settlement', id: s.id });
  };
};

/** A research is finished: the unit can be trained in that settlement. */
export const researchComplete: EventHandler = async (conn, ev, { world, realtime }) => {
  const ref = await one<{ settlement_id: number; unit: string }>(conn, 'SELECT settlement_id, unit FROM research_queue WHERE id = ?', [ev.ref_id]);
  if (!ref) return; // cancelled

  const s = await loadSettlement(conn, ref.settlement_id, true);
  if (!s || !(await eventStillPending(conn, ev.id))) return;
  await exec(conn, 'INSERT IGNORE INTO settlement_research (settlement_id, unit) VALUES (?, ?)', [s.id, ref.unit]);
  await exec(conn, 'DELETE FROM research_queue WHERE id = ?', [ev.ref_id]);
  return () => {
    if (s.ownerId) realtime.sendTo(world.id, s.ownerId, { t: 'settlement', id: s.id });
  };
};

/** An army that was sent back comes home. */
export const returnArrive: EventHandler = async (conn, ev, { world, realtime }) => {
  const cmd = await one<CommandRow>(conn, 'SELECT * FROM commands WHERE id = ?', [ev.ref_id]);
  if (!cmd || cmd.status !== 'travelling') return;

  const origin = await loadSettlement(conn, cmd.origin_id, true);
  if (!origin || !(await eventStillPending(conn, ev.id))) return;
  await addTroops(conn, origin.id, parseUnits(cmd.units));
  await exec(conn, `UPDATE commands SET status = 'done' WHERE id = ?`, [cmd.id]);
  return () => {
    realtime.sendTo(world.id, cmd.owner_id, { t: 'command' });
    realtime.sendTo(world.id, cmd.owner_id, { t: 'settlement', id: origin.id });
  };
};

/**
 * An army reaches an abandoned settlement and fights its garrison. If it wins, the settlement
 * becomes the attacker's with the survivors as its new garrison. If it loses, the army is gone.
 * If somebody else conquered the target first, the army turns round and goes home.
 */
export const attackArrive: EventHandler = async (conn, ev, { world, realtime }) => {
  const cmd = await one<CommandRow>(conn, 'SELECT * FROM commands WHERE id = ?', [ev.ref_id]);
  if (!cmd || cmd.status !== 'travelling') return;

  // Lock in id order, the same order the API uses, then the event row.
  const locked = new Map<number, NonNullable<Awaited<ReturnType<typeof loadSettlement>>>>();
  for (const id of [cmd.origin_id, cmd.target_id].sort((a, b) => a - b)) {
    const s = await loadSettlement(conn, id, true);
    if (s) locked.set(id, s);
  }
  if (!(await eventStillPending(conn, ev.id))) return;
  const origin = locked.get(cmd.origin_id);
  const target = locked.get(cmd.target_id);
  if (!origin || !target) return;

  const attackers = parseUnits(cmd.units);
  const [originHex] = await rows<{ idx: number }>(conn, 'SELECT idx FROM hexes WHERE world_id = ? AND h3 = ?', [world.id, origin.h3]);
  const [targetHex] = await rows<{ idx: number }>(conn, 'SELECT idx FROM hexes WHERE world_id = ? AND h3 = ?', [world.id, target.h3]);
  const base = { originId: origin.id, originIdx: originHex.idx, targetId: target.id, targetIdx: targetHex.idx };
  const nobody = (): UnitCounts => normalizeUnits({});

  const attackerName = (await one<{ nation: string }>(conn, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [cmd.world_id, cmd.owner_id]))?.nation ?? null;
  let report: BattleReportData;
  let conquered = false;
  let nation: string | null = null;

  {
    // Whoever holds the target now, abandoned, another player or the attacker, the army fights its garrison.
    const defenders = await loadUnits(conn, target.id);
    const defenderName = target.ownerId === null ? null : ((await one<{ nation: string }>(conn, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [cmd.world_id, target.ownerId]))?.nation ?? null);
    const fortificationLevel = target.levels.fortifications;
    const air = airUnits(attackers);
    // Defence Drones bring down bombers first: DRONES_PER_BOMBER of them stop one.
    const bombersShot = Math.min(air.bomber, Math.floor(defenders.drone / DRONES_PER_BOMBER));
    air.bomber -= bombersShot;
    const ground = groundUnits(attackers);
    const fights = unitTotal(ground) > 0;

    // Spies look first, then the bombers do their work, then the ground army fights.
    const intel = air.spy > 0 ? { ...target.levels } : null;
    let bombed: BattleReportData['bombed'] = null;
    if (air.bomber > 0) {
      const candidates = BUILDING_IDS.filter((id) => target.levels[id] > minBuildingLevel(id));
      const aimed = candidates.find((id) => id === cmd.bomb_target);
      const hit = aimed ?? [...candidates].sort((a, b) => target.levels[b] - target.levels[a])[0];
      if (hit) {
        const from = target.levels[hit];
        const to = Math.max(minBuildingLevel(hit), from - levelsBombed(air.bomber));
        target.stock = stockAt(target, ev.execute_at, world.settings);
        target.resourcesAt = ev.execute_at;
        target.levels = { ...target.levels, [hit as BuildingId]: to };
        target.points = settlementPoints(target.levels);
        await saveSettlement(conn, target);
        bombed = { building: hit, from, to };
      }
    }

    const battle = fights
      ? resolveBattle({ attackers: ground, defenders, fortificationLevel, luck: luckFromSeed(cmd.id) })
      : { winner: 'defender' as const, attackPower: 0, defensePower: 0, luck: 0, attackerLosses: nobody(), defenderLosses: nobody(), attackerSurvivors: nobody(), defenderSurvivors: defenders };
    // Winning only takes the settlement when a President came along; otherwise it is a raid.
    const won = fights && battle.winner === 'attacker';
    // Only an abandoned settlement can be taken; another player's is raided, never conquered.
    conquered = won && ground.president >= 1 && target.ownerId === null;
    // Tanks that won the day tear down the walls for good (and the town keeps the lower level).
    let wallsDown: BattleReportData['wallsDown'] = null;
    const wallFrom = target.levels.fortifications;
    if (won && battle.attackerSurvivors.tank > 0 && wallFrom > minBuildingLevel('fortifications')) {
      const wallTo = Math.max(minBuildingLevel('fortifications'), wallFrom - wallLevelsDemolished(battle.attackerSurvivors.tank));
      target.stock = stockAt(target, ev.execute_at, world.settings);
      target.resourcesAt = ev.execute_at;
      target.levels = { ...target.levels, fortifications: wallTo };
      target.points = settlementPoints(target.levels);
      await saveSettlement(conn, target);
      wallsDown = { from: wallFrom, to: wallTo };
    }

    if (conquered) {
      // The President never falls in a won battle: he stays to govern what was taken.
      battle.attackerSurvivors.president = ground.president;
      battle.attackerLosses.president = 0;
    }

    if (conquered) {
      // The settlement changes hands with the stock it has built up, and the survivors garrison it.
      target.stock = stockAt(target, ev.execute_at, world.settings);
      target.resourcesAt = ev.execute_at;
      await saveSettlement(conn, target);
      await exec(conn, 'UPDATE settlements SET owner_id = ?, loyalty = 100, custom_name = NULL WHERE id = ?', [cmd.owner_id, target.id]);
      await setTroops(conn, target.id, battle.attackerSurvivors);
      await refreshPlayerPoints(conn, cmd.world_id, cmd.owner_id);
      const player = await one<{ nation: string }>(conn, 'SELECT nation FROM world_players WHERE world_id = ? AND account_id = ?', [cmd.world_id, cmd.owner_id]);
      nation = player?.nation ?? null;
    } else {
      await setTroops(conn, target.id, battle.defenderSurvivors);
    }

    // The defending player's total follows the buildings that were bombed or pulled down.
    if (target.ownerId !== null && target.ownerId !== cmd.owner_id && (bombed || wallsDown)) await refreshPlayerPoints(conn, cmd.world_id, target.ownerId);

    report = {
      ...base,
      attackerName,
      outcome: !fights ? 'air' : conquered ? 'conquered' : won ? 'victory' : 'defeat',
      attackers,
      attackerLosses: { ...battle.attackerLosses, bomber: bombersShot },
      bombersShot,
      // Only spies get to see the garrison when no ground army fought.
      defenders: fights || air.spy > 0 ? defenders : nobody(),
      defenderLosses: battle.defenderLosses,
      attackPower: Math.round(battle.attackPower),
      defensePower: Math.round(battle.defensePower),
      luck: Math.round(battle.luck * 1000) / 1000,
      fortificationLevel,
      defenderName,
      intel,
      bombed,
      wallsDown,
    };

    // The air units never stay, and neither does an army that won without taking the place:
    // they fly home, taking as long as the way here took.
    const homeward = won && !conquered ? { ...air, ...battle.attackerSurvivors, spy: air.spy, bomber: air.bomber } : air;
    if (unitTotal(homeward) > 0) {
      const back = ev.execute_at + (Number(cmd.arrives_at) - Number(cmd.sent_at));
      const result = await exec(
        conn,
        `INSERT INTO commands (world_id, owner_id, type, origin_id, target_id, units, sent_at, arrives_at) VALUES (?, ?, 'return', ?, ?, ?, ?, ?)`,
        [cmd.world_id, cmd.owner_id, cmd.origin_id, cmd.target_id, JSON.stringify(homeward), ev.execute_at, back],
      );
      await exec(conn, `INSERT INTO game_events (world_id, type, ref_id, execute_at) VALUES (?, 'RETURN_ARRIVE', ?, ?)`, [cmd.world_id, result.insertId, back]);
    }
  }

  await exec(conn, `UPDATE commands SET status = 'done' WHERE id = ?`, [cmd.id]);
  const saved = await exec(conn, `INSERT INTO reports (world_id, account_id, type, data, created_at) VALUES (?, ?, 'battle', ?, ?)`, [
    cmd.world_id,
    cmd.owner_id,
    JSON.stringify(report),
    ev.execute_at,
  ]);

  // The defending player gets their own copy, without what the spies found out.
  const defenderId = target.ownerId !== null && target.ownerId !== cmd.owner_id && report.outcome !== 'fizzled' ? target.ownerId : null;
  let defenderReportId = 0;
  if (defenderId !== null) {
    const copy: BattleReportData = { ...report, asDefender: true, intel: null };
    const savedCopy = await exec(conn, `INSERT INTO reports (world_id, account_id, type, data, created_at) VALUES (?, ?, 'battle', ?, ?)`, [cmd.world_id, defenderId, JSON.stringify(copy), ev.execute_at]);
    defenderReportId = savedCopy.insertId;
  }

  return () => {
    realtime.sendTo(world.id, cmd.owner_id, { t: 'report', id: saved.insertId });
    realtime.sendTo(world.id, cmd.owner_id, { t: 'command' });
    if (defenderId !== null) {
      realtime.sendTo(world.id, defenderId, { t: 'report', id: defenderReportId });
      realtime.sendTo(world.id, defenderId, { t: 'settlement', id: target.id });
    }
    realtime.sendTo(world.id, cmd.owner_id, { t: 'settlement', id: origin.id });
    if (conquered) {
      realtime.sendTo(world.id, cmd.owner_id, { t: 'settlement', id: target.id });
      realtime.broadcast(world.id, { t: 'map', row: [targetHex.idx, target.id, cmd.owner_id, target.points], ownerName: nation });
    }
  };
};
