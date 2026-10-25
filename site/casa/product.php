<?php
require_once __DIR__ . '/_auth.php';
// Detaliu produs, deschis dintr-un rand din shopping.php - graficul complet si tot istoricul de
// verificari de pret pentru un singur produs, cu posibilitatea de a adauga/edita/sterge manual o
// intrare din istoric (util cand o verificare automata a esuat, sau cand pretul e stiut din alta
// sursa, ex. la magazin).
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];
require_once __DIR__ . '/stage_defs.php';
$stageTagText = casa_current_stage_tag($mysqli, $houseId, $stageLabels, $stageCount);

$casaRooms = casa_rooms_for_pages($mysqli, $houseId, $currentHouse['slug']);

function casa_shopping_host(string $url): string
{
    $host = parse_url($url, PHP_URL_HOST);
    return $host ? preg_replace('/^www\./', '', $host) : $url;
}
function casa_shopping_tags(?string $raw): array
{
    if ($raw === null || trim($raw) === '') return [];
    return array_values(array_filter(array_map('trim', explode(',', $raw))));
}

$pid = (int)($_GET['id'] ?? 0);
$stmt = $mysqli->prepare('SELECT id, name, url, room_slug, tags, comment, added_by FROM casa_price_products WHERE id = ? AND house_id = ?');
$stmt->bind_param('ii', $pid, $houseId);
$stmt->execute();
$product = $stmt->get_result()->fetch_assoc();
if (!$product) {
    header('Location: /shopping.php');
    exit;
}
if (!isset($casaRooms[$product['room_slug']])) $product['room_slug'] = 'others';
$tags = casa_shopping_tags($product['tags']);

$history = [];
$mysqli->query('ALTER TABLE casa_price_history ADD COLUMN IF NOT EXISTS unit_price DECIMAL(10,2) NULL AFTER currency');
$stmt = $mysqli->prepare('SELECT id, price, unit_price, currency, ok, error, checked_at FROM casa_price_history WHERE product_id = ? ORDER BY checked_at DESC, id DESC');
$stmt->bind_param('i', $pid);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) $history[] = $row;

$successHistory = array_values(array_filter($history, function ($h) { return (int)$h['ok'] === 1; }));
$latestOk = $successHistory[0] ?? null;
$prevOk = $successHistory[1] ?? null;
// Graficul vrea ordine crescatoare (cel mai vechi -> cel mai nou), istoricul afisat e descrescator.
$chartPoints = array_reverse(array_map(function ($h) {
    return ['t' => strtotime($h['checked_at']) * 1000, 'p' => (float)$h['price']];
}, $successHistory));
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — <?= htmlspecialchars($product['name']) ?></title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  main { max-width: 1100px; margin: 0 auto; padding: 32px 24px 80px; }


  .product-head h1 { margin: 0 0 8px; font-size: 1.7rem; font-weight: 600; letter-spacing: -0.02em; color: var(--ink); }
  .product-host { font-size: 0.85rem; color: var(--ink-2); }
  .product-meta { margin-top: 8px; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
  .product-tag { font: 400 0.68rem var(--mono); color: var(--ink-3); border: 1px solid var(--line-soft); border-radius: 10px; padding: 2px 9px; }
  .product-added-by { font-size: 0.72rem; color: var(--ink-3); }
  .product-comment { margin-top: 10px; font-size: 0.86rem; color: var(--ink-2); font-style: italic; }

  .price-card {
    display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;
    margin-top: 26px; padding: 20px 22px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
  }
  .price-current { font-family: var(--mono); font-weight: 500; font-size: 1.9rem; color: var(--ink); }
  .price-current .cur { font-size: 1rem; color: var(--ink-2); }
  .price-current.is-empty { font-family: var(--disp); font-size: 1rem; font-weight: 500; color: var(--ink-2); }
  .price-trend { font: 400 0.78rem var(--mono); margin-top: 4px; }
  .price-trend.up { color: var(--bad); }
  .price-trend.down { color: var(--good); }
  .check-now-btn {
    padding: 10px 20px; border: 1px solid var(--line); border-radius: 6px;
    background: transparent; color: var(--ink); font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer; transition: border-color 0.2s ease, color 0.2s ease;
  }
  .check-now-btn:hover { border-color: var(--accent); color: var(--accent); }
  .check-now-btn.checking { opacity: 0.6; pointer-events: none; }

  .chart-card { margin-top: 20px; padding: 20px 22px; background: var(--panel); border: 1px solid var(--line); border-radius: 10px; }
  .chart-wrap-large { position: relative; width: 100%; height: 180px; }
  .chart-svg { width: 100%; height: 100%; overflow: visible; }
  .chart-line { fill: none; stroke: var(--accent); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
  .chart-dot { fill: var(--accent); }
  .chart-dot.is-hover { fill: var(--ink); }
  .chart-crosshair { stroke: var(--line-soft); stroke-width: 1; }
  .chart-tooltip {
    position: absolute; pointer-events: none;
    background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    padding: 6px 10px; font-family: var(--mono); font-size: 0.74rem; color: var(--ink);
    white-space: nowrap; transform: translate(-50%, -125%); opacity: 0; transition: opacity 0.1s ease; z-index: 5;
  }
  .chart-tooltip.is-visible { opacity: 1; }
  .chart-empty { text-align: center; color: var(--ink-3); font-family: var(--mono); font-size: 0.82rem; padding: 40px 0; }

  .history-head { display: flex; align-items: center; justify-content: space-between; margin: 28px 0 12px; }
  .history-head h2 { margin: 0; font-size: 1.1rem; font-weight: 600; color: var(--ink); }
  .add-history-btn {
    padding: 8px 16px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent); font-family: var(--disp); font-weight: 600; font-size: 0.82rem;
    cursor: pointer; transition: background 0.2s ease;
  }
  .add-history-btn:hover { background: #c6923a; }

  .history-toolbar { display: flex; gap: 8px; margin-bottom: 10px; }
  .toolbar-btn {
    padding: 7px 14px; border: 1px solid var(--line); border-radius: 6px;
    background: transparent; color: var(--ink-2); font-family: var(--disp); font-weight: 600; font-size: 0.78rem;
    cursor: pointer; transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease, opacity 0.2s ease;
  }
  .toolbar-btn:hover { border-color: var(--accent); color: var(--accent); }
  .toolbar-btn.delete-selected-btn { margin-left: auto; }
  .toolbar-btn.delete-selected-btn:not(:disabled):hover { border-color: var(--bad); color: var(--bad); }
  .toolbar-btn:disabled { opacity: 0.4; cursor: default; border-color: var(--line); color: var(--ink-3); }

  .history-list { display: flex; flex-direction: column; }
  .history-row {
    display: flex; align-items: center; gap: 14px;
    padding: 11px 4px; border-bottom: 1px solid var(--line-soft);
  }
  .history-check { flex-shrink: 0; width: 16px; height: 16px; accent-color: var(--accent); cursor: pointer; }
  .history-date { flex-shrink: 0; width: 130px; font-family: var(--mono); font-size: 0.8rem; color: var(--ink-2); }
  .history-price { flex: 1; font-family: var(--mono); font-size: 0.9rem; color: var(--ink); }
  .history-price .cur { font-size: 0.72rem; color: var(--ink-3); }
  .history-price.is-error { color: var(--bad); font-family: var(--disp); font-size: 0.82rem; }
  .history-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 30px 20px; border: 1px dashed var(--line); border-radius: 8px; margin-top: 8px;
  }

  .history-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .history-modal-backdrop.is-open { display: flex; }
  .history-modal {
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 22px 24px; max-width: 360px; width: 100%;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .history-modal h3 { margin: 0 0 16px; font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--ink); }
  .history-modal .field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
  .history-modal label { font-family: var(--mono); font-size: 0.66rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--ink-3); }
  .history-modal input {
    padding: 9px 12px; background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .history-modal input:focus { outline: none; border-color: var(--accent); }
  .history-modal-actions { display: flex; gap: 8px; margin-top: 4px; }
  .history-modal-actions button {
    padding: 9px 18px; border-radius: 6px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.82rem;
  }
  .history-modal-actions .save-btn { background: var(--accent); color: var(--on-accent); }
  .history-modal-actions .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span><?= htmlspecialchars($currentHouse['name']) ?></span></div>
    <nav id="heroNav">
      <a href="/progres.php">Construcție</a>
      <a href="/design/">Design</a>
      <a href="/links.php">Link-uri</a>
      <a href="/jurnal.php">Jurnal</a>
      <a href="/shopping.php" class="is-current">Lista de cumpărături</a>
      <a href="/index.php?logout=all" class="nav-exit">Ieși</a>
    </nav>
  </div>
  <span class="stage-tag"><?= htmlspecialchars($stageTagText) ?></span>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <a class="back-link" href="/shopping.php"><span class="arrow">←</span> Lista de cumpărături</a>

  <div class="product-head">
    <h1><?= htmlspecialchars($product['name']) ?></h1>
    <a class="product-host" href="<?= htmlspecialchars($product['url']) ?>" target="_blank" rel="noopener noreferrer"><?= htmlspecialchars(casa_shopping_host($product['url'])) ?> ↗</a>
    <div class="product-meta">
      <span class="product-tag"><?= htmlspecialchars($casaRooms[$product['room_slug']]['name']) ?></span>
      <?php foreach ($tags as $tag): ?>
        <span class="product-tag"><?= htmlspecialchars($tag) ?></span>
      <?php endforeach; ?>
      <span class="product-added-by">adăugat de <?= htmlspecialchars($product['added_by'] ?: 'Anonim') ?></span>
    </div>
    <?php if (!empty($product['comment'])): ?>
      <div class="product-comment"><?= htmlspecialchars($product['comment']) ?></div>
    <?php endif; ?>
  </div>

  <div class="price-card">
    <div>
      <?php if ($latestOk): ?>
        <div class="price-current"><?= number_format((float)$latestOk['price'], 2, ',', '.') ?> <span class="cur"><?= htmlspecialchars($latestOk['currency'] ?: 'RON') ?><?= !empty($latestOk['unit_price']) ? '/mp' : '' ?></span></div>
        <?php if ($prevOk && (float)$prevOk['price'] != (float)$latestOk['price']): ?>
          <?php $diff = (float)$latestOk['price'] - (float)$prevOk['price']; ?>
          <div class="price-trend <?= $diff > 0 ? 'up' : 'down' ?>"><?= $diff > 0 ? '▲' : '▼' ?> <?= number_format(abs($diff), 2, ',', '.') ?> față de <?= htmlspecialchars(date('d.m.Y', strtotime($prevOk['checked_at']))) ?></div>
        <?php else: ?>
          <div class="price-trend">verificat <?= htmlspecialchars(date('d.m.Y H:i', strtotime($latestOk['checked_at']))) ?></div>
        <?php endif; ?>
      <?php else: ?>
        <div class="price-current is-empty">Neverificat încă</div>
      <?php endif; ?>
    </div>
    <button type="button" class="check-now-btn" id="checkNowBtn">Verifică acum</button>
  </div>

  <div class="chart-card">
    <?php if (count($chartPoints) >= 2): ?>
      <div class="chart-wrap-large" id="productChart" data-history='<?= json_encode($chartPoints) ?>'></div>
    <?php else: ?>
      <div class="chart-empty">Graficul apare de la a doua verificare reușită.</div>
    <?php endif; ?>
  </div>

  <div class="history-head">
    <h2>Istoric prețuri</h2>
    <button type="button" class="add-history-btn" id="addHistoryBtn">+ Adaugă intrare</button>
  </div>

  <?php if (empty($history)): ?>
    <div class="empty-state" id="historyEmpty">Niciun preț înregistrat încă.</div>
  <?php else: ?>
    <div class="history-toolbar" id="historyToolbar">
      <button type="button" class="toolbar-btn" id="selectAllBtn">Selectează tot</button>
      <button type="button" class="toolbar-btn" id="deselectAllBtn">Deselectează tot</button>
      <button type="button" class="toolbar-btn delete-selected-btn" id="deleteSelectedBtn" disabled>Șterge selectate</button>
    </div>
    <div class="history-list" id="historyList">
      <?php foreach ($history as $h): ?>
        <div class="history-row" data-id="<?= (int)$h['id'] ?>" data-price="<?= htmlspecialchars($h['price'] ?? '') ?>" data-currency="<?= htmlspecialchars($h['currency'] ?? 'RON') ?>" data-checked-at="<?= htmlspecialchars(date('Y-m-d\TH:i', strtotime($h['checked_at']))) ?>">
          <input type="checkbox" class="history-check" title="Selectează">
          <span class="history-date"><?= htmlspecialchars(date('d.m.Y H:i', strtotime($h['checked_at']))) ?></span>
          <?php if ((int)$h['ok'] === 1): ?>
            <span class="history-price"><?= number_format((float)$h['price'], 2, ',', '.') ?> <span class="cur"><?= htmlspecialchars($h['currency'] ?: 'RON') ?><?= !empty($h['unit_price']) ? '/mp' : '' ?></span></span>
          <?php else: ?>
            <span class="history-price is-error"><?= htmlspecialchars($h['error'] ?: 'Eroare la verificare') ?></span>
          <?php endif; ?>
          <div class="history-actions">
            <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
            <button type="button" class="icon-btn delete-btn" title="Șterge">✕</button>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>
</main>

<div class="history-modal-backdrop" id="historyModalBackdrop">
  <div class="history-modal" role="dialog" aria-modal="true">
    <h3 id="historyModalTitle">Adaugă intrare</h3>
    <div class="field">
      <label>Data</label>
      <input type="datetime-local" id="historyDate">
    </div>
    <div class="field">
      <label>Preț</label>
      <input type="number" id="historyPrice" step="0.01" min="0" placeholder="0.00">
    </div>
    <div class="field">
      <label>Monedă</label>
      <input type="text" id="historyCurrency" value="RON" maxlength="8">
    </div>
    <div class="history-modal-actions">
      <button type="button" class="save-btn" id="historySaveBtn">Salvează</button>
      <button type="button" class="cancel-btn" id="historyCancelBtn">Anulează</button>
    </div>
  </div>
</div>

<?php casa_render_footer(); ?>

<script>
(function() {
  var navToggle = document.getElementById('navToggle');
  var heroNav = document.getElementById('heroNav');
  if (navToggle && heroNav) {
    navToggle.addEventListener('click', function() {
      var open = heroNav.classList.toggle('is-open');
      navToggle.classList.toggle('is-open', open);
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
})();

(function() {
  function formatMoney(n) {
    return n.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }
  function formatDate(ts) {
    var d = new Date(ts);
    return ('0' + d.getDate()).slice(-2) + '.' + ('0' + (d.getMonth() + 1)).slice(-2) + '.' + d.getFullYear();
  }

  function renderChart(wrap) {
    var raw = wrap.getAttribute('data-history');
    if (!raw) return;
    var points;
    try { points = JSON.parse(raw); } catch (e) { return; }
    if (!points || points.length < 2) return;

    var width = wrap.clientWidth || 600;
    var height = wrap.clientHeight || 180;
    var padL = 6, padR = 6, padT = 10, padB = 10;

    var minP = Math.min.apply(null, points.map(function(p) { return p.p; }));
    var maxP = Math.max.apply(null, points.map(function(p) { return p.p; }));
    if (minP === maxP) { minP -= 1; maxP += 1; }
    var minT = points[0].t, maxT = points[points.length - 1].t;
    var spanT = Math.max(1, maxT - minT);

    function xFor(t) { return padL + ((t - minT) / spanT) * (width - padL - padR); }
    function yFor(p) { return padT + (1 - (p - minP) / (maxP - minP)) * (height - padT - padB); }

    var svgNS = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(svgNS, 'svg');
    svg.setAttribute('class', 'chart-svg');
    svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
    svg.setAttribute('preserveAspectRatio', 'none');

    var pathD = points.map(function(p, i) {
      return (i === 0 ? 'M' : 'L') + xFor(p.t).toFixed(1) + ',' + yFor(p.p).toFixed(1);
    }).join(' ');
    var path = document.createElementNS(svgNS, 'path');
    path.setAttribute('class', 'chart-line');
    path.setAttribute('d', pathD);
    svg.appendChild(path);

    var lastPoint = points[points.length - 1];
    var lastDot = document.createElementNS(svgNS, 'circle');
    lastDot.setAttribute('class', 'chart-dot');
    lastDot.setAttribute('cx', xFor(lastPoint.t));
    lastDot.setAttribute('cy', yFor(lastPoint.p));
    lastDot.setAttribute('r', 4);
    svg.appendChild(lastDot);

    var crosshair = document.createElementNS(svgNS, 'line');
    crosshair.setAttribute('class', 'chart-crosshair');
    crosshair.setAttribute('y1', padT);
    crosshair.setAttribute('y2', height - padB);
    crosshair.style.display = 'none';
    svg.appendChild(crosshair);

    var hoverDot = document.createElementNS(svgNS, 'circle');
    hoverDot.setAttribute('class', 'chart-dot is-hover');
    hoverDot.setAttribute('r', 4.5);
    hoverDot.style.display = 'none';
    svg.appendChild(hoverDot);

    wrap.innerHTML = '';
    wrap.appendChild(svg);

    var tooltip = document.createElement('div');
    tooltip.className = 'chart-tooltip';
    wrap.appendChild(tooltip);

    var hitArea = document.createElementNS(svgNS, 'rect');
    hitArea.setAttribute('x', 0);
    hitArea.setAttribute('y', 0);
    hitArea.setAttribute('width', width);
    hitArea.setAttribute('height', height);
    hitArea.setAttribute('fill', 'transparent');
    svg.appendChild(hitArea);

    function nearestPoint(mouseX) {
      var t = minT + (mouseX / width) * spanT;
      var best = points[0], bestDist = Infinity;
      points.forEach(function(p) {
        var d = Math.abs(p.t - t);
        if (d < bestDist) { bestDist = d; best = p; }
      });
      return best;
    }

    hitArea.addEventListener('mousemove', function(e) {
      var rect = svg.getBoundingClientRect();
      var mouseX = (e.clientX - rect.left) * (width / rect.width);
      var pt = nearestPoint(mouseX);
      var px = xFor(pt.t), py = yFor(pt.p);
      crosshair.setAttribute('x1', px);
      crosshair.setAttribute('x2', px);
      crosshair.style.display = '';
      hoverDot.setAttribute('cx', px);
      hoverDot.setAttribute('cy', py);
      hoverDot.style.display = '';
      tooltip.textContent = formatDate(pt.t) + ' — ' + formatMoney(pt.p) + ' RON';
      tooltip.style.left = (px / width * 100) + '%';
      tooltip.style.top = (py / height * 100) + '%';
      tooltip.classList.add('is-visible');
    });
    hitArea.addEventListener('mouseleave', function() {
      crosshair.style.display = 'none';
      hoverDot.style.display = 'none';
      tooltip.classList.remove('is-visible');
    });
  }

  var chart = document.getElementById('productChart');
  if (chart) renderChart(chart);
})();

(function() {
  var checkBtn = document.getElementById('checkNowBtn');
  checkBtn.addEventListener('click', function() {
    checkBtn.classList.add('checking');
    fetch('shopping_check.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ id: <?= (int)$pid ?> }).toString()
    }).then(function(res) { return res.json(); }).then(function() {
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut verifica prețul. Încearcă din nou.');
      checkBtn.classList.remove('checking');
    });
  });
})();

(function() {
  var backdrop = document.getElementById('historyModalBackdrop');
  var titleEl = document.getElementById('historyModalTitle');
  var dateInput = document.getElementById('historyDate');
  var priceInput = document.getElementById('historyPrice');
  var currencyInput = document.getElementById('historyCurrency');
  var addBtn = document.getElementById('addHistoryBtn');
  var saveBtn = document.getElementById('historySaveBtn');
  var cancelBtn = document.getElementById('historyCancelBtn');
  var editingId = null;

  function nowLocal() {
    var d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  }

  function openModal(id, price, currency, checkedAt) {
    editingId = id;
    titleEl.textContent = id ? 'Editează intrare' : 'Adaugă intrare';
    dateInput.value = checkedAt || nowLocal();
    priceInput.value = price || '';
    currencyInput.value = currency || 'RON';
    backdrop.classList.add('is-open');
    priceInput.focus();
  }
  function closeModal() {
    backdrop.classList.remove('is-open');
    editingId = null;
  }

  addBtn.addEventListener('click', function() {
    openModal(null, '', 'RON', nowLocal());
  });
  cancelBtn.addEventListener('click', closeModal);
  backdrop.addEventListener('click', function(e) {
    if (e.target === backdrop) closeModal();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && backdrop.classList.contains('is-open')) closeModal();
  });

  document.querySelectorAll('.history-row .edit-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var row = btn.closest('.history-row');
      openModal(row.getAttribute('data-id'), row.getAttribute('data-price'), row.getAttribute('data-currency'), row.getAttribute('data-checked-at'));
    });
  });

  document.querySelectorAll('.history-row .delete-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      if (!confirm('Ștergi această intrare din istoric?')) return;
      var row = btn.closest('.history-row');
      var id = row.getAttribute('data-id');
      fetch('price_history_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge. Încearcă din nou.');
      });
    });
  });

  var checkboxes = document.querySelectorAll('.history-check');
  var selectAllBtn = document.getElementById('selectAllBtn');
  var deselectAllBtn = document.getElementById('deselectAllBtn');
  var deleteSelectedBtn = document.getElementById('deleteSelectedBtn');

  function updateDeleteSelectedState() {
    var anyChecked = Array.prototype.some.call(checkboxes, function(cb) { return cb.checked; });
    deleteSelectedBtn.disabled = !anyChecked;
  }

  checkboxes.forEach(function(cb) {
    cb.addEventListener('change', updateDeleteSelectedState);
  });

  if (selectAllBtn) {
    selectAllBtn.addEventListener('click', function() {
      checkboxes.forEach(function(cb) { cb.checked = true; });
      updateDeleteSelectedState();
    });
  }
  if (deselectAllBtn) {
    deselectAllBtn.addEventListener('click', function() {
      checkboxes.forEach(function(cb) { cb.checked = false; });
      updateDeleteSelectedState();
    });
  }
  if (deleteSelectedBtn) {
    deleteSelectedBtn.addEventListener('click', function() {
      var ids = Array.prototype.filter.call(checkboxes, function(cb) { return cb.checked; })
        .map(function(cb) { return cb.closest('.history-row').getAttribute('data-id'); });
      if (!ids.length) return;
      if (!confirm('Ștergi ' + ids.length + (ids.length === 1 ? ' intrare selectată' : ' intrări selectate') + ' din istoric?')) return;
      fetch('price_history_delete_bulk.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ ids: ids.join(',') }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('bulk delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge. Încearcă din nou.');
      });
    });
  }

  saveBtn.addEventListener('click', function() {
    var date = dateInput.value;
    var price = parseFloat(priceInput.value);
    var currency = currencyInput.value.trim() || 'RON';
    if (!date || isNaN(price) || price < 0) {
      alert('Completează data și un preț valid.');
      return;
    }
    var payload = { checked_at: date, price: price, currency: currency };
    var url;
    if (editingId) {
      payload.id = editingId;
      url = 'price_history_update.php';
    } else {
      payload.product_id = <?= (int)$pid ?>;
      url = 'price_history_add.php';
    }
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(payload).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('save failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut salva. Încearcă din nou.');
    });
  });
})();
</script>

</body>
</html>
