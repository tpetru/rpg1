<?php
// Adauga un document nou. AJAX + raspuns JSON.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
docs_require_api_auth($mysqli);

header('Content-Type: application/json');

function docs_fail(string $reason): void
{
    echo json_encode(['ok' => false, 'error' => $reason]);
    exit;
}

$name = trim($_POST['name'] ?? '');
if ($name === '') {
    docs_fail('bad_name');
}
if (mb_strlen($name) > DOCS_NAME_MAX) {
    $name = mb_substr($name, 0, DOCS_NAME_MAX);
}

$lockedCompanyId = docs_locked_company_id();
if ($lockedCompanyId !== null) {
    // Locked role: the document is always filed under its own company, regardless of what
    // (if anything) the client sent - the company select is disabled client-side for this reason.
    if ($lockedCompanyId < 0) docs_fail('locked_company_missing');
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
    docs_fail('bad_date');
}

$stmt = $mysqli->prepare('INSERT INTO docs_items (name, company_id, expires_at) VALUES (?, ?, ?)');
$stmt->bind_param('sis', $name, $companyIdOrNull, $expiresAt);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
