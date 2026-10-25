<?php
// Editeaza un document existent (nume, firma, data expirarii). AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);

header('Content-Type: application/json');

function docs_update_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    docs_update_fail('bad_id');
}

$name = trim($_POST['name'] ?? '');
if ($name === '') {
    docs_update_fail('bad_name');
}
if (mb_strlen($name) > DOCS_NAME_MAX) {
    $name = mb_substr($name, 0, DOCS_NAME_MAX);
}

docs_require_doc_access($mysqli, $id);

$lockedCompanyId = docs_locked_company_id();
if ($lockedCompanyId !== null) {
    // Locked role: can't move the document to another company - the select is disabled
    // client-side, and docs_require_doc_access() above already confirmed it's theirs.
    $companyIdOrNull = $lockedCompanyId;
} else {
    $companyId = (int)($_POST['company_id'] ?? 0);
    $companyIdOrNull = null;
    if ($companyId > 0) {
        $check = $mysqli->prepare('SELECT id FROM docs_companies WHERE id = ?');
        $check->bind_param('i', $companyId);
        $check->execute();
        if ($check->get_result()->num_rows > 0) {
            $companyIdOrNull = $companyId;
        }
    }
}

$expiresAt = trim($_POST['expires_at'] ?? '');
$expiresTs = DateTime::createFromFormat('Y-m-d', $expiresAt);
if (!$expiresTs || $expiresTs->format('Y-m-d') !== $expiresAt) {
    docs_update_fail('bad_date');
}

$stmt = $mysqli->prepare('UPDATE docs_items SET name = ?, company_id = ?, expires_at = ? WHERE id = ?');
$stmt->bind_param('sisi', $name, $companyIdOrNull, $expiresAt, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
