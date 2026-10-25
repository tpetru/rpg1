<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$note = trim($_POST['note'] ?? '');

if ($id <= 0 || $note === '' || mb_strlen($note) > 500) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$stmt = $mysqli->prepare('UPDATE casa_design_notes SET note = ? WHERE id = ? AND house_id = ?');
$stmt->bind_param('sii', $note, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true, 'note' => $note]);
