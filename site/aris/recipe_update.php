<?php
// Editeaza o reteta (nume + lista de alimente cu gramaj - inlocuieste ingredientele existente).
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_recipe_update_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    aris_recipe_update_fail('bad_id');
}

aris_ensure_tables($mysqli);

$name = trim($_POST['name'] ?? '');
if ($name === '' || mb_strlen($name) > ARIS_RECIPE_NAME_MAX) {
    aris_recipe_update_fail('bad_name');
}

$foodNames = $_POST['food_name'] ?? [];
$grams = $_POST['grams'] ?? [];
if (!is_array($foodNames) || !is_array($grams)) {
    aris_recipe_update_fail('no_ingredients');
}

$items = [];
foreach ($foodNames as $i => $ingredientName) {
    $ingredientName = trim((string)$ingredientName);
    if ($ingredientName === '') continue;
    $fid = aris_find_or_create_food($mysqli, $ingredientName);
    if ($fid === null) continue;
    $g = isset($grams[$i]) ? (int)$grams[$i] : null;
    if ($g !== null && $g <= 0) $g = null;
    $items[] = ['food_id' => $fid, 'grams' => $g];
}
if (empty($items)) {
    aris_recipe_update_fail('no_ingredients');
}

$stmt = $mysqli->prepare('UPDATE aris_recipes SET name = ? WHERE id = ?');
$stmt->bind_param('si', $name, $id);
$stmt->execute();

$del = $mysqli->prepare('DELETE FROM aris_recipe_items WHERE recipe_id = ?');
$del->bind_param('i', $id);
$del->execute();

$itemStmt = $mysqli->prepare('INSERT INTO aris_recipe_items (recipe_id, food_id, grams, sort_order) VALUES (?, ?, ?, ?)');
foreach ($items as $i => $item) {
    $itemStmt->bind_param('iiii', $id, $item['food_id'], $item['grams'], $i);
    $itemStmt->execute();
}

echo json_encode(['ok' => true]);
