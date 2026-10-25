<?php
// Editeaza o masa existenta. Sursa e exact una dintre: aliment, reteta, sau text custom.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_update_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    aris_update_fail('bad_id');
}

aris_ensure_tables($mysqli);

$mealDate = trim($_POST['meal_date'] ?? '');
$mealDateTs = DateTime::createFromFormat('Y-m-d', $mealDate);
if (!$mealDateTs || $mealDateTs->format('Y-m-d') !== $mealDate) {
    aris_update_fail('bad_date');
}

$source = $_POST['source'] ?? 'food';
$foodId = null;
$recipeId = null;
$customText = null;

if ($source === 'food') {
    $fid = (int)($_POST['food_id'] ?? 0);
    if ($fid <= 0) aris_update_fail('bad_food');
    $check = $mysqli->prepare('SELECT id FROM aris_foods WHERE id = ?');
    $check->bind_param('i', $fid);
    $check->execute();
    if ($check->get_result()->num_rows === 0) aris_update_fail('bad_food');
    $foodId = $fid;
} elseif ($source === 'recipe') {
    $rid = (int)($_POST['recipe_id'] ?? 0);
    if ($rid <= 0) aris_update_fail('bad_recipe');
    $check = $mysqli->prepare('SELECT id FROM aris_recipes WHERE id = ?');
    $check->bind_param('i', $rid);
    $check->execute();
    if ($check->get_result()->num_rows === 0) aris_update_fail('bad_recipe');
    $recipeId = $rid;
} elseif ($source === 'custom') {
    $text = trim($_POST['custom_text'] ?? '');
    if ($text === '') aris_update_fail('bad_custom');
    if (mb_strlen($text) > ARIS_CUSTOM_TEXT_MAX) $text = mb_substr($text, 0, ARIS_CUSTOM_TEXT_MAX);
    $customText = $text;
} else {
    aris_update_fail('bad_source');
}

$quantity = trim($_POST['quantity'] ?? '');
if (mb_strlen($quantity) > ARIS_QUANTITY_MAX) $quantity = mb_substr($quantity, 0, ARIS_QUANTITY_MAX);
$quantityOrNull = $quantity === '' ? null : $quantity;

$notes = trim($_POST['notes'] ?? '');
if (mb_strlen($notes) > ARIS_NOTES_MAX) $notes = mb_substr($notes, 0, ARIS_NOTES_MAX);
$notesOrNull = $notes === '' ? null : $notes;

$stmt = $mysqli->prepare('UPDATE aris_meals SET meal_date = ?, food_id = ?, recipe_id = ?, custom_text = ?, quantity = ?, notes = ? WHERE id = ?');
$stmt->bind_param('siisssi', $mealDate, $foodId, $recipeId, $customText, $quantityOrNull, $notesOrNull, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
