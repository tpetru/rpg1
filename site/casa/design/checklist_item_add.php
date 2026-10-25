<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/checklist_defs.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];
// AJAX (not a full page POST + redirect) - adding an item shouldn't reload the page and collapse
// whatever tab/spoiler the user had open elsewhere on it.
header('Content-Type: application/json');

$room = $_POST['room'] ?? '';
$category = $_POST['category'] ?? '';
$name = trim($_POST['name'] ?? '');
$cumparat = ($_POST['cumparat'] ?? '0') === '1' ? 1 : 0;
$montat = ($_POST['montat'] ?? '0') === '1' ? 1 : 0;
$priceEstimate = (float)($_POST['price_estimate'] ?? 0);
if ($priceEstimate < 0) $priceEstimate = 0;
$priceActual = (float)($_POST['price_actual'] ?? 0);
if ($priceActual < 0) $priceActual = 0;

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $room) && is_dir(casa_house_dir($currentHouse['slug']) . '/design/' . $room);
$validCategory = isset($casaChecklistDefs[$category]);

if (!$validRoom || !$validCategory || $name === '' || mb_strlen($name) > 150) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

casa_design_checklist_ensure_schema($mysqli, $casaChecklistDefs);

$stmt = $mysqli->prepare(
    'INSERT INTO casa_design_checklist_items (house_id, room_slug, category, name, cumparat, montat, price_estimate, price_actual)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
);
$stmt->bind_param('isssiidd', $houseId, $room, $category, $name, $cumparat, $montat, $priceEstimate, $priceActual);
$stmt->execute();

echo json_encode([
    'ok' => true,
    'item' => [
        'id' => $mysqli->insert_id,
        'name' => $name,
        'cumparat' => (bool)$cumparat,
        'montat' => (bool)$montat,
        'price_estimate' => $priceEstimate,
        'price_actual' => $priceActual,
    ],
]);
