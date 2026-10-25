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
$room = $_POST['room'] ?? 'others';
if (!in_array($room, $casaRoomSlugs, true)) $room = 'others';
$category = trim($_POST['category'] ?? '');
$label = trim($_POST['label'] ?? '');
$url = trim($_POST['url'] ?? '');
$comment = trim($_POST['comment'] ?? '');

if ($id <= 0 || mb_strlen($category) > 100 || $url === '' || mb_strlen($url) > 500
    || mb_strlen($label) > 150 || mb_strlen($comment) > 256) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}
if (!filter_var($url, FILTER_VALIDATE_URL) || !preg_match('#^https?://#i', $url)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid url']);
    exit;
}

$labelOrNull = $label === '' ? null : $label;
$commentOrNull = $comment === '' ? null : $comment;

$stmt = $mysqli->prepare('UPDATE casa_links SET category = ?, room_slug = ?, label = ?, url = ?, comment = ? WHERE id = ? AND house_id = ?');
$stmt->bind_param('sssssii', $category, $room, $labelOrNull, $url, $commentOrNull, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
