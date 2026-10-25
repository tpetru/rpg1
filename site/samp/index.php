<?php
// Started here (not in footer.php) so the shared footer can detect login status - by the time
// footer.php runs (near the end of <body>), headers are already sent and session_start() would fail.
session_start();
require_once __DIR__ . '/includes/lang.php';
$publicLoggedIn = isset($_SESSION['ucp_player_id']);
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
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
    display: grid;
    grid-template-columns: minmax(0,1fr) auto minmax(0,1fr);
    align-items: center;
    column-gap: 16px;
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
  .topbar .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 1.1rem; letter-spacing: 0.3px; color: #fff; text-decoration: none; transition: color 0.25s ease; white-space: nowrap; }
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
  .topbar nav { display: flex; flex-wrap: wrap; align-items: center; justify-content: center; gap: 6px 10px; justify-self: center; min-width: 0; }
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
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 600; letter-spacing: 0.3px;
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
    border: 1px solid var(--border); border-radius: 8px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 14px 32px rgba(0,0,0,0.5);
  }
  .topbar .nav-dd-menu a { display: block; position: static; padding: 8px 10px; border: none; border-radius: 7px; font-size: 0.88rem; white-space: nowrap; text-decoration: none; transition: background 0.2s ease, color 0.2s ease; }
  .topbar .nav-dd-menu a::after { display: none; }
  .topbar .nav-dd-menu a:hover { background: rgba(255,106,0,0.1); border: none; color: var(--accent); text-decoration: none; }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }
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
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
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

  footer { text-align: center; padding: 24px; color: var(--muted); font-size: 0.82rem; border-top: 1px solid var(--border); }
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
      <a href="forum.php" class="brand-dd-box">💬 <?= t('Forum') ?></a>
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
  <button type="button" class="topbar-toggle" id="topbarToggle" aria-label="<?= t('Toggle menu') ?>" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <nav>
    <a href="index.php">🏠 <?= t('Homepage') ?></a>
    <a href="presentation.php">🏙️ <?= t('Presentation') ?></a>
    <a href="forum.php">💬 <?= t('Forum') ?></a>
    <a href="games/index.php">🎮 <?= t('Games') ?></a>
    <a href="newspaper.php">📰 <?= t('Newspaper') ?></a>
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

<header class="hero">
  <div class="tagline"><?= t('Welcome to No-Santos') ?></div>
  <h1>🌴 Nostalgia: <span class="accent-word">Los Santos</span> <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</h1>
  <p>"Ah shit, here we go again."</p>
</header>

<main>
  <div class="grid">
    <a class="card <?= $publicLoggedIn ? '' : 'auth-login-trigger' ?>" href="<?= $publicLoggedIn ? 'ucp/dashboard.php' : '#' ?>">
      <div class="spot"></div>
      <div class="icon">🧭</div>
      <h2>UCP</h2>
      <p><?= t('The account control panel — login, stats, properties, factions and administration.') ?></p>
      <span class="go"><?= t('Enter') ?> <span>→</span></span>
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
      <h2><?= t('Presentation') ?></h2>
      <p><?= t("The server's presentation — welcome to Nostalgia: Los Santos | RPG.") ?></p>
      <span class="go"><?= t('Enter') ?> <span>→</span></span>
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

    <a class="card" href="forum.php">
      <div class="spot"></div>
      <div class="icon">💬</div>
      <h2><?= t('Forum') ?></h2>
      <p><?= t("Suggestions, complaints, bugs, faction regulations and the server's rules.") ?></p>
      <span class="go"><?= t('Enter') ?> <span>→</span></span>
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

    <a class="card" href="games/index.php">
      <div class="spot"></div>
      <div class="icon">🎮</div>
      <h2><?= t('Games') ?></h2>
      <p><?= t('Take a break with a few web-based mini-games, right here on the site.') ?></p>
      <span class="go"><?= t('Enter') ?> <span>→</span></span>
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

<?php include __DIR__ . '/includes/footer.php'; ?>

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
