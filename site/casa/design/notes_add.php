<?php
require_once __DIR__ . '/../_auth.php';
// AJAX endpoint for the per-room notes box on the design page. Room is validated the same way as
// the other room-scoped endpoints here (safe-slug pattern + existing-directory check).
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$note = trim($_POST['note'] ?? '');

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir(casa_house_dir($currentHouse['slug']) . '/design/' . $room);

if (!$validRoom || $note === '' || mb_strlen($note) > 500) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid room/note']);
    exit;
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_notes (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        note VARCHAR(500) NOT NULL,
        author VARCHAR(60) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY room_slug (room_slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query('ALTER TABLE casa_design_notes ADD COLUMN IF NOT EXISTS author VARCHAR(60) NULL AFTER note');

$author = casa_current_name();

$stmt = $mysqli->prepare('INSERT INTO casa_design_notes (room_slug, note, author, house_id) VALUES (?, ?, ?, ?)');
$stmt->bind_param('sssi', $room, $note, $author, $houseId);
$stmt->execute();

echo json_encode([
    'ok' => true,
    'id' => $mysqli->insert_id,
    'note' => $note,
    'author' => $author,
    'date' => date('d.m.Y H:i'),
    'dateShort' => date('d.m'),
]);
