<?php
// Sterge un aliment din lista. Mesele care il foloseau raman (devin "aliment sters"), nu se sterg.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

aris_ensure_tables($mysqli);

$unlink = $mysqli->prepare('UPDATE aris_meals SET food_id = NULL WHERE food_id = ?');
$unlink->bind_param('i', $id);
$unlink->execute();

$unlinkItems = $mysqli->prepare('UPDATE aris_recipe_items SET food_id = NULL WHERE food_id = ?');
$unlinkItems->bind_param('i', $id);
$unlinkItems->execute();

$unlinkAllergens = $mysqli->prepare('UPDATE aris_allergens SET food_id = NULL WHERE food_id = ?');
$unlinkAllergens->bind_param('i', $id);
$unlinkAllergens->execute();

$del = $mysqli->prepare('DELETE FROM aris_foods WHERE id = ?');
$del->bind_param('i', $id);
$del->execute();

echo json_encode(['ok' => true]);
