<?php
// Started here (not in footer.php) so the shared footer can detect login status - by the time
// footer.php runs (near the end of <body>), headers are already sent and session_start() would fail.
session_start();
$publicLoggedIn = isset($_SESSION['ucp_player_id']);

// Read newspaper images
$newspaperDir = __DIR__ . '/newspaper';
$images = [];
if (is_dir($newspaperDir)) {
    $files = glob($newspaperDir . '/*.png');
    usort($files, function($a, $b) {
        return filemtime($a) <=> filemtime($b);
    });
    foreach ($files as $file) {
        $images[] = [
            'path' => 'newspaper/' . basename($file),
            'name' => basename($file)
        ];
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Newspaper</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
  :root {
    --bg: #0b0d10;
    --panel: #12161b;
    --panel-2: #171c22;
    --border: #252b32;
    --text: #f2f2f2;
    --muted: #8e969f;
    --accent: #ff6a00;
    --accent-2: #ff8533;
    --accent-soft: #e8a268;
    --green: #3ecf8e;
    --red: #ff5d5d;
  }
  @import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&display=swap');
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }

  .topbar {
    position: relative;
    display: grid; grid-template-columns: minmax(0,1fr) auto minmax(0,1fr); align-items: center; column-gap: 16px;
    row-gap: 8px; padding: 14px 24px;
    background: rgba(18, 22, 27, 0.72);
    backdrop-filter: blur(14px) saturate(140%);
    -webkit-backdrop-filter: blur(14px) saturate(140%);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0; z-index: 100; min-height: 64px;
  }
  .topbar::after {
    content: "";
    position: absolute; left: 0; right: 0; bottom: -1px; height: 1px;
    background: linear-gradient(90deg, transparent, rgba(255,106,0,0.6) 20%, rgba(255,133,51,0.4) 50%, rgba(255,106,0,0.6) 80%, transparent);
    opacity: 0.7;
  }
  .topbar .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 1.1rem; letter-spacing: 0.3px; color: #fff; text-decoration: none; transition: color 0.25s ease; white-space: nowrap; }
  .topbar .brand:hover { text-decoration: none; color: var(--accent); }
  .topbar .brand img {
    height: 34px; width: 34px; border-radius: 8px;
    border: 1px solid var(--border);
    transition: border-color 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease;
  }
  .topbar .brand:hover img {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(255,106,0,0.12), 0 4px 14px rgba(255,106,0,0.2);
    transform: rotate(-4deg) scale(1.05);
  }
  .topbar nav { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 6px 10px; justify-self: center; min-width: 0; }
  .topbar nav a {
    position: relative; display: inline-flex; align-items: center; justify-content: center;
    min-width: 108px; padding: 6px 12px;
    border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 0.92rem; text-decoration: none; text-align: center;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 600; letter-spacing: 0.3px;
    transition: color 0.25s ease, border-color 0.25s ease, background 0.25s ease;
  }
  .topbar nav a::after {
    content: "";
    position: absolute; left: 50%; bottom: 4px; width: 0; height: 2px;
    border-radius: 2px;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    transition: width 0.28s ease, left 0.28s ease;
  }
  .topbar nav a:hover { color: #fff; text-decoration: none; border-color: var(--accent-soft); background: var(--panel-2); }
  .topbar nav a:hover::after { width: calc(100% - 24px); left: 12px; }
  .nav-dd { position: relative; }
  .nav-dd-toggle { cursor: pointer; }
  .nav-dd-menu {
    display: none;
    position: absolute; top: 100%; left: 50%; transform: translateX(-50%); margin-top: 0;
    background: rgba(23, 28, 34, 0.92);
    backdrop-filter: blur(10px);
    border: 1px solid var(--border); border-radius: 8px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 14px 32px rgba(0,0,0,0.5);
  }
  .topbar .nav-dd-menu a { display: block; position: static; padding: 8px 10px; border: none; border-radius: 7px; font-size: 0.88rem; white-space: nowrap; text-decoration: none; transition: background 0.2s ease, color 0.2s ease; }
  .topbar .nav-dd-menu a::after { display: none; }
  .topbar .nav-dd-menu a:hover { background: rgba(255,106,0,0.1); border: none; color: var(--accent); text-decoration: none; }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }
  .topbar-toggle {
    display: none;
    align-items: center; justify-content: center;
    flex-direction: column; gap: 5px;
    width: 42px; height: 38px;
    background: transparent; border: 1px solid var(--border); border-radius: 8px;
    cursor: pointer; justify-self: end;
    transition: border-color 0.2s ease, background 0.2s ease;
  }
  .topbar-toggle:hover { border-color: var(--accent-soft); background: var(--panel-2); }
  .topbar-toggle span { display: block; width: 20px; height: 2px; background: var(--text); border-radius: 2px; transition: transform 0.25s ease, opacity 0.2s ease; }
  .topbar.nav-open .topbar-toggle span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
  .topbar.nav-open .topbar-toggle span:nth-child(2) { opacity: 0; }
  .topbar.nav-open .topbar-toggle span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }
  @media (min-width: 1400px) {
    .topbar nav { flex-wrap: nowrap; }
  }
  @media (min-width: 1000px) and (max-width: 1399px) {
    .topbar { grid-template-columns: 1fr; }
    .topbar nav { grid-column: 1 / -1; flex-wrap: wrap; }
  }
  @media (max-width: 999px) {
    .topbar { grid-template-columns: 1fr auto; }
    .topbar-toggle { display: flex; }
    .topbar nav { display: none; grid-column: 1 / -1; justify-self: stretch; }
    .topbar.nav-open nav { display: flex; flex-direction: column; align-items: stretch; gap: 4px; padding-top: 12px; }
    .topbar nav a { width: 100%; min-width: 0; justify-content: flex-start; }
    .topbar nav a::after { display: none; }
  }
  .brand-dd { position: relative; display: flex; align-items: center; padding-bottom: 10px; margin-bottom: -10px; justify-self: start; min-width: 0; }
  .brand-dd-caret {
    margin-left: 6px;
    font-size: 0.62rem;
    color: var(--muted);
    transition: transform 0.25s ease, color 0.25s ease;
  }
  .brand-dd:hover .brand-dd-caret, .brand-dd:focus-within .brand-dd-caret { color: var(--accent); transform: rotate(180deg); }
  .brand-dd-menu {
    display: flex; gap: 10px;
    position: absolute; top: 100%; left: 0;
  background: transparent;
  padding: 6px;
  z-index: 200;
    white-space: nowrap;
    opacity: 0; visibility: hidden; pointer-events: none;
    transform: translateY(-22px);
    transition: opacity 0.25s ease, transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), visibility 0.25s;
  }
  .brand-dd:hover .brand-dd-menu, .brand-dd:focus-within .brand-dd-menu {
    opacity: 1; visibility: visible; pointer-events: auto; transform: translateY(0);
  }
  .brand-dd-menu { align-items: center; padding: 10px 12px; }
  @property --bdd-angle {
    syntax: '<angle>';
    initial-value: 0deg;
    inherits: false;
  }
  @keyframes brand-dd-spin { to { --bdd-angle: 360deg; } }
  .brand-dd-box {
    position: relative;
    isolation: isolate;
    display: flex; align-items: center; justify-content: center;
    width: 108px; padding: 7px 10px;
    border-radius: 8px;
    font-size: 0.92rem; font-weight: 600;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; letter-spacing: 0.3px;
    color: var(--text); text-align: center; text-decoration: none;
    border: 1px solid var(--border);
    transform: perspective(600px) translateY(0) rotateX(0deg);
    transition: transform 0.35s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.35s ease, border-color 0.25s ease, color 0.25s ease;
  }
  .brand-dd-box::before {
    content: "";
    position: absolute; inset: -1px;
    z-index: -1;
    padding: 1.5px;
    border-radius: inherit;
    background: conic-gradient(from var(--bdd-angle), var(--accent), var(--accent-2), transparent 35%, transparent 65%, var(--accent));
    -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    opacity: 0;
    transition: opacity 0.35s ease;
    animation: brand-dd-spin 3s linear infinite paused;
  }
  .brand-dd-box:hover {
    transform: perspective(600px) translateY(-4px) rotateX(6deg);
    box-shadow: 0 10px 22px rgba(0,0,0,0.35), 0 0 18px rgba(255,106,0,0.18);
    border-color: transparent; color: #fff;
    text-decoration: none;
  }
  .brand-dd-box:hover::before { opacity: 1; animation-play-state: running; }

  .brand-cj-idle { position: relative; width: 22px; height: 40px; flex-shrink: 0; }
  .brand-cj-idle .bcj-head { position: absolute; top: 0; left: 6px; width: 11px; height: 11px; background: #a5673f; border-radius: 50%; }
  .brand-cj-idle .bcj-head::before { content: ""; position: absolute; top: -3px; left: -1px; width: 13px; height: 6px; background: #191512; border-radius: 7px 7px 0 0; }
  .brand-cj-idle .bcj-torso { position: absolute; top: 13px; left: 5px; width: 12px; height: 16px; background: #f0f0ec; border-radius: 3px 3px 2px 2px; }
  .brand-cj-idle .bcj-arm { position: absolute; top: 15px; width: 5px; height: 14px; background: #a5673f; border-radius: 2px; transform-origin: top center; animation: brand-cj-swing 0.32s ease-in-out infinite alternate; }
  .brand-cj-idle .bcj-arm-l { left: 1px; animation-direction: alternate-reverse; }
  .brand-cj-idle .bcj-arm-r { left: 16px; }
  .brand-cj-idle .bcj-leg { position: absolute; bottom: 0; width: 6px; height: 15px; background: #3a5a96; border-radius: 2px; transform-origin: top center; animation: brand-cj-swing 0.32s ease-in-out infinite alternate; }
  .brand-cj-idle .bcj-leg-l { left: 4px; }
  .brand-cj-idle .bcj-leg-r { left: 12px; animation-direction: alternate-reverse; }
  @keyframes brand-cj-swing { 0% { transform: rotate(-20deg); } 100% { transform: rotate(20deg); } }

main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 50px 24px 80px;
  }

  .newspaper-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 40px;
    margin-bottom: 60px;
  }
  @media (max-width: 900px) {
    .newspaper-grid { grid-template-columns: 1fr; gap: 30px; }
  }

  .page-spread {
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 10px 40px rgba(0,0,0,0.4);
    transition: transform 0.2s, box-shadow 0.2s;
    cursor: pointer;
  }
  .page-spread:hover {
    transform: translateY(-4px);
    box-shadow: 0 15px 50px rgba(0,0,0,0.6);
  }

  .page-image {
    width: 100%;
    height: auto;
    display: block;
    background: #000;
  }

  .page-info {
    padding: 18px 20px;
        border-top: 1px solid var(--border);
  }
  .page-info h3 {
    margin: 0 0 6px;
    font-size: 1.1rem;
    color: var(--accent-2);
    word-wrap: break-word;
    overflow-wrap: break-word;
    word-break: break-word;
    max-width: 100%;
    display: block;
    min-height: 1.4rem;
  }
  .page-info p {
    margin: 0;
    font-size: 0.9rem;
    color: var(--muted);
  }

  .modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.95);
    z-index: 1000;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .modal.active {
    display: flex;
  }

  .modal-content {
    position: relative;
    max-width: 90%;
    max-height: 90vh;
    overflow: auto;
  }
  .modal-image {
    width: 100%;
    height: auto;
    display: block;
  }

  .modal-close {
    position: absolute;
    top: 20px;
    right: 20px;
    background: rgba(255,255,255,0.2);
    border: none;
    color: #fff;
    font-size: 2rem;
    cursor: pointer;
    width: 50px;
    height: 50px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }
  .modal-close:hover {
    background: rgba(255,255,255,0.3);
  }

  .modal-nav {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(255,255,255,0.2);
    border: none;
    color: #fff;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 15px 20px;
    border-radius: 6px;
    transition: background 0.2s;
  }
  .modal-nav:hover {
    background: rgba(255,255,255,0.3);
  }
  .modal-prev { left: 20px; }
  .modal-next { right: 20px; }

  footer { text-align: center; padding: 30px 24px; color: var(--muted); font-size: 0.85rem; border-top: 1px solid var(--border); }
  .auth-modal-overlay {
    position: fixed; inset: 0; z-index: 1000;
    display: flex; align-items: center; justify-content: center;
    padding: 20px;
    opacity: 0; visibility: hidden; pointer-events: none;
    transition: opacity 0.25s ease, visibility 0.25s;
  }
  .auth-modal-overlay.is-open { opacity: 1; visibility: visible; pointer-events: auto; }
  .auth-modal-backdrop {
    position: absolute; inset: 0;
    background: rgba(8,9,11,0.72);
    backdrop-filter: blur(6px);
  }
  .auth-modal-card {
    position: relative; z-index: 1;
    width: 920px; max-width: 100%;
    background: linear-gradient(160deg, var(--panel) 0%, var(--panel-2) 100%);
    border: 1px solid var(--border);
    border-radius: 18px;
    padding: 0;
    box-shadow: 0 30px 70px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,106,0,0.06);
    overflow: hidden;
    transform: scale(0.92) translateY(10px);
    transition: transform 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
  }
  .auth-modal-overlay.is-open .auth-modal-card { transform: scale(1) translateY(0); }
  .auth-modal-card::before {
    content: "";
    position: absolute; top: 0; left: 0; right: 0; height: 3px; z-index: 2;
    background: linear-gradient(90deg, var(--accent), var(--accent-2), var(--accent));
  }
  .auth-modal-body { display: flex; }
  .auth-modal-form-col { flex: 1; min-width: 0; padding: 40px 32px 30px; display: flex; flex-direction: column; justify-content: center; }
  .auth-modal-image-col {
    width: 480px; flex-shrink: 0;
    padding: 30px;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2);
    border-left: 1px solid var(--border);
  }
  @media (max-width: 720px) {
    .auth-modal-card { width: 100%; }
    .auth-modal-body { flex-direction: column-reverse; }
    .auth-modal-image-col { width: 100%; border-left: none; border-top: 1px solid var(--border); padding: 16px 0; }
  }
  @keyframes auth-shake {
    10%, 90% { transform: translateX(-1px); }
    20%, 80% { transform: translateX(2px); }
    30%, 50%, 70% { transform: translateX(-4px); }
    40%, 60% { transform: translateX(4px); }
  }
  .auth-modal-card.shake { animation: auth-shake 0.45s; }
  .auth-modal-logo { display: block; width: 420px; height: 420px; max-width: 100%; margin: 0; border-radius: 12px; border: none; object-fit: cover; }
  .auth-modal-title {
    text-align: center; margin: 0 0 22px;
    font-size: 1.2rem; font-weight: 700; letter-spacing: 0.3px; color: #fff;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif;
  }
  .auth-modal-close {
    position: absolute; top: 14px; right: 14px; z-index: 2;
    width: 30px; height: 30px;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 50%;
    color: var(--muted); font-size: 1.2rem; line-height: 1; cursor: pointer; padding: 0;
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease, transform 0.2s ease;
  }
  .auth-modal-close:hover { background: rgba(255,93,93,0.12); border-color: var(--red); color: var(--red); transform: rotate(90deg); }
  .auth-tabs {
    position: relative; display: flex; gap: 4px;
    background: var(--bg); border: 1px solid var(--border); border-radius: 11px;
    padding: 4px; margin-bottom: 22px;
  }
  .auth-tabs-indicator {
    position: absolute; top: 4px; left: 0; height: calc(100% - 8px);
    border-radius: 8px;
    background: linear-gradient(135deg, var(--accent), var(--accent-2));
    transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1), width 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    z-index: 0;
  }
  .auth-tab {
    position: relative; z-index: 1; flex: 1;
    padding: 9px; border-radius: 8px;
    background: transparent; border: none;
    color: var(--muted); font-weight: 700; cursor: pointer;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; letter-spacing: 0.3px; font-size: 0.92rem;
    transition: color 0.2s ease;
  }
  .auth-tab.active { color: #0f1115; }
  .auth-modal-error {
    background: rgba(255,93,93,0.1); border: 1px solid var(--red); color: var(--red);
    padding: 10px 14px; border-radius: 8px; font-size: 0.85rem; margin-bottom: 16px;
  }
  .auth-field { position: relative; margin-bottom: 14px; }
  .auth-field-icon {
    position: absolute; left: 13px; top: 50%; transform: translateY(-50%);
    font-size: 0.9rem; opacity: 0.55; pointer-events: none;
  }
  .auth-field input {
    width: 100%; padding: 11px 14px 11px 38px;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 10px;
    color: var(--text); font-size: 0.95rem;
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
  }
  .auth-field input:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(255,106,0,0.15); }
  .auth-submit {
    width: 100%; margin-top: 8px; padding: 12px;
    background: linear-gradient(135deg, var(--accent), var(--accent-2));
    border: none; border-radius: 10px;
    color: #0f1115; font-weight: 700; font-size: 0.98rem; cursor: pointer;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; letter-spacing: 0.3px;
    transition: transform 0.2s ease, box-shadow 0.2s ease, opacity 0.2s ease;
  }
  .auth-submit:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(255,106,0,0.35); }
  .auth-submit:disabled { opacity: 0.7; cursor: default; }
  .auth-terms { margin-top: 14px; font-size: 0.76rem; color: var(--muted); text-align: center; line-height: 1.5; }
  .auth-register-info { text-align: center; }
  .auth-register-info p { color: var(--muted); font-size: 0.88rem; line-height: 1.6; margin: 0 0 14px; }
  .auth-register-info p strong { color: #fff; font-family: 'Rajdhani', 'Segoe UI', sans-serif; letter-spacing: 0.3px; }
  .auth-register-info p a { color: var(--accent); font-weight: 700; }
  .auth-connect-btn { display: block; text-decoration: none; text-align: center; margin-top: 8px; }
</style>
</head>
<body>

<header class="topbar">
  <div class="brand-dd">
    <a href="index.php" class="brand"><img src="ucp/assets/img/logo.jpg" alt="" class="brand-logo"> No-Santos <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</a>
    <span class="brand-dd-caret">▾</span>
    <div class="brand-dd-menu">
      <a href="forum.php" class="brand-dd-box">💬 Forum</a>
      <div class="brand-cj-idle" aria-hidden="true">
        <span class="bcj-head"></span>
        <span class="bcj-torso"></span>
        <span class="bcj-arm bcj-arm-l"></span>
        <span class="bcj-arm bcj-arm-r"></span>
        <span class="bcj-leg bcj-leg-l"></span>
        <span class="bcj-leg bcj-leg-r"></span>
      </div>
      <?php if ($publicLoggedIn): ?>
        <a href="ucp/dashboard.php" class="brand-dd-box">🧭 UCP</a>
      <?php else: ?>
        <a href="#" class="brand-dd-box auth-login-trigger">🧭 UCP</a>
      <?php endif; ?>
    </div>
  </div>
  <button type="button" class="topbar-toggle" id="topbarToggle" aria-label="Toggle menu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <nav>
    <a href="index.php">🏠 Homepage</a>
    <a href="presentation.php">🏙️ Presentation</a>
    <a href="forum.php">💬 Forum</a>
    <a href="games/index.php">🎮 Games</a>
    <a href="newspaper.php">📰 Newspaper</a>
    <?php if ($publicLoggedIn): ?>
      <a href="ucp/dashboard.php">🧭 UCP</a>
    <?php else: ?>
      <a href="#" class="auth-login-trigger">🧭 UCP</a>
    <?php endif; ?>
  </nav>
</header>

<script>
(function() {
  var topbar = document.querySelector('header.topbar');
  var toggle = document.getElementById('topbarToggle');
  if (!toggle) return;
  toggle.addEventListener('click', function() {
    var open = topbar.classList.toggle('nav-open');
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
})();
</script>

<?php require __DIR__ . '/includes/auth_modal.php'; ?>

<main>
  <div class="newspaper-grid">
    <?php foreach ($images as $index => $image): ?>
    <div class="page-spread" onclick="openModal(<?= $index ?>)">
      <img src="<?= htmlspecialchars($image['path']) ?>" alt="Page" class="page-image">
      <div class="page-info">
        <p>📄 Click to view full page</p>
      </div>
    </div>
    <?php endforeach; ?>
  </div>

  <?php if (empty($images)): ?>
  <div class="page-spread" style="padding: 40px; text-align: center;">
    <p style="color: var(--muted);">No newspaper pages found. Add images to the newspaper/ folder.</p>
  </div>
  <?php endif; ?>
</main>

<div class="modal" id="modal">
  <div class="modal-content">
    <button class="modal-close" onclick="closeModal()">✕</button>
    <button class="modal-nav modal-prev" onclick="prevPage()">❮</button>
    <img src="" alt="Full page" class="modal-image" id="modalImage">
    <button class="modal-nav modal-next" onclick="nextPage()">❯</button>
  </div>
</div>

<?php include __DIR__ . '/includes/footer.php'; ?>

<script>
  let currentPage = 0;
  const pages = <?= json_encode(array_map(fn($img) => $img['path'], $images)) ?>;

  function openModal(index) {
    currentPage = index;
    const modal = document.getElementById('modal');
    const img = document.getElementById('modalImage');
    img.src = pages[currentPage];
    modal.classList.add('active');
  }

  function closeModal() {
    document.getElementById('modal').classList.remove('active');
  }

  function nextPage() {
    currentPage = (currentPage + 1) % pages.length;
    document.getElementById('modalImage').src = pages[currentPage];
  }

  function prevPage() {
    currentPage = (currentPage - 1 + pages.length) % pages.length;
    document.getElementById('modalImage').src = pages[currentPage];
  }

  document.addEventListener('keydown', (e) => {
    if (!document.getElementById('modal').classList.contains('active')) return;
    if (e.key === 'ArrowRight') nextPage();
    if (e.key === 'ArrowLeft') prevPage();
    if (e.key === 'Escape') closeModal();
  });
</script>

</body>
</html>
