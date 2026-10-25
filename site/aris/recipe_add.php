<?php
// Adauga o reteta noua (nume + lista de alimente cu gramaj). AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_recipe_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

aris_ensure_tables($mysqli);

$name = trim($_POST['name'] ?? '');
if ($name === '' || mb_strlen($name) > ARIS_RECIPE_NAME_MAX) {
    aris_recipe_fail('bad_name');
}

$foodNames = $_POST['food_name'] ?? [];
$grams = $_POST['grams'] ?? [];
if (!is_array($foodNames) || !is_array($grams) || count($foodNames) === 0) {
    aris_recipe_fail('no_ingredients');
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
    aris_recipe_fail('no_ingredients');
}

$stmt = $mysqli->prepare('INSERT INTO aris_recipes (name) VALUES (?)');
$stmt->bind_param('s', $name);
$stmt->execute();
$recipeId = $mysqli->insert_id;

$itemStmt = $mysqli->prepare('INSERT INTO aris_recipe_items (recipe_id, food_id, grams, sort_order) VALUES (?, ?, ?, ?)');
foreach ($items as $i => $item) {
    $itemStmt->bind_param('iiii', $recipeId, $item['food_id'], $item['grams'], $i);
    $itemStmt->execute();
}

echo json_encode(['ok' => true, 'id' => $recipeId]);
