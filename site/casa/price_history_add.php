<?php
// Adauga manual o intrare in istoricul de pret al unui produs (ex. pret vazut la magazin, sau o
// verificare automata esuata pe care o completezi cu mana). AJAX + JSON.
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$productId = (int)($_POST['product_id'] ?? 0);
$price = (float)($_POST['price'] ?? -1);
$currency = trim($_POST['currency'] ?? '') ?: 'RON';
$checkedAt = trim($_POST['checked_at'] ?? '');

if ($productId <= 0 || $price < 0 || mb_strlen($currency) > 8) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}
$checkedAtTs = DateTime::createFromFormat('Y-m-d\TH:i', $checkedAt);
if (!$checkedAtTs) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid date']);
    exit;
}
$checkedAtSql = $checkedAtTs->format('Y-m-d H:i:s');

// Produsul trebuie sa apartina casei curente - altfel s-ar putea adauga istoric pe id-uri ghicite.
$stmt = $mysqli->prepare('SELECT id FROM casa_price_products WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $productId, $houseId);
$stmt->execute();
if ($stmt->get_result()->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not_found']);
    exit;
}

$stmt = $mysqli->prepare('INSERT INTO casa_price_history (product_id, price, currency, ok, checked_at) VALUES (?, ?, ?, 1, ?)');
$stmt->bind_param('idss', $productId, $price, $currency, $checkedAtSql);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
