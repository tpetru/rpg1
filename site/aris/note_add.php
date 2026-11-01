<?php
// Adauga o notita libera pe /aris/notite.php. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

aris_require_api_auth();

header('Content-Type: application/json');

$body = trim($_POST['body'] ?? '');
if ($body === '' || mb_strlen($body) > ARIS_FREE_NOTE_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_body']);
    exit;
}

aris_ensure_tables($mysqli);

$createdAt = aris_now_local();
$stmt = $mysqli->prepare('INSERT INTO aris_notes (body, created_at) VALUES (?, ?)');
$stmt->bind_param('ss', $body, $createdAt);
if (!$stmt->execute()) {
    echo json_encode(['ok' => false, 'error' => 'db']);
    exit;
}

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
