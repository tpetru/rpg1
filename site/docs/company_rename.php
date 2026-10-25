<?php
// Redenumeste o firma existenta. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);
docs_require_full_access();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$name = trim($_POST['name'] ?? '');
if ($id <= 0 || $name === '' || mb_strlen($name) > DOCS_COMPANY_NAME_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_input']);
    exit;
}

$stmt = $mysqli->prepare('UPDATE docs_companies SET name = ? WHERE id = ?');
$stmt->bind_param('si', $name, $id);
if (!$stmt->execute()) {
    echo json_encode(['ok' => false, 'error' => 'duplicate']);
    exit;
}

echo json_encode(['ok' => true]);
