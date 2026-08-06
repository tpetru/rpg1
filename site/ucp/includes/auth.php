<?php
session_start();
require_once __DIR__ . '/db.php';

// Site-root-relative base path for the UCP, used for links/asset URLs in shared includes (header.php,
// admin_nav.php) so they resolve correctly regardless of how deep the including page lives
// (e.g. /ucp/admin/houses.php is one level deeper than /ucp/dashboard.php).
if (!defined('UCP_BASE')) define('UCP_BASE', '/ucp');

// Autentificare folosind exact contul din joc (tabelul `players`).
// NOTA: parola e stocata in clar in DB (la fel ca in gamemode, vezi /register din bare.pwn) -
// comparatie directa, fara hash. Daca se adauga hashing in gamemode, schimba si aici (password_verify).
function ucp_login($username, $password) {
    global $mysqli;

    $stmt = $mysqli->prepare("SELECT `id`,`username`,`password`,`admin_level`,`faction`,`faction_rank` FROM `players` WHERE `username` = ? LIMIT 1");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return false;
    if ($row['password'] !== $password) return false;

    $_SESSION['ucp_player_id']    = (int)$row['id'];
    $_SESSION['ucp_username']     = $row['username'];
    $_SESSION['ucp_admin_level']  = (int)$row['admin_level'];
    $_SESSION['ucp_faction']      = (int)$row['faction'];
    $_SESSION['ucp_faction_rank'] = (int)$row['faction_rank'];
    return true;
}

// Creeaza un cont nou, la fel ca /register din bare.pwn (INSERT doar username+password,
// restul coloanelor iau valorile DEFAULT din tabela `players`). Parola e stocata in clar,
// la fel ca in gamemode (vezi nota de mai sus) - se autentifica automat dupa creare.
// Returneaza true la succes, sau false + $error setat prin referinta.
function ucp_register($username, $password, &$error) {
    global $mysqli;

    $username = trim($username);
    if (!preg_match('/^[A-Za-z0-9_\[\]$@=.]{3,24}$/', $username)) {
        $error = 'Username-ul trebuie să aibă 3-24 caractere (litere, cifre, _ [ ] $ @ = .).';
        return false;
    }
    if (strlen($password) < 4 || strlen($password) > 64) {
        $error = 'Parola trebuie să aibă între 4 și 64 de caractere.';
        return false;
    }

    $stmt = $mysqli->prepare("SELECT `id` FROM `players` WHERE `username` = ? LIMIT 1");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $exists = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($exists) {
        $error = 'Acest username este deja înregistrat.';
        return false;
    }

    $stmt = $mysqli->prepare("INSERT INTO `players` (`username`, `password`) VALUES (?, ?)");
    $stmt->bind_param('ss', $username, $password);
    try {
        $stmt->execute();
    } catch (mysqli_sql_exception $e) {
        $stmt->close();
        $error = 'Acest username este deja înregistrat.';
        return false;
    }
    $newId = $stmt->insert_id;
    $stmt->close();

    $_SESSION['ucp_player_id']    = (int)$newId;
    $_SESSION['ucp_username']     = $username;
    $_SESSION['ucp_admin_level']  = 0;
    $_SESSION['ucp_faction']      = 0;
    $_SESSION['ucp_faction_rank'] = 1;
    return true;
}

function ucp_logout() {
    $_SESSION = [];
    session_destroy();
}

function ucp_require_login() {
    if (!isset($_SESSION['ucp_player_id'])) {
        header('Location: index.php');
        exit;
    }
}

function ucp_require_admin() {
    ucp_require_login();
    if ((int)$_SESSION['ucp_admin_level'] < 1) {
        header('Location: dashboard.php');
        exit;
    }
}

function ucp_current_player_id() {
    return isset($_SESSION['ucp_player_id']) ? (int)$_SESSION['ucp_player_id'] : 0;
}

function ucp_current_admin_level() {
    return isset($_SESSION['ucp_admin_level']) ? (int)$_SESSION['ucp_admin_level'] : 0;
}

function ucp_current_faction() {
    return isset($_SESSION['ucp_faction']) ? (int)$_SESSION['ucp_faction'] : 0;
}

function ucp_current_faction_rank() {
    return isset($_SESSION['ucp_faction_rank']) ? (int)$_SESSION['ucp_faction_rank'] : 0;
}

// Lider = faction_rank 5 (vezi pFactionRank == 5 => "Lead" in bare.pwn)
function ucp_is_faction_leader($factionId) {
    return ucp_current_faction() === (int)$factionId && ucp_current_faction_rank() >= 5;
}

// Acces la pagina unei factii: doar liderul acelei factii sau un admin
function ucp_require_faction_access($factionId) {
    ucp_require_login();
    if (!ucp_is_faction_leader($factionId) && ucp_current_admin_level() < 1) {
        header('Location: dashboard.php');
        exit;
    }
}
