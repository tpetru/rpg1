<?php
// Bifeaza / debifeaza rapid "i-a fost dat deja" pentru un alergen, fara sa deschizi formularul de
// editare. Data si reactia raman salvate chiar daca debifezi (nu se sterg), ca sa nu pierzi notele
// daca ai bifat din greseala.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$isGiven = (int)($_POST['is_given'] ?? 0) === 1 ? 1 : 0;
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

aris_ensure_tables($mysqli);

$stmt = $mysqli->prepare('UPDATE aris_allergens SET is_given = ? WHERE id = ?');
$stmt->bind_param('ii', $isGiven, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
