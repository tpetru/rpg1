<?php
// Sterge o categorie. Produsele din ea NU se sterg - trec la "Fără categorie".
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
if ($id <= 0) shop_json_error(400, 'invalid id');

$stmt = $mysqli->prepare('UPDATE shop_products SET category_id = NULL WHERE category_id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

$stmt = $mysqli->prepare('DELETE FROM shop_categories WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();

echo json_encode(['ok' => true]);
