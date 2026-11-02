<?php
// Inceputul comun al endpoint-urilor AJAX din /shopping/: helperi, DB, tabele, raspuns JSON, doar POST.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') shop_json_error(405, 'POST only');
shop_ensure_tables($mysqli);
