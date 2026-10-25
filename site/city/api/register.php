<?php
// Cont nou: nume + parola. Pornesti cu CITY_START_BALANCE LEI, esti mutat in chirie (vezi
// city_auto_rent) si primesti automat un loc de munca liber de pe harta (sau esti somer pana apare
// unul). Esti logat imediat.
// De pe acelasi IP pot exista cel mult CITY_MAX_ACCOUNTS_PER_IP conturi.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);
city_sync_if_needed($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
if (city_current_resident($mysqli)) city_json(['ok' => false, 'error' => 'Ești deja intrat într-un cont. Ieși din el ca să faci altul.'], 409);

$name = city_clean_name((string)($_POST['username'] ?? ''));
$password = (string)($_POST['password'] ?? '');
$emoji = (string)($_POST['emoji'] ?? '');
if (!in_array($emoji, CITY_EMOJIS, true)) $emoji = '';

if (!city_valid_name($name)) {
    city_json(['ok' => false, 'error' => 'Numele trebuie să aibă 2-24 de caractere: litere, cifre, spații, punct sau cratimă.'], 400);
}
if (strlen($password) < CITY_PASSWORD_MIN || strlen($password) > 72) {
    city_json(['ok' => false, 'error' => 'Parola trebuie să aibă cel puțin ' . CITY_PASSWORD_MIN . ' caractere.'], 400);
}

$ip = city_ip();
$mysqli->begin_transaction();
$stmt = $mysqli->prepare('INSERT IGNORE INTO city_ips (ip) VALUES (?)');
$stmt->bind_param('s', $ip);
$stmt->execute();
// FOR UPDATE: doua conturi create in aceeasi secunda de pe acelasi IP nu pot trece amandoua de limita.
$stmt = $mysqli->prepare('SELECT accounts FROM city_ips WHERE ip = ? FOR UPDATE');
$stmt->bind_param('s', $ip);
$stmt->execute();
$accounts = (int)$stmt->get_result()->fetch_assoc()['accounts'];

if ($accounts >= CITY_MAX_ACCOUNTS_PER_IP) {
    $mysqli->rollback();
    $stmt = $mysqli->prepare('SELECT username FROM city_residents WHERE created_ip = ? ORDER BY joined_at, id');
    $stmt->bind_param('s', $ip);
    $stmt->execute();
    $res = $stmt->get_result();
    $names = [];
    while ($row = $res->fetch_assoc()) $names[] = $row['username'];
    city_json([
        'ok' => false,
        'code' => 'ip_limit',
        'error' => 'De pe conexiunea ta s-au mutat deja ' . CITY_MAX_ACCOUNTS_PER_IP . ' locuitori în oraș, cât e limita. Vino acasă într-unul dintre ei.',
        'accounts' => $names,
    ], 403);
}

$stmt = $mysqli->prepare('SELECT id FROM city_residents WHERE username = ?');
$stmt->bind_param('s', $name);
$stmt->execute();
if ($stmt->get_result()->fetch_assoc()) {
    $mysqli->rollback();
    city_json(['ok' => false, 'error' => 'Numele „' . $name . '” e deja luat. Alege altul.'], 409);
}

$hash = password_hash($password, PASSWORD_DEFAULT);
$today = date('Y-m-d');

try {
    // last_daily = azi: in prima zi ai doar soldul de start, salariul si chiria incep de maine
    $stmt = $mysqli->prepare('INSERT INTO city_residents (username, password_hash, emoji, created_ip, last_daily, last_seen) VALUES (?, ?, ?, ?, ?, NOW())');
    $stmt->bind_param('sssss', $name, $hash, $emoji, $ip, $today);
    $inserted = $stmt->execute();
} catch (mysqli_sql_exception $e) {
    $inserted = false;
}
if (!$inserted) {
    $mysqli->rollback();
    city_json(['ok' => false, 'error' => 'Numele „' . $name . '” e deja luat. Alege altul.'], 409);
}
$id = (int)$mysqli->insert_id;
$stmt = $mysqli->prepare('UPDATE city_ips SET accounts = accounts + 1 WHERE ip = ?');
$stmt->bind_param('s', $ip);
$stmt->execute();
city_money($mysqli, $id, CITY_START_BALANCE, 'start', 'Bani de bun venit în oraș');
$mysqli->commit();

city_auto_rent($mysqli, $id);
city_hire($mysqli, $id);
city_start_session($mysqli, $id);
city_json(['ok' => true, 'resident' => city_public_resident(city_fetch_resident($mysqli, $id))]);
