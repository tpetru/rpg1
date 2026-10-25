<?php
// Adauga un aliment nou pe lista de alergeni de urmarit. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$foodId = (int)($_POST['food_id'] ?? 0);
if ($foodId <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_food']);
    exit;
}

aris_ensure_tables($mysqli);

$check = $mysqli->prepare('SELECT id FROM aris_foods WHERE id = ?');
$check->bind_param('i', $foodId);
$check->execute();
if ($check->get_result()->num_rows === 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_food']);
    exit;
}

$maxOrder = -1;
$orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM aris_allergens');
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$stmt = $mysqli->prepare('INSERT INTO aris_allergens (food_id, sort_order) VALUES (?, ?)');
$stmt->bind_param('ii', $foodId, $nextOrder);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
