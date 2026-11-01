-- Military: troops stationed in settlements, the training queue, armies on the move and battle reports.
-- A settlement without an owner (owner_id NULL) is an abandoned settlement: anybody can conquer it.

CREATE TABLE settlement_units (
  settlement_id INT UNSIGNED NOT NULL,
  unit VARCHAR(24) NOT NULL,
  amount INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (settlement_id, unit),
  CONSTRAINT fk_units_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE train_queue (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  settlement_id INT UNSIGNED NOT NULL,
  unit VARCHAR(24) NOT NULL,
  amount INT UNSIGNED NOT NULL,
  cost_food DOUBLE NOT NULL,
  cost_steel DOUBLE NOT NULL,
  cost_oil DOUBLE NOT NULL,
  starts_at BIGINT UNSIGNED NOT NULL,
  finishes_at BIGINT UNSIGNED NOT NULL,
  KEY ix_train_settlement (settlement_id, finishes_at),
  CONSTRAINT fk_train_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- An army on the move. Its units are taken out of the origin when it leaves and put back
-- (or stationed in a conquered settlement) when the matching game_events row runs.
CREATE TABLE commands (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  world_id INT UNSIGNED NOT NULL,
  owner_id INT UNSIGNED NOT NULL,
  type ENUM('attack', 'return') NOT NULL,
  origin_id INT UNSIGNED NOT NULL,
  target_id INT UNSIGNED NOT NULL,
  units JSON NOT NULL,
  sent_at BIGINT UNSIGNED NOT NULL,
  arrives_at BIGINT UNSIGNED NOT NULL,
  status ENUM('travelling', 'done') NOT NULL DEFAULT 'travelling',
  KEY ix_command_owner (world_id, owner_id, status),
  KEY ix_command_origin (origin_id, status),
  CONSTRAINT fk_command_origin FOREIGN KEY (origin_id) REFERENCES settlements (id) ON DELETE CASCADE,
  CONSTRAINT fk_command_target FOREIGN KEY (target_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  world_id INT UNSIGNED NOT NULL,
  account_id INT UNSIGNED NOT NULL,
  type VARCHAR(24) NOT NULL,
  data JSON NOT NULL,
  created_at BIGINT UNSIGNED NOT NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  KEY ix_report_account (account_id, world_id, created_at),
  CONSTRAINT fk_report_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
