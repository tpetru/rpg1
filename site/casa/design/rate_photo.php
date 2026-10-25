<?php
require_once __DIR__ . '/../_auth.php';
// Ratings are stored in the DB, keyed by (room, filename, visitor IP) - each IP has its own
// personal rating for a photo, so the photo file itself is never touched/renamed.
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
$rating = isset($_POST['rating']) ? (int)$_POST['rating'] : -1;

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir($baseDir . '/' . $room);
$validFilename = $filename !== '' && basename($filename) === $filename;
$ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

if (!$validRoom || !$validFilename || !in_array($ext, $imageExtensions, true) || $rating < 0 || $rating > 5) {
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
    'CREATE TABLE IF NOT EXISTS casa_design_photo_ratings (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        ip VARCHAR(45) NOT NULL,
        rating TINYINT UNSIGNED NOT NULL DEFAULT 0,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY room_filename_ip (room_slug, filename, ip)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

$ip = $_SERVER['REMOTE_ADDR'] ?? '';

if ($rating === 0) {
    $stmt = $mysqli->prepare('DELETE FROM casa_design_photo_ratings WHERE room_slug = ? AND filename = ? AND ip = ? AND house_id = ?');
    $stmt->bind_param('sssi', $room, $filename, $ip, $houseId);
    $stmt->execute();
} else {
    $stmt = $mysqli->prepare(
        'INSERT INTO casa_design_photo_ratings (room_slug, filename, ip, rating, house_id)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE rating = VALUES(rating)'
    );
    $stmt->bind_param('sssii', $room, $filename, $ip, $rating, $houseId);
    $stmt->execute();
}

$statsStmt = $mysqli->prepare('SELECT AVG(rating) AS avg_rating, COUNT(*) AS vote_count FROM casa_design_photo_ratings WHERE room_slug = ? AND filename = ? AND house_id = ?');
$statsStmt->bind_param('ssi', $room, $filename, $houseId);
$statsStmt->execute();
$stats = $statsStmt->get_result()->fetch_assoc();

echo json_encode([
    'ok' => true,
    'filename' => $filename,
    'rating' => $rating,
    'avg' => (float)($stats['avg_rating'] ?? 0),
    'voteCount' => (int)($stats['vote_count'] ?? 0),
]);
