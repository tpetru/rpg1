<?php
// Sterge o reteta. Mesele care o foloseau raman (devin "reteta stearsa"), nu se sterg.
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

$unlink = $mysqli->prepare('UPDATE aris_meals SET recipe_id = NULL WHERE recipe_id = ?');
$unlink->bind_param('i', $id);
$unlink->execute();

$delItems = $mysqli->prepare('DELETE FROM aris_recipe_items WHERE recipe_id = ?');
$delItems->bind_param('i', $id);
$delItems->execute();

$del = $mysqli->prepare('DELETE FROM aris_recipes WHERE id = ?');
$del->bind_param('i', $id);
$del->execute();

echo json_encode(['ok' => true]);
