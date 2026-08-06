<?php
require_once __DIR__ . '/includes/auth.php';
ucp_logout();
header('Location: index.php');
exit;
