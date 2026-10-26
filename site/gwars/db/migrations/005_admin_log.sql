-- Every change made from the admin page, so a mistake can be traced and undone by hand.
CREATE TABLE admin_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  at BIGINT UNSIGNED NOT NULL,
  world_id INT UNSIGNED NOT NULL,
  settlement_id INT UNSIGNED NULL,
  action VARCHAR(32) NOT NULL,
  details JSON NOT NULL,
  ip VARCHAR(64) NOT NULL,
  KEY ix_admin_log_at (at),
  KEY ix_admin_log_settlement (settlement_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
