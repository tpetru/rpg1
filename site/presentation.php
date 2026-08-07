<?php
$houseCount = 0;
$businessCount = 0;
$hotelCount = 0;
$farmCount = 0;
$forestCount = 0;

try {
    require_once __DIR__ . '/includes/db.php';
    require_once __DIR__ . '/includes/functions.php';

    if ($mysqli && $mysqli->ping()) {
        function presentation_count($mysqli, $table) {
            $res = $mysqli->query("SELECT COUNT(*) AS cnt FROM `$table`");
            if (!$res) return 0;
            return (int)$res->fetch_assoc()['cnt'];
        }

        $houseCount    = presentation_count($mysqli, 'houses');
        $businessCount = presentation_count($mysqli, 'businesses');
        $hotelCount    = presentation_count($mysqli, 'hotels');
        $farmCount     = presentation_count($mysqli, 'farms');
        $forestCount   = presentation_count($mysqli, 'forests');
    }
} catch (Exception $e) {
    // DB unavailable
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Presentation</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
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
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.65;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }

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
  .topbar .brand .dot-live {
    width: 8px; height: 8px; border-radius: 50%; background: var(--green);
    box-shadow: 0 0 0 3px rgba(62,207,142,0.18);
  }
  .topbar .status { color: var(--muted); font-size: 0.82rem; }

  header.hero {
    padding: 64px 24px 0;
    text-align: center;
    background: radial-gradient(ellipse at top, #1b2030 0%, #0f1115 65%);
  }
  header.hero .kicker {
    display: inline-block;
    color: var(--accent-2);
    font-size: 0.78rem;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    border: 1px solid rgba(255,204,0,0.35);
    background: rgba(255,204,0,0.08);
    padding: 5px 14px;
    border-radius: 999px;
    margin-bottom: 18px;
  }
  header.hero h1 {
    margin: 0 0 14px;
    font-size: 3rem;
    letter-spacing: 0.5px;
    color: #fff;
  }
  header.hero h1 span { color: var(--accent); }
  header.hero p.tagline { margin: 0 auto; max-width: 680px; color: var(--muted); font-size: 1.12rem; }

  .stat-strip {
    max-width: 900px; margin: 40px auto 0;
    display: grid; grid-template-columns: repeat(4, 1fr);
    border-top: 1px solid var(--border);
    border-left: 1px solid var(--border);
  }
  .stat-strip .stat {
    border-right: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    padding: 20px 14px;
  }
  .stat-strip .stat .num { font-size: 1.6rem; font-weight: 700; color: var(--accent); }
  .stat-strip .stat .lbl { font-size: 0.78rem; color: var(--muted); margin-top: 2px; }
  .stat-strip .stat:first-child { grid-column: 1 / -1; }
  @media (max-width: 700px) { .stat-strip { grid-template-columns: repeat(2, 1fr); } .stat-strip .stat:first-child { grid-column: 1 / -1; } }

  .explore {
    max-width: 1400px; margin: 0 auto;
    padding: 54px 24px 40px;
    border-bottom: 1px solid var(--border);
  }
  .explore h2 { text-align: center; font-size: 1.3rem; margin: 0 0 4px; color: #fff; }
  .explore p.lead { text-align: center; color: var(--muted); margin: 0 0 30px; font-size: 0.95rem; }
  .explore-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    width: 100%;
  }
  .explore-grid .explore-card:first-child { grid-column: 1 / -1; }
  @media (max-width: 900px) { .explore-grid { grid-template-columns: repeat(2, 1fr); } .explore-grid .explore-card:first-child { grid-column: 1 / -1; } }
  @media (max-width: 480px) { .explore-grid { grid-template-columns: 1fr; } }
  .explore-card {
    display: flex; flex-direction: column; gap: 4px;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 16px 16px 14px;
    color: var(--text);
    text-decoration: none;
    transition: border-color 0.15s ease, transform 0.15s ease, background 0.15s ease;
  }
  .explore-grid .explore-card:first-child {
    text-align: center;
    align-items: center;
    justify-content: center;
  }
  .explore-card:hover {
    border-color: var(--accent);
    background: var(--panel-2);
    transform: translateY(-2px);
    text-decoration: none;
  }
  .explore-card .ico { font-size: 1.5rem; }
  .explore-card .ttl { font-weight: 600; font-size: 0.92rem; }
  .explore-card .desc { color: var(--muted); font-size: 0.78rem; line-height: 1.4; }

  main { max-width: 1400px; margin: 0 auto; padding: 30px 24px 80px; }

  section { margin-bottom: 60px; scroll-margin-top: 70px; }
  section h2 {
    font-size: 1.7rem;
    margin: 0 0 6px;
    color: #fff;
  }
  section .subtitle { color: var(--muted); margin: 0 0 20px; font-size: 1rem; }

  .card {
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px 22px;
    margin: 14px 0;
  }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
  @media (max-width: 900px) { .grid-2, .grid-3, .grid-4 { grid-template-columns: 1fr; } }

  table { width: 100%; border-collapse: collapse; margin: 12px 0 8px; font-size: 0.94rem; }
  th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); }
  th { background: var(--panel-2); color: var(--muted); font-size: 0.74rem; text-transform: uppercase; letter-spacing: 0.5px; }

  code, .cmd {
    background: #11141b;
    border: 1px solid var(--border);
    border-radius: 5px;
    padding: 2px 8px;
    font-family: "Cascadia Code", Consolas, monospace;
    font-size: 0.9em;
    color: var(--green);
    white-space: nowrap;
  }

  .feature-icon { font-size: 1.8rem; margin-bottom: 8px; }
  .faction-row {
    display: flex; align-items: center; gap: 12px;
    padding: 12px 16px; border-radius: 10px;
    background: var(--panel-2); margin-bottom: 8px;
  }
  .dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }

  .note {
    border-left: 3px solid var(--accent-2);
    background: rgba(255,204,0,0.06);
    padding: 12px 18px;
    border-radius: 0 10px 10px 0;
    margin: 16px 0;
    font-size: 0.94rem;
  }
  .note.warn { border-left-color: var(--red); background: rgba(255,93,93,0.07); }

  footer { text-align: center; padding: 40px 20px 60px; color: var(--muted); font-size: 0.9rem; border-top: 1px solid var(--border); }

  /* Floating side navigation (right edge), same look/feel as the UCP dashboard's .section-nav */
  .side-nav {
    position: fixed;
    top: 50%;
    right: 18px;
    transform: translateY(-50%);
    display: flex;
    flex-direction: column;
    gap: 6px;
    max-height: 82vh;
    overflow-y: auto;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 10px 7px;
    z-index: 150;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
    scrollbar-width: thin;
  }
  .side-nav::-webkit-scrollbar { width: 5px; }
  .side-nav::-webkit-scrollbar-thumb { background: var(--border); border-radius: 999px; }
  .side-nav a {
    position: relative;
    display: flex; align-items: center; justify-content: center;
    width: 36px; height: 36px;
    flex: 0 0 auto;
    border-radius: 9px;
    font-size: 1.1rem;
    text-decoration: none;
    transition: background 0.15s, transform 0.15s;
  }
  .side-nav a:hover { background: var(--panel-2); transform: scale(1.08); text-decoration: none; }
  .side-nav a:hover::after {
    content: attr(title);
    position: absolute;
    right: 46px;
    background: var(--panel-2);
    border: 1px solid var(--border);
    color: var(--text);
    font-size: 0.78rem;
    padding: 4px 8px;
    border-radius: 6px;
    white-space: nowrap;
    pointer-events: none;
  }
  @media (max-width: 1100px) { .side-nav { display: none; } }
</style>
</head>
<body>

<?php include __DIR__ . '/includes/header-public.php'; ?>

<header class="hero">
  <span class="kicker">Now recruiting citizens</span>
  <h1>Welcome to <span>Nostalgia: Los Santos | RPG</span></h1>
  <p class="tagline">An RPG server built from scratch, with a real economy, active factions, systems modeled after
  real life down to the smallest detail, and a life system that never lets you sit idle.</p>

  <div class="stat-strip">
    <div class="stat"><div class="num">∞</div><div class="lbl">Ways to make money</div></div>
    <div class="stat"><div class="num">8</div><div class="lbl">Factions</div></div>
    <div class="stat"><div class="num">12</div><div class="lbl">Jobs</div></div>
    <div class="stat"><div class="num">1</div><div class="lbl">Elected President</div></div>
    <div class="stat"><div class="num"><?= $forestCount ?></div><div class="lbl">Forests</div></div>
    <div class="stat"><div class="num"><?= $houseCount ?></div><div class="lbl">Houses</div></div>
    <div class="stat"><div class="num"><?= $businessCount ?></div><div class="lbl">Businesses</div></div>
    <div class="stat"><div class="num"><?= $hotelCount ?></div><div class="lbl">Hotels</div></div>
    <div class="stat"><div class="num"><?= $farmCount ?></div><div class="lbl">Farms</div></div>
  </div>
</header>

<nav class="side-nav" aria-label="Jump to section">
  <a href="#start" title="Getting started">🚪</a>
  <a href="#factions" title="Factions">🪪</a>
  <a href="#news" title="Press &amp; News">📰</a>
  <a href="#economy" title="Economy">💰</a>
  <a href="#president" title="President">🗳️</a>
  <a href="#jobs" title="Jobs">💼</a>
  <a href="#farming" title="Farming">🚜</a>
  <a href="#forests" title="Forests">🌲</a>
  <a href="#wars" title="Territory wars">⚔️</a>
  <a href="#drugs" title="Drugs &amp; Vault">🌿</a>
  <a href="#houses-biz" title="Houses &amp; Businesses">🏠</a>
  <a href="#hotels" title="Hotels">🏨</a>
  <a href="#vehicles" title="Vehicles">🚗</a>
  <a href="#exams" title="Driving &amp; flight exams">🪪</a>
  <a href="#weapons" title="Weapons &amp; Ammu-Nation">🔫</a>
  <a href="#shops" title="Shops &amp; Markets">🛍️</a>
  <a href="#health" title="Health &amp; Tiredness">❤️</a>
  <a href="#food" title="Food">🍕</a>
  <a href="#skins" title="Clothes &amp; Skins">👕</a>
  <a href="#robbery" title="Robbery">💰</a>
  <a href="#hunting" title="Hunting">🏹</a>
  <a href="#casino" title="Casino">🎰</a>
  <a href="#auctions" title="Auctions">🔨</a>
  <a href="#golf" title="Golf">⛳</a>
  <a href="#basketball" title="Basketball">🏀</a>
  <a href="#events" title="Events">🎮</a>
  <a href="#caravans" title="Caravans">🚐</a>
  <a href="#trains" title="Trains">🚂</a>
  <a href="#camping" title="Camping">🏕️</a>
  <a href="#party" title="Parties">🎉</a>
  <a href="#gps" title="GPS &amp; Radar">🗺️</a>
  <a href="#phone" title="Phones">📱</a>
  <a href="#police" title="Law &amp; Order">🚓</a>
</nav>

<section class="explore">
  <h2>Explore the server</h2>
  <p class="lead">Jump straight to any system — click a card to scroll down to it</p>
  <div class="explore-grid">
    <a class="explore-card" href="#start"><span class="ico">🚪</span><span class="ttl">Getting started</span><span class="desc">Account, stats, help</span></a>
    <a class="explore-card" href="#factions"><span class="ico">🪪</span><span class="ttl">Factions</span><span class="desc">8 factions, ranks, duty</span></a>
    <a class="explore-card" href="#jobs"><span class="ico">💼</span><span class="ttl">Jobs</span><span class="desc">12 jobs, from delivery to lumberjack</span></a>
    <a class="explore-card" href="#houses-biz"><span class="ico">🏠</span><span class="ttl">Houses &amp; Businesses</span><span class="desc">Fridge, animals, income</span></a>
    <a class="explore-card" href="#vehicles"><span class="ico">🚗</span><span class="ttl">Vehicles</span><span class="desc">Fuel, dirt, documents</span></a>
    <a class="explore-card" href="#hotels"><span class="ico">🏨</span><span class="ttl">Hotels</span><span class="desc">Passive income, rooms</span></a>
    <a class="explore-card" href="#farming"><span class="ico">🚜</span><span class="ttl">Farming</span><span class="desc">Plow to harvest, 5 stages</span></a>
    <a class="explore-card" href="#forests"><span class="ico">🌲</span><span class="ttl">Forests</span><span class="desc">Timber resources, supply chain</span></a>
    <a class="explore-card" href="#wars"><span class="ico">⚔️</span><span class="ttl">Territory wars</span><span class="desc">Mafia turf battles</span></a>
    <a class="explore-card" href="#drugs"><span class="ico">🌿</span><span class="ttl">Drugs &amp; Vault</span><span class="desc">Craft, smuggle, defend</span></a>
    <a class="explore-card" href="#news"><span class="ico">📰</span><span class="ttl">Press &amp; News</span><span class="desc">Newspapers, live Q&amp;A</span></a>
    <a class="explore-card" href="#economy"><span class="ico">💰</span><span class="ttl">Economy</span><span class="desc">PayDay, bank, taxes</span></a>
    <a class="explore-card" href="#president"><span class="ico">🗳️</span><span class="ttl">President</span><span class="desc">Weekly vote, tax control</span></a>
    <a class="explore-card" href="#exams"><span class="ico">🪪</span><span class="ttl">Driving &amp; flight exams</span><span class="desc">6 licenses to earn</span></a>
    <a class="explore-card" href="#weapons"><span class="ico">🔫</span><span class="ttl">Weapons &amp; Ammu-Nation</span><span class="desc">Legal buys, W license</span></a>
    <a class="explore-card" href="#shops"><span class="ico">🛍️</span><span class="ttl">Shops &amp; Markets</span><span class="desc">Stores, fast-food, gear</span></a>
    <a class="explore-card" href="#health"><span class="ico">❤️</span><span class="ttl">Health &amp; Tiredness</span><span class="desc">Sleep, illness, SMURD</span></a>
    <a class="explore-card" href="#food"><span class="ico">🍕</span><span class="ttl">Food</span><span class="desc">Pizza, burger, donuts</span></a>
    <a class="explore-card" href="#skins"><span class="ico">👕</span><span class="ttl">Clothes &amp; Skins</span><span class="desc">Outfits, uniforms</span></a>
    <a class="explore-card" href="#robbery"><span class="ico">💰</span><span class="ttl">Robbery</span><span class="desc">Crew up, hit a store</span></a>
    <a class="explore-card" href="#hunting"><span class="ico">🏹</span><span class="ttl">Hunting</span><span class="desc">Snipe deer, sell meat</span></a>
    <a class="explore-card" href="#casino"><span class="ico">🎰</span><span class="ttl">Casino</span><span class="desc">Roulette, slots, dice</span></a>
    <a class="explore-card" href="#auctions"><span class="ico">🔨</span><span class="ttl">Auctions</span><span class="desc">Bid on properties</span></a>
    <a class="explore-card" href="#golf"><span class="ico">⛳</span><span class="ttl">Golf</span><span class="desc">5-hole elimination</span></a>
    <a class="explore-card" href="#basketball"><span class="ico">🏀</span><span class="ttl">Basketball</span><span class="desc">Self-started mini-game</span></a>
    <a class="explore-card" href="#events"><span class="ico">🎮</span><span class="ttl">Events</span><span class="desc">Races, CS, Hunt The Mayor</span></a>
    <a class="explore-card" href="#caravans"><span class="ico">🚐</span><span class="ttl">Caravans</span><span class="desc">Tow a home on wheels</span></a>
    <a class="explore-card" href="#trains"><span class="ico">🚂</span><span class="ttl">Trains</span><span class="desc">Fast travel, 3 stations</span></a>
    <a class="explore-card" href="#camping"><span class="ico">🏕️</span><span class="ttl">Camping</span><span class="desc">Temporary spawn point</span></a>
    <a class="explore-card" href="#party"><span class="ico">🎉</span><span class="ttl">Parties</span><span class="desc">Music, drinks, grill</span></a>
    <a class="explore-card" href="#gps"><span class="ico">🗺️</span><span class="ttl">GPS &amp; Radar</span><span class="desc">Navigation, speed traps</span></a>
    <a class="explore-card" href="#phone"><span class="ico">📱</span><span class="ttl">Phones</span><span class="desc">Calls &amp; SMS</span></a>
    <a class="explore-card" href="#police"><span class="ico">🚓</span><span class="ttl">Law &amp; Order</span><span class="desc">Wanted, fines, impound</span></a>
  </div>
</section>

<main>

<section id="start">
  <h2>🚪 Getting started</h2>
  <p class="subtitle">Everything you need to know before stepping into the world</p>
  <div class="grid-3">
    <div class="card">
      <div class="feature-icon">📝</div>
      <h4>Create your account</h4>
      <p style="color:var(--muted); margin:0">When you connect, a dialog pops up automatically asking you to set a password —
      Register the first time, Login afterward. No commands needed.</p>
    </div>
    <div class="card">
      <div class="feature-icon">📊</div>
      <h4>Track your progress</h4>
      <p style="color:var(--muted); margin:0">A stats command shows your level, RP, money, faction and house at any time.
      A separate command covers your vehicles' documents, fuel and dirt level.</p>
    </div>
    <div class="card">
      <div class="feature-icon">🆘</div>
      <h4>Need help?</h4>
      <p style="color:var(--muted); margin:0">An in-game help command lists everything available to players, and a
      "how to" guide walks you through any system in more depth, whenever you need it.</p>
    </div>
  </div>
</section>

<section id="factions">
  <h2>🪪 Factions</h2>
  <p class="subtitle">Pick your side — public order or street life</p>

  <?php for ($fid = 1; $fid <= 8; $fid++): ?>
    <div class="faction-row">
      <span class="dot" style="background:<?= ucp_faction_color($fid) ?>"></span>
      <strong><?= htmlspecialchars(ucp_faction_name($fid)) ?></strong>
      <span style="color:var(--muted); margin-left:auto"><?= $fid <= 3 ? 'Public faction' : 'Civilian' ?></span>
    </div>
  <?php endfor; ?>

  <div class="card" style="margin-top:20px">
    <h4 style="margin-top:0">How it works</h4>
    <p>Every faction has a headquarters (HQ), its own bank, and a rank system (1 to 5, where 5 is the leader).
    Senior members can invite new players, manage the faction bank, promote or remove others, and refuel/respawn
    the faction's fleet. Police, RAR and SMURD also run a <strong>duty</strong> system — clocking in near the HQ
    gives you access to your faction's special powers while you're on shift. SMURD crews can also respond to
    <strong>random house fires</strong> around the map with the faction's Firetruck.</p>
  </div>
</section>

<section id="news">
  <h2>📰 Press &amp; Newspapers</h2>
  <p class="subtitle">The News Reporters faction keeps the city informed</p>
  <div class="grid-3">
    <div class="card">
      <div class="feature-icon">📢</div>
      <h4>Live news</h4>
      <p style="color:var(--muted); margin:0">Reporters broadcast breaking news to every player on the server.</p>
    </div>
    <div class="card">
      <div class="feature-icon">🗞️</div>
      <h4>Newspapers</h4>
      <p style="color:var(--muted); margin:0">Higher-ranked reporters can publish a newspaper with up to 5 stories and put it up for sale.
      Anyone can buy and read it. Newspapers reset every day at midnight.</p>
    </div>
    <div class="card">
      <div class="feature-icon">🎤</div>
      <h4>Live interviews (Q&amp;A)</h4>
      <p style="color:var(--muted); margin:0">Senior reporters can invite a player to a live interview. The audience submits questions,
      the reporter picks which ones to ask, and the guest answers live for everyone to see.</p>
    </div>
  </div>
</section>

<section id="economy">
  <h2>💰 Economy</h2>
  <p class="subtitle">Money doesn't fall from the sky — but you don't need to grind for it either</p>

  <div class="card">
    <h4 style="margin-top:0">💵 PayDay — your hourly wage</h4>
    <p>Once every hour, every connected player automatically receives a wage based on their character's level
    (the more experienced you are, the more you earn). Income tax and health contributions — both set by the
    elected President — are deducted, and the cash sitting in your bank account earns interest even while you do nothing.</p>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🏘️ Property tax</h4>
    <p>If you own vehicles, a house, a business, a farm or a hotel, a small property tax proportional to each
    asset's value is also deducted at every PayDay. It's itemized on your PayDay receipt, so you always know
    exactly what you paid.</p>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🏦 Bank account &amp; ATM</h4>
      <p style="color:var(--muted); margin:0">Money can be held as cash or in the bank. The bank pays interest at every
      PayDay. Any ATM in the city lets you move money between cash and account, with sensible per-transaction
      limits and a small fee.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📈 Level &amp; RP</h4>
      <p style="color:var(--muted); margin:0">Every PayDay also grows your RP (Role-Play Points) — a marker of your
      experience on the server.</p>
    </div>
  </div>
</section>

<section id="president">
  <h2>🗳️ President</h2>
  <p class="subtitle">Every week, players vote a President who controls the city's taxes</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🗳️ The vote</h4>
      <p>Every <strong>Sunday, between 08:00 and 19:30</strong>, players can cast a vote for a candidate. The
      candidate must be online, and each player gets exactly <strong>one vote</strong> per week.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏛️ The result</h4>
      <p>Sunday at <strong>20:00</strong> the winner is announced — the player with the most votes becomes the
      new President. A sitting President can't win two terms in a row, so the role always rotates.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💼 Presidential power</h4>
      <p>The President can set the <strong>income tax</strong> and <strong>health contribution</strong> rates
      applied to everyone's PayDay, straight from in-game. Any change is announced to the whole server.</p>
    </div>
  </div>

  <div class="note">
    Anyone can check who the current President is and which tax/contribution rates are active, at any time.
  </div>
</section>

<section id="jobs">
  <h2>💼 Jobs</h2>
  <p class="subtitle">Earn your living honestly — or close to it. 12 unique jobs to choose from</p>

  <div class="card">
    <h4 style="margin-top:0">📋 Getting a job</h4>
    <p>Head to the <strong>Job Center</strong> at City Hall to get hired, or browse the full job list there.
    You can only hold one job at a time, and you can quit anytime. Once hired, you start and stop working
    whenever you like.</p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🛵 Glovo</h4>
      <p>Delivery runs: pick up an order from a restaurant with the work vehicle, then drop it off at a house.
      Pay scales with distance driven, and a small cut of every delivery feeds the business hosting the job.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚧 Cement Truck Driver</h4>
      <p>Load cement at the factory and haul it to one of the city's construction sites.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 Gun Delivery</h4>
      <p>Pick up weapons from a fixed loading point and deliver them to a mafia's HQ or fixed drop-offs.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 Car Transporter</h4>
      <p>Move vehicles from loading points to businesses around the city.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚕 Uber</h4>
      <p>Drive your own personal car as a taxi: set your fare and go on duty, then accept ride requests from
      players who need a lift, charged over time until they get out.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚑 Emergency Logistics Driver</h4>
      <p>Head out from the depot with a Bobcat or Burrito, pick up medical supplies at the loading point, and
      deliver them to shops.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚌 Bus Driver</h4>
      <p>Take a depot bus and drive one of three fixed routes. You earn at every checkpoint, a bonus at the end
      of the route, and extra for every passenger who boards.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 Electrician</h4>
      <p>Drive the Electrician's job vehicle around town, repairing things for a fee. A locator points you to
      nearby houses that need work — fix a fridge or bed before it breaks (paid from the house's own bank), or
      clear an active apartment issue (flood, sewage, wiring). You can also offer nearby players a paid repair
      for their broken phone or watch, which they confirm before you get paid.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">✈️ Crop Duster Pilot</h4>
      <p>Take off in one of the two job planes, fly to a marked point to load fertilizer, then reach a randomly
      chosen farm within 2 minutes while flying between 100 and 200 altitude, and spray it. Good pay per run,
      no license required for the job plane.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎣 Fisherman</h4>
      <p>Cast your line at dedicated fishing spots around the map. Catch fish (300-2500g) and deliver them to a randomly chosen
      fast-food restaurant. Pay based on weight delivered — a relaxing way to make steady income.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💧 Water Hauler</h4>
      <p>Drive a DFT-30 truck and haul water to designated dump points. Spray plants and agricultural areas to earn money.
      Distance-based pay with $1,000 per successful delivery. Useful for farms and landscaping work.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🌲 Lumberjack</h4>
      <p>Grab a chainsaw and harvest timber from forests across the map. Use <code>/chopwood</code> at any forest to chop trees (one harvest per payday),
      then load the wood into a truck and deliver it to the timber business. Earn money based on your haul. The more trees available in forests, the better the yield.</p>
    </div>
  </div>
</section>

<section id="farming">
  <h2>🚜 Farming</h2>
  <p class="subtitle">Work the land, one stage a day, and harvest at the end</p>

  <div class="card">
    <h4 style="margin-top:0">Owning & Equipment</h4>
    <p>You can own <strong>one farm</strong> at a time. Once you buy a plot, you must purchase the machines needed to work it:
    <strong>Tractor</strong> ($10,000), <strong>Bulldozer</strong> ($15,000), and <strong>Combine</strong> ($20,000). These machines are expensive and
    <strong>wear out over time</strong> — treat them carefully. You can resell any machine from inside it for 75% back,
    but a broken machine is only worth a fraction of its original price.</p>

    <h4>The 5-Stage Cycle</h4>
    <p>Farming works through a <strong>5-stage daily cycle</strong>: each real day you must complete ONE stage. If you fail a stage,
    you lose that day's progress and can't retry until the next day.</p>
    <ul>
      <li><strong>Plow</strong> (1 min) — Drive a Tractor for 1 minute without leaving it</li>
      <li><strong>Level</strong> (2 min) — Drive a Bulldozer for 2 minutes without leaving it</li>
      <li><strong>Seed</strong> (3 min) — Drive a Tractor for 3 minutes without leaving it</li>
      <li><strong>Fertilize</strong> (1 min) — Drive a Tractor for 1 minute without leaving it</li>
      <li><strong>Harvest</strong> (4 min) — Drive a Combine for 4 minutes → earns <strong>$15,000</strong>, cycle restarts</li>
    </ul>

    <h4>Keeping Your Machines</h4>
    <p><strong>Machines degrade:</strong> every time you leave a machine or fail to complete its stage, it takes damage. Damage reduces resale value and
    eventually makes the machine unusable — you'll have to buy a replacement. Park carefully on flat ground and always complete your work
    in one sitting or you risk losing your investment.</p>

    <p>You can check your farm's status anytime with <code>/farmstats</code> to see which stage you're on and what machines you own.</p>
  </div>
</section>

<section id="forests">
  <h2>🌲 Forests</h2>
  <p class="subtitle">Manage timber resources and supply the economy</p>

  <div class="card">
    <p>Forests are ownable properties spread across Los Santos. Each forest has a <strong>maximum tree capacity</strong> and a <strong>current tree count</strong>.
    Trees grow naturally every payday (<strong>+10 base</strong>, plus any saplings planted since the last payday). When a forest reaches maximum capacity, growth stops until trees are harvested.</p>

    <h4 style="margin-top:16px">Ownership &amp; trading</h4>
    <p>Like houses and businesses, you can buy a forest for sale, list it for sale to other players, trade it directly, or sell it back to the state for 60% of its value.
    You can own <strong>one forest</strong> at a time.</p>

    <h4 style="margin-top:16px">The supply chain</h4>
    <p>Lumberjacks harvest trees from forests using <code>/chopwood</code> (once per payday), regardless of ownership. The more trees your forest has stored, the more valuable
    it is to active lumberjacks, making well-managed forests a genuine investment. Forest owners benefit indirectly from high activity and demand for timber.</p>

    <h4 style="margin-top:16px">🌱 Planting saplings</h4>
    <p>Forest owners can speed up regrowth by stocking up on tree saplings. Buy them at a <strong>Tools Shop</strong> ($10/unit) while sitting in a <strong>Benson</strong>, then
    drive the load to your forest and deposit it. A Lumberjack can then plant one at a time: drive a <strong>Forklift</strong> to the forest, get out with a shovel in hand and
    plant it on the spot for a small fee — every planted sapling gets added to the forest's tree count at the next payday.</p>

    <h4 style="margin-top:16px">Growth &amp; management</h4>
    <p>Every payday (hourly), each forest gains trees equal to its growth rate. You can check your forest's status anytime and plan harvests accordingly. Strategic forest ownership
    can generate passive income as lumberjacks depend on healthy, well-stocked forests to maximize their earnings.</p>
  </div>
</section>

<section id="wars">
  <h2>⚔️ Territory wars</h2>
  <p class="subtitle">Mafias only — conquer rival territory by force</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🔫 Preparation</h4>
      <p>Inside your mafia's HQ, you can heal up and get combat gear (high ranks even get a sniper rifle) before
      heading out to attack.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📣 Declaring war</h4>
      <p>Stand inside an enemy mafia's territory (marked on the map) and declare war. Both factions need at
      least 2 members online. After a short prep phase, the actual fight lasts <strong>15 minutes</strong>.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏆 Conquest</h4>
      <p>Whichever faction gets the most kills in the zone by the end of the 15 minutes wins. A tie goes to
      <strong>sudden death</strong> (first to 3 kills wins). If the attackers win, the territory changes hands.</p>
    </div>
  </div>

  <div class="note">
    The score can be checked live at any time during the fight. Leaders can surrender an active war, but only
    after the first 5 minutes.
  </div>
</section>

<section id="drugs">
  <h2>🌿 Drugs &amp; Vault (mafias only)</h2>
  <p class="subtitle">The mafias' underground economy — it fuels the territory fight</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🔒 The mafia vault</h4>
      <p>Every mafia keeps a <strong>vault</strong> where weed and drugs accumulate. Senior members can check the
      stock at any time.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 Transport &amp; production</h4>
      <p>Certain ranks haul raw weed to the vault, others turn it into drugs at the crafting station.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💉 In battle</h4>
      <p>While your faction is fighting a war, members can pull drugs from the vault and use them on the
      contested territory for a quick burst of health.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚤 Sea smuggling</h4>
      <p>Using a designated faction boat, run supplies through a loading point (which alerts the Police and
      raises everyone aboard to wanted level 6), then two randomly chosen pickup points, before switching to the
      faction's Sultan and delivering the cargo to a random hotel. A successful run pays the vault in cash and
      weed, plus a cash bonus for every surviving crew member, and drops wanted back to 5. Police get a bounty
      for catching smugglers. Only one successful run per faction per day.</p>
    </div>
  </div>
</section>

<section id="houses-biz">
  <h2>🏠 Houses &amp; Businesses</h2>
  <p class="subtitle">Invest in your in-game life</p>
  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🏠 Houses</h4>
      <p>Buy any house that's for sale — whether it's unowned (state-owned) or listed by another player. You can
      only own <strong>one</strong> house at a time, or rent one if you don't own anything. A house with an
      interior can be entered and exited on foot at its pickup.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🛏️ Tiredness &amp; sleep</h4>
      <p>Staying awake tires your character out over time; past a threshold it starts costing you extra health.
      A bed at your own house (a one-time $7,500 upgrade) lets you sleep for free in 30 seconds, resetting
      tiredness to zero. Away from home, any <strong>hotel</strong> (see below) will rent you a room for a small
      fee instead.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🐾 House animals</h4>
      <p>A house with a yard can get an animal ($5,000): Turtle or Deer for a Villa, Cow for a Countryside House.
      It appears and lives in your yard, can be renamed, and a Cow has a chance to fill your fridge with fresh
      milk at every PayDay you're online. Animals <strong>age with each PayDay</strong> and eventually die of old
      age — a deceased animal stops producing anything and blocks renting the house out until you give it a
      proper burial with a Romero hearse, driving it from your house to the chapel.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🧊 Fridge &amp; 🌳 Tree</h4>
      <p>A fridge ($10,000, breaks after 32 days) can be stocked with milk/bananas/water/juice/beer between
      15:00 and 20:00, each restoring health when eaten. City and Countryside houses can also grow a tree
      ($20,000) that yields more bananas the longer it grows, up to a cap, then resets. Fridges, beds, trees and
      house animals are all ordered from <strong>Home Furnitures</strong>: pick a Benson from their lot, place your
      order there, then drive it home — the purchase is finalized the moment you pull up to your own house.</p>
      <table style="margin-top:10px">
        <tr><th>Item</th><th>Capacity</th><th>Price/unit</th><th>Health</th></tr>
        <tr><td>Milk</td><td>20 L</td><td>$100</td><td>+20</td></tr>
        <tr><td>Bananas</td><td>30 pcs</td><td>$50</td><td>+10</td></tr>
        <tr><td>Water</td><td>25 L</td><td>$150</td><td>+25</td></tr>
        <tr><td>Juice</td><td>20 L</td><td>$200</td><td>+15</td></tr>
        <tr><td>Beer</td><td>50 L</td><td>$250</td><td>+10</td></tr>
      </table>
      <p style="margin:8px 0 0; color:var(--red)">A broken fridge or bed loses all value and must be replaced with
      the same upgrade command.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 Apartment problems &amp; preventive repairs</h4>
      <p>Every day at <strong>22:00</strong>, a random owned apartment develops a problem (flood, clogged pipes,
      a burnt circuit) that blocks spawning there until fixed. Only the <strong>Electrician</strong> job can fix
      it, or preventively service a fridge/bed before it breaks — both paid from the house's own bank.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚰 Bottles &amp; 🗑️ Trash</h4>
      <p>Drinking from the fridge leaves empty bottles, eating leaves trash (both capped at 100 per house). Special
      vans pick them up at your house and pay your house bank per unit at the recycling/dump point. Below level
      5, anyone can also make some quick cash on foot by <strong>buying a bag</strong> at the shop and searching
      public street bins for loose bottles, selling them at the same drop-off point — the bag and its contents
      are lost on death, respawn or disconnect.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏢 Businesses</h4>
      <p>You can own <strong>one</strong> business at a time. It earns passive income into its own bank whenever
      players use the activity tied to it — fast food orders, ATM fees, phone/SIM sales, calls and SMS, fridge
      shopping, appliance upgrades, Glovo deliveries, exam fees — you don't need to be online for it to earn.</p>
      <p style="margin:8px 0 0"><strong>Tax audits (ANAF):</strong> every day at <strong>12:00</strong>, a random
      business gets flagged and earns nothing until cleared. Drive a <strong>model 428</strong> vehicle to your
      business to pick up the paperwork, then deliver it to the tax office — the business unlocks at the next
      PayDay.</p>
    </div>
  </div>

  <h3>🏷️ Selling to other players</h3>
  <p>Houses, businesses, vehicles, farms and hotels can be <strong>listed for sale</strong> at your own price.
  Another player buys it with the matching purchase command, and <strong>the money lands straight in your
  bank</strong> — even while you're offline. Houses and businesses also support a direct offer to a specific
  player, which they confirm.</p>
  <p>Setting the price to <strong>0</strong> cancels a listing. While listed, you can keep using the property
  normally until someone buys it. Any of them can also be sold <strong>instantly to the state</strong> for
  <strong>60%</strong> of their value, paid in cash on the spot.</p>

  <div class="note warn">
    A business, farm or hotel's bank balance <strong>transfers to the new owner</strong> along with it — withdraw
    your money before selling.
  </div>
</section>

<section id="hotels">
  <h2>🏨 Hotels</h2>
  <p class="subtitle">A passive-income property anyone can rent a room at, no ownership needed</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🛎️ Renting a room</h4>
      <p>Any player can pay a small fee at a hotel's pickup to sleep there for under a minute, dropping their
      tiredness partway down — handy when you're away from home or don't own a bed. It doesn't have to be your
      own hotel, and no bed is required.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💼 Owning one</h4>
      <p>You can own <strong>one</strong> hotel at a time, bought like a house or business, and it can be listed
      for sale, sold directly to the state, or auctioned. Every guest's room fee splits between running costs and
      the hotel's own bank — passive income whether you're online or not, withdrawable near any bank or ATM.</p>
    </div>
  </div>

  <div class="note">
    Players can also rent a room at a hotel long-term instead of owning a house, paying rent out of their pocket
    into the hotel's bank at every PayDay, until they end the arrangement.
  </div>
</section>

<section id="vehicles">
  <h2>🚗 Personal vehicles</h2>
  <p class="subtitle">Your car, your rules — you can own up to 3 at once</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🔑 Buying</h4>
      <p>Buy the vehicle you're sitting in if it's for sale — you need a matching driving license to drive it.
      It comes with insurance, a plate, and can be fitted with a medical kit and extinguisher bought at the shop.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⛽ Fuel &amp; condition</h4>
      <p>Vehicles burn fuel while the engine runs — refuel at a gas station, or carry a gas can (filled at a
      station) for emergencies far from one. Cars also get dirtier every time they respawn: past a threshold
      you're warned to wash it, and above a higher one the engine refuses to start until it's cleaned at a Car
      Wash.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 Controls</h4>
      <p>Toggle the engine, lock/unlock the doors, and switch lights, alarm, doors, hood or boot on the vehicle
      you're driving — all visible live on your dashboard. Save your preferred parking spot so the car respawns
      exactly there.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎨 Personalization</h4>
      <p>Repaint your primary and secondary colors, and get a custom license plate at the RAR HQ.</p>
    </div>
  </div>

  <div class="card" style="margin-top:8px">
    <h4 style="margin-top:0">📋 Documents (all at R.A.R.)</h4>
    <p>Insurance, a technical inspection (ITP — engine off, hood open, boot closed, lights on), a plate, plus a
    medical kit and extinguisher fitted from items bought at the shop. Each stays valid for the whole day it's
    due to expire on. Police and RAR can inspect and confiscate any of them on the road.</p>
  </div>

  <div class="grid-2" style="margin-top:8px">
    <div class="card">
      <h4 style="margin-top:0">🚲 🚙 Rentals</h4>
      <p>Bikes and cars are available to rent from several spots around the city, no license required — ideal
      for when you don't (yet) own your own vehicle.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 Impounding &amp; towing</h4>
      <p>RAR can tow away a car with expired documents; Police and RAR can also confiscate a vehicle outright.
      Either way, the car won't start until you pay a release fee to get it back at the vehicle itself.</p>
    </div>
  </div>
</section>

<section id="exams">
  <h2>🪪 Driving &amp; flight exams</h2>
  <p class="subtitle">Six categories, all testing real skill under a time limit</p>

  <table>
    <tr><th>Category</th><th>Vehicle</th><th>License lasts (clean / damaged finish)</th></tr>
    <tr><td>A</td><td>Motorcycle</td><td>7 / 2 days</td></tr>
    <tr><td>B</td><td>Car</td><td>10 / 3 days</td></tr>
    <tr><td>C</td><td>Truck + trailer</td><td>12 / 3 days</td></tr>
    <tr><td>D</td><td>Bus</td><td>13 / 3 days</td></tr>
    <tr><td>P</td><td>Plane ✈️</td><td>15 / 2 days</td></tr>
    <tr><td>H</td><td>Helicopter 🚁</td><td>16 / 2 days</td></tr>
  </table>

  <div class="note">
    Every leg of the route has a time limit — fall too far behind at a checkpoint and you fail. Finishing with
    the exam vehicle in good health earns the full validity shown above; a damaged finish gives the shorter one.
    Rentals and exam vehicles never need a license.
  </div>

  <p>Your license status across all six categories can be checked at any time.</p>
</section>

<section id="weapons">
  <h2>🔫 Weapons &amp; Ammu-Nation</h2>
  <p class="subtitle">Buying firepower legally, earning the right to carry it, and where the illegal stuff comes from</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏪 Ammu-Nation</h4>
      <p>Gun stores are marked on the map — walk up and press ENTER to step inside, then buy straight from the
      counter. No license or faction is required to purchase: Colt 45, Deagle, Shotgun, MP5, AK-47, M4 and Uzi
      are all available for cash, each with a fixed amount of ammo and its own price.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎯 Weapon License (W)</h4>
      <p>Take the shooting range exam near the category D exam zone for a fee. You're handed a Deagle, an MP5
      and an AK-47 with limited ammo and <strong>90 seconds</strong> to hit <strong>6 targets</strong>. Hit all 6
      and the license lasts <strong>8 days</strong>; hit 5 out of 6 and it's valid for <strong>3 days</strong> —
      miss more than that and you fail. Check it alongside your driving and flight licenses at any time.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚫 Illegal weapons</h4>
      <p>Grenades, tear gas, molotovs, the sawn-off and combat shotguns, Uzi, Tec-9, sniper rifle, rocket
      launcher, heat-seeker, flamethrower, minigun, satchel charges and bombs are all treated as illegal to
      carry. Ammu-Nation doesn't stock most of them — they come from the black market instead: the mafias' own
      arsenal (handed out to members preparing for a territory war) or the <strong>Gun Delivery</strong> job,
      which moves crates from a fixed pickup to mafia HQs and other drop-offs.</p>
    </div>
  </div>

  <div class="note warn">
    An on-duty Police officer (rank 2+) can search a nearby player for weapons and drugs. Getting caught
    carrying anything from the illegal list gets your <strong>Weapon W license confiscated on the spot</strong>
    — whether or not you were carrying it legally otherwise.
  </div>
</section>

<section id="shops">
  <h2>🛍️ Shops &amp; Markets</h2>
  <p class="subtitle">Multiple types of stores across the city, each with their own inventory and purpose</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏪 24/7 Shop</h4>
      <p>Convenience store chain. Buy medical kits (<strong>$500</strong>), fire extinguishers (<strong>$500</strong>),
      and gas cans (<strong>$500</strong>). Multiple locations across the city — marked on GPS.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📱 Electronics Shop</h4>
      <p>Tech store. Purchase phones and watches here. Phones unlock GPS navigation and messaging;
      watches let you check the time with <code>/time</code>. Each item is customizable by brand.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 Tools Shop</h4>
      <p>Specialized equipment retailer. Buy fishing rods (<strong>$1,500</strong>) for the Fisherman job and tree saplings
      for the forest system. One of the most important supply chains on the server.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 Ammu-Nation</h4>
      <p>Weapons shop for legal firearm purchases. Stock includes Colt 45, Deagle, Shotgun, MP5, AK-47, M4 and Uzi,
      each with pre-loaded ammo. No license required to enter or purchase — that comes later if you need to carry legally.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">👕 Clothing Store</h4>
      <p>Buy outfits and change your wardrobe. Each outfit costs <strong>$10,000</strong> and is permanently added to your closet.
      Switch freely between owned outfits at any clothing store, for free.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍕 Pizza Shop</h4>
      <p>Fast-food franchise. Buy food for <strong>$50</strong> to restore <strong>+20 HP</strong>, capped at 100. Revenue feeds the
      central fast-food business bank (shared with burger, chicken and donuts).</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍔 Burger Shop</h4>
      <p>Another fast-food option. Burgers cost <strong>$55</strong> for <strong>+25 HP</strong>. Revenue flows into the same
      centralized fast-food business bank as all other food spots.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍗 Cluckin' Bell</h4>
      <p>Fried chicken fast-food. Meals are <strong>$60</strong> for <strong>+22 HP</strong>. Every purchase feeds the shared
      fast-food business bank (one owner, four food types).</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍩 Donut Shop</h4>
      <p>Quick and cheap fast-food. Donuts are only <strong>$30</strong> for <strong>+15 HP</strong> — ideal for when you're low on cash.
      Revenue joins the central fast-food business pool.</p>
    </div>
  </div>

  <div class="note">
    All fast-food shops (Pizza, Burger, Cluckin' Bell, Donut Shop) share the same central business bank. Whoever owns
    the fast-food business receives income from all four food spots whenever a player buys from any of them — passive income
    whether you're online or not.
  </div>
</section>

<section id="health">
  <h2>❤️ Health, Tiredness &amp; Illness</h2>
  <p class="subtitle">RPG life isn't always easy</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">⏳ Health drains over time</h4>
      <p style="color:var(--muted); margin:0">Every character's health slowly ticks down over time — one more
      reason to keep an eye on your wellbeing and call SMURD when you need to.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">😴 Tiredness</h4>
      <p style="color:var(--muted); margin:0">Staying awake builds up tiredness over time; past a threshold it
      starts eating into your health too. Sleeping at your own bed resets it for free; a hotel room resets it
      partway for a small fee.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚑 SMURD treatment</h4>
      <p style="color:var(--muted); margin:0">Hop into an ambulance as a passenger and a medic can heal you
      fully for a small fee.</p>
    </div>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🦠 You can get sick</h4>
    <p>From time to time, illness outbreaks can appear in the city. If you catch one, you'll feel the effect
    right away (unsteady movement, faster health drain) and get a clear message about it. Illness fades on its
    own over time, but the fastest cure is heading to the SMURD hospital for treatment.</p>
  </div>
</section>

<section id="food">
  <h2>🍕 Food</h2>
  <p class="subtitle">Hunger won't kill you, but a little extra health never hurts</p>

  <div class="grid-4">
    <div class="card">
      <h4 style="margin-top:0">🍕 Pizza</h4>
      <p style="color:var(--muted); margin:0"><strong>$50</strong> — restores <strong>20 HP</strong>, capped at 100.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍔 Burger</h4>
      <p style="color:var(--muted); margin:0"><strong>$55</strong> — restores <strong>25 HP</strong>, capped at 100.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍗 Cluckin' Bell</h4>
      <p style="color:var(--muted); margin:0"><strong>$60</strong> — restores <strong>22 HP</strong>, capped at 100.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍩 Donut Shop</h4>
      <p style="color:var(--muted); margin:0"><strong>$30</strong> — restores <strong>15 HP</strong>, capped at 100.</p>
    </div>
  </div>

  <table style="margin-top:8px">
    <tr><th>Spot</th><th>Price</th><th>Health restored</th></tr>
    <tr><td>Pizza</td><td>$50</td><td>+20 HP</td></tr>
    <tr><td>Burger</td><td>$55</td><td>+25 HP</td></tr>
    <tr><td>Cluckin' Bell</td><td>$60</td><td>+22 HP</td></tr>
    <tr><td>Donut Shop</td><td>$30</td><td>+15 HP</td></tr>
  </table>

  <div class="note">
    All four only work near the correct location — food spots are marked on the map with their own icons, always
    visible. The label above each spot shows its name, price, and how much health it restores. A cut of every
    order feeds the bank of the business hosting that spot.
  </div>
</section>

<section id="skins">
  <h2>👕 Clothes &amp; Skins</h2>
  <p class="subtitle">Buy your wardrobe and change your look whenever you want</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🛍️ Clothing store</h4>
      <p>Look for a clothing store on the GPS. There you can browse the outfit catalog — each outfit costs
      <strong>$10,000</strong> and gets worn immediately on purchase — or open your wardrobe to switch freely
      between outfits you already own.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">♾️ Yours forever</h4>
      <p>Purchased outfits are <strong>permanently yours</strong>. Switch between them anytime, free of charge,
      at any clothing store. Your skin persists across disconnects.</p>
    </div>
  </div>

  <h3>🪪 Faction uniforms</h3>
  <p>If you're in a faction, your <strong>uniform depends on your rank</strong>:</p>
  <table>
    <tr><th>Rank</th><th>Uniform</th></tr>
    <tr><td>1 - 2</td><td>Basic uniform</td></tr>
    <tr><td>3 - 4</td><td>Intermediate uniform</td></tr>
    <tr><td>5</td><td>Leader uniform</td></tr>
  </table>
  <p>Spawning on duty at your faction spawn puts you in the right uniform automatically. Spawning as a civilian
  wears your personal outfit instead. Inside your faction's HQ you can switch between uniform and civilian
  clothes at will.</p>
</section>

<section id="robbery">
  <h2>💰 Robbery</h2>
  <p class="subtitle">Hit a store with your crew — but shake the police before you cash out</p>

  <div class="note warn">
    You need <strong>10/10 rob points</strong> to pull a robbery. You gain <strong>+1 rob point every PayDay</strong>
    (max 10), and a robbery costs <strong>all 10</strong>. Your points are visible in your stats, under
    <strong>[Crime]</strong>.
  </div>

  <h3>How it works</h3>
  <ol>
    <li>Get your crew into a car — you have to be the <strong>driver</strong>.</li>
    <li>Pull up next to a shop or fast-food spot and start the robbery.</li>
    <li>Everyone in the car at that moment joins in: each loses 10 rob points and gets <strong>wanted level 6</strong>.</li>
    <li>The <strong>police are notified immediately</strong> — with your name and the store hit.</li>
    <li>A checkpoint appears at a random business. Reach it, and a second one appears. You must reach
    <strong>both</strong> to cash out.</li>
  </ol>

  <h3>The payout</h3>
  <p>After the second business, every crew member gets a base cut plus a per-participant bonus and a random
  extra — the more people in the car, the more everyone earns. Once delivered, the wanted level drops from 6 to
  <strong>5</strong>.</p>

  <div class="note warn">
    <strong>Die or disconnect, and you get nothing.</strong> The robbery continues for the rest of the crew, but
    you're out of the payout. Only members still <strong>alive and connected</strong> at delivery time get paid.
  </div>
</section>

<section id="hunting">
  <h2>🏹 Hunting</h2>
  <p class="subtitle">Track deer through the forest and sell the meat for cash</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎯 Getting started</h4>
      <p>Head to the hunting spot marked on the map and you'll be handed a sniper rifle for free.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🦌 The hunt</h4>
      <p>Deer roam the forest and bolt if you get within 30m, so snipe from a distance — a close shot drops them,
      a near-miss sends them fleeing. You can carry several carcasses at once, and a hunted deer respawns
      elsewhere after a few seconds.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💵 Selling</h4>
      <p>Sell everything you're carrying at once at any shop, for <strong>$2,500 per deer</strong>.</p>
    </div>
  </div>
</section>

<section id="casino">
  <h2>🎰 Casino</h2>
  <p class="subtitle">Three tables, one house edge — gamble responsibly</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎡 Roulette</h4>
      <p>Bet on a color, odd/even, or an exact number. Color or parity pays double (zero always loses to those
      bets); an exact number pays 36x.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎰 Slots</h4>
      <p>Three matching Sevens pays 10x, any other three of a kind pays 5x, two Sevens pays double.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎲 Dice</h4>
      <p>You and the house each roll two dice — the higher total wins double, a tie returns your bet.</p>
    </div>
  </div>

  <div class="note">
    Walk into the casino (marked on the map) to play, and leave whenever you like. All three games share the
    same betting range, and every table plays at its own physical spot inside.
  </div>
</section>

<section id="auctions">
  <h2>🔨 Auctions</h2>
  <p class="subtitle">Staff-run bidding wars over houses, businesses, farms and hotels</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📣 Opening</h4>
      <p>An admin puts a property up for auction for the whole server to bid on, announcing what's for sale and
      the starting price.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💰 Bidding</h4>
      <p>Each bid must beat the current highest and is taken from your bank immediately — outbid, and it's
      refunded automatically. Every bid resets the clock to <strong>90 seconds</strong>, with warnings at 60, 30
      and 5 seconds left.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏁 Closing</h4>
      <p>When the clock runs out, the highest bidder wins the property outright — if it already had an owner,
      they lose it with <strong>no compensation</strong>. No bids at all means the auction just ends.</p>
    </div>
  </div>
</section>

<section id="golf">
  <h2>⛳ Golf Tournament</h2>
  <p class="subtitle">An elimination mini-game, opened periodically by staff</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📝 Signing up</h4>
      <p>When an admin opens registration, a server-wide announcement appears. You can sign up while it's open,
      and drop out anytime — though leaving mid-round eliminates you automatically.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏌️ How it plays</h4>
      <p>Each player gets their own ball, labelled with their ID. Hit with a chosen power (0-200) — power
      controls distance, and your look direction sets the aim. Every shot reports the stroke count and the
      remaining distance to the hole.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏆 Tournament structure</h4>
      <p>A tournament has <strong>5 holes</strong>, played in a shuffled order that's randomized every time. It
      ends when a <strong>single winner</strong> remains or all 5 holes have been played.</p>
    </div>
  </div>

  <div class="note">
    Each round's goal is to sink the ball in the fewest strokes. Once everyone finishes the hole, only the
    players with the fewest strokes advance — the rest are eliminated.
  </div>
</section>

<section id="basketball">
  <h2>🏀 Basketball</h2>
  <p class="subtitle">A quick mini-game you can start yourself, no admin required</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📝 Joining a game</h4>
      <p>Head to a basketball court on the map and sign up. Once enough players have joined, a short countdown
      starts and the round begins automatically.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏀 How it plays</h4>
      <p>You move through the court's 8 hoops, one at a time, in a shuffled order. At each hoop you throw with a
      chosen power (0-20); power and aim direction determine how far the ball travels.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎯 Feedback on every shot</h4>
      <p>Right after the ball reaches the hoop, you learn whether it was a GOAL or a MISS, plus a hint on power
      if you clearly missed.</p>
    </div>
  </div>

  <div class="note">
    Each hoop is played once per round — no retries. At the end, the scores of everyone who finished all 8 hoops
    are compared and the winner (most GOALs) is announced.
  </div>
</section>

<section id="events">
  <h2>🎮 Staff-run events</h2>
  <p class="subtitle">Races, team fights and manhunts — started by staff, unlike Golf/Basketball which you start yourself</p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏁 Races (Best Lap)</h4>
      <p>An admin opens a race on a chosen track, with either a fixed vehicle or a random one shared by
      everyone. Sign up while registration is open — at the start, a 5-second countdown runs and timing starts
      exactly at "GO." Beating the best known time for that track and vehicle sets a new server RECORD.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 Counter Strike</h4>
      <p><strong>5 vs 5</strong> bomb matches, several running at once. A match runs 10 rounds, teams swap sides
      after round 5. Terrorists win by planting and detonating the bomb or wiping out CT; CT wins by wiping out T
      (if unplanted) or defusing the bomb — once planted, CT must defuse even if T is wiped out.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏛️ Hunt The Mayor</h4>
      <p>One randomly picked player becomes the "Mayor," spawning well-armed at a secret location; everyone else
      hunts them down over 15 minutes. Landing a hit pays a bounty, the kill pays more, and a surviving Mayor
      collects a prize of their own.</p>
    </div>
  </div>
</section>

<section id="caravans">
  <h2>🚐 Personal caravans</h2>
  <p class="subtitle">A home on wheels, towed behind your own car</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🔑 Getting a caravan</h4>
      <p>Caravans are currently handed out by server staff — there are 3 different types, each with its own
      model. Once you have one, it's permanently tied to your account.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚙 Towing it</h4>
      <p>Attach the caravan right behind your personal car while you're at the wheel, and it follows you
      wherever you go. Detach it to unhitch and park it exactly where you stop; the spot is saved and survives a
      restart.</p>
    </div>
  </div>
</section>

<section id="trains">
  <h2>🚂 Train stations &amp; travel</h2>
  <p class="subtitle">Fast transport between three fixed stations across the map — no vehicle required</p>

  <div class="card">
    <h4 style="margin-top:0">🚂 How it works</h4>
    <p>Three train stations are scattered across the map. Walk up to any station and use the <code>/train</code> command
    to see the other destinations and teleport to one. A ticket costs <strong>$150</strong> and takes you instantly
    to your chosen station.</p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🗺️ Station locations</h4>
      <p>Three fixed stations across San Andreas: North, Central, and South regions. All marked on the GPS map with the
      train icon. Any player can use any station — no level, faction or license required.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💰 Affordable travel</h4>
      <p>At just <strong>$150 per ride</strong>, trains are an economical way to cross the map quickly, especially in early levels.
      No need to drive yourself or own a vehicle.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⚡ Instant teleport</h4>
      <p>Trains are not vehicles you board and ride — you teleport instantly to your destination. A brief loading screen
      appears while the system processes your arrival.</p>
    </div>
  </div>
</section>

<section id="camping">
  <h2>🏕️ Camping</h2>
  <p class="subtitle">Set a temporary spawn point right next to your caravan</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">⛺ How it works</h4>
      <p>With the caravan attached and you at the wheel, stop on flat ground and set up camp. That spot becomes
      your new respawn point — every time you connect or die, you'll appear right next to your caravan instead
      of the usual spawn.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⏳ How long it lasts</h4>
      <p>The camping spawn stays active for <strong>3 PayDays</strong> (roughly 3 hours of play), then expires
      automatically and your spawn point reverts to normal.</p>
    </div>
  </div>
</section>

<section id="party">
  <h2>🎉 Parties</h2>
  <p class="subtitle">A dedicated spot to hang out, listen to music, and socialize</p>

  <div class="card">
    <h4 style="margin-top:0">🎟️ Getting in</h4>
    <p>A party venue exists on the map with its own entrance. Show up, pay a small ticket, and you're inside — a
    private instance shared only with the other guests. Music starts automatically as you walk in.</p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎵 You're the DJ</h4>
      <p>Anyone can change the track playing for everyone at the party, for a small fee.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍺 The bar</h4>
      <p>Grab a beer at the bar, then drink it — a bit of health, and a bit tipsy.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍖 The grill</h4>
      <p>Grab a bite for a few extra health points, on the spot.</p>
    </div>
  </div>

  <div class="note">
    Every party interaction only works near the right stand, and the money spent automatically feeds the bank of
    the business hosting the party.
  </div>
</section>

<section id="gps">
  <h2>🗺️ GPS &amp; Radar</h2>
  <p class="subtitle">Never get lost, and never speed past a camera</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🧭 GPS navigation</h4>
      <p>Open a category menu — factions, businesses, banks/ATMs, stores, fast food, farms, and more — pick a
      category, then a location, and get a checkpoint on your map instantly, with the exact distance shown.
      Categories update automatically as new locations appear.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📡 Speed radar</h4>
      <p>Police officers can install radar cameras around the city. Speed past the posted limit and you'll be
      flagged on the spot.</p>
    </div>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🚦 Digital dashboard (HUD)</h4>
    <p>Every time you get into a vehicle, a small live display shows current speed, the car's condition, fuel,
    dirt level, and whether the engine is running and the doors are locked.</p>
  </div>
</section>

<section id="phone">
  <h2>📱 Mobile phones</h2>
  <p class="subtitle">Call your friends and send texts, anywhere on the map</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">📲 Buying a phone</h4>
      <p>Buying a phone opens a shop with 5 brands to choose from:</p>
      <table>
        <tr><th>Model</th><th>Price</th></tr>
        <tr><td>Motorola 67</td><td>$500</td></tr>
        <tr><td>Samsung A70</td><td>$1,000</td></tr>
        <tr><td>iPhone 16</td><td>$1,600</td></tr>
        <tr><td>Samsung S27</td><td>$2,000</td></tr>
        <tr><td>iPhone 17</td><td>$2,200</td></tr>
      </table>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📇 Getting a number (SIM)</h4>
      <p>Once you own a phone, you can get a unique, randomly generated <strong>7-digit number</strong> — the
      number other players use to call or text you.</p>
    </div>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">📞 Calls</h4>
      <p>Calling a number rings whichever player owns it, if they're online. Once they pick up, everything typed
      by either side goes straight to the other. An unanswered call ends itself after 30 seconds; calls cost a
      small fee every 10 seconds, paid by the caller.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">✉️ SMS</h4>
      <p>A text message can be sent to any online player's number for a small flat fee, visible to both sides in
      chat, tagged with the phone brand used.</p>
    </div>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">⌚ Buying a watch</h4>
      <p>Watches work exactly like phones — buy one from the Electronics Shop and pick from multiple brands. Each watch is
      a personal item that tracks real-time. Use <code>/time</code> to check the current in-game time and date whenever you want.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🕐 Time tracking</h4>
      <p>The server runs on a full day-night cycle. Your watch displays the in-game time and date, helping you plan jobs,
      appointments, and activities. Some events only happen at specific times of the day.</p>
    </div>
  </div>
</section>

<section id="police">
  <h2>🚓 Law &amp; Order</h2>
  <p class="subtitle">What awaits you if you break the rules</p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🚨 Wanted &amp; arrests</h4>
      <p>On-duty officers can raise a suspect's wanted level and jail them at an arrest zone. A wanted player can
      also turn themselves in at the jail when no officer is on duty — same sentence and fine as a normal arrest,
      but with a surcharge that goes straight into the Police vault.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎫 Fines &amp; checks</h4>
      <p>A RAR or Police officer can issue a fine for a violation — it isn't deducted automatically, the driver
      has to accept it for the payment to go through. Both factions can also inspect your vehicle's documents
      and your driving licenses right there in the field, and confiscate either.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 Impounding</h4>
      <p>RAR can tow away vehicles with expired documents; once impounded, the engine stays dead until the owner
      pays a release fee to get it back.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔥 Firefighting</h4>
      <p>Fires can break out anywhere on the map. On duty, SMURD can take a Firetruck, get close, and hose it
      down until it's out.</p>
    </div>
  </div>
</section>

</main>

<footer>
  Nostalgia LosSantos | RPG — come play, build your story.
</footer>

</body>
</html>
