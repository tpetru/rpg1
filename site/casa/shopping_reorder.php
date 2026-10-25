<?php
// Muta un produs cu o pozitie in sus/jos, DOAR printre produsele din aceeasi camera (nu global pe
// toata casa) - ordinea "Manual" din shopping.php e per-camera, la fel cum sunt si grupate acolo.
// AJAX + JSON. Acelasi tipar ca construction_reorder.php.
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$direction = $_POST['direction'] ?? '';

if ($id <= 0 || !in_array($direction, ['up', 'down'], true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$stmt = $mysqli->prepare('SELECT room_slug FROM casa_price_products WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $id, $houseId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
if (!$row) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}
$roomSlug = $row['room_slug'];

// Renumeroteaza secvential (0,1,2,...) toate produsele DIN ACEEASI CAMERA, in ordinea curenta de
// afisare, ca sort_order sa fie mereu unic inainte de swap.
$stmt = $mysqli->prepare('SELECT id FROM casa_price_products WHERE house_id = ? AND room_slug = ? ORDER BY sort_order, id');
$stmt->bind_param('is', $houseId, $roomSlug);
$stmt->execute();
$allRes = $stmt->get_result();
$ids = [];
while ($r = $allRes->fetch_assoc()) $ids[] = (int)$r['id'];

$renumberStmt = $mysqli->prepare('UPDATE casa_price_products SET sort_order = ? WHERE id = ?');
foreach ($ids as $i => $itemId) {
    $renumberStmt->bind_param('ii', $i, $itemId);
    $renumberStmt->execute();
}

$pos = array_search($id, $ids, true);
if ($pos === false) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

$swapPos = $direction === 'up' ? $pos - 1 : $pos + 1;
if ($swapPos < 0 || $swapPos >= count($ids)) {
    echo json_encode(['ok' => true, 'moved' => false]);
    exit;
}

$swapId = $ids[$swapPos];
$renumberStmt->bind_param('ii', $swapPos, $id);
$renumberStmt->execute();
$renumberStmt->bind_param('ii', $pos, $swapId);
$renumberStmt->execute();

echo json_encode(['ok' => true, 'moved' => true]);
