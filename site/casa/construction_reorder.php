<?php
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

// Renumber every row sequentially first (0,1,2,...) in current display order, so sort_order is
// always unique before swapping - guards against legacy rows that still share the same sort_order
// from before items could be reordered.
$stmt = $mysqli->prepare('SELECT id FROM casa_construction_items WHERE house_id = ? ORDER BY sort_order, id');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$allRes = $stmt->get_result();
$ids = [];
while ($row = $allRes->fetch_assoc()) $ids[] = (int)$row['id'];

$renumberStmt = $mysqli->prepare('UPDATE casa_construction_items SET sort_order = ? WHERE id = ?');
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
