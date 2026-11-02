<?php
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) shop_json_error(400, 'invalid id');

$stmt = $mysqli->prepare('DELETE FROM shop_products WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    $stmt = $mysqli->prepare('DELETE FROM shop_price_history WHERE product_id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
}

echo json_encode(['ok' => true]);
