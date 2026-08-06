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
    $confirm  = $_POST['confirm'] ?? '';

    if ($username === '' || $password === '' || $confirm === '') {
        $error = 'Completează toate câmpurile.';
    } elseif ($password !== $confirm) {
        $error = 'Parolele nu coincid.';
    } elseif (ucp_register($username, $password, $error)) {
        header('Location: dashboard.php');
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Register</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<div class="login-wrap">
  <div class="login-card">
    <a href="index.php" style="display:block; text-align:center; margin-bottom:16px;">
      <img src="assets/img/logo.jpg" alt="Nostalgia: Los Santos" style="max-width:160px; width:100%; border-radius:10px;">
    </a>
    <h1>🏙️ Creează cont</h1>

    <?php if ($error): ?>
      <div class="error-box"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="post">
      <label>Username</label>
      <input type="text" name="username" autocomplete="username" minlength="3" maxlength="24" required
             value="<?= htmlspecialchars($_POST['username'] ?? '') ?>">

      <label>Parolă</label>
      <input type="password" name="password" autocomplete="new-password" minlength="4" maxlength="64" required>

      <label>Confirmă parola</label>
      <input type="password" name="confirm" autocomplete="new-password" minlength="4" maxlength="64" required>

      <button type="submit">Register</button>
    </form>

    <p style="text-align:center; margin-top:16px; font-size:0.85rem; color:var(--muted)">
      Ai deja cont? <a href="login.php">Login</a>
    </p>
  </div>
</div>

</body>
</html>
