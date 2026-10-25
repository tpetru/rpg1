<?php
// "Șterge contul" - sterge contul curent, cu toate login-urile lui, si elibereaza locul in limita IP-ului.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);

$me = city_current_resident($mysqli);
if ($me) city_delete_resident($mysqli, (int)$me['id']);
city_end_session($mysqli);
city_json(['ok' => true]);
