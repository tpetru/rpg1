<?php
// Muta o categorie cu o pozitie in sus/jos (ordinea grupurilor din pagina).
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
$direction = $_POST['direction'] ?? '';
if ($id <= 0 || !in_array($direction, ['up', 'down'], true)) shop_json_error(400, 'invalid input');

$ids = array_keys(shop_categories($mysqli));
$pos = array_search($id, $ids, true);
if ($pos === false) shop_json_error(404, 'not found');

$swapPos = $direction === 'up' ? $pos - 1 : $pos + 1;
if ($swapPos >= 0 && $swapPos < count($ids)) {
    [$ids[$pos], $ids[$swapPos]] = [$ids[$swapPos], $ids[$pos]];
}
$stmt = $mysqli->prepare('UPDATE shop_categories SET sort_order = ? WHERE id = ?');
foreach ($ids as $i => $catId) {
    $stmt->bind_param('ii', $i, $catId);
    $stmt->execute();
}

echo json_encode(['ok' => true]);
