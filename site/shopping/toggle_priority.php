<?php
// Comuta steagul "prioritar" (coroana) al unui produs.
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) shop_json_error(400, 'invalid id');

$stmt = $mysqli->prepare('UPDATE shop_products SET priority = 1 - priority WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

$stmt = $mysqli->prepare('SELECT priority FROM shop_products WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
if (!$row) shop_json_error(404, 'not found');

echo json_encode(['ok' => true, 'priority' => (bool)$row['priority']]);
