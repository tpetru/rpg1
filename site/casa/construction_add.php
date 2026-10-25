<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$name = trim($_POST['name'] ?? '');
$priceEstimate = (float)($_POST['price_estimate'] ?? 0);
$stage = (int)($_POST['stage'] ?? 1);
if ($name === '' || mb_strlen($name) > 150 || $priceEstimate < 0 || $stage < 1 || $stage > 11) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid name/price/stage']);
    exit;
}

$maxOrder = 0;
$stmt = $mysqli->prepare('SELECT COALESCE(MAX(sort_order), 0) AS max_order FROM casa_construction_items WHERE house_id = ?');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$res = $stmt->get_result();
if ($res) $maxOrder = (int)$res->fetch_assoc()['max_order'];

$stmt = $mysqli->prepare('INSERT INTO casa_construction_items (name, price_estimate, stage, sort_order, house_id) VALUES (?, ?, ?, ?, ?)');
$nextOrder = $maxOrder + 1;
$stmt->bind_param('sdiii', $name, $priceEstimate, $stage, $nextOrder, $houseId);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id, 'name' => $name, 'price_estimate' => $priceEstimate, 'stage' => $stage]);
