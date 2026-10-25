<?php
// Login cu nume + parola. Dupa CITY_LOGIN_MAX_FAILS incercari gresite de pe acelasi IP, login-ul se
// blocheaza CITY_LOGIN_FAIL_WINDOW minute (ca parolele sa nu poata fi ghicite la nesfarsit).
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);

$name = city_clean_name((string)($_POST['username'] ?? ''));
$password = (string)($_POST['password'] ?? '');
$ip = city_ip();

$stmt = $mysqli->prepare('INSERT IGNORE INTO city_ips (ip) VALUES (?)');
$stmt->bind_param('s', $ip);
$stmt->execute();
$stmt = $mysqli->prepare('SELECT login_fails, fails_since, fails_since > NOW() - INTERVAL ' . CITY_LOGIN_FAIL_WINDOW . ' MINUTE AS recent FROM city_ips WHERE ip = ?');
$stmt->bind_param('s', $ip);
$stmt->execute();
$ipRow = $stmt->get_result()->fetch_assoc();
if ($ipRow['recent'] && (int)$ipRow['login_fails'] >= CITY_LOGIN_MAX_FAILS) {
    city_json(['ok' => false, 'error' => 'Prea multe încercări greșite. Mai încearcă peste ' . CITY_LOGIN_FAIL_WINDOW . ' minute.'], 429);
}

$row = null;
if ($name !== '') {
    $stmt = $mysqli->prepare('SELECT * FROM city_residents WHERE username = ?');
    $stmt->bind_param('s', $name);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
}
if (!$row || $row['password_hash'] === '' || !password_verify($password, $row['password_hash'])) {
    // fereastra de 15 minute porneste de la prima greseala; dupa ce expira, numaratoarea o ia de la capat
    if ($ipRow['recent']) $stmt = $mysqli->prepare('UPDATE city_ips SET login_fails = login_fails + 1 WHERE ip = ?');
    else $stmt = $mysqli->prepare('UPDATE city_ips SET login_fails = 1, fails_since = NOW() WHERE ip = ?');
    $stmt->bind_param('s', $ip);
    $stmt->execute();
    usleep(400000);
    city_json(['ok' => false, 'error' => 'Nume sau parolă greșită.'], 401);
}

$stmt = $mysqli->prepare('UPDATE city_ips SET login_fails = 0, fails_since = NULL WHERE ip = ?');
$stmt->bind_param('s', $ip);
$stmt->execute();
if (password_needs_rehash($row['password_hash'], PASSWORD_DEFAULT)) {
    $newHash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $mysqli->prepare('UPDATE city_residents SET password_hash = ? WHERE id = ?');
    $stmt->bind_param('si', $newHash, $row['id']);
    $stmt->execute();
}

city_end_session($mysqli);
city_start_session($mysqli, (int)$row['id']);
city_json(['ok' => true, 'resident' => city_public_resident(city_fetch_resident($mysqli, (int)$row['id']))]);
