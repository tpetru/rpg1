<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
// Full page POST + redirect (not AJAX) - the design page re-scans the folder on every load anyway,
// same convention as upload.php.

$name = trim($_POST['name'] ?? '');
if ($name === '' || mb_strlen($name) > 60) {
    header('Location: /design/?room_error=bad_name');
    exit;
}

$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
casa_make_dir($baseDir);

$slug = casa_room_slugify($name);
if ($slug === '') {
    header('Location: /design/?room_error=bad_name');
    exit;
}
$finalSlug = $slug;
$suffix = 2;
while (is_dir($baseDir . '/' . $finalSlug)) {
    $finalSlug = $slug . $suffix;
    $suffix++;
}

casa_make_dir($baseDir . '/' . $finalSlug);

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_rooms (
        house_id INT UNSIGNED NOT NULL,
        room_slug VARCHAR(64) NOT NULL,
        name VARCHAR(100) NOT NULL,
        PRIMARY KEY (house_id, room_slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$stmt = $mysqli->prepare(
    'INSERT INTO casa_design_rooms (house_id, room_slug, name) VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE name = VALUES(name)'
);
$stmt->bind_param('iss', $currentHouse['id'], $finalSlug, $name);
$stmt->execute();

header('Location: /design/#' . rawurlencode($finalSlug));
exit;
