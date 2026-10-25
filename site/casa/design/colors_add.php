<?php
require_once __DIR__ . '/../_auth.php';
// Adds one color chip to a room's palette. Colors are stored as a JSON array (see
// casa_parse_room_colors() in index.php) in a single TEXT column per room - read-modify-write,
// fine at this scale (one household, no concurrent editors).
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$hex = $_POST['hex'] ?? '';
$label = trim($_POST['label'] ?? '');

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir(casa_house_dir($currentHouse['slug']) . '/design/' . $room);
$validHex = preg_match('/^#[0-9a-f]{6}$/i', $hex);

if (!$validRoom || !$validHex || $label === '' || mb_strlen($label) > 60) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_colors (
        room_slug VARCHAR(64) NOT NULL,
        colors TEXT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (room_slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query('ALTER TABLE casa_design_colors MODIFY COLUMN colors TEXT NOT NULL');

$stmt = $mysqli->prepare('SELECT colors FROM casa_design_colors WHERE room_slug = ? AND house_id = ?');
$stmt->bind_param('si', $room, $houseId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

$colors = [];
if ($row) {
    $decoded = json_decode($row['colors'], true);
    if (is_array($decoded)) {
        $colors = $decoded;
    } elseif (trim($row['colors']) !== '') {
        // Legacy plain-text value - carry it forward as its own chip instead of discarding it.
        $colors[] = ['id' => 'legacy', 'hex' => '#d9a441', 'label' => trim($row['colors'])];
    }
}

$id = uniqid('c');
$colors[] = ['id' => $id, 'hex' => $hex, 'label' => $label];

$json = json_encode($colors, JSON_UNESCAPED_UNICODE);
$stmt = $mysqli->prepare(
    'INSERT INTO casa_design_colors (room_slug, colors, house_id) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE colors = VALUES(colors)'
);
$stmt->bind_param('ssi', $room, $json, $houseId);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $id, 'hex' => $hex, 'label' => $label]);
