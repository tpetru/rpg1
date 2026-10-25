<?php
require_once __DIR__ . '/../_defs.php';
require_once __DIR__ . '/../../includes/db.php';
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

cs_ensure_reels_table($mysqli);

$stmt = $mysqli->prepare('DELETE FROM cs_reels WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

if ($stmt->affected_rows === 0) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

echo json_encode(['ok' => true]);
