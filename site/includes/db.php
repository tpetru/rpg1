<?php
// Credentiale conexiune - definite in afara repo-ului git SI in afara webroot-ului (htdocs),
// ca parola sa nu fie comisa in istoric si nici accesibila direct printr-un URL.
// Fisierul defineste $DB_HOST/$DB_PORT/$DB_USER/$DB_PASS/$DB_NAME (aceleasi date ca in gamemode).
require_once 'C:/xampp/rpg1_secrets/db_credentials.php';

$mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME, $DB_PORT);
if ($mysqli->connect_error) {
    die('Eroare conectare la baza de date: ' . $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');
