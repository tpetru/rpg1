<?php
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';
header('Content-Type: application/json');

$name = trim($_POST['name'] ?? '');
if ($name === '' || mb_strlen($name) > COCKTAIL_FILTER_NAME_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

cocktail_ensure_tables($mysqli);

$existing = $mysqli->prepare('SELECT id, name FROM cocktail_filters WHERE name = ?');
$existing->bind_param('s', $name);
$existing->execute();
$row = $existing->get_result()->fetch_assoc();
if ($row) {
    echo json_encode(['ok' => true, 'id' => (int)$row['id'], 'name' => $row['name']]);
    exit;
}

$maxOrder = -1;
$orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM cocktail_filters');
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$stmt = $mysqli->prepare('INSERT INTO cocktail_filters (name, sort_order) VALUES (?, ?)');
$stmt->bind_param('si', $name, $nextOrder);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => (int)$mysqli->insert_id, 'name' => $name]);
