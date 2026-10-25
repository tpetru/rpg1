<?php
// Sterge un document. AJAX + raspuns JSON.
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

docs_require_doc_access($mysqli, $id);

$delTasks = $mysqli->prepare('DELETE FROM docs_tasks WHERE doc_id = ?');
$delTasks->bind_param('i', $id);
$delTasks->execute();

$stmt = $mysqli->prepare('DELETE FROM docs_items WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

echo json_encode(['ok' => true]);
