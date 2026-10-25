<?php
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$name = trim($_POST['name'] ?? '');
if ($id <= 0 || $name === '' || mb_strlen($name) > COCKTAIL_FILTER_NAME_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

cocktail_ensure_tables($mysqli);

$dupe = $mysqli->prepare('SELECT id FROM cocktail_filters WHERE name = ? AND id != ?');
$dupe->bind_param('si', $name, $id);
$dupe->execute();
if ($dupe->get_result()->num_rows > 0) {
    http_response_code(409);
    echo json_encode(['ok' => false, 'error' => 'duplicate name']);
    exit;
}

$stmt = $mysqli->prepare('UPDATE cocktail_filters SET name = ? WHERE id = ?');
$stmt->bind_param('si', $name, $id);
$stmt->execute();

if ($stmt->affected_rows === 0) {
    $checkStmt = $mysqli->prepare('SELECT id FROM cocktail_filters WHERE id = ?');
    $checkStmt->bind_param('i', $id);
    $checkStmt->execute();
    if ($checkStmt->get_result()->num_rows === 0) {
        http_response_code(404);
        echo json_encode(['ok' => false, 'error' => 'not found']);
        exit;
    }
}

echo json_encode(['ok' => true]);
