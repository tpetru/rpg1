<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];
// Deletes one photo from a room's gallery folder. Room and filename are both validated - room
// against a safe-slug pattern plus an existing-directory check, filename against basename() to
// block path traversal - before touching the filesystem.
$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
$imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$filename = $_POST['filename'] ?? '';

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

if (!unlink($path)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => 'delete failed']);
    exit;
}

// Clean up any ratings (from any visitor IP) and uploader metadata left behind for this now-gone photo.
$stmt = $mysqli->prepare('DELETE FROM casa_design_photo_ratings WHERE room_slug = ? AND filename = ? AND house_id = ?');
$stmt->bind_param('ssi', $room, $filename, $houseId);
$stmt->execute();

$stmt = $mysqli->prepare('DELETE FROM casa_design_photo_meta WHERE room_slug = ? AND filename = ? AND house_id = ?');
$stmt->bind_param('ssi', $room, $filename, $houseId);
$stmt->execute();

$stmt = $mysqli->prepare('DELETE FROM casa_design_photo_winners WHERE room_slug = ? AND filename = ? AND house_id = ?');
$stmt->bind_param('ssi', $room, $filename, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
