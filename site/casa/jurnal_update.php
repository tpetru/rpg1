<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$date = trim($_POST['date'] ?? '');
$title = trim($_POST['title'] ?? '');
$price = (float)($_POST['price'] ?? 0);
$comment = trim($_POST['comment'] ?? '');

$dateValid = (bool)preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) && strtotime($date) !== false;

if ($id <= 0 || !$dateValid || $title === '' || mb_strlen($title) > 150 || $price < 0 || mb_strlen($comment) > 256) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

$commentOrNull = $comment === '' ? null : $comment;
$stmt = $mysqli->prepare('UPDATE casa_journal SET entry_date = ?, title = ?, price = ?, comment = ? WHERE id = ? AND house_id = ?');
$stmt->bind_param('ssdsii', $date, $title, $price, $commentOrNull, $id, $houseId);
$stmt->execute();

echo json_encode(['ok' => true]);
