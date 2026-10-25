<?php
// Adminul modifica un locuitor. POST id = locuitorul, action:
//   info                       -> banii si vehiculele lui
//   money (amount)             -> seteaza soldul (diferenta se noteaza ca tranzactie de admin)
//   job (workplace)            -> alt loc de munca (0 = somer); merge doar daca mai e loc acolo
//   home (x, y) | home_clear   -> muta in prima locuinta libera de pe patratelul (x, y) / il lasa fara casa
//   car_delete (car)           -> sterge o masina a lui, fara despagubire
require_once __DIR__ . '/_auth.php';
city_require_admin_api();
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
$id = (int)($_POST['id'] ?? 0);
$action = (string)($_POST['action'] ?? '');
$stmt = $mysqli->prepare('SELECT id, username, balance, home_id, job_id FROM city_residents WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$r = $stmt->get_result()->fetch_assoc();
if (!$r) city_json(['ok' => false, 'error' => 'Locuitorul nu mai există.'], 404);

function edit_done(mysqli $db, int $id, string $msg): void
{
    $b = (int)$db->query('SELECT balance FROM city_residents WHERE id = ' . $id)->fetch_assoc()['balance'];
    city_json(['ok' => true, 'message' => $msg, 'balance' => $b, 'vehicles' => city_my_vehicles($db, $id)]);
}

if ($action === 'info') edit_done($mysqli, $id, '');

if ($action === 'money') {
    $amount = (int)($_POST['amount'] ?? 0);
    if ($amount < -100000000 || $amount > 100000000) city_json(['ok' => false, 'error' => 'Sumă prea mare.'], 400);
    $diff = $amount - (int)$r['balance'];
    if ($diff !== 0) city_money($mysqli, $id, $diff, 'admin', 'Ajustare de la primărie');
    edit_done($mysqli, $id, $r['username'] . ' are acum ' . city_lei($amount) . '.');
}

if ($action === 'job') {
    $w = (int)($_POST['workplace'] ?? 0);
    if ($w === 0) {
        $stmt = $mysqli->prepare('UPDATE city_residents SET job_id = NULL WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        edit_done($mysqli, $id, $r['username'] . ' e acum șomer.');
    }
    if (!city_take_job($mysqli, $id, $w)) city_json(['ok' => false, 'error' => 'Nu mai e loc liber acolo.'], 409);
    edit_done($mysqli, $id, $r['username'] . ' are un job nou.');
}

if ($action === 'home_clear') {
    $stmt = $mysqli->prepare('UPDATE city_residents SET home_id = NULL, rent_amount = 0 WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    edit_done($mysqli, $id, $r['username'] . ' nu mai are casă.');
}

if ($action === 'home') {
    $x = (int)($_POST['x'] ?? -1);
    $y = (int)($_POST['y'] ?? -1);
    $stmt = $mysqli->prepare('SELECT p.* FROM city_properties p LEFT JOIN city_residents o ON o.home_id = p.id
        WHERE p.x = ? AND p.y = ? AND (o.id IS NULL OR o.id = ?) ORDER BY o.id IS NULL, p.unit LIMIT 1');
    $stmt->bind_param('iii', $x, $y, $id);
    $stmt->execute();
    $p = $stmt->get_result()->fetch_assoc();
    if (!$p) city_json(['ok' => false, 'error' => 'Nu e nicio locuință liberă pe patratul (' . $x . ',' . $y . ').'], 404);
    // al lui = fara chirie; altfel chiria cerută de proprietar sau cea a Primăriei
    $rent = (int)$p['owner_id'] === $id ? 0 : (city_effective_rent($p) ?? CITY_RENTS[$p['kind']]);
    $stmt = $mysqli->prepare('UPDATE city_residents SET home_id = ?, rent_amount = ? WHERE id = ?');
    $stmt->bind_param('iii', $p['id'], $rent, $id);
    $stmt->execute();
    edit_done($mysqli, $id, $r['username'] . ' locuiește acum la ' . city_property_label($p, true) . '.');
}

if ($action === 'car_delete') {
    $car = (int)($_POST['car'] ?? 0);
    $stmt = $mysqli->prepare('DELETE FROM city_vehicles WHERE id = ? AND owner_id = ?');
    $stmt->bind_param('ii', $car, $id);
    $stmt->execute();
    if (!$stmt->affected_rows) city_json(['ok' => false, 'error' => 'Mașina nu mai e a lui.'], 404);
    edit_done($mysqli, $id, 'Mașina a fost ștearsă.');
}

city_json(['ok' => false, 'error' => 'Acțiune necunoscută.'], 400);
