<?php
// Adauga manual o intrare in istoricul de pret (ex. pret vazut la magazin, sau o verificare
// automata esuata completata de mana).
require_once __DIR__ . '/_api.php';

$productId = (int)($_POST['product_id'] ?? 0);
$price = (float)($_POST['price'] ?? -1);
$currency = trim($_POST['currency'] ?? '') ?: 'RON';
$checkedAt = DateTime::createFromFormat('Y-m-d\TH:i', trim($_POST['checked_at'] ?? ''));
if ($productId <= 0 || $price < 0 || mb_strlen($currency) > 8) shop_json_error(400, 'invalid input');
if (!$checkedAt) shop_json_error(400, 'invalid date');
$checkedAtSql = $checkedAt->format('Y-m-d H:i:s');

$stmt = $mysqli->prepare('SELECT id FROM shop_products WHERE id = ?');
$stmt->bind_param('i', $productId);
$stmt->execute();
if (!$stmt->get_result()->fetch_assoc()) shop_json_error(404, 'not found');

$stmt = $mysqli->prepare('INSERT INTO shop_price_history (product_id, price, currency, ok, checked_at) VALUES (?, ?, ?, 1, ?)');
$stmt->bind_param('idss', $productId, $price, $currency, $checkedAtSql);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => (int)$mysqli->insert_id]);
