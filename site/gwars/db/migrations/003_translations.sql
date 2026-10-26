-- Data that lets clients show place names in the player's language.
-- Filled by `npm run db:seed`, which also backfills worlds that already exist.

ALTER TABLE countries ADD COLUMN iso_a2 CHAR(2) NULL AFTER code;

ALTER TABLE hexes ADD COLUMN name_key VARCHAR(140) NULL AFTER name;
