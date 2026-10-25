<?php
require_once __DIR__ . '/../_auth.php';
// Handles photo uploads for a room's gallery folder. Full page POST + redirect (not AJAX) - the
// design page re-scans the folder on every load anyway, so a redirect is enough to show the new photo.
require_once __DIR__ . '/image_resize.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
$imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

// Uploadul reincarca pagina, iar panourile camerelor pornesc inchise. Ducem inapoi si "tab=photos",
// ca pagina sa redeschida exact panoul din care s-a dat uploadul (vezi restoreTabFromUrl in
// design/index.php) - altfel spoilerul se inchide sub mana utilizatorului dupa fiecare poza.
function casa_upload_fail(string $reason, string $room = '', string $detail = ''): void
{
    $url = '/design/?upload_error=' . rawurlencode($reason);
    if ($detail !== '') $url .= '&upload_detail=' . rawurlencode($detail);
    if ($room !== '') $url .= '&tab=photos#' . $room;
    header('Location: ' . $url);
    exit;
}

$room = $_POST['room'] ?? '';
$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir($baseDir . '/' . $room);

if (!$validRoom) {
    casa_upload_fail('bad_room');
}
if (!isset($_FILES['photo'])) {
    // With an empty $_FILES and $_POST both, this almost always means the whole request body was
    // larger than post_max_size and PHP silently dropped it - not a validation failure downstream.
    casa_upload_fail(empty($_POST) ? 'too_big_for_server' : 'no_file', $room);
}
if ($_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    casa_upload_fail('upload_error_' . $_FILES['photo']['error'], $room);
}

$file = $_FILES['photo'];
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

if (!in_array($ext, $imageExtensions, true)) {
    casa_upload_fail('bad_extension', $room);
}
if ($file['size'] > 15 * 1024 * 1024) {
    casa_upload_fail('too_big', $room);
}

// Confirm it's actually an image (not just a renamed file with an image extension).
if (@getimagesize($file['tmp_name']) === false) {
    casa_upload_fail('not_an_image', $room);
}

$filename = date('Ymd_His') . '_' . substr(uniqid(), -4) . '.' . $ext;
$destination = $baseDir . '/' . $room . '/' . $filename;

// No is_writable() pre-check here - it's known to be unreliable for directories on Windows
// (can report false even though the directory is genuinely writable). move_uploaded_file()
// below is the real test, and its own error message is more trustworthy.
error_clear_last();
if (!@move_uploaded_file($file['tmp_name'], $destination)) {
    $err = error_get_last();
    casa_upload_fail('save_failed', $room, $err['message'] ?? 'unknown');
}
// Acelasi motiv ca la foldere: fisierul trebuie sa ramana modificabil si de celalalt utilizator
// care lucreaza in folderele casei (FTP/SSH), nu doar de serverul web.
@chmod($destination, CASA_FILE_MODE);

// Best-effort downscale; if it fails (no GD, odd format) the original stays in place.
casa_resize_image_in_place($destination, $ext);

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_photo_meta (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        uploader VARCHAR(60) NULL,
        uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY room_filename (room_slug, filename)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$uploader = casa_current_name();
$stmt = $mysqli->prepare('INSERT INTO casa_design_photo_meta (room_slug, filename, uploader, house_id) VALUES (?, ?, ?, ?)');
$stmt->bind_param('sssi', $room, $filename, $uploader, $houseId);
$stmt->execute();

header('Location: /design/?tab=photos#' . $room);
exit;
