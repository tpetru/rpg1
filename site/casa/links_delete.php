<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid id']);
    exit;
}

$stmt = $mysqli->prepare('DELETE FROM casa_links WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
