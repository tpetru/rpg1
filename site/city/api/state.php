<?php
// Harta orasului, pentru oricine. ?v=<versiune> -> daca nu s-a schimbat, raspunde scurt.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

$state = city_load_state($mysqli);
if (!$state) city_json(['ok' => true, 'version' => 0, 'data' => null]);

$known = (int)($_GET['v'] ?? -1);
if ($known === $state['version']) city_json(['ok' => true, 'version' => $state['version'], 'unchanged' => true]);

city_json(['ok' => true, 'version' => $state['version'], 'data' => $state['data']]);
