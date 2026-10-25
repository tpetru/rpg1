<?php
// Started here (not in footer.php) so the shared footer can detect login status - by the time
// footer.php runs (near the end of <body>), headers are already sent and session_start() would fail.
session_start();

$houseCount = 0;
$businessCount = 0;
$hotelCount = 0;
$farmCount = 0;
$forestCount = 0;
$vehicleCount = 0;
$ammuCount = 0;
$shopCount = 0;
$gasStationCount = 0;

try {
    require_once __DIR__ . '/../includes/db.php';
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
        $vehicleCount    = presentation_count($mysqli, 'vehicles_personal');
        $ammuCount       = presentation_count($mysqli, 'ammunations');
        $shopCount       = presentation_count($mysqli, 'shops');
        $gasStationCount = presentation_count($mysqli, 'fuelstations');
    }
} catch (Exception $e) {
    // DB unavailable
}
require_once __DIR__ . '/includes/lang.php';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Presentation</title>
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
  .topbar .brand-logo {
    height: 34px; width: 34px; border-radius: 8px;
    border: 1px solid var(--border);
    transition: border-color 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease;
  }
  .topbar .brand:hover .brand-logo {
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
  .topbar .brand .dot-live {
    width: 8px; height: 8px; border-radius: 50%; background: var(--green);
    box-shadow: 0 0 0 3px rgba(62,207,142,0.18);
  }
  .topbar .status { color: var(--muted); font-size: 0.82rem; }

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
  header.hero .kicker {
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
  header.hero h1 span {
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }
  header.hero p.tagline { position: relative; z-index: 1; margin: 0; color: var(--muted); font-size: 1.05rem; }

  .stat-strip {
    max-width: 900px; margin: 40px auto 0;
    display: grid; grid-template-columns: repeat(4, 1fr);
    text-align: center;
    border-top: 1px solid var(--border);
    border-left: 1px solid var(--border);
  }
  .stat-strip .stat {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
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
    padding: 12px 16px; border-radius: 8px;
    background: var(--panel-2); margin-bottom: 8px;
  }
  .dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }

  .note {
    border-left: 3px solid var(--accent-2);
    background: rgba(255,133,51,0.06);
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
    display: grid;
    grid-template-columns: repeat(2, 36px);
    grid-auto-flow: row;
    gap: 6px;
    max-height: 90vh;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 10px 7px;
    z-index: 150;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
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
        border: 1px solid var(--border);
    color: var(--text);
    font-size: 0.78rem;
    padding: 4px 8px;
    border-radius: 6px;
    white-space: nowrap;
    pointer-events: none;
  }
  @media (max-width: 1100px) { .side-nav { display: none; } }
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

<?php include __DIR__ . '/includes/header-public.php'; ?>

<header class="hero">
  <span class="kicker"><?= t('Now recruiting citizens') ?></span>
  <h1>🌴 Nostalgia: <span>Los Santos</span> <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</h1>
  <p class="tagline">"Man, this whole street's changed."</p>
</header>

<div class="stat-strip">
  <div class="stat"><div class="num">∞</div><div class="lbl"><?= t('Ways to make money') ?></div></div>
  <div class="stat"><div class="num">8</div><div class="lbl"><?= t('Factions') ?></div></div>
  <div class="stat"><div class="num">13</div><div class="lbl"><?= t('Jobs') ?></div></div>
  <div class="stat"><div class="num">1</div><div class="lbl"><?= t('Elected President') ?></div></div>
  <div class="stat"><div class="num"><?= $forestCount ?></div><div class="lbl"><?= t('Forests') ?></div></div>
  <div class="stat"><div class="num"><?= $houseCount ?></div><div class="lbl"><?= t('Houses') ?></div></div>
  <div class="stat"><div class="num"><?= $businessCount ?></div><div class="lbl"><?= t('Businesses') ?></div></div>
  <div class="stat"><div class="num"><?= $hotelCount ?></div><div class="lbl"><?= t('Hotels') ?></div></div>
  <div class="stat"><div class="num"><?= $farmCount ?></div><div class="lbl"><?= t('Farms') ?></div></div>
  <div class="stat"><div class="num"><?= $vehicleCount ?></div><div class="lbl"><?= t('Personal vehicles') ?></div></div>
  <div class="stat"><div class="num"><?= $ammuCount ?></div><div class="lbl">Ammu-Nations</div></div>
  <div class="stat"><div class="num"><?= $shopCount ?></div><div class="lbl"><?= t('Shops') ?></div></div>
  <div class="stat"><div class="num"><?= $gasStationCount ?></div><div class="lbl"><?= t('Fuel Stations') ?></div></div>
</div>

<nav class="side-nav" aria-label="<?= t('Jump to section') ?>">
  <a href="#start" title="<?= t('Getting started') ?>">🚪</a>
  <a href="#factions" title="<?= t('Factions') ?>">🪪</a>
  <a href="#news" title="<?= t('Press & News') ?>">📰</a>
  <a href="#economy" title="<?= t('Economy') ?>">💰</a>
  <a href="#president" title="<?= t('President') ?>">🗳️</a>
  <a href="#jobs" title="<?= t('Jobs') ?>">💼</a>
  <a href="#farming" title="<?= t('Farming') ?>">🚜</a>
  <a href="#forests" title="<?= t('Forests') ?>">🌲</a>
  <a href="#wars" title="<?= t('Territory wars') ?>">⚔️</a>
  <a href="#drugs" title="<?= t('Drugs & Vault') ?>">🌿</a>
  <a href="#houses-biz" title="<?= t('Houses & Businesses') ?>">🏠</a>
  <a href="#hotels" title="<?= t('Hotels') ?>">🏨</a>
  <a href="#vehicles" title="<?= t('Vehicles') ?>">🚗</a>
  <a href="#exams" title="<?= t('Driving & flight exams') ?>">🪪</a>
  <a href="#weapons" title="<?= t('Weapons & Ammu-Nation') ?>">🔫</a>
  <a href="#shops" title="<?= t('Shops & Markets') ?>">🛍️</a>
  <a href="#health" title="<?= t('Health & Tiredness') ?>">❤️</a>
  <a href="#food" title="<?= t('Food') ?>">🍕</a>
  <a href="#skins" title="<?= t('Clothes & Skins') ?>">👕</a>
  <a href="#robbery" title="<?= t('Robbery') ?>">💰</a>
  <a href="#hunting" title="<?= t('Hunting') ?>">🏹</a>
  <a href="#casino" title="<?= t('Casino') ?>">🎰</a>
  <a href="#auctions" title="<?= t('Auctions') ?>">🔨</a>
  <a href="#golf" title="<?= t('Golf') ?>">⛳</a>
  <a href="#basketball" title="<?= t('Basketball') ?>">🏀</a>
  <a href="#events" title="<?= t('Events') ?>">🎮</a>
  <a href="#caravans" title="<?= t('Caravans') ?>">🚐</a>
  <a href="#trains" title="<?= t('Trains') ?>">🚂</a>
  <a href="#camping" title="<?= t('Camping') ?>">🏕️</a>
  <a href="#party" title="<?= t('Parties') ?>">🎉</a>
  <a href="#gps" title="<?= t('GPS & Radar') ?>">🗺️</a>
  <a href="#phone" title="<?= t('Phones') ?>">📱</a>
  <a href="#police" title="<?= t('Law & Order') ?>">🚓</a>
  <a href="#religion" title="<?= t('Religion & Sins') ?>">⛪</a>
</nav>

<section class="explore">
  <h2><?= t('Explore the server') ?></h2>
  <p class="lead"><?= t('Jump straight to any system — click a card to scroll down to it') ?></p>
  <div class="explore-grid">
    <a class="explore-card" href="#start"><span class="ico">🚪</span><span class="ttl"><?= t('Getting started') ?></span><span class="desc"><?= t('Account, stats, help') ?></span></a>
    <a class="explore-card" href="#factions"><span class="ico">🪪</span><span class="ttl"><?= t('Factions') ?></span><span class="desc"><?= t('9 factions, ranks, duty') ?></span></a>
    <a class="explore-card" href="#religion"><span class="ico">⛪</span><span class="ttl"><?= t('Religion & Sins') ?></span><span class="desc"><?= t('Faith, praying, Sunday confession') ?></span></a>
    <a class="explore-card" href="#jobs"><span class="ico">💼</span><span class="ttl"><?= t('Jobs') ?></span><span class="desc"><?= t('13 jobs, from delivery to lumberjack') ?></span></a>
    <a class="explore-card" href="#houses-biz"><span class="ico">🏠</span><span class="ttl"><?= t('Houses & Businesses') ?></span><span class="desc"><?= t('Fridge, animals, income') ?></span></a>
    <a class="explore-card" href="#vehicles"><span class="ico">🚗</span><span class="ttl"><?= t('Vehicles') ?></span><span class="desc"><?= t('Fuel, dirt, documents') ?></span></a>
    <a class="explore-card" href="#hotels"><span class="ico">🏨</span><span class="ttl"><?= t('Hotels') ?></span><span class="desc"><?= t('Passive income, rooms') ?></span></a>
    <a class="explore-card" href="#farming"><span class="ico">🚜</span><span class="ttl"><?= t('Farming') ?></span><span class="desc"><?= t('Plow to harvest, 5 stages') ?></span></a>
    <a class="explore-card" href="#forests"><span class="ico">🌲</span><span class="ttl"><?= t('Forests') ?></span><span class="desc"><?= t('Timber resources, supply chain') ?></span></a>
    <a class="explore-card" href="#wars"><span class="ico">⚔️</span><span class="ttl"><?= t('Territory wars') ?></span><span class="desc"><?= t('Mafia turf battles') ?></span></a>
    <a class="explore-card" href="#drugs"><span class="ico">🌿</span><span class="ttl"><?= t('Drugs & Vault') ?></span><span class="desc"><?= t('Craft, smuggle, defend') ?></span></a>
    <a class="explore-card" href="#news"><span class="ico">📰</span><span class="ttl"><?= t('Press & News') ?></span><span class="desc"><?= t('Newspapers, live Q&A') ?></span></a>
    <a class="explore-card" href="#economy"><span class="ico">💰</span><span class="ttl"><?= t('Economy') ?></span><span class="desc"><?= t('PayDay, bank, taxes') ?></span></a>
    <a class="explore-card" href="#president"><span class="ico">🗳️</span><span class="ttl"><?= t('President') ?></span><span class="desc"><?= t('Weekly vote, tax control') ?></span></a>
    <a class="explore-card" href="#exams"><span class="ico">🪪</span><span class="ttl"><?= t('Driving & flight exams') ?></span><span class="desc"><?= t('6 licenses to earn') ?></span></a>
    <a class="explore-card" href="#weapons"><span class="ico">🔫</span><span class="ttl"><?= t('Weapons & Ammu-Nation') ?></span><span class="desc"><?= t('Legal buys, W license') ?></span></a>
    <a class="explore-card" href="#shops"><span class="ico">🛍️</span><span class="ttl"><?= t('Shops & Markets') ?></span><span class="desc"><?= t('Stores, fast-food, gear') ?></span></a>
    <a class="explore-card" href="#health"><span class="ico">❤️</span><span class="ttl"><?= t('Health & Tiredness') ?></span><span class="desc"><?= t('Sleep, illness, SMURD') ?></span></a>
    <a class="explore-card" href="#food"><span class="ico">🍕</span><span class="ttl"><?= t('Food') ?></span><span class="desc"><?= t('Pizza, burger, donuts') ?></span></a>
    <a class="explore-card" href="#skins"><span class="ico">👕</span><span class="ttl"><?= t('Clothes & Skins') ?></span><span class="desc"><?= t('Outfits, uniforms') ?></span></a>
    <a class="explore-card" href="#robbery"><span class="ico">💰</span><span class="ttl"><?= t('Robbery') ?></span><span class="desc"><?= t('Crew up, hit a store') ?></span></a>
    <a class="explore-card" href="#hunting"><span class="ico">🏹</span><span class="ttl"><?= t('Hunting') ?></span><span class="desc"><?= t('Snipe deer, sell meat') ?></span></a>
    <a class="explore-card" href="#casino"><span class="ico">🎰</span><span class="ttl"><?= t('Casino') ?></span><span class="desc"><?= t('Roulette, slots, dice') ?></span></a>
    <a class="explore-card" href="#auctions"><span class="ico">🔨</span><span class="ttl"><?= t('Auctions') ?></span><span class="desc"><?= t('Bid on properties') ?></span></a>
    <a class="explore-card" href="#golf"><span class="ico">⛳</span><span class="ttl"><?= t('Golf') ?></span><span class="desc"><?= t('5-hole elimination') ?></span></a>
    <a class="explore-card" href="#basketball"><span class="ico">🏀</span><span class="ttl"><?= t('Basketball') ?></span><span class="desc"><?= t('Self-started mini-game') ?></span></a>
    <a class="explore-card" href="#events"><span class="ico">🎮</span><span class="ttl"><?= t('Events') ?></span><span class="desc"><?= t('Races, CS, Hunt The Mayor') ?></span></a>
    <a class="explore-card" href="#caravans"><span class="ico">🚐</span><span class="ttl"><?= t('Caravans') ?></span><span class="desc"><?= t('Tow a home on wheels') ?></span></a>
    <a class="explore-card" href="#trains"><span class="ico">🚂</span><span class="ttl"><?= t('Trains') ?></span><span class="desc"><?= t('Fast travel, 3 stations') ?></span></a>
    <a class="explore-card" href="#camping"><span class="ico">🏕️</span><span class="ttl"><?= t('Camping') ?></span><span class="desc"><?= t('Temporary spawn point') ?></span></a>
    <a class="explore-card" href="#party"><span class="ico">🎉</span><span class="ttl"><?= t('Parties') ?></span><span class="desc"><?= t('Music, drinks, grill') ?></span></a>
    <a class="explore-card" href="#gps"><span class="ico">🗺️</span><span class="ttl"><?= t('GPS & Radar') ?></span><span class="desc"><?= t('Navigation, speed traps') ?></span></a>
    <a class="explore-card" href="#phone"><span class="ico">📱</span><span class="ttl"><?= t('Phones') ?></span><span class="desc"><?= t('Calls & SMS') ?></span></a>
    <a class="explore-card" href="#police"><span class="ico">🚓</span><span class="ttl"><?= t('Law & Order') ?></span><span class="desc"><?= t('Wanted, fines, impound') ?></span></a>
  </div>
</section>

<main>

<section id="start">
  <h2>🚪 <?= t('Getting started') ?></h2>
  <p class="subtitle"><?= t('Everything you need to know before stepping into the world') ?></p>
  <div class="grid-3">
    <div class="card">
      <div class="feature-icon">📝</div>
      <h4><?= t('Create your account') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('When you connect, a dialog pops up automatically asking you to set a password —') ?>
      <?= t('Register the first time, Login afterward. No commands needed.') ?></p>
    </div>
    <div class="card">
      <div class="feature-icon">📊</div>
      <h4><?= t('Track your progress') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('A stats command shows your level, RP, money, faction and house at any time.') ?>
      <?= t("A separate command covers your vehicles' documents, fuel and dirt level.") ?></p>
    </div>
    <div class="card">
      <div class="feature-icon">🆘</div>
      <h4><?= t('Need help?') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('An in-game help command lists everything available to players, and a') ?>
      <?= t('"how to" guide walks you through any system in more depth, whenever you need it.') ?></p>
    </div>
  </div>
</section>

<section id="factions">
  <h2>🪪 Factions</h2>
  <p class="subtitle">Pick your side — public order or street life</p>

  <?php
    $factionKind = [
      1 => 'Public faction', 2 => 'Public faction', 3 => 'Public faction',
      4 => 'Mafia', 5 => 'Mafia', 6 => 'Mafia', 7 => 'Mafia',
      8 => 'Press', 9 => 'Tuning crew',
    ];
    for ($fid = 1; $fid <= 9; $fid++): ?>
    <div class="faction-row">
      <span class="dot" style="background:<?= ucp_faction_color($fid) ?>"></span>
      <strong><?= htmlspecialchars(ucp_faction_name($fid)) ?></strong>
      <span style="color:var(--muted); margin-left:auto"><?= $factionKind[$fid] ?></span>
    </div>
  <?php endfor; ?>

  <div class="card" style="margin-top:20px">
    <h4 style="margin-top:0"><?= t('How it works') ?></h4>
    <p><?= t("Every faction has a headquarters (HQ), its own bank, and a rank system (1 to 5, where 5 is the leader).") ?>
    <?= t("Senior members can invite new players, manage the faction bank, promote or remove others, and refuel/respawn the faction's fleet. Police, DMV and SMURD also run a") ?> <strong><?= t('duty') ?></strong> <?= t("system — clocking in near the HQ gives you access to your faction's special powers while you're on shift. SMURD crews can also respond to") ?>
    <strong><?= t('random house fires') ?></strong> <?= t("around the map with the faction's Firetruck.") ?></p>
    <p><strong>Loco Outlaw Customs</strong> <?= t('is the newest faction — a street tuning crew. Its members are the only') ?>
    <?= t("ones who can modify other players' cars with") ?> <code>/tune</code> <?= t('at their garage: spoilers, bumpers, exhausts, wheels, nitro, hydraulics and paintjobs. The menu only ever lists parts that actually fit the car in front of them, so nothing is wasted. Riding along as a passenger while a car gets tuned counts as a sin, though —') ?>
    <?= t('see') ?> <a href="#religion"><?= t('Religion & Sins') ?></a>.</p>
  </div>
</section>

<section id="news">
  <h2>📰 <?= t('Press & Newspapers') ?></h2>
  <p class="subtitle"><?= t('The News Reporters faction keeps the city informed') ?></p>
  <div class="grid-3">
    <div class="card">
      <div class="feature-icon">📢</div>
      <h4><?= t('Live news') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Reporters broadcast breaking news to every player on the server.') ?></p>
    </div>
    <div class="card">
      <div class="feature-icon">🗞️</div>
      <h4><?= t('Newspapers') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Higher-ranked reporters can publish a newspaper with up to 5 stories and put it up for sale.') ?>
      <?= t('Anyone can buy and read it. Newspapers reset every day at midnight.') ?></p>
    </div>
    <div class="card">
      <div class="feature-icon">🎤</div>
      <h4><?= t('Live interviews (Q&A)') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Senior reporters can invite a player to a live interview. The audience submits questions,') ?>
      <?= t('the reporter picks which ones to ask, and the guest answers live for everyone to see.') ?></p>
    </div>
  </div>
</section>

<section id="economy">
  <h2>💰 <?= t('Economy') ?></h2>
  <p class="subtitle"><?= t("Money doesn't fall from the sky — but you don't need to grind for it either") ?></p>

  <div class="card">
    <h4 style="margin-top:0">💵 <?= t('PayDay — your hourly wage') ?></h4>
    <p><?= t("Once every hour, every connected player automatically receives a wage based on their character's level") ?>
    (<?= t('the more experienced you are, the more you earn') ?>). <?= t('Income tax and health contributions — both set by the') ?>
    <?= t('elected President — are deducted, and the cash sitting in your bank account earns interest even while you do nothing.') ?></p>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🏘️ <?= t('Property tax') ?></h4>
    <p><?= t("If you own vehicles, a house, a business, a farm or a hotel, a small property tax proportional to each") ?>
    <?= t("asset's value is also deducted at every PayDay. It's itemized on your PayDay receipt, so you always know") ?>
    <?= t('exactly what you paid.') ?></p>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🏦 <?= t('Bank account & ATM') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Money can be held as cash or in the bank. The bank pays interest at every') ?>
      <?= t('PayDay. Any ATM in the city lets you move money between cash and account, with sensible per-transaction') ?>
      <?= t('limits and a small fee.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📈 <?= t('Level & RP') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Every PayDay also grows your RP (Role-Play Points) — a marker of your') ?>
      <?= t('experience on the server.') ?></p>
    </div>
  </div>
</section>

<section id="president">
  <h2>🗳️ <?= t('President') ?></h2>
  <p class="subtitle"><?= t("Every week, players vote a President who controls the city's taxes") ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🗳️ <?= t('The vote') ?></h4>
      <p><?= t('Every') ?> <strong><?= t('Sunday, between 08:00 and 19:30') ?></strong>, <?= t('players can cast a vote for a candidate. The') ?>
      <?= t('candidate must be online, and each player gets exactly') ?> <strong><?= t('one vote') ?></strong> <?= t('per week.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏛️ <?= t('The result') ?></h4>
      <p><?= t('Sunday at') ?> <strong>20:00</strong> <?= t('the winner is announced — the player with the most votes becomes the') ?>
      <?= t("new President. A sitting President can't win two terms in a row, so the role always rotates.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💼 <?= t('Presidential power') ?></h4>
      <p><?= t('The President can set the') ?> <strong><?= t('income tax') ?></strong> <?= t('and') ?> <strong><?= t('health contribution') ?></strong> <?= t('rates')  ?>
      <?= t("applied to everyone's PayDay, straight from in-game. Any change is announced to the whole server.") ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('Anyone can check who the current President is and which tax/contribution rates are active, at any time.') ?>
  </div>
</section>

<section id="jobs">
  <h2>💼 <?= t('Jobs') ?></h2>
  <p class="subtitle"><?= t('Earn your living honestly — or close to it. 13 unique jobs to choose from') ?></p>

  <div class="card">
    <h4 style="margin-top:0">📋 <?= t('Getting a job') ?></h4>
    <p><?= t('Head to the') ?> <strong>Job Center</strong> <?= t('at City Hall to get hired, or browse the full job list there.') ?>
    <?= t('You can only hold one job at a time, and you can quit anytime. Once hired, you start and stop working') ?>
    <?= t('whenever you like.') ?></p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🛵 Glovo</h4>
      <p><?= t('Delivery runs: pick up an order from a restaurant with the work vehicle, then drop it off at a house.') ?>
      <?= t('Pay scales with distance driven, and a small cut of every delivery feeds the business hosting the job.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚧 <?= t('Cement Truck Driver') ?></h4>
      <p><?= t("Load cement at the factory and haul it to one of the city's construction sites.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 <?= t('Gun Delivery') ?></h4>
      <p><?= t("Pick up weapons from a fixed loading point and deliver them to a mafia's HQ or fixed drop-offs.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 <?= t('Car Transporter') ?></h4>
      <p><?= t('Move vehicles from loading points to businesses around the city.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚕 Uber</h4>
      <p><?= t('Drive your own personal car as a taxi: set your fare and go on duty, then accept ride requests from') ?>
      <?= t('players who need a lift, charged over time until they get out.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚑 <?= t('Emergency Logistics Driver') ?></h4>
      <p><?= t('Head out from the depot with a Bobcat or Burrito, pick up medical supplies at the loading point, and') ?>
      <?= t('deliver them to shops.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚌 <?= t('Bus Driver') ?></h4>
      <p><?= t('Take a depot bus and drive one of three fixed routes. You earn at every checkpoint, a bonus at the end') ?>
      <?= t('of the route, and extra for every passenger who boards.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 <?= t('Electrician') ?></h4>
      <p><?= t("Drive the Electrician's job vehicle around town, repairing things for a fee. A locator points you to") ?>
      <?= t('nearby houses that need work — fix a fridge or bed before it breaks (paid from the house\'s own bank), or') ?>
      <?= t('clear an active apartment issue (flood, sewage, wiring). You can also offer nearby players a paid repair') ?>
      <?= t('for their broken phone or watch, which they confirm before you get paid.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">✈️ <?= t('Crop Duster Pilot') ?></h4>
      <p><?= t('Take off in one of the two job planes, fly to a marked point to load fertilizer, then reach a randomly') ?>
      <?= t('chosen farm within 2 minutes while flying between 100 and 200 altitude, and spray it. Good pay per run,') ?>
      <?= t('no license required for the job plane.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎣 <?= t('Fisherman') ?></h4>
      <p><?= t('Cast your line at dedicated fishing spots around the map. Catch fish (300-2500g) and deliver them to a randomly chosen') ?>
      <?= t('fast-food restaurant. Pay based on weight delivered — a relaxing way to make steady income.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💧 <?= t('Water Hauler') ?></h4>
      <p><?= t('Drive a DFT-30 truck and haul water to designated dump points. Spray plants and agricultural areas to earn money.') ?>
      <?= t('Distance-based pay with $1,000 per successful delivery. Useful for farms and landscaping work.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🌲 <?= t('Lumberjack') ?></h4>
      <p><?= t('Grab a chainsaw and harvest timber from forests across the map. Use') ?> <code>/chopwood</code> <?= t('at any forest to chop trees (one harvest per payday),') ?>
      <?= t('then load the wood into a truck and deliver it to the timber business. Earn money based on your haul. The more trees available in forests, the better the yield.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⛽ <?= t('Fuel Carrier') ?></h4>
      <p><?= t("Haul a roadtrain and tanker trailer from the Gas Distributor to a fuel station of your choice (or your own faction's HQ), topping up its tank.") ?>
      <?= t('Pays') ?> <strong>$6,000-$7,500</strong> <?= t('per delivery. Keeps the city\'s gas stations running.') ?></p>
    </div>
  </div>
</section>

<section id="farming">
  <h2>🚜 <?= t('Farming') ?></h2>
  <p class="subtitle"><?= t('Work the land, one stage a day, and harvest at the end') ?></p>

  <div class="card">
    <h4 style="margin-top:0"><?= t('Owning & Equipment') ?></h4>
    <p><?= t('You can own') ?> <strong><?= t('one farm') ?></strong> <?= t('at a time. Once you buy a plot, you must purchase the machines needed to work it:') ?>
    <strong><?= t('Tractor') ?></strong> ($10,000), <strong><?= t('Bulldozer') ?></strong> ($15,000), <?= t('and') ?> <strong><?= t('Combine') ?></strong> ($20,000). <?= t('These machines are expensive and') ?>
    <strong><?= t('wear out over time') ?></strong> — <?= t('treat them carefully. You can resell any machine from inside it for 75% back,') ?>
    <?= t('but a broken machine is only worth a fraction of its original price.') ?></p>

    <h4><?= t('The 5-Stage Cycle') ?></h4>
    <p><?= t('Farming works through a') ?> <strong><?= t('5-stage daily cycle') ?></strong>: <?= t('each real day you must complete ONE stage. If you fail a stage,') ?>
    <?= t("you lose that day's progress and can't retry until the next day.") ?></p>
    <ul>
      <li><strong><?= t('Plow') ?></strong> (1 <?= t('min') ?>) — <?= t('Drive a Tractor for 1 minute without leaving it') ?></li>
      <li><strong><?= t('Level') ?></strong> (2 <?= t('min') ?>) — <?= t('Drive a Bulldozer for 2 minutes without leaving it') ?></li>
      <li><strong><?= t('Seed') ?></strong> (3 <?= t('min') ?>) — <?= t('Drive a Tractor for 3 minutes without leaving it') ?></li>
      <li><strong><?= t('Fertilize') ?></strong> (1 <?= t('min') ?>) — <?= t('Drive a Tractor for 1 minute without leaving it') ?></li>
      <li><strong><?= t('Harvest') ?></strong> (4 <?= t('min') ?>) — <?= t('Drive a Combine for 4 minutes → earns') ?> <strong>$15,000</strong>, <?= t('cycle restarts') ?></li>
    </ul>

    <h4><?= t('Keeping Your Machines') ?></h4>
    <p><strong><?= t('Machines degrade:') ?></strong> <?= t('every time you leave a machine or fail to complete its stage, it takes damage. Damage reduces resale value and') ?>
    <?= t("eventually makes the machine unusable — you'll have to buy a replacement. Park carefully on flat ground and always complete your work") ?>
    <?= t('in one sitting or you risk losing your investment.') ?></p>

    <p><?= t("You can check your farm's status anytime with") ?> <code>/farmstats</code> <?= t('to see which stage you\'re on and what machines you own.') ?></p>
  </div>
</section>

<section id="forests">
  <h2>🌲 <?= t('Forests') ?></h2>
  <p class="subtitle"><?= t('Manage timber resources and supply the economy') ?></p>

  <div class="card">
    <p><?= t('Forests are ownable properties spread across Los Santos. Each forest has a') ?> <strong><?= t('maximum tree capacity') ?></strong> <?= t('and a') ?> <strong><?= t('current tree count') ?></strong>.
    <?= t('Trees grow naturally every payday (') ?><strong><?= t('+10 base') ?></strong>, <?= t('plus any saplings planted since the last payday). When a forest reaches maximum capacity, growth stops until trees are harvested.') ?></p>

    <h4 style="margin-top:16px"><?= t('Ownership & trading') ?></h4>
    <p><?= t('Like houses and businesses, you can buy a forest for sale, list it for sale to other players, trade it directly, or sell it back to the state for 60% of its value.') ?>
    <?= t('You can own') ?> <strong><?= t('one forest') ?></strong> <?= t('at a time.') ?></p>

    <h4 style="margin-top:16px"><?= t('The supply chain') ?></h4>
    <p><?= t('Lumberjacks harvest trees from forests using') ?> <code>/chopwood</code> (<?= t('once per payday') ?>), <?= t('regardless of ownership. The more trees your forest has stored, the more valuable') ?>
    <?= t('it is to active lumberjacks, making well-managed forests a genuine investment. Forest owners benefit indirectly from high activity and demand for timber.') ?></p>

    <h4 style="margin-top:16px">🌱 <?= t('Planting saplings') ?></h4>
    <p><?= t('Forest owners can speed up regrowth by stocking up on tree saplings. Buy them at a') ?> <strong><?= t('Tools Shop') ?></strong> ($10/<?= t('unit') ?>) <?= t('while sitting in a') ?> <strong>Benson</strong>, <?= t('then') ?>
    <?= t('drive the load to your forest and deposit it. A Lumberjack can then plant one at a time: drive a') ?> <strong><?= t('Forklift') ?></strong> <?= t('to the forest, get out with a shovel in hand and') ?>
    <?= t("plant it on the spot for a small fee — every planted sapling gets added to the forest's tree count at the next payday.") ?></p>

    <h4 style="margin-top:16px"><?= t('Growth & management') ?></h4>
    <p><?= t("Every payday (hourly), each forest gains trees equal to its growth rate. You can check your forest's status anytime and plan harvests accordingly. Strategic forest ownership") ?>
    <?= t('can generate passive income as lumberjacks depend on healthy, well-stocked forests to maximize their earnings.') ?></p>
  </div>
</section>

<section id="wars">
  <h2>⚔️ <?= t('Territory wars') ?></h2>
  <p class="subtitle"><?= t('Mafias only — conquer rival territory by force') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🔫 <?= t('Preparation') ?></h4>
      <p><?= t("Inside your mafia's HQ, you can heal up and get combat gear (high ranks even get a sniper rifle) before") ?>
      <?= t('heading out to attack.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📣 <?= t('Declaring war') ?></h4>
      <p><?= t("Stand inside an enemy mafia's territory (marked on the map) and declare war. Both factions need at") ?>
      <?= t('least 2 members online. After a short prep phase, the actual fight lasts') ?> <strong>15 <?= t('minutes') ?></strong>.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏆 <?= t('Conquest') ?></h4>
      <p><?= t('Whichever faction gets the most kills in the zone by the end of the 15 minutes wins. A tie goes to') ?>
      <strong><?= t('sudden death') ?></strong> (<?= t('first to 3 kills wins') ?>). <?= t('If the attackers win, the territory changes hands.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('The score can be checked live at any time during the fight. Leaders can surrender an active war, but only') ?>
    <?= t('after the first 5 minutes.') ?>
  </div>
</section>

<section id="drugs">
  <h2>🌿 <?= t('Drugs & Vault (mafias only)') ?></h2>
  <p class="subtitle"><?= t("The mafias' underground economy — it fuels the territory fight") ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🔒 <?= t('The mafia vault') ?></h4>
      <p><?= t('Every mafia keeps a') ?> <strong><?= t('vault') ?></strong> <?= t('where weed and drugs accumulate. Senior members can check the') ?>
      <?= t('stock at any time.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 <?= t('Transport & production') ?></h4>
      <p><?= t('Certain ranks haul raw weed to the vault, others turn it into drugs at the crafting station.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💉 <?= t('In battle') ?></h4>
      <p><?= t('While your faction is fighting a war, members can pull drugs from the vault and use them on the') ?>
      <?= t('contested territory for a quick burst of health.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚤 <?= t('Sea smuggling') ?></h4>
      <p><?= t('Using a designated faction boat, run supplies through a loading point (which alerts the Police and') ?>
      <?= t("raises everyone aboard to wanted level 6), then two randomly chosen pickup points, before switching to the") ?>
      <?= t("faction's Sultan and delivering the cargo to a random hotel. A successful run pays the vault in cash and") ?>
      <?= t('weed, plus a cash bonus for every surviving crew member, and drops wanted back to 5. Police get a bounty') ?>
      <?= t('for catching smugglers. Only one successful run per faction per day.') ?></p>
    </div>
  </div>
</section>

<section id="houses-biz">
  <h2>🏠 <?= t('Houses & Businesses') ?></h2>
  <p class="subtitle"><?= t('Invest in your in-game life') ?></p>
  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🏠 <?= t('Houses') ?></h4>
      <p><?= t("Buy any house that's for sale — whether it's unowned (state-owned) or listed by another player. You can") ?>
      <?= t('only own') ?> <strong><?= t('one') ?></strong> <?= t("house at a time, or rent one if you don't own anything. A house with an") ?>
      <?= t('interior can be entered and exited on foot at its pickup.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🛏️ <?= t('Tiredness & sleep') ?></h4>
      <p><?= t('Staying awake tires your character out over time; past a threshold it starts costing you extra health.') ?>
      <?= t('A bed at your own house (a one-time $7,500 upgrade) lets you sleep for free in 30 seconds, resetting') ?>
      <?= t('tiredness to zero. Away from home, any') ?> <strong><?= t('hotel') ?></strong> (<?= t('see below') ?>) <?= t('will rent you a room for a small') ?>
      <?= t('fee instead.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🐾 <?= t('House animals') ?></h4>
      <p><?= t('A house with a yard can get an animal ($5,000): Turtle or Deer for a Villa, Cow for a Countryside House.') ?>
      <?= t("It appears and lives in your yard, can be renamed, and a Cow has a chance to fill your fridge with fresh") ?>
      <?= t("milk at every PayDay you're online. Animals") ?> <strong><?= t('age with each PayDay') ?></strong> <?= t('and eventually die of old') ?>
      <?= t('age — a deceased animal stops producing anything and blocks renting the house out until you give it a') ?>
      <?= t('proper burial with a Romero hearse, driving it from your house to the chapel.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🧊 <?= t('Fridge & 🌳 Tree') ?></h4>
      <p><?= t('A fridge ($10,000, breaks after 32 days) can be stocked with milk/bananas/water/juice/beer between') ?>
      <?= t('15:00 and 20:00, each restoring health when eaten. City and Countryside houses can also grow a tree') ?>
      <?= t('($20,000) that yields more bananas the longer it grows, up to a cap, then resets. Fridges, beds, trees and') ?>
      <?= t('house animals are all ordered from') ?> <strong>Home Furnitures</strong>: <?= t("pick a Benson from their lot, place your") ?>
      <?= t('order there, then drive it home — the purchase is finalized the moment you pull up to your own house.') ?></p>
      <table style="margin-top:10px">
        <tr><th><?= t('Item') ?></th><th><?= t('Capacity') ?></th><th><?= t('Price/unit') ?></th><th><?= t('Health') ?></th></tr>
        <tr><td><?= t('Milk') ?></td><td>20 L</td><td>$100</td><td>+20</td></tr>
        <tr><td><?= t('Bananas') ?></td><td>30 <?= t('pcs') ?></td><td>$50</td><td>+10</td></tr>
        <tr><td><?= t('Water') ?></td><td>25 L</td><td>$150</td><td>+25</td></tr>
        <tr><td><?= t('Juice') ?></td><td>20 L</td><td>$200</td><td>+15</td></tr>
        <tr><td><?= t('Beer') ?></td><td>50 L</td><td>$250</td><td>+10</td></tr>
      </table>
      <p style="margin:8px 0 0; color:var(--red)"><?= t('A broken fridge or bed loses all value and must be replaced with') ?>
      <?= t('the same upgrade command.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 <?= t('Apartment problems & preventive repairs') ?></h4>
      <p><?= t('Every day at') ?> <strong>22:00</strong>, <?= t('a random owned apartment develops a problem (flood, clogged pipes,') ?>
      <?= t('a burnt circuit) that blocks spawning there until fixed. Only the') ?> <strong><?= t('Electrician') ?></strong> <?= t('job can fix') ?>
      <?= t("it, or preventively service a fridge/bed before it breaks — both paid from the house's own bank.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚰 <?= t('Bottles & 🗑️ Trash') ?></h4>
      <p><?= t('Drinking from the fridge leaves empty bottles, eating leaves trash (both capped at 100 per house). Special') ?>
      <?= t('vans pick them up at your house and pay your house bank per unit at the recycling/dump point. Below level') ?>
      <?= t('5, anyone can also make some quick cash on foot by') ?> <strong><?= t('buying a bag') ?></strong> <?= t('at the shop and searching') ?>
      <?= t('public street bins for loose bottles, selling them at the same drop-off point — the bag and its contents') ?>
      <?= t('are lost on death, respawn or disconnect.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏢 <?= t('Businesses') ?></h4>
      <p><?= t('You can own') ?> <strong><?= t('one') ?></strong> <?= t('business at a time. It earns passive income into its own bank whenever') ?>
      <?= t("players use the activity tied to it — fast food orders, ATM fees, phone/SIM sales, calls and SMS, fridge") ?>
      <?= t("shopping, appliance upgrades, Glovo deliveries, exam fees — you don't need to be online for it to earn.") ?></p>
      <p style="margin:8px 0 0"><strong><?= t('Tax audits (ANAF):') ?></strong> <?= t('every day at') ?> <strong>12:00</strong>, <?= t('a random') ?>
      <?= t('business gets flagged and earns nothing until cleared. Drive a') ?> <strong><?= t('model 428') ?></strong> <?= t('vehicle to your') ?>
      <?= t('business to pick up the paperwork, then deliver it to the tax office — the business unlocks at the next') ?>
      <?= t('PayDay.') ?></p>
    </div>
  </div>

  <h3>🏷️ <?= t('Selling to other players') ?></h3>
  <p><?= t('Houses, businesses, vehicles, farms and hotels can be') ?> <strong><?= t('listed for sale') ?></strong> <?= t('at your own price.') ?>
  <?= t('Another player buys it with the matching purchase command, and') ?> <strong><?= t('the money lands straight in your') ?>
  <?= t('bank') ?></strong> — <?= t("even while you're offline. Houses and businesses also support a direct offer to a specific") ?>
  <?= t('player, which they confirm.') ?></p>
  <p><?= t('Setting the price to') ?> <strong>0</strong> <?= t('cancels a listing. While listed, you can keep using the property') ?>
  <?= t('normally until someone buys it. Any of them can also be sold') ?> <strong><?= t('instantly to the state') ?></strong> <?= t('for') ?>
  <strong>60%</strong> <?= t('of their value, paid in cash on the spot.') ?></p>

  <div class="note warn">
    <?= t("A business, farm or hotel's bank balance") ?> <strong><?= t('transfers to the new owner') ?></strong> <?= t('along with it — withdraw') ?>
    <?= t('your money before selling.') ?>
  </div>
</section>

<section id="hotels">
  <h2>🏨 <?= t('Hotels') ?></h2>
  <p class="subtitle"><?= t('A passive-income property anyone can rent a room at, no ownership needed') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🛎️ <?= t('Renting a room') ?></h4>
      <p><?= t("Any player can pay a small fee at a hotel's pickup to sleep there for under a minute, dropping their") ?>
      <?= t("tiredness partway down — handy when you're away from home or don't own a bed. It doesn't have to be your") ?>
      <?= t('own hotel, and no bed is required.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💼 <?= t('Owning one') ?></h4>
      <p><?= t('You can own') ?> <strong><?= t('one') ?></strong> <?= t('hotel at a time, bought like a house or business, and it can be listed') ?>
      <?= t('for sale, sold directly to the state, or auctioned. Every guest\'s room fee splits between running costs and') ?>
      <?= t("the hotel's own bank — passive income whether you're online or not, withdrawable near any bank or ATM.") ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('Players can also rent a room at a hotel long-term instead of owning a house, paying rent out of their pocket') ?>
    <?= t("into the hotel's bank at every PayDay, until they end the arrangement.") ?>
  </div>
</section>

<section id="vehicles">
  <h2>🚗 <?= t('Personal vehicles') ?></h2>
  <p class="subtitle"><?= t('Your car, your rules — you can own up to 3 at once') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🔑 <?= t('Buying') ?></h4>
      <p><?= t("Buy the vehicle you're sitting in if it's for sale — you need a matching driving license to drive it.") ?>
      <?= t('It comes with insurance, a plate, and can be fitted with a medical kit and extinguisher bought at the shop.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⛽ <?= t('Fuel & condition') ?></h4>
      <p><?= t('Vehicles burn fuel while the engine runs — refuel at a gas station, or carry a gas can (filled at a') ?>
      <?= t('station) for emergencies far from one. Cars also get dirtier every time they respawn: past a threshold') ?>
      <?= t("you're warned to wash it, and above a higher one the engine refuses to start until it's cleaned at a Car") ?>
      <?= t('Wash.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 <?= t('Controls') ?></h4>
      <p><?= t("Toggle the engine, lock/unlock the doors, and switch lights, alarm, doors, hood or boot on the vehicle") ?>
      <?= t("you're driving — all visible live on your dashboard. Save your preferred parking spot so the car respawns") ?>
      <?= t('exactly there.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎨 <?= t('Personalization') ?></h4>
      <p><?= t('Repaint your primary and secondary colors, and get a custom license plate at the DMV HQ.') ?></p>
    </div>
  </div>

  <div class="card" style="margin-top:8px">
    <h4 style="margin-top:0">📋 <?= t('Documents (all at R.A.R.)') ?></h4>
    <p><?= t("Insurance, a technical inspection (ITP — engine off, hood open, boot closed, lights on), a plate, plus a") ?>
    <?= t("medical kit and extinguisher fitted from items bought at the shop. Each stays valid for the whole day it's") ?>
    <?= t('due to expire on. Police and DMV can inspect and confiscate any of them on the road.') ?></p>
  </div>

  <div class="grid-2" style="margin-top:8px">
    <div class="card">
      <h4 style="margin-top:0">🚲 🚙 <?= t('Rentals') ?></h4>
      <p><?= t('Bikes and cars are available to rent from several spots around the city, no license required — ideal') ?>
      <?= t("for when you don't (yet) own your own vehicle.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 <?= t('Impounding & towing') ?></h4>
      <p><?= t('DMV can tow away a car with expired documents; Police and DMV can also confiscate a vehicle outright.') ?>
      <?= t("Either way, the car won't start until you pay a release fee to get it back at the vehicle itself.") ?></p>
    </div>
  </div>
</section>

<section id="exams">
  <h2>🪪 <?= t('Driving & flight exams') ?></h2>
  <p class="subtitle"><?= t('Six categories, all testing real skill under a time limit') ?></p>

  <table>
    <tr><th><?= t('Category') ?></th><th><?= t('Vehicle') ?></th><th><?= t('License lasts (clean / damaged finish)') ?></th></tr>
    <tr><td>A</td><td><?= t('Motorcycle') ?></td><td>7 / 2 <?= t('days') ?></td></tr>
    <tr><td>B</td><td><?= t('Car') ?></td><td>10 / 3 <?= t('days') ?></td></tr>
    <tr><td>C</td><td><?= t('Truck + trailer') ?></td><td>12 / 3 <?= t('days') ?></td></tr>
    <tr><td>D</td><td><?= t('Bus') ?></td><td>13 / 3 <?= t('days') ?></td></tr>
    <tr><td>P</td><td><?= t('Plane') ?> ✈️</td><td>15 / 2 <?= t('days') ?></td></tr>
    <tr><td>H</td><td><?= t('Helicopter') ?> 🚁</td><td>16 / 2 <?= t('days') ?></td></tr>
  </table>

  <div class="note">
    <?= t('Every leg of the route has a time limit — fall too far behind at a checkpoint and you fail. Finishing with') ?>
    <?= t('the exam vehicle in good health earns the full validity shown above; a damaged finish gives the shorter one.') ?>
    <?= t('Rentals and exam vehicles never need a license.') ?>
  </div>

  <p><?= t('Your license status across all six categories can be checked at any time.') ?></p>
</section>

<section id="weapons">
  <h2>🔫 <?= t('Weapons & Ammu-Nation') ?></h2>
  <p class="subtitle"><?= t('Buying firepower legally, earning the right to carry it, and where the illegal stuff comes from') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏪 Ammu-Nation</h4>
      <p><?= t('Gun stores are marked on the map — walk up and press ENTER to step inside, then buy straight from the') ?>
      <?= t('counter. No license or faction is required to purchase: Colt 45, Deagle, Shotgun, MP5, AK-47, M4 and Uzi') ?>
      <?= t('are all available for cash, each with a fixed amount of ammo and its own price.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎯 <?= t('Weapon License (W)') ?></h4>
      <p><?= t('Take the shooting range exam near the category D exam zone for a fee. You\'re handed a Deagle, an MP5') ?>
      <?= t('and an AK-47 with limited ammo and') ?> <strong>90 <?= t('seconds') ?></strong> <?= t('to hit') ?> <strong>6 <?= t('targets') ?></strong>. <?= t('Hit all 6') ?>
      <?= t('and the license lasts') ?> <strong>8 <?= t('days') ?></strong>; <?= t("hit 5 out of 6 and it's valid for") ?> <strong>3 <?= t('days') ?></strong> —
      <?= t('miss more than that and you fail. Check it alongside your driving and flight licenses at any time.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚫 <?= t('Illegal weapons') ?></h4>
      <p><?= t('Grenades, tear gas, molotovs, the sawn-off and combat shotguns, Uzi, Tec-9, sniper rifle, rocket') ?>
      <?= t('launcher, heat-seeker, flamethrower, minigun, satchel charges and bombs are all treated as illegal to') ?>
      <?= t("carry. Ammu-Nation doesn't stock most of them — they come from the black market instead: the mafias' own") ?>
      <?= t('arsenal (handed out to members preparing for a territory war) or the') ?> <strong><?= t('Gun Delivery') ?></strong> <?= t('job,') ?>
      <?= t('which moves crates from a fixed pickup to mafia HQs and other drop-offs.') ?></p>
    </div>
  </div>

  <div class="note warn">
    <?= t('An on-duty Police officer (rank 2+) can search a nearby player for weapons and drugs. Getting caught') ?>
    <?= t('carrying anything from the illegal list gets your') ?> <strong><?= t('Weapon W license confiscated on the spot') ?></strong>
    — <?= t('whether or not you were carrying it legally otherwise.') ?>
  </div>
</section>

<section id="shops">
  <h2>🛍️ <?= t('Shops & Markets') ?></h2>
  <p class="subtitle"><?= t('Multiple types of stores across the city, each with their own inventory and purpose') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏪 24/7 Shop</h4>
      <p><?= t('Convenience store chain. Buy medical kits (') ?><strong>$500</strong>), <?= t('fire extinguishers (') ?><strong>$500</strong>),
      <?= t('and gas cans (') ?><strong>$500</strong>). <?= t('Multiple locations across the city — marked on GPS.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📱 <?= t('Electronics Shop') ?></h4>
      <p><?= t('Tech store. Purchase phones and watches here. Phones unlock GPS navigation and messaging;') ?>
      <?= t('watches let you check the time with') ?> <code>/time</code>. <?= t('Each item is customizable by brand.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔧 <?= t('Tools Shop') ?></h4>
      <p><?= t('Specialized equipment retailer. Buy fishing rods (') ?><strong>$1,500</strong>) <?= t('for the Fisherman job and tree saplings') ?>
      <?= t('for the forest system. One of the most important supply chains on the server.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 Ammu-Nation</h4>
      <p><?= t('Weapons shop for legal firearm purchases. Stock includes Colt 45, Deagle, Shotgun, MP5, AK-47, M4 and Uzi,') ?>
      <?= t('each with pre-loaded ammo. No license required to enter or purchase — that comes later if you need to carry legally.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">👕 <?= t('Clothing Store') ?></h4>
      <p><?= t('Buy outfits and change your wardrobe. Each outfit costs') ?> <strong>$10,000</strong> <?= t('and is permanently added to your closet.') ?>
      <?= t('Switch freely between owned outfits at any clothing store, for free.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍕 <?= t('Pizza Shop') ?></h4>
      <p><?= t('Fast-food franchise. Buy food for') ?> <strong>$50</strong> <?= t('to restore') ?> <strong>+20 HP</strong>, <?= t('capped at 100. Revenue feeds the') ?>
      <?= t('central fast-food business bank (shared with burger, chicken and donuts).') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍔 <?= t('Burger Shop') ?></h4>
      <p><?= t('Another fast-food option. Burgers cost') ?> <strong>$55</strong> <?= t('for') ?> <strong>+25 HP</strong>. <?= t('Revenue flows into the same') ?>
      <?= t('centralized fast-food business bank as all other food spots.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍗 Cluckin' Bell</h4>
      <p><?= t('Fried chicken fast-food. Meals are') ?> <strong>$60</strong> <?= t('for') ?> <strong>+22 HP</strong>. <?= t('Every purchase feeds the shared') ?>
      <?= t('fast-food business bank (one owner, four food types).') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍩 <?= t('Donut Shop') ?></h4>
      <p><?= t('Quick and cheap fast-food. Donuts are only') ?> <strong>$30</strong> <?= t('for') ?> <strong>+15 HP</strong> — <?= t("ideal for when you're low on cash.") ?>
      <?= t('Revenue joins the central fast-food business pool.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t("All fast-food shops (Pizza, Burger, Cluckin' Bell, Donut Shop) share the same central business bank. Whoever owns") ?>
    <?= t('the fast-food business receives income from all four food spots whenever a player buys from any of them — passive income') ?>
    <?= t("whether you're online or not.") ?>
  </div>
</section>

<section id="health">
  <h2>❤️ <?= t('Health, Tiredness & Illness') ?></h2>
  <p class="subtitle"><?= t("RPG life isn't always easy") ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">⏳ <?= t('Health drains over time') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t("Every character's health slowly ticks down over time — one more") ?>
      <?= t('reason to keep an eye on your wellbeing and call SMURD when you need to.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">😴 <?= t('Tiredness') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Staying awake builds up tiredness over time; past a threshold it') ?>
      <?= t('starts eating into your health too. Sleeping at your own bed resets it for free; a hotel room resets it') ?>
      <?= t('partway for a small fee.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚑 <?= t('SMURD treatment') ?></h4>
      <p style="color:var(--muted); margin:0"><?= t('Hop into an ambulance as a passenger and a medic can heal you') ?>
      <?= t('fully for a small fee.') ?></p>
    </div>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🦠 <?= t('You can get sick') ?></h4>
    <p><?= t('From time to time, illness outbreaks can appear in the city. If you catch one, you\'ll feel the effect') ?>
    <?= t('right away (unsteady movement, faster health drain) and get a clear message about it. Illness fades on its') ?>
    <?= t('own over time, but the fastest cure is heading to the SMURD hospital for treatment.') ?></p>
  </div>
</section>

<section id="food">
  <h2>🍕 <?= t('Food') ?></h2>
  <p class="subtitle"><?= t("Hunger won't kill you, but a little extra health never hurts") ?></p>

  <div class="grid-4">
    <div class="card">
      <h4 style="margin-top:0">🍕 Pizza</h4>
      <p style="color:var(--muted); margin:0"><strong>$50</strong> — <?= t('restores') ?> <strong>20 HP</strong>, <?= t('capped at 100.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍔 Burger</h4>
      <p style="color:var(--muted); margin:0"><strong>$55</strong> — <?= t('restores') ?> <strong>25 HP</strong>, <?= t('capped at 100.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍗 Cluckin' Bell</h4>
      <p style="color:var(--muted); margin:0"><strong>$60</strong> — <?= t('restores') ?> <strong>22 HP</strong>, <?= t('capped at 100.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍩 Donut Shop</h4>
      <p style="color:var(--muted); margin:0"><strong>$30</strong> — <?= t('restores') ?> <strong>15 HP</strong>, <?= t('capped at 100.') ?></p>
    </div>
  </div>

  <table style="margin-top:8px">
    <tr><th><?= t('Spot') ?></th><th><?= t('Price') ?></th><th><?= t('Health restored') ?></th></tr>
    <tr><td>Pizza</td><td>$50</td><td>+20 HP</td></tr>
    <tr><td>Burger</td><td>$55</td><td>+25 HP</td></tr>
    <tr><td>Cluckin' Bell</td><td>$60</td><td>+22 HP</td></tr>
    <tr><td>Donut Shop</td><td>$30</td><td>+15 HP</td></tr>
  </table>

  <div class="note">
    <?= t('All four only work near the correct location — food spots are marked on the map with their own icons, always') ?>
    <?= t("visible. The label above each spot shows its name, price, and how much health it restores. A cut of every") ?>
    <?= t('order feeds the bank of the business hosting that spot.') ?>
  </div>
</section>

<section id="skins">
  <h2>👕 <?= t('Clothes & Skins') ?></h2>
  <p class="subtitle"><?= t('Buy your wardrobe and change your look whenever you want') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🛍️ <?= t('Clothing store') ?></h4>
      <p><?= t('Look for a clothing store on the GPS. There you can browse the outfit catalog — each outfit costs') ?>
      <strong>$10,000</strong> <?= t('and gets worn immediately on purchase — or open your wardrobe to switch freely') ?>
      <?= t('between outfits you already own.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">♾️ <?= t('Yours forever') ?></h4>
      <p><?= t('Purchased outfits are') ?> <strong><?= t('permanently yours') ?></strong>. <?= t('Switch between them anytime, free of charge,') ?>
      <?= t('at any clothing store. Your skin persists across disconnects.') ?></p>
    </div>
  </div>

  <h3>🪪 <?= t('Faction uniforms') ?></h3>
  <p><?= t("If you're in a faction, your") ?> <strong><?= t('uniform depends on your rank') ?></strong>:</p>
  <table>
    <tr><th><?= t('Rank') ?></th><th><?= t('Uniform') ?></th></tr>
    <tr><td>1 - 2</td><td><?= t('Basic uniform') ?></td></tr>
    <tr><td>3 - 4</td><td><?= t('Intermediate uniform') ?></td></tr>
    <tr><td>5</td><td><?= t('Leader uniform') ?></td></tr>
  </table>
  <p><?= t('Spawning on duty at your faction spawn puts you in the right uniform automatically. Spawning as a civilian') ?>
  <?= t("wears your personal outfit instead. Inside your faction's HQ you can switch between uniform and civilian") ?>
  <?= t('clothes at will.') ?></p>
</section>

<section id="robbery">
  <h2>💰 <?= t('Robbery') ?></h2>
  <p class="subtitle"><?= t('Hit a store with your crew — but shake the police before you cash out') ?></p>

  <div class="note warn">
    <?= t('You need') ?> <strong>10/10 <?= t('rob points') ?></strong> <?= t('to pull a robbery. You gain') ?> <strong><?= t('+1 rob point every PayDay') ?></strong>
    (<?= t('max 10') ?>), <?= t('and a robbery costs') ?> <strong><?= t('all 10') ?></strong>. <?= t('Your points are visible in your stats, under') ?>
    <strong>[Crime]</strong>.
  </div>

  <h3><?= t('How it works') ?></h3>
  <ol>
    <li><?= t('Get your crew into a car — you have to be the') ?> <strong><?= t('driver') ?></strong>.</li>
    <li><?= t('Pull up next to a shop or fast-food spot and start the robbery.') ?></li>
    <li><?= t('Everyone in the car at that moment joins in: each loses 10 rob points and gets') ?> <strong><?= t('wanted level 6') ?></strong>.</li>
    <li><?= t('The') ?> <strong><?= t('police are notified immediately') ?></strong> — <?= t('with your name and the store hit.') ?></li>
    <li><?= t('A checkpoint appears at a random business. Reach it, and a second one appears. You must reach') ?>
    <strong><?= t('both') ?></strong> <?= t('to cash out.') ?></li>
  </ol>

  <h3><?= t('The payout') ?></h3>
  <p><?= t('After the second business, every crew member gets a base cut plus a per-participant bonus and a random') ?>
  <?= t('extra — the more people in the car, the more everyone earns. Once delivered, the wanted level drops from 6 to') ?>
  <strong>5</strong>.</p>

  <div class="note warn">
    <strong><?= t('Die or disconnect, and you get nothing.') ?></strong> <?= t('The robbery continues for the rest of the crew, but') ?>
    <?= t("you're out of the payout. Only members still") ?> <strong><?= t('alive and connected') ?></strong> <?= t('at delivery time get paid.') ?>
  </div>
</section>

<section id="hunting">
  <h2>🏹 <?= t('Hunting') ?></h2>
  <p class="subtitle"><?= t('Track deer through the forest and sell the meat for cash') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎯 <?= t('Getting started') ?></h4>
      <p><?= t("Head to the hunting spot marked on the map and you'll be handed a sniper rifle for free.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🦌 <?= t('The hunt') ?></h4>
      <p><?= t('Deer roam the forest and bolt if you get within 30m, so snipe from a distance — a close shot drops them,') ?>
      <?= t('a near-miss sends them fleeing. You can carry several carcasses at once, and a hunted deer respawns') ?>
      <?= t('elsewhere after a few seconds.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💵 <?= t('Selling') ?></h4>
      <p><?= t("Sell everything you're carrying at once at any shop, for") ?> <strong>$2,500 <?= t('per deer') ?></strong>.</p>
    </div>
  </div>
</section>

<section id="casino">
  <h2>🎰 <?= t('Casino') ?></h2>
  <p class="subtitle"><?= t('Three tables, one house edge — gamble responsibly') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎡 <?= t('Roulette') ?></h4>
      <p><?= t('Bet on a color, odd/even, or an exact number. Color or parity pays double (zero always loses to those') ?>
      <?= t('bets); an exact number pays 36x.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎰 <?= t('Slots') ?></h4>
      <p><?= t('Three matching Sevens pays 10x, any other three of a kind pays 5x, two Sevens pays double.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎲 <?= t('Dice') ?></h4>
      <p><?= t('You and the house each roll two dice — the higher total wins double, a tie returns your bet.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('Walk into the casino (marked on the map) to play, and leave whenever you like. All three games share the') ?>
    <?= t('same betting range, and every table plays at its own physical spot inside.') ?>
  </div>
</section>

<section id="auctions">
  <h2>🔨 <?= t('Auctions') ?></h2>
  <p class="subtitle"><?= t('Staff-run bidding wars over houses, businesses, farms and hotels') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📣 <?= t('Opening') ?></h4>
      <p><?= t("An admin puts a property up for auction for the whole server to bid on, announcing what's for sale and") ?>
      <?= t('the starting price.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💰 <?= t('Bidding') ?></h4>
      <p><?= t('Each bid must beat the current highest and is taken from your bank immediately — outbid, and it\'s') ?>
      <?= t('refunded automatically. Every bid resets the clock to') ?> <strong>90 <?= t('seconds') ?></strong>, <?= t('with warnings at 60, 30') ?>
      <?= t('and 5 seconds left.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏁 <?= t('Closing') ?></h4>
      <p><?= t('When the clock runs out, the highest bidder wins the property outright — if it already had an owner,') ?>
      <?= t('they lose it with') ?> <strong><?= t('no compensation') ?></strong>. <?= t('No bids at all means the auction just ends.') ?></p>
    </div>
  </div>
</section>

<section id="golf">
  <h2>⛳ <?= t('Golf Tournament') ?></h2>
  <p class="subtitle"><?= t('An elimination mini-game, opened periodically by staff') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📝 <?= t('Signing up') ?></h4>
      <p><?= t("When an admin opens registration, a server-wide announcement appears. You can sign up while it's open,") ?>
      <?= t('and drop out anytime — though leaving mid-round eliminates you automatically.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏌️ <?= t('How it plays') ?></h4>
      <p><?= t('Each player gets their own ball, labelled with their ID. Hit with a chosen power (0-200) — power') ?>
      <?= t('controls distance, and your look direction sets the aim. Every shot reports the stroke count and the') ?>
      <?= t('remaining distance to the hole.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏆 <?= t('Tournament structure') ?></h4>
      <p><?= t('A tournament has') ?> <strong>5 <?= t('holes') ?></strong>, <?= t("played in a shuffled order that's randomized every time. It") ?>
      <?= t('ends when a') ?> <strong><?= t('single winner') ?></strong> <?= t('remains or all 5 holes have been played.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t("Each round's goal is to sink the ball in the fewest strokes. Once everyone finishes the hole, only the") ?>
    <?= t('players with the fewest strokes advance — the rest are eliminated.') ?>
  </div>
</section>

<section id="basketball">
  <h2>🏀 <?= t('Basketball') ?></h2>
  <p class="subtitle"><?= t('A quick mini-game you can start yourself, no admin required') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">📝 <?= t('Joining a game') ?></h4>
      <p><?= t('Head to a basketball court on the map and sign up. Once enough players have joined, a short countdown') ?>
      <?= t('starts and the round begins automatically.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏀 <?= t('How it plays') ?></h4>
      <p><?= t("You move through the court's 8 hoops, one at a time, in a shuffled order. At each hoop you throw with a") ?>
      <?= t('chosen power (0-20); power and aim direction determine how far the ball travels.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎯 <?= t('Feedback on every shot') ?></h4>
      <p><?= t('Right after the ball reaches the hoop, you learn whether it was a GOAL or a MISS, plus a hint on power') ?>
      <?= t('if you clearly missed.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('Each hoop is played once per round — no retries. At the end, the scores of everyone who finished all 8 hoops') ?>
    <?= t('are compared and the winner (most GOALs) is announced.') ?>
  </div>
</section>

<section id="events">
  <h2>🎮 <?= t('Staff-run events') ?></h2>
  <p class="subtitle"><?= t('Races, team fights and manhunts — started by staff, unlike Golf/Basketball which you start yourself') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🏁 <?= t('Races (Best Lap)') ?></h4>
      <p><?= t('An admin opens a race on a chosen track, with either a fixed vehicle or a random one shared by') ?>
      <?= t('everyone. Sign up while registration is open — at the start, a 5-second countdown runs and timing starts') ?>
      <?= t('exactly at "GO." Beating the best known time for that track and vehicle sets a new server RECORD.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔫 Counter Strike</h4>
      <p><strong>5 vs 5</strong> <?= t('bomb matches, several running at once. A match runs 10 rounds, teams swap sides') ?>
      <?= t('after round 5. Terrorists win by planting and detonating the bomb or wiping out CT; CT wins by wiping out T') ?>
      <?= t('(if unplanted) or defusing the bomb — once planted, CT must defuse even if T is wiped out.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🏛️ Hunt The Mayor</h4>
      <p><?= t('One randomly picked player becomes the "Mayor," spawning well-armed at a secret location; everyone else') ?>
      <?= t('hunts them down over 15 minutes. Landing a hit pays a bounty, the kill pays more, and a surviving Mayor') ?>
      <?= t('collects a prize of their own.') ?></p>
    </div>
  </div>
</section>

<section id="caravans">
  <h2>🚐 <?= t('Personal caravans') ?></h2>
  <p class="subtitle"><?= t('A home on wheels, towed behind your own car') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🔑 <?= t('Getting a caravan') ?></h4>
      <p><?= t('Caravans are currently handed out by server staff — there are 3 different types, each with its own') ?>
      <?= t("model. Once you have one, it's permanently tied to your account.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚙 <?= t('Towing it') ?></h4>
      <p><?= t("Attach the caravan right behind your personal car while you're at the wheel, and it follows you") ?>
      <?= t('wherever you go. Detach it to unhitch and park it exactly where you stop; the spot is saved and survives a') ?>
      <?= t('restart.') ?></p>
    </div>
  </div>
</section>

<section id="trains">
  <h2>🚂 <?= t('Train stations & travel') ?></h2>
  <p class="subtitle"><?= t('Fast transport between three fixed stations across the map — no vehicle required') ?></p>

  <div class="card">
    <h4 style="margin-top:0">🚂 <?= t('How it works') ?></h4>
    <p><?= t('Three train stations are scattered across the map. Walk up to any station and use the') ?> <code>/train</code> <?= t('command') ?>
    <?= t('to see the other destinations and teleport to one. A ticket costs') ?> <strong>$150</strong> <?= t('and takes you instantly') ?>
    <?= t('to your chosen station.') ?></p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🗺️ <?= t('Station locations') ?></h4>
      <p><?= t('Three fixed stations across San Andreas: North, Central, and South regions. All marked on the GPS map with the') ?>
      <?= t('train icon. Any player can use any station — no level, faction or license required.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">💰 <?= t('Affordable travel') ?></h4>
      <p><?= t('At just') ?> <strong>$150 <?= t('per ride') ?></strong>, <?= t('trains are an economical way to cross the map quickly, especially in early levels.') ?>
      <?= t('No need to drive yourself or own a vehicle.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⚡ <?= t('Instant teleport') ?></h4>
      <p><?= t('Trains are not vehicles you board and ride — you teleport instantly to your destination. A brief loading screen') ?>
      <?= t('appears while the system processes your arrival.') ?></p>
    </div>
  </div>
</section>

<section id="camping">
  <h2>🏕️ <?= t('Camping') ?></h2>
  <p class="subtitle"><?= t('Set a temporary spawn point right next to your caravan') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">⛺ <?= t('How it works') ?></h4>
      <p><?= t('With the caravan attached and you at the wheel, stop on flat ground and set up camp. That spot becomes') ?>
      <?= t("your new respawn point — every time you connect or die, you'll appear right next to your caravan instead") ?>
      <?= t('of the usual spawn.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">⏳ <?= t('How long it lasts') ?></h4>
      <p><?= t('The camping spawn stays active for') ?> <strong>3 PayDays</strong> (<?= t('roughly 3 hours of play') ?>), <?= t('then expires') ?>
      <?= t('automatically and your spawn point reverts to normal.') ?></p>
    </div>
  </div>
</section>

<section id="party">
  <h2>🎉 <?= t('Parties') ?></h2>
  <p class="subtitle"><?= t('A dedicated spot to hang out, listen to music, and socialize') ?></p>

  <div class="card">
    <h4 style="margin-top:0">🎟️ <?= t('Getting in') ?></h4>
    <p><?= t("A party venue exists on the map with its own entrance. Show up, pay a small ticket, and you're inside — a") ?>
    <?= t('private instance shared only with the other guests. Music starts automatically as you walk in.') ?></p>
  </div>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">🎵 <?= t("You're the DJ") ?></h4>
      <p><?= t('Anyone can change the track playing for everyone at the party, for a small fee.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍺 <?= t('The bar') ?></h4>
      <p><?= t('Grab a beer at the bar, then drink it — a bit of health, and a bit tipsy.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🍖 <?= t('The grill') ?></h4>
      <p><?= t('Grab a bite for a few extra health points, on the spot.') ?></p>
    </div>
  </div>

  <div class="note">
    <?= t('Every party interaction only works near the right stand, and the money spent automatically feeds the bank of') ?>
    <?= t('the business hosting the party.') ?>
  </div>
</section>

<section id="gps">
  <h2>🗺️ <?= t('GPS & Radar') ?></h2>
  <p class="subtitle"><?= t('Never get lost, and never speed past a camera') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🧭 <?= t('GPS navigation') ?></h4>
      <p><?= t('Open a category menu — factions, businesses, banks/ATMs, stores, fast food, farms, and more — pick a') ?>
      <?= t('category, then a location, and get a checkpoint on your map instantly, with the exact distance shown.') ?>
      <?= t('Categories update automatically as new locations appear.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📡 <?= t('Speed radar') ?></h4>
      <p><?= t('Police officers can install radar cameras around the city. Speed past the posted limit and you\'ll be') ?>
      <?= t('flagged on the spot.') ?></p>
    </div>
  </div>

  <div class="card">
    <h4 style="margin-top:0">🚦 <?= t('Digital dashboard (HUD)') ?></h4>
    <p><?= t("Every time you get into a vehicle, a small live display shows current speed, the car's condition, fuel,") ?>
    <?= t('dirt level, and whether the engine is running and the doors are locked.') ?></p>
  </div>
</section>

<section id="phone">
  <h2>📱 <?= t('Mobile phones') ?></h2>
  <p class="subtitle"><?= t('Call your friends and send texts, anywhere on the map') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">📲 <?= t('Buying a phone') ?></h4>
      <p><?= t('Buying a phone opens a shop with 5 brands to choose from:') ?></p>
      <table>
        <tr><th><?= t('Model') ?></th><th><?= t('Price') ?></th></tr>
        <tr><td>Motorola 67</td><td>$500</td></tr>
        <tr><td>Samsung A70</td><td>$1,000</td></tr>
        <tr><td>iPhone 16</td><td>$1,600</td></tr>
        <tr><td>Samsung S27</td><td>$2,000</td></tr>
        <tr><td>iPhone 17</td><td>$2,200</td></tr>
      </table>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📇 <?= t('Getting a number (SIM)') ?></h4>
      <p><?= t('Once you own a phone, you can get a unique, randomly generated') ?> <strong><?= t('7-digit number') ?></strong> — <?= t('the') ?>
      <?= t('number other players use to call or text you.') ?></p>
    </div>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">📞 <?= t('Calls') ?></h4>
      <p><?= t("Calling a number rings whichever player owns it, if they're online. Once they pick up, everything typed") ?>
      <?= t('by either side goes straight to the other. An unanswered call ends itself after 30 seconds; calls cost a') ?>
      <?= t('small fee every 10 seconds, paid by the caller.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">✉️ SMS</h4>
      <p><?= t("A text message can be sent to any online player's number for a small flat fee, visible to both sides in") ?>
      <?= t('chat, tagged with the phone brand used.') ?></p>
    </div>
  </div>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">⌚ <?= t('Buying a watch') ?></h4>
      <p><?= t('Watches work exactly like phones — buy one from the Electronics Shop and pick from multiple brands. Each watch is') ?>
      <?= t('a personal item that tracks real-time. Use') ?> <code>/time</code> <?= t('to check the current in-game time and date whenever you want.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🕐 <?= t('Time tracking') ?></h4>
      <p><?= t('The server runs on a full day-night cycle. Your watch displays the in-game time and date, helping you plan jobs,') ?>
      <?= t('appointments, and activities. Some events only happen at specific times of the day.') ?></p>
    </div>
  </div>
</section>

<section id="police">
  <h2>🚓 <?= t('Law & Order') ?></h2>
  <p class="subtitle"><?= t('What awaits you if you break the rules') ?></p>

  <div class="grid-2">
    <div class="card">
      <h4 style="margin-top:0">🚨 <?= t('Wanted & arrests') ?></h4>
      <p><?= t("On-duty officers can raise a suspect's wanted level and jail them at an arrest zone. A wanted player can") ?>
      <?= t('also turn themselves in at the jail when no officer is on duty — same sentence and fine as a normal arrest,') ?>
      <?= t('but with a surcharge that goes straight into the Police vault.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🎫 <?= t('Fines & checks') ?></h4>
      <p><?= t("A DMV or Police officer can issue a fine for a violation — it isn't deducted automatically, the driver") ?>
      <?= t("has to accept it for the payment to go through. Both factions can also inspect your vehicle's documents") ?>
      <?= t('and your driving licenses right there in the field, and confiscate either.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🚚 <?= t('Impounding') ?></h4>
      <p><?= t('DMV can tow away vehicles with expired documents; once impounded, the engine stays dead until the owner') ?>
      <?= t('pays a release fee to get it back.') ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🔥 <?= t('Firefighting') ?></h4>
      <p><?= t('Fires can break out anywhere on the map. On duty, SMURD can take a Firetruck, get close, and hose it') ?>
      <?= t("down until it's out.") ?></p>
    </div>
  </div>
</section>

<section id="religion">
  <h2>⛪ <?= t('Religion & Sins') ?></h2>
  <p class="subtitle"><?= t('Pick a faith, pray daily, and confess what you did every Sunday') ?></p>

  <div class="grid-3">
    <div class="card">
      <h4 style="margin-top:0">✝️ <?= t('Your faith') ?></h4>
      <p><?= t("Right after you register you're invited to pick a religion with") ?> <code>/setreligion</code>: <strong>Ateu</strong>
      (<?= t('the rationalists') ?>), <strong>The Ascendants</strong> (<?= t('a modern church of progress') ?>), <strong>The Holy Order</strong>
      (<?= t('medieval tradition and asceticism') ?>) <?= t('or') ?> <strong>The Divine Blessing</strong> — Santa Luz, <?= t('a colonial church built') ?>
      <?= t('on community and nature.') ?> <code>/whatreligion</code> <?= t('shows what each one believes. Three churches are scattered') ?>
      <?= t("across the map and you'll find them in your GPS.") ?></p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">📜 <?= t('The 12 sins') ?></h4>
      <p><?= t('You never tick a sin yourself — the server flags them while you play: getting wanted, robbing, gambling,') ?>
      <?= t('smuggling, killing out of revenge, blowing past a radar, doing jail time, drinking or using drugs, eating meat') ?>
      <?= t('on a fasting day, driving without a license, or riding along while a car gets illegally tuned.') ?></p>
      <p><strong>Anti-Nature</strong> <?= t('is the odd one out: you start the week guilty of it, and you clear it by planting') ?>
      <?= t('a tree or doing one Water Hauler shift. Read the full list in-game with') ?> <code>/sinlist</code>.
      <?= t('Everything resets every') ?> <strong>Monday at 00:00</strong>.</p>
    </div>
    <div class="card">
      <h4 style="margin-top:0">🙏 <?= t('Praying') ?></h4>
      <p><code>/pray</code> <?= t('once a day, at any time. Every prayer is counted for that week, and the count is what') ?>
      <?= t("decides whether Sunday's confession pays out at all — so it rewards showing up, not cramming.") ?></p>
    </div>
  </div>

  <div class="card" style="margin-top:20px">
    <h4 style="margin-top:0">🕯️ <?= t('Sunday confession') ?></h4>
    <p><?= t('On Sunday,') ?> <code>/pray</code> <?= t('also opens a panel listing all 12 sins. Click the ones you believe you committed') ?>
    <?= t('this week — they turn green, click again to untick — then press') ?> <strong><?= t('ASK FORGIVENESS') ?></strong>. <?= t("You're frozen") ?>
    <?= t('for 5 seconds plus one per confessed sin while the priest prays, then the server compares your list against what') ?>
    <?= t('actually happened.') ?></p>

    <table style="margin-top:14px">
      <tr><th><?= t('How well you remembered') ?></th><th><?= t('What you get') ?></th></tr>
      <tr>
        <td><strong><?= t('Wrong on 2 or more sins') ?></strong></td>
        <td><?= t('Forgiven anyway — full health, tiredness reset to 0, any illness cured') ?></td>
      </tr>
      <tr>
        <td><strong><?= t('Wrong on exactly 1') ?></strong></td>
        <td><?= t('The above, plus every personal vehicle cleaned and') ?> <strong>$25,000</strong></td>
      </tr>
      <tr>
        <td><strong><?= t('All 12 correct') ?></strong></td>
        <td><?= t('The above, plus a full tank in every personal vehicle,') ?> <strong><?= t('+1 day on every license') ?></strong>
        (<?= t('an expired one becomes valid again today') ?>) <?= t('and') ?> <strong>$50,000</strong></td>
      </tr>
    </table>

    <p style="margin-bottom:0"><strong><?= t('Two catches.') ?></strong> <?= t('Those rewards only unlock if you prayed at least') ?>
    <strong>4 <?= t('times') ?></strong> <?= t('that week. The prayer bonus, however, is always paid out no matter what:') ?>
    <strong>$5,000 <?= t('per prayer') ?></strong> <?= t('that week, plus a small random top-up.') ?></p>
  </div>
</section>

</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

</body>
</html>
