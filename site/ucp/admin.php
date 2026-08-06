<?php
// The admin panel is now split into separate pages under /admin/ (houses.php, businesses.php,
// vehicles.php, farms.php, hotels.php, shops.php, fastfood.php) - kept here as a redirect
// so old bookmarks/links still work.
require_once __DIR__ . '/includes/auth.php';
header('Location: ' . UCP_BASE . '/admin/houses.php');
exit;
