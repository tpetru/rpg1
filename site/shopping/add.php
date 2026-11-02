<?php
require_once __DIR__ . '/_api.php';

$in = shop_product_input($mysqli);
$catId = $in['category_id'];

$stmt = $mysqli->prepare('SELECT COALESCE(MAX(sort_order), 0) AS m FROM shop_products WHERE category_id <=> ?');
$stmt->bind_param('i', $catId);
$stmt->execute();
$nextOrder = (int)$stmt->get_result()->fetch_assoc()['m'] + 1;

$stmt = $mysqli->prepare('INSERT INTO shop_products (name, url, category_id, tags, comment, sort_order) VALUES (?, ?, ?, ?, ?, ?)');
$stmt->bind_param('ssissi', $in['name'], $in['url'], $catId, $in['tags'], $in['comment'], $nextOrder);
$stmt->execute();
$id = (int)$mysqli->insert_id;

// Primul pret se citeste imediat, ca produsul nou sa nu stea "Neverificat" pana la urmatoarea rulare.
$check = shop_check_product_price($mysqli, $id, $in['url']);
$check['name'] = $in['name'];

echo json_encode(['ok' => true, 'id' => $id, 'name' => $in['name'], 'check' => $check]);
