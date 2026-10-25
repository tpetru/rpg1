<?php
// Sterge o firma. Documentele care o foloseau raman (devin "Fara firma"), nu se sterg.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);
docs_require_full_access();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

$unlink = $mysqli->prepare('UPDATE docs_items SET company_id = NULL WHERE company_id = ?');
$unlink->bind_param('i', $id);
$unlink->execute();

$del = $mysqli->prepare('DELETE FROM docs_companies WHERE id = ?');
$del->bind_param('i', $id);
$del->execute();

echo json_encode(['ok' => true]);
