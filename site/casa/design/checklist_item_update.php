<?php
require_once __DIR__ . '/../_auth.php';
// AJAX endpoint for a single checklist item's editable fields (name, Cumpărat/Montat checkboxes,
// estimated/real cost) - one generic endpoint instead of one per field, same pattern as
// casa_price_products' inline editing elsewhere in this module.
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$field = $_POST['field'] ?? '';
$value = $_POST['value'] ?? '';

$allowedFields = ['name', 'cumparat', 'montat', 'price_estimate', 'price_actual'];
if ($id <= 0 || !in_array($field, $allowedFields, true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

if ($field === 'name') {
    $name = trim((string)$value);
    if ($name === '' || mb_strlen($name) > 150) {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'invalid name']);
        exit;
    }
    $stmt = $mysqli->prepare("UPDATE casa_design_checklist_items SET name = ? WHERE id = ? AND house_id = ?");
    $stmt->bind_param('sii', $name, $id, $houseId);
} elseif ($field === 'cumparat' || $field === 'montat') {
    $done = $value === '1' ? 1 : 0;
    $stmt = $mysqli->prepare("UPDATE casa_design_checklist_items SET `$field` = ? WHERE id = ? AND house_id = ?");
    $stmt->bind_param('iii', $done, $id, $houseId);
} else {
    $price = (float)$value;
    if ($price < 0) $price = 0;
    $stmt = $mysqli->prepare("UPDATE casa_design_checklist_items SET `$field` = ? WHERE id = ? AND house_id = ?");
    $stmt->bind_param('dii', $price, $id, $houseId);
}
$stmt->execute();

if ($stmt->affected_rows === 0) {
    // Fie id-ul nu exista, fie apartine altei case - oricum, nu confirmam o salvare care n-a avut loc.
    $checkStmt = $mysqli->prepare('SELECT id FROM casa_design_checklist_items WHERE id = ? AND house_id = ?');
    $checkStmt->bind_param('ii', $id, $houseId);
    $checkStmt->execute();
    if (!$checkStmt->get_result()->fetch_assoc()) {
        http_response_code(404);
        echo json_encode(['ok' => false, 'error' => 'not found']);
        exit;
    }
}

echo json_encode(['ok' => true]);
