<?php
// Verificare zilnica de preturi pentru TOATE casele - rulat printr-un Windows Scheduled Task
// (php.exe cron_check_all.php), nu accesat din browser. Spre deosebire de shopping_check.php (care
// verifica doar produsele casei in care esti logat), aici nu exista o "casa curenta" - se
// verifica fiecare produs din fiecare casa, la rand. Logica de extragere a pretului e in
// _price_check.php, ca sa ramana identica cu verificarea manuala din UI.
if (php_sapi_name() !== 'cli') {
    http_response_code(403);
    exit('CLI only');
}

require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_price_check.php';

casa_ensure_price_history_table($mysqli);

$res = $mysqli->query('SELECT id, name, url, house_id FROM casa_price_products ORDER BY house_id, sort_order, id');
$products = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];

$checkedOk = 0;
$checkedFail = 0;
$startedAt = date('Y-m-d H:i:s');
echo "[$startedAt] Verificare preturi - " . count($products) . " produse gasite" . PHP_EOL;

foreach ($products as $product) {
    $result = casa_check_product_price($mysqli, (int)$product['id'], $product['url']);
    if ($result['ok']) {
        $checkedOk++;
        echo "  OK  #{$product['id']} ({$product['name']}): {$result['price']} {$result['currency']}" . PHP_EOL;
    } else {
        $checkedFail++;
        echo "  ERR #{$product['id']} ({$product['name']}): {$result['error']}" . PHP_EOL;
    }
    // Scurta pauza intre cereri, ca sa nu bombardam mai multe magazine deodata cu request-uri
    // consecutive fara nicio intarziere.
    usleep(500000);
}

$finishedAt = date('Y-m-d H:i:s');
echo "[$finishedAt] Gata - $checkedOk reusite, $checkedFail esuate." . PHP_EOL;
