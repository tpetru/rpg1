<?php
// AJAX endpoint for the login/register modal (see includes/header.php) - lets guests log in or
// register without leaving the page they were on, instead of being sent to index.php.
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/lang.php';
header('Content-Type: application/json');

if (isset($_SESSION['ucp_player_id'])) {
    echo json_encode(['success' => true]);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST' || !ucp_csrf_verify()) {
    echo json_encode(['success' => false, 'error' => t('Security check failed. Please refresh the page and try again.')]);
    exit;
}

$action = $_POST['action'] ?? '';

if ($action === 'login') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if ($username === '' || $password === '') {
        echo json_encode(['success' => false, 'error' => t('Fill in your username and password.')]);
    } elseif (ucp_login($username, $password)) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'error' => t('Incorrect username or password.')]);
    }
} elseif ($action === 'register') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $confirm  = $_POST['confirm'] ?? '';
    $error = '';

    if ($username === '' || $password === '' || $confirm === '') {
        echo json_encode(['success' => false, 'error' => t('Fill in all fields.')]);
    } elseif ($password !== $confirm) {
        echo json_encode(['success' => false, 'error' => t('Passwords do not match.')]);
    } elseif (ucp_register($username, $password, $error)) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'error' => $error]);
    }
} else {
    echo json_encode(['success' => false, 'error' => t('Invalid request.')]);
}
