<?php
// Camere: planificator de camere de supraveghere. Utilizatorul isi deseneaza terenul si casa (poligoane cu
// laturi editabile), apoi "Generează" plaseaza N camere pe peretii casei folosind un algoritm de optimizare
// (acoperire maxima: alegere greedy + cautare locala cu perturbari, gen simulated annealing) care tine cont de
// unghiul de vedere, distanta si de faptul ca peretii casei blocheaza vederea. Totul ruleaza in browser.
header('Cache-Control: no-cache, must-revalidate');
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Camere de supraveghere · Planificator</title>
<link rel="icon" type="image/png" href="/samp/ucp/assets/img/favicon.ico">
<style>
  :root {
    --bg: #0b0d10; --panel: #12161b; --panel-2: #181d23; --border: #252b32;
    --text: #f2f2f2; --muted: #8e969f; --accent: #ff6a00; --accent-2: #ff8533;
    --land: #1d3b26; --land-line: #5fbf74; --house: #3a3f47; --house-line: #e8e8e8;
    --bad: #ff5a5a;
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html, body { margin: 0; background: var(--bg); color: var(--text); }
  body { font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif; font-size: 14px; }
  header { padding: 14px 16px 6px; max-width: 1280px; margin: 0 auto; }
  header h1 { margin: 0; font-size: 1.25rem; }
  header p { margin: 4px 0 0; color: var(--muted); font-size: 13px; }
  .layout {
    display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 14px;
    max-width: 1280px; margin: 0 auto; padding: 10px 16px 30px;
  }
  @media (max-width: 860px) { .layout { grid-template-columns: minmax(0, 1fr); } }
  .stage {
    position: relative; background: var(--panel); border: 1px solid var(--border); border-radius: 14px;
    overflow: hidden; touch-action: none; aspect-ratio: 4 / 3; min-height: 300px;
  }
  .stage canvas { display: block; width: 100%; height: 100%; cursor: crosshair; }
  .campop {
    position: absolute; z-index: 3; display: flex; gap: 4px; padding: 5px; transform: translate(-50%, 0);
    background: rgba(18,22,27,.96); border: 1px solid var(--border); border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,.5);
    white-space: nowrap; touch-action: none; user-select: none;
  }
  .campop button { padding: 6px 10px; font-size: 13px; }
  .campop .deg { align-self: center; color: var(--muted); font-size: 12px; padding: 0 4px; min-width: 38px; text-align: center; }
  .hint {
    position: absolute; left: 10px; bottom: 8px; right: 10px; color: var(--muted); font-size: 12px;
    pointer-events: none; text-shadow: 0 1px 2px #000;
  }
  .side { display: flex; flex-direction: column; gap: 12px; }
  .card { background: var(--panel); border: 1px solid var(--border); border-radius: 14px; padding: 12px; }
  .card h2 { margin: 0 0 8px; font-size: 14px; color: var(--muted); font-weight: 600; letter-spacing: .3px; }
  .tabs { display: flex; gap: 6px; margin-bottom: 10px; flex-wrap: wrap; }
  .tabs button { flex: 1 1 auto; }
  .tabs button.add { flex: 0 0 auto; border-style: dashed; color: var(--muted); }
  .bopts { display: flex; gap: 6px; align-items: center; margin-bottom: 8px; flex-wrap: wrap; }
  .bopts input[type=text] {
    flex: 1 1 120px; min-width: 0; font: inherit; color: var(--text); background: #0d1014; border: 1px solid var(--border);
    border-radius: 8px; padding: 5px 7px;
  }
  .bopts label { color: var(--muted); font-size: 13px; white-space: nowrap; }
  button {
    font: inherit; color: var(--text); background: var(--panel-2); border: 1px solid var(--border);
    border-radius: 10px; padding: 7px 10px; cursor: pointer;
  }
  button:hover { border-color: var(--accent); }
  button.on { background: var(--accent); border-color: var(--accent); color: #140a02; font-weight: 700; }
  button.big {
    width: 100%; padding: 12px; font-size: 16px; font-weight: 800; letter-spacing: .5px;
    background: linear-gradient(135deg, var(--accent), var(--accent-2)); color: #140a02; border: 0;
  }
  button.big:hover { filter: brightness(1.08); }
  button.small { padding: 3px 8px; font-size: 12px; border-radius: 8px; }
  .row { display: flex; gap: 6px; flex-wrap: wrap; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 3px 2px; vertical-align: middle; }
  td.lbl { color: var(--muted); white-space: nowrap; }
  td.lbl b { color: var(--text); }
  input[type=number] {
    width: 100%; font: inherit; color: var(--text); background: #0d1014; border: 1px solid var(--border);
    border-radius: 8px; padding: 5px 7px;
  }
  input[type=number]:focus { outline: none; border-color: var(--accent); }
  .unit { color: var(--muted); font-size: 12px; }
  .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 13px; }
  .stats div { background: var(--panel-2); border-radius: 8px; padding: 6px 8px; }
  .stats b { display: block; font-size: 16px; }
  .warn { color: var(--bad); font-size: 13px; margin-top: 6px; }
  .muted { color: var(--muted); font-size: 12px; }
  .camlist { margin: 8px 0 0; padding: 0; list-style: none; font-size: 13px; }
  .camlist li { display: flex; gap: 8px; align-items: center; padding: 4px 0; border-top: 1px solid var(--border); }
  .dot { width: 12px; height: 12px; border-radius: 50%; flex: none; }
  details.spoiler { border: 1px solid var(--border); border-radius: 10px; background: var(--panel-2); }
  details.spoiler > summary {
    cursor: pointer; padding: 8px 10px; list-style: none; font-weight: 600; display: flex; align-items: center; gap: 8px;
  }
  details.spoiler > summary::-webkit-details-marker { display: none; }
  details.spoiler > summary::after { content: '▸'; margin-left: auto; color: var(--muted); transition: transform .15s; }
  details.spoiler[open] > summary::after { transform: rotate(90deg); }
  details.spoiler > #sidesBox { padding: 0 8px 8px; }
  .fab {
    position: absolute; right: 10px; bottom: 30px; z-index: 2; display: none;
    padding: 10px 14px; border-radius: 22px; font-weight: 700; border: 0; color: #140a02;
    background: linear-gradient(135deg, var(--accent), var(--accent-2)); box-shadow: 0 6px 18px rgba(0,0,0,.5);
  }
  .sheet-bg { position: fixed; inset: 0; background: rgba(0,0,0,.55); z-index: 9; display: flex; align-items: flex-end; }
  .sheet {
    width: 100%; max-height: 75vh; overflow: auto; background: var(--panel); border-top: 1px solid var(--border);
    border-radius: 18px 18px 0 0; padding: 12px 14px 20px; box-shadow: 0 -12px 40px rgba(0,0,0,.6);
  }
  .sheet-head { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
  .sheet-head b { flex: 1; font-size: 15px; }
  @media (max-width: 860px) {
    details.spoiler { display: none; }
    .fab { display: block; }
    .stage { aspect-ratio: 1 / 1; min-height: 0; }   /* min-height + 4:3 latea pagina peste ecranul telefonului */
  }
  .modal-bg {
    position: fixed; inset: 0; background: rgba(0,0,0,.6); display: flex; align-items: center; justify-content: center;
    z-index: 10; padding: 16px;
  }
  .modal {
    background: var(--panel); border: 1px solid var(--border); border-radius: 16px; padding: 18px;
    width: 100%; max-width: 380px; box-shadow: 0 20px 60px rgba(0,0,0,.6);
  }
  .modal h3 { margin: 0 0 12px; }
  .modal label { display: block; margin: 10px 0 4px; color: var(--muted); font-size: 13px; }
  .modal .count { display: flex; align-items: center; gap: 8px; }
  .modal .count input { text-align: center; font-size: 22px; font-weight: 800; }
  .modal .count button { font-size: 20px; width: 44px; height: 44px; flex: none; }
  .modal .actions { display: flex; gap: 8px; margin-top: 16px; }
  .modal .actions button { flex: 1; padding: 10px; }
  .progress { height: 8px; background: #0d1014; border-radius: 4px; overflow: hidden; margin-top: 10px; }
  .progress i { display: block; height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), #ffd08a); transition: width .1s; }
  .think { color: var(--muted); font-size: 13px; margin-top: 8px; min-height: 18px; }
</style>
</head>
<body>
<header>
  <h1>📹 Planificator camere de supraveghere</h1>
  <p>Desenează terenul și casa, apoi apasă <b>Generează</b>: algoritmul caută cele mai bune locuri pe pereții casei pentru camerele tale.</p>
</header>

<div class="layout">
  <div>
    <div class="stage" id="stage">
      <canvas id="cv"></canvas>
      <div class="hint" id="hint"></div>
      <button class="fab" id="fabSides">📏 Laturi</button>
      <div class="campop" id="campop" hidden>
        <button id="cpMove" title="Mută camera pe alt perete">✥ Mută</button>
        <button id="cpLeft" title="Rotește spre stânga (ține apăsat)">⟲</button>
        <span class="deg" id="cpDeg"></span>
        <button id="cpRight" title="Rotește spre dreapta (ține apăsat)">⟳</button>
        <button id="cpDel" title="Șterge camera">🗑</button>
        <button id="cpClose" title="Închide">✕</button>
      </div>
    </div>
  </div>

  <div class="side">
    <div class="card">
      <div class="tabs" id="tabs"></div>
      <div class="bopts" id="bopts">
        <input type="text" id="bName" maxlength="30" placeholder="Nume construcție">
        <label title="Algoritmul poate monta camere pe pereții ei"><input type="checkbox" id="bCams"> camere pe ea</label>
        <button class="small" id="bDel" title="Șterge construcția">🗑</button>
      </div>
      <div class="row" style="margin-bottom:8px">
        <button class="small" id="btnDraw">✏️ Desenează din nou</button>
        <button class="small" id="btnRect">▭ Dreptunghi</button>
        <button class="small" id="btnL">⌐ Formă L</button>
        <button class="small" id="btnDone" hidden>✔ Închide forma</button>
      </div>
      <div class="row" id="viewBtns" style="margin-bottom:8px" hidden>
        <button class="small on" id="btnDirs">🔦 Direcții: afișate</button>
        <button class="small on" id="btnZones">🎨 Zone filmate: afișate</button>
        <button class="small" id="btnClear">Ascunde camerele</button>
      </div>
      <details class="spoiler" id="sidesDet">
        <summary id="sidesSum">📏 Dimensiuni laturi</summary>
        <div id="sidesBox">
          <table id="sides"></table>
          <div class="muted" id="areaInfo" style="margin-top:6px"></div>
        </div>
      </details>
      <div class="warn" id="warn"></div>
    </div>

    <div class="card">
      <button class="big" id="btnGen">⚡ Generează</button>
      <button id="btnAddCam" style="width:100%;margin-top:8px">＋ Adaugă cameră</button>
      <div id="result" hidden>
        <div class="stats" style="margin-top:10px">
          <div>Acoperire<b id="stPct">–</b></div>
          <div>Suprafață filmată<b id="stArea">–</b></div>
          <div>Văzut de 2+ camere<b id="stDouble">–</b></div>
          <div>Unghi / distanță<b id="stCam">–</b></div>
        </div>
        <ul class="camlist" id="camlist"></ul>
      </div>
    </div>

    <div class="card muted">
      Trage de colțuri ca să le muți, de „+” de pe mijlocul unei laturi ca să adaugi un colț, sau de interiorul formei ca s-o muți cu totul.
      Lungimile se pot scrie exact în tabel (în metri). Zonele <span style="color:#ff7a7a">roșiatice</span> sunt nefilmate.
    </div>
  </div>
</div>

<div class="sheet-bg" id="sheetBg" hidden>
  <div class="sheet" id="sheet">
    <div class="sheet-head"><b id="sheetTitle">Dimensiuni laturi</b><button class="small" id="sheetClose">✕ Închide</button></div>
  </div>
</div>

<div class="modal-bg" id="modal" hidden>
  <div class="modal">
    <h3>Câte camere ai?</h3>
    <div class="count">
      <button id="mMinus">−</button>
      <input type="number" id="mCount" min="1" max="20" value="4">
      <button id="mPlus">+</button>
    </div>
    <label for="mFov">Unghi de vedere al unei camere (grade)</label>
    <input type="number" id="mFov" min="30" max="360" step="5" value="90">
    <label for="mRange">Distanța utilă de filmare (metri)</label>
    <input type="number" id="mRange" min="2" max="60" step="1" value="15">
    <label><input type="checkbox" id="mNear" checked> Prioritate pe zona din jurul casei (primii 5 m)</label>
    <div id="mProgress" hidden>
      <div class="progress"><i id="mBar"></i></div>
      <div class="think" id="mThink"></div>
    </div>
    <div class="actions" id="mActions">
      <button id="mCancel">Renunță</button>
      <button class="on" id="mGo">Pornește AI</button>
    </div>
  </div>
</div>

<script>
(() => {
'use strict';

// ---------- stare ----------
const STORE = 'camere.v1';
const COLORS = ['#ff6a00', '#3fa9ff', '#ffd23f', '#c86bff', '#4fe3a1', '#ff4f8b', '#9be35a', '#5ad1e3',
                '#ff9f6b', '#a0a0ff', '#e3c85a', '#ff6bd5', '#6bffc8', '#d8ff6b', '#6b9bff', '#ffb36b',
                '#b36bff', '#6bffe9', '#ff6b6b', '#c8c8c8'];
let land = rect(0, 0, 30, 20);
let buildings = [{ name: 'Casă', poly: lshape(9, 5, 12, 10), cams: true }];
let active = 0;              // 'land' sau indexul constructiei editate
let drawing = null;          // puncte in curs de desenare
let result = null;           // rezultatul generarii
let settings = { count: 4, fov: 90, range: 15, near: true };
let show = { dirs: true, zones: true };   // ce se deseneaza peste camere

function rect(x, y, w, h) { return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]]; }
function lshape(x, y, w, h) {
  return [[x, y], [x + w, y], [x + w, y + h * 0.55], [x + w * 0.55, y + h * 0.55], [x + w * 0.55, y + h], [x, y + h]];
}
try {
  const s = JSON.parse(localStorage.getItem(STORE) || 'null');
  if (s && s.land && (s.buildings || s.house)) {
    land = s.land;
    buildings = s.buildings && s.buildings.length ? s.buildings : [{ name: 'Casă', poly: s.house, cams: true }];
    if (s.settings) settings = Object.assign(settings, s.settings);
    if (s.show) show = Object.assign(show, s.show);
  }
} catch (e) {}
function save() {
  try { localStorage.setItem(STORE, JSON.stringify({ land, buildings, settings, show })); } catch (e) {}
}

// ---------- geometrie ----------
const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const mul = (a, k) => [a[0] * k, a[1] * k];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1];
const len = a => Math.hypot(a[0], a[1]);
const norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l]; };
const r1 = v => Math.round(v * 100) / 100;
function area(p) { let s = 0; for (let i = 0; i < p.length; i++) { const a = p[i], b = p[(i + 1) % p.length]; s += a[0] * b[1] - b[0] * a[1]; } return s / 2; }
function ccw(p) { return area(p) < 0 ? p.slice().reverse() : p; }
function inside(pt, poly) {
  let c = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i], b = poly[j];
    if ((a[1] > pt[1]) !== (b[1] > pt[1]) && pt[0] < (b[0] - a[0]) * (pt[1] - a[1]) / (b[1] - a[1]) + a[0]) c = !c;
  }
  return c;
}
function segX(p1, p2, p3, p4) {     // intersectie stricta intre segmente
  const d1x = p2[0] - p1[0], d1y = p2[1] - p1[1], d2x = p4[0] - p3[0], d2y = p4[1] - p3[1];
  const den = d1x * d2y - d1y * d2x;
  if (Math.abs(den) < 1e-12) return false;
  const t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / den;
  const u = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / den;
  return t > 1e-9 && t < 1 - 1e-9 && u > -1e-9 && u < 1 + 1e-9;
}
function selfIntersects(p) {
  const n = p.length;
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
    if (j === i + 1 || (i === 0 && j === n - 1)) continue;
    if (segX(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n])) return true;
  }
  return false;
}
function polyInside(inner, outer) {
  if (!inner.every(pt => inside(pt, outer))) return false;
  for (let i = 0; i < inner.length; i++) for (let j = 0; j < outer.length; j++)
    if (segX(inner[i], inner[(i + 1) % inner.length], outer[j], outer[(j + 1) % outer.length])) return false;
  return true;
}
const L = i => String.fromCharCode(65 + (i % 26)) + (i >= 26 ? Math.floor(i / 26) : '');

// Schimba lungimea laturii i "intinzand" forma: tot ce e dincolo de capatul laturii se muta pe directia ei.
// Pentru dreptunghiuri / forme L asta pastreaza unghiurile drepte (ca la "stretch" din CAD).
function setSide(poly, i, newLen) {
  const n = poly.length, a = poly[i], b = poly[(i + 1) % n];
  const old = len(sub(b, a));
  if (!(newLen > 0.05) || old < 1e-6) return poly;
  const d = norm(sub(b, a)), cut = dot(b, d) - Math.min(old * 0.5, 1e-3), delta = newLen - old;
  return poly.map((p, j) => j === i ? p : (dot(p, d) >= cut || j === (i + 1) % n) ? [r1(p[0] + d[0] * delta), r1(p[1] + d[1] * delta)] : p);
}

// ---------- canvas & vedere ----------
const cv = document.getElementById('cv'), ctx = cv.getContext('2d');
const stage = document.getElementById('stage');
let W = 0, H = 0, DPR = 1, view = { s: 10, ox: 0, oy: 0 };
function fit() {
  const pts = buildings.reduce((a, b) => a.concat(b.poly), land.slice());
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of pts) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
  const pad = 46, w = Math.max(x1 - x0, 1), h = Math.max(y1 - y0, 1);
  const s = Math.min((W - pad * 2) / w, (H - pad * 2) / h);
  view = { s, ox: (W - w * s) / 2 - x0 * s, oy: (H + h * s) / 2 + y0 * s };
}
const toS = p => [view.ox + p[0] * view.s, view.oy - p[1] * view.s];
const toW = (x, y) => [(x - view.ox) / view.s, (view.oy - y) / view.s];
function resize() {
  const r = stage.getBoundingClientRect();
  DPR = window.devicePixelRatio || 1; W = r.width; H = r.height;
  cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
  fit(); draw();
}
new ResizeObserver(resize).observe(stage);

function pathPoly(p) { ctx.beginPath(); p.forEach((q, i) => { const s = toS(q); i ? ctx.lineTo(s[0], s[1]) : ctx.moveTo(s[0], s[1]); }); ctx.closePath(); }

function draw() {
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
  ctx.clearRect(0, 0, W, H);
  // grila de 1 m (sau 5 m daca e prea deasa)
  const step = view.s < 8 ? 5 : 1;
  const [wx0, wy1] = toW(0, 0), [wx1, wy0] = toW(W, H);
  ctx.lineWidth = 1;
  for (let x = Math.floor(wx0 / step) * step; x <= wx1; x += step) {
    const sx = toS([x, 0])[0];
    ctx.strokeStyle = x % (step * 5) === 0 ? '#1f252c' : '#161b20';
    ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, H); ctx.stroke();
  }
  for (let y = Math.floor(wy0 / step) * step; y <= wy1; y += step) {
    const sy = toS([0, y])[1];
    ctx.strokeStyle = y % (step * 5) === 0 ? '#1f252c' : '#161b20';
    ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(W, sy); ctx.stroke();
  }

  pathPoly(land); ctx.fillStyle = '#16301f'; ctx.fill();

  if (result && show.zones) drawCoverage();

  pathPoly(land); ctx.strokeStyle = '#5fbf74'; ctx.lineWidth = active === 'land' ? 2.5 : 1.5; ctx.stroke();
  buildings.forEach((b, bi) => {
    pathPoly(b.poly); ctx.fillStyle = bi === active ? '#454b55' : '#3a3f47'; ctx.fill();
    ctx.strokeStyle = bi === active ? '#ffffff' : '#c8c8c8'; ctx.lineWidth = bi === active ? 3 : 2; ctx.stroke();
  });

  labelHits = [];
  drawLabels(land, 'land', '#8fe0a0');
  buildings.forEach((b, bi) => drawLabels(b.poly, bi, '#ffffff'));
  // numele constructiilor
  ctx.font = 'bold 13px Segoe UI, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  buildings.forEach((b, bi) => {
    const c = toS(labelPoint(b.poly));
    ctx.font = 'bold 13px Segoe UI, sans-serif';
    ctx.fillStyle = bi === active ? '#ffffff' : '#aab2bb'; ctx.fillText(b.name || 'Construcție', c[0], b.cams ? c[1] : c[1] - 7);
    if (!b.cams) { ctx.font = '11px Segoe UI, sans-serif'; ctx.fillStyle = '#8e969f'; ctx.fillText('fără camere', c[0], c[1] + 8); }
  });
  ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';

  if (drawing) {
    ctx.strokeStyle = '#ffd08a'; ctx.lineWidth = 2; ctx.setLineDash([6, 4]);
    ctx.beginPath(); drawing.forEach((q, i) => { const s = toS(q); i ? ctx.lineTo(s[0], s[1]) : ctx.moveTo(s[0], s[1]); });
    if (hover) { const s = toS(hover); ctx.lineTo(s[0], s[1]); }
    ctx.stroke(); ctx.setLineDash([]);
    drawing.forEach((q, i) => { const s = toS(q); ctx.fillStyle = i === 0 ? '#ff6a00' : '#ffd08a'; ctx.beginPath(); ctx.arc(s[0], s[1], i === 0 ? 7 : 4, 0, 7); ctx.fill(); });
    if (hover && drawing.length) {
      const d = len(sub(hover, drawing[drawing.length - 1])); const s = toS(hover);
      ctx.fillStyle = '#ffd08a'; ctx.font = '12px Segoe UI, sans-serif'; ctx.fillText(d.toFixed(2) + ' m', s[0] + 10, s[1] - 10);
    }
  } else {
    // manere pentru forma activa
    const p = getActive();
    p.forEach((q, i) => {
      const s = toS(q), m = toS(mul(add(q, p[(i + 1) % p.length]), 0.5));
      ctx.fillStyle = '#ff6a00'; ctx.beginPath(); ctx.arc(s[0], s[1], 6, 0, 7); ctx.fill();
      ctx.fillStyle = '#0b0d10'; ctx.font = 'bold 9px Segoe UI, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(L(i), s[0], s[1] + 0.5);
      ctx.strokeStyle = '#ff6a00'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(m[0], m[1], 5, 0, 7); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(m[0] - 3, m[1]); ctx.lineTo(m[0] + 3, m[1]); ctx.moveTo(m[0], m[1] - 3); ctx.lineTo(m[0], m[1] + 3); ctx.stroke();
    });
    ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
  }
  if (result) drawCameras();
  if (selCam >= 0 && !camMove && !camDrag) placePop();
  cv.style.cursor = camMove ? 'move' : '';
}

let labelHits = [];
function drawLabels(p, id, color) {
  const act = active === id;
  const P = ccw(p), flipped = P !== p;
  ctx.font = (act ? 'bold ' : '') + '12px Segoe UI, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  for (let i = 0; i < p.length; i++) {
    const a = p[i], b = p[(i + 1) % p.length], d = len(sub(b, a));
    if (d < 0.3) continue;
    let n = norm([b[1] - a[1], -(b[0] - a[0])]); if (flipped) n = mul(n, -1);   // normala exterioara
    let bw = 0, bh = 0;
    if (p !== land) { const xs = p.map(q => q[0]), ys = p.map(q => q[1]); bw = Math.max(...xs) - Math.min(...xs); bh = Math.max(...ys) - Math.min(...ys); }
    const outside = p === land || Math.min(bw, bh) * view.s < 120;     // constructiile mici: etichete in afara
    const off = (p === land ? 14 : outside ? -13 : 24) / view.s;
    const m = toS(add(mul(add(a, b), 0.5), mul(n, p === land ? off : -off)));
    const txt = d.toFixed(2).replace(/\.?0+$/, '') + ' m';
    const w = ctx.measureText(txt).width + 8;
    ctx.fillStyle = act ? 'rgba(11,13,16,.85)' : 'rgba(11,13,16,.6)';
    ctx.fillRect(m[0] - w / 2, m[1] - 8, w, 16);
    ctx.fillStyle = act ? color : '#8e969f'; ctx.fillText(txt, m[0], m[1]);
    labelHits.push({ poly: id, i, x: m[0], y: m[1], w, h: 16 });
  }
  ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
}

// ---------- interactiune ----------
let drag = null, hover = null;
function evPos(e) { const r = cv.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }
function snap(w, poly, idx) {
  let x = Math.round(w[0] * 10) / 10, y = Math.round(w[1] * 10) / 10;
  const tol = 8 / view.s;
  if (poly) {        // aliniere cu colturile vecine => unghiuri drepte usor
    const n = poly.length, nb = [poly[(idx + n - 1) % n], poly[(idx + 1) % n]];
    for (const q of nb) { if (Math.abs(q[0] - x) < tol) x = q[0]; if (Math.abs(q[1] - y) < tol) y = q[1]; }
  } else if (drawing && drawing.length) {
    const q = drawing[drawing.length - 1]; if (Math.abs(q[0] - x) < tol) x = q[0]; if (Math.abs(q[1] - y) < tol) y = q[1];
  }
  return [x, y];
}
function getActive() { return active === 'land' ? land : buildings[active].poly; }
function setActive(p) { if (active === 'land') land = p; else buildings[active].poly = p; }
// punct pentru eticheta: centroidul daca e in interior, altfel mijlocul celui mai lung segment orizontal
function labelPoint(p) {
  const c = centroid(p); if (inside(c, p)) return c;
  let best = c, bl = -1;
  for (let i = 0; i < p.length; i++) {
    const y = (p[i][1] + p[(i + 1) % p.length][1]) / 2, xs = [];
    for (let j = 0; j < p.length; j++) { const a = p[j], b = p[(j + 1) % p.length]; if ((a[1] > y) !== (b[1] > y)) xs.push(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1])); }
    xs.sort((u, v) => u - v);
    for (let k = 0; k + 1 < xs.length; k += 2) if (xs[k + 1] - xs[k] > bl) { bl = xs[k + 1] - xs[k]; best = [(xs[k] + xs[k + 1]) / 2, y]; }
  }
  return best;
}

cv.addEventListener('pointerdown', e => {
  const [sx, sy] = evPos(e);
  if (result && !drawing) {
    if (camMove) { camDrag = { ci: camMove.ci, moved: true }; moveCamTo(toW(sx, sy)); cv.setPointerCapture(e.pointerId); return; }
    const ci = hitCam(sx, sy);
    if (ci >= 0) { camDrag = { ci, sx, sy, moved: false }; cv.setPointerCapture(e.pointerId); return; }
    if (selCam >= 0) { closeCam(); return; }
  }
  if (drawing) {
    const w = snap(toW(sx, sy));
    if (drawing.length >= 3) { const f = toS(drawing[0]); if (Math.hypot(f[0] - sx, f[1] - sy) < 12) { finishDraw(); return; } }
    drawing.push(w); draw(); return;
  }
  const lh = labelHits.find(h => h.poly === active && Math.abs(sx - h.x) < h.w / 2 && Math.abs(sy - h.y) < h.h / 2);
  const p = getActive();
  for (let i = 0; i < p.length; i++) {
    const s = toS(p[i]); if (Math.hypot(s[0] - sx, s[1] - sy) < 12) { drag = { type: 'v', i }; cv.setPointerCapture(e.pointerId); return; }
  }
  for (let i = 0; i < p.length; i++) {
    const m = toS(mul(add(p[i], p[(i + 1) % p.length]), 0.5));
    if (Math.hypot(m[0] - sx, m[1] - sy) < 10) {
      const np = p.slice(); np.splice(i + 1, 0, mul(add(p[i], p[(i + 1) % p.length]), 0.5).map(r1));
      setActive(np); drag = { type: 'v', i: i + 1 }; invalidate(); cv.setPointerCapture(e.pointerId); return;
    }
  }
  if (lh) { openSides(); const inp = document.querySelector(`#sides input[data-i="${lh.i}"]`); if (inp) { inp.focus(); inp.select(); } return; }
  const w = toW(sx, sy);
  if (inside(w, p)) { drag = { type: 'move', start: w, orig: p.map(q => q.slice()) }; cv.setPointerCapture(e.pointerId); return; }
  // click in alta forma => o activeaza (constructiile au prioritate fata de teren)
  const hit = buildings.findIndex(b => inside(w, b.poly));
  if (hit >= 0) selectTab(hit); else if (active !== 'land' && inside(w, land)) selectTab('land');
});
cv.addEventListener('pointermove', e => {
  const [sx, sy] = evPos(e);
  if (result && camMove && !camDrag) { moveCamTo(toW(sx, sy)); return; }
  if (result && !drag && !drawing) cv.style.cursor = hitCam(sx, sy) >= 0 ? 'pointer' : '';      // camera urmareste mouse-ul
  if (camDrag) {
    if (!camDrag.moved && Math.hypot(sx - camDrag.sx, sy - camDrag.sy) > 6) { camDrag.moved = true; selCam = camDrag.ci; hidePop(); }
    if (camDrag.moved) moveCamTo(toW(sx, sy));
    return;
  }
  if (drawing) { hover = snap(toW(sx, sy)); draw(); return; }
  if (!drag) return;
  const w = toW(sx, sy), p = getActive();
  if (drag.type === 'v') {
    const np = p.slice(); np[drag.i] = snap(w, p, drag.i); setActive(np);
  } else {
    let dx = Math.round((w[0] - drag.start[0]) * 10) / 10, dy = Math.round((w[1] - drag.start[1]) * 10) / 10;
    setActive(drag.orig.map(q => [r1(q[0] + dx), r1(q[1] + dy)]));
  }
  invalidate(false);
});
function endDrag() {
  if (camDrag) {
    const d = camDrag; camDrag = null;
    if (d.moved) { camMove = null; finishCamEdit(); refreshUI(); openCam(d.ci); }
    else if (selCam === d.ci) closeCam(); else openCam(d.ci);
    return;
  }
  if (drag) { drag = null; fit(); invalidate(); }
}
cv.addEventListener('pointerup', endDrag);
cv.addEventListener('pointercancel', endDrag);
cv.addEventListener('dblclick', () => { if (drawing && drawing.length >= 3) finishDraw(); });

function startDraw() { drawing = []; hover = null; result = null; document.getElementById('btnDone').hidden = false; refreshUI(); draw(); }
function finishDraw() {
  if (drawing.length >= 3) setActive(drawing.map(q => q.slice()));
  drawing = null; hover = null; document.getElementById('btnDone').hidden = true; fit(); invalidate();
}

// orice modificare a formelor invalideaza camerele
function invalidate(full = true) { result = null; closeCam(); save(); if (full) refreshUI(); else { updateTable(true); updateWarn(); } draw(); }

// ---------- panou ----------
function selectTab(t) { active = t; if (drawing) { drawing = null; document.getElementById('btnDone').hidden = true; } refreshUI(); draw(); }
function renderTabs() {
  const el = document.getElementById('tabs'); el.innerHTML = '';
  const mk = (txt, on, fn, cls) => { const b = document.createElement('button'); b.textContent = txt; if (on) b.classList.add('on'); if (cls) b.classList.add(cls); b.onclick = fn; el.appendChild(b); };
  mk('🌳 Teren', active === 'land', () => selectTab('land'));
  buildings.forEach((b, bi) => mk((bi === 0 ? '🏠 ' : '🏚 ') + (b.name || 'Construcție ' + (bi + 1)), active === bi, () => selectTab(bi)));
  mk('＋ Construcție', false, addBuilding, 'add');
  const bo = document.getElementById('bopts'); bo.hidden = active === 'land';
  if (active !== 'land') {
    const b = buildings[active];
    if (document.activeElement !== document.getElementById('bName')) document.getElementById('bName').value = b.name;
    document.getElementById('bCams').checked = b.cams;
    document.getElementById('bDel').disabled = buildings.length <= 1;
  }
}
const NAMES = ['Garaj', 'Magazie', 'Foișor', 'Anexă', 'Șopron', 'Bucătărie de vară', 'Atelier', 'Saună'];
function addBuilding() {
  const used = new Set(buildings.map(b => b.name));
  const name = NAMES.find(n => !used.has(n)) || 'Construcție ' + (buildings.length + 1);
  // cautam un loc liber pe teren pentru o constructie de 5 x 4 m
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of land) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
  let poly = null, bestD = -1;
  for (let y = y0 + 1; y + 4 <= y1 - 1 && true; y += 1) for (let x = x0 + 1; x + 5 <= x1 - 1; x += 1) {
    const cand = rect(x, y, 5, 4);
    if (!polyInside(cand, land) || buildings.some(b => polysOverlap(cand, b.poly))) continue;
    const d = Math.min(...buildings.map(b => Math.min(...cand.map(q => distToPoly(q, b.poly)))));
    const score = Math.min(d, 3) - 0.01 * d;        // aproape de restul, dar cu spatiu intre ele
    if (score > bestD) { bestD = score; poly = cand; }
  }
  if (!poly) { const c = centroid(land); poly = rect(r1(c[0] - 2.5), r1(c[1] - 2), 5, 4); }
  buildings.push({ name, poly, cams: true });
  active = buildings.length - 1; fit(); invalidate();
}
document.getElementById('bName').addEventListener('input', e => { buildings[active].name = e.target.value; save(); renderTabs(); draw(); });
document.getElementById('bCams').addEventListener('change', e => { buildings[active].cams = e.target.checked; invalidate(); });
document.getElementById('bDel').onclick = () => {
  if (active === 'land' || buildings.length <= 1) return;
  buildings.splice(active, 1); active = Math.min(active, buildings.length - 1); fit(); invalidate();
};
document.getElementById('btnDraw').onclick = startDraw;
document.getElementById('btnDone').onclick = () => { if (drawing && drawing.length >= 3) finishDraw(); };
document.getElementById('btnRect').onclick = () => {
  const p = getActive(); const c = centroid(p);
  const sz = active === 0 ? [12, 10] : [5, 4];
  setActive(active === 'land' ? rect(0, 0, 30, 20) : rect(r1(c[0] - sz[0] / 2), r1(c[1] - sz[1] / 2), sz[0], sz[1])); fit(); invalidate();
};
document.getElementById('btnL').onclick = () => {
  const p = getActive(); const c = centroid(p);
  const sz = active === 0 ? [12, 10] : [6, 5];
  setActive(active === 'land' ? lshape(0, 0, 36, 28) : lshape(r1(c[0] - sz[0] / 2), r1(c[1] - sz[1] / 2), sz[0], sz[1])); fit(); invalidate();
};
function centroid(p) { let x = 0, y = 0; p.forEach(q => { x += q[0]; y += q[1]; }); return [x / p.length, y / p.length]; }

const sidesEl = document.getElementById('sides');
function updateTable(valuesOnly) {
  const p = getActive();
  if (valuesOnly && sidesEl.querySelectorAll('input').length === p.length) {
    sidesEl.querySelectorAll('input').forEach((inp, i) => {
      if (document.activeElement !== inp) inp.value = len(sub(p[(i + 1) % p.length], p[i])).toFixed(2);
    });
  } else {
    sidesEl.innerHTML = '';
    p.forEach((q, i) => {
      const tr = document.createElement('tr');
      tr.innerHTML = `<td class="lbl">Latura <b>${L(i)}–${L((i + 1) % p.length)}</b></td>
        <td><input type="number" step="0.1" min="0.1" data-i="${i}" value="${len(sub(p[(i + 1) % p.length], q)).toFixed(2)}"></td>
        <td class="unit">m</td>
        <td><button class="small" title="Șterge colțul ${L(i)}" data-del="${i}">✕</button></td>`;
      sidesEl.appendChild(tr);
    });
    sidesEl.querySelectorAll('input').forEach(inp => {
      const apply = () => {
        const v = parseFloat(inp.value.replace(',', '.'));
        if (v > 0.05) { setActive(setSide(getActive(), +inp.dataset.i, v)); fit(); invalidate(false); }
      };
      inp.addEventListener('change', apply);
      inp.addEventListener('keydown', e => { if (e.key === 'Enter') { apply(); inp.blur(); } });
    });
    sidesEl.querySelectorAll('button[data-del]').forEach(b => b.onclick = () => {
      const p2 = getActive(); if (p2.length <= 3) return;
      const np = p2.slice(); np.splice(+b.dataset.del, 1); setActive(np); fit(); invalidate();
    });
  }
  const a = Math.abs(area(p));
  document.getElementById('areaInfo').textContent =
    `${active === 'land' ? 'Teren' : (buildings[active].name || 'Construcție')}: ${p.length} colțuri · suprafață ${a.toFixed(1)} m²` +
    (active !== 'land' ? '' : ` · liber în jurul construcțiilor ${(a - buildings.reduce((s, b) => s + Math.abs(area(b.poly)), 0)).toFixed(1)} m²`);
}
function problems() {
  const out = [];
  if (selfIntersects(land)) out.push('Laturile terenului se intersectează.');
  buildings.forEach((b, i) => {
    const nm = b.name || 'Construcția ' + (i + 1);
    if (selfIntersects(b.poly)) out.push(`Laturile pentru „${nm}” se intersectează.`);
    if (!polyInside(b.poly, land)) out.push(`„${nm}” trebuie să fie în întregime pe teren.`);
    for (let j = i + 1; j < buildings.length; j++) if (polysOverlap(b.poly, buildings[j].poly)) out.push(`„${nm}” se suprapune cu „${buildings[j].name || 'Construcția ' + (j + 1)}”.`);
  });
  if (!buildings.some(b => b.cams)) out.push('Bifează „camere pe ea” la cel puțin o construcție.');
  return out;
}
function polysOverlap(a, b) {
  if (a.some(p => inside(p, b)) || b.some(p => inside(p, a))) return true;
  for (let i = 0; i < a.length; i++) for (let j = 0; j < b.length; j++)
    if (segX(a[i], a[(i + 1) % a.length], b[j], b[(j + 1) % b.length])) return true;
  return false;
}
function updateWarn() { document.getElementById('warn').innerHTML = problems().join('<br>'); }
function refreshUI() {
  renderTabs();
  updateTable(false); updateWarn();
  document.getElementById('result').hidden = !result;
  document.getElementById('viewBtns').hidden = !result;
  document.getElementById('hint').textContent = drawing
    ? 'Click pentru fiecare colț. Închide forma apăsând pe primul punct (portocaliu), dublu-click sau „Închide forma”.'
    : (active === 'land' ? 'Editezi terenul.' : `Editezi: ${buildings[active].name || 'construcția'}.`) + ' Trage de colțuri, de „+” sau de interior.';
}

// ---------- modal ----------
const modal = document.getElementById('modal');
const mCount = document.getElementById('mCount');
document.getElementById('btnGen').onclick = () => {
  const pr = problems();
  if (pr.length) { alertWarn(pr.join(' ')); return; }
  mCount.value = settings.count; document.getElementById('mFov').value = settings.fov;
  document.getElementById('mRange').value = settings.range; document.getElementById('mNear').checked = settings.near;
  document.getElementById('mProgress').hidden = true; document.getElementById('mActions').hidden = false;
  modal.hidden = false; setTimeout(() => { mCount.focus(); mCount.select(); }, 30);
};
function alertWarn(t) { const w = document.getElementById('warn'); w.textContent = t; w.scrollIntoView({ block: 'nearest' }); }
document.getElementById('mMinus').onclick = () => mCount.value = Math.max(1, (+mCount.value || 1) - 1);
document.getElementById('mPlus').onclick = () => mCount.value = Math.min(20, (+mCount.value || 0) + 1);
document.getElementById('mCancel').onclick = () => { cancelRun = true; modal.hidden = true; };
modal.addEventListener('keydown', e => { if (e.key === 'Enter' && !document.getElementById('mActions').hidden) go(); if (e.key === 'Escape') { cancelRun = true; modal.hidden = true; } });
document.getElementById('mGo').onclick = go;
function syncShow() {
  const d = document.getElementById('btnDirs'), z = document.getElementById('btnZones');
  d.classList.toggle('on', show.dirs); d.textContent = '🔦 Direcții: ' + (show.dirs ? 'afișate' : 'ascunse');
  z.classList.toggle('on', show.zones); z.textContent = '🎨 Zone filmate: ' + (show.zones ? 'afișate' : 'ascunse');
}
document.getElementById('btnDirs').onclick = () => { show.dirs = !show.dirs; syncShow(); save(); draw(); };
document.getElementById('btnZones').onclick = () => { show.zones = !show.zones; syncShow(); save(); draw(); };
document.getElementById('btnClear').onclick = () => { closeCam(); result = null; refreshUI(); draw(); };

let cancelRun = false;
async function go() {
  settings.count = Math.max(1, Math.min(20, Math.round(+mCount.value || 1)));
  settings.fov = Math.max(30, Math.min(360, +document.getElementById('mFov').value || 90));
  settings.range = Math.max(2, Math.min(60, +document.getElementById('mRange').value || 15));
  settings.near = document.getElementById('mNear').checked;
  save();
  document.getElementById('mActions').hidden = true; document.getElementById('mProgress').hidden = false;
  cancelRun = false;
  try {
    const r = await optimize(settings, (f, msg) => {
      document.getElementById('mBar').style.width = Math.round(f * 100) + '%';
      document.getElementById('mThink').textContent = msg;
    });
    if (!r || cancelRun) return;
    closeCam(); result = r; modal.hidden = true; refreshUI(); showResult(); draw();
  } catch (err) {
    document.getElementById('mThink').textContent = 'Eroare: ' + err.message;
    document.getElementById('mActions').hidden = false;
  }
}
const tick = () => new Promise(r => setTimeout(r, 0));

// ---------- optimizare ----------
// Model: terenul (minus casa) e impartit in celule mici. Fiecare "candidat" = o pozitie pe peretele casei
// + o directie (din 5 in 5 grade). Pentru fiecare candidat stim exact ce celule vede (raza, unghi si linia
// de vedere blocata de pereti) sub forma de bitset. Apoi cautam combinatia de N candidati cu acoperire maxima.
// geometria comuna (celule libere, pereti) folosita si de optimizare si de camerele adaugate manual
function buildScene() {
  const B = buildings.map(b => ccw(b.poly)), Ld = land;
  const edges = []; B.forEach(P => P.forEach((p, i) => edges.push([p, P[(i + 1) % P.length]])));
  const NE = edges.length;
  const inAny = p => B.some(P => inside(p, P));
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const p of Ld) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
  const cell = Math.max(0.25, Math.sqrt((x1 - x0) * (y1 - y0) / 14000));
  const cells = [], gidx = [];   // centrele celulelor libere + pozitia lor in grila (pentru desenare)
  const nx = Math.ceil((x1 - x0) / cell), ny = Math.ceil((y1 - y0) / cell);
  for (let gy = 0; gy < ny; gy++) for (let gx = 0; gx < nx; gx++) {
    const p = [x0 + (gx + 0.5) * cell, y0 + (gy + 0.5) * cell];
    if (inside(p, Ld) && !inAny(p)) { cells.push(p); gidx.push(gx + (ny - 1 - gy) * nx); }
  }
  const C = cells.length, WORDS = (C + 31) >>> 5;
  if (!C) throw new Error('nu există teren liber în jurul construcțiilor');
  const camB = B.map((P, bi) => bi).filter(bi => buildings[bi].cams);
  return { B, edges, NE, inAny, x0, y0, x1, y1, cell, cells, gidx, nx, ny, C, WORDS, camB };
}
async function optimize(st, progress) {
  const { B, edges, NE, inAny, x0, y0, cell, cells, gidx, nx, ny, C, WORDS, camB } = buildScene();
  // celule din primii 5 m fata de constructiile pe care se pun camere
  const nearMask = new Uint32Array(WORDS);
  cells.forEach((p, k) => { if (camB.some(bi => distToPoly(p, B[bi]) <= 5)) nearMask[k >>> 5] |= 1 << (k & 31); });

  // pozitii candidate pe perimetrul constructiilor bifate
  const perimAll = camB.reduce((s, bi) => s + B[bi].reduce((t, p, i) => t + len(sub(B[bi][(i + 1) % B[bi].length], p)), 0), 0);
  const spacing = Math.max(0.5, perimAll / 130);
  const positions = [];
  for (const bi of camB) {
  const H = B[bi], n = H.length;
  for (let i = 0; i < n; i++) {
    const a = H[i], b = H[(i + 1) % n], e = sub(b, a), el = len(e), d = norm(e);
    const nOut = [d[1], -d[0]];
    const prev = H[(i + n - 1) % n], dp = norm(sub(a, prev)), nPrev = [dp[1], -dp[0]];
    // coltul a (pe bisectoarea normalelor), apoi puncte de-a lungul laturii
    let cn = norm(add(nOut, nPrev)); let cp = add(a, mul(cn, 0.05));
    if (inside(cp, H)) cp = add(a, mul(cn, -0.05));
    if (!inAny(cp)) positions.push({ p: cp, n: cn, b: bi, wall: i, t: 0, corner: true });
    const k = Math.floor(el / spacing);
    for (let j = 1; j < k; j++) {
      const t = j * el / k;
      const pp = add(add(a, mul(d, t)), mul(nOut, 0.05));
      if (!inAny(pp)) positions.push({ p: pp, n: nOut, b: bi, wall: i, t, corner: false });
    }
  }
  }

  const DIRS = 72, dStep = 2 * Math.PI / DIRS, half = st.fov / 2 * Math.PI / 180, R2 = st.range * st.range;
  const cands = [];   // {pos, dir, bits, cnt}
  for (let pi = 0; pi < positions.length; pi++) {
    if (cancelRun) return null;
    const pos = positions[pi], c = pos.p;
    const visible = [];
    for (let k = 0; k < C; k++) {
      const q = cells[k], dx = q[0] - c[0], dy = q[1] - c[1];
      if (dx * dx + dy * dy > R2) continue;
      let blocked = false;
      for (let w = 0; w < NE; w++) if (segX(c, q, edges[w][0], edges[w][1])) { blocked = true; break; }
      if (!blocked) visible.push(k, Math.atan2(dy, dx));
    }
    const sets = [];
    for (let di = 0; di < DIRS; di++) sets.push(null);
    for (let v = 0; v < visible.length; v += 2) {
      const k = visible[v], ang = visible[v + 1];
      if (half >= Math.PI) break;
      const lo = Math.ceil((ang - half) / dStep), hi = Math.floor((ang + half) / dStep);
      for (let j = lo; j <= hi; j++) { const di = ((j % DIRS) + DIRS) % DIRS; (sets[di] || (sets[di] = new Uint32Array(WORDS)))[k >>> 5] |= 1 << (k & 31); }
    }
    if (half >= Math.PI) {   // 360°: o singura directie e suficienta
      const b = new Uint32Array(WORDS); for (let v = 0; v < visible.length; v += 2) { const k = visible[v]; b[k >>> 5] |= 1 << (k & 31); }
      cands.push({ pos, dir: Math.atan2(pos.n[1], pos.n[0]), bits: b });
    } else {
      for (let di = 0; di < DIRS; di++) if (sets[di]) cands.push({ pos, dir: di * dStep, bits: sets[di] });
    }
    if (pi % 6 === 0) { progress(0.45 * pi / positions.length, `Analizez ce vede fiecare punct de pe pereți… (${pi}/${positions.length})`); await tick(); }
  }
  // scor = celule acoperite (+ bonus pentru zona din jurul casei)
  const nearW = st.near ? 1.5 : 0;
  const score = bits => { let s = 0, sn = 0; for (let w = 0; w < WORDS; w++) { const v = bits[w]; if (v) { s += pc(v); if (nearW) sn += pc(v & nearMask[w]); } } return s + nearW * sn; };
  cands.forEach(c => c.solo = score(c.bits));
  cands.sort((a, b) => b.solo - a.solo);
  const pool = cands.filter(c => c.solo > 0).slice(0, 2500);   // pastram cei mai buni candidati
  const K = Math.min(st.count, pool.length);
  const P = pool.length;

  const unionOf = (sel, skip) => { const u = new Uint32Array(WORDS); sel.forEach((ci, j) => { if (j === skip) return; const b = pool[ci].bits; for (let w = 0; w < WORDS; w++) u[w] |= b[w]; }); return u; };
  const gainScore = (u, b) => { let s = 0, sn = 0; for (let w = 0; w < WORDS; w++) { const v = u[w] | b[w]; if (v) { s += pc(v); if (nearW) sn += pc(v & nearMask[w]); } } return s + nearW * sn; };
  const tooClose = (sel, ci, skip) => sel.some((cj, j) => j !== skip && cj !== undefined && len(sub(pool[cj].pos.p, pool[ci].pos.p)) < 1);

  // 1) greedy
  progress(0.5, 'Aleg camerele una câte una (greedy)…'); await tick();
  let sel = [];
  for (let k = 0; k < K; k++) {
    const u = unionOf(sel, -1); let best = -1, bs = -1;
    for (let ci = 0; ci < P; ci++) { if (tooClose(sel, ci, -1)) continue; const s = gainScore(u, pool[ci].bits); if (s > bs) { bs = s; best = ci; } }
    if (best < 0) break; sel.push(best);
    progress(0.5 + 0.15 * (k + 1) / K, `Camera ${k + 1}/${K} plasată (greedy)…`); await tick();
  }
  const total = s => gainScore(unionOf(s, -1), new Uint32Array(WORDS));
  // 2) cautare locala: inlocuim pe rand cate o camera cu cea mai buna alternativa
  async function localSearch(s, label, deadline) {
    let improved = true, rounds = 0;
    while (improved && rounds < 6 && !(deadline && performance.now() > deadline)) {
      improved = false; rounds++;
      for (let j = 0; j < s.length; j++) {
        if (cancelRun) return s;
        const u = unionOf(s, j), cur = gainScore(u, pool[s[j]].bits);
        let best = s[j], bs = cur;
        for (let ci = 0; ci < P; ci++) { if (tooClose(s, ci, j)) continue; const sc = gainScore(u, pool[ci].bits); if (sc > bs + 1e-9) { bs = sc; best = ci; } }
        if (best !== s[j]) { s[j] = best; improved = true; }
        if (label) { await tick(); }
      }
    }
    return s;
  }
  progress(0.68, 'Optimizez pozițiile (căutare locală)…'); await tick();
  sel = await localSearch(sel.slice(), true);
  let bestSel = sel.slice(), bestScore = total(sel), curSel = sel.slice(), curScore = bestScore;
  // 3) simulated annealing: mutam 1-2 camere la intamplare, re-optimizam local si acceptam uneori si
  //    solutii putin mai slabe (cu probabilitate care scade in timp) ca sa iesim din optimele locale
  const t0 = performance.now(), budget = 3000; let it = 0;
  while (performance.now() - t0 < budget && K > 1) {
    if (cancelRun) return null;
    it++;
    const s = curSel.slice(), m = 1 + (Math.random() < 0.5 ? 1 : 0);
    for (let r = 0; r < m; r++) { const j = Math.floor(Math.random() * K); let ci, tries = 0; do { ci = Math.floor(Math.random() * Math.min(P, 800)); } while (tooClose(s, ci, j) && ++tries < 50); s[j] = ci; }
    await localSearch(s, false, t0 + budget + 800);
    const sc = total(s);
    const T = 0.01 * bestScore * Math.max(0.001, 1 - (performance.now() - t0) / budget);
    if (sc >= curScore || Math.random() < Math.exp((sc - curScore) / T)) { curSel = s; curScore = sc; }
    if (sc > bestScore) { bestScore = sc; bestSel = s.slice(); }
    progress(0.72 + 0.28 * Math.min(1, (performance.now() - t0) / budget), `AI: încerc variante (${it}) · cea mai bună acoperire ${(100 * pcAll(unionOf(bestSel, -1)) / C).toFixed(1)}%`);
    await tick();
  }

  // rezultat
  const cams = bestSel.map(ci => pool[ci]);
  const count = new Uint8Array(C);
  cams.forEach(c => { for (let k = 0; k < C; k++) if (c.bits[k >>> 5] & (1 << (k & 31))) count[k]++; });
  let cov = 0, dbl = 0; for (let k = 0; k < C; k++) { if (count[k]) cov++; if (count[k] > 1) dbl++; }
  const img = makeImage(nx, ny, gidx, cams, count, C);
  return { cells, cell, cams: cams.map(c => ({ pos: c.pos, dir: c.dir, bits: c.bits })), count, C, cov, dbl, st: Object.assign({}, st), img,
           box: [x0, y0, x0 + nx * cell, y0 + ny * cell], nx, ny, gidx, edges, B, WORDS, camB, manual: false };
}
function pc(v) { v = v - ((v >>> 1) & 0x55555555); v = (v & 0x33333333) + ((v >>> 2) & 0x33333333); return (((v + (v >>> 4)) & 0x0F0F0F0F) * 0x01010101) >>> 24; }
function pcAll(b) { let s = 0; for (let i = 0; i < b.length; i++) if (b[i]) s += pc(b[i]); return s; }
function distToPoly(p, poly) {
  let m = Infinity;
  for (let i = 0; i < poly.length; i++) {
    const a = poly[i], b = poly[(i + 1) % poly.length], ab = sub(b, a);
    const t = Math.max(0, Math.min(1, dot(sub(p, a), ab) / (dot(ab, ab) || 1)));
    m = Math.min(m, len(sub(p, add(a, mul(ab, t)))));
  }
  return m;
}

// ---------- desenare rezultat ----------
// o imagine cu un pixel per celula: culoarea camerei (amestec daca sunt mai multe) sau rosu daca e nefilmata
function makeImage(nx, ny, gidx, cams, count, C) {
  const c = document.createElement('canvas'); c.width = nx; c.height = ny;
  const g = c.getContext('2d'), im = g.createImageData(nx, ny), d = im.data;
  const rgb = cams.map((_, i) => { const n = parseInt(COLORS[i % COLORS.length].slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; });
  for (let k = 0; k < C; k++) {
    const o = gidx[k] * 4;
    if (!count[k]) { d[o] = 255; d[o + 1] = 70; d[o + 2] = 70; d[o + 3] = 70; continue; }
    let r = 0, gg = 0, b = 0;
    cams.forEach((cm, i) => { if (cm.bits[k >>> 5] & (1 << (k & 31))) { r += rgb[i][0]; gg += rgb[i][1]; b += rgb[i][2]; } });
    d[o] = r / count[k]; d[o + 1] = gg / count[k]; d[o + 2] = b / count[k]; d[o + 3] = count[k] > 1 ? 150 : 105;
  }
  g.putImageData(im, 0, 0); return c;
}
function drawCoverage() {
  const r = result, a = toS([r.box[0], r.box[3]]), b = toS([r.box[2], r.box[1]]);
  ctx.save(); pathPoly(land); ctx.clip();
  ctx.imageSmoothingEnabled = false; ctx.drawImage(r.img, a[0], a[1], b[0] - a[0], b[1] - a[1]);
  ctx.restore();
}
function drawCameras() {
  const r = result, half = r.st.fov / 2 * Math.PI / 180;
  r.cams.forEach((c, ci) => {
    const col = COLORS[ci % COLORS.length], p = toS(c.pos.p);
    // conturul unghiului de vedere
    if (show.dirs && half < Math.PI) {
      const R = r.st.range * view.s;
      ctx.strokeStyle = hexA(col, 0.7); ctx.lineWidth = 1.2; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.arc(p[0], p[1], R, -c.dir - half, -c.dir + half); ctx.closePath(); ctx.stroke();
      ctx.setLineDash([]);
    }
    if (ci === selCam) { ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(p[0], p[1], 14, 0, 7); ctx.stroke(); }
    ctx.fillStyle = col; ctx.strokeStyle = '#0b0d10'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(p[0], p[1], 9, 0, 7); ctx.fill(); ctx.stroke();
    if (show.dirs && half < Math.PI) {
      const tip = [p[0] + Math.cos(-c.dir) * 17, p[1] + Math.sin(-c.dir) * 17];
      ctx.strokeStyle = col; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(tip[0], tip[1]); ctx.stroke();
    }
    ctx.fillStyle = '#0b0d10'; ctx.font = 'bold 11px Segoe UI, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(ci + 1, p[0], p[1] + 0.5); ctx.textAlign = 'start'; ctx.textBaseline = 'alphabetic';
  });
}
function hexA(h, a) { const n = parseInt(h.slice(1), 16); return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`; }

// ---------- tabelul de laturi: spoiler pe desktop, popup (bottom sheet) pe telefon ----------
const sidesBox = document.getElementById('sidesBox'), sidesDet = document.getElementById('sidesDet');
const sheetBg = document.getElementById('sheetBg'), mobileQ = window.matchMedia('(max-width: 860px)');
try { if (localStorage.getItem('camere.sidesOpen') === '1') sidesDet.open = true; } catch (e) {}
sidesDet.addEventListener('toggle', () => { try { localStorage.setItem('camere.sidesOpen', sidesDet.open ? '1' : '0'); } catch (e) {} });
function sidesTitle() { return '📏 Laturi: ' + (active === 'land' ? 'Teren' : (buildings[active].name || 'Construcție')); }
function openSides() {
  if (!mobileQ.matches) { sidesDet.open = true; return; }
  document.getElementById('sheetTitle').textContent = sidesTitle();
  document.getElementById('sheet').appendChild(sidesBox); sheetBg.hidden = false;
}
function closeSheet() { if (sheetBg.hidden) return; sheetBg.hidden = true; sidesDet.appendChild(sidesBox); }
document.getElementById('fabSides').onclick = openSides;
document.getElementById('sheetClose').onclick = closeSheet;
sheetBg.addEventListener('click', e => { if (e.target === sheetBg) closeSheet(); });
mobileQ.addEventListener('change', closeSheet);

// ---------- editare manuala a camerelor ----------
let selCam = -1, camMove = null, camDrag = null;
const pop = document.getElementById('campop');
function hitCam(sx, sy) {
  if (!result) return -1;
  for (let i = result.cams.length - 1; i >= 0; i--) { const p = toS(result.cams[i].pos.p); if (Math.hypot(p[0] - sx, p[1] - sy) < 13) return i; }
  return -1;
}
function openCam(ci) { selCam = ci; camMove = null; placePop(); draw(); }
function closeCam() { selCam = -1; camMove = null; camDrag = null; hidePop(); if (typeof cv !== 'undefined') cv.style.cursor = ''; }
function hidePop() { pop.hidden = true; }
function placePop() {
  if (selCam < 0 || !result) { hidePop(); return; }
  const c = result.cams[selCam], p = toS(c.pos.p);
  pop.hidden = false;
  const w = pop.offsetWidth, h = pop.offsetHeight;
  let x = Math.max(w / 2 + 4, Math.min(W - w / 2 - 4, p[0])), y = p[1] + 18;
  if (y + h > H - 4) y = p[1] - 18 - h;
  pop.style.left = x + 'px'; pop.style.top = y + 'px';
  const deg = ((c.dir * 180 / Math.PI) % 360 + 360) % 360;
  document.getElementById('cpDeg').textContent = result.st.fov >= 360 ? '360°' : deg.toFixed(0) + '°';
  document.getElementById('cpMove').classList.toggle('on', !!camMove);
}
// cel mai apropiat punct de pe peretii constructiilor cu camere (cu mic decalaj spre exterior)
function snapToWall(w) {
  const r = result; let best = null, bd = Infinity;
  for (const bi of r.camB) {
    const P = r.B[bi], n = P.length;
    for (let i = 0; i < n; i++) {
      const a = P[i], b = P[(i + 1) % n], ab = sub(b, a), el = len(ab);
      const t = Math.max(0, Math.min(el, dot(sub(w, a), ab) / (el || 1)));
      const q = add(a, mul(ab, t / (el || 1))), d = len(sub(w, q));
      if (d < bd) { bd = d; best = { bi, i, t, el, a, b }; }
    }
  }
  if (!best) return null;
  const P = r.B[best.bi], n = P.length, d = norm(sub(best.b, best.a)), nOut = [d[1], -d[0]];
  const cornerTol = Math.max(0.25, 10 / view.s);
  let i = best.i, t = best.t, corner = false;
  if (t > best.el - cornerTol) { i = (i + 1) % n; t = 0; }
  if (t < cornerTol) corner = true;
  const inAny = p => r.B.some(Q => inside(p, Q));
  let pos;
  if (corner) {
    const a = P[i], e = norm(sub(P[(i + 1) % n], a)), dp = norm(sub(a, P[(i + n - 1) % n]));
    const cn = norm(add([e[1], -e[0]], [dp[1], -dp[0]]));
    let cp = add(a, mul(cn, 0.05)); if (inside(cp, P)) cp = add(a, mul(cn, -0.05));
    pos = { p: cp, n: cn, b: best.bi, wall: i, t: 0, corner: true };
  } else {
    pos = { p: add(add(best.a, mul(d, t)), mul(nOut, 0.05)), n: nOut, b: best.bi, wall: best.i, t, corner: false };
  }
  return inAny(pos.p) ? null : pos;
}
// ce vede o camera (aceeasi regula ca la optimizare: raza, unghi, pereti care blocheaza)
function camBits(pos, dir) {
  const r = result, c = pos.p, R2 = r.st.range * r.st.range, half = r.st.fov / 2 * Math.PI / 180;
  const bits = new Uint32Array(r.WORDS), E = r.edges, NE = E.length;
  for (let k = 0; k < r.C; k++) {
    const q = r.cells[k], dx = q[0] - c[0], dy = q[1] - c[1];
    if (dx * dx + dy * dy > R2) continue;
    if (half < Math.PI) { let da = Math.atan2(dy, dx) - dir; da = Math.atan2(Math.sin(da), Math.cos(da)); if (Math.abs(da) > half) continue; }
    let blocked = false;
    for (let w = 0; w < NE; w++) if (segX(c, q, E[w][0], E[w][1])) { blocked = true; break; }
    if (!blocked) bits[k >>> 5] |= 1 << (k & 31);
  }
  return bits;
}
function moveCamTo(w) {
  const c = result.cams[camDrag ? camDrag.ci : camMove.ci], pos = snapToWall(w);
  if (!pos) return;
  // camera mutata priveste drept in fata peretelui (sau pe bisectoare, in colturi); apoi se poate roti
  c.pos = pos; c.dir = Math.atan2(pos.n[1], pos.n[0]);
  c.bits = camBits(c.pos, c.dir); refreshCoverage(false); draw();
}
function rotateCam(deltaDeg) {
  if (selCam < 0 || result.st.fov >= 360) return;
  const c = result.cams[selCam]; c.dir += deltaDeg * Math.PI / 180;
  c.bits = camBits(c.pos, c.dir); finishCamEdit(); placePop();
}
function finishCamEdit() { refreshCoverage(true); draw(); }
function refreshCoverage(full) {
  const r = result; r.manual = true;
  r.count = new Uint8Array(r.C);
  r.cams.forEach(c => { for (let k = 0; k < r.C; k++) if (c.bits[k >>> 5] & (1 << (k & 31))) r.count[k]++; });
  r.cov = 0; r.dbl = 0; for (let k = 0; k < r.C; k++) { if (r.count[k]) r.cov++; if (r.count[k] > 1) r.dbl++; }
  r.img = makeImage(r.nx, r.ny, r.gidx, r.cams, r.count, r.C);
  if (full) showResult(); else { const cellA = r.cell * r.cell; document.getElementById('stPct').textContent = (100 * r.cov / r.C).toFixed(1) + '%'; document.getElementById('stArea').textContent = (r.cov * cellA).toFixed(0) + ' / ' + (r.C * cellA).toFixed(0) + ' m²'; }
}
document.getElementById('cpMove').onclick = () => {
  if (selCam < 0) return;
  camMove = camMove ? null : { ci: selCam };
  if (camMove) { hidePop(); document.getElementById('hint').textContent = 'Mișcă mouse-ul (sau trage cu degetul) de-a lungul pereților și dă click ca să fixezi camera. Esc oprește mutarea.'; }
};
function holdRepeat(btn, fn) {
  let t1 = null, t2 = null;
  const stop = () => { clearTimeout(t1); clearInterval(t2); t1 = t2 = null; };
  btn.addEventListener('pointerdown', e => { e.preventDefault(); fn(); t1 = setTimeout(() => { t2 = setInterval(fn, 70); }, 350); });
  ['pointerup', 'pointerleave', 'pointercancel'].forEach(ev => btn.addEventListener(ev, stop));
}
holdRepeat(document.getElementById('cpLeft'), () => rotateCam(5));     // stanga = sens trigonometric (harta are nordul sus)
holdRepeat(document.getElementById('cpRight'), () => rotateCam(-5));
document.getElementById('cpClose').onclick = () => { closeCam(); draw(); };
document.getElementById('cpDel').onclick = () => {
  if (selCam < 0) return;
  result.cams.splice(selCam, 1); closeCam(); refreshCoverage(true); refreshUI(); draw();
};
// camera noua: apare pe un perete si urmareste mouse-ul / degetul pana o asezi
document.getElementById('btnAddCam').onclick = () => {
  const pr = problems();
  if (pr.length) { alertWarn(pr.join(' ')); return; }
  if (drawing) return;
  if (!result) {
    let S; try { S = buildScene(); } catch (e) { alertWarn(e.message); return; }
    result = { cells: S.cells, cell: S.cell, cams: [], count: new Uint8Array(S.C), C: S.C, cov: 0, dbl: 0, st: Object.assign({}, settings),
               img: null, box: [S.x0, S.y0, S.x0 + S.nx * S.cell, S.y0 + S.ny * S.cell], nx: S.nx, ny: S.ny, gidx: S.gidx,
               edges: S.edges, B: S.B, WORDS: S.WORDS, camB: S.camB, manual: true };
  }
  if (result.cams.length >= 20) { alertWarn('Maxim 20 de camere.'); return; }
  const bi = result.camB[0], pos = snapToWall(labelPoint(result.B[bi]));
  if (!pos) return;
  result.cams.push({ pos, dir: Math.atan2(pos.n[1], pos.n[0]), bits: new Uint32Array(result.WORDS) });
  const c = result.cams[result.cams.length - 1]; c.bits = camBits(c.pos, c.dir);
  closeCam(); refreshCoverage(true); refreshUI();
  selCam = result.cams.length - 1; camMove = { ci: selCam };
  document.getElementById('hint').textContent = 'Așază camera nouă: mișcă mouse-ul (sau trage cu degetul) de-a lungul pereților și dă click. Apoi o poți roti.';
  if (mobileQ.matches) document.getElementById('stage').scrollIntoView({ behavior: 'smooth', block: 'center' });
  draw();
};
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && (selCam >= 0 || camMove)) { closeCam(); refreshUI(); draw(); }
  if (selCam >= 0 && !camMove && (e.key === 'ArrowLeft' || e.key === 'ArrowRight') && document.activeElement.tagName !== 'INPUT') { e.preventDefault(); rotateCam(e.key === 'ArrowLeft' ? 5 : -5); }
});

function showResult() {
  const r = result, cellA = r.cell * r.cell;
  document.getElementById('stPct').textContent = (100 * r.cov / r.C).toFixed(1) + '%';
  document.getElementById('stArea').textContent = (r.cov * cellA).toFixed(0) + ' / ' + (r.C * cellA).toFixed(0) + ' m²';
  document.getElementById('stDouble').textContent = (r.dbl * cellA).toFixed(0) + ' m²';
  document.getElementById('stCam').textContent = r.st.fov + '° · ' + r.st.range + ' m';
  document.getElementById('stPct').textContent += r.manual ? ' ✋' : '';
  document.getElementById('stPct').title = r.manual ? 'Camerele au fost ajustate manual' : '';
  const ul = document.getElementById('camlist'); ul.innerHTML = '';
  // numele colturilor sunt cele din tabel (poligonul original, nu cel reorientat)
  const dirs = ['E', 'NE', 'N', 'NV', 'V', 'SV', 'S', 'SE'];
  r.cams.forEach((c, ci) => {
    const orig = buildings[c.pos.b].poly, flipped = ccw(orig) !== orig, n = orig.length;
    const bn = buildings.length > 1 ? `pe ${buildings[c.pos.b].name || 'construcția ' + (c.pos.b + 1)}, ` : '';
    let wa = c.pos.wall, wb = (wa + 1) % n, t = c.pos.t;
    // pozitia pe casa in termeni de colturi din tabel
    let where;
    const ia = flipped ? (n - 1 - wa) : wa, ib = flipped ? (n - 1 - wb) : wb;
    if (c.pos.corner) where = `în colțul ${L(ia)}`;
    else where = `pe latura ${L(Math.min(ia, ib) === 0 && Math.max(ia, ib) === n - 1 ? n - 1 : Math.min(ia, ib))}–${L(Math.min(ia, ib) === 0 && Math.max(ia, ib) === n - 1 ? 0 : Math.max(ia, ib))}, la ${t.toFixed(1)} m de ${L(ia)}`;
    const deg = ((c.dir * 180 / Math.PI) % 360 + 360) % 360;
    const li = document.createElement('li');
    li.innerHTML = `<span class="dot" style="background:${COLORS[ci % COLORS.length]}"></span>
      <span><b>Camera ${ci + 1}</b> ${bn}${where}${r.st.fov < 360 ? `, orientată spre ${dirs[Math.round(deg / 45) % 8]} (${deg.toFixed(0)}°)` : ''}</span>`;
    ul.appendChild(li);
  });
}

syncShow();
refreshUI();
resize();
})();
</script>
</body>
</html>
