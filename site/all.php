<?php
// Cuprins minimal cu link-urile principale ale site-ului. Uz intern - nu e link-uit in navigare.
$links = [
    ['Casa',      '/index.php',     '🏠'],
    ['SAMP',      '/samp/index.php', '🎮'],
    ['CS',        '/cs/reels/',     '🎯'],
    ['Cocktails', '/cocktails.php', '🍸'],
    ['Games',     '/samp/games/',   '🕹️'],
];
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Cuprins</title>
<link rel="icon" type="image/png" href="/samp/ucp/assets/img/favicon.ico">
<style>
  :root {
    --bg: #0b0d10;
    --text: #f2f2f2;
    --muted: #8e969f;
    --panel: #12161b;
    --border: #252b32;
    --accent: #ff6a00;
    --accent-2: #ff8533;
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body {
    display: flex; align-items: center; justify-content: center;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: radial-gradient(ellipse at 50% 40%, rgba(255,106,0,0.06) 0%, transparent 60%), var(--bg);
    color: var(--text);
  }
  .wrap { padding: 24px; width: 100%; max-width: 420px; }
  h1 {
    text-align: center; margin: 0 0 28px;
    font-size: 1.3rem; letter-spacing: 0.4px; color: var(--muted); font-weight: 600;
  }
  .links { display: flex; flex-direction: column; gap: 12px; }
  .links a {
    display: flex; align-items: center; gap: 14px;
    padding: 16px 22px;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    color: var(--text);
    font-weight: 700;
    font-size: 1.05rem;
    text-decoration: none;
    transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
  }
  .links a:hover {
    transform: translateY(-2px);
    border-color: var(--accent);
    box-shadow: 0 10px 26px rgba(255,106,0,0.15);
  }
  .links a .icon { font-size: 1.4rem; }
</style>
</head>
<body>
  <div class="wrap">
    <h1>Cuprins</h1>
    <div class="links">
      <?php foreach ($links as [$label, $href, $icon]): ?>
      <a href="<?= htmlspecialchars($href) ?>"><span class="icon"><?= $icon ?></span> <?= htmlspecialchars($label) ?></a>
      <?php endforeach; ?>
    </div>
  </div>
</body>
</html>
