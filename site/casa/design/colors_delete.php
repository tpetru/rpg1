<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$id = $_POST['id'] ?? '';

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir(casa_house_dir($currentHouse['slug']) . '/design/' . $room);

if (!$validRoom || $id === '') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$stmt = $mysqli->prepare('SELECT colors FROM casa_design_colors WHERE room_slug = ? AND house_id = ?');
$stmt->bind_param('si', $room, $houseId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!$row) {
    echo json_encode(['ok' => true]);
    exit;
}

$colors = json_decode($row['colors'], true);
if (!is_array($colors)) {
    // Legacy plain-text value - deleting its one implicit chip clears the field entirely.
    $colors = [];
} else {
    $colors = array_values(array_filter($colors, function ($c) use ($id) {
        return !is_array($c) || (string)($c['id'] ?? '') !== $id;
    }));
}

$json = json_encode($colors, JSON_UNESCAPED_UNICODE);
$stmt = $mysqli->prepare('UPDATE casa_design_colors SET colors = ? WHERE room_slug = ? AND house_id = ?');
$stmt->bind_param('ssi', $json, $room, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
