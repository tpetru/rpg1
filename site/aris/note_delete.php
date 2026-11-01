<?php
// Sterge o notita libera de pe /aris/notite.php. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    echo json_encode(['ok' => false, 'error' => 'bad_id']);
    exit;
}

aris_ensure_tables($mysqli);

$del = $mysqli->prepare('DELETE FROM aris_notes WHERE id = ?');
$del->bind_param('i', $id);
$del->execute();

echo json_encode(['ok' => true]);
