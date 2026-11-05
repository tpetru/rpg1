<?php
// Portret: "Desenează-mă" - utilizatorul incarca o imagine (silueta, desen, logo), conturul e extras
// in browser (prag Otsu + marching squares), buclele sunt unite intr-un singur drum inchis si desenat
// cu epicicluri (serie Fourier cu N termeni), in acelasi stil ca fun.php. Imaginea nu pleaca spre server.
// Pagina se schimba des: browserul (mai ales pe telefon) trebuie sa ceara mereu versiunea noua.
header('Cache-Control: no-cache, must-revalidate');
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Portret · Epicicluri</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<style>
  :root {
    --bg: #000; --ink: #f2ede6; --ink-2: #a39d95; --line: #2a2723;
    --trace: #f0b8a0; --accent: #e8a08a;
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }   /* .controls / .group au display:flex, care altfel ar castiga */
  html, body { margin: 0; background: var(--bg); color: var(--ink); }
  body { font-family: "Latin Modern Roman", "CMU Serif", Georgia, "Times New Roman", serif; }
  main { max-width: 980px; margin: 0 auto; padding: 18px 16px 40px; }
  .stage { position: relative; width: 100%; }
  canvas { display: block; width: 100%; height: auto; }
  .formulas {
    position: absolute; left: 0; top: 4%; font-size: clamp(11px, 2.1vw, 19px);
    pointer-events: none; line-height: 1.2;
  }
  .formulas .katex { color: var(--ink); }
  .formulas .f-fallback { font-style: italic; white-space: nowrap; }
  .credit {
    position: absolute; right: 0; top: 0; font-size: clamp(11px, 1.8vw, 16px); color: var(--ink-2);
  }
  .credit a { color: inherit; text-decoration: none; }
  .readout {
    position: absolute; left: 58%; transform: translateX(-50%); top: 88%;
    text-align: center; pointer-events: none; white-space: nowrap;
  }
  .readout .n { font-size: clamp(22px, 5vw, 46px); }
  .readout .n b { color: var(--accent); font-weight: 400; }
  .readout .err { font-size: clamp(12px, 2.2vw, 20px); margin-top: 4px; }

  .controls {
    display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: center; justify-content: center;
    margin-top: 14px; font-family: system-ui, "Segoe UI", Roboto, sans-serif; font-size: 13px; color: var(--ink-2);
  }
  .controls .group { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
  .controls button {
    font: inherit; color: var(--ink-2); background: transparent; border: 1px solid var(--line);
    border-radius: 14px; padding: 5px 11px; cursor: pointer; min-width: 36px;
  }
  .controls button:hover { border-color: var(--accent); color: var(--ink); }
  .controls button.on { background: var(--accent); border-color: var(--accent); color: #1a1210; }
  .controls select {
    font: inherit; color: var(--ink); background: #111; border: 1px solid var(--line);
    border-radius: 14px; padding: 5px 10px; cursor: pointer;
  }
  .controls select:focus { outline: none; border-color: var(--accent); }
  .controls input[type=range] { accent-color: var(--accent); width: 120px; }
  .controls .row { display: flex; flex-wrap: wrap; gap: 8px 10px; align-items: center; justify-content: center; width: 100%; }
  .controls .slider { display: flex; align-items: center; gap: 6px; flex: 1 1 140px; max-width: 420px; }
  .controls .slider input[type=range] { flex: 1; width: auto; min-width: 70px; height: 32px; }
  .controls .row.sliders { flex-wrap: nowrap; }
  .controls.result { margin-top: 6px; visibility: hidden; }        /* loc rezervat: pagina nu sare */
  .controls.result.show { visibility: visible; }
  .controls.result button { padding: 3px 10px; font-size: 12px; }
  .controls .upload { border-color: var(--accent); color: var(--ink); }
  #controls[data-mode="lin"] .sil, #controls[data-mode="sil"] .lin { display: none; }
  .controls .hint { font-size: 12px; color: var(--ink-2); }
  .dropping canvas { outline: 2px dashed var(--accent); outline-offset: -6px; }
  #edView { position: fixed; inset: 0; background: #0b0a09; z-index: 60; display: flex; flex-direction: column; }
  #edView[hidden] { display: none; }
  #edView .ed-stage { flex: 1; min-height: 0; position: relative; }
  #edView canvas { position: absolute; inset: 0; width: 100%; height: 100%; touch-action: none; cursor: crosshair; }
  #edView .ed-bar { padding: 10px 12px 14px; display: flex; flex-direction: column; gap: 8px; align-items: center;
    font-family: system-ui, "Segoe UI", Roboto, sans-serif; font-size: 14px; color: var(--ink-2); }
  #edView .row { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; justify-content: center; }
  #edView button { font: inherit; color: var(--ink); background: transparent; border: 1px solid var(--line); border-radius: 16px; padding: 7px 14px; cursor: pointer; }
  #edView button:hover { border-color: var(--accent); }
  #edView button.on { background: var(--accent); border-color: var(--accent); color: #1a1210; }
  #edView input[type=range] { accent-color: var(--accent); width: 160px; }
  #edView .hint { font-size: 12px; }
  #fsView { position: fixed; inset: 0; background: #000; z-index: 50; }
  #fsView canvas { width: 100%; height: 100%; }
  #fsView img { position: absolute; inset: 0; margin: auto; max-width: 100%; max-height: 100%; -webkit-touch-callout: default; }
  #fsView .hint { position: absolute; left: 0; right: 0; bottom: 18px; text-align: center; color: var(--ink-2);
    font-family: system-ui, "Segoe UI", Roboto, sans-serif; font-size: 14px; }
  #fsView .bar { position: absolute; top: 12px; right: 12px; display: flex; gap: 8px; font-family: system-ui, "Segoe UI", Roboto, sans-serif; font-size: 14px; }
  #fsView button { font: inherit; color: var(--ink); background: rgba(0,0,0,.6); border: 1px solid var(--line); border-radius: 16px; padding: 6px 13px; cursor: pointer; }
  #fsView button:hover { border-color: var(--accent); }
  .loading { text-align: center; color: var(--ink-2); font-family: system-ui, sans-serif; padding: 40px 0; }
</style>
</head>
<body>
<main>
  <div class="stage" id="stage">
    <canvas id="cv" aria-label="Imagine desenata cu epicicluri"></canvas>
    <div class="formulas" id="formulas">
      <div class="f-fallback">x<sub>N</sub>(t) = &Sigma;<sub>k=1..N</sub> (a<sub>k</sub> cos kt + b<sub>k</sub> sin kt)</div>
      <div class="f-fallback">y<sub>N</sub>(t) = &Sigma;<sub>k=1..N</sub> (c<sub>k</sub> cos kt + d<sub>k</sub> sin kt)</div>
    </div>
    <div class="credit">inspirat de <a href="https://www.instagram.com/epicycle.studio/" target="_blank" rel="noopener">@epicycle.studio</a></div>
    <div class="readout" id="readout" hidden>
      <div class="n">N = <b id="nVal">4096</b></div>
      <div class="err">approximation error = <span id="errVal">0.10</span>%</div>
    </div>
  </div>
  <div class="loading" id="loading">Se pregătește…</div>

  <div class="controls result" id="resultBtns">
    <button id="againBtn" title="Desenează din nou">↻ Repetă</button>
    <button id="fsBtn" title="Desenul terminat, pe tot ecranul">⛶ Ecran complet</button>
    <button id="dlBtn" title="Descarcă desenul ca imagine PNG">⤓ Descarcă</button>
  </div>
  <div class="controls" id="controls" hidden data-mode="sil">
    <div class="row">
      <button id="uploadBtn" class="upload" title="Alege o imagine (poză, siluetă, desen, logo) și o desenăm cu epicicluri">Selectează imagine</button>
      <input type="file" id="fileInput" accept="image/*" hidden>
      <button id="editBtn" title="Taie, rotește sau încadrează din nou poza">✂ Editează poza</button>
      <label class="group">N: <select id="nSelect" title="Câți termeni are seria Fourier"></select></label>
    </div>
    <div class="row sliders">
      <label class="slider"><span>Viteză</span><input type="range" id="speed" min="0" max="100" value="45"></label>
      <label class="slider sil"><span>Prag</span><input type="range" id="thr" min="1" max="254" value="128" title="Pragul de luminozitate obiect/fundal"></label>
      <label class="slider lin"><span>Detalii</span><input type="range" id="detail" min="0" max="100" value="35" title="Câte margini păstrăm: puține (doar cele puternice) … multe"></label>
    </div>
    <div class="row" id="imgOpts" hidden>
      <button id="modeSil" title="Conturul obiectului (siluete, logo-uri, PNG transparent)">Siluetă</button>
      <button id="modeLin" title="Marginile din imagine (fotografii, portrete, desene)">Linii</button>
      <button id="personBtn" title="Scoate fundalul și desenează doar persoana (model AI care rulează în browser, ~25 MB la prima folosire)">Doar persoana</button>
      <button id="objBtn" title="Desenează doar obiectul principal (AI în browser, ~6 MB la prima folosire). Apoi atinge desenul ca să alegi alt obiect.">Doar obiectul</button>
      <button id="outerBtn" class="sil" title="Doar cea mai lungă buclă de contur, fără detaliile interioare">Doar conturul exterior</button>
      <button id="invertBtn" class="sil" title="Schimbă ce e obiect și ce e fundal">Inversează</button>
    </div>
    <div class="row"><span class="hint" id="imgStatus"></span></div>
  </div>
</main>
<div id="edView" hidden>
  <div class="ed-stage"><canvas id="edCv" aria-label="Editează poza: trage de colțuri ca să tai"></canvas></div>
  <div class="ed-bar">
    <div class="row">
      <button id="edRotL" title="Rotește 90° la stânga">↺ 90°</button>
      <button id="edRotR" title="Rotește 90° la dreapta">↻ 90°</button>
      <span>Rotire</span><input type="range" id="edAngle" min="-45" max="45" step="0.5" value="0" title="Rotire fină (îndreaptă poza)">
      <span id="edAngleVal">0°</span>
    </div>
    <div class="row">
      <span class="hint">Trage de colțuri ca să tai · trage zona ca s-o muți</span>
    </div>
    <div class="row">
      <button id="edReset">Resetează</button>
      <button id="edCancel">Anulează</button>
      <button id="edOk" class="on">✓ Desenează</button>
    </div>
  </div>
</div>
<div id="fsView" hidden>
  <canvas id="fsCv" aria-label="Desenul terminat"></canvas>
  <img id="fsImg" alt="Desenul terminat" hidden>
  <div class="hint" id="fsHint" hidden>Ține apăsat pe imagine → „Salvează imaginea”</div>
  <div class="bar"><button id="fsDl">⤓ Descarcă</button><button id="fsClose" title="Închide (Esc)">✕</button></div>
</div>

<script>
(function () {
  'use strict';

  // ---------- FFT (radix-2, in-place) ----------
  function fft(re, im, inverse) {
    const n = re.length;
    for (let i = 1, j = 0; i < n; i++) {
      let bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) { let t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
    }
    for (let len = 2; len <= n; len <<= 1) {
      const ang = (inverse ? 2 : -2) * Math.PI / len;
      const wr = Math.cos(ang), wi = Math.sin(ang), half = len >> 1;
      for (let i = 0; i < n; i += len) {
        let cr = 1, ci = 0;
        for (let k = 0; k < half; k++) {
          const a = i + k, b = a + half;
          const tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr;
          re[b] = re[a] - tr; im[b] = im[a] - ti; re[a] += tr; im[a] += ti;
          const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
        }
      }
    }
    if (inverse) for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
  }

  const NS = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
  const cv = document.getElementById('cv'), ctx = cv.getContext('2d');
  const stage = document.getElementById('stage');

  let M, X, Y;              // samples
  let Zre, Zim;             // spectrum of z = x + iy
  let xTerms, yTerms;       // [{k, r, ph}] sorted by radius desc, for the real series of x and y
  let x0, y0;               // mean (k = 0)
  let yMax = 0;             // height of the map data
  let recon = null, curN = 4096, errPct = 0;
  let progress = 0, playing = true, auto = false, holdUntil = 0, done = false;
  let frameRect = null, framing = 0;      // rama pozei (coordonate de date) si cat din ea e desenat (0..1)
  function restart() {                    // porneste desenul de la inceput si ascunde butoanele de final
    progress = 0; holdUntil = 0; done = false; framing = 0;
    document.getElementById('resultBtns').classList.remove('show');
  }
  let L = null;             // layout

  let started = false;

  // ---------- "Desenează-mă": contur din imaginea utilizatorului (totul local, in browser) ----------
  const MAXDIM = 480, MAXLOOPS = 120;
  let imgSrc = null;                          // {w, h, v: luminozitate 0..255 (sau opacitate inversata)}
  const imgOpt = { invert: false, outer: false, thr: 128, mode: 'sil', detail: 35, person: false, obj: false, objPt: [0.5, 0.5] };
  const imgStatus = t => { document.getElementById('imgStatus').textContent = t; };

  function loadImageFile(file) {
    if (!file || !/^image\//.test(file.type)) { showImgOpts(); imgStatus('Alege un fișier imagine.'); return; }
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => { URL.revokeObjectURL(url); openEditor(img); };
    img.onerror = () => { URL.revokeObjectURL(url); showImgOpts(); imgStatus('Nu am putut citi imaginea.'); };
    img.src = url;
  }

  // ---------- editor: rotire (90° + fina) si taiere, inainte de desen ----------
  const ED_MAX = 1400;                       // rezolutia de lucru a editorului (desenul foloseste oricum max. 480 px)
  const edView = document.getElementById('edView'), edCv = document.getElementById('edCv');
  let ed = null;                             // { img, alpha, quarter, fine, rc (canvas rotit), crop: [x0,y0,x1,y1] in 0..1 }
  let edOrig = null;                         // ultima imagine originala, pentru "Editează poza"

  function hasAlpha(img) {
    const c = document.createElement('canvas'); c.width = 64; c.height = 64;
    const g = c.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0, 64, 64);
    const d = g.getImageData(0, 0, 64, 64).data;
    for (let i = 3; i < d.length; i += 4) if (d[i] < 250) return true;
    return false;
  }
  function openEditor(img) {
    edOrig = img;
    ed = { img, alpha: hasAlpha(img), quarter: 0, fine: 0, rc: null, crop: [0, 0, 1, 1], drag: null };
    document.getElementById('edAngle').value = 0;
    edView.hidden = false;
    edRotate();
  }
  // deseneaza poza rotita intr-un canvas de lucru (fundal alb la colturi, daca poza nu e transparenta)
  function edRotate() {
    const img = ed.img, iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
    const f = Math.min(1, ED_MAX / Math.max(iw, ih)), w = iw * f, h = ih * f;
    const a = (ed.quarter * 90 + ed.fine) * Math.PI / 180, c = Math.abs(Math.cos(a)), sn = Math.abs(Math.sin(a));
    const W = Math.round(w * c + h * sn), H = Math.round(w * sn + h * c);
    const rc = document.createElement('canvas'); rc.width = Math.max(1, W); rc.height = Math.max(1, H);
    const g = rc.getContext('2d');
    if (!ed.alpha) { g.fillStyle = '#fff'; g.fillRect(0, 0, W, H); }
    g.translate(W / 2, H / 2); g.rotate(a); g.drawImage(img, -w / 2, -h / 2, w, h);
    ed.rc = rc;
    if (ed.fine) {                            // rotire fina: taie automat colturile albe (cel mai mare dreptunghi interior)
      const q = ed.quarter % 2, w2 = q ? h : w, h2 = q ? w : h, fa = Math.abs(ed.fine) * Math.PI / 180;
      const sa = Math.sin(fa), ca = Math.cos(fa), lng = Math.max(w2, h2), sht = Math.min(w2, h2);
      let wr, hr;
      if (sht <= 2 * sa * ca * lng) { const x = sht / 2; [wr, hr] = w2 >= h2 ? [x / sa, x / ca] : [x / ca, x / sa]; }
      else { const c2 = ca * ca - sa * sa; wr = (w2 * ca - h2 * sa) / c2; hr = (h2 * ca - w2 * sa) / c2; }
      const fx = Math.min(1, wr / W), fy = Math.min(1, hr / H);
      ed.crop = [(1 - fx) / 2, (1 - fy) / 2, (1 + fx) / 2, (1 + fy) / 2];
    }
    document.getElementById('edAngleVal').textContent = (ed.fine > 0 ? '+' : '') + ed.fine + '°';
    edDraw();
  }
  function edLayout() {
    const d = window.devicePixelRatio || 1, cw = edCv.clientWidth, ch = edCv.clientHeight;
    if (edCv.width !== Math.round(cw * d) || edCv.height !== Math.round(ch * d)) { edCv.width = Math.round(cw * d); edCv.height = Math.round(ch * d); }
    const pad = 18, rc = ed.rc, sc = Math.min((cw - 2 * pad) / rc.width, (ch - 2 * pad) / rc.height);
    return { d, sc, x: (cw - rc.width * sc) / 2, y: (ch - rc.height * sc) / 2, w: rc.width * sc, h: rc.height * sc };
  }
  function edDraw() {
    if (!ed || edView.hidden) return;
    const L2 = edLayout(), g = edCv.getContext('2d'), [x0, y0, x1, y1] = ed.crop;
    g.setTransform(L2.d, 0, 0, L2.d, 0, 0);
    g.clearRect(0, 0, edCv.width, edCv.height);
    g.drawImage(ed.rc, L2.x, L2.y, L2.w, L2.h);
    const cx = L2.x + x0 * L2.w, cy = L2.y + y0 * L2.h, cw = (x1 - x0) * L2.w, ch = (y1 - y0) * L2.h;
    g.fillStyle = 'rgba(0,0,0,0.6)';
    g.beginPath(); g.rect(L2.x, L2.y, L2.w, L2.h); g.rect(cx, cy, cw, ch); g.fill('evenodd');
    g.strokeStyle = '#e8a08a'; g.lineWidth = 2; g.strokeRect(cx, cy, cw, ch);
    g.strokeStyle = 'rgba(232,160,138,0.35)'; g.lineWidth = 1; g.beginPath();
    for (let k = 1; k < 3; k++) { g.moveTo(cx + cw * k / 3, cy); g.lineTo(cx + cw * k / 3, cy + ch); g.moveTo(cx, cy + ch * k / 3); g.lineTo(cx + cw, cy + ch * k / 3); }
    g.stroke();
    g.fillStyle = '#e8a08a';
    for (const [hx, hy] of [[cx, cy], [cx + cw, cy], [cx, cy + ch], [cx + cw, cy + ch]]) { g.beginPath(); g.arc(hx, hy, 7, 0, Math.PI * 2); g.fill(); }
  }
  edCv.addEventListener('pointerdown', e => {
    const L2 = edLayout(), r = edCv.getBoundingClientRect();
    const px = e.clientX - r.left, py = e.clientY - r.top, [x0, y0, x1, y1] = ed.crop;
    const cx0 = L2.x + x0 * L2.w, cy0 = L2.y + y0 * L2.h, cx1 = L2.x + x1 * L2.w, cy1 = L2.y + y1 * L2.h;
    const near = (a, b) => Math.abs(a - b) < (e.pointerType === 'touch' ? 28 : 16);
    let mode = null;
    if (near(px, cx0) && near(py, cy0)) mode = 'tl'; else if (near(px, cx1) && near(py, cy0)) mode = 'tr';
    else if (near(px, cx0) && near(py, cy1)) mode = 'bl'; else if (near(px, cx1) && near(py, cy1)) mode = 'br';
    else if (px > cx0 && px < cx1 && py > cy0 && py < cy1) mode = 'move';
    else mode = 'new';
    const u = (px - L2.x) / L2.w, v = (py - L2.y) / L2.h;
    ed.drag = { mode, u, v, start: ed.crop.slice() };
    edCv.setPointerCapture(e.pointerId); e.preventDefault();
  });
  edCv.addEventListener('pointermove', e => {
    if (!ed || !ed.drag) return;
    const L2 = edLayout(), r = edCv.getBoundingClientRect();
    const cl = q => Math.min(1, Math.max(0, q)), MIN = 0.05;
    const u = cl((e.clientX - r.left - L2.x) / L2.w), v = cl((e.clientY - r.top - L2.y) / L2.h);
    const D = ed.drag, [a0, b0, a1, b1] = D.start;
    let [x0, y0, x1, y1] = D.start;
    if (D.mode === 'move') {
      const du = Math.min(1 - a1, Math.max(-a0, u - D.u)), dv = Math.min(1 - b1, Math.max(-b0, v - D.v));
      x0 = a0 + du; x1 = a1 + du; y0 = b0 + dv; y1 = b1 + dv;
    } else if (D.mode === 'new') {
      x0 = Math.min(D.u, u); x1 = Math.max(D.u, u); y0 = Math.min(D.v, v); y1 = Math.max(D.v, v);
      if (x1 - x0 < MIN || y1 - y0 < MIN) return;
    } else {
      if (D.mode[1] === 'l') x0 = Math.min(u, x1 - MIN); else x1 = Math.max(u, x0 + MIN);
      if (D.mode[0] === 't') y0 = Math.min(v, y1 - MIN); else y1 = Math.max(v, y0 + MIN);
    }
    ed.crop = [x0, y0, x1, y1]; edDraw();
  });
  const edEnd = () => { if (ed) ed.drag = null; };
  edCv.addEventListener('pointerup', edEnd); edCv.addEventListener('pointercancel', edEnd);
  window.addEventListener('resize', edDraw);
  document.getElementById('edRotL').onclick = () => { ed.quarter = (ed.quarter + 3) % 4; ed.crop = [0, 0, 1, 1]; edRotate(); };
  document.getElementById('edRotR').onclick = () => { ed.quarter = (ed.quarter + 1) % 4; ed.crop = [0, 0, 1, 1]; edRotate(); };
  document.getElementById('edAngle').oninput = e => { ed.fine = +e.target.value; if (!ed.fine) ed.crop = [0, 0, 1, 1]; edRotate(); };
  document.getElementById('edReset').onclick = () => {
    ed.quarter = 0; ed.fine = 0; ed.crop = [0, 0, 1, 1]; document.getElementById('edAngle').value = 0; edRotate();
  };
  document.getElementById('edCancel').onclick = () => { edView.hidden = true; ed = null; };
  document.getElementById('edOk').onclick = () => {
    const rc = ed.rc, [x0, y0, x1, y1] = ed.crop;
    const sx = Math.round(x0 * rc.width), sy = Math.round(y0 * rc.height);
    const sw = Math.max(8, Math.round((x1 - x0) * rc.width)), sh = Math.max(8, Math.round((y1 - y0) * rc.height));
    const out = document.createElement('canvas'); out.width = sw; out.height = sh;
    out.getContext('2d').drawImage(rc, sx, sy, sw, sh, 0, 0, sw, sh);
    edView.hidden = true; ed = null;
    prepareImage(out);
  };
  document.getElementById('editBtn').onclick = () => { if (edOrig) openEditor(edOrig); };
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && !edView.hidden) document.getElementById('edCancel').click(); });

  function prepareImage(img) {
    const iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
    const sc = Math.min(1, MAXDIM / Math.max(iw, ih));
    const w = Math.max(8, Math.round(iw * sc)), h = Math.max(8, Math.round(ih * sc));
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const g = c.getContext('2d', { willReadFrequently: true });
    g.drawImage(img, 0, 0, w, h);
    const d = g.getImageData(0, 0, w, h).data, n = w * h, v = new Float32Array(n), lum = new Float32Array(n);
    let transp = 0;
    for (let i = 0; i < n; i++) if (d[4 * i + 3] < 128) transp++;
    const useAlpha = transp > n * 0.02;       // PNG cu fundal transparent: obiectul = partea opaca
    for (let i = 0; i < n; i++) {
      const a = d[4 * i + 3] / 255;
      lum[i] = (0.299 * d[4 * i] + 0.587 * d[4 * i + 1] + 0.114 * d[4 * i + 2]) * a + 255 * (1 - a);
      v[i] = useAlpha ? 255 * (1 - a) : lum[i];
    }
    imgSrc = { w, h, v, lum, canvas: c, person: null, obj: null, objKey: '' };
    imgOpt.objPt = [0.5, 0.5];
    imgOpt.invert = false;
    document.getElementById('invertBtn').classList.remove('on');
    imgOpt.thr = otsu(v);
    document.getElementById('thr').value = imgOpt.thr;
    // fotografie (multe tonuri intermediare) -> modul "Linii"; siluete / logo-uri / PNG transparent -> "Siluetă"
    let mid = 0;
    for (let i = 0; i < n; i++) if (v[i] > 45 && v[i] < 210) mid++;
    setMode(!useAlpha && mid > n * 0.2 ? 'lin' : 'sil');
    if (imgOpt.person) withPerson(); else if (imgOpt.obj) withObject(); else extractAndShow();
  }

  function otsu(v) {
    const hist = new Float64Array(256);
    for (let i = 0; i < v.length; i++) hist[Math.min(255, v[i] | 0)]++;
    let sum = 0; for (let i = 0; i < 256; i++) sum += i * hist[i];
    let wB = 0, sB = 0, best = -1, thr = 128;
    for (let t = 0; t < 256; t++) {
      wB += hist[t]; if (!wB) continue;
      const wF = v.length - wB; if (!wF) break;
      sB += t * hist[t];
      const d = sB / wB - (sum - sB) / wF, b = wB * wF * d * d;
      if (b > best) { best = b; thr = t; }
    }
    return Math.min(254, Math.max(1, thr + 1));
  }

  // ---- "Doar persoana": segmentare cu MediaPipe (selfie multiclass), incarcata doar la cerere ----
  const MP = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';
  const MP_MODEL = 'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float32/latest/selfie_multiclass_256x256.tflite';
  let segP = null;
  function getSegmenter() {
    if (!segP) {
      segP = (async () => {
        const vision = await import(MP + '/vision_bundle.mjs');
        const files = await vision.FilesetResolver.forVisionTasks(MP + '/wasm');
        return vision.ImageSegmenter.createFromOptions(files, {
          baseOptions: { modelAssetPath: MP_MODEL }, runningMode: 'IMAGE',
          outputConfidenceMasks: true, outputCategoryMask: false,
        });
      })();
      segP.catch(() => { segP = null; });
    }
    return segP;
  }
  async function segmentPerson(src) {
    if (src.person) return src.person;
    const seg = await getSegmenter();
    const { w, h } = src;
    let p = null;
    seg.segment(src.canvas, r => {
      const m = r.confidenceMasks[0], bg = m.getAsFloat32Array(), mw = m.width, mh = m.height;
      p = new Float32Array(w * h);                 // categoria 0 = fundal; restul (par, fata, corp, haine) = persoana
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
        p[y * w + x] = 1 - bg[Math.min(mh - 1, (y * mh / h) | 0) * mw + Math.min(mw - 1, (x * mw / w) | 0)];
    });
    let cnt = 0; for (let i = 0; i < p.length; i++) if (p[i] > 0.5) cnt++;
    src.person = cnt > p.length * 0.005 ? p : 'none';
    return src.person;
  }
  async function withPerson() {
    const src = imgSrc, btn = document.getElementById('personBtn');
    showImgOpts();
    if (!src.person) imgStatus(segP ? 'Caut persoana…' : 'Se încarcă modelul pentru persoane (~25 MB, doar prima dată)…');
    try { await segmentPerson(src); }
    catch (e) {
      imgOpt.person = false; btn.classList.remove('on');
      imgStatus('Nu am putut încărca modelul pentru persoane.');
      return;
    }
    if (src !== imgSrc) return;                       // intre timp s-a incarcat alta imagine
    if (src.person === 'none') {
      imgOpt.person = false; btn.classList.remove('on');
      extractAndShow();
      imgStatus('Nu am găsit nicio persoană în imagine — o desenez întreagă.');
      return;
    }
    extractAndShow();
  }
  // ---- "Doar obiectul": MediaPipe InteractiveSegmenter (MagicTouch) - obiectul de sub un punct ----
  // Implicit punctul e centrul pozei; un click / o atingere pe desen alege alt obiect.
  const MT_MODEL = 'https://storage.googleapis.com/mediapipe-models/interactive_segmenter/magic_touch/float32/latest/magic_touch.tflite';
  let mtP = null;
  function getMagic() {
    if (!mtP) {
      mtP = (async () => {
        const vision = await import(MP + '/vision_bundle.mjs');
        const files = await vision.FilesetResolver.forVisionTasks(MP + '/wasm');
        return vision.InteractiveSegmenter.createFromOptions(files, {
          baseOptions: { modelAssetPath: MT_MODEL }, outputConfidenceMasks: true, outputCategoryMask: false,
        });
      })();
      mtP.catch(() => { mtP = null; });
    }
    return mtP;
  }
  async function segmentObject(src, pt) {
    const key = pt.map(q => q.toFixed(3)).join(',');
    if (src.obj && src.objKey === key) return src.obj;
    const seg = await getMagic();
    const { w, h } = src;
    let p = null;
    seg.segment(src.canvas, { keypoint: { x: pt[0], y: pt[1] } }, r => {
      const m = r.confidenceMasks[0], a = m.getAsFloat32Array(), mw = m.width, mh = m.height;
      p = new Float32Array(w * h);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
        p[y * w + x] = a[Math.min(mh - 1, (y * mh / h) | 0) * mw + Math.min(mw - 1, (x * mw / w) | 0)];
    });
    // masca trebuie sa contina punctul ales; daca e invers (fundalul), o intoarcem
    const ki = Math.min(h - 1, (pt[1] * h) | 0) * w + Math.min(w - 1, (pt[0] * w) | 0);
    if (p[ki] < 0.5) for (let i = 0; i < p.length; i++) p[i] = 1 - p[i];
    let cnt = 0; for (let i = 0; i < p.length; i++) if (p[i] > 0.5) cnt++;
    src.obj = cnt > p.length * 0.003 && cnt < p.length * 0.97 ? p : 'none';
    src.objKey = key;
    return src.obj;
  }
  async function withObject() {
    const src = imgSrc, btn = document.getElementById('objBtn');
    showImgOpts();
    imgStatus(mtP ? 'Caut obiectul…' : 'Se încarcă modelul pentru obiecte (~15 MB, doar prima dată)…');
    try { await segmentObject(src, imgOpt.objPt); }
    catch (e) {
      imgOpt.obj = false; btn.classList.remove('on'); cv.style.cursor = '';
      imgStatus('Nu am putut încărca modelul pentru obiecte.');
      return;
    }
    if (src !== imgSrc) return;
    if (src.obj === 'none') {
      extractAndShow();
      imgStatus('Nu am găsit un obiect acolo — atinge desenul pe obiectul dorit.');
      return;
    }
    extractAndShow();
  }
  const personMask = () => {
    if (imgOpt.obj) return imgSrc.obj && imgSrc.obj !== 'none' ? imgSrc.obj : null;
    return imgOpt.person && imgSrc.person && imgSrc.person !== 'none' ? imgSrc.person : null;
  };

  function showImgOpts() {
    document.getElementById('imgOpts').hidden = false;
  }
  function setMode(m) {
    imgOpt.mode = m;
    document.getElementById('controls').dataset.mode = m;
    document.getElementById('modeSil').classList.toggle('on', m === 'sil');
    document.getElementById('modeLin').classList.toggle('on', m === 'lin');
  }

  function extractAndShow() {
    showImgOpts();
    const lin = imgOpt.mode === 'lin', flat = lin ? edgesToPath() : imageToPath();
    if (!flat) {
      imgStatus(lin ? 'Nu am găsit margini — mărește „Detalii" sau încearcă „Siluetă".'
                    : 'Nu am găsit niciun contur — încearcă alt prag, „Inversează" sau „Linii".');
      return;
    }
    frameRect = flat.path.frame || null;
    init(flat.path);
    imgStatus(flat.loops + (lin ? (flat.loops === 1 ? ' linie' : ' linii') : (flat.loops === 1 ? ' buclă' : ' bucle'))
      + (personMask() ? (imgOpt.obj ? ' · doar obiectul (atinge desenul ca să alegi altul)' : ' · doar persoana') : '')
      + ' · imaginea rămâne în browserul tău');
  }

  // masca obiect/fundal -> bucle (marching squares) -> un singur drum inchis -> M puncte, 0..1000
  function imageToPath() {
    const pm = personMask(), { w, h } = imgSrc;
    let v = imgSrc.v, thr = imgOpt.thr, fgDark;
    if (pm) {                                        // persoana = "opaca", fundalul = transparent
      v = pm.map(q => 255 * (1 - q)); thr = 128; fgDark = !imgOpt.invert;
    } else {
      // fundalul e ce domina pe margine
      let darkBorder = 0, nb = 0;
      for (let x = 0; x < w; x++) { darkBorder += (v[x] < thr) + (v[(h - 1) * w + x] < thr); nb += 2; }
      for (let y = 0; y < h; y++) { darkBorder += (v[y * w] < thr) + (v[y * w + w - 1] < thr); nb += 2; }
      fgDark = (darkBorder < nb / 2) !== imgOpt.invert;
    }
    const W = w + 2, H = h + 2, G = new Uint8Array(W * H);     // bordura de 0 => toate buclele se inchid
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const val = v[y * w + x];
      G[(y + 1) * W + x + 1] = fgDark ? (val < thr ? 1 : 0) : (val >= thr ? 1 : 0);
    }
    const loops = marching(G, W, H)
      .map(smoothLoop)
      .map(p => ({ p, len: loopLen(p) }))
      .sort((a, b) => b.len - a.len);
    if (!loops.length) return null;
    const minLen = Math.max(14, loops[0].len * 0.015);
    let keep = loops.filter(l => l.len >= minLen).slice(0, imgOpt.outer ? 1 : MAXLOOPS);
    const path = joinLoops(keep.map(l => l.p));
    // rama pozei, in coordonatele marching squares (pixelul x are centrul in x+1)
    return { path: resampleNormalize(path, 16384, [0.5, 0.5, w + 0.5, h + 0.5]), loops: keep.length };
  }

  // Modul "Linii": margini Canny (blur gaussian, Sobel, suprimare non-maxime, histerezis), urmarite ca
  // lanturi de pixeli; fiecare lant e parcurs dus-intors ca sa devina bucla, apoi totul se uneste.
  function edgesToPath() {
    let { w, h, lum } = imgSrc, pm = personMask();
    // pozele mari dau prea multe margini marunte: lucram la max. 360 px
    const f = Math.min(1, 360 / Math.max(w, h));
    if (f < 1) {
      const w2 = Math.round(w * f), h2 = Math.round(h * f);
      const down = src => {
        const out = new Float32Array(w2 * h2);
        for (let y = 0; y < h2; y++) for (let x = 0; x < w2; x++) {
          let s = 0, c = 0;
          const x0 = Math.floor(x / f), x1 = Math.min(w, Math.floor((x + 1) / f)), y0 = Math.floor(y / f), y1 = Math.min(h, Math.floor((y + 1) / f));
          for (let yy = y0; yy < y1; yy++) for (let xx = x0; xx < x1; xx++) { s += src[yy * w + xx]; c++; }
          out[y * w2 + x] = c ? s / c : 0;
        }
        return out;
      };
      lum = down(lum); if (pm) pm = down(pm);
      w = w2; h = h2;
    }
    const n = w * h, K = [1, 4, 6, 4, 1], tmp = new Float32Array(n), b = new Float32Array(n);
    const cl = (v, a) => v < 0 ? 0 : v >= a ? a - 1 : v;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      let s = 0; for (let k = -2; k <= 2; k++) s += K[k + 2] * lum[y * w + cl(x + k, w)]; tmp[y * w + x] = s / 16;
    }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      let s = 0; for (let k = -2; k <= 2; k++) s += K[k + 2] * tmp[cl(y + k, h) * w + x]; b[y * w + x] = s / 16;
    }
    const mag = new Float32Array(n), dir = new Uint8Array(n);
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      const gx = b[i - w + 1] + 2 * b[i + 1] + b[i + w + 1] - b[i - w - 1] - 2 * b[i - 1] - b[i + w - 1];
      const gy = b[i + w - 1] + 2 * b[i + w] + b[i + w + 1] - b[i - w - 1] - 2 * b[i - w] - b[i - w + 1];
      mag[i] = Math.hypot(gx, gy);
      let a = Math.atan2(gy, gx) * 180 / Math.PI; if (a < 0) a += 180;
      dir[i] = a < 22.5 || a >= 157.5 ? 0 : a < 67.5 ? 1 : a < 112.5 ? 2 : 3;
    }
    const OFF = [[1, 0], [1, 1], [0, 1], [-1, 1]];
    const nms = new Float32Array(n), cand = [];
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x, m = mag[i]; if (m < 4 || (pm && pm[i] < 0.35)) continue;   // fara fundal
      const [dx, dy] = OFF[dir[i]];
      if (m >= mag[i + dy * w + dx] && m > mag[i - dy * w - dx]) { nms[i] = m; cand.push(m); }
    }
    if (cand.length < 10) return null;
    cand.sort((a, b) => a - b);
    const keep = 0.04 + 0.5 * imgOpt.detail / 100;           // fractiunea de margini "puternice"
    const hi = cand[Math.floor(cand.length * (1 - keep))], lo = hi * 0.45;
    const E = new Uint8Array(n), st = [];
    for (let i = 0; i < n; i++) if (nms[i] >= hi) { E[i] = 1; st.push(i); }
    while (st.length) {
      const i = st.pop(), x = i % w, y = (i / w) | 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
        const j = yy * w + xx; if (!E[j] && nms[j] >= lo) { E[j] = 1; st.push(j); }
      }
    }
    // urmarirea lanturilor: intai de la capete, apoi ce a ramas (bucle inchise)
    const N8 = [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, 1], [-1, -1], [1, -1]];
    const deg = i => { let c = 0; const x = i % w, y = (i / w) | 0;
      for (const [dx, dy] of N8) { const xx = x + dx, yy = y + dy; if (xx >= 0 && yy >= 0 && xx < w && yy < h && E[yy * w + xx]) c++; } return c; };
    const used = new Uint8Array(n), chains = [];
    const walk = s => {
      const c = []; let i = s;
      while (i >= 0) {
        used[i] = 1; c.push([i % w + 0.5, ((i / w) | 0) + 0.5]);
        const x = i % w, y = (i / w) | 0; let nx = -1;
        for (const [dx, dy] of N8) {
          const xx = x + dx, yy = y + dy;
          if (xx >= 0 && yy >= 0 && xx < w && yy < h) { const j = yy * w + xx; if (E[j] && !used[j]) { nx = j; break; } }
        }
        i = nx;
      }
      return c;
    };
    for (let i = 0; i < n; i++) if (E[i] && !used[i] && deg(i) === 1) chains.push(walk(i));
    for (let i = 0; i < n; i++) if (E[i] && !used[i]) chains.push(walk(i));
    const minLen = Math.max(6, Math.max(w, h) * 0.025);
    let loops = chains.filter(c => c.length >= minLen).sort((a, b) => b.length - a.length).slice(0, 400)
      .map(c => {
        const sm = c.map((p, i) => {            // netezire (fara a muta capetele)
          if (i < 2 || i > c.length - 3) return p;
          let sx = 0, sy = 0; for (let j = -2; j <= 2; j++) { sx += c[i + j][0]; sy += c[i + j][1]; }
          return [sx / 5, sy / 5];
        });
        return sm.concat(sm.slice(1, -1).reverse());  // dus-intors => bucla
      });
    if (pm) {                                        // conturul persoanei, ca prima bucla
      const W = w + 2, H = h + 2, G = new Uint8Array(W * H);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) G[(y + 1) * W + x + 1] = pm[y * w + x] >= 0.5 ? 1 : 0;
      const sil = marching(G, W, H).map(smoothLoop).map(l => l.map(q => [q[0] - 0.5, q[1] - 0.5]))
        .sort((a, b) => b.length - a.length);
      if (sil.length) loops = sil.filter(l => l.length >= sil[0].length * 0.1).slice(0, 3).concat(loops);
    }
    if (!loops.length) return null;
    return { path: resampleNormalize(joinLoops(loops), 16384, [0, 0, w, h]), loops: loops.length };
  }

  function marching(G, W, H) {
    const E = 2 * W * H, nb = new Int32Array(2 * E).fill(-1);
    const hE = (x, y) => y * W + x, vE = (x, y) => W * H + y * W + x;
    const link = (a, b) => {
      nb[2 * a] < 0 ? nb[2 * a] = b : nb[2 * a + 1] = b;
      nb[2 * b] < 0 ? nb[2 * b] = a : nb[2 * b + 1] = a;
    };
    for (let y = 0; y < H - 1; y++) for (let x = 0; x < W - 1; x++) {
      const c = G[y * W + x] * 8 + G[y * W + x + 1] * 4 + G[(y + 1) * W + x + 1] * 2 + G[(y + 1) * W + x];
      if (c === 0 || c === 15) continue;
      const T = hE(x, y), R = vE(x + 1, y), B = hE(x, y + 1), Lf = vE(x, y);
      switch (c) {
        case 1: case 14: link(Lf, B); break;
        case 2: case 13: link(B, R); break;
        case 3: case 12: link(Lf, R); break;
        case 4: case 11: link(T, R); break;
        case 6: case 9: link(T, B); break;
        case 7: case 8: link(Lf, T); break;
        case 5: link(T, R); link(Lf, B); break;
        case 10: link(Lf, T); link(B, R); break;
      }
    }
    const pt = e => e < W * H ? [e % W + 0.5, (e / W | 0)] : [(e - W * H) % W, ((e - W * H) / W | 0) + 0.5];
    const seen = new Uint8Array(E), loops = [];
    for (let s = 0; s < E; s++) {
      if (seen[s] || nb[2 * s] < 0) continue;
      const loop = []; let prev = -1, cur = s;
      while (cur >= 0 && !seen[cur]) {
        seen[cur] = 1; loop.push(pt(cur));
        const nx = nb[2 * cur] !== prev ? nb[2 * cur] : nb[2 * cur + 1];
        prev = cur; cur = nx;
      }
      if (loop.length >= 4) loops.push(loop);
    }
    return loops;
  }

  function smoothLoop(p) {               // medie mobila circulara: scoate "scarile" pixelilor
    const n = p.length, r = Math.min(2, (n - 1) >> 1), out = new Array(n);
    for (let i = 0; i < n; i++) {
      let sx = 0, sy = 0;
      for (let j = -r; j <= r; j++) { const q = p[(i + j + n) % n]; sx += q[0]; sy += q[1]; }
      out[i] = [sx / (2 * r + 1), sy / (2 * r + 1)];
    }
    return out;
  }

  function loopLen(p) {
    let s = 0;
    for (let i = 0; i < p.length; i++) { const a = p[i], b = p[(i + 1) % p.length]; s += Math.hypot(a[0] - b[0], a[1] - b[1]); }
    return s;
  }

  // Leaga buclele intr-un singur drum: fiecare bucla e inserata in cel mai apropiat punct al
  // drumului de pana acum (dus-intors pe "pod"), ca la o singura linie trasa fara a ridica creionul.
  function joinLoops(loops) {
    let path = loops[0].slice();
    for (let li = 1; li < loops.length; li++) {
      const lp = loops[li];
      const sp = Math.max(1, Math.ceil(path.length / 500)), sl = Math.max(1, Math.ceil(lp.length / 300));
      let best = Infinity, bi = 0, bj = 0;
      for (let i = 0; i < path.length; i += sp) {
        const a = path[i];
        for (let j = 0; j < lp.length; j += sl) {
          const d = (a[0] - lp[j][0]) ** 2 + (a[1] - lp[j][1]) ** 2;
          if (d < best) { best = d; bi = i; bj = j; }
        }
      }
      const rot = lp.slice(bj).concat(lp.slice(0, bj + 1));
      path = path.slice(0, bi + 1).concat(rot, path.slice(bi));
    }
    return path;
  }

  // rect = rama pozei [x0,y0,x1,y1]: desenul e scalat dupa ea, ca sa stea in poza ca in original;
  // rama normalizata e pusa pe rezultat ca .frame
  function resampleNormalize(p, M, rect) {
    const n = p.length, cum = new Float64Array(n + 1);
    for (let i = 0; i < n; i++) { const a = p[i], b = p[(i + 1) % n]; cum[i + 1] = cum[i] + Math.hypot(a[0] - b[0], a[1] - b[1]); }
    const total = cum[n], xs = new Float64Array(M), ys = new Float64Array(M);
    let j = 0;
    for (let k = 0; k < M; k++) {
      const s = total * k / M;
      while (j < n - 1 && cum[j + 1] <= s) j++;
      const a = p[j], b = p[(j + 1) % n], seg = cum[j + 1] - cum[j], f = seg > 0 ? (s - cum[j]) / seg : 0;
      xs[k] = a[0] + (b[0] - a[0]) * f; ys[k] = a[1] + (b[1] - a[1]) * f;
    }
    let mnx = Infinity, mny = Infinity, mxx = -Infinity, mxy = -Infinity;
    for (let k = 0; k < M; k++) { mnx = Math.min(mnx, xs[k]); mxx = Math.max(mxx, xs[k]); mny = Math.min(mny, ys[k]); mxy = Math.max(mxy, ys[k]); }
    if (rect) { mnx = Math.min(mnx, rect[0]); mny = Math.min(mny, rect[1]); mxx = Math.max(mxx, rect[2]); mxy = Math.max(mxy, rect[3]); }
    const bw = Math.max(1, mxx - mnx), bh = Math.max(1, mxy - mny), sc = Math.min(1000 / bw, 800 / bh);
    const ox = (1000 - bw * sc) / 2, flat = new Array(2 * M);
    for (let k = 0; k < M; k++) {
      flat[2 * k] = Math.round((ox + (xs[k] - mnx) * sc) * 10) / 10;
      flat[2 * k + 1] = Math.round((ys[k] - mny) * sc * 10) / 10;
    }
    if (rect) flat.frame = [ox + (rect[0] - mnx) * sc, (rect[1] - mny) * sc, ox + (rect[2] - mnx) * sc, (rect[3] - mny) * sc];
    return flat;
  }

  const fileInput = document.getElementById('fileInput');
  document.getElementById('uploadBtn').onclick = () => fileInput.click();
  fileInput.onchange = () => { if (fileInput.files[0]) loadImageFile(fileInput.files[0]); fileInput.value = ''; };
  document.getElementById('invertBtn').onclick = e => {
    if (!imgSrc) return;
    imgOpt.invert = !imgOpt.invert; e.target.classList.toggle('on', imgOpt.invert); extractAndShow();
  };
  document.getElementById('outerBtn').onclick = e => {
    if (!imgSrc) return;
    imgOpt.outer = !imgOpt.outer; e.target.classList.toggle('on', imgOpt.outer); extractAndShow();
  };
  document.getElementById('detail').onchange = e => { if (imgSrc) { imgOpt.detail = +e.target.value; extractAndShow(); } };
  document.getElementById('modeSil').onclick = () => { if (imgSrc && imgOpt.mode !== 'sil') { setMode('sil'); extractAndShow(); } };
  document.getElementById('personBtn').onclick = e => {
    if (!imgSrc) return;
    imgOpt.person = !imgOpt.person; e.target.classList.toggle('on', imgOpt.person);
    if (imgOpt.person) { imgOpt.obj = false; document.getElementById('objBtn').classList.remove('on'); cv.style.cursor = ''; }
    if (imgOpt.person) withPerson(); else extractAndShow();
  };
  document.getElementById('objBtn').onclick = e => {
    if (!imgSrc) return;
    imgOpt.obj = !imgOpt.obj; e.target.classList.toggle('on', imgOpt.obj);
    cv.style.cursor = imgOpt.obj ? 'crosshair' : '';
    if (imgOpt.obj) { imgOpt.person = false; document.getElementById('personBtn').classList.remove('on'); withObject(); }
    else extractAndShow();
  };
  // in modul "Doar obiectul": click / atingere pe desen (in rama pozei) = alege obiectul de acolo
  cv.addEventListener('click', e => {
    if (!imgOpt.obj || !imgSrc || !frameRect || !L) return;
    const r = cv.getBoundingClientRect(), lx = (e.clientX - r.left) * L.W / r.width, ly = (e.clientY - r.top) * L.H / r.height;
    const dx = (lx - L.mapX) / L.s, dy = (ly - L.mapY) / L.s, f = frameRect;
    const u = (dx - f[0]) / (f[2] - f[0]), v = (dy - f[1]) / (f[3] - f[1]);
    if (u < 0 || u > 1 || v < 0 || v > 1) return;
    imgOpt.objPt = [u, v];
    withObject();
  });
  document.getElementById('modeLin').onclick = () => { if (imgSrc && imgOpt.mode !== 'lin') { setMode('lin'); extractAndShow(); } };
  document.getElementById('thr').onchange = e => { if (imgSrc) { imgOpt.thr = +e.target.value; extractAndShow(); } };
  // trage o imagine peste pagina sau lipeste-o (Ctrl+V)
  ['dragenter', 'dragover'].forEach(ev => document.addEventListener(ev, e => {
    if (!e.dataTransfer || ![...e.dataTransfer.types].includes('Files')) return;
    e.preventDefault(); stage.classList.add('dropping');
  }));
  document.addEventListener('dragleave', e => { if (!e.relatedTarget) stage.classList.remove('dropping'); });
  document.addEventListener('drop', e => {
    stage.classList.remove('dropping');
    if (!e.dataTransfer || !e.dataTransfer.files.length) return;
    e.preventDefault(); loadImageFile(e.dataTransfer.files[0]);
  });
  document.addEventListener('paste', e => {
    const it = [...(e.clipboardData || {}).items || []].find(i => i.type.startsWith('image/'));
    if (it) loadImageFile(it.getAsFile());
  });

  function demo() {
    const c = document.createElement('canvas'); c.width = 400; c.height = 380;
    const g = c.getContext('2d');
    g.fillStyle = '#fff'; g.fillRect(0, 0, 400, 380);
    g.fillStyle = '#000'; g.beginPath();
    for (let i = 0; i <= 200; i++) {            // inima clasica: x = 16 sin^3 t, y = 13 cos t - 5 cos 2t - ...
      const t = 2 * Math.PI * i / 200;
      const x = 16 * Math.sin(t) ** 3, y = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t);
      const px = 200 + x * 11, py = 170 - y * 11;
      i ? g.lineTo(px, py) : g.moveTo(px, py);
    }
    g.fill();
    prepareImage(c);
    imgStatus('Exemplu · încarcă, trage sau lipește (Ctrl+V) o imagine a ta');
  }

  // ---------- rezultat: ecran complet si descarcare PNG ----------
  // Rama: sus, dreapta, jos, stanga, ca o singura linie; f = cat din perimetru (0..1). Intoarce varful.
  function framePath(g, r, f, map) {
    const pts = [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]], [r[0], r[1]]];
    const per = 2 * ((r[2] - r[0]) + (r[3] - r[1]));
    let left = f * per, tip = map(pts[0]);
    g.beginPath(); g.moveTo(tip[0], tip[1]);
    for (let i = 0; i < 4 && left > 0; i++) {
      const a = pts[i], b = pts[i + 1], len = Math.abs(b[0] - a[0]) + Math.abs(b[1] - a[1]), u = Math.min(1, left / len);
      tip = map([a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]);
      g.lineTo(tip[0], tip[1]); left -= len;
    }
    g.stroke();
    return tip;
  }

  // Deseneaza curba reconstruita (la N-ul curent) centrata intr-un canvas oarecare.
  function renderResult(c, W, H, caption) {
    const g = c.getContext('2d');
    c.width = W; c.height = H;
    g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
    let a = Infinity, b = Infinity, A = -Infinity, B = -Infinity;
    for (let i = 0; i < M; i++) { const x = recon.x[i], y = recon.y[i]; if (x < a) a = x; if (x > A) A = x; if (y < b) b = y; if (y > B) B = y; }
    const fr = frameRect;
    if (fr) { a = Math.min(a, fr[0]); b = Math.min(b, fr[1]); A = Math.max(A, fr[2]); B = Math.max(B, fr[3]); }
    const pad = Math.min(W, H) * 0.07, sc = Math.min((W - 2 * pad) / Math.max(1, A - a), (H - 2 * pad) / Math.max(1, B - b));
    const ox = (W - (A - a) * sc) / 2 - a * sc, oy = (H - (B - b) * sc) / 2 - b * sc;
    g.strokeStyle = '#f0b8a0'; g.lineWidth = Math.max(1.2, Math.min(W, H) / 700); g.lineJoin = g.lineCap = 'round';
    g.beginPath();
    for (let i = 0; i <= M; i++) { const j = i % M, x = ox + recon.x[j] * sc, y = oy + recon.y[j] * sc; i ? g.lineTo(x, y) : g.moveTo(x, y); }
    g.stroke();
    if (fr) framePath(g, fr, 1, q => [ox + q[0] * sc, oy + q[1] * sc]);
    if (caption) {
      g.fillStyle = 'rgba(242,237,230,0.45)'; g.font = Math.round(Math.min(W, H) / 55) + 'px Georgia, serif';
      g.textAlign = 'right'; g.fillText('N = ' + curN + ' · no-santos.com/portret.php', W - pad / 2, H - pad / 2);
    }
  }
  const fsView = document.getElementById('fsView'), fsCv = document.getElementById('fsCv');
  function drawFs() {
    if (fsView.hidden) return;
    const d = window.devicePixelRatio || 1;
    renderResult(fsCv, Math.round(fsView.clientWidth * d), Math.round(fsView.clientHeight * d), false);
  }
  function openFs() {
    fsImg.hidden = true; fsHint.hidden = true; fsCv.hidden = false;
    fsView.hidden = false; drawFs();
    if (fsView.requestFullscreen) fsView.requestFullscreen().then(drawFs, () => {});
  }
  function closeFs() {
    fsView.hidden = true; fsImg.hidden = true; fsHint.hidden = true; fsCv.hidden = false; fsImg.removeAttribute('src');
    if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen().catch(() => {});
  }
  // Descarcare. Pe telefon a.download e ignorat des (iOS, browsere din aplicatii), asa ca:
  // 1) foaia de partajare cu fisierul (iOS: "Salvează imaginea", Android: Galerie / Drive ...),
  // 2) link de descarcare clasic, 3) pe ecrane tactile, imaginea afisata pentru "tine apasat -> salveaza".
  // Totul sincron in click, ca browserul sa nu piarda "gestul utilizatorului" inainte de share().
  const fsImg = document.getElementById('fsImg'), fsHint = document.getElementById('fsHint');
  function download() {
    const c = document.createElement('canvas');
    renderResult(c, 2400, 2400, true);
    const url = c.toDataURL('image/png'), name = 'portret-epicicluri-N' + curN + '.png';
    const bin = atob(url.split(',')[1]), u8 = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
    const blob = new Blob([u8], { type: 'image/png' });
    const touch = window.matchMedia && matchMedia('(pointer: coarse)').matches;
    const showImg = () => {                       // varianta de rezerva: imaginea, de salvat cu apasare lunga
      fsImg.src = url; fsImg.hidden = false; fsHint.hidden = false; fsCv.hidden = true; fsView.hidden = false;
    };
    let file = null;
    try { file = new File([blob], name, { type: 'image/png' }); } catch (e) {}
    if (touch && file && navigator.canShare && navigator.canShare({ files: [file] })) {
      navigator.share({ files: [file], title: 'Portret cu epicicluri' })
        .catch(e => { if (!e || e.name !== 'AbortError') showImg(); });
      return;
    }
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 60000);
    if (touch) showImg();
  }
  document.getElementById('fsBtn').onclick = openFs;
  document.getElementById('dlBtn').onclick = download;
  document.getElementById('fsDl').onclick = download;
  document.getElementById('fsClose').onclick = closeFs;
  document.addEventListener('fullscreenchange', () => { if (!document.fullscreenElement && !fsView.hidden) closeFs(); else drawFs(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && !fsView.hidden) closeFs(); });
  window.addEventListener('resize', drawFs);

  demo();

  function init(flat) {
    yMax = 0; restart();
    M = flat.length / 2;
    X = new Float64Array(M); Y = new Float64Array(M);
    for (let i = 0; i < M; i++) { X[i] = flat[2 * i]; Y[i] = flat[2 * i + 1]; if (Y[i] > yMax) yMax = Y[i]; }
    if (frameRect) yMax = Math.max(yMax, frameRect[3]);
    Zre = Float64Array.from(X); Zim = Float64Array.from(Y);
    fft(Zre, Zim, false);
    x0 = Zre[0] / M; y0 = Zim[0] / M;
    // Separate real series: Xk = (Zk + conj Z(M-k))/2, Yk = (Zk - conj Z(M-k))/(2i)
    xTerms = []; yTerms = [];
    for (let k = 1; k < M / 2; k++) {
      const ar = Zre[k], ai = Zim[k], br = Zre[M - k], bi = -Zim[M - k];
      const xr = (ar + br) / 2, xi = (ai + bi) / 2;
      const yr = (ai - bi) / 2, yi = -(ar - br) / 2;
      xTerms.push({ k, r: 2 * Math.hypot(xr, xi) / M, ph: Math.atan2(xi, xr) });
      yTerms.push({ k, r: 2 * Math.hypot(yr, yi) / M, ph: Math.atan2(yi, yr) });
    }
    setN(auto ? 1 : curN);
    resize();
    if (started) return;
    started = true;
    buildControls();
    setN(curN);
    window.addEventListener('resize', resize);
    document.getElementById('loading').remove();
    document.getElementById('controls').hidden = false;
    document.getElementById('readout').hidden = false;
    renderFormulas();
    requestAnimationFrame(frame);
  }

  function renderFormulas() {
    const tryRender = () => {
      if (!window.katex) return false;
      const box = document.getElementById('formulas');
      box.innerHTML = '';
      ['x_N(t) = \\sum_{k=1}^{N} \\left(a_k \\cos kt + b_k \\sin kt\\right)',
       'y_N(t) = \\sum_{k=1}^{N} \\left(c_k \\cos kt + d_k \\sin kt\\right)'].forEach(tex => {
        const d = document.createElement('div');
        katex.render(tex, d, { displayMode: false, throwOnError: false });
        d.style.margin = '0 0 0.6em';
        box.appendChild(d);
      });
      return true;
    };
    if (!tryRender()) window.addEventListener('load', tryRender);
  }

  function setN(n) {
    curN = n;
    const re = new Float64Array(M), im = new Float64Array(M);
    re[0] = Zre[0]; im[0] = Zim[0];
    for (let k = 1; k <= n && k < M / 2; k++) {
      re[k] = Zre[k]; im[k] = Zim[k];
      re[M - k] = Zre[M - k]; im[M - k] = Zim[M - k];
    }
    fft(re, im, true);
    recon = { x: re, y: im };
    let num = 0, den = 0;
    for (let i = 0; i < M; i++) {
      num += (re[i] - X[i]) ** 2 + (im[i] - Y[i]) ** 2;
      den += (X[i] - x0) ** 2 + (Y[i] - y0) ** 2;
    }
    errPct = 100 * Math.sqrt(num / den);
    document.getElementById('nVal').textContent = n;
    document.getElementById('errVal').textContent = errPct >= 10 ? errPct.toFixed(1) : errPct.toFixed(2);
    document.getElementById('nSelect').value = n;
    drawFs();
  }

  function buildControls() {
    const sel = document.getElementById('nSelect');
    NS.forEach(n => sel.add(new Option(n, n)));
    sel.value = curN;
    sel.onchange = () => { setN(+sel.value); restart(); };
    document.getElementById('againBtn').onclick = restart;
  }

  function resize() {
    const w = stage.clientWidth;
    const narrow = w < 600, W_ = 1000;
    // Map box (data is 0..1000 wide), placed bottom-right like in the reel.
    const s = narrow ? 0.7 : 0.6;
    // lantul de sus (x) are nevoie de loc pentru cercurile lui mari: coboara desenul daca e cazul
    const reachX = xTerms.map(t => t.r).sort((a, b) => b - a).slice(0, 3).reduce((a, b) => a + b, 0) * s;
    const xChainY = Math.max(narrow ? 270 : 230, reachX + 10);
    const mapX = W_ - 1000 * s - 10, mapY = Math.max(narrow ? 470 : 450, xChainY + reachX * 0.6 + 40);
    const W = W_, H = Math.round(mapY + yMax * s + (narrow ? 190 : 150));   // logical units
    const dpr = window.devicePixelRatio || 1;
    cv.width = Math.round(w * dpr); cv.height = Math.round(w * H / W * dpr);
    const k = cv.width / W;
    // keep the left chain on canvas: room for its biggest circles
    const reach = yTerms.map(t => t.r).sort((a, b) => b - a).slice(0, 3).reduce((a, b) => a + b, 0) * s;
    const yChainX = Math.max(narrow ? 140 : 170, Math.min(reach + 10, mapX - 30));
    L = { W, H, k, s, mapX, mapY, xChainY, yChainX };
    const ro = document.getElementById('readout');
    ro.style.top = ((mapY + yMax * s + 25) / H * 100) + '%';
    ro.style.left = ((mapX + 500 * s) / W * 100) + '%';
  }

  // Draw a chain of epicycles. comp(t): returns vector of a term. Returns tip.
  function chain(cx, cy, terms, t, vertical) {
    const s = L.s;
    let x = cx, y = cy;
    let drawn = 0;
    ctx.lineWidth = 1 / L.k * 1.1;
    for (let i = 0; i < terms.length; i++) {
      const T = terms[i];
      if (T.k > curN) continue;
      const r = T.r * s, a = T.k * t + T.ph;
      const dx = vertical ? r * Math.sin(a) : r * Math.cos(a);
      const dy = vertical ? r * Math.cos(a) : r * Math.sin(a);
      if (r * L.k > 0.6 && drawn < 700) {
        const alpha = Math.min(0.55, 0.12 + r / 160);
        ctx.strokeStyle = 'rgba(242,237,230,' + alpha.toFixed(3) + ')';
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + dx, y + dy); ctx.stroke();
        drawn++;
      }
      x += dx; y += dy;
    }
    return [x, y];
  }

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.1, (now - last) / 1000); last = now;
    const sp = +document.getElementById('speed').value;
    const dur = 90 * Math.pow(0.04, sp / 100) + 4;     // ~ 4 s .. 94 s per drawing
    if (playing && !done && framing > 0) {          // dupa contur: rama pozei
      framing += dt / Math.min(4, Math.max(1.2, dur * 0.2));
      if (framing >= 1) { framing = 1; done = true; document.getElementById('resultBtns').classList.add('show'); }
    } else if (playing && !done && now >= holdUntil) {
      progress += dt / dur;
      if (progress >= 1) {
        const i = NS.indexOf(curN);
        if (auto && i >= 0 && i < NS.length - 1) {   // "N crește": trece la N-ul urmator pana la 4096
          progress = 0; holdUntil = now + 1800; setN(NS[i + 1]);
        } else if (frameRect) {                      // conturul e gata: urmeaza rama
          progress = 1; framing = 1e-6;
        } else {                                      // gata: ne oprim si aratam butoanele
          progress = 1; done = true;
          document.getElementById('resultBtns').classList.add('show');
        }
      }
    }
    draw(done || framing > 0 || holdUntil > now ? 1 : progress);
    requestAnimationFrame(frame);
  }

  function draw(p) {
    const { k, s, mapX, mapY } = L;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, cv.width, cv.height);
    ctx.setTransform(k, 0, 0, k, 0, 0);
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';

    const idx = Math.min(M - 1, Math.floor(p * M));
    const t = 2 * Math.PI * idx / M;

    // faint target outline
    ctx.strokeStyle = 'rgba(240,184,160,0.07)'; ctx.lineWidth = 1.2 / k;
    ctx.beginPath();
    for (let i = 0; i < M; i += 2) {
      const px = mapX + X[i] * s, py = mapY + Y[i] * s;
      i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    }
    ctx.stroke();

    // traced part of the reconstruction
    ctx.strokeStyle = '#f0b8a0'; ctx.lineWidth = 1.3 / k * Math.max(1, k * 0.9);
    ctx.beginPath();
    for (let i = 0; i <= idx; i++) {
      const px = mapX + recon.x[i] * s, py = mapY + recon.y[i] * s;
      i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    }
    ctx.stroke();

    // epicycles: x on top, y on the left
    const [tx, txy] = chain(mapX + x0 * s, L.xChainY, xTerms, t, false);
    const [tyx, ty] = chain(L.yChainX, mapY + y0 * s, yTerms, t, true);
    const px = mapX + recon.x[idx] * s, py = mapY + recon.y[idx] * s;

    if (framing > 0) {                              // rama, desenata dupa contur
      ctx.strokeStyle = '#f0b8a0'; ctx.lineWidth = 1.3 / k * Math.max(1, k * 0.9);
      const tip = framePath(ctx, frameRect, framing, q => [mapX + q[0] * s, mapY + q[1] * s]);
      if (framing < 1) { ctx.fillStyle = '#f2ede6'; ctx.beginPath(); ctx.arc(tip[0], tip[1], 3, 0, Math.PI * 2); ctx.fill(); }
    }

    ctx.setLineDash([6, 6]); ctx.strokeStyle = 'rgba(242,237,230,0.55)'; ctx.lineWidth = 1 / k * 1.2;
    ctx.beginPath(); ctx.moveTo(tx, txy); ctx.lineTo(px, py); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(tyx, ty); ctx.lineTo(px, py); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#f2ede6';
    ctx.beginPath(); ctx.arc(px, py, 3, 0, Math.PI * 2); ctx.fill();
  }
})();
</script>
</body>
</html>
