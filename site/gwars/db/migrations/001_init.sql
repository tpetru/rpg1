-- Game timestamps (resources_at, starts_at, finishes_at, execute_at, expires_at) are BIGINT
-- milliseconds since epoch: exact ordering, no timezone conversions.

CREATE TABLE countries (
  code CHAR(3) NOT NULL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  continent VARCHAR(40) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE worlds (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60) NOT NULL,
  h3_res TINYINT UNSIGNED NOT NULL,
  settings JSON NOT NULL,
  status ENUM('open', 'running', 'ended') NOT NULL DEFAULT 'open',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE hexes (
  world_id INT UNSIGNED NOT NULL,
  h3 VARCHAR(16) NOT NULL,
  idx INT UNSIGNED NOT NULL COMMENT 'Position in the world hex list, used as map feature id',
  lat DOUBLE NOT NULL,
  lng DOUBLE NOT NULL,
  country_code CHAR(3) NOT NULL,
  landmass SMALLINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  food_mult DOUBLE NOT NULL,
  steel_mult DOUBLE NOT NULL,
  oil_mult DOUBLE NOT NULL,
  rare_mult DOUBLE NOT NULL,
  uranium_mult DOUBLE NOT NULL,
  PRIMARY KEY (world_id, h3),
  UNIQUE KEY uq_hex_idx (world_id, idx),
  KEY ix_hex_country (world_id, country_code),
  CONSTRAINT fk_hex_world FOREIGN KEY (world_id) REFERENCES worlds (id),
  CONSTRAINT fk_hex_country FOREIGN KEY (country_code) REFERENCES countries (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE accounts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(24) NOT NULL,
  email VARCHAR(190) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_account_username (username),
  UNIQUE KEY uq_account_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sessions (
  token_hash CHAR(64) NOT NULL PRIMARY KEY,
  account_id INT UNSIGNED NOT NULL,
  expires_at BIGINT UNSIGNED NOT NULL,
  KEY ix_session_account (account_id),
  CONSTRAINT fk_session_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE world_players (
  world_id INT UNSIGNED NOT NULL,
  account_id INT UNSIGNED NOT NULL,
  nationality CHAR(3) NOT NULL,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (world_id, account_id),
  CONSTRAINT fk_wp_world FOREIGN KEY (world_id) REFERENCES worlds (id),
  CONSTRAINT fk_wp_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_wp_country FOREIGN KEY (nationality) REFERENCES countries (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE settlements (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  world_id INT UNSIGNED NOT NULL,
  h3 VARCHAR(16) NOT NULL,
  owner_id INT UNSIGNED NULL COMMENT 'NULL = independent town',
  name VARCHAR(120) NOT NULL,
  buildings JSON NOT NULL,
  food DOUBLE NOT NULL,
  steel DOUBLE NOT NULL,
  oil DOUBLE NOT NULL,
  resources_at BIGINT UNSIGNED NOT NULL,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  loyalty TINYINT UNSIGNED NOT NULL DEFAULT 100,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_settlement_hex (world_id, h3),
  KEY ix_settlement_owner (owner_id),
  CONSTRAINT fk_settlement_hex FOREIGN KEY (world_id, h3) REFERENCES hexes (world_id, h3),
  CONSTRAINT fk_settlement_owner FOREIGN KEY (owner_id) REFERENCES accounts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE build_queue (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  settlement_id INT UNSIGNED NOT NULL,
  building VARCHAR(24) NOT NULL,
  target_level TINYINT UNSIGNED NOT NULL,
  cost_food DOUBLE NOT NULL,
  cost_steel DOUBLE NOT NULL,
  cost_oil DOUBLE NOT NULL,
  starts_at BIGINT UNSIGNED NOT NULL,
  finishes_at BIGINT UNSIGNED NOT NULL,
  KEY ix_queue_settlement (settlement_id, finishes_at),
  CONSTRAINT fk_queue_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every delayed action in the game. One engine per world processes them strictly by (execute_at, id).
CREATE TABLE game_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  world_id INT UNSIGNED NOT NULL,
  type VARCHAR(32) NOT NULL,
  ref_id BIGINT UNSIGNED NOT NULL,
  execute_at BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'done', 'cancelled', 'failed') NOT NULL DEFAULT 'pending',
  processed_at BIGINT UNSIGNED NULL,
  KEY ix_event_due (world_id, status, execute_at, id),
  KEY ix_event_ref (type, ref_id),
  CONSTRAINT fk_event_world FOREIGN KEY (world_id) REFERENCES worlds (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
