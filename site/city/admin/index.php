<?php
require_once __DIR__ . '/_auth.php';
city_require_admin_page();
$cityMode = 'admin';
require __DIR__ . '/../_page.php';
