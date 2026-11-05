<?php
// Portret: "Desenează-mă" - utilizatorul incarca o imagine (silueta, desen, logo), conturul e extras
// in browser (prag Otsu + marching squares), buclele sunt unite intr-un singur drum inchis si desenat
// cu epicicluri (serie Fourier cu N termeni), in acelasi stil ca fun.php. Imaginea nu pleaca spre server.
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
  .controls .upload { border-color: var(--accent); color: var(--ink); }
  .controls .hint { font-size: 12px; color: var(--ink-2); }
  .dropping canvas { outline: 2px dashed var(--accent); outline-offset: -6px; }
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

  <div class="controls" id="controls" hidden>
    <div class="group" id="nButtons"><span>N:</span></div>
    <div class="group">
      <button id="autoBtn" title="Dublează N la fiecare desen, de la 1 la 4096">N crește</button>
      <button id="playBtn">Pauză</button>
      <button id="restartBtn">De la capăt</button>
    </div>
    <div class="group">
      <span>Viteză</span><input type="range" id="speed" min="0" max="100" value="45">
    </div>
    <div class="group">
      <button id="uploadBtn" class="upload" title="Încarcă o imagine (siluetă, desen, logo) și o desenăm cu epicicluri">✎ Desenează-mă</button>
      <input type="file" id="fileInput" accept="image/*" hidden>
    </div>
    <div class="group" id="imgOpts" hidden>
      <button id="outerBtn" title="Doar cea mai lungă buclă de contur, fără detaliile interioare">Doar conturul exterior</button>
      <button id="invertBtn" title="Schimbă ce e obiect și ce e fundal">Inversează</button>
      <span>Prag</span><input type="range" id="thr" min="1" max="254" value="128" title="Pragul de luminozitate obiect/fundal">
      <span class="hint" id="imgStatus"></span>
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

  let started = false;

  // ---------- "Desenează-mă": contur din imaginea utilizatorului (totul local, in browser) ----------
  const MAXDIM = 480, MAXLOOPS = 120;
  let imgSrc = null;                          // {w, h, v: luminozitate 0..255 (sau opacitate inversata)}
  const imgOpt = { invert: false, outer: false, thr: 128 };
  const imgStatus = t => { document.getElementById('imgStatus').textContent = t; };

  function loadImageFile(file) {
    if (!file || !/^image\//.test(file.type)) { showImgOpts(); imgStatus('Alege un fișier imagine.'); return; }
    const url = URL.createObjectURL(file), img = new Image();
    img.onload = () => { URL.revokeObjectURL(url); prepareImage(img); };
    img.onerror = () => { URL.revokeObjectURL(url); showImgOpts(); imgStatus('Nu am putut citi imaginea.'); };
    img.src = url;
  }

  function prepareImage(img) {
    const iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
    const sc = Math.min(1, MAXDIM / Math.max(iw, ih));
    const w = Math.max(8, Math.round(iw * sc)), h = Math.max(8, Math.round(ih * sc));
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    const g = c.getContext('2d', { willReadFrequently: true });
    g.drawImage(img, 0, 0, w, h);
    const d = g.getImageData(0, 0, w, h).data, n = w * h, v = new Float32Array(n);
    let transp = 0;
    for (let i = 0; i < n; i++) if (d[4 * i + 3] < 128) transp++;
    const useAlpha = transp > n * 0.02;       // PNG cu fundal transparent: obiectul = partea opaca
    for (let i = 0; i < n; i++) {
      const a = d[4 * i + 3] / 255;
      v[i] = useAlpha ? 255 * (1 - a)
        : (0.299 * d[4 * i] + 0.587 * d[4 * i + 1] + 0.114 * d[4 * i + 2]) * a + 255 * (1 - a);
    }
    imgSrc = { w, h, v };
    imgOpt.invert = false;
    document.getElementById('invertBtn').classList.remove('on');
    imgOpt.thr = otsu(v);
    document.getElementById('thr').value = imgOpt.thr;
    extractAndShow();
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

  function showImgOpts() {
    document.getElementById('imgOpts').hidden = false;
  }

  function extractAndShow() {
    showImgOpts();
    const flat = imageToPath();
    if (!flat) { imgStatus('Nu am găsit niciun contur — încearcă alt prag sau „Inversează".'); return; }
    init(flat.path);
    imgStatus(flat.loops + (flat.loops === 1 ? ' buclă' : ' bucle') + ' de contur · imaginea rămâne în browserul tău');
  }

  // masca obiect/fundal -> bucle (marching squares) -> un singur drum inchis -> M puncte, 0..1000
  function imageToPath() {
    const { w, h, v } = imgSrc, thr = imgOpt.thr;
    // fundalul e ce domina pe margine
    let darkBorder = 0, nb = 0;
    for (let x = 0; x < w; x++) { darkBorder += (v[x] < thr) + (v[(h - 1) * w + x] < thr); nb += 2; }
    for (let y = 0; y < h; y++) { darkBorder += (v[y * w] < thr) + (v[y * w + w - 1] < thr); nb += 2; }
    const fgDark = (darkBorder < nb / 2) !== imgOpt.invert;
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
    return { path: resampleNormalize(path, 16384), loops: keep.length };
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

  function resampleNormalize(p, M) {
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
    const bw = Math.max(1, mxx - mnx), bh = Math.max(1, mxy - mny), sc = Math.min(1000 / bw, 800 / bh);
    const ox = (1000 - bw * sc) / 2, flat = new Array(2 * M);
    for (let k = 0; k < M; k++) {
      flat[2 * k] = Math.round((ox + (xs[k] - mnx) * sc) * 10) / 10;
      flat[2 * k + 1] = Math.round((ys[k] - mny) * sc * 10) / 10;
    }
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
  demo();

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
