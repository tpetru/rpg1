<?php
// Credentiale conexiune - definite in afara repo-ului git SI in afara webroot-ului (htdocs),
// ca parola sa nu fie comisa in istoric si nici accesibila direct printr-un URL.
// Fisierul defineste $DB_HOST/$DB_PORT/$DB_USER/$DB_PASS/$DB_NAME (aceleasi date ca in gamemode).
// Local (XAMPP/Windows): C:/xampp/rpg1_secrets/db_credentials.php
// Hosting extern (Linux): un folder cu acelasi nume, pus manual chiar deasupra webroot-ului
//   (ex. daca site-ul e in /home/user/public_html, pune fisierul in /home/user/rpg1_secrets/db_credentials.php)
$dbCredFileLocal = 'C:/xampp/rpg1_secrets/db_credentials.php';
$dbCredFileHosting = dirname($_SERVER['DOCUMENT_ROOT']) . '/rpg1_secrets/db_credentials.php';

if (file_exists($dbCredFileLocal)) {
    require_once $dbCredFileLocal;
} elseif (file_exists($dbCredFileHosting)) {
    require_once $dbCredFileHosting;
} else {
    die('Eroare: fisierul de credentiale DB nu a fost gasit. Creaza-l manual la: ' . $dbCredFileHosting);
}

$mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME, $DB_PORT);
if ($mysqli->connect_error) {
    die('Eroare conectare la baza de date: ' . $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');
