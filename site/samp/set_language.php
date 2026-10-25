<?php
// Comuta limba site-ului intre 'en' si 'ro'.
//   - logat in UCP -> scrie in players.language (aceeasi coloana pe care o seteaza /en, /ro din joc)
//   - vizitator     -> scrie doar cookie-ul site_lang (nu exista rand in `players` de actualizat)
// Link folosit din header.php / header-public.php: /set_language.php?lang=ro&redirect=<path curent>
require_once __DIR__ . '/../includes/db.php';
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

$lang = (($_GET['lang'] ?? '') === 'ro') ? 'ro' : 'en';

if (isset($_SESSION['ucp_player_id'])) {
    $pid = (int)$_SESSION['ucp_player_id'];
    $stmt = $mysqli->prepare("UPDATE `players` SET `language` = ? WHERE `id` = ?");
    $stmt->bind_param('si', $lang, $pid);
    $stmt->execute();
    $stmt->close();
} else {
    setcookie('site_lang', $lang, time() + 60 * 60 * 24 * 365, '/');
}

// doar path-uri locale (fara scheme/host) - niciodata un redirect catre un URL extern
$redirect = $_GET['redirect'] ?? '/';
if (!preg_match('#^/[A-Za-z0-9_\-./]*$#', $redirect)) {
    $redirect = '/';
}

header('Location: ' . $redirect);
exit;
