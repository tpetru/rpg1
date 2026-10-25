<?php
// Iesi din cont pe dispozitivul acesta (celelalte login-uri raman active).
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
city_end_session($mysqli);
city_json(['ok' => true]);
