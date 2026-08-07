<?php
require_once __DIR__ . '/../includes/auth.php';

if (isset($_SESSION['ucp_player_id'])) {
    header('Location: dashboard.php');
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — UCP</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .home-wrap {
    min-height: 100vh;
    display: flex; flex-direction: column; align-items: center; justify-content: flex-start;
    padding: 5vh 24px 40px;
    text-align: center;
  }
  .home-logo { max-width: 840px; width: 100%; border-radius: 14px; box-shadow: 0 12px 40px rgba(0,0,0,0.5); }
  .home-wrap h1 {
    margin: 26px 0 6px;
    font-size: 1.8rem;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    -webkit-background-clip: text; background-clip: text; color: transparent;
  }
  .home-wrap p.tag { color: var(--muted); margin: 0 0 30px; }
  .home-actions { display: flex; gap: 14px; flex-wrap: wrap; justify-content: center; }
  .home-actions a {
    display: inline-block;
    padding: 12px 32px;
    border-radius: 999px;
    font-weight: 700;
    font-size: 1rem;
    text-decoration: none;
  }
  .home-actions a.btn-login { background: var(--accent); color: #0f1115; }
  .home-actions a.btn-register { background: transparent; color: var(--text); border: 1px solid var(--border); }
  .home-actions a:hover { opacity: 0.9; text-decoration: none; }
</style>
</head>
<body>

<div class="home-wrap">
  <img src="assets/img/logo.jpg" alt="Nostalgia: Los Santos" class="home-logo">
  <h1>Nostalgia: Los Santos</h1>

  <div class="home-actions">
    <a href="login.php" class="btn-login">Login</a>
    <a href="register.php" class="btn-register">Register</a>
  </div>
</div>

</body>
</html>
