<?php
require_once __DIR__ . '/_auth.php';
casa_require_admin_api_auth();
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_suppliers.php';
casa_suppliers_ensure_table($mysqli);
// Sterge un furnizor. AJAX + raspuns JSON.
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$stmt = $mysqli->prepare('DELETE FROM casa_suppliers WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

echo json_encode(['ok' => true]);
