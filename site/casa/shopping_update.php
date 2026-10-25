<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];
header('Content-Type: application/json');

// Same room set as casa/design/ (folders), so a room added there is accepted here too.
$casaRoomSlugs = array_keys(casa_rooms_for_pages($mysqli, $houseId, $currentHouse['slug']));

$id = (int)($_POST['id'] ?? 0);
$name = trim($_POST['name'] ?? '');
$url = trim($_POST['url'] ?? '');
$room = $_POST['room'] ?? 'others';
if (!in_array($room, $casaRoomSlugs, true)) $room = 'others';
$tags = trim($_POST['tags'] ?? '');
$comment = trim($_POST['comment'] ?? '');

if ($id <= 0 || $url === '' || mb_strlen($url) > 500 || mb_strlen($name) > 150
    || mb_strlen($tags) > 255 || mb_strlen($comment) > 256) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}
if (!filter_var($url, FILTER_VALIDATE_URL) || !preg_match('#^https?://#i', $url)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid url']);
    exit;
}
if ($name === '') {
    $host = parse_url($url, PHP_URL_HOST);
    $name = $host ? preg_replace('/^www\./', '', $host) : 'Produs';
}

$tagsOrNull = $tags === '' ? null : $tags;
$commentOrNull = $comment === '' ? null : $comment;

$stmt = $mysqli->prepare('UPDATE casa_price_products SET name = ?, url = ?, room_slug = ?, tags = ?, comment = ? WHERE id = ? AND house_id = ?');
$stmt->bind_param('sssssii', $name, $url, $room, $tagsOrNull, $commentOrNull, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
