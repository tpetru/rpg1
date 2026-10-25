<?php
// Editeaza un rand din lista de alergeni (aliment, bifa, data, reactie). AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

function aris_allergen_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    aris_allergen_fail('bad_id');
}

aris_ensure_tables($mysqli);

$foodId = (int)($_POST['food_id'] ?? 0);
if ($foodId <= 0) aris_allergen_fail('bad_food');
$check = $mysqli->prepare('SELECT id FROM aris_foods WHERE id = ?');
$check->bind_param('i', $foodId);
$check->execute();
if ($check->get_result()->num_rows === 0) aris_allergen_fail('bad_food');

$isGiven = (int)($_POST['is_given'] ?? 0) === 1 ? 1 : 0;

$usedOn = trim($_POST['used_on'] ?? '');
$usedOnOrNull = null;
if ($usedOn !== '') {
    $usedOnTs = DateTime::createFromFormat('Y-m-d', $usedOn);
    if (!$usedOnTs || $usedOnTs->format('Y-m-d') !== $usedOn) {
        aris_allergen_fail('bad_date');
    }
    $usedOnOrNull = $usedOn;
}

$reaction = trim($_POST['reaction'] ?? '');
if (mb_strlen($reaction) > ARIS_REACTION_MAX) $reaction = mb_substr($reaction, 0, ARIS_REACTION_MAX);
$reactionOrNull = $reaction === '' ? null : $reaction;

$stmt = $mysqli->prepare('UPDATE aris_allergens SET food_id = ?, is_given = ?, used_on = ?, reaction = ? WHERE id = ?');
$stmt->bind_param('iissi', $foodId, $isGiven, $usedOnOrNull, $reactionOrNull, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
