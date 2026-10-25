<?php
// Comuta steagul "prioritar" (coroana) al unui produs urmărit. AJAX + JSON.
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS priority TINYINT(1) NOT NULL DEFAULT 0 AFTER comment');

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid id']);
    exit;
}

$stmt = $mysqli->prepare('UPDATE casa_price_products SET priority = 1 - priority WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $id, $houseId);
$stmt->execute();

if ($stmt->affected_rows === 0) {
    // Fie nu exista, fie house_id nu se potriveste (nicio schimbare de fapt daca priority
    // ramanea aceeasi valoare, dar toggle-ul mereu schimba valoarea, deci 0 inseamna "nu era al meu").
    $check = $mysqli->prepare('SELECT priority FROM casa_price_products WHERE id = ? AND house_id = ?');
    $check->bind_param('ii', $id, $houseId);
    $check->execute();
    $row = $check->get_result()->fetch_assoc();
    if (!$row) {
        http_response_code(404);
        echo json_encode(['ok' => false, 'error' => 'not_found']);
        exit;
    }
    echo json_encode(['ok' => true, 'priority' => (bool)$row['priority']]);
    exit;
}

$stmt = $mysqli->prepare('SELECT priority FROM casa_price_products WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

echo json_encode(['ok' => true, 'priority' => (bool)$row['priority']]);
