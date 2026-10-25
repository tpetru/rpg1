<?php
// Comuta starea unui task intre complet / incomplet. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

$check = $mysqli->prepare('SELECT doc_id, completed_at FROM docs_tasks WHERE id = ?');
$check->bind_param('i', $id);
$check->execute();
$row = $check->get_result()->fetch_assoc();
if (!$row) {
    echo json_encode(['ok' => false, 'error' => 'not_found']);
    exit;
}
docs_require_doc_access($mysqli, (int)$row['doc_id']);

if ($row['completed_at'] !== null) {
    $stmt = $mysqli->prepare('UPDATE docs_tasks SET completed_at = NULL WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    echo json_encode(['ok' => true, 'completed_at' => null]);
} else {
    $today = date('Y-m-d');
    $stmt = $mysqli->prepare('UPDATE docs_tasks SET completed_at = ? WHERE id = ?');
    $stmt->bind_param('si', $today, $id);
    $stmt->execute();
    echo json_encode(['ok' => true, 'completed_at' => $today]);
}
