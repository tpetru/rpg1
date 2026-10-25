<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];
// AJAX (not a full page POST + redirect) - deleting an item shouldn't reload the page and collapse
// whatever tab/spoiler the user had open elsewhere on it.
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);

$stmt = $mysqli->prepare('DELETE FROM casa_design_checklist_items WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
