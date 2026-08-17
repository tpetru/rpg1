<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
  .topbar {
    position: sticky;
    top: 0;
    z-index: 100;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    row-gap: 8px;
    min-height: 64px;
    padding: 14px 24px;
    background: rgba(18, 22, 27, 0.72);
    backdrop-filter: blur(14px) saturate(140%);
    -webkit-backdrop-filter: blur(14px) saturate(140%);
    border-bottom: 1px solid var(--border);
  }
  .topbar::after {
    content: "";
    position: absolute;
    left: 0; right: 0; bottom: -1px;
    height: 1px;
    background: linear-gradient(90deg, transparent, rgba(255,106,0,0.6) 20%, rgba(255,133,51,0.4) 50%, rgba(255,106,0,0.6) 80%, transparent);
    opacity: 0.7;
  }
  .topbar .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 1.1rem; letter-spacing: 0.3px; color: #fff; text-decoration: none; transition: color 0.25s ease; }
  .topbar .brand:hover { text-decoration: none; color: var(--accent); }
  .topbar .brand-logo {
    height: 34px; width: 34px;
    border-radius: 8px;
    border: 1px solid var(--border);
    transition: border-color 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease;
  }
  .topbar .brand:hover .brand-logo {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(255,106,0,0.12), 0 4px 14px rgba(255,106,0,0.2);
    transform: rotate(-4deg) scale(1.05);
  }
  .topbar nav { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 20px; }
  .topbar nav a {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 108px;
    padding: 6px 12px;
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text);
    font-size: 0.92rem;
    text-decoration: none;
    text-align: center;
    transition: color 0.25s ease, border-color 0.25s ease, background 0.25s ease;
  }
  .topbar nav a::after {
    content: "";
    position: absolute;
    left: 50%;
    bottom: 4px;
    width: 0;
    height: 2px;
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
    border: 1px solid var(--border); border-radius: 10px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 14px 32px rgba(0,0,0,0.5);
  }
  .topbar .nav-dd-menu a { display: block; position: static; padding: 8px 10px; border: none; border-radius: 7px; font-size: 0.88rem; white-space: nowrap; text-decoration: none; transition: background 0.2s ease, color 0.2s ease; }
  .topbar .nav-dd-menu a::after { display: none; }
  .topbar .nav-dd-menu a:hover { background: rgba(255,106,0,0.1); border: none; color: var(--accent); text-decoration: none; }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }
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
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.65;
  }
  a { color: var(--accent); text-decoration: none; }

  header.hero {
    position: relative;
    overflow: hidden;
    padding: 100px 24px 56px;
    text-align: center;
    background:
      radial-gradient(ellipse at 20% 0%, rgba(255,106,0,0.06) 0%, transparent 55%),
      radial-gradient(ellipse at 80% 10%, rgba(255,133,51,0.03) 0%, transparent 50%),
      linear-gradient(180deg, #1a1410 0%, #0b0d10 75%);
    border-bottom: 1px solid var(--border);
  }
  header.hero::before {
    content: "";
    position: absolute;
    inset: 0;
    background-image:
      linear-gradient(rgba(255,106,0,0.02) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255,106,0,0.02) 1px, transparent 1px);
    background-size: 42px 42px;
    mask-image: radial-gradient(ellipse at center, black 0%, transparent 75%);
    pointer-events: none;
  }
  .tagline {
    position: relative;
    z-index: 1;
    display: inline-block;
    width: 270px;
    text-align: center;
    margin: 0 0 16px;
    padding: 6px 16px;
    border: 1px solid var(--accent);
    border-radius: 999px;
    color: #cc8a52;
    background: rgba(255,106,0,0.08);
    font-size: 0.82rem;
    font-weight: 700;
    letter-spacing: 1.5px;
    text-transform: uppercase;
  }
  header.hero h1 {
    position: relative;
    z-index: 1;
    margin: 0 0 12px;
    font-size: 3rem;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--text);
    text-shadow: 0 0 24px rgba(255,106,0,0.1);
  }
  header.hero h1 .accent-word {
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }
  header.hero p { position: relative; z-index: 1; margin: 0; color: var(--muted); font-size: 1.05rem; }

  main {
    flex: 1;
    max-width: 1400px;
    width: 100%;
    margin: 0 auto;
    padding: 30px 24px 80px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 32px;
    max-width: 1180px;
    margin: 0 auto;
  }
  @media (max-width: 1100px) {
    .grid { grid-template-columns: repeat(2, 1fr); max-width: 700px; }
  }
  @media (max-width: 620px) {
    .grid { grid-template-columns: 1fr; max-width: 480px; }
  }

  @property --angle {
    syntax: '<angle>';
    initial-value: 0deg;
    inherits: false;
  }
  @keyframes spin-border { to { --angle: 360deg; } }

  .card {
    --x: 50%;
    --y: 50%;
    position: relative;
    display: block;
    isolation: isolate;
    overflow: hidden;
    background: linear-gradient(160deg, var(--panel) 0%, var(--panel-2) 100%);
    border-radius: 48px 20px 48px 20px;
    padding: 60px 40px;
    min-height: 320px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    transition: transform 0.35s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.35s ease, border-radius 0.35s ease;
    transform: perspective(800px) translateY(0) rotateX(0deg);
    will-change: transform;
  }
  .card:nth-child(2) { border-radius: 20px 48px 20px 48px; }
  .card:hover { border-radius: 34px 34px 34px 34px; }
  /* rotating conic-gradient frame, revealed only on hover */
  .card::before {
    content: "";
    position: absolute;
    inset: 0;
    z-index: -2;
    padding: 1.5px;
    border-radius: inherit;
    background: conic-gradient(from var(--angle), var(--accent), var(--accent-2), transparent 35%, transparent 65%, var(--accent));
    -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    opacity: 0;
    transition: opacity 0.35s ease;
    animation: spin-border 4s linear infinite paused;
  }
  /* base hairline border, always visible, fades under the glow frame */
  .card::after {
    content: "";
    position: absolute;
    inset: 0;
    z-index: -3;
    border-radius: inherit;
    border: 1px solid var(--border);
    transition: opacity 0.35s ease;
  }
  /* cursor-tracked spotlight */
  .card .spot {
    position: absolute;
    inset: 0;
    z-index: -1;
    border-radius: inherit;
    background: radial-gradient(320px circle at var(--x) var(--y), rgba(255,106,0,0.13), transparent 65%);
    opacity: 0;
    transition: opacity 0.3s ease;
  }
  .card:hover {
    text-decoration: none;
    transform: perspective(800px) translateY(-8px) rotateX(2deg);
    box-shadow: 0 24px 48px rgba(0,0,0,0.4), 0 0 30px rgba(255,106,0,0.08);
  }
  .card:hover::before { opacity: 1; animation-play-state: running; }
  .card:hover::after { opacity: 0; }
  .card:hover .spot { opacity: 1; }

  .card .icon {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 84px;
    height: 84px;
    margin: 0 auto 22px;
    border-radius: 24px;
    font-size: 2.4rem;
    background: radial-gradient(circle at 30% 30%, rgba(255,106,0,0.2), rgba(255,133,51,0.08));
    border: 1px solid var(--border);
    transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), border-color 0.35s ease, box-shadow 0.35s ease;
  }
  .card .icon::after {
    content: "";
    position: absolute;
    inset: -6px;
    border-radius: 22px;
    background: radial-gradient(circle, rgba(255,106,0,0.3), transparent 70%);
    opacity: 0;
    transition: opacity 0.35s ease;
    z-index: -1;
    animation: pulse-glow 2.2s ease-in-out infinite;
  }
  @keyframes pulse-glow {
    0%, 100% { transform: scale(0.92); }
    50% { transform: scale(1.08); }
  }
  .card:hover .icon {
    transform: scale(1.1) rotate(-8deg);
    border-color: var(--accent);
    box-shadow: 0 8px 20px rgba(255,106,0,0.22);
  }
  .card:hover .icon::after { opacity: 1; }

  .card h2 {
    margin: 0 0 8px;
    font-size: 1.32rem;
    color: #fff;
    letter-spacing: 0.3px;
    transition: transform 0.35s ease;
  }
  .card:hover h2 { transform: translateY(-2px); }
  .card p { margin: 0; color: var(--muted); font-size: 0.9rem; }
  .card .go {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-top: 18px;
    font-size: 0.78rem;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--accent);
    opacity: 0;
    transform: translateY(6px);
    transition: opacity 0.35s ease, transform 0.35s ease;
  }
  .card .go span {
    display: inline-block;
    transition: transform 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
  }
  .card:hover .go { opacity: 1; transform: translateY(0); }
  .card:hover .go span { transform: translateX(4px); }

  /* CJ walk-on easter egg — appears on a random edge/direction each hover */
  .cj {
    position: absolute;
    pointer-events: none;
    opacity: 0;
    z-index: 5;
    transition: opacity 0.2s ease;
  }
  .card:hover .cj.cj-run { opacity: 1; }

  /* strip along the edge the sprite travels */
  .cj.path-bottom-ltr, .cj.path-bottom-rtl { left: 0; right: 0; bottom: 16px; height: 46px; }
  .cj.path-top-ltr, .cj.path-top-rtl { left: 0; right: 0; top: 16px; height: 46px; }
  .cj.path-left-btt, .cj.path-left-ttb { top: 0; bottom: 0; left: 16px; width: 46px; }
  .cj.path-right-btt, .cj.path-right-ttb { top: 0; bottom: 0; right: 16px; width: 46px; }

  .cj-sprite {
    position: absolute;
    width: 22px;
    height: 40px;
    animation-duration: 3s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
  }
  .path-bottom-ltr .cj-sprite { bottom: 0; left: -32px; animation-name: cj-move-x-ltr; }
  .path-bottom-rtl .cj-sprite { bottom: 0; right: -32px; animation-name: cj-move-x-rtl; transform: scaleX(-1); }
  .path-top-ltr .cj-sprite { top: 0; left: -32px; animation-name: cj-move-x-ltr; }
  .path-top-rtl .cj-sprite { top: 0; right: -32px; animation-name: cj-move-x-rtl; transform: scaleX(-1); }
  .path-left-btt .cj-sprite { left: 0; bottom: -44px; animation-name: cj-move-y-btt; }
  .path-left-ttb .cj-sprite { left: 0; top: -44px; animation-name: cj-move-y-ttb; }
  .path-right-btt .cj-sprite { right: 0; bottom: -44px; animation-name: cj-move-y-btt; }
  .path-right-ttb .cj-sprite { right: 0; top: -44px; animation-name: cj-move-y-ttb; }

  @keyframes cj-move-x-ltr {
    0% { left: -32px; }
    100% { left: 100%; }
  }
  @keyframes cj-move-x-rtl {
    0% { right: -32px; }
    100% { right: 100%; }
  }
  @keyframes cj-move-y-btt {
    0% { bottom: -44px; }
    100% { bottom: 100%; }
  }
  @keyframes cj-move-y-ttb {
    0% { top: -44px; }
    100% { top: 100%; }
  }
  .cj-head {
    position: absolute;
    top: 0;
    left: 6px;
    width: 11px;
    height: 11px;
    background: #a5673f;
    border-radius: 50%;
  }
  .cj-head::before {
    content: "";
    position: absolute;
    top: -3px;
    left: -1px;
    width: 13px;
    height: 6px;
    background: #191512;
    border-radius: 7px 7px 0 0;
  }
  .cj-torso {
    position: absolute;
    top: 13px;
    left: 5px;
    width: 12px;
    height: 16px;
    background: #f0f0ec;
    border-radius: 3px 3px 2px 2px;
  }
  .cj-arm {
    position: absolute;
    top: 15px;
    width: 5px;
    height: 14px;
    background: #a5673f;
    border-radius: 2px;
    transform-origin: top center;
    animation: cj-swing 0.32s ease-in-out infinite alternate;
  }
  .cj-arm-l { left: 1px; animation-direction: alternate-reverse; }
  .cj-arm-r { left: 16px; }
  .cj-leg {
    position: absolute;
    bottom: 0;
    width: 6px;
    height: 15px;
    background: #3a5a96;
    border-radius: 2px;
    transform-origin: top center;
    animation: cj-swing 0.32s ease-in-out infinite alternate;
  }
  .cj-leg-l { left: 4px; }
  .cj-leg-r { left: 12px; animation-direction: alternate-reverse; }
  @keyframes cj-swing {
    0% { transform: rotate(-20deg); }
    100% { transform: rotate(20deg); }
  }

  .topbar .brand-logo { border: 1px solid var(--border); }

  footer { text-align: center; padding: 24px; color: var(--muted); font-size: 0.82rem; border-top: 1px solid var(--border); }
</style>
</head>
<body>

<header class="topbar">
  <a href="index.php" class="brand"><img src="ucp/assets/img/logo.jpg" alt="" class="brand-logo"> Nostalgia: Los Santos | RPG</a>
  <nav>
    <a href="index.php">🏠 Homepage</a>
    <a href="presentation.php">🏙️ Presentation</a>
    <a href="newspaper.php">📰 Newspaper</a>
    <a href="ucp/index.php">🧭 UCP</a>
    <a href="ucp/forum.php">💬 Forum</a>
  </nav>
</header>

<header class="hero">
  <div class="tagline">Welcome to No-Santos</div>
  <h1>🌴 Nostalgia: <span class="accent-word">Los Santos</span> | RPG</h1>
  <p>"Ah shit, here we go again."</p>
</header>

<main>
  <div class="grid">
    <a class="card" href="ucp/index.php">
      <div class="spot"></div>
      <div class="icon">🧭</div>
      <h2>UCP</h2>
      <p>The account control panel — login, stats, properties, factions and administration.</p>
      <span class="go">Enter <span>→</span></span>
      <div class="cj" aria-hidden="true">
        <div class="cj-sprite">
          <span class="cj-head"></span>
          <span class="cj-torso"></span>
          <span class="cj-arm cj-arm-l"></span>
          <span class="cj-arm cj-arm-r"></span>
          <span class="cj-leg cj-leg-l"></span>
          <span class="cj-leg cj-leg-r"></span>
        </div>
      </div>
    </a>

    <a class="card" href="presentation.php">
      <div class="spot"></div>
      <div class="icon">🏙️</div>
      <h2>Presentation</h2>
      <p>The server's presentation — welcome to Nostalgia: Los Santos | RPG.</p>
      <span class="go">Enter <span>→</span></span>
      <div class="cj" aria-hidden="true">
        <div class="cj-sprite">
          <span class="cj-head"></span>
          <span class="cj-torso"></span>
          <span class="cj-arm cj-arm-l"></span>
          <span class="cj-arm cj-arm-r"></span>
          <span class="cj-leg cj-leg-l"></span>
          <span class="cj-leg cj-leg-r"></span>
        </div>
      </div>
    </a>

    <a class="card" href="ucp/forum.php">
      <div class="spot"></div>
      <div class="icon">💬</div>
      <h2>Forum</h2>
      <p>Suggestions, complaints, bugs, faction regulations and the server's rules.</p>
      <span class="go">Enter <span>→</span></span>
      <div class="cj" aria-hidden="true">
        <div class="cj-sprite">
          <span class="cj-head"></span>
          <span class="cj-torso"></span>
          <span class="cj-arm cj-arm-l"></span>
          <span class="cj-arm cj-arm-r"></span>
          <span class="cj-leg cj-leg-l"></span>
          <span class="cj-leg cj-leg-r"></span>
        </div>
      </div>
    </a>
  </div>
</main>

<footer>Nostalgia: Los Santos | RPG · <a href="tc.html">Terms &amp; Conditions</a></footer>

<script>
  document.querySelectorAll('.card').forEach(function (card) {
    card.addEventListener('mousemove', function (e) {
      var rect = card.getBoundingClientRect();
      card.style.setProperty('--x', (e.clientX - rect.left) + 'px');
      card.style.setProperty('--y', (e.clientY - rect.top) + 'px');
    });

    var cj = card.querySelector('.cj');
    if (cj) {
      var paths = [
        'bottom-ltr', 'bottom-rtl',
        'left-btt', 'left-ttb',
        'right-btt', 'right-ttb',
        'top-ltr', 'top-rtl'
      ];
      card.addEventListener('mouseenter', function () {
        var path = paths[Math.floor(Math.random() * paths.length)];
        cj.className = 'cj path-' + path;
        void cj.offsetWidth;
        cj.classList.add('cj-run');
      });
      card.addEventListener('mouseleave', function () {
        cj.classList.remove('cj-run');
      });
    }
  });
</script>

</body>
</html>
