<?php
// Redenumeste o categorie / ii schimba emoji-ul.
require_once __DIR__ . '/_api.php';

$id = (int)($_POST['id'] ?? 0);
$name = trim($_POST['name'] ?? '');
$icon = trim($_POST['icon'] ?? '');
if ($id <= 0 || $name === '' || mb_strlen($name) > SHOP_CATEGORY_NAME_MAX || mb_strlen($icon) > SHOP_CATEGORY_ICON_MAX) {
    shop_json_error(400, 'invalid input');
}
$iconOrNull = $icon === '' ? null : $icon;

$stmt = $mysqli->prepare('SELECT id FROM shop_categories WHERE name = ? AND id <> ?');
$stmt->bind_param('si', $name, $id);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) shop_json_error(409, 'exists');

$stmt = $mysqli->prepare('UPDATE shop_categories SET name = ?, icon = ? WHERE id = ?');
$stmt->bind_param('ssi', $name, $iconOrNull, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
