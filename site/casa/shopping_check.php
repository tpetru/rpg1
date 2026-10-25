<?php
require_once __DIR__ . '/_auth.php';
// Fetches every tracked product page and records today's price. Runs synchronously on the button
// click - fine for a household-sized list; each fetch gets its own short timeout so one dead shop
// can't hang the whole run. The actual scraping lives in _price_check.php, shared with
// cron_check_all.php (the daily scheduled check for every house).
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
require_once __DIR__ . '/_price_check.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];

header('Content-Type: application/json');
set_time_limit(300);

casa_ensure_price_history_table($mysqli);

$onlyId = (int)($_POST['id'] ?? 0);
if ($onlyId > 0) {
    $stmt = $mysqli->prepare('SELECT id, name, url FROM casa_price_products WHERE id = ? AND house_id = ?');
    $stmt->bind_param('ii', $onlyId, $houseId);
    $stmt->execute();
    $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
} else {
    $stmt = $mysqli->prepare('SELECT id, name, url FROM casa_price_products WHERE house_id = ? ORDER BY sort_order, id');
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $res = $stmt->get_result();
    $products = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
}

$results = [];
foreach ($products as $product) {
    $result = casa_check_product_price($mysqli, (int)$product['id'], $product['url']);
    $result['name'] = $product['name'];
    $results[] = $result;
}

echo json_encode(['ok' => true, 'checked' => count($results), 'results' => $results]);
