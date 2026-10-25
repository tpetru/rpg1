<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
// Only changes the display name (see casa_design_rooms) - the folder/slug never changes, so
// nothing else keyed by room_slug (photos, notes, prices, ratings) is ever touched by a rename.
header('Content-Type: application/json');

$slug = $_POST['slug'] ?? '';
$name = trim($_POST['name'] ?? '');

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $slug) && is_dir(casa_house_dir($currentHouse['slug']) . '/design/' . $slug);
if (!$validRoom || $name === '' || mb_strlen($name) > 100) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

casa_design_rooms_ensure_table($mysqli);
$stmt = $mysqli->prepare(
    'INSERT INTO casa_design_rooms (house_id, room_slug, name) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE name = VALUES(name)'
);
$stmt->bind_param('iss', $currentHouse['id'], $slug, $name);
$stmt->execute();

echo json_encode(['ok' => true, 'name' => $name]);
