<?php
// Adauga un task nou pe un document. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);

header('Content-Type: application/json');

$docId = (int)($_POST['doc_id'] ?? 0);
$text = trim($_POST['text'] ?? '');
if ($docId <= 0 || $text === '') {
    echo json_encode(['ok' => false, 'error' => 'bad_input']);
    exit;
}
if (mb_strlen($text) > DOCS_TASK_TEXT_MAX) {
    $text = mb_substr($text, 0, DOCS_TASK_TEXT_MAX);
}

$check = $mysqli->prepare('SELECT id FROM docs_items WHERE id = ?');
$check->bind_param('i', $docId);
$check->execute();
if ($check->get_result()->num_rows === 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_doc']);
    exit;
}
docs_require_doc_access($mysqli, $docId);

$maxOrder = -1;
$orderStmt = $mysqli->prepare('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM docs_tasks WHERE doc_id = ?');
$orderStmt->bind_param('i', $docId);
$orderStmt->execute();
$orderRes = $orderStmt->get_result();
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$stmt = $mysqli->prepare('INSERT INTO docs_tasks (doc_id, text, sort_order) VALUES (?, ?, ?)');
$stmt->bind_param('isi', $docId, $text, $nextOrder);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id, 'text' => $text, 'completed_at' => null]);
