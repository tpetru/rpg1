<?php
// Aceleasi date de conectare ca in gamemode (gamemodes/bare.pwn, MYSQL_HOST/USER/PASS/DB)
$DB_HOST = '127.0.0.1';
$DB_USER = 'root';
$DB_PASS = '';
$DB_NAME = 'rpg1';

$mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);
if ($mysqli->connect_error) {
    die('Eroare conectare la baza de date: ' . $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');
