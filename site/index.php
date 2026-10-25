<?php
// The real homepage lives at /samp/index.php while the site is temporarily kept off the bare "/" URL -
// this placeholder intentionally has no links or hints pointing there.
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
  :root {
    --bg: #0b0d10;
    --text: #f2f2f2;
    --muted: #8e969f;
    --accent: #ff6a00;
  }
  * { box-sizing: border-box; }
  html, body {
    height: 100%;
    margin: 0;
  }
  body {
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: radial-gradient(ellipse at 50% 40%, rgba(255,106,0,0.05) 0%, transparent 60%), var(--bg);
    color: var(--text);
    text-align: center;
  }
  .box { padding: 24px; display: flex; flex-direction: column; gap: 14px; }
  .box a {
    display: inline-block;
    padding: 14px 34px;
    background: linear-gradient(135deg, var(--accent), #ff8533);
    border-radius: 999px;
    color: #0f1115;
    font-weight: 700;
    font-size: 1.05rem;
    letter-spacing: 0.4px;
    text-decoration: none;
    box-shadow: 0 10px 26px rgba(255,106,0,0.28);
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }
  .box a:hover { transform: translateY(-2px); box-shadow: 0 16px 34px rgba(255,106,0,0.38); }
</style>
</head>
<body>
  <div class="box">
    <a href="https://casa.no-santos.com/">Spre Casa →</a>
    <a href="https://aris.no-santos.com/">Spre Aris →</a>
    <a href="https://docs.no-santos.com/">Spre Docs →</a>
    <a href="https://city.no-santos.com/">Spre City →</a>
  </div>
</body>
</html>
