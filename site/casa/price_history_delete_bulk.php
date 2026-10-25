<?php
// Sterge mai multe intrari din istoricul de pret dintr-o data (butonul "Șterge selectate").
// AJAX + JSON.
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$idsRaw = trim($_POST['ids'] ?? '');
$ids = array_values(array_unique(array_filter(array_map('intval', explode(',', $idsRaw)), function ($id) {
    return $id > 0;
})));

if (empty($ids)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'no_ids']);
    exit;
}

$placeholders = implode(',', array_fill(0, count($ids), '?'));
$types = str_repeat('i', count($ids)) . 'i';
$params = $ids;
$params[] = $houseId;

$stmt = $mysqli->prepare(
    "DELETE h FROM casa_price_history h
     JOIN casa_price_products p ON p.id = h.product_id
     WHERE h.id IN ($placeholders) AND p.house_id = ?"
);
$stmt->bind_param($types, ...$params);
$stmt->execute();

echo json_encode(['ok' => true, 'deleted' => $stmt->affected_rows]);
