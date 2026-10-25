<?php
// Adauga un articol manual pe lista de cumparaturi a unei saptamani (nu vine dintr-o reteta).
// AJAX + JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_shopping_add_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$name = trim($_POST['name'] ?? '');
if ($name === '') {
    aris_shopping_add_fail('bad_name');
}
if (mb_strlen($name) > ARIS_FOOD_NAME_MAX) {
    $name = mb_substr($name, 0, ARIS_FOOD_NAME_MAX);
}

$weekStart = trim($_POST['week_start'] ?? '');
$weekStartTs = DateTime::createFromFormat('Y-m-d', $weekStart);
if (!$weekStartTs || $weekStartTs->format('Y-m-d') !== $weekStart) {
    aris_shopping_add_fail('bad_week');
}

aris_ensure_tables($mysqli);

$stmt = $mysqli->prepare('INSERT INTO aris_shopping_extra (week_start, name) VALUES (?, ?)');
$stmt->bind_param('ss', $weekStart, $name);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
