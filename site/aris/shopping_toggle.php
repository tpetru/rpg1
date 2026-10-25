<?php
// Comuta AVEM / NU AVEM pentru un articol din lista de cumparaturi a unei saptamani (fie un
// aliment derivat din retete, fie un articol adaugat manual). AJAX + JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_shopping_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$type = trim($_POST['type'] ?? 'food');
$id = (int)($_POST['id'] ?? 0);
if ($id <= 0 || !in_array($type, ['food', 'extra'], true)) {
    aris_shopping_fail('bad_item');
}

$weekStart = trim($_POST['week_start'] ?? '');
$weekStartTs = DateTime::createFromFormat('Y-m-d', $weekStart);
if (!$weekStartTs || $weekStartTs->format('Y-m-d') !== $weekStart) {
    aris_shopping_fail('bad_week');
}

$haveIt = (int)($_POST['have_it'] ?? 0) === 1 ? 1 : 0;

aris_ensure_tables($mysqli);

if ($type === 'extra') {
    $stmt = $mysqli->prepare('UPDATE aris_shopping_extra SET have_it = ? WHERE id = ? AND week_start = ?');
    $stmt->bind_param('iis', $haveIt, $id, $weekStart);
    $stmt->execute();
} else {
    $stmt = $mysqli->prepare(
        'INSERT INTO aris_shopping_status (food_id, week_start, have_it) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE have_it = VALUES(have_it)'
    );
    $stmt->bind_param('isi', $id, $weekStart, $haveIt);
    $stmt->execute();
}

echo json_encode(['ok' => true]);
