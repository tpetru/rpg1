<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Vremea</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #0b0e14;
    --bg-2: #11151e;
    --panel: rgba(255,255,255,0.04);
    --panel-solid: #141924;
    --line: rgba(255,255,255,0.08);
    --ink: #eef1f6;
    --ink-2: #9aa3b2;
    --ink-3: #6b7383;
    --accent: #7cc4ff;
    --warm: #ffa463;
    --cold: #7cc4ff;
    --bad: #ff7a6b;
    --radius: 18px;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; }
  body {
    min-height: 100vh;
    background:
      radial-gradient(1200px 600px at 10% -10%, rgba(124,196,255,0.10), transparent 60%),
      radial-gradient(900px 500px at 110% 10%, rgba(255,164,99,0.08), transparent 60%),
      var(--bg);
    color: var(--ink);
    font-family: 'Inter', system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main { max-width: 980px; margin: 0 auto; padding: 48px 16px 80px; }
  [hidden] { display: none !important; }

  /* ---------- Search hero ---------- */
  .intro { text-align: center; margin-bottom: 28px; }
  .intro h1 {
    margin: 0;
    font-family: 'Space Grotesk', sans-serif;
    font-size: clamp(2rem, 6vw, 3rem);
    letter-spacing: -0.03em;
  }
  .intro p { margin: 8px 0 0; color: var(--ink-2); }

  .search {
    position: relative;
    max-width: 620px; margin: 0 auto;
  }
  .search-icon {
    position: absolute; left: 18px; top: 50%; transform: translateY(-50%);
    color: var(--ink-3); font-size: 1.1rem; pointer-events: none;
  }
  .search input {
    width: 100%;
    padding: 16px 120px 16px 48px;
    background: var(--panel-solid);
    border: 1px solid var(--line);
    border-radius: 999px;
    color: var(--ink); font: inherit; font-size: 1.05rem;
    box-shadow: 0 10px 40px rgba(0,0,0,0.35);
    transition: border-color 0.2s ease, box-shadow 0.2s ease;
  }
  .search input::placeholder { color: var(--ink-3); }
  .search input:focus { outline: none; border-color: rgba(124,196,255,0.6); box-shadow: 0 10px 40px rgba(0,0,0,0.35), 0 0 0 4px rgba(124,196,255,0.12); }
  .search button {
    position: absolute; right: 6px; top: 6px; bottom: 6px;
    padding: 0 22px;
    border: none; border-radius: 999px;
    background: var(--accent); color: #07111d;
    font: inherit; font-weight: 600; cursor: pointer;
    transition: filter 0.15s ease;
  }
  .search button:hover { filter: brightness(1.08); }

  .chips { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; margin-top: 14px; }
  .chip {
    padding: 6px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 999px;
    color: var(--ink-2); font: inherit; font-size: 0.85rem; cursor: pointer;
    transition: border-color 0.15s ease, color 0.15s ease;
  }
  .chip:hover { border-color: var(--accent); color: var(--ink); }

  .status { text-align: center; color: var(--ink-2); font-size: 0.92rem; margin: 18px 0 0; min-height: 1.2em; }
  .status.is-error { color: var(--bad); }
  .spinner {
    display: inline-block; width: 14px; height: 14px; margin-right: 8px; vertical-align: -2px;
    border: 2px solid var(--line); border-top-color: var(--accent); border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .candidates {
    max-width: 620px; margin: 16px auto 0;
    display: grid; gap: 8px;
  }
  .candidate {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    padding: 12px 16px;
    background: var(--panel-solid); border: 1px solid var(--line); border-radius: 14px;
    color: var(--ink); font: inherit; text-align: left; cursor: pointer;
    transition: border-color 0.15s ease, transform 0.15s ease;
  }
  .candidate:hover { border-color: var(--accent); transform: translateY(-1px); }
  .candidate small { color: var(--ink-2); }
  .candidate .pop { color: var(--ink-3); font-size: 0.8rem; white-space: nowrap; }

  /* ---------- Results ---------- */
  #results { margin-top: 36px; display: grid; gap: 16px; animation: rise 0.35s ease both; }
  @keyframes rise { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }

  .card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: var(--radius);
    padding: 22px 24px;
    backdrop-filter: blur(8px);
  }
  .card-title {
    margin: 0 0 16px;
    font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.1em; text-transform: uppercase;
    color: var(--ink-3);
  }

  /* Now hero - tinted by the current weather */
  .now {
    position: relative; overflow: hidden;
    padding: 28px;
    border-radius: 24px;
    border: 1px solid var(--line);
    background: linear-gradient(135deg, #1d3557, #14213d);
  }
  .now[data-sky="clear-day"]   { background: linear-gradient(135deg, #2b7bd6 0%, #5aa9f0 55%, #f7b267 130%); }
  .now[data-sky="clear-night"] { background: linear-gradient(135deg, #0f1c3f 0%, #1d2c5e 60%, #3b3f7a 130%); }
  .now[data-sky="cloudy"]      { background: linear-gradient(135deg, #3a4558 0%, #56627a 70%, #7a869c 130%); }
  .now[data-sky="fog"]         { background: linear-gradient(135deg, #59606d 0%, #7d8592 70%, #a3aab5 130%); }
  .now[data-sky="rain"]        { background: linear-gradient(135deg, #1f3a5a 0%, #2f5578 60%, #4c7aa0 130%); }
  .now[data-sky="snow"]        { background: linear-gradient(135deg, #5d7896 0%, #8fb0cf 65%, #d7e6f5 130%); }
  .now[data-sky="storm"]       { background: linear-gradient(135deg, #1b1530 0%, #33285a 60%, #574a8a 130%); }
  .now::after {
    content: '';
    position: absolute; inset: 0;
    background: radial-gradient(600px 300px at 85% 0%, rgba(255,255,255,0.18), transparent 70%);
    pointer-events: none;
  }
  .now > * { position: relative; z-index: 1; }

  .now-top { display: flex; flex-wrap: wrap; align-items: flex-start; justify-content: space-between; gap: 12px; }
  .city-name { margin: 0; font-family: 'Space Grotesk', sans-serif; font-size: clamp(1.6rem, 4.5vw, 2.3rem); letter-spacing: -0.02em; }
  .city-meta { margin-top: 4px; color: rgba(255,255,255,0.78); font-size: 0.95rem; }
  .route-btn {
    display: inline-flex; align-items: center; gap: 8px;
    padding: 10px 16px;
    background: rgba(255,255,255,0.16);
    border: 1px solid rgba(255,255,255,0.25);
    border-radius: 999px;
    color: #fff; text-decoration: none; font-weight: 600; font-size: 0.88rem;
    backdrop-filter: blur(6px);
    transition: background 0.15s ease;
  }
  .route-btn:hover { background: rgba(255,255,255,0.26); }

  .now-main { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 24px; margin-top: 18px; }
  .now-temp {
    font-family: 'Space Grotesk', sans-serif;
    font-size: clamp(4rem, 14vw, 6.5rem);
    font-weight: 600; line-height: 1; letter-spacing: -0.05em;
  }
  .now-icon { font-size: clamp(3rem, 10vw, 4.5rem); line-height: 1; filter: drop-shadow(0 6px 18px rgba(0,0,0,0.25)); }
  .now-desc { font-size: 1.1rem; font-weight: 600; }
  .now-sub { color: rgba(255,255,255,0.78); font-size: 0.9rem; margin-top: 2px; }

  .now-details { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 20px; }
  .pill {
    padding: 7px 12px;
    background: rgba(0,0,0,0.18);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 999px;
    font-size: 0.85rem;
  }
  .pill b { font-weight: 600; }

  /* Stat tiles */
  .stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
  @media (max-width: 760px) { .stats { grid-template-columns: repeat(2, 1fr); } }
  .stat {
    padding: 16px 18px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 16px;
  }
  .stat-label { display: flex; align-items: center; gap: 6px; font-size: 0.75rem; color: var(--ink-3); text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600; }
  .stat-value { margin-top: 8px; font-family: 'Space Grotesk', sans-serif; font-size: 1.45rem; font-weight: 600; letter-spacing: -0.01em; }
  .stat-note { margin-top: 2px; font-size: 0.8rem; color: var(--ink-2); }
  .is-warm { color: var(--warm); }
  .is-cold { color: var(--cold); }

  /* Forecast */
  .forecast-head { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
  .forecast-head .card-title { margin: 0; }
  .segmented {
    display: inline-flex; padding: 4px;
    background: rgba(0,0,0,0.25); border: 1px solid var(--line); border-radius: 999px;
  }
  .range-btn {
    padding: 7px 16px;
    background: transparent; border: none; border-radius: 999px;
    color: var(--ink-2); font: inherit; font-size: 0.85rem; font-weight: 600; cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .range-btn.is-active { background: var(--ink); color: var(--bg); }
  .range-note { margin: 0 0 12px; color: var(--ink-2); font-size: 0.82rem; }

  .days { display: flex; flex-direction: column; }
  .day {
    display: grid;
    grid-template-columns: 110px 34px 1fr 56px minmax(80px, 2fr) 56px 70px;
    align-items: center; gap: 12px;
    padding: 10px 6px;
    border-top: 1px solid var(--line);
  }
  .day:first-child { border-top: none; }
  .day-date { font-weight: 600; font-size: 0.92rem; }
  .day-date small { display: block; font-weight: 400; color: var(--ink-3); font-size: 0.78rem; }
  .day-icon { font-size: 1.5rem; text-align: center; }
  .day-desc { color: var(--ink-2); font-size: 0.85rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .day-lo, .day-hi { font-variant-numeric: tabular-nums; font-weight: 600; font-size: 0.92rem; }
  .day-lo { text-align: right; color: var(--cold); }
  .day-hi { color: var(--warm); }
  .day-bar { position: relative; height: 6px; border-radius: 999px; background: rgba(255,255,255,0.07); }
  .day-bar span {
    position: absolute; top: 0; bottom: 0;
    border-radius: 999px;
    background: linear-gradient(90deg, var(--cold), var(--warm));
  }
  .day-rain { color: var(--cold); font-size: 0.8rem; text-align: right; white-space: nowrap; }
  .day.is-trend { opacity: 0.6; }
  .day.is-trend .day-bar span { background: repeating-linear-gradient(90deg, var(--ink-3) 0 6px, transparent 6px 10px); }
  .trend-sep {
    margin: 8px 0 2px; padding-top: 12px;
    border-top: 1px dashed var(--line);
    font-size: 0.75rem; color: var(--ink-3); text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600;
  }
  @media (max-width: 640px) {
    .day { grid-template-columns: 74px 28px 44px 1fr 44px; gap: 8px; }
    .day-desc, .day-rain { display: none; }
  }

  /* Fun fact */
  .fact { display: grid; grid-template-columns: 1fr; gap: 18px; align-items: start; }
  .fact.has-image { grid-template-columns: 180px 1fr; }
  @media (max-width: 560px) { .fact.has-image { grid-template-columns: 1fr; } }
  .fact img { width: 100%; aspect-ratio: 4 / 3; object-fit: cover; border-radius: 12px; border: 1px solid var(--line); }
  .fact p { margin: 0 0 10px; line-height: 1.65; color: var(--ink); }
  .fact a { color: var(--accent); text-decoration: none; font-weight: 600; font-size: 0.9rem; }
  .fact a:hover { text-decoration: underline; }

  .skeleton {
    display: inline-block; height: 1em; width: 6em; border-radius: 6px;
    background: linear-gradient(90deg, rgba(255,255,255,0.05), rgba(255,255,255,0.12), rgba(255,255,255,0.05));
    background-size: 200% 100%;
    animation: shimmer 1.2s ease infinite;
    vertical-align: middle;
  }
  @keyframes shimmer { from { background-position: 200% 0; } to { background-position: -200% 0; } }

  footer { margin-top: 40px; text-align: center; color: var(--ink-3); font-size: 0.78rem; }
  footer a { color: var(--ink-2); }
</style>
</head>
<body>
<main>
  <header class="intro">
    <h1>Vremea</h1>
    <p>Prognoză, recorduri istorice și câte ceva despre orice oraș din lume.</p>
  </header>

  <form class="search" id="searchForm" autocomplete="off">
    <span class="search-icon">🔎</span>
    <input type="text" id="cityInput" placeholder="Caută un oraș…" required>
    <button type="submit">Caută</button>
  </form>
  <div class="chips" id="chips">
    <button type="button" class="chip">București</button>
    <button type="button" class="chip">Cluj-Napoca</button>
    <button type="button" class="chip">Paris</button>
    <button type="button" class="chip">Tokyo</button>
    <button type="button" class="chip">New York</button>
    <button type="button" class="chip">Reykjavík</button>
  </div>

  <div class="status" id="status"></div>
  <div class="candidates" id="candidates" hidden></div>

  <section id="results" hidden>
    <div class="now" id="now">
      <div class="now-top">
        <div>
          <h2 class="city-name" id="cityName"></h2>
          <div class="city-meta" id="cityMeta"></div>
        </div>
        <a class="route-btn" id="routeBtn" href="#" target="_blank" rel="noopener">🗺️ Traseu în Google Maps</a>
      </div>
      <div class="now-main">
        <div class="now-temp" id="nowTemp">–</div>
        <div class="now-icon" id="nowIcon"></div>
        <div>
          <div class="now-desc" id="nowDesc"></div>
          <div class="now-sub" id="nowSub"></div>
        </div>
      </div>
      <div class="now-details" id="nowDetails"></div>
    </div>

    <div class="stats">
      <div class="stat">
        <div class="stat-label">📍 Distanța</div>
        <div class="stat-value" id="statDistance"><span class="skeleton"></span></div>
        <div class="stat-note" id="statDistanceNote">față de locația ta</div>
      </div>
      <div class="stat">
        <div class="stat-label">🌡️ Perioada aleasă</div>
        <div class="stat-value" id="statRange"><span class="skeleton"></span></div>
        <div class="stat-note" id="statRangeNote">min / max</div>
      </div>
      <div class="stat">
        <div class="stat-label">🥶 Record minim</div>
        <div class="stat-value is-cold" id="statRecordMin"><span class="skeleton"></span></div>
        <div class="stat-note" id="statRecordMinDate">din 1950 încoace</div>
      </div>
      <div class="stat">
        <div class="stat-label">🔥 Record maxim</div>
        <div class="stat-value is-warm" id="statRecordMax"><span class="skeleton"></span></div>
        <div class="stat-note" id="statRecordMaxDate">din 1950 încoace</div>
      </div>
    </div>

    <div class="card">
      <div class="forecast-head">
        <h3 class="card-title">Prognoza</h3>
        <div class="segmented" id="ranges">
          <button type="button" class="range-btn is-active" data-days="5">5 zile</button>
          <button type="button" class="range-btn" data-days="15">15 zile</button>
          <button type="button" class="range-btn" data-days="30">30 zile</button>
        </div>
      </div>
      <p class="range-note" id="rangeNote" hidden>Prognoza meteo acoperă maxim 16 zile. Zilele de după sunt media istorică a ultimilor 30 de ani pentru aceeași dată.</p>
      <div class="days" id="days"></div>
    </div>

    <div class="card">
      <h3 class="card-title">Știai că…</h3>
      <div class="fact" id="funfact"><p><span class="skeleton" style="width:80%"></span></p></div>
    </div>
  </section>

  <footer>Date: <a href="https://open-meteo.com" target="_blank" rel="noopener">Open-Meteo</a> · <a href="https://www.wikipedia.org" target="_blank" rel="noopener">Wikipedia</a></footer>
</main>

<script>
(function() {
  // [icon zi, icon noapte, descriere, tipul de cer pentru fundalul cardului "acum"]
  var WEATHER_CODES = {
    0: ['☀️', '🌙', 'Cer senin', 'clear'], 1: ['🌤️', '🌙', 'Mai mult senin', 'clear'],
    2: ['⛅', '☁️', 'Parțial noros', 'cloudy'], 3: ['☁️', '☁️', 'Înnorat', 'cloudy'],
    45: ['🌫️', '🌫️', 'Ceață', 'fog'], 48: ['🌫️', '🌫️', 'Ceață cu chiciură', 'fog'],
    51: ['🌦️', '🌧️', 'Burniță slabă', 'rain'], 53: ['🌦️', '🌧️', 'Burniță', 'rain'], 55: ['🌧️', '🌧️', 'Burniță densă', 'rain'],
    56: ['🌧️', '🌧️', 'Burniță înghețată', 'rain'], 57: ['🌧️', '🌧️', 'Burniță înghețată', 'rain'],
    61: ['🌦️', '🌧️', 'Ploaie slabă', 'rain'], 63: ['🌧️', '🌧️', 'Ploaie', 'rain'], 65: ['🌧️', '🌧️', 'Ploaie torențială', 'rain'],
    66: ['🌧️', '🌧️', 'Ploaie înghețată', 'rain'], 67: ['🌧️', '🌧️', 'Ploaie înghețată', 'rain'],
    71: ['🌨️', '🌨️', 'Ninsoare slabă', 'snow'], 73: ['🌨️', '🌨️', 'Ninsoare', 'snow'], 75: ['❄️', '❄️', 'Ninsoare abundentă', 'snow'],
    77: ['❄️', '❄️', 'Grăunțe de zăpadă', 'snow'],
    80: ['🌦️', '🌧️', 'Averse slabe', 'rain'], 81: ['🌧️', '🌧️', 'Averse', 'rain'], 82: ['⛈️', '⛈️', 'Averse puternice', 'storm'],
    85: ['🌨️', '🌨️', 'Averse de ninsoare', 'snow'], 86: ['🌨️', '🌨️', 'Averse de ninsoare', 'snow'],
    95: ['⛈️', '⛈️', 'Furtună', 'storm'], 96: ['⛈️', '⛈️', 'Furtună cu grindină', 'storm'], 99: ['⛈️', '⛈️', 'Furtună cu grindină', 'storm']
  };
  function codeInfo(code, isDay) {
    var c = WEATHER_CODES[code];
    if (!c) return { icon: '❔', desc: '–', sky: 'cloudy' };
    var sky = c[3] === 'clear' ? (isDay === 0 ? 'clear-night' : 'clear-day') : c[3];
    return { icon: isDay === 0 ? c[1] : c[0], desc: c[2], sky: sky };
  }

  var $ = function(id) { return document.getElementById(id); };
  var form = $('searchForm'), input = $('cityInput'), statusEl = $('status');
  var candidatesEl = $('candidates'), resultsEl = $('results'), daysEl = $('days');

  var state = { forecast: null, climate: null, days: 5, place: null };
  var userPos = null, userPosPromise = null;
  var SKELETON = '<span class="skeleton"></span>';

  function setStatus(text, opts) {
    opts = opts || {};
    statusEl.classList.toggle('is-error', !!opts.error);
    statusEl.innerHTML = '';
    if (!text) return;
    if (opts.loading) {
      var s = document.createElement('span');
      s.className = 'spinner';
      statusEl.appendChild(s);
    }
    statusEl.appendChild(document.createTextNode(text));
  }

  function getJson(url) {
    return fetch(url).then(function(res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    });
  }

  function isoDate(d) {
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }
  function parseIso(iso) { return new Date(iso + 'T12:00:00'); }
  function weekday(iso) {
    var s = parseIso(iso).toLocaleDateString('ro-RO', { weekday: 'long' });
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
  function shortDate(iso) { return parseIso(iso).toLocaleDateString('ro-RO', { day: 'numeric', month: 'short' }); }
  function longDate(iso) { return parseIso(iso).toLocaleDateString('ro-RO', { day: 'numeric', month: 'long', year: 'numeric' }); }
  function temp(t) { return Math.round(t) + '°'; }
  function tempPrecise(t) { return (Math.round(t * 10) / 10).toLocaleString('ro-RO') + '°C'; }

  function askUserPosition() {
    if (userPosPromise) return userPosPromise;
    userPosPromise = new Promise(function(resolve) {
      if (!navigator.geolocation) return resolve(null);
      navigator.geolocation.getCurrentPosition(
        function(p) { userPos = { lat: p.coords.latitude, lon: p.coords.longitude }; resolve(userPos); },
        function() { resolve(null); },
        { timeout: 10000, maximumAge: 600000 }
      );
    });
    return userPosPromise;
  }

  function haversineKm(a, b) {
    var R = 6371, rad = Math.PI / 180;
    var dLat = (b.lat - a.lat) * rad, dLon = (b.lon - a.lon) * rad;
    var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 2 * R * Math.asin(Math.sqrt(h));
  }

  // ---------- Search ----------
  $('chips').addEventListener('click', function(e) {
    var chip = e.target.closest('.chip');
    if (!chip) return;
    input.value = chip.textContent;
    form.requestSubmit();
  });

  form.addEventListener('submit', function(e) {
    e.preventDefault();
    var name = input.value.trim();
    if (!name) return;
    askUserPosition();
    candidatesEl.hidden = true;
    setStatus('Caut orașul…', { loading: true });

    getJson('https://geocoding-api.open-meteo.com/v1/search?count=8&language=ro&format=json&name=' + encodeURIComponent(name))
      .then(function(data) {
        var results = data.results || [];
        if (!results.length) { setStatus('Nu am găsit niciun oraș cu numele ăsta.', { error: true }); return; }
        if (results.length === 1) { selectPlace(results[0]); return; }
        setStatus('Am găsit mai multe locuri — alege unul:');
        candidatesEl.innerHTML = '';
        results.forEach(function(r) {
          var btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'candidate';
          btn.innerHTML = '<span><strong></strong><br><small></small></span><span class="pop"></span>';
          btn.querySelector('strong').textContent = r.name;
          btn.querySelector('small').textContent = [r.admin1, r.country].filter(Boolean).join(', ');
          btn.querySelector('.pop').textContent = r.population ? r.population.toLocaleString('ro-RO') + ' loc.' : '';
          btn.addEventListener('click', function() { selectPlace(r); });
          candidatesEl.appendChild(btn);
        });
        candidatesEl.hidden = false;
      })
      .catch(function() { setStatus('Nu s-a putut contacta serviciul de căutare. Încearcă din nou.', { error: true }); });
  });

  function selectPlace(place) {
    state.place = place;
    state.forecast = null;
    state.climate = null;
    candidatesEl.hidden = true;
    setStatus('Încarc vremea…', { loading: true });

    $('cityName').textContent = place.name;
    $('cityMeta').textContent = [place.admin1, place.country].filter(Boolean).join(', ');
    $('statRecordMin').innerHTML = SKELETON;
    $('statRecordMax').innerHTML = SKELETON;
    $('statRecordMinDate').textContent = 'din 1950 încoace';
    $('statRecordMaxDate').textContent = 'din 1950 încoace';
    $('funfact').className = 'fact';
    $('funfact').innerHTML = '<p><span class="skeleton" style="width:80%"></span></p>';
    renderDistance();

    var url = 'https://api.open-meteo.com/v1/forecast?latitude=' + place.latitude + '&longitude=' + place.longitude +
      '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day' +
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,sunrise,sunset' +
      '&timezone=auto&forecast_days=16';
    var placeRef = place;

    getJson(url).then(function(data) {
      if (state.place !== placeRef) return;
      state.forecast = data.daily;
      renderNow(data.current, data.daily);
      renderDays();
      resultsEl.hidden = false;
      setStatus('');
      resultsEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }).catch(function() {
      setStatus('Nu s-a putut încărca prognoza.', { error: true });
    });

    loadHistory(place);
    loadFunFact(place);
  }

  // ---------- Now ----------
  function renderNow(cur, daily) {
    var info = codeInfo(cur.weather_code, cur.is_day);
    $('now').setAttribute('data-sky', info.sky);
    $('nowTemp').textContent = temp(cur.temperature_2m);
    $('nowIcon').textContent = info.icon;
    $('nowDesc').textContent = info.desc;
    $('nowSub').textContent = 'Max ' + temp(daily.temperature_2m_max[0]) + ' · Min ' + temp(daily.temperature_2m_min[0]);

    var details = [
      ['Se simte ca', temp(cur.apparent_temperature)],
      ['Umiditate', cur.relative_humidity_2m + '%'],
      ['Vânt', Math.round(cur.wind_speed_10m) + ' km/h'],
      ['Răsărit', daily.sunrise[0].slice(11, 16)],
      ['Apus', daily.sunset[0].slice(11, 16)]
    ];
    var box = $('nowDetails');
    box.innerHTML = '';
    details.forEach(function(d) {
      var pill = document.createElement('span');
      pill.className = 'pill';
      pill.innerHTML = '<span></span> <b></b>';
      pill.firstChild.textContent = d[0];
      pill.lastChild.textContent = d[1];
      box.appendChild(pill);
    });
  }

  // ---------- History ----------
  function loadHistory(place) {
    // ERA5 are o intarziere de cateva zile fata de prezent, deci ne oprim cu o saptamana in urma.
    var end = new Date(); end.setDate(end.getDate() - 7);
    var url = 'https://archive-api.open-meteo.com/v1/archive?latitude=' + place.latitude + '&longitude=' + place.longitude +
      '&start_date=1950-01-01&end_date=' + isoDate(end) +
      '&daily=temperature_2m_max,temperature_2m_min&timezone=auto';
    var placeRef = place;

    getJson(url).then(function(data) {
      if (state.place !== placeRef) return;
      var d = data.daily;
      var minIdx = -1, maxIdx = -1;
      for (var i = 0; i < d.time.length; i++) {
        var lo = d.temperature_2m_min[i], hi = d.temperature_2m_max[i];
        if (lo !== null && (minIdx < 0 || lo < d.temperature_2m_min[minIdx])) minIdx = i;
        if (hi !== null && (maxIdx < 0 || hi > d.temperature_2m_max[maxIdx])) maxIdx = i;
      }
      $('statRecordMin').textContent = minIdx < 0 ? '–' : tempPrecise(d.temperature_2m_min[minIdx]);
      $('statRecordMinDate').textContent = minIdx < 0 ? '' : longDate(d.time[minIdx]);
      $('statRecordMax').textContent = maxIdx < 0 ? '–' : tempPrecise(d.temperature_2m_max[maxIdx]);
      $('statRecordMaxDate').textContent = maxIdx < 0 ? '' : longDate(d.time[maxIdx]);

      state.climate = buildClimate(d);
      if (state.forecast && state.days > state.forecast.time.length) renderDays();
    }).catch(function() {
      if (state.place !== placeRef) return;
      $('statRecordMin').textContent = '–';
      $('statRecordMax').textContent = '–';
      $('statRecordMinDate').textContent = 'indisponibil';
      $('statRecordMaxDate').textContent = 'indisponibil';
    });
  }

  // Media pe ultimii 30 de ani pentru fiecare zi a anului (cheie "MM-DD") - folosita ca estimare
  // pentru zilele 17-30, unde nicio prognoza gratuita nu mai ajunge.
  function buildClimate(d) {
    var sums = {};
    var cutoffYear = new Date().getFullYear() - 30;
    for (var i = 0; i < d.time.length; i++) {
      if (parseInt(d.time[i].slice(0, 4), 10) < cutoffYear) continue;
      var lo = d.temperature_2m_min[i], hi = d.temperature_2m_max[i];
      if (lo === null || hi === null) continue;
      var key = d.time[i].slice(5);
      if (!sums[key]) sums[key] = { lo: 0, hi: 0, n: 0 };
      sums[key].lo += lo; sums[key].hi += hi; sums[key].n++;
    }
    var out = {};
    Object.keys(sums).forEach(function(k) { out[k] = { lo: sums[k].lo / sums[k].n, hi: sums[k].hi / sums[k].n }; });
    return out;
  }

  // ---------- Fun fact ----------
  function loadFunFact(place) {
    var placeRef = place;
    var el = $('funfact');
    var titles = [place.name + ', ' + place.country, place.name];

    function tryLang(lang, i) {
      if (i >= titles.length) {
        if (lang === 'ro') return tryLang('en', 0);
        el.innerHTML = '<p></p>';
        el.firstChild.textContent = 'N-am găsit nimic interesant despre ' + place.name + '.';
        return;
      }
      getJson('https://' + lang + '.wikipedia.org/api/rest_v1/page/summary/' + encodeURIComponent(titles[i].replace(/ /g, '_')))
        .then(function(data) {
          if (state.place !== placeRef) return;
          if (data.type === 'disambiguation' || !data.extract) throw new Error('no extract');
          el.innerHTML = '';
          if (data.thumbnail && data.thumbnail.source) {
            var img = document.createElement('img');
            img.src = data.thumbnail.source;
            img.alt = place.name;
            img.loading = 'lazy';
            el.appendChild(img);
            el.className = 'fact has-image';
          } else {
            el.className = 'fact';
          }
          var body = document.createElement('div');
          var p = document.createElement('p');
          p.textContent = pickFact(data.extract);
          body.appendChild(p);
          if (data.content_urls && data.content_urls.desktop) {
            var a = document.createElement('a');
            a.href = data.content_urls.desktop.page;
            a.target = '_blank';
            a.rel = 'noopener';
            a.textContent = 'Citește mai mult pe Wikipedia →';
            body.appendChild(a);
          }
          el.appendChild(body);
        })
        .catch(function() {
          if (state.place !== placeRef) return;
          tryLang(lang, i + 1);
        });
    }
    tryLang('ro', 0);
  }

  // Prima propozitie e de obicei o definitie seaca ("X este un oras in Y") - o luam pe urmatoarele,
  // care tind sa fie mai interesante, daca exista.
  function pickFact(extract) {
    var sentences = extract.match(/[^.!?]+[.!?]+/g) || [extract];
    if (sentences.length >= 3) return sentences.slice(1, 3).join(' ').trim();
    return extract.trim();
  }

  // ---------- Distance + route ----------
  // Fara origin, Google Maps porneste traseul din locatia curenta a dispozitivului; cand o avem
  // deja de la browser o trimitem explicit, ca traseul sa fie gata calculat la deschidere.
  function routeUrl(place, pos) {
    var url = 'https://www.google.com/maps/dir/?api=1&destination=' + place.latitude + ',' + place.longitude;
    if (pos) url += '&origin=' + pos.lat + ',' + pos.lon;
    return url;
  }

  function renderDistance() {
    var placeRef = state.place;
    $('statDistance').innerHTML = SKELETON;
    $('statDistanceNote').textContent = 'față de locația ta';
    $('routeBtn').href = routeUrl(placeRef, userPos);
    askUserPosition().then(function(pos) {
      if (state.place !== placeRef) return;
      $('routeBtn').href = routeUrl(placeRef, pos);
      if (!pos) {
        $('statDistance').textContent = '–';
        $('statDistanceNote').textContent = 'permite accesul la locație';
        return;
      }
      var km = haversineKm(pos, { lat: placeRef.latitude, lon: placeRef.longitude });
      $('statDistance').textContent = Math.round(km).toLocaleString('ro-RO') + ' km';
    });
  }

  // ---------- Forecast list ----------
  function renderDays() {
    var f = state.forecast;
    if (!f) return;
    var list = [];
    var available = Math.min(state.days, f.time.length);
    for (var i = 0; i < available; i++) {
      list.push({ date: f.time[i], lo: f.temperature_2m_min[i], hi: f.temperature_2m_max[i], code: f.weather_code[i], rain: f.precipitation_sum[i], trend: false });
    }
    if (state.days > f.time.length && state.climate) {
      var last = parseIso(f.time[f.time.length - 1]);
      for (var j = f.time.length; j < state.days; j++) {
        last.setDate(last.getDate() + 1);
        var iso = isoDate(last);
        var c = state.climate[iso.slice(5)];
        if (c) list.push({ date: iso, lo: c.lo, hi: c.hi, code: null, rain: null, trend: true });
      }
    }

    var minLo = Infinity, maxHi = -Infinity;
    list.forEach(function(day) { minLo = Math.min(minLo, day.lo); maxHi = Math.max(maxHi, day.hi); });
    var span = Math.max(maxHi - minLo, 1);

    $('rangeNote').hidden = state.days <= f.time.length;
    daysEl.innerHTML = '';
    var todayIso = isoDate(new Date());
    var sepAdded = false;

    list.forEach(function(day) {
      if (day.trend && !sepAdded) {
        var sep = document.createElement('div');
        sep.className = 'trend-sep';
        sep.textContent = state.climate ? 'Media istorică' : 'Se încarcă media istorică…';
        daysEl.appendChild(sep);
        sepAdded = true;
      }
      var info = day.trend ? { icon: '📊', desc: 'Medie istorică' } : codeInfo(day.code, 1);
      var row = document.createElement('div');
      row.className = 'day' + (day.trend ? ' is-trend' : '');
      row.innerHTML =
        '<div class="day-date"><span class="dn"></span><small></small></div>' +
        '<div class="day-icon"></div>' +
        '<div class="day-desc"></div>' +
        '<div class="day-lo"></div>' +
        '<div class="day-bar"><span></span></div>' +
        '<div class="day-hi"></div>' +
        '<div class="day-rain"></div>';
      row.querySelector('.dn').textContent = day.date === todayIso ? 'Azi' : weekday(day.date);
      row.querySelector('small').textContent = shortDate(day.date);
      row.querySelector('.day-icon').textContent = info.icon;
      row.querySelector('.day-desc').textContent = info.desc;
      row.querySelector('.day-lo').textContent = temp(day.lo);
      row.querySelector('.day-hi').textContent = temp(day.hi);
      var bar = row.querySelector('.day-bar span');
      bar.style.left = ((day.lo - minLo) / span * 100) + '%';
      bar.style.width = Math.max((day.hi - day.lo) / span * 100, 2) + '%';
      row.querySelector('.day-rain').textContent = day.rain ? '💧 ' + day.rain.toLocaleString('ro-RO') + ' mm' : '';
      daysEl.appendChild(row);
    });

    if (state.days > f.time.length && !state.climate) {
      var wait = document.createElement('div');
      wait.className = 'trend-sep';
      wait.textContent = 'Se încarcă media istorică pentru restul zilelor…';
      daysEl.appendChild(wait);
    }

    if (list.length) {
      $('statRange').innerHTML = '<span class="is-cold"></span> / <span class="is-warm"></span>';
      $('statRange').firstChild.textContent = temp(minLo);
      $('statRange').lastChild.textContent = temp(maxHi);
    }
    $('statRangeNote').textContent = 'min / max · ' + state.days + ' zile';
  }

  $('ranges').addEventListener('click', function(e) {
    var btn = e.target.closest('.range-btn');
    if (!btn) return;
    document.querySelectorAll('.range-btn').forEach(function(b) { b.classList.toggle('is-active', b === btn); });
    state.days = parseInt(btn.getAttribute('data-days'), 10);
    renderDays();
  });
})();
</script>
</body>
</html>
