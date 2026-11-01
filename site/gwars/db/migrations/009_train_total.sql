-- Troops now join the garrison one by one. `amount` is what is still to come and `total` is what was ordered,
-- so the time per unit is (finishes_at - starts_at) / total.
ALTER TABLE train_queue ADD COLUMN total INT UNSIGNED NULL AFTER amount;
UPDATE train_queue SET total = amount;
ALTER TABLE train_queue MODIFY COLUMN total INT UNSIGNED NOT NULL;
