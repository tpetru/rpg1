-- Parliament and Command Center were removed from the game.
-- Their levels disappear from every settlement; points and queued upgrades are settled accordingly.

-- 1. Upgrades still in a build queue: give the resources back, cancel their events, drop the rows.
UPDATE settlements s
  JOIN (SELECT settlement_id, SUM(cost_food) AS f, SUM(cost_steel) AS st, SUM(cost_oil) AS o
        FROM build_queue WHERE building IN ('parliament', 'commandcenter') GROUP BY settlement_id) q
    ON q.settlement_id = s.id
  SET s.food = s.food + q.f, s.steel = s.steel + q.st, s.oil = s.oil + q.o;

UPDATE game_events SET status = 'cancelled', processed_at = UNIX_TIMESTAMP() * 1000
  WHERE type = 'BUILD_COMPLETE' AND status = 'pending'
    AND ref_id IN (SELECT id FROM build_queue WHERE building IN ('parliament', 'commandcenter'));

DELETE FROM build_queue WHERE building IN ('parliament', 'commandcenter');

-- 2. Points: Parliament level 1 was worth 512 and Command Center level 1 was worth 3.
UPDATE settlements
  SET points = GREATEST(0, points
      - IF(COALESCE(JSON_VALUE(buildings, '$.parliament'), 0) > 0, 512, 0)
      - IF(COALESCE(JSON_VALUE(buildings, '$.commandcenter'), 0) > 0, 3, 0));

-- 3. Remove the levels themselves.
UPDATE settlements SET buildings = JSON_REMOVE(buildings, '$.parliament', '$.commandcenter');

-- 4. Player totals follow their settlements.
UPDATE world_players wp
  SET points = (SELECT COALESCE(SUM(s.points), 0) FROM settlements s WHERE s.world_id = wp.world_id AND s.owner_id = wp.account_id);
