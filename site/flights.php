<?php
// Flights: alegi o tara si scrii un text; un avion decoleaza de pe aeroportul principal al tarii (cel de
// langa capitala) si "scrie" textul in aer, ca desenele facute de avioane pe Flightradar24.
// Harta: Leaflet + placi OpenStreetMap intunecate din CSS (fara chei API; CARTO cere acum cheie). Datele (aeroporturi + fontul de linii Hershey)
// sunt in flights/data.json, generat de flights/build_data.py. Totul ruleaza in browser.
header('Cache-Control: no-cache, must-revalidate');
$dataVer = @filemtime(__DIR__ . '/flights/data.json') ?: 1;
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title>Flights · scrie pe cer</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  :root {
    --bg: #0e1116; --panel: rgba(18, 22, 28, .92); --ink: #eef1f5; --ink-2: #9aa3ad; --line: #2b323b;
    --plane: #ffc400; --trail: #ffb000; --move: #6c8fb3; --accent: #ffc400;
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--ink); }
  body { font-family: system-ui, "Segoe UI", Roboto, sans-serif; font-size: 14px; overflow: hidden; }
  #map { position: fixed; inset: 0; background: #0b0d10; }
  .leaflet-container { background: #0b0d10; font: inherit; }
  .dark-tiles { filter: invert(1) hue-rotate(180deg) brightness(.82) contrast(.88) saturate(.35); }
  .leaflet-control-attribution { background: rgba(0,0,0,.55) !important; color: #8a939c !important; font-size: 10px; }
  .leaflet-control-attribution a { color: #b3bcc6 !important; }

  .panel {
    position: fixed; z-index: 1000; left: 12px; top: 12px; width: 340px; max-width: calc(100vw - 24px);
    background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 12px;
    box-shadow: 0 6px 24px rgba(0,0,0,.45); backdrop-filter: blur(6px);
  }
  .panel h1 { margin: 0 0 8px; font-size: 15px; font-weight: 600; letter-spacing: .02em; display: flex; align-items: center; gap: 8px; }
  .panel h1 svg { width: 18px; height: 18px; fill: var(--plane); }
  .panel h1 .toggle { margin-left: auto; }
  .panel label { display: block; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--ink-2); margin: 8px 0 4px; }
  .panel select, .panel input[type=text] {
    width: 100%; font: inherit; font-size: 16px; color: var(--ink); background: #0b0e12; border: 1px solid var(--line);
    border-radius: 8px; padding: 8px 10px;
  }
  .panel select:focus, .panel input:focus { outline: none; border-color: var(--accent); }
  .row { display: flex; gap: 8px; align-items: center; margin-top: 10px; flex-wrap: wrap; }
  button {
    font: inherit; color: var(--ink-2); background: transparent; border: 1px solid var(--line);
    border-radius: 8px; padding: 7px 12px; cursor: pointer;
  }
  button:hover { border-color: var(--accent); color: var(--ink); }
  button.primary { background: var(--accent); border-color: var(--accent); color: #1b1600; font-weight: 600; flex: 1; }
  button.primary:hover { filter: brightness(1.08); color: #1b1600; }
  .seg { display: inline-flex; }
  .seg button { border-radius: 0; padding: 7px 9px; min-width: 38px; }
  .seg button:first-child { border-radius: 8px 0 0 8px; }
  .seg button:last-child { border-radius: 0 8px 8px 0; }
  .seg button + button { margin-left: -1px; }
  .seg button.on { background: #2a3038; color: var(--ink); border-color: #4a535e; }
  .check { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--ink-2); cursor: pointer; user-select: none; }
  .check input { accent-color: var(--accent); }
  .toggle { padding: 2px 8px; font-size: 12px; }
  .panel.min .body { display: none; }
  .panel label.check { display: flex; margin: 0; font-size: 12px; text-transform: none; letter-spacing: 0; }

  .info {
    position: fixed; z-index: 1000; left: 50%; transform: translateX(-50%); bottom: 22px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 8px 14px;
    display: flex; gap: 18px; align-items: center; white-space: nowrap; box-shadow: 0 6px 24px rgba(0,0,0,.45);
    font-variant-numeric: tabular-nums;
  }
  .info .cs { font-weight: 700; color: var(--plane); font-size: 15px; }
  .info .route { font-size: 12px; color: var(--ink-2); }
  .info .k { font-size: 10px; text-transform: uppercase; letter-spacing: .06em; color: var(--ink-2); }
  .info .v { font-size: 14px; }
  .info .bar { position: absolute; left: 12px; right: 12px; bottom: 3px; height: 2px; background: #252b33; border-radius: 2px; overflow: hidden; }
  .info .bar i { display: block; height: 100%; width: 0; background: var(--plane); }
  .msg { font-size: 12px; color: #ff9a8a; margin-top: 6px; min-height: 0; }

  .plane-icon { width: 34px; height: 34px; }
  .plane-icon svg { width: 34px; height: 34px; display: block; filter: drop-shadow(0 1px 2px rgba(0,0,0,.8)); transform-origin: 50% 50%; }
  .apt-icon { width: 12px; height: 12px; border-radius: 50%; background: #0b0d10; border: 2px solid var(--plane); }
  .apt-label { background: rgba(0,0,0,.65); border: 0; color: var(--ink); box-shadow: none; font-weight: 600; padding: 2px 6px; }
  .apt-label::before { display: none; }

  @media (max-width: 600px) {
    .panel { left: 8px; right: 8px; top: 8px; width: auto; max-width: none; padding: 10px; }
    .panel label { margin-top: 6px; }
    .grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .info { left: 8px; right: 8px; transform: none; bottom: calc(14px + env(safe-area-inset-bottom)); gap: 10px; justify-content: space-between; padding: 7px 10px; }
    .info .route { display: none; }
    .info .v { font-size: 13px; }
    .leaflet-bottom.leaflet-right { bottom: calc(76px + env(safe-area-inset-bottom)); }
  }
</style>
</head>
<body>
<div id="map" role="application" aria-label="Harta zborului"></div>

<div class="panel" id="panel">
  <h1>
    <svg viewBox="0 0 64 64" aria-hidden="true"><path d="M32 2c2.2 0 3.6 2.6 3.6 6v14l22 13v6l-22-6.5V47l7 5v5l-10.6-3L32 58l-0.4-4L21 57v-5l7-5V34.5L6 41v-6l22-13V8c0-3.4 1.8-6 4-6z"/></svg>
    Scrie pe cer
    <button class="toggle" id="toggle" type="button" aria-expanded="true">−</button>
  </h1>
  <div class="body">
    <div class="grid2">
      <div>
        <label for="country">Țara</label>
        <select id="country"></select>
      </div>
      <div>
        <label for="airport">Aeroport</label>
        <select id="airport"></select>
      </div>
    </div>
    <label for="text">Textul</label>
    <input type="text" id="text" maxlength="40" value="SALUT" autocomplete="off" enterkeyhint="go">
    <div class="row">
      <button class="primary" id="go" type="button">Decolează</button>
      <span class="seg" id="speed" aria-label="Viteză">
        <button type="button" data-v="1">1×</button><button type="button" data-v="2" class="on">2×</button><button type="button" data-v="5">5×</button><button type="button" data-v="20">20×</button>
      </span>
    </div>
    <div class="row">
      <label class="check"><input type="checkbox" id="showMoves" checked> Arată și traseul dintre litere</label>
      <label class="check"><input type="checkbox" id="follow"> Urmărește avionul</label>
    </div>
    <div class="msg" id="msg"></div>
  </div>
</div>

<div class="info" id="info" hidden>
  <div><div class="cs" id="callsign">NOS1</div><div class="route" id="route"></div></div>
  <div><div class="k">Altitudine</div><div class="v" id="alt">0 ft</div></div>
  <div><div class="k">Viteză</div><div class="v" id="spd">0 kt</div></div>
  <div><div class="k">Distanță</div><div class="v" id="dist">0 km</div></div>
  <div class="bar"><i id="bar"></i></div>
</div>

<script>
(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const msg = t => { $('msg').textContent = t || ''; };
  if (!window.L) { msg('Harta nu s-a putut încărca (verifică conexiunea).'); return; }

  // ---------- harta ----------
  const map = L.map('map', { zoomControl: false, worldCopyJump: true, minZoom: 2 }).setView([45.9, 24.9], 5);
  L.control.zoom({ position: 'bottomright' }).addTo(map);
  // Plăcile standard OpenStreetMap (fără cheie), făcute întunecate din CSS (.dark-tiles).
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19, className: 'dark-tiles',
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> · aeroporturi: <a href="https://ourairports.com/">OurAirports</a>'
  }).addTo(map);

  const PLANE_SVG = '<svg viewBox="0 0 64 64"><path fill="#ffc400" stroke="#2a2000" stroke-width="2" stroke-linejoin="round" d="M32 2c2.2 0 3.6 2.6 3.6 6v14l22 13v6l-22-6.5V47l7 5v5l-10.6-3L32 58l-0.4-4L21 57v-5l7-5V34.5L6 41v-6l22-13V8c0-3.4 1.8-6 4-6z"/></svg>';

  const moveLine = L.polyline([], { color: '#6c8fb3', weight: 1.5, opacity: .55, dashArray: '4 6', interactive: false }).addTo(map);
  const glowLine = L.polyline([], { color: '#ffb000', weight: 9, opacity: .18, lineCap: 'round', lineJoin: 'round', interactive: false }).addTo(map);
  const inkLine = L.polyline([], { color: '#ffc21a', weight: 3.2, opacity: .95, lineCap: 'round', lineJoin: 'round', interactive: false }).addTo(map);
  let planeMarker = null, aptMarker = null;

  // ---------- date ----------
  let DATA = null;
  const regionNames = (() => { try { return new Intl.DisplayNames(['ro'], { type: 'region' }); } catch (e) { return null; } })();
  const countryName = cc => { try { return (regionNames && regionNames.of(cc)) || cc; } catch (e) { return cc; } };

  // ---------- font de linii (Hershey Roman Simplex) + diacritice romanesti ----------
  // Coordonate font: x la dreapta, y in jos; linia de baza y=9, majusculele urca la y=-12.
  function glyphFor(ch) {
    const F = DATA.font;
    const extra = { 'ă': ['a', 'breve', -9], 'Ă': ['A', 'breve', -16], 'â': ['a', 'circ', -9], 'Â': ['A', 'circ', -16],
      'î': ['ı', 'circ', -9], 'Î': ['I', 'circ', -16], 'ș': ['s', 'comma'], 'ş': ['s', 'comma'], 'Ș': ['S', 'comma'], 'Ş': ['S', 'comma'],
      'ț': ['t', 'comma'], 'ţ': ['t', 'comma'], 'Ț': ['T', 'comma'], 'Ţ': ['T', 'comma'] };
    if (extra[ch]) {
      const [b, kind, top] = extra[ch];
      let g;
      if (b === 'ı') { // i fara punct: doar cea mai lunga linie din "i"
        const gi = F.i; let best = gi.s[0];
        gi.s.forEach(s => { if (s.length > best.length || Math.abs(s[s.length - 1][1] - s[0][1]) > Math.abs(best[best.length - 1][1] - best[0][1])) best = s; });
        g = { w: gi.w, s: [best] };
      } else g = F[b];
      const cx = g.w / 2;
      let acc;
      if (kind === 'breve') acc = [[cx - 3.5, top - 2], [cx - 2.5, top], [cx, top + 1], [cx + 2.5, top], [cx + 3.5, top - 2]];
      else if (kind === 'circ') acc = [[cx - 3.5, top + 1], [cx, top - 2.5], [cx + 3.5, top + 1]];
      else acc = [[cx + 0.6, 11.5], [cx, 13.5], [cx - 1.2, 15]];
      return { w: g.w, s: g.s.concat([acc]) };
    }
    if (F[ch]) return F[ch];
    const base = ch.normalize('NFD').replace(/[̀-ͯ]/g, '');
    if (F[base]) return F[base];
    return F['?'];
  }

  // Imparte textul pe randuri astfel incat dreptunghiul lui sa semene cu forma ecranului.
  function layoutText(text, aspect) {
    const words = text.trim().split(/\s+/).filter(Boolean);
    const wordW = w => [...w].reduce((s, c) => s + glyphFor(c).w, 0);
    const spaceW = DATA.font[' '].w;
    const LINE_H = 34;
    const total = words.reduce((s, w) => s + wordW(w), 0) + spaceW * (words.length - 1);
    let best = null;
    for (let n = 1; n <= Math.min(words.length, 6); n++) {
      const target = total / n;
      const lines = []; let cur = [], curW = 0;
      words.forEach(w => {
        const ww = wordW(w);
        if (cur.length && curW + spaceW + ww > target * 1.12 && lines.length < n - 1) { lines.push(cur); cur = []; curW = 0; }
        curW += (cur.length ? spaceW : 0) + ww; cur.push(w);
      });
      lines.push(cur);
      const widths = lines.map(l => wordW(l.join('')) + spaceW * (l.length - 1));
      const W = Math.max(...widths), H = lines.length * LINE_H - (LINE_H - 24);
      const score = Math.abs(Math.log((W / H) / aspect));
      if (!best || score < best.score - 0.05) best = { lines, widths, W, H, score };
    }
    // linii (polilinii) in unitati de font, centrate in (0,0); y in jos
    const strokes = [];
    best.lines.forEach((l, li) => {
      let x = -best.widths[li] / 2;
      const yOff = li * LINE_H - best.H / 2 + 14; // 14 ~ distanta de la varful majusculei la linia de baza (-12 -> 0)
      [...l.join(' ')].forEach(c => {
        const g = glyphFor(c);
        g.s.forEach(s => strokes.push(s.map(p => [p[0] + x, p[1] + yOff - 2])));
        x += g.w;
      });
    });
    return { strokes, W: best.W, H: best.H };
  }

  // ---------- planul de zbor ----------
  // Lucram in metri Web Mercator (exact ce deseneaza harta), deci literele apar nedeformate pe ecran.
  const proj = L.Projection.SphericalMercator;
  function buildFlight(apt, text) {
    const size = map.getSize();
    const aspect = Math.max(0.45, Math.min(3.2, size.x / Math.max(1, size.y - (size.x < 600 ? 170 : 120))));
    const lay = layoutText(text, aspect);
    if (!lay.strokes.length) return null;
    const c = proj.project(L.latLng(apt.lat, apt.lon));
    const k = 1 / Math.cos(apt.lat * Math.PI / 180);        // km pe sol -> metri Mercator
    // marimea: ~110 km inaltimea unei majuscule, dar textul intreg incape in ~1600 x 1000 km
    let unitKm = 5.2;
    unitKm = Math.min(unitKm, 1600 / lay.W, 1000 / lay.H);
    unitKm = Math.max(unitKm, 1.2);
    const u = unitKm * 1000 * k;
    // textul e asezat langa aeroport, nu peste el: centrul la ~ (jumatate de latime + 80 km) intr-o parte,
    // partea fiind cea spre care e indreptata pista, ca avionul sa intre direct in text dupa decolare.
    const hdg = (apt.hdg == null ? 90 : apt.hdg) * Math.PI / 180;
    const dir = [Math.sin(hdg), Math.cos(hdg)];            // est, nord
    const halfW = lay.W * u / 2, halfH = lay.H * u / 2;
    const reach = Math.min(halfW / Math.max(1e-6, Math.abs(dir[0])), halfH / Math.max(1e-6, Math.abs(dir[1])));
    const off = reach + 90 * 1000 * k;
    const cx = c.x + dir[0] * off, cy = c.y + dir[1] * off;
    const toM = p => [cx + p[0] * u, cy - p[1] * u];
    const ink = lay.strokes.map(s => s.map(toM));

    // drumul complet: decolare pe directia pistei, apoi fiecare litera, apoi aterizare
    const pts = []; // [x, y, pen]  pen=1 desen, 0 deplasare
    const push = (p, pen) => pts.push([p[0], p[1], pen]);
    const A = [c.x, c.y];
    const rw = 25 * 1000 * k;
    const climbOut = [A[0] + dir[0] * rw, A[1] + dir[1] * rw];
    push(A, 0); push(climbOut, 0);
    // curba lina pana la inceputul primei linii
    const curve = (P0, P1, P2, pen) => { for (let i = 1; i <= 16; i++) { const t = i / 16, a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, d = t * t; push([a * P0[0] + b * P1[0] + d * P2[0], a * P0[1] + b * P1[1] + d * P2[1]], pen); } };
    const ctrl = [climbOut[0] + dir[0] * rw * 1.5, climbOut[1] + dir[1] * rw * 1.5];
    curve(climbOut, ctrl, ink[0][0], 0);
    ink.forEach((s, i) => {
      if (i > 0) push(s[0], 0);
      for (let j = 1; j < s.length; j++) push(s[j], 1);
      if (s.length === 1) push(s[0], 1);
    });
    // aterizare: intra pe pista din directia opusa decolarii
    const last = pts[pts.length - 1];
    const finalFix = [A[0] - dir[0] * rw * 1.6, A[1] - dir[1] * rw * 1.6];
    const ctrl2 = [finalFix[0] - dir[0] * rw * 2, finalFix[1] - dir[1] * rw * 2];
    curve([last[0], last[1]], ctrl2, finalFix, 0);
    push(A, 0);

    // distante cumulate, in km reali pe sol
    const cum = [0];
    for (let i = 1; i < pts.length; i++) {
      const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1];
      cum.push(cum[i - 1] + Math.hypot(dx, dy) / k / 1000);
    }
    const toLL = p => proj.unproject(L.point(p[0], p[1]));
    let inkKm = 0; for (let i = 1; i < pts.length; i++) if (pts[i][2]) inkKm += cum[i] - cum[i - 1];
    return { pts, cum, total: cum[cum.length - 1], inkKm, toLL, A, climbKm: rw / k / 1000, landKm: rw * 1.6 / k / 1000 };
  }

  // ---------- animatia ----------
  let flight = null, raf = 0, dist = 0, lastT = 0, speedMul = 2, heading = 0, lastIdx = 0;
  let inkSegs = [], moveSegs = [], curInk = null, curMove = null;

  function resetTrails() {
    inkSegs = []; moveSegs = []; curInk = null; curMove = null;
    inkLine.setLatLngs([]); glowLine.setLatLngs([]); moveLine.setLatLngs([]);
  }

  function addPoint(ll, pen) {
    if (pen) {
      if (!curInk) { curInk = [curMove ? curMove[curMove.length - 1] : ll]; inkSegs.push(curInk); curMove = null; }
      curInk.push(ll);
    } else {
      if (!curMove) { curMove = [curInk ? curInk[curInk.length - 1] : ll]; moveSegs.push(curMove); curInk = null; }
      curMove.push(ll);
    }
  }

  function posAt(d) {
    const { pts, cum } = flight;
    let i = Math.max(1, lastIdx);
    while (i < pts.length - 1 && cum[i] < d) i++;
    const t = cum[i] === cum[i - 1] ? 1 : (d - cum[i - 1]) / (cum[i] - cum[i - 1]);
    return { i, x: pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * Math.min(1, t), y: pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * Math.min(1, t) };
  }

  function setPlaneHeading(deg) {
    const el = planeMarker && planeMarker.getElement();
    if (el) el.firstChild.style.transform = 'rotate(' + deg + 'deg)';
  }

  // viteza "afisata": ~ 900 km/h in croaziera, mai mica la decolare/aterizare. Animatia: 1x ~ 125 km/s (injumatatit la cererea lui Petru).
  const BASE_KMS = 125;
  function frame(t) {
    if (!flight) return;
    const dt = Math.min(0.1, (t - lastT) / 1000); lastT = t;
    const f = flight;
    const inCruise = dist > f.climbKm && dist < f.total - f.landKm;
    dist = Math.min(f.total, dist + dt * BASE_KMS * speedMul * (inCruise ? 1 : 0.45));
    const p = posAt(dist);
    // puncte noi trecute de avion
    for (let j = Math.max(lastIdx, 1); j < p.i; j++) addPoint(f.toLL(f.pts[j]), f.pts[j][2]);
    if (p.i !== lastIdx) lastIdx = p.i;
    const ll = f.toLL([p.x, p.y]);
    const pen = f.pts[p.i][2];
    const inkView = inkSegs.map(s => s.slice()), moveView = moveSegs.map(s => s.slice());
    // segmentul curent, pana la avion
    const lastPt = f.toLL(f.pts[p.i - 1]);
    const tgt = pen ? inkView : moveView;
    const cur = pen ? curInk : curMove;
    if (cur) tgt[tgt.length - 1].push(ll); else tgt.push([lastPt, ll]);
    inkLine.setLatLngs(inkView); glowLine.setLatLngs(inkView);
    moveLine.setLatLngs($('showMoves').checked ? moveView : []);
    planeMarker.setLatLng(ll);
    // directia: spre urmatorul punct, rotita lin
    const nx = f.pts[p.i][0] - p.x, ny = f.pts[p.i][1] - p.y;
    if (Math.hypot(nx, ny) > 1) {
      const want = Math.atan2(nx, ny) * 180 / Math.PI;
      let diff = ((want - heading + 540) % 360) - 180;
      heading += diff * Math.min(1, dt * 14);
      setPlaneHeading(heading);
    }
    if ($('follow').checked) map.panTo(ll, { animate: false });
    updateInfo(dist);
    if (dist >= f.total) { finish(); return; }
    raf = requestAnimationFrame(frame);
  }

  function updateInfo(d) {
    const f = flight;
    const up = Math.min(1, d / f.climbKm), down = Math.min(1, (f.total - d) / f.landKm);
    const alt = Math.round(Math.min(up, down) * 36000 / 100) * 100;
    const spd = Math.round(160 + Math.min(up, down) * 320);
    $('alt').textContent = alt.toLocaleString('ro-RO') + ' ft';
    $('spd').textContent = spd + ' kt';
    $('dist').textContent = Math.round(d).toLocaleString('ro-RO') + ' km';
    $('bar').style.width = (100 * d / f.total).toFixed(1) + '%';
  }

  function finish() {
    cancelAnimationFrame(raf); raf = 0;
    const f = flight;
    for (let j = Math.max(lastIdx, 1); j < f.pts.length; j++) addPoint(f.toLL(f.pts[j]), f.pts[j][2]);
    lastIdx = f.pts.length;
    inkLine.setLatLngs(inkSegs); glowLine.setLatLngs(inkSegs);
    moveLine.setLatLngs($('showMoves').checked ? moveSegs : []);
    $('alt').textContent = '0 ft'; $('spd').textContent = '0 kt';
    $('go').textContent = 'Zboară din nou';
  }

  function currentAirport() {
    const cc = $('country').value, a = DATA.airports[cc].a[+$('airport').value || 0];
    return { cc, code: a[0], name: a[1], city: a[2], lat: a[3], lon: a[4], hdg: a[5] };
  }

  function showAirport() {
    const apt = currentAirport();
    if (aptMarker) aptMarker.remove();
    aptMarker = L.marker([apt.lat, apt.lon], { icon: L.divIcon({ className: 'apt-icon', iconSize: [12, 12] }), keyboard: false })
      .bindTooltip(apt.code, { permanent: true, direction: 'right', offset: [8, 0], className: 'apt-label' }).addTo(map);
    return apt;
  }

  function start() {
    msg('');
    const text = $('text').value.replace(/\s+/g, ' ').trim();
    if (!text) { msg('Scrie un text.'); $('text').focus(); return; }
    const apt = showAirport();
    cancelAnimationFrame(raf);
    resetTrails();
    flight = buildFlight(apt, text);
    if (!flight) { msg('Textul nu are litere de desenat.'); return; }
    // incadreaza tot zborul (textul + aeroportul)
    const b = L.latLngBounds(flight.pts.map(p => flight.toLL(p)));
    const small = map.getSize().x < 600;
    // pe telefon, panoul se strange ca sa se vada harta
    if (small) setMin(true);
    const panelH = $('panel').offsetHeight;
    map.fitBounds(b, { paddingTopLeft: [small ? 20 : 370, (small ? panelH + 16 : 30)], paddingBottomRight: [small ? 20 : 40, small ? 80 : 90], animate: false });
    if (!planeMarker) planeMarker = L.marker([apt.lat, apt.lon], { icon: L.divIcon({ className: 'plane-icon', html: PLANE_SVG, iconSize: [34, 34] }), keyboard: false, interactive: false, zIndexOffset: 1000 }).addTo(map);
    planeMarker.setLatLng([apt.lat, apt.lon]);
    heading = apt.hdg == null ? 90 : apt.hdg; setPlaneHeading(heading);
    dist = 0; lastIdx = 1;
    $('callsign').textContent = 'NOS' + (1 + (text.length * 37 + apt.code.charCodeAt(0)) % 899);
    $('route').textContent = apt.code + ' → ' + apt.code + ' · ' + Math.round(flight.total).toLocaleString('ro-RO') + ' km';
    $('info').hidden = false;
    $('go').textContent = 'Decolează';
    updateInfo(0);
    const q = new URLSearchParams({ tara: apt.cc, text });
    if (+$('airport').value) q.set('aeroport', apt.code);
    history.replaceState(null, '', location.pathname + '?' + q.toString());
    lastT = performance.now();
    raf = requestAnimationFrame(frame);
  }

  function fillAirports(cc, pick) {
    const sel = $('airport'); sel.innerHTML = '';
    DATA.airports[cc].a.forEach((a, i) => {
      const o = document.createElement('option'); o.value = i;
      o.textContent = a[0] + ' · ' + (a[2] || a[1]) + (i === 0 ? ' (principal)' : '');
      o.title = a[1];
      if (pick && a[0] === pick) o.selected = true;
      sel.appendChild(o);
    });
  }

  function setMin(v) {
    $('panel').classList.toggle('min', v);
    $('toggle').textContent = v ? '+' : '−';
    $('toggle').setAttribute('aria-expanded', String(!v));
  }

  // ---------- pornire ----------
  fetch('flights/data.json?v=<?= (int)$dataVer ?>').then(r => r.json()).then(d => {
    DATA = d;
    const sel = $('country');
    const ccs = Object.keys(d.airports).map(cc => [cc, countryName(cc)]).sort((a, b) => a[1].localeCompare(b[1], 'ro'));
    ccs.forEach(([cc, n]) => { const o = document.createElement('option'); o.value = cc; o.textContent = n; sel.appendChild(o); });
    const q = new URLSearchParams(location.search);
    const cc = (q.get('tara') || 'RO').toUpperCase();
    sel.value = d.airports[cc] ? cc : 'RO';
    fillAirports(sel.value, q.get('aeroport'));
    if (q.get('text')) $('text').value = q.get('text').slice(0, 40);
    const apt = showAirport();
    map.setView([apt.lat, apt.lon], 6);
    if (q.get('text')) start();
  }).catch(() => msg('Nu am putut încărca lista de aeroporturi.'));

  $('country').addEventListener('change', () => { fillAirports($('country').value); const a = showAirport(); if (!raf) map.setView([a.lat, a.lon], 6); });
  $('airport').addEventListener('change', () => { const a = showAirport(); if (!raf) map.setView([a.lat, a.lon], 6); });
  $('go').addEventListener('click', start);
  $('text').addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); $('text').blur(); start(); } });
  $('toggle').addEventListener('click', () => setMin(!$('panel').classList.contains('min')));
  $('speed').addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    speedMul = +b.dataset.v;
    $('speed').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
  });
  $('showMoves').addEventListener('change', () => { if (!raf && flight) moveLine.setLatLngs($('showMoves').checked ? moveSegs : []); });
})();
</script>
</body>
</html>
