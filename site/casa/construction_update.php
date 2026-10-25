<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$field = $_POST['field'] ?? '';
$done = isset($_POST['done']) && $_POST['done'] === '1' ? 1 : 0;

$allowedFields = ['achizitionat', 'montat'];
if ($id <= 0 || !in_array($field, $allowedFields, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid id/field']);
    exit;
}

$stmt = $mysqli->prepare("UPDATE casa_construction_items SET `$field` = ? WHERE id = ? AND house_id = ?");
$stmt->bind_param('iii', $done, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
