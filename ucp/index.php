<?php
require_once __DIR__ . '/includes/auth.php';

if (isset($_SESSION['ucp_player_id'])) {
    header('Location: dashboard.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if ($username === '' || $password === '') {
        $error = 'Completează username și parolă.';
    } elseif (ucp_login($username, $password)) {
        header('Location: dashboard.php');
        exit;
    } else {
        $error = 'Username sau parolă incorectă.';
    }
}
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NostalgiaRP UCP — Login</title>
<link rel="stylesheet" href="assets/css/style.css">
</head>
<body>

<div class="login-wrap">
  <div class="login-card">
    <h1>🏙️ NostalgiaRP UCP</h1>

    <?php if ($error): ?>
      <div class="error-box"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="post">
      <label>Username</label>
      <input type="text" name="username" autocomplete="username" required>

      <label>Parolă</label>
      <input type="password" name="password" autocomplete="current-password" required>

      <button type="submit">Login</button>
    </form>
  </div>
</div>

</body>
</html>
