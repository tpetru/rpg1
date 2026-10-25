<?php
// Redenumeste un aliment existent. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$name = trim($_POST['name'] ?? '');
if ($id <= 0 || $name === '' || mb_strlen($name) > ARIS_FOOD_NAME_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_input']);
    exit;
}

aris_ensure_tables($mysqli);

$stmt = $mysqli->prepare('UPDATE aris_foods SET name = ? WHERE id = ?');
$stmt->bind_param('si', $name, $id);
if (!$stmt->execute()) {
    echo json_encode(['ok' => false, 'error' => 'duplicate']);
    exit;
}

echo json_encode(['ok' => true]);
