<?php
// Adminul sterge contul unui locuitor.
require_once __DIR__ . '/_auth.php';
city_require_admin_api();
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
city_delete_resident($mysqli, (int)($_POST['id'] ?? 0));
city_json(['ok' => true]);
