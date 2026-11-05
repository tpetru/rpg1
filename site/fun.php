<?php
// Fun: harta Romaniei (cu judetele) desenata de epicicluri - serie Fourier cu N termeni.
// Inspirat de un reel @epicycle.studio. Pagina statica, fara DB; datele conturului sunt in
// fun/romania-judete.json (generat cu fun/build_path.py din Natural Earth admin-1, 1:10m) si
// fun/judete/<judet>.json (fiecare judet cu comunele lui, din geoBoundaries ROU ADM1/ADM2 simplified).
$judete = [
    'alba' => 'Alba', 'arad' => 'Arad', 'arges' => 'Argeș', 'bacau' => 'Bacău', 'bihor' => 'Bihor',
    'bistrita-nasaud' => 'Bistrița-Năsăud', 'botosani' => 'Botoșani', 'braila' => 'Brăila', 'brasov' => 'Brașov',
    'bucharest' => 'București', 'buzau' => 'Buzău', 'calarasi' => 'Călărași', 'caras-severin' => 'Caraș-Severin',
    'cluj' => 'Cluj', 'constanta' => 'Constanța', 'covasna' => 'Covasna', 'dambovita' => 'Dâmbovița',
    'dolj' => 'Dolj', 'galati' => 'Galați', 'giurgiu' => 'Giurgiu', 'gorj' => 'Gorj', 'harghita' => 'Harghita',
    'hunedoara' => 'Hunedoara', 'ialomita' => 'Ialomița', 'iasi' => 'Iași', 'ilfov' => 'Ilfov',
    'maramures' => 'Maramureș', 'mehedinti' => 'Mehedinți', 'mures' => 'Mureș', 'neamt' => 'Neamț',
    'olt' => 'Olt', 'prahova' => 'Prahova', 'salaj' => 'Sălaj', 'satu-mare' => 'Satu Mare', 'sibiu' => 'Sibiu',
    'suceava' => 'Suceava', 'teleorman' => 'Teleorman', 'timis' => 'Timiș', 'tulcea' => 'Tulcea',
    'valcea' => 'Vâlcea', 'vaslui' => 'Vaslui', 'vrancea' => 'Vrancea',
];
$maps = ['romania' => ['label' => 'România (județe)', 'file' => 'fun/romania-judete.json']];
foreach ($judete as $slug => $label) $maps[$slug] = ['label' => $label . ($slug === 'bucharest' ? ' (sectoare)' : ' (comune)'), 'file' => "fun/judete/$slug.json"];
foreach ($maps as $k => $m) $maps[$k]['file'] .= '?v=' . (int)@filemtime(__DIR__ . '/' . $m['file']);
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Fun · Epicicluri</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<style>
  :root {
    --bg: #000; --ink: #f2ede6; --ink-2: #a39d95; --line: #2a2723;
    --trace: #f0b8a0; --accent: #e8a08a;
  }
  * { box-sizing: border-box; }
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
  .loading { text-align: center; color: var(--ink-2); font-family: system-ui, sans-serif; padding: 40px 0; }
</style>
</head>
<body>
<main>
  <div class="stage" id="stage">
    <canvas id="cv" aria-label="Harta desenata cu epicicluri"></canvas>
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
  <div class="loading" id="loading">Se calculează seria Fourier…</div>

  <div class="controls" id="controls" hidden>
    <div class="group"><label for="mapSelect">Harta:</label><select id="mapSelect"></select></div>
    <div class="group" id="nButtons"><span>N:</span></div>
    <div class="group">
      <button id="autoBtn" title="Dublează N la fiecare desen, de la 1 la 4096">N crește</button>
      <button id="playBtn">Pauză</button>
      <button id="restartBtn">De la capăt</button>
    </div>
    <div class="group">
      <span>Viteză</span><input type="range" id="speed" min="0" max="100" value="45">
    </div>
  </div>
</main>

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
  let progress = 0, playing = true, auto = false, holdUntil = 0;
  let L = null;             // layout

  const MAPS = <?= json_encode($maps, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?>;
  const cache = {};
  let started = false, curMap = null;

  function loadMap(key) {
    if (!MAPS[key]) key = 'romania';
    curMap = key;
    try { history.replaceState(null, '', key === 'romania' ? location.pathname : '?harta=' + key); } catch (e) {}
    mapSel.value = key;
    const p = cache[key] || (cache[key] = fetch(MAPS[key].file).then(r => r.json()));
    p.then(flat => { if (curMap === key) init(flat); }).catch(() => {
      const el = document.getElementById('loading');
      if (el) el.textContent = 'Nu am putut încărca conturul hărții.';
    });
  }
  const mapSel = document.getElementById('mapSelect');
  Object.keys(MAPS).forEach(key => mapSel.add(new Option(MAPS[key].label, key)));
  mapSel.onchange = () => { if (mapSel.value !== curMap) loadMap(mapSel.value); };
  loadMap(new URLSearchParams(location.search).get('harta') || 'romania');

  function init(flat) {
    yMax = 0; progress = 0; holdUntil = 0;
    M = flat.length / 2;
    X = new Float64Array(M); Y = new Float64Array(M);
    for (let i = 0; i < M; i++) { X[i] = flat[2 * i]; Y[i] = flat[2 * i + 1]; if (Y[i] > yMax) yMax = Y[i]; }
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
    document.querySelectorAll('#nButtons button').forEach(b => b.classList.toggle('on', +b.dataset.n === n));
  }

  function buildControls() {
    const box = document.getElementById('nButtons');
    [1, 4, 16, 64, 256, 1024, 4096].forEach(n => {
      const b = document.createElement('button');
      b.textContent = n; b.dataset.n = n;
      b.onclick = () => { auto = false; autoBtn.classList.remove('on'); setN(n); progress = 0; holdUntil = 0; };
      box.appendChild(b);
    });
    const autoBtn = document.getElementById('autoBtn');
    autoBtn.onclick = () => {
      auto = !auto; autoBtn.classList.toggle('on', auto);
      if (auto) { setN(1); progress = 0; holdUntil = 0; }
    };
    const playBtn = document.getElementById('playBtn');
    playBtn.onclick = () => { playing = !playing; playBtn.textContent = playing ? 'Pauză' : 'Pornește'; };
    document.getElementById('restartBtn').onclick = () => { progress = 0; holdUntil = 0; };
  }

  function resize() {
    const w = stage.clientWidth;
    const narrow = w < 600, W_ = 1000;
    // Map box (data is 0..1000 wide), placed bottom-right like in the reel.
    const s = narrow ? 0.7 : 0.6;
    const mapX = W_ - 1000 * s - 10, mapY = narrow ? 470 : 450;
    const W = W_, H = Math.round(mapY + yMax * s + (narrow ? 190 : 150));   // logical units
    const dpr = window.devicePixelRatio || 1;
    cv.width = Math.round(w * dpr); cv.height = Math.round(w * H / W * dpr);
    const k = cv.width / W;
    // keep the left chain on canvas: room for its biggest circles
    const reach = yTerms.map(t => t.r).sort((a, b) => b - a).slice(0, 3).reduce((a, b) => a + b, 0) * s;
    const yChainX = Math.max(narrow ? 140 : 170, Math.min(reach + 10, mapX - 30));
    L = { W, H, k, s, mapX, mapY, xChainY: narrow ? 270 : 230, yChainX };
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
    if (playing && now >= holdUntil) {
      progress += dt / dur;
      if (progress >= 1) {
        progress = 0;
        holdUntil = now + 1800;
        if (auto) {
          const i = NS.indexOf(curN);
          setN(NS[(i + 1) % NS.length]);
        }
      }
    }
    draw(holdUntil > now ? 1 : progress);
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
