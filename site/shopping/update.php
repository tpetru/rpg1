<?php
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) shop_json_error(400, 'invalid id');
$in = shop_product_input($mysqli);

$stmt = $mysqli->prepare('UPDATE shop_products SET name = ?, url = ?, category_id = ?, tags = ?, comment = ? WHERE id = ?');
$stmt->bind_param('ssissi', $in['name'], $in['url'], $in['category_id'], $in['tags'], $in['comment'], $id);
$stmt->execute();

echo json_encode(['ok' => true]);
