<?php
// Credentiale conexiune - definite in afara repo-ului git SI in afara webroot-ului (htdocs),
// ca parola sa nu fie comisa in istoric si nici accesibila direct printr-un URL.
// Fisierul defineste $DB_HOST/$DB_PORT/$DB_USER/$DB_PASS/$DB_NAME (aceleasi date ca in gamemode).
// Local (XAMPP/Windows): C:/xampp/rpg1_secrets/db_credentials.php
// Hosting extern (Linux): un folder cu acelasi nume, pus manual chiar deasupra webroot-ului
//   (ex. daca site-ul e in /home/user/public_html, pune fisierul in /home/user/rpg1_secrets/db_credentials.php)
$dbCredFileLocal = 'C:/xampp/rpg1_secrets/db_credentials.php';
// Bazat pe locatia fizica a acestui fisier (__DIR__), nu pe DOCUMENT_ROOT - acesta din urma difera
// acum intre subdomenii (fiecare cu propriul DocumentRoot intr-un subfolder), in timp ce fisierul
// db.php ramane mereu la aceeasi adancime fata de rpg1_secrets, indiferent de vhost-ul care serveste.
$dbCredFileHosting = dirname(__DIR__, 2) . '/rpg1_secrets/db_credentials.php';

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
