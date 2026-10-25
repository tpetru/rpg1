<?php
// Adauga o firma noua. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);
docs_require_full_access();

header('Content-Type: application/json');

$name = trim($_POST['name'] ?? '');
if ($name === '' || mb_strlen($name) > DOCS_COMPANY_NAME_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_name']);
    exit;
}

$maxOrder = -1;
$orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM docs_companies');
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$stmt = $mysqli->prepare('INSERT INTO docs_companies (name, sort_order) VALUES (?, ?)');
$stmt->bind_param('si', $name, $nextOrder);
if (!$stmt->execute()) {
    // Most likely the UNIQUE(name) constraint - a company with this name already exists.
    echo json_encode(['ok' => false, 'error' => 'duplicate']);
    exit;
}

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id, 'name' => $name]);
