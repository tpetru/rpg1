<?php
require_once __DIR__ . '/../_defs.php';
require_once __DIR__ . '/../../includes/db.php';
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$map = $_POST['map'] ?? '';
$team = strtolower(trim($_POST['team'] ?? ''));
$description = trim($_POST['description'] ?? '');

if ($id <= 0 || !isset($csReelMaps[$map]) || !isset($csReelTeams[$team]) || mb_strlen($description) > 128) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

cs_ensure_reels_table($mysqli);

$descOrNull = $description === '' ? null : $description;
$stmt = $mysqli->prepare('UPDATE cs_reels SET map_slug = ?, team = ?, description = ? WHERE id = ?');
$stmt->bind_param('sssi', $map, $team, $descOrNull, $id);
$stmt->execute();

$checkStmt = $mysqli->prepare('SELECT id FROM cs_reels WHERE id = ?');
$checkStmt->bind_param('i', $id);
$checkStmt->execute();
if ($checkStmt->get_result()->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

echo json_encode(['ok' => true]);
