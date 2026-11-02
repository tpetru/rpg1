<?php
// Sterge mai multe intrari din istoricul de pret dintr-o data ("Șterge selectate").
require_once __DIR__ . '/_api.php';

$ids = array_values(array_unique(array_filter(array_map('intval', explode(',', (string)($_POST['ids'] ?? ''))), function ($id) {
    return $id > 0;
})));
if (!$ids) shop_json_error(400, 'no ids');

$placeholders = implode(',', array_fill(0, count($ids), '?'));
$stmt = $mysqli->prepare("DELETE FROM shop_price_history WHERE id IN ($placeholders)");
$stmt->bind_param(str_repeat('i', count($ids)), ...$ids);
$stmt->execute();

echo json_encode(['ok' => true, 'deleted' => $stmt->affected_rows]);
