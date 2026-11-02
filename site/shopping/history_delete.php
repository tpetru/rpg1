<?php
// Sterge o intrare din istoricul de pret al unui produs (din pagina de detaliu).
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) shop_json_error(400, 'invalid id');

$stmt = $mysqli->prepare('DELETE FROM shop_price_history WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

echo json_encode(['ok' => true]);
