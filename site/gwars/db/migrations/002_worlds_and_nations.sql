-- Worlds get a public number ("World 0", "World 1", ...) and players choose their own
-- nation name per world instead of picking a real country.

ALTER TABLE worlds ADD COLUMN number SMALLINT UNSIGNED NULL AFTER id;
-- Until now there was a single world, used for testing: it becomes World 0.
UPDATE worlds SET number = 0, name = 'World 0' WHERE id = (SELECT id FROM (SELECT MIN(id) AS id FROM worlds) AS first_world);
UPDATE worlds SET number = id WHERE number IS NULL;
ALTER TABLE worlds MODIFY number SMALLINT UNSIGNED NOT NULL, ADD UNIQUE KEY uq_world_number (number);

ALTER TABLE world_players DROP FOREIGN KEY fk_wp_country;
ALTER TABLE world_players ADD COLUMN nation VARCHAR(20) NOT NULL DEFAULT '' AFTER account_id;
UPDATE world_players SET nation = CONCAT('Nation', account_id) WHERE nation = '';
ALTER TABLE world_players
  DROP COLUMN nationality,
  ALTER COLUMN nation DROP DEFAULT,
  ADD UNIQUE KEY uq_wp_nation (world_id, nation);
