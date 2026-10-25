<?php
// Dedicated DB connection for the casa module - lives in its own `casa` database on the same
// MySQL server, separate from the SA-MP site's `rpg1` database (moved out so the two projects'
// data can't collide/interfere). Reuses the same host/user/pass from the shared credentials file
// (same server, same MySQL account - it already has privileges on both databases) but always
// connects to `casa` regardless of whatever $DB_NAME that file defines.
$dbCredFileLocal = 'C:/xampp/rpg1_secrets/db_credentials.php';
// Bazat pe locatia fizica a acestui fisier (__DIR__), nu pe DOCUMENT_ROOT - vezi includes/db.php.
$dbCredFileHosting = dirname(__DIR__, 2) . '/rpg1_secrets/db_credentials.php';

if (file_exists($dbCredFileLocal)) {
    require_once $dbCredFileLocal;
} elseif (file_exists($dbCredFileHosting)) {
    require_once $dbCredFileHosting;
} else {
    die('Eroare: fisierul de credentiale DB nu a fost gasit. Creaza-l manual la: ' . $dbCredFileHosting);
}

$mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, 'casa', $DB_PORT);
if ($mysqli->connect_error) {
    die('Eroare conectare la baza de date: ' . $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');
