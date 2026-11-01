-- Units are researched in a settlement's Research Center before they can be trained there.
CREATE TABLE settlement_research (
  settlement_id INT UNSIGNED NOT NULL,
  unit VARCHAR(24) NOT NULL,
  PRIMARY KEY (settlement_id, unit),
  CONSTRAINT fk_research_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One research at a time per settlement.
CREATE TABLE research_queue (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  settlement_id INT UNSIGNED NOT NULL,
  unit VARCHAR(24) NOT NULL,
  cost_food DOUBLE NOT NULL,
  cost_steel DOUBLE NOT NULL,
  cost_oil DOUBLE NOT NULL,
  starts_at BIGINT UNSIGNED NOT NULL,
  finishes_at BIGINT UNSIGNED NOT NULL,
  UNIQUE KEY ux_research_settlement (settlement_id),
  CONSTRAINT fk_researchq_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Settlements that exist now keep the three units they could already train.
INSERT INTO settlement_research (settlement_id, unit)
  SELECT s.id, u.unit FROM settlements s JOIN (SELECT 'rifleman' AS unit UNION SELECT 'assault' UNION SELECT 'tank') u;

-- Bombers aim at one building of the attacked town.
ALTER TABLE commands ADD COLUMN bomb_target VARCHAR(24) NULL;
