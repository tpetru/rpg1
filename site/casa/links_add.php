<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];
header('Content-Type: application/json');

// Same fixed room set as casa/design/ and links.php itself - anything unrecognized falls back to
// Same room set as casa/design/ (folders), so a room added there is accepted here too.
$casaRoomSlugs = array_keys(casa_rooms_for_pages($mysqli, $houseId, $currentHouse['slug']));

$room = $_POST['room'] ?? 'others';
if (!in_array($room, $casaRoomSlugs, true)) $room = 'others';
$category = trim($_POST['category'] ?? '');
$label = trim($_POST['label'] ?? '');
$url = trim($_POST['url'] ?? '');
$comment = trim($_POST['comment'] ?? '');

if (mb_strlen($category) > 100 || $url === '' || mb_strlen($url) > 500
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

$maxOrder = 0;
$stmt = $mysqli->prepare('SELECT COALESCE(MAX(sort_order), 0) AS max_order FROM casa_links WHERE room_slug = ? AND house_id = ?');
$stmt->bind_param('si', $room, $houseId);
$stmt->execute();
$res = $stmt->get_result();
if ($res) $maxOrder = (int)$res->fetch_assoc()['max_order'];

$labelOrNull = $label === '' ? null : $label;
$commentOrNull = $comment === '' ? null : $comment;
$nextOrder = $maxOrder + 1;
$insertStmt = $mysqli->prepare('INSERT INTO casa_links (category, room_slug, label, url, comment, sort_order, house_id) VALUES (?, ?, ?, ?, ?, ?, ?)');
$insertStmt->bind_param('sssssii', $category, $room, $labelOrNull, $url, $commentOrNull, $nextOrder, $houseId);
$insertStmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
