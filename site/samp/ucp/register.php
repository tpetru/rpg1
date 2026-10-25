<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/lang.php';

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
        $error = t('Fill in all fields.');
    } elseif ($password !== $confirm) {
        $error = t('Passwords do not match.');
    } elseif (ucp_register($username, $password, $error)) {
        header('Location: dashboard.php');
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Register</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<div class="login-wrap">
  <div class="login-card">
    <a href="index.php" style="display:block; text-align:center; margin-bottom:16px;">
      <img src="assets/img/logo.jpg" alt="Nostalgia: Los Santos" style="max-width:160px; width:100%; border-radius:10px;">
    </a>
    <h1>🏙️ <?= t('Create account') ?></h1>

    <?php if ($error): ?>
      <div class="error-box"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <form method="post">
      <label><?= t('Username') ?></label>
      <input type="text" name="username" autocomplete="username" minlength="3" maxlength="24" required
             value="<?= htmlspecialchars($_POST['username'] ?? '') ?>">

      <label><?= t('Password') ?></label>
      <input type="password" name="password" autocomplete="new-password" minlength="4" maxlength="64" required>

      <label><?= t('Confirm password') ?></label>
      <input type="password" name="confirm" autocomplete="new-password" minlength="4" maxlength="64" required>

      <button type="submit"><?= t('Register') ?></button>
    </form>

    <p style="margin-top:16px; font-size:0.82rem; color:var(--muted); border-left:3px solid #ff5d5d; padding:8px 12px; background:rgba(255,93,93,0.06); border-radius:0 6px 6px 0;">
      <strong><?= t('Attention:') ?></strong> <?= t('Use a unique password that you do NOT use on any other site/application.') ?>
      <?= t('Registering confirms you agree to the Nostalgia: Los Santos') ?> <a href="../tc.php" target="_blank"><?= t('Terms & Conditions') ?></a>.
    </p>

    <p style="text-align:center; margin-top:16px; font-size:0.85rem; color:var(--muted)">
      <?= t('Already have an account?') ?> <a href="login.php"><?= t('Login') ?></a>
    </p>
  </div>
</div>

</body>
</html>
