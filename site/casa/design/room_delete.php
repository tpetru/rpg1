<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
// Deletes a room's whole folder (all its photos) plus every DB row keyed by that room_slug for
// this house - status/prices/notes/ratings/meta/winners/colors/the custom name override. Full page
// POST + redirect (not AJAX), same convention as upload.php - destructive, confirmed client-side.

$slug = $_POST['slug'] ?? '';
$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
$dir = $baseDir . '/' . $slug;

if (!preg_match('/^[a-z0-9_-]+$/i', $slug) || !is_dir($dir)) {
    header('Location: /design/?room_error=bad_room');
    exit;
}

$files = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS),
    RecursiveIteratorIterator::CHILD_FIRST
);
foreach ($files as $file) {
    if ($file->isDir()) {
        @rmdir($file->getPathname());
    } else {
        @unlink($file->getPathname());
    }
}
@rmdir($dir);

$houseId = $currentHouse['id'];
$roomScopedTables = [
    'casa_design_status',
    'casa_design_prices',
    'casa_design_notes',
    'casa_design_photo_ratings',
    'casa_design_photo_meta',
    'casa_design_photo_winners',
    'casa_design_colors',
    'casa_design_rooms',
];
foreach ($roomScopedTables as $table) {
    $stmt = $mysqli->prepare("DELETE FROM $table WHERE house_id = ? AND room_slug = ?");
    $stmt->bind_param('is', $houseId, $slug);
    $stmt->execute();
}

header('Location: /design/');
exit;
