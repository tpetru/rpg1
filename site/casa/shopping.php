<?php
require_once __DIR__ . '/_auth.php';
// Personal page - a watchlist of product links from various online shops. "Verifică prețurile"
// fetches each URL server-side and tries to read its price from whatever structured data the shop
// publishes (JSON-LD, OpenGraph, microdata) - the same data those shops feed to Google/Facebook, so
// it works across most stores without a custom scraper per site. Not guaranteed for every shop:
// pages that only render their price via client-side JS (no server-rendered/structured price) can't
// be read this way - those show up as a failed check with the actual error, never a fake price.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];
require_once __DIR__ . '/stage_defs.php';
$stageTagText = casa_current_stage_tag($mysqli, $houseId, $stageLabels, $stageCount);

// Same room set/order/labels as casa/design/ and links.php.
$casaRooms = casa_rooms_for_pages($mysqli, $houseId, $currentHouse['slug']);

// Short codes for the floating nav buttons, same as casa/design/ - each room reads at a glance
// instead of showing an identical dot for every one of them.
$roomLetterCodes = [
    'living' => 'L',
    'bucatarie' => 'B',
    'dormitor_matrimonial' => 'D1',
    'dormitor2' => 'D2',
    'dormitor3' => 'D3',
    'baie_dus' => 'Bd',
    'baie_cada' => 'Bc',
    'hol' => 'H',
    'terasa' => 'T',
    'exterior' => 'Ex',
    'others' => 'O',
];
function casa_room_letter_code(string $slug, array $roomLetterCodes): string
{
    if (isset($roomLetterCodes[$slug])) return $roomLetterCodes[$slug];
    return mb_strtoupper(mb_substr($slug, 0, 1));
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_price_products (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        name VARCHAR(150) NOT NULL,
        url VARCHAR(500) NOT NULL,
        room_slug VARCHAR(64) NOT NULL DEFAULT \'others\',
        tags VARCHAR(255) NULL,
        comment VARCHAR(256) NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query("ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS room_slug VARCHAR(64) NOT NULL DEFAULT 'others' AFTER url");
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS tags VARCHAR(255) NULL AFTER room_slug');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS comment VARCHAR(256) NULL AFTER tags');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS priority TINYINT(1) NOT NULL DEFAULT 0 AFTER comment');
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS added_by VARCHAR(60) NULL AFTER priority');
$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_price_history (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        product_id INT UNSIGNED NOT NULL,
        price DECIMAL(10,2) NULL,
        currency VARCHAR(8) NULL,
        ok TINYINT(1) NOT NULL DEFAULT 0,
        error VARCHAR(255) NULL,
        checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY product_checked (product_id, checked_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

$mysqli->query('ALTER TABLE casa_price_history ADD COLUMN IF NOT EXISTS unit_price DECIMAL(10,2) NULL AFTER currency');

$allProducts = [];
$stmt = $mysqli->prepare('SELECT id, name, url, room_slug, tags, comment, priority, added_by FROM casa_price_products WHERE house_id = ? ORDER BY sort_order, id');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    if (!isset($casaRooms[$row['room_slug']])) $row['room_slug'] = 'others';
    $allProducts[] = $row;
}

// Grouped by room, in the same fixed order as design/links - only rooms with at least one
// tracked product show up.
$productsByRoom = [];
foreach ($casaRooms as $slug => $meta) {
    $roomProducts = array_values(array_filter($allProducts, function ($p) use ($slug) { return $p['room_slug'] === $slug; }));
    if ($roomProducts) $productsByRoom[$slug] = $roomProducts;
}

$historyByProduct = [];
if ($allProducts) {
    $ids = implode(',', array_map(function ($p) { return (int)$p['id']; }, $allProducts));
    $histRes = $mysqli->query("SELECT product_id, price, unit_price, currency, ok, error, checked_at FROM casa_price_history WHERE product_id IN ($ids) ORDER BY checked_at ASC");
    while ($row = $histRes->fetch_assoc()) {
        $historyByProduct[(int)$row['product_id']][] = $row;
    }
}

function casa_shopping_host(string $url): string
{
    $host = parse_url($url, PHP_URL_HOST);
    return $host ? preg_replace('/^www\./', '', $host) : $url;
}

// "gresie, baie" -> ["gresie", "baie"], trimmed and empties dropped.
function casa_shopping_tags(?string $raw): array
{
    if ($raw === null || trim($raw) === '') return [];
    return array_values(array_filter(array_map('trim', explode(',', $raw))));
}

// Per-product derived state used both for the row display and the filter pill counts: whether the
// latest check failed outright, or (when it succeeded) whether the price moved down/up/unchanged
// since the previous successful check. Products never checked, or checked only once, stay 'neutral'
// (shown under "Toate" but not counted in any of the scăzut/crescut/eroare pills).
function casa_shopping_status(array $latest = null, array $latestOk = null, array $prevOk = null): string
{
    if ($latest !== null && (int)$latest['ok'] === 0) return 'error';
    if ($latestOk !== null && $prevOk !== null) {
        $diff = (float)$latestOk['price'] - (float)$prevOk['price'];
        if ($diff < 0) return 'down';
        if ($diff > 0) return 'up';
    }
    return 'neutral';
}

$countDown = 0;
$countUp = 0;
$countError = 0;
$productStates = []; // id => ['latest'=>?, 'latestOk'=>?, 'prevOk'=>?, 'status'=>string]
foreach ($allProducts as $product) {
    $pid = (int)$product['id'];
    $history = $historyByProduct[$pid] ?? [];
    $successHistory = array_values(array_filter($history, function ($h) { return (int)$h['ok'] === 1; }));
    $latest = $history ? end($history) : null;
    $latestOk = $successHistory ? end($successHistory) : null;
    $prevOk = count($successHistory) > 1 ? $successHistory[count($successHistory) - 2] : null;
    $status = casa_shopping_status($latest ?: null, $latestOk ?: null, $prevOk ?: null);
    if ($status === 'down') $countDown++;
    elseif ($status === 'up') $countUp++;
    elseif ($status === 'error') $countError++;
    $productStates[$pid] = ['latest' => $latest ?: null, 'latestOk' => $latestOk ?: null, 'prevOk' => $prevOk ?: null, 'successHistory' => $successHistory, 'status' => $status];
}

// "Last run" summary line: the globally most recent check across every product, plus how many
// products landed a check within the same short window (a proxy for "the same batch run", since
// a single "Verifică prețurile" click fires every request back-to-back within a few seconds).
$lastCheckedAt = null;
foreach ($productStates as $state) {
    if (!$state['latest']) continue;
    $ts = strtotime($state['latest']['checked_at']);
    if ($lastCheckedAt === null || $ts > $lastCheckedAt) $lastCheckedAt = $ts;
}
$lastRunOk = 0;
$lastRunTotal = 0;
if ($lastCheckedAt !== null) {
    $windowStart = $lastCheckedAt - 300;
    foreach ($productStates as $state) {
        if (!$state['latest']) continue;
        if (strtotime($state['latest']['checked_at']) >= $windowStart) {
            $lastRunTotal++;
            if ((int)$state['latest']['ok'] === 1) $lastRunOk++;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Lista de cumpărături</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  a { color: var(--accent); text-decoration: none; }

  main { max-width: 1200px; margin: 0 auto; padding: 40px 24px 80px; }

  .failed-checks-warning {
    display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
    margin-bottom: 22px; padding: 12px 16px;
    border: 1px solid var(--bad); border-radius: 8px;
    background: rgba(210,105,79,0.08);
    font-size: 0.85rem; color: var(--ink);
  }
  .failed-checks-warning[hidden] { display: none; }
  .failed-checks-link {
    padding: 0; border: none; background: transparent;
    color: var(--bad); font-family: var(--disp); font-weight: 700; font-size: 0.85rem;
    text-decoration: underline; cursor: pointer;
  }
  .failed-checks-dismiss {
    margin-left: auto; flex-shrink: 0;
    width: 24px; height: 24px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid transparent; border-radius: 5px;
    color: var(--bad); cursor: pointer; font-size: 0.8rem; opacity: 0.75;
    transition: opacity 0.2s ease, border-color 0.2s ease;
  }
  .failed-checks-dismiss:hover { opacity: 1; border-color: var(--bad); }

  .failed-checks-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .failed-checks-modal-backdrop.is-open { display: flex; }
  .failed-checks-modal {
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 22px 24px; max-width: 480px; width: 100%; max-height: 80vh; overflow-y: auto;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .failed-checks-modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
  .failed-checks-modal-head h3 { margin: 0; font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--ink); }
  .failed-checks-modal-close {
    flex-shrink: 0; width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
  }
  .failed-checks-modal-close:hover { border-color: var(--bad); color: var(--bad); }
  .failed-checks-list { display: flex; flex-direction: column; }
  .failed-checks-item { padding: 11px 4px; border-bottom: 1px solid var(--line-soft); }
  .failed-checks-item .name { font-size: 0.9rem; font-weight: 600; color: var(--ink); }
  .failed-checks-item .name a { color: inherit; }
  .failed-checks-item .error { margin-top: 3px; font-family: var(--mono); font-size: 0.74rem; color: var(--ink-3); }

  .shopping-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 30px; flex-wrap: wrap; }
  .shopping-head h1 { margin: 0; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }
  .shopping-head p { margin: 9px 0 0; max-width: 620px; font-size: 0.82rem; line-height: 1.6; color: var(--ink-2); }

  .shopping-actions { display: flex; flex-direction: column; align-items: flex-end; gap: 9px; flex-shrink: 0; }
  .check-all-btn {
    border: none; cursor: pointer;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.82rem;
    padding: 11px 20px; border-radius: 6px;
    transition: background 0.2s ease;
  }
  .check-all-btn:hover { background: #c6923a; }
  .check-all-btn:disabled { opacity: 0.65; cursor: not-allowed; }
  .last-run { font: 400 0.66rem var(--mono); color: var(--ink-3); }

  .filter-bar { display: flex; gap: 10px; margin-top: 26px; align-items: center; flex-wrap: wrap; }
  .filter-label { font: 500 0.66rem var(--mono); letter-spacing: 0.09em; color: var(--ink-3); margin-right: 4px; text-transform: uppercase; }
  .filter-pill {
    font-size: 0.78rem; padding: 5px 12px; border-radius: 14px;
    border: 1px solid var(--line); color: var(--ink-2);
    background: transparent; cursor: pointer; font-family: var(--disp);
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .filter-pill .count { font-family: var(--mono); font-size: 0.7rem; }
  .filter-pill.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }
  .filter-pill:hover:not(.is-active) { border-color: var(--accent); color: var(--ink); }
  .filter-spacer { flex: 1; }
  .sort-select {
    padding: 6px 12px; border: 1px solid var(--line); border-radius: 14px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.78rem; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .sort-select:hover, .sort-select:focus { border-color: var(--accent); color: var(--ink); outline: none; }
  .sort-select option { background: var(--panel); color: var(--ink); }
  .add-toggle-btn {
    display: block; width: 100%;
    padding: 11px 14px;
    margin: 18px 0 20px;
    border: 1px dashed var(--line); border-radius: 6px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.82rem;
    cursor: pointer; text-align: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px; margin: 24px 0;
  }

  .room-card { margin: 0; border: none; background: none; border-radius: 0; }
  .room-card[hidden] { display: none; }
  .room-card summary {
    list-style: none;
    cursor: pointer;
    display: flex; align-items: baseline; gap: 12px;
    margin-top: 34px;
    padding-bottom: 9px;
    border-bottom: 1px solid var(--line);
    font-family: var(--disp); font-weight: 600;
    font-size: 0.88rem; letter-spacing: 0.02em;
    color: var(--ink);
  }
  .room-card summary::-webkit-details-marker { display: none; }
  .room-card summary .room-count { font: 400 0.7rem var(--mono); color: var(--ink-3); font-weight: 400; }
  .room-card-body { padding-left: 14px; }
  .room-card summary::after {
    content: "";
    margin-left: auto;
    width: 7px; height: 7px;
    border-right: 1px solid var(--ink-3);
    border-bottom: 1px solid var(--ink-3);
    transform: rotate(-45deg);
    transition: transform 0.2s ease;
    flex-shrink: 0;
  }
  .room-card[open] summary::after { transform: rotate(45deg); }

  /* Meniu plutitor cu camerele, in dreapta - acelasi tipar ca la casa/design/ */
  .room-floating-nav {
    position: fixed;
    top: 50%;
    right: 18px;
    transform: translateY(-50%);
    display: flex;
    flex-direction: column;
    gap: 6px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 10px 7px;
    z-index: 150;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .room-floating-nav a {
    position: relative;
    display: flex; align-items: center; justify-content: center;
    width: 36px; height: 36px;
    border-radius: 9px;
    font-family: var(--disp);
    font-weight: 700;
    letter-spacing: 0.2px;
    font-size: 0.85rem;
    text-decoration: none;
    color: var(--ink);
    transition: background 0.15s ease;
  }
  .room-floating-nav a:hover { background: rgba(240,236,228,.08); }
  .room-floating-nav a.is-active { background: var(--accent); color: var(--on-accent); }
  .room-floating-nav a.is-active:hover { background: var(--accent); }
  .room-floating-nav a:hover::after {
    content: attr(title);
    position: absolute;
    right: 46px;
    background: var(--panel);
    border: 1px solid var(--line);
    color: var(--ink);
    font-size: 0.78rem;
    padding: 4px 8px;
    border-radius: 6px;
    white-space: nowrap;
    pointer-events: none;
  }
  @media (max-width: 1100px) {
    .room-floating-nav { display: none; }
  }

  /* Burger cu camerele, pentru ecrane inguste unde meniul plutitor lateral nu incape */
  .room-burger-btn {
    display: none;
    position: fixed; right: 16px; bottom: 16px;
    z-index: 160;
    width: 52px; height: 52px;
    align-items: center; justify-content: center;
    flex-direction: column; gap: 5px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    cursor: pointer;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .room-burger-btn span { display: block; width: 22px; height: 2px; background: var(--accent); border-radius: 2px; transition: transform 0.25s ease, opacity 0.2s ease; }
  .room-burger-btn.is-open span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
  .room-burger-btn.is-open span:nth-child(2) { opacity: 0; }
  .room-burger-btn.is-open span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }

  .room-burger-panel {
    display: none;
    position: fixed;
    right: 16px;
    bottom: 80px;
    z-index: 155;
    width: 230px;
    max-width: calc(100vw - 32px);
    max-height: 65vh;
    overflow-y: auto;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 12px;
    box-shadow: 0 14px 34px rgba(0,0,0,0.5);
  }
  .room-burger-panel.is-open { display: block; }
  .room-burger-panel .burger-title {
    text-align: center;
    font-weight: 600;
    font-size: 0.72rem;
    color: var(--accent);
    margin: 2px 0 10px;
  }
  .room-burger-panel .burger-links {
    display: flex; flex-direction: column; gap: 6px;
  }
  .room-burger-panel .burger-links a {
    display: flex; align-items: center; gap: 10px;
    padding: 9px 10px;
    border: 1px solid var(--line-soft);
    border-radius: 8px;
    background: var(--panel);
    color: var(--ink);
    font-weight: 500;
    font-size: 0.76rem;
    text-align: left;
  }
  .room-burger-panel .burger-links a .room-nav-icon {
    flex-shrink: 0;
    width: 20px;
    text-align: center;
    font-size: 1.05rem;
  }
  .room-burger-panel .burger-links a.is-active {
    background: var(--accent);
    border-color: var(--accent);
    color: var(--on-accent);
  }
  @media (max-width: 1100px) {
    .room-burger-btn { display: flex; }
  }

  .product-row {
    display: grid;
    grid-template-columns: 1fr 168px 132px 78px;
    align-items: center;
    gap: 20px;
    padding: 16px 4px;
    border-bottom: 1px solid var(--line-soft);
    cursor: pointer;
  }
  .product-row .product-host, .product-row .product-actions, .product-row .chart-wrap { cursor: default; }
  .product-row[hidden] { display: none; }
  .product-row.is-error {
    border-left: 2px solid var(--bad);
    padding-left: 14px;
    background: rgba(210,105,79,0.05);
    border-radius: 0 5px 5px 0;
  }

  .product-info { min-width: 0; }
  .product-name-row { display: flex; align-items: center; gap: 6px; }
  .product-name { font-size: 0.94rem; font-weight: 600; color: var(--ink); display: block; }

  .priority-crown {
    flex-shrink: 0; width: 22px; height: 22px; padding: 0; margin: 0 0 0 -3px;
    display: inline-flex; align-items: center; justify-content: center;
    border: none; background: transparent; cursor: pointer;
    color: var(--ink-3); opacity: 0.5;
    transition: color 0.2s ease, opacity 0.2s ease, transform 0.15s ease;
  }
  .priority-crown:hover { color: var(--accent); opacity: 0.85; transform: scale(1.1); }
  .priority-crown.is-active { color: var(--accent); opacity: 1; }
  .product-meta { display: flex; align-items: center; gap: 9px; margin-top: 5px; flex-wrap: wrap; }
  .product-host { font: 400 0.69rem var(--mono); color: var(--ink-3); }
  .product-host:hover { color: var(--accent); }
  .product-tag {
    font-size: 0.69rem; color: var(--ink-2);
    background: rgba(240,236,228,.06); border-radius: 10px; padding: 2px 9px;
  }
  .product-added-by { font-size: 0.69rem; color: var(--ink-3); }
  .product-comment { font-size: 0.78rem; color: var(--ink-3); margin-top: 5px; font-style: italic; }
  .product-error-text { font: 400 0.72rem var(--mono); color: var(--bad); margin-top: 6px; }

  .chart-wrap { position: relative; width: 168px; height: 40px; }
  .chart-svg { width: 100%; height: 100%; overflow: visible; }
  .chart-line { fill: none; stroke: var(--accent); stroke-width: 1.75; stroke-linecap: round; stroke-linejoin: round; }
  .chart-dot { fill: var(--accent); }
  .chart-dot.is-hover { fill: var(--ink); }
  .chart-crosshair { stroke: var(--line-soft); stroke-width: 1; }
  .chart-single { font: 400 0.68rem var(--mono); color: var(--ink-3); line-height: 1.4; }
  .chart-tooltip {
    position: absolute;
    pointer-events: none;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 5px;
    padding: 5px 9px;
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--ink);
    white-space: nowrap;
    transform: translate(-50%, -115%);
    opacity: 0;
    transition: opacity 0.1s ease;
    z-index: 5;
  }
  .chart-tooltip.is-visible { opacity: 1; }

  .product-price-block { text-align: right; }
  .product-price { font-family: var(--mono); font-weight: 500; font-size: 1.1rem; color: var(--ink); display: block; }
  .product-price .cur { font-size: 0.72rem; color: var(--ink-2); }
  .product-price.is-empty { font-family: var(--disp); font-size: 0.82rem; font-weight: 500; color: var(--ink-2); }
  .product-trend { font: 400 0.69rem var(--mono); margin-top: 3px; }
  .product-trend.down { color: var(--good); }
  .product-trend.up { color: var(--bad); }
  .product-checked-at { font: 400 0.69rem var(--mono); color: var(--ink-3); margin-top: 3px; }

  .product-actions { display: flex; justify-content: flex-end; }
  .normal-actions, .reorder-actions { display: flex; gap: 6px; }
  .reorder-actions { display: none; }
  #productList.is-manual-sort .normal-actions { display: none; }
  #productList.is-manual-sort .reorder-actions { display: flex; }
  .reorder-btn:disabled { opacity: 0.3; cursor: default; }
  .reorder-btn:disabled:hover { border-color: var(--line); color: var(--ink-3); }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-row-btn:hover { border-color: var(--bad); color: var(--bad); }
  .icon-btn.checking { animation: spin 0.9s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }

  .product-row.is-editing { display: none; }
  .product-edit-row {
    display: none; flex-wrap: wrap; gap: 8px;
    background: var(--panel);
    border: 1px solid var(--accent);
    border-radius: 8px;
    padding: 14px 16px;
    margin-bottom: 16px;
  }
  .product-row.is-editing + .product-edit-row { display: flex; }
  .product-edit-row input, .product-edit-row select {
    padding: 8px 10px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .product-edit-row select[name=edit-room] { width: 150px; }
  .product-edit-row input[name=edit-name] { width: 170px; }
  .product-edit-row input[name=edit-url] { flex: 1; min-width: 200px; font-family: var(--mono); }
  .product-edit-row input[name=edit-tags] { width: 200px; }
  .product-edit-row input[name=edit-comment] { flex-basis: 100%; }
  .product-edit-row input:focus, .product-edit-row select:focus { outline: none; border-color: var(--accent); }
  .product-edit-row .edit-actions { display: flex; gap: 8px; margin-left: auto; }
  .product-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .product-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .product-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .product-edit-row .delete-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .product-edit-row .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .add-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 20px 22px;
    margin-top: 18px;
  }
  .add-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .add-modal-backdrop.is-open { display: flex; }
  .add-modal-backdrop .add-card {
    margin-top: 0; width: 100%; max-width: 640px; max-height: 85vh; overflow-y: auto;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .add-card-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
  .add-card h2 {
    margin: 0;
    font-family: var(--disp); font-weight: 600;
    font-size: 1rem; color: var(--ink);
  }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input, .add-row select {
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row select[name=room] { width: 170px; }
  .add-row input[name=name] { width: 200px; }
  .add-row input[name=url] { flex: 1; min-width: 240px; font-family: var(--mono); }
  .add-row input[name=tags] { width: 220px; }
  .add-row input[name=comment] { flex-basis: 100%; }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
  .add-row button {
    padding: 10px 22px;
    background: var(--accent); border: none; border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-row button:hover { background: #c6923a; }
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

  <div class="failed-checks-warning" id="failedChecksWarning" hidden>
    <span id="failedChecksText"></span>
    <button type="button" class="failed-checks-link" id="failedChecksLink">AICI</button>
    <button type="button" class="failed-checks-dismiss" id="failedChecksDismiss" title="Închide">✕</button>
  </div>

  <?php if (!empty($productsByRoom)): ?>
  <nav class="room-floating-nav" aria-label="Sari la camera">
    <?php foreach ($productsByRoom as $roomSlug => $roomProducts): ?>
      <a href="#room-<?= htmlspecialchars($roomSlug) ?>" title="<?= htmlspecialchars($casaRooms[$roomSlug]['name']) ?>"><span><?= htmlspecialchars(casa_room_letter_code($roomSlug, $roomLetterCodes)) ?></span></a>
    <?php endforeach; ?>
  </nav>

  <button type="button" class="room-burger-btn" id="roomBurgerBtn" aria-label="Camere" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <div class="room-burger-panel" id="roomBurgerPanel">
    <p class="burger-title">Camere</p>
    <div class="burger-links">
      <?php foreach ($productsByRoom as $roomSlug => $roomProducts): ?>
        <a href="#room-<?= htmlspecialchars($roomSlug) ?>"><span class="room-nav-icon"><?= htmlspecialchars($casaRooms[$roomSlug]['icon']) ?></span><?= htmlspecialchars($casaRooms[$roomSlug]['name']) ?></a>
      <?php endforeach; ?>
    </div>
  </div>
  <?php endif; ?>

  <div class="shopping-head">
    <div>
      <h1>Lista de cumpărături</h1>
      <p>Fiecare link trimite la un produs pe un magazin online. Prețurile se verifică automat în fiecare zi la 9:00, sau oricând manual cu „Verifică prețurile" - cel mult o intrare pe zi per produs, actualizată dacă se mai verifică o dată aceeași zi. Când o verificare eșuează, nu se salvează nimic în istoric - apare un avertisment sus, cu produsele afectate.</p>
    </div>
    <div class="shopping-actions">
      <button type="button" class="check-all-btn" id="checkAllBtn">Verifică prețurile</button>
      <span class="last-run" id="lastRun"><?php if ($lastCheckedAt !== null): ?>ultima rulare <?= htmlspecialchars(date('d.m.Y H:i', $lastCheckedAt)) ?> · <?= $lastRunOk ?>/<?= $lastRunTotal ?> ok<?php endif; ?></span>
    </div>
  </div>

  <div class="filter-bar">
    <span class="filter-label">Filtru</span>
    <button type="button" class="filter-pill is-active" data-filter="all">Toate</button>
    <button type="button" class="filter-pill" data-filter="down">A scăzut <span class="count"><?= $countDown ?></span></button>
    <button type="button" class="filter-pill" data-filter="up">A crescut <span class="count"><?= $countUp ?></span></button>
    <button type="button" class="filter-pill" data-filter="error">Eroare <span class="count"><?= $countError ?></span></button>
    <span class="filter-spacer"></span>
    <span class="filter-label">Ordonează</span>
    <select class="sort-select" id="sortSelect">
      <option value="default">Implicit</option>
      <option value="manual" id="manualSortOption">Manual (mută sus/jos)</option>
      <option value="priority">Prioritare primele</option>
      <option value="name-asc">Nume (A-Z)</option>
      <option value="name-desc">Nume (Z-A)</option>
      <option value="price-asc">Preț crescător</option>
      <option value="price-desc">Preț descrescător</option>
    </select>
  </div>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă produs</button>

  <div class="add-modal-backdrop" id="addModalBackdrop">
  <div class="add-card" id="addCard" role="dialog" aria-modal="true">
    <div class="add-card-head">
      <h2>Adaugă produs</h2>
      <button type="button" class="failed-checks-modal-close" id="addModalClose" title="Închide">✕</button>
    </div>
    <div class="add-row">
      <select name="room" id="newRoom">
        <?php foreach ($casaRooms as $slug => $meta): ?>
          <option value="<?= htmlspecialchars($slug) ?>" <?= $slug === 'others' ? 'selected' : '' ?>><?= htmlspecialchars($meta['name']) ?></option>
        <?php endforeach; ?>
      </select>
      <input type="text" name="name" id="newName" placeholder="Nume (opțional)">
      <input type="url" name="url" id="newUrl" placeholder="https://...">
      <input type="text" name="tags" id="newTags" placeholder="Tag-uri, separate prin virgulă (opțional)">
      <input type="text" name="comment" id="newComment" maxlength="256" placeholder="Comentariu (opțional)">
      <button id="addBtn">Adaugă</button>
    </div>
  </div>
  </div>

  <div id="productList">
    <?php if (empty($allProducts)): ?>
      <div class="empty-state" id="emptyState">Niciun produs urmărit încă. Adaugă primul mai sus.</div>
    <?php else: ?>
      <?php foreach ($productsByRoom as $roomSlug => $roomProducts): ?>
        <details class="room-card" id="room-<?= htmlspecialchars($roomSlug) ?>">
          <summary><span><?= htmlspecialchars($casaRooms[$roomSlug]['name']) ?></span><span class="room-count"><?= count($roomProducts) ?> produse</span></summary>
          <div class="room-card-body">
          <?php foreach ($roomProducts as $product): ?>
            <?php
              $pid = (int)$product['id'];
              $state = $productStates[$pid];
              $latest = $state['latest'];
              $latestOk = $state['latestOk'];
              $prevOk = $state['prevOk'];
              $successHistory = $state['successHistory'];
              $status = $state['status'];
              $isError = $latest !== null && (int)$latest['ok'] === 0;
              $tags = casa_shopping_tags($product['tags']);
            ?>
            <?php $isPriority = (int)($product['priority'] ?? 0) === 1; ?>
            <div class="product-row<?= $isError ? ' is-error' : '' ?><?= $isPriority ? ' is-priority' : '' ?>" data-id="<?= $pid ?>" data-status="<?= htmlspecialchars($status) ?>" data-name="<?= htmlspecialchars(mb_strtolower($product['name'])) ?>" data-price="<?= $latestOk ? (float)$latestOk['price'] : '' ?>" data-priority="<?= $isPriority ? 1 : 0 ?>">
              <div class="product-info">
                <div class="product-name-row">
                  <button type="button" class="priority-crown<?= $isPriority ? ' is-active' : '' ?>" title="<?= $isPriority ? 'Prioritar - dă click pentru a scoate' : 'Marchează ca prioritar' ?>">
                    <svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7z"/></svg>
                  </button>
                  <span class="product-name"><?= htmlspecialchars($product['name']) ?></span>
                </div>
                <div class="product-meta">
                  <a class="product-host" href="<?= htmlspecialchars($product['url']) ?>" target="_blank" rel="noopener noreferrer"><?= htmlspecialchars(casa_shopping_host($product['url'])) ?> ↗</a>
                  <span class="product-added-by">adăugat de <?= htmlspecialchars($product['added_by'] ?: 'Anonim') ?></span>
                  <?php foreach ($tags as $tag): ?>
                    <span class="product-tag"><?= htmlspecialchars($tag) ?></span>
                  <?php endforeach; ?>
                </div>
                <?php if (!empty($product['comment'])): ?>
                  <div class="product-comment"><?= htmlspecialchars($product['comment']) ?></div>
                <?php endif; ?>
                <?php if ($isError && !empty($latest['error'])): ?>
                  <div class="product-error-text"><?= htmlspecialchars($latest['error']) ?></div>
                <?php endif; ?>
              </div>

              <?php if (count($successHistory) >= 2): ?>
                <div class="chart-wrap" data-history='<?= json_encode(array_map(function ($h) {
                  return ['t' => strtotime($h['checked_at']) * 1000, 'p' => (float)$h['price']];
                }, $successHistory)) ?>'></div>
              <?php elseif (count($successHistory) === 1 && !$isError): ?>
                <div class="chart-single">o singură verificare — graficul apare de la a doua</div>
              <?php else: ?>
                <div></div>
              <?php endif; ?>

              <div class="product-price-block">
                <?php if ($isError): ?>
                  <span class="product-price is-empty">Neverificat</span>
                  <div class="product-checked-at">încercat <?= htmlspecialchars(date('d.m.Y H:i', strtotime($latest['checked_at']))) ?></div>
                <?php elseif ($latestOk): ?>
                  <span class="product-price"><?= number_format((float)$latestOk['price'], 2, ',', '.') ?> <span class="cur"><?= htmlspecialchars($latestOk['currency'] ?: 'RON') ?><?= !empty($latestOk['unit_price']) ? '/mp' : '' ?></span></span>
                  <?php if ($prevOk && (float)$prevOk['price'] != (float)$latestOk['price']): ?>
                    <?php $diff = (float)$latestOk['price'] - (float)$prevOk['price']; ?>
                    <div class="product-trend <?= $diff > 0 ? 'up' : 'down' ?>"><?= $diff > 0 ? '▲' : '▼' ?> <?= number_format(abs($diff), 2, ',', '.') ?> față de <?= htmlspecialchars(date('d.m', strtotime($prevOk['checked_at']))) ?></div>
                  <?php else: ?>
                    <div class="product-checked-at">verificat <?= htmlspecialchars(date('d.m.Y H:i', strtotime($latest['checked_at']))) ?></div>
                  <?php endif; ?>
                <?php else: ?>
                  <span class="product-price is-empty">Neverificat</span>
                <?php endif; ?>
              </div>

              <div class="product-actions">
                <div class="normal-actions">
                  <button type="button" class="icon-btn check-one-btn" title="Verifică acum">↻</button>
                  <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
                  <button type="button" class="icon-btn delete-row-btn" title="Șterge produsul">✕</button>
                </div>
                <div class="reorder-actions">
                  <button type="button" class="icon-btn reorder-btn" data-dir="up" title="Mută mai sus">▲</button>
                  <button type="button" class="icon-btn reorder-btn" data-dir="down" title="Mută mai jos">▼</button>
                </div>
              </div>
            </div>
            <div class="product-edit-row">
              <select name="edit-room">
                <?php foreach ($casaRooms as $slug => $meta): ?>
                  <option value="<?= htmlspecialchars($slug) ?>" <?= $slug === $roomSlug ? 'selected' : '' ?>><?= htmlspecialchars($meta['name']) ?></option>
                <?php endforeach; ?>
              </select>
              <input type="text" name="edit-name" value="<?= htmlspecialchars($product['name']) ?>" placeholder="Nume">
              <input type="url" name="edit-url" value="<?= htmlspecialchars($product['url']) ?>" placeholder="https://...">
              <input type="text" name="edit-tags" value="<?= htmlspecialchars($product['tags'] ?? '') ?>" placeholder="Tag-uri, separate prin virgulă">
              <input type="text" name="edit-comment" value="<?= htmlspecialchars($product['comment'] ?? '') ?>" maxlength="256" placeholder="Comentariu (opțional)">
              <div class="edit-actions">
                <button type="button" class="save-btn">Salvează</button>
                <button type="button" class="cancel-btn">Anulează</button>
                <button type="button" class="delete-btn">Șterge</button>
              </div>
            </div>
          <?php endforeach; ?>
          </div>
        </details>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>

</main>

<div class="failed-checks-modal-backdrop" id="failedChecksModalBackdrop">
  <div class="failed-checks-modal" role="dialog" aria-modal="true">
    <div class="failed-checks-modal-head">
      <h3>Produse necitite</h3>
      <button type="button" class="failed-checks-modal-close" id="failedChecksModalClose" title="Închide">✕</button>
    </div>
    <div class="failed-checks-list" id="failedChecksList"></div>
  </div>
</div>

<?php casa_render_footer(); ?>

<script>
// Ce camere erau deschise (elementele <details> de mai jos) - tinut in sessionStorage, ca sa
// supraviețuiască reload-ul de pagina facut dupa "Verifică prețurile"/verificarea unui produs, in
// loc sa se inchida toate camerele la fiecare verificare.
(function() {
  var CASA_OPEN_ROOMS_KEY = 'casa_shopping_open_rooms';
  var roomCards = document.querySelectorAll('.room-card');
  if (!roomCards.length) return;

  var openIds = [];
  try {
    var raw = sessionStorage.getItem(CASA_OPEN_ROOMS_KEY);
    openIds = raw ? JSON.parse(raw) : [];
  } catch (e) {}

  roomCards.forEach(function(details) {
    if (openIds.indexOf(details.id) !== -1) details.open = true;
    details.addEventListener('toggle', function() {
      var current = Array.prototype.filter.call(roomCards, function(d) { return d.open; }).map(function(d) { return d.id; });
      try { sessionStorage.setItem(CASA_OPEN_ROOMS_KEY, JSON.stringify(current)); } catch (e) {}
    });
  });
})();

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

  // Burger cu camerele (ecrane inguste unde meniul plutitor lateral nu incape)
  var burgerBtn = document.getElementById('roomBurgerBtn');
  var burgerPanel = document.getElementById('roomBurgerPanel');
  if (burgerBtn && burgerPanel) {
    var closeBurger = function() {
      burgerPanel.classList.remove('is-open');
      burgerBtn.classList.remove('is-open');
      burgerBtn.setAttribute('aria-expanded', 'false');
    };
    burgerBtn.addEventListener('click', function() {
      var open = burgerPanel.classList.toggle('is-open');
      burgerBtn.classList.toggle('is-open', open);
      burgerBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    burgerPanel.querySelectorAll('a').forEach(function(a) {
      a.addEventListener('click', closeBurger);
    });
    document.addEventListener('click', function(e) {
      if (!burgerPanel.classList.contains('is-open')) return;
      if (burgerPanel.contains(e.target) || burgerBtn.contains(e.target)) return;
      closeBurger();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') closeBurger();
    });
  }

  // Evidentiaza camera curenta (in ambele meniuri) pe masura ce se deruleaza pagina
  var roomSections = document.querySelectorAll('.room-card');
  var navLinks = document.querySelectorAll('.room-floating-nav a, .room-burger-panel .burger-links a');
  if (roomSections.length && navLinks.length && 'IntersectionObserver' in window) {
    var setActive = function(slug) {
      navLinks.forEach(function(a) {
        a.classList.toggle('is-active', a.getAttribute('href') === '#' + slug);
      });
    };
    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) setActive(entry.target.id);
      });
    }, { rootMargin: '-40% 0px -55% 0px' });
    roomSections.forEach(function(section) { observer.observe(section); });
    setActive(roomSections[0].id);
  }

  // "+ Adaugă produs" opens the add form in a popup; closes with the X, Escape or a click outside.
  var addToggleBtn = document.getElementById('addToggleBtn');
  var addModal = document.getElementById('addModalBackdrop');
  if (addToggleBtn && addModal) {
    var closeAddModal = function() { addModal.classList.remove('is-open'); };
    addToggleBtn.addEventListener('click', function() {
      addModal.classList.add('is-open');
      document.getElementById('newUrl').focus();
    });
    document.getElementById('addModalClose').addEventListener('click', closeAddModal);
    addModal.addEventListener('click', function(e) { if (e.target === addModal) closeAddModal(); });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && addModal.classList.contains('is-open')) closeAddModal();
    });
  }

  // Filter pills: show/hide product rows by their derived status, and hide a room entirely once
  // none of its rows match (rather than leaving an empty, confusing room header behind).
  var filterPills = document.querySelectorAll('.filter-pill');
  var roomCards = document.querySelectorAll('.room-card');
  function applyFilter(filter) {
    roomCards.forEach(function(room) {
      var anyVisible = false;
      room.querySelectorAll('.product-row').forEach(function(row) {
        var match = filter === 'all' || row.getAttribute('data-status') === filter;
        row.hidden = !match;
        var editRow = row.nextElementSibling;
        if (editRow && editRow.classList.contains('product-edit-row') && !match) {
          row.classList.remove('is-editing');
        }
        if (match) anyVisible = true;
      });
      room.hidden = !anyVisible;
    });
  }
  // Ordonarea manuală n-are sens pe o listă filtrată (nu vezi toate produsele ca să le aranjezi
  // corect intre ele) - se dezactivează optiunea din dropdown cat timp un filtru e activ.
  var sortSelectForFilters = document.getElementById('sortSelect');
  var manualSortOption = document.getElementById('manualSortOption');
  filterPills.forEach(function(pill) {
    pill.addEventListener('click', function() {
      filterPills.forEach(function(p) { p.classList.toggle('is-active', p === pill); });
      var filter = pill.getAttribute('data-filter');
      applyFilter(filter);
      if (manualSortOption) {
        manualSortOption.disabled = filter !== 'all';
        if (filter !== 'all' && sortSelectForFilters && sortSelectForFilters.value === 'manual') {
          sortSelectForFilters.value = 'default';
          sortSelectForFilters.dispatchEvent(new Event('change'));
        }
      }
    });
  });
})();

// Ordonarea produselor DIN INTERIORUL fiecărei camere (nu le amestecă între camere) - "Implicit"
// revine la ordinea din pagină la încărcare, restul citesc atributele data-* de pe fiecare rând.
// "Manual" arată butoanele ▲▼ (vezi wireRow) în loc de sortare calculată - butoanele astea scriu
// direct in sort_order prin shopping_reorder.php, deci "Implicit" de dupa reflecta mereu ce ai
// aranjat manual ultima oara.
var CASA_ROOM_DEFAULT_ORDER = new Map();

function casaRowPairs(body) {
  return Array.prototype.map.call(body.querySelectorAll('.product-row'), function(row) {
    var editRow = row.nextElementSibling;
    if (!editRow || !editRow.classList.contains('product-edit-row')) editRow = null;
    return { row: row, editRow: editRow };
  });
}

// Apelat dupa un reorder manual reusit, ca "Implicit" sa reflecte noua ordine fara reload.
function casaRefreshDefaultOrder(body) {
  CASA_ROOM_DEFAULT_ORDER.set(body, Array.prototype.map.call(body.querySelectorAll('.product-row'), function(r) {
    return r.getAttribute('data-id');
  }));
}

(function() {
  var sortSelect = document.getElementById('sortSelect');
  if (!sortSelect) return;

  var productList = document.getElementById('productList');
  var roomBodies = document.querySelectorAll('.room-card-body');
  roomBodies.forEach(casaRefreshDefaultOrder);

  function sortPairs(pairs, mode, order) {
    if (mode === 'default' || mode === 'manual') {
      pairs.sort(function(a, b) {
        return order.indexOf(a.row.getAttribute('data-id')) - order.indexOf(b.row.getAttribute('data-id'));
      });
      return pairs;
    }
    function priceOf(p) {
      var v = p.row.getAttribute('data-price');
      return v === '' ? null : parseFloat(v);
    }
    pairs.sort(function(a, b) {
      if (mode === 'priority') {
        var pa = a.row.getAttribute('data-priority'), pb = b.row.getAttribute('data-priority');
        if (pa !== pb) return pb - pa;
        return a.row.getAttribute('data-name') < b.row.getAttribute('data-name') ? -1 : 1;
      }
      if (mode === 'name-asc' || mode === 'name-desc') {
        var na = a.row.getAttribute('data-name'), nb = b.row.getAttribute('data-name');
        var cmp = na < nb ? -1 : (na > nb ? 1 : 0);
        return mode === 'name-asc' ? cmp : -cmp;
      }
      if (mode === 'price-asc' || mode === 'price-desc') {
        var pra = priceOf(a), prb = priceOf(b);
        if (pra === null && prb === null) return 0;
        if (pra === null) return 1;
        if (prb === null) return -1;
        return mode === 'price-asc' ? pra - prb : prb - pra;
      }
      return 0;
    });
    return pairs;
  }

  sortSelect.addEventListener('change', function() {
    var mode = sortSelect.value;
    if (productList) productList.classList.toggle('is-manual-sort', mode === 'manual');
    roomBodies.forEach(function(body) {
      var pairs = sortPairs(casaRowPairs(body), mode, CASA_ROOM_DEFAULT_ORDER.get(body));
      pairs.forEach(function(pair) {
        body.appendChild(pair.row);
        if (pair.editRow) body.appendChild(pair.editRow);
      });
    });
  });
})();

(function() {
  function formatMoney(n) {
    return n.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }
  function formatDate(ts) {
    var d = new Date(ts);
    return ('0' + d.getDate()).slice(-2) + '.' + ('0' + (d.getMonth() + 1)).slice(-2) + '.' + d.getFullYear();
  }

  // A compact sparkline sized to fit inline in the row: thin line, rounded caps, hover
  // crosshair + tooltip. No axis labels - there isn't room at this size, and the tooltip covers
  // the same information on demand.
  function renderChart(wrap) {
    var raw = wrap.getAttribute('data-history');
    if (!raw) return;
    var points;
    try { points = JSON.parse(raw); } catch (e) { return; }
    if (!points || points.length < 2) return;

    var width = wrap.clientWidth || 168;
    var height = wrap.clientHeight || 40;
    var padL = 3, padR = 3, padT = 5, padB = 5;

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
    lastDot.setAttribute('r', 3);
    svg.appendChild(lastDot);

    var crosshair = document.createElementNS(svgNS, 'line');
    crosshair.setAttribute('class', 'chart-crosshair');
    crosshair.setAttribute('y1', padT);
    crosshair.setAttribute('y2', height - padB);
    crosshair.style.display = 'none';
    svg.appendChild(crosshair);

    var hoverDot = document.createElementNS(svgNS, 'circle');
    hoverDot.setAttribute('class', 'chart-dot is-hover');
    hoverDot.setAttribute('r', 3.5);
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

  function wireRow(row) {
    var id = row.getAttribute('data-id');

    var chartWrap = row.querySelector('.chart-wrap');
    if (chartWrap) renderChart(chartWrap);

    // Un click oriunde pe rand (in afara de link-ul extern, butoanele de acțiune, sau graficul cu
    // hover propriu) duce la pagina de detaliu a produsului, cu tot istoricul de preț.
    row.addEventListener('click', function(e) {
      if (e.target.closest('.product-actions, .product-host, .chart-wrap, .priority-crown')) return;
      window.location.href = 'product.php?id=' + id;
    });

    var crownBtn = row.querySelector('.priority-crown');
    if (crownBtn) {
      crownBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        fetch('shopping_toggle_priority.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('toggle failed');
          crownBtn.classList.toggle('is-active', data.priority);
          row.classList.toggle('is-priority', data.priority);
          crownBtn.title = data.priority ? 'Prioritar - dă click pentru a scoate' : 'Marchează ca prioritar';
        }).catch(function() {
          alert('Nu s-a putut actualiza. Încearcă din nou.');
        });
      });
    }

    row.querySelectorAll('.reorder-btn').forEach(function(btn) {
      btn.addEventListener('click', function(e) {
        e.stopPropagation();
        var direction = btn.getAttribute('data-dir');
        fetch('shopping_reorder.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, direction: direction }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('reorder failed');
          if (!data.moved) return;
          var body = row.closest('.room-card-body');
          var pairs = casaRowPairs(body);
          var idx = pairs.findIndex(function(p) { return p.row === row; });
          var swapIdx = direction === 'up' ? idx - 1 : idx + 1;
          if (idx === -1 || swapIdx < 0 || swapIdx >= pairs.length) return;
          var tmp = pairs[idx];
          pairs[idx] = pairs[swapIdx];
          pairs[swapIdx] = tmp;
          pairs.forEach(function(pair) {
            body.appendChild(pair.row);
            if (pair.editRow) body.appendChild(pair.editRow);
          });
          casaRefreshDefaultOrder(body);
        }).catch(function() {
          alert('Nu s-a putut reordona. Încearcă din nou.');
        });
      });
    });

    row.querySelector('.check-one-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      var btn = this;
      btn.classList.add('checking');
      fetch('shopping_check.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (data.ok) updateFailedChecksAfterCheck(data.results, false);
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut verifica prețul. Încearcă din nou.');
      }).finally(function() {
        btn.classList.remove('checking');
      });
    });

    function deleteProduct() {
      if (!confirm('Ștergi acest produs din listă (și tot istoricul de preț)?')) return;
      fetch('shopping_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        var editRow = row.nextElementSibling;
        row.remove();
        if (editRow && editRow.classList.contains('product-edit-row')) editRow.remove();
        if (!document.querySelector('.product-row')) location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge produsul. Încearcă din nou.');
      });
    }

    row.querySelector('.delete-row-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      deleteProduct();
    });

    var editRow = row.nextElementSibling;
    row.querySelector('.edit-btn').addEventListener('click', function() {
      row.classList.add('is-editing');
    });
    if (editRow && editRow.classList.contains('product-edit-row')) {
      editRow.querySelector('.cancel-btn').addEventListener('click', function() {
        row.classList.remove('is-editing');
      });
      editRow.querySelector('.save-btn').addEventListener('click', function() {
        var room = editRow.querySelector('[name=edit-room]').value;
        var name = editRow.querySelector('[name=edit-name]').value.trim();
        var url = editRow.querySelector('[name=edit-url]').value.trim();
        var tags = editRow.querySelector('[name=edit-tags]').value.trim();
        var comment = editRow.querySelector('[name=edit-comment]').value.trim();
        if (!url) {
          alert('Completează cel puțin URL-ul.');
          return;
        }
        if (!/^https?:\/\//i.test(url)) url = 'https://' + url;

        fetch('shopping_update.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, room: room, name: name, url: url, tags: tags, comment: comment }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('update failed');
          location.reload();
        }).catch(function() {
          alert('Nu s-a putut salva modificarea. Verifică URL-ul și încearcă din nou.');
        });
      });
      editRow.querySelector('.delete-btn').addEventListener('click', deleteProduct);
    }
  }

  document.querySelectorAll('.product-row').forEach(wireRow);

  var checkAllBtn = document.getElementById('checkAllBtn');
  checkAllBtn.addEventListener('click', function() {
    if (!document.querySelector('.product-row')) {
      alert('Adaugă cel puțin un produs mai întâi.');
      return;
    }
    checkAllBtn.disabled = true;
    checkAllBtn.textContent = 'Se verifică...';

    fetch('shopping_check.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: ''
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('check failed');
      updateFailedChecksAfterCheck(data.results, true);
      location.reload();
    }).catch(function() {
      checkAllBtn.disabled = false;
      checkAllBtn.textContent = 'Verifică prețurile';
      alert('A eșuat verificarea. Încearcă din nou.');
    });
  });

  var roomInput = document.getElementById('newRoom');
  var nameInput = document.getElementById('newName');
  var urlInput = document.getElementById('newUrl');
  var tagsInput = document.getElementById('newTags');
  var commentInput = document.getElementById('newComment');
  var addBtn = document.getElementById('addBtn');
  addBtn.addEventListener('click', function() {
    var room = roomInput.value;
    var name = nameInput.value.trim();
    var url = urlInput.value.trim();
    var tags = tagsInput.value.trim();
    var comment = commentInput.value.trim();
    if (!url) {
      alert('Completează cel puțin URL-ul.');
      return;
    }
    if (!/^https?:\/\//i.test(url)) url = 'https://' + url;

    fetch('shopping_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ room: room, name: name, url: url, tags: tags, comment: comment }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut adăuga produsul. Verifică URL-ul și încearcă din nou.');
    });
  });

  [nameInput, urlInput, tagsInput, commentInput].forEach(function(input) {
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') addBtn.click();
    });
  });
})();

// Produsele care n-au putut fi citite la ultima verificare (din browser-ul curent) - nu se scrie
// nimic in baza de date pentru asta, doar sessionStorage, deci dispare cand se inchide tab-ul.
// Declarate global (nu intr-un IIFE) ca sa poata fi apelate din handlerele de check de mai sus.
var CASA_FAILED_CHECKS_KEY = 'casa_failed_checks';

function loadFailedChecks() {
  try {
    var raw = sessionStorage.getItem(CASA_FAILED_CHECKS_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch (e) {
    return [];
  }
}

function saveFailedChecks(list) {
  try {
    sessionStorage.setItem(CASA_FAILED_CHECKS_KEY, JSON.stringify(list));
  } catch (e) {}
}

// results = array-ul intors de shopping_check.php ([{id, name, ok, error, ...}]). replaceAll=true
// la "Verifică prețurile" (acoperă tot ce exista - lista veche se inlocuiește complet); false la
// verificarea unui singur produs (doar acel produs se actualizează in lista păstrată).
function updateFailedChecksAfterCheck(results, replaceAll) {
  var current = replaceAll ? [] : loadFailedChecks();
  results.forEach(function(r) {
    current = current.filter(function(c) { return c.id != r.id; });
    if (!r.ok) {
      current.push({ id: r.id, name: r.name, error: r.error });
    }
  });
  saveFailedChecks(current);
}

function renderFailedChecksWarning() {
  var list = loadFailedChecks();
  var warning = document.getElementById('failedChecksWarning');
  var text = document.getElementById('failedChecksText');
  var listEl = document.getElementById('failedChecksList');
  if (!warning) return;

  if (!list.length) {
    warning.hidden = true;
    return;
  }

  text.textContent = list.length === 1
    ? '1 produs nu a putut fi citit.'
    : list.length + ' produse nu au putut fi citite.';
  warning.hidden = false;

  listEl.innerHTML = '';
  list.forEach(function(item) {
    var row = document.createElement('div');
    row.className = 'failed-checks-item';

    var name = document.createElement('div');
    name.className = 'name';
    var link = document.createElement('a');
    link.href = 'product.php?id=' + item.id;
    link.textContent = item.name || ('Produs #' + item.id);
    name.appendChild(link);

    var err = document.createElement('div');
    err.className = 'error';
    err.textContent = item.error || 'Eroare necunoscută';

    row.appendChild(name);
    row.appendChild(err);
    listEl.appendChild(row);
  });
}

(function() {
  renderFailedChecksWarning();

  var warning = document.getElementById('failedChecksWarning');
  var linkBtn = document.getElementById('failedChecksLink');
  var dismissBtn = document.getElementById('failedChecksDismiss');
  var modalBackdrop = document.getElementById('failedChecksModalBackdrop');
  var closeBtn = document.getElementById('failedChecksModalClose');
  if (!linkBtn || !modalBackdrop) return;

  linkBtn.addEventListener('click', function() {
    modalBackdrop.classList.add('is-open');
  });
  if (dismissBtn) {
    dismissBtn.addEventListener('click', function() {
      saveFailedChecks([]);
      warning.hidden = true;
    });
  }
  closeBtn.addEventListener('click', function() {
    modalBackdrop.classList.remove('is-open');
  });
  modalBackdrop.addEventListener('click', function(e) {
    if (e.target === modalBackdrop) modalBackdrop.classList.remove('is-open');
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') modalBackdrop.classList.remove('is-open');
  });
})();
</script>

</body>
</html>
