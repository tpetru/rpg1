<?php
// Comuta marcajul DA/NU "e alergic confirmat" pentru un aliment. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$isAllergic = (int)($_POST['is_allergic'] ?? 0) === 1 ? 1 : 0;
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

aris_ensure_tables($mysqli);

$stmt = $mysqli->prepare('UPDATE aris_foods SET is_allergic = ? WHERE id = ?');
$stmt->bind_param('ii', $isAllergic, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
