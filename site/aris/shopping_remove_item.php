<?php
// Scoate un articol din lista de cumparaturi a unei saptamani. Pentru un aliment derivat dintr-o
// reteta doar il ascunde pentru saptamana asta (retetele raman neschimbate); pentru un articol
// adaugat manual il sterge de tot. AJAX + JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_shopping_remove_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$type = trim($_POST['type'] ?? '');
$id = (int)($_POST['id'] ?? 0);
if ($id <= 0 || !in_array($type, ['food', 'extra'], true)) {
    aris_shopping_remove_fail('bad_item');
}

$weekStart = trim($_POST['week_start'] ?? '');
$weekStartTs = DateTime::createFromFormat('Y-m-d', $weekStart);
if (!$weekStartTs || $weekStartTs->format('Y-m-d') !== $weekStart) {
    aris_shopping_remove_fail('bad_week');
}

aris_ensure_tables($mysqli);

if ($type === 'extra') {
    $stmt = $mysqli->prepare('DELETE FROM aris_shopping_extra WHERE id = ? AND week_start = ?');
    $stmt->bind_param('is', $id, $weekStart);
    $stmt->execute();
} else {
    $stmt = $mysqli->prepare(
        'INSERT INTO aris_shopping_removed (food_id, week_start) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE food_id = food_id'
    );
    $stmt->bind_param('is', $id, $weekStart);
    $stmt->execute();
}

echo json_encode(['ok' => true]);
