<?php
// Editeaza o intrare existenta din istoricul de pret. Editarea presupune mereu un pret valid, deci
// si o intrare marcata anterior ca eroare de verificare devine o intrare reusita (ok=1) dupa editare.
// AJAX + JSON.
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$houseId = casa_require_api_house_auth($mysqli)['id'];
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$price = (float)($_POST['price'] ?? -1);
$currency = trim($_POST['currency'] ?? '') ?: 'RON';
$checkedAt = trim($_POST['checked_at'] ?? '');

if ($id <= 0 || $price < 0 || mb_strlen($currency) > 8) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}
$checkedAtTs = DateTime::createFromFormat('Y-m-d\TH:i', $checkedAt);
if (!$checkedAtTs) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid date']);
    exit;
}
$checkedAtSql = $checkedAtTs->format('Y-m-d H:i:s');

// Verificam intai ca intrarea apartine unui produs din casa curenta, prin JOIN - casa_price_history
// n-are house_id direct, e mostenit de la produsul lui. Verificarea separata (nu affected_rows pe
// UPDATE) conteaza corect si cazul in care se salveaza aceleasi valori nemodificate.
$stmt = $mysqli->prepare(
    'SELECT h.id FROM casa_price_history h
     JOIN casa_price_products p ON p.id = h.product_id
     WHERE h.id = ? AND p.house_id = ?'
);
$stmt->bind_param('ii', $id, $houseId);
$stmt->execute();
if ($stmt->get_result()->num_rows === 0) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not_found']);
    exit;
}

$stmt = $mysqli->prepare('UPDATE casa_price_history SET price = ?, currency = ?, ok = 1, error = NULL, checked_at = ? WHERE id = ?');
$stmt->bind_param('dssi', $price, $currency, $checkedAtSql, $id);
$stmt->execute();

echo json_encode(['ok' => true]);
