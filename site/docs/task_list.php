<?php
// Lista task-urilor unui document. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);

header('Content-Type: application/json');

$docId = (int)($_GET['doc_id'] ?? $_POST['doc_id'] ?? 0);
if ($docId <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

docs_require_doc_access($mysqli, $docId);

$tasks = [];
$stmt = $mysqli->prepare('SELECT id, text, completed_at FROM docs_tasks WHERE doc_id = ? ORDER BY sort_order ASC, id ASC');
$stmt->bind_param('i', $docId);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    $tasks[] = [
        'id' => (int)$row['id'],
        'text' => $row['text'],
        'completed_at' => $row['completed_at'],
    ];
}

echo json_encode(['ok' => true, 'tasks' => $tasks]);
