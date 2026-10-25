<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$field = $_POST['field'] ?? '';
$price = (float)($_POST['price'] ?? -1);

$allowedFields = ['price_estimate', 'price_actual'];
if ($id <= 0 || !in_array($field, $allowedFields, true) || $price < 0) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid id/field/price']);
    exit;
}

$stmt = $mysqli->prepare("UPDATE casa_construction_items SET `$field` = ? WHERE id = ? AND house_id = ?");
$stmt->bind_param('dii', $price, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
