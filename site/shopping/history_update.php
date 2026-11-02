<?php
// Editeaza o intrare din istoricul de pret (devine mereu o intrare reusita, ok=1).
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
$price = (float)($_POST['price'] ?? -1);
$currency = trim($_POST['currency'] ?? '') ?: 'RON';
$checkedAt = DateTime::createFromFormat('Y-m-d\TH:i', trim($_POST['checked_at'] ?? ''));
if ($id <= 0 || $price < 0 || mb_strlen($currency) > 8) shop_json_error(400, 'invalid input');
if (!$checkedAt) shop_json_error(400, 'invalid date');
$checkedAtSql = $checkedAt->format('Y-m-d H:i:s');

$stmt = $mysqli->prepare('UPDATE shop_price_history SET price = ?, currency = ?, ok = 1, error = NULL, checked_at = ? WHERE id = ?');
$stmt->bind_param('dssi', $price, $currency, $checkedAtSql, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
