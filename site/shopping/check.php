<?php
// Verifica pretul unui produs (id) sau al tuturor, sincron, la click. Fiecare fetch are timeout
// scurt (vezi casa_fetch_page), deci un magazin picat nu blocheaza toata rularea.
require_once __DIR__ . '/_api.php';
set_time_limit(300);

$onlyId = (int)($_POST['id'] ?? 0);
if ($onlyId > 0) {
    $stmt = $mysqli->prepare('SELECT id, name, url FROM shop_products WHERE id = ?');
    $stmt->bind_param('i', $onlyId);
    $stmt->execute();
    $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
} else {
    $res = $mysqli->query('SELECT id, name, url FROM shop_products ORDER BY sort_order, id');
    $products = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
}

$results = [];
foreach ($products as $product) {
    $result = shop_check_product_price($mysqli, (int)$product['id'], $product['url']);
    $result['name'] = $product['name'];
    $results[] = $result;
}

echo json_encode(['ok' => true, 'checked' => count($results), 'results' => $results]);
