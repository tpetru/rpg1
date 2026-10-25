<?php
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$description = trim($_POST['description'] ?? '');

if ($id <= 0 || mb_strlen($description) > COCKTAIL_DESC_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

cocktail_ensure_tables($mysqli);

$checkStmt = $mysqli->prepare('SELECT id FROM cocktail_reels WHERE id = ?');
$checkStmt->bind_param('i', $id);
$checkStmt->execute();
if ($checkStmt->get_result()->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

$descOrNull = $description === '' ? null : $description;
$stmt = $mysqli->prepare('UPDATE cocktail_reels SET description = ? WHERE id = ?');
$stmt->bind_param('si', $descOrNull, $id);
$stmt->execute();

$validIds = [];
$res = $mysqli->query('SELECT id FROM cocktail_filters');
if ($res) while ($row = $res->fetch_assoc()) $validIds[] = (int)$row['id'];

$filterIds = array_map('intval', $_POST['filters'] ?? []);
cocktail_set_reel_filters($mysqli, $id, $filterIds, $validIds);

echo json_encode(['ok' => true]);
