-- The Hospital was replaced by the Command Center (a new building with a new id).
-- Upgrades still in a build queue are refunded and cancelled, then the old levels disappear.
-- Points are recomputed afterwards with `npm run recalc-points`.

UPDATE settlements s
  JOIN (SELECT settlement_id, SUM(cost_food) AS f, SUM(cost_steel) AS st, SUM(cost_oil) AS o
        FROM build_queue WHERE building = 'hospital' GROUP BY settlement_id) q
    ON q.settlement_id = s.id
  SET s.food = s.food + q.f, s.steel = s.steel + q.st, s.oil = s.oil + q.o;

UPDATE game_events SET status = 'cancelled', processed_at = UNIX_TIMESTAMP() * 1000
  WHERE type = 'BUILD_COMPLETE' AND status = 'pending'
    AND ref_id IN (SELECT id FROM build_queue WHERE building = 'hospital');

DELETE FROM build_queue WHERE building = 'hospital';

UPDATE settlements SET buildings = JSON_REMOVE(buildings, '$.hospital');
