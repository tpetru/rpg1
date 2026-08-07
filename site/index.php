<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
  .topbar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; row-gap: 8px; padding: 14px 24px; background: var(--panel); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 100; min-height: 60px; }
  .topbar .brand { display: flex; align-items: center; gap: 9px; font-weight: 700; font-size: 1.1rem; color: #fff; text-decoration: none; }
  .topbar .brand:hover { text-decoration: none; opacity: 0.9; }
  .topbar .brand-logo { height: 32px; width: 32px; border-radius: 6px; }
  .topbar nav { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 16px; }
  .topbar nav a { color: var(--text); font-size: 0.92rem; text-decoration: none; }
  .topbar nav a:hover { color: var(--accent); text-decoration: none; }
  .nav-dd { position: relative; }
  .nav-dd-toggle { cursor: pointer; }
  .nav-dd-menu {
    display: none;
    position: absolute; top: 100%; left: 0; margin-top: 0;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .nav-dd-menu a { display: block; padding: 7px 10px; border-radius: 6px; font-size: 0.88rem; white-space: nowrap; text-decoration: none; }
  .nav-dd-menu a:hover { background: var(--panel); text-decoration: none; }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }
  :root {
    --bg: #0f1115;
    --panel: #161922;
    --panel-2: #1d212c;
    --border: #2a2f3d;
    --text: #d8dce5;
    --muted: #8b93a7;
    --accent: #5b9dff;
    --accent-2: #ffcc00;
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
    padding: 80px 24px 40px;
    text-align: center;
    background: radial-gradient(ellipse at top, #1b2030 0%, #0f1115 70%);
    border-bottom: 1px solid var(--border);
  }
  header.hero h1 {
    margin: 0 0 12px;
    font-size: 2.6rem;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }
  header.hero p { margin: 0; color: var(--muted); font-size: 1.05rem; }

  main {
    flex: 1;
    max-width: 1400px;
    width: 100%;
    margin: 0 auto;
    padding: 30px 24px 80px;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 20px;
    max-width: 700px;
    margin: 0 auto;
  }
  @media (max-width: 800px) {
    .grid { grid-template-columns: 1fr; }
  }

  .card {
    display: block;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 32px 24px;
    text-align: center;
    transition: transform 0.15s, border-color 0.15s, background 0.15s;
  }
  .card:hover {
    text-decoration: none;
    transform: translateY(-4px);
    border-color: var(--accent);
    background: var(--panel-2);
  }
  .card .icon { font-size: 2.6rem; margin-bottom: 14px; }
  .card h2 { margin: 0 0 8px; font-size: 1.25rem; color: #fff; }
  .card p { margin: 0; color: var(--muted); font-size: 0.9rem; }

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
  </nav>
</header>

<header class="hero">
  <h1>🏙️ Nostalgia: Los Santos | RPG</h1>
  <p>Choose where you want to go.</p>
</header>

<main>
  <div class="grid">
    <a class="card" href="ucp/index.php">
      <div class="icon">🧭</div>
      <h2>UCP</h2>
      <p>The account control panel — login, stats, properties, factions and administration.</p>
    </a>

    <a class="card" href="presentation.php">
      <div class="icon">🏙️</div>
      <h2>Presentation</h2>
      <p>The server's presentation — welcome to Nostalgia: Los Santos | RPG.</p>
    </a>
  </div>
</main>

<footer>Nostalgia: Los Santos | RPG</footer>

</body>
</html>
