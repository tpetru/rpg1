<?php
// Seteaza/schimba/sterge parola de acces a unei firme. AJAX + raspuns JSON.
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

$password = trim($_POST['password'] ?? '');
if (mb_strlen($password) > DOCS_COMPANY_PASSWORD_MAX) {
    echo json_encode(['ok' => false, 'error' => 'bad_password']);
    exit;
}
// Nu poate fi parola master (ar suprascrie mereu rolul complet la login) si nici goala->duplicat.
if ($password !== '' && hash_equals(DOCS_MASTER_PASSWORD, $password)) {
    echo json_encode(['ok' => false, 'error' => 'reserved_password']);
    exit;
}

if ($password !== '') {
    $dup = $mysqli->prepare("SELECT id FROM docs_companies WHERE password = ? AND id != ? LIMIT 1");
    $dup->bind_param('si', $password, $id);
    $dup->execute();
    if ($dup->get_result()->num_rows > 0) {
        echo json_encode(['ok' => false, 'error' => 'duplicate_password']);
        exit;
    }
}

$passwordOrNull = $password !== '' ? $password : null;
$stmt = $mysqli->prepare('UPDATE docs_companies SET password = ? WHERE id = ?');
$stmt->bind_param('si', $passwordOrNull, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
