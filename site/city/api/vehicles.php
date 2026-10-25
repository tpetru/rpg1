<?php
// Masini personale: POST action = buy (model, color) | sell (id). Cumparatul merge doar daca exista un
// Dealership pe harta; cel mult CITY_MAX_CARS masini; la vanzare iei CITY_CAR_RESALE% din ce ai platit.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
$me = city_current_resident($mysqli);
if (!$me) city_json(['ok' => false, 'error' => 'Intră în cont mai întâi.'], 401);
$meId = (int)$me['id'];
$action = (string)($_POST['action'] ?? '');

function car_fail(mysqli $db, string $err, int $code = 409): void
{
    $db->rollback();
    city_json(['ok' => false, 'error' => $err], $code);
}
function car_done(mysqli $db, int $id, string $msg): void
{
    $db->commit();
    city_json(['ok' => true, 'message' => $msg, 'vehicles' => city_my_vehicles($db, $id), 'balance' => (int)$db->query('SELECT balance FROM city_residents WHERE id = ' . $id)->fetch_assoc()['balance']]);
}

$mysqli->begin_transaction();
$stmt = $mysqli->prepare('SELECT balance FROM city_residents WHERE id = ? FOR UPDATE');
$stmt->bind_param('i', $meId);
$stmt->execute();
$balance = (int)$stmt->get_result()->fetch_assoc()['balance'];

if ($action === 'buy') {
    $brand = (string)($_POST['brand'] ?? '');
    $model = (string)($_POST['model'] ?? '');
    $color = (string)($_POST['color'] ?? '');
    if (isset(CITY_BRANDS[$brand]) && CITY_BRANDS[$brand][1] === 'moto') $model = 'moto';
    if (!isset(CITY_BRANDS[$brand]) || !in_array($model, CITY_BRANDS[$brand][3], true) || !in_array($color, CITY_CAR_COLORS, true)) car_fail($mysqli, 'Marcă, caroserie sau culoare necunoscută.', 400);
    if (!$mysqli->query("SELECT 1 FROM city_workplaces WHERE kind = 'dealership' LIMIT 1")->num_rows) car_fail($mysqli, 'Nu există niciun dealership în oraș.');
    if (count(city_my_vehicles($mysqli, $meId)) >= CITY_MAX_CARS) car_fail($mysqli, 'Ai deja ' . CITY_MAX_CARS . ' mașini - vinde una ca să cumperi alta.');
    $price = city_car_price($brand, $model, $color);
    $name = city_car_name($brand, $model);
    if ($balance < $price) car_fail($mysqli, 'Îți mai trebuie ' . city_lei($price - $balance) . '.');
    city_money($mysqli, $meId, -$price, 'car', 'Mașină nouă: ' . $name);
    $stmt = $mysqli->prepare('INSERT INTO city_vehicles (owner_id, brand, model, color, paid, built_at, km, owners) VALUES (?, ?, ?, ?, ?, CURDATE(), 0, 1)');
    $stmt->bind_param('isssi', $meId, $brand, $model, $color, $price);
    $stmt->execute();
    car_done($mysqli, $meId, 'Ai cumpărat: ' . $name . ' · ' . city_lei($price) . '. Drum bun! 🚗');
}
if ($action === 'sell') {
    $id = (int)($_POST['id'] ?? 0);
    $stmt = $mysqli->prepare('SELECT * FROM city_vehicles WHERE id = ? AND owner_id = ? FOR UPDATE');
    $stmt->bind_param('ii', $id, $meId);
    $stmt->execute();
    $v = $stmt->get_result()->fetch_assoc();
    if (!$v) car_fail($mysqli, 'Mașina nu mai e a ta.');
    $back = (int)floor(city_car_value($v) * CITY_CAR_RESALE / 100);
    $stmt = $mysqli->prepare('DELETE FROM city_vehicles WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    city_money($mysqli, $meId, $back, 'car', 'Mașină vândută: ' . city_car_name((string)$v['brand'], $v['model']));
    car_done($mysqli, $meId, 'Ai vândut mașina · ' . city_lei($back) . '.');
}
if ($action === 'list' || $action === 'unlist') {
    $id = (int)($_POST['id'] ?? 0);
    $stmt = $mysqli->prepare('SELECT * FROM city_vehicles WHERE id = ? AND owner_id = ? FOR UPDATE');
    $stmt->bind_param('ii', $id, $meId);
    $stmt->execute();
    $v = $stmt->get_result()->fetch_assoc();
    if (!$v) car_fail($mysqli, 'Mașina nu mai e a ta.');
    if ($action === 'unlist') {
        $stmt = $mysqli->prepare('UPDATE city_vehicles SET listed_price = NULL WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        car_done($mysqli, $meId, 'Ai retras mașina de la vânzare.');
    }
    if (!city_has_workplace_kind($mysqli, 'usedlot')) car_fail($mysqli, 'Nu există niciun parc auto în oraș unde să o scoți la vânzare.');
    $price = (int)($_POST['price'] ?? 0);
    if ($price < 500 || $price > CITY_MAX_PRICE) car_fail($mysqli, 'Prețul trebuie să fie între 500 și ' . number_format(CITY_MAX_PRICE, 0, ',', '.') . ' LEI.', 400);
    $stmt = $mysqli->prepare('UPDATE city_vehicles SET listed_price = ? WHERE id = ?');
    $stmt->bind_param('ii', $price, $id);
    $stmt->execute();
    car_done($mysqli, $meId, 'Mașina e acum la vânzare în parcul auto · ' . city_lei($price) . '.');
}
if ($action === 'buyused') {
    if (!city_has_workplace_kind($mysqli, 'usedlot')) car_fail($mysqli, 'Nu există niciun parc auto în oraș.');
    $id = (int)($_POST['id'] ?? 0);
    $stmt = $mysqli->prepare('SELECT * FROM city_vehicles WHERE id = ? FOR UPDATE');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $v = $stmt->get_result()->fetch_assoc();
    if (!$v || $v['listed_price'] === null) car_fail($mysqli, 'Mașina nu mai e la vânzare.');
    if ((int)$v['owner_id'] === $meId) car_fail($mysqli, 'E mașina ta.');
    if (count(city_my_vehicles($mysqli, $meId)) >= CITY_MAX_CARS) car_fail($mysqli, 'Ai deja ' . CITY_MAX_CARS . ' mașini - vinde una ca să cumperi alta.');
    $price = (int)$v['listed_price'];
    if ($balance < $price) car_fail($mysqli, 'Îți mai trebuie ' . city_lei($price - $balance) . '.');
    $name = city_car_name((string)$v['brand'], $v['model']);
    city_money($mysqli, $meId, -$price, 'car', 'Mașină second-hand: ' . $name);
    if ((int)$v['owner_id'] > 0) city_money($mysqli, (int)$v['owner_id'], $price, 'car', 'Mașină vândută în parcul auto: ' . $name);
    $stmt = $mysqli->prepare('UPDATE city_vehicles SET owner_id = ?, listed_price = NULL, owners = owners + 1, paid = ? WHERE id = ?');
    $stmt->bind_param('iii', $meId, $price, $id);
    $stmt->execute();
    car_done($mysqli, $meId, 'Ai cumpărat second-hand: ' . $name . ' · ' . city_lei($price) . '.');
}
car_fail($mysqli, 'Acțiune necunoscută.', 400);
