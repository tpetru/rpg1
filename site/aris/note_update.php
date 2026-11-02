<?php
// Editeaza o notita libera de pe /aris/notite.php (text + data notitei). AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$body = trim($_POST['body'] ?? '');
if ($id <= 0 || $body === '' || mb_strlen($body) > ARIS_FREE_NOTE_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_input']);
    exit;
}

aris_ensure_tables($mysqli);

$noteDate = aris_clean_note_date($_POST['note_date'] ?? '');
$stmt = $mysqli->prepare('UPDATE aris_notes SET body = ?, note_date = ? WHERE id = ?');
$stmt->bind_param('ssi', $body, $noteDate, $id);
if (!$stmt->execute()) {
    echo json_encode(['ok' => false, 'error' => 'db']);
    exit;
}

echo json_encode(['ok' => true]);
