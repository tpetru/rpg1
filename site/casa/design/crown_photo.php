<?php
require_once __DIR__ . '/../_auth.php';
// Toggles the "winning photo" crown - a shared/global flag (unlike the personal per-IP star
// rating), the same for every visitor. Winning photos sort first in the gallery and get a gold
// frame (see index.php).
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
$imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$filename = $_POST['filename'] ?? '';
$winner = !empty($_POST['winner']) && $_POST['winner'] !== '0';

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir($baseDir . '/' . $room);
$validFilename = $filename !== '' && basename($filename) === $filename;
$ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

if (!$validRoom || !$validFilename || !in_array($ext, $imageExtensions, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$path = $baseDir . '/' . $room . '/' . $filename;
if (!is_file($path)) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_photo_winners (
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        crowned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (room_slug, filename)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

if ($winner) {
    $stmt = $mysqli->prepare('INSERT IGNORE INTO casa_design_photo_winners (room_slug, filename, house_id) VALUES (?, ?, ?)');
    $stmt->bind_param('ssi', $room, $filename, $houseId);
    $stmt->execute();
} else {
    $stmt = $mysqli->prepare('DELETE FROM casa_design_photo_winners WHERE room_slug = ? AND filename = ? AND house_id = ?');
    $stmt->bind_param('ssi', $room, $filename, $houseId);
    $stmt->execute();
}

echo json_encode(['ok' => true, 'filename' => $filename, 'winner' => $winner]);
