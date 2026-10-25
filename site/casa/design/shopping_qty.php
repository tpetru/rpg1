<?php
require_once __DIR__ . '/../_auth.php';
// AJAX endpoint for the Cantitate input in a design room's Shopping tab - the quantity lives on
// the casa_price_products row so shopping.php and the design page share the same product list.
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
$houseId = $currentHouse['id'];

header('Content-Type: application/json');

$productId = (int)($_POST['id'] ?? 0);
$qtyRaw = str_replace(',', '.', trim((string)($_POST['quantity'] ?? '')));

if ($productId <= 0 || !is_numeric($qtyRaw) || (float)$qtyRaw < 0 || (float)$qtyRaw > 99999) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid id/quantity']);
    exit;
}
$qty = round((float)$qtyRaw, 2);

$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS quantity DECIMAL(10,2) NOT NULL DEFAULT 1');

$stmt = $mysqli->prepare('UPDATE casa_price_products SET quantity = ? WHERE id = ? AND house_id = ?');
$stmt->bind_param('dii', $qty, $productId, $houseId);
$stmt->execute();

echo json_encode(['ok' => true, 'quantity' => $qty]);
