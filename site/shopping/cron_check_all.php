<?php
// Verificarea zilnica a preturilor pentru toate produsele din /shopping.php - rulat din linia de
// comanda (cron pe server), nu din browser. Ex. crontab, in fiecare zi la 9:00:
//   0 9 * * * php /var/www/html/shopping/cron_check_all.php >> /var/log/shop_prices.log 2>&1
if (php_sapi_name() !== 'cli') {
    http_response_code(403);
    exit('CLI only');
}

require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';
shop_ensure_tables($mysqli);

$res = $mysqli->query('SELECT id, name, url FROM shop_products ORDER BY sort_order, id');
$products = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];

$okCount = 0;
$failCount = 0;
echo '[' . date('Y-m-d H:i:s') . '] Verificare preturi shopping - ' . count($products) . ' produse' . PHP_EOL;

foreach ($products as $product) {
    $result = shop_check_product_price($mysqli, (int)$product['id'], $product['url']);
    if ($result['ok']) {
        $okCount++;
        echo "  OK  #{$product['id']} ({$product['name']}): {$result['price']} {$result['currency']}" . PHP_EOL;
    } else {
        $failCount++;
        echo "  ERR #{$product['id']} ({$product['name']}): {$result['error']}" . PHP_EOL;
    }
    usleep(500000); // pauza scurta intre magazine
}

echo '[' . date('Y-m-d H:i:s') . "] Gata - $okCount reusite, $failCount esuate." . PHP_EOL;
