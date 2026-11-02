<?php
require_once __DIR__ . '/_api.php';

$name = trim($_POST['name'] ?? '');
$icon = trim($_POST['icon'] ?? '');
if ($name === '' || mb_strlen($name) > SHOP_CATEGORY_NAME_MAX || mb_strlen($icon) > SHOP_CATEGORY_ICON_MAX) {
    shop_json_error(400, 'invalid input');
}
$iconOrNull = $icon === '' ? null : $icon;

$stmt = $mysqli->prepare('SELECT id FROM shop_categories WHERE name = ?');
$stmt->bind_param('s', $name);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) shop_json_error(409, 'exists');

$res = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS m FROM shop_categories');
$nextOrder = (int)$res->fetch_assoc()['m'] + 1;

$stmt = $mysqli->prepare('INSERT INTO shop_categories (name, icon, sort_order) VALUES (?, ?, ?)');
$stmt->bind_param('ssi', $name, $iconOrNull, $nextOrder);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => (int)$mysqli->insert_id]);
