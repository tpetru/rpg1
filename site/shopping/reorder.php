<?php
// Muta un produs cu o pozitie in sus/jos, doar printre produsele din aceeasi categorie.
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
$direction = $_POST['direction'] ?? '';
if ($id <= 0 || !in_array($direction, ['up', 'down'], true)) shop_json_error(400, 'invalid input');

$stmt = $mysqli->prepare('SELECT category_id FROM shop_products WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
if (!$row) shop_json_error(404, 'not found');
$catId = $row['category_id'] === null ? null : (int)$row['category_id'];

// Renumeroteaza 0,1,2,... produsele categoriei in ordinea curenta, ca sort_order sa fie unic.
$stmt = $mysqli->prepare('SELECT id FROM shop_products WHERE category_id <=> ? ORDER BY sort_order, id');
$stmt->bind_param('i', $catId);
$stmt->execute();
$res = $stmt->get_result();
$ids = [];
while ($r = $res->fetch_assoc()) $ids[] = (int)$r['id'];

$renumber = $mysqli->prepare('UPDATE shop_products SET sort_order = ? WHERE id = ?');
foreach ($ids as $i => $itemId) {
    $renumber->bind_param('ii', $i, $itemId);
    $renumber->execute();
}

$pos = array_search($id, $ids, true);
$swapPos = $direction === 'up' ? $pos - 1 : $pos + 1;
if ($swapPos < 0 || $swapPos >= count($ids)) {
    echo json_encode(['ok' => true, 'moved' => false]);
    exit;
}

$swapId = $ids[$swapPos];
$renumber->bind_param('ii', $swapPos, $id);
$renumber->execute();
$renumber->bind_param('ii', $pos, $swapId);
$renumber->execute();

echo json_encode(['ok' => true, 'moved' => true]);
