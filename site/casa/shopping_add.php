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

$name = trim($_POST['name'] ?? '');
$url = trim($_POST['url'] ?? '');
$room = $_POST['room'] ?? 'others';
if (!in_array($room, $casaRoomSlugs, true)) $room = 'others';
$tags = trim($_POST['tags'] ?? '');
$comment = trim($_POST['comment'] ?? '');

if ($url === '' || mb_strlen($url) > 500 || mb_strlen($name) > 150 || mb_strlen($tags) > 255 || mb_strlen($comment) > 256) {
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

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_price_products (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        name VARCHAR(150) NOT NULL,
        url VARCHAR(500) NOT NULL,
        room_slug VARCHAR(64) NOT NULL DEFAULT \'others\',
        tags VARCHAR(255) NULL,
        comment VARCHAR(256) NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query("ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS room_slug VARCHAR(64) NOT NULL DEFAULT 'others' AFTER url");
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS tags VARCHAR(255) NULL AFTER room_slug');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS comment VARCHAR(256) NULL AFTER tags');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS priority TINYINT(1) NOT NULL DEFAULT 0 AFTER comment');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS added_by VARCHAR(60) NULL AFTER priority');

$stmt = $mysqli->prepare('SELECT COALESCE(MAX(sort_order), 0) AS m FROM casa_price_products WHERE house_id = ?');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$maxRes = $stmt->get_result();
$nextOrder = $maxRes ? ((int)$maxRes->fetch_assoc()['m'] + 1) : 1;

$tagsOrNull = $tags === '' ? null : $tags;
$commentOrNull = $comment === '' ? null : $comment;
$addedBy = casa_current_name();

$stmt = $mysqli->prepare('INSERT INTO casa_price_products (name, url, room_slug, tags, comment, sort_order, house_id, added_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
$stmt->bind_param('sssssiis', $name, $url, $room, $tagsOrNull, $commentOrNull, $nextOrder, $houseId, $addedBy);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id, 'name' => $name]);
