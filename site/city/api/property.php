<?php
// Tranzactii cu proprietati, pentru jucatorul intrat in cont. POST action + id (+ price):
//   buy        - cumperi (de la Primărie la pretul ei, sau de la un jucator la pretul cerut de el)
//   rent       - te muti in chirie intr-o casa / un apartament gol
//   move_in    - te muti intr-o proprietate a ta, goala
//   sell       - (proprietar) o pui la vanzare la pretul tau     sell_cancel - o retragi
//   lease      - (proprietar) o oferi spre inchiriere                lease_cancel - retragi oferta
// Totul intr-o tranzactie, cu randurile blocate, ca doi jucatori sa nu cumpere acelasi lucru deodata.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
$me = city_current_resident($mysqli);
if (!$me) city_json(['ok' => false, 'error' => 'Intră în cont mai întâi.'], 401);
$meId = (int)$me['id'];
city_daily($mysqli, $meId);

$action = (string)($_POST['action'] ?? '');
$id = (int)($_POST['id'] ?? 0);
$price = (int)($_POST['price'] ?? 0);

function fail(mysqli $db, string $msg, int $code = 400): void
{
    $db->rollback();
    city_json(['ok' => false, 'error' => $msg], $code);
}

$mysqli->begin_transaction();
$stmt = $mysqli->prepare('SELECT * FROM city_properties WHERE id = ? FOR UPDATE');
$stmt->bind_param('i', $id);
$stmt->execute();
$p = $stmt->get_result()->fetch_assoc();
if (!$p) fail($mysqli, 'Proprietatea nu mai există (poate a fost demolată).', 404);
$stmt = $mysqli->prepare('SELECT id, username FROM city_residents WHERE home_id = ? FOR UPDATE');
$stmt->bind_param('i', $id);
$stmt->execute();
$occupant = $stmt->get_result()->fetch_assoc();
$stmt = $mysqli->prepare('SELECT * FROM city_residents WHERE id = ? FOR UPDATE');
$stmt->bind_param('i', $meId);
$stmt->execute();
$meRow = $stmt->get_result()->fetch_assoc();

$ownerId = $p['owner_id'] === null ? null : (int)$p['owner_id'];
$isMine = $ownerId === $meId;
$label = city_property_label($p, true);
$message = '';
$sellerToRehouse = null;

// Unde locuiesc acum: in ceva al meu (proprietar) sau in chirie / nicaieri.
$livesInOwn = false;
if ($meRow['home_id'] !== null) {
    $stmt = $mysqli->prepare('SELECT owner_id FROM city_properties WHERE id = ?');
    $stmt->bind_param('i', $meRow['home_id']);
    $stmt->execute();
    $h = $stmt->get_result()->fetch_assoc();
    $livesInOwn = $h && (int)$h['owner_id'] === $meId;
}

function move_resident(mysqli $db, int $residentId, int $propertyId, int $rent): void
{
    $stmt = $db->prepare('UPDATE city_residents SET home_id = ?, rent_amount = ? WHERE id = ?');
    $stmt->bind_param('iii', $propertyId, $rent, $residentId);
    $stmt->execute();
}

switch ($action) {
    case 'buy':
        if ($isMine) fail($mysqli, 'E deja a ta.');
        $cost = $ownerId === null ? CITY_PRICES[$p['kind']] : ($p['sale_price'] === null ? null : (int)$p['sale_price']);
        if ($cost === null) fail($mysqli, 'Proprietarul n-a pus-o la vânzare.');
        if ((int)$meRow['balance'] < $cost) fail($mysqli, 'Nu ai destui bani - îți mai trebuie ' . city_lei($cost - (int)$meRow['balance']) . '.');
        city_money($mysqli, $meId, -$cost, 'buy', 'Ai cumpărat ' . $label);
        if ($ownerId !== null) {
            city_money($mysqli, $ownerId, $cost, 'sell', 'Ai vândut ' . $label . ' lui ' . $meRow['username']);
            if ($occupant && (int)$occupant['id'] === $ownerId) {
                // vanzatorul locuia acolo - se muta (in chirie, daca e vreun apartament liber)
                $stmt = $mysqli->prepare('UPDATE city_residents SET home_id = NULL, rent_amount = 0 WHERE id = ?');
                $stmt->bind_param('i', $ownerId);
                $stmt->execute();
                $occupant = null;
                $sellerToRehouse = $ownerId;
            }
        }
        $stmt = $mysqli->prepare('UPDATE city_properties SET owner_id = ?, sale_price = NULL, rent_price = NULL, paid_price = ? WHERE id = ?');
        $stmt->bind_param('iii', $meId, $cost, $id);
        $stmt->execute();
        if ($occupant && (int)$occupant['id'] === $meId) {
            // cumperi apartamentul in care stateai in chirie - nu mai platesti chirie
            move_resident($mysqli, $meId, $id, 0);
            $message = 'Felicitări! Apartamentul în care stăteai e acum al tău - nu mai plătești chirie.';
        } elseif (!$occupant && !$livesInOwn) {
            move_resident($mysqli, $meId, $id, 0);
            $message = 'Felicitări! Te-ai mutat în ' . $label . '.';
        } elseif ($occupant) {
            $message = 'Felicitări! ' . $occupant['username'] . ' stă acolo în chirie și de acum îți plătește ție.';
        } else {
            $message = 'Felicitări! E a ta. Când vrei, te poți muta acolo.';
        }
        break;

    case 'rent':
        if ($isMine) fail($mysqli, 'E al tău - folosește „Mută-te aici”.');
        if ($occupant && (int)$occupant['id'] === $meId) fail($mysqli, 'Deja locuiești aici.');
        if ($occupant) fail($mysqli, 'Locuiește deja cineva acolo.');
        $rent = city_effective_rent($p);
        if ($rent === null) fail($mysqli, 'Proprietarul nu o închiriază.');
        if ((int)$meRow['balance'] < 0) fail($mysqli, 'Ai datorii - nu te poți muta până nu le plătești.');
        move_resident($mysqli, $meId, $id, $rent);
        $message = 'Te-ai mutat în chirie: ' . city_lei($rent) . ' pe zi.';
        break;

    case 'move_in':
        if (!$isMine) fail($mysqli, 'Nu e a ta.');
        if ($occupant && (int)$occupant['id'] === $meId) fail($mysqli, 'Deja locuiești aici.');
        if ($occupant) fail($mysqli, $occupant['username'] . ' stă acolo în chirie.');
        move_resident($mysqli, $meId, $id, 0);
        $message = 'Te-ai mutat în ' . $label . '.';
        break;

    case 'sell':
        if (!$isMine) fail($mysqli, 'Nu e a ta.');
        if ($price < 1 || $price > CITY_MAX_PRICE) fail($mysqli, 'Alege un preț între 1 și ' . city_lei(CITY_MAX_PRICE) . '.');
        $stmt = $mysqli->prepare('UPDATE city_properties SET sale_price = ? WHERE id = ?');
        $stmt->bind_param('ii', $price, $id);
        $stmt->execute();
        $message = 'Ai pus la vânzare ' . $label . ' cu ' . city_lei($price) . '.';
        break;

    case 'sell_cancel':
        if (!$isMine) fail($mysqli, 'Nu e a ta.');
        $mysqli->query('UPDATE city_properties SET sale_price = NULL WHERE id = ' . $id);
        $message = 'Nu mai e de vânzare.';
        break;

    case 'lease':
        if (!$isMine) fail($mysqli, 'Nu e a ta.');
        if ($price < 1 || $price > CITY_MAX_RENT) fail($mysqli, 'Alege o chirie între 1 și ' . city_lei(CITY_MAX_RENT) . ' pe zi.');
        $stmt = $mysqli->prepare('UPDATE city_properties SET rent_price = ? WHERE id = ?');
        $stmt->bind_param('ii', $price, $id);
        $stmt->execute();
        $message = 'E de închiriat cu ' . city_lei($price) . ' pe zi' . ($occupant ? ' (de îndată ce se eliberează).' : '.');
        break;

    case 'lease_cancel':
        if (!$isMine) fail($mysqli, 'Nu e a ta.');
        $mysqli->query('UPDATE city_properties SET rent_price = NULL WHERE id = ' . $id);
        $message = 'Nu mai e de închiriat' . ($occupant && (int)$occupant['id'] !== $meId ? ' - chiriașul de acum rămâne până pleacă singur.' : '.');
        break;

    default:
        fail($mysqli, 'Acțiune necunoscută.');
}
$mysqli->commit();
if ($sellerToRehouse !== null) city_auto_rent($mysqli, $sellerToRehouse);
// Cine a ramas fara casa (de ex. te-ai mutat din chirie intr-o casa cumparata) eliberandu-i loc
city_rehouse_homeless($mysqli);

city_json(['ok' => true, 'message' => $message, 'meInfo' => city_me_info($mysqli, $meId)]);
