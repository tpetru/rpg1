<?php
session_start();
require_once __DIR__ . '/db.php';

// Autentificare folosind exact contul din joc (tabelul `players`).
// NOTA: parola e stocata in clar in DB (la fel ca in gamemode, vezi /register din bare.pwn) -
// comparatie directa, fara hash. Daca se adauga hashing in gamemode, schimba si aici (password_verify).
function ucp_login($username, $password) {
    global $mysqli;

    $stmt = $mysqli->prepare("SELECT `id`,`username`,`password`,`admin_level` FROM `players` WHERE `username` = ? LIMIT 1");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return false;
    if ($row['password'] !== $password) return false;

    $_SESSION['ucp_player_id']   = (int)$row['id'];
    $_SESSION['ucp_username']    = $row['username'];
    $_SESSION['ucp_admin_level'] = (int)$row['admin_level'];
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
