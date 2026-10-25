<?php
require_once __DIR__ . '/_auth.php';
// Personal page - tracks the overall house construction progress: one row per material/work item,
// each moving through the same two stages (achizitionat -> montat). Items are user-managed (added/
// removed from the page itself) since the list of construction steps isn't a fixed, known set.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];

// Every house has one password now (no more owner/guest split) - everyone who gets in sees everything.
$isOwner = true;

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_construction_items (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        name VARCHAR(150) NOT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        price_estimate DECIMAL(10,2) NOT NULL DEFAULT 0,
        price_actual DECIMAL(10,2) NOT NULL DEFAULT 0,
        stage TINYINT UNSIGNED NOT NULL DEFAULT 1,
        achizitionat TINYINT(1) NOT NULL DEFAULT 0,
        montat TINYINT(1) NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
// Schema migrations for installs created before price tracking / the estimate-vs-actual split /
// the per-item build stage existed.
$hasOldPriceCol = $mysqli->query("SHOW COLUMNS FROM casa_construction_items LIKE 'price'");
if ($hasOldPriceCol && $hasOldPriceCol->num_rows > 0) {
    $mysqli->query('ALTER TABLE casa_construction_items CHANGE COLUMN price price_estimate DECIMAL(10,2) NOT NULL DEFAULT 0');
}
$hasEstimateCol = $mysqli->query("SHOW COLUMNS FROM casa_construction_items LIKE 'price_estimate'");
if ($hasEstimateCol && $hasEstimateCol->num_rows === 0) {
    $mysqli->query('ALTER TABLE casa_construction_items ADD COLUMN price_estimate DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER name');
}
$hasActualCol = $mysqli->query("SHOW COLUMNS FROM casa_construction_items LIKE 'price_actual'");
if ($hasActualCol && $hasActualCol->num_rows === 0) {
    $mysqli->query('ALTER TABLE casa_construction_items ADD COLUMN price_actual DECIMAL(10,2) NOT NULL DEFAULT 0 AFTER price_estimate');
}
$hasStageCol = $mysqli->query("SHOW COLUMNS FROM casa_construction_items LIKE 'stage'");
$stageColJustAdded = false;
if ($hasStageCol && $hasStageCol->num_rows === 0) {
    $mysqli->query('ALTER TABLE casa_construction_items ADD COLUMN stage TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER sort_order');
    $stageColJustAdded = true;

    // One-time best-effort backfill so pre-existing items aren't all silently dumped into stage 1 -
    // matched by keyword in the item name. Anything unmatched stays at the default for the user to fix.
    // Numbers match the 11-stage scheme below (Teren..Cheie).
    $stageKeywords = [
        3 => ['fund'],
        4 => ['caramid', 'cărămid', 'zid'],
        5 => ['acoperis', 'acoperiș', 'tigl', 'țigl', 'sarpant', 'șarpant'],
        6 => ['electric', 'sanitar', 'instalati', 'instalați', 'teava', 'țeava', 'cablu', 'priza', 'priză'],
        7 => ['tencuial', 'termopan', 'geam', 'fereastr'],
        8 => ['vata', 'vată', 'izola'],
        9 => ['parchet', 'gresie', 'faianta', 'faianță', 'gips', 'vopsea interior'],
        10 => ['fatada', 'fațadă', 'vopsea'],
    ];
    $backfillRes = $mysqli->query('SELECT id, name FROM casa_construction_items');
    while ($backfillRes && ($bfRow = $backfillRes->fetch_assoc())) {
        $nameLower = mb_strtolower($bfRow['name']);
        $matchedStage = null;
        foreach ($stageKeywords as $stageNum => $keywords) {
            foreach ($keywords as $kw) {
                if (mb_strpos($nameLower, $kw) !== false) { $matchedStage = $stageNum; break 2; }
            }
        }
        if ($matchedStage !== null) {
            $bfStmt = $mysqli->prepare('UPDATE casa_construction_items SET stage = ? WHERE id = ?');
            $bfStmt->bind_param('ii', $matchedStage, $bfRow['id']);
            $bfStmt->execute();
        }
    }
}

// One-time remap for installs whose `stage` column already existed under the earlier 8-stage scheme
// (6=Tencuială+termopane, 7=Izolație, 8=Finisată) before it was split into today's 11 stages with
// Instalații inserted and finishing broken into interior/exterior. Skipped when the column was just
// freshly added above, since that backfill already wrote the new numbering directly.
$mysqli->query(
    "CREATE TABLE IF NOT EXISTS casa_migrations (
        name VARCHAR(64) NOT NULL,
        applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
);
$migrationName = 'stage_scheme_v2_11stages';
$migCheck = $mysqli->query("SELECT 1 FROM casa_migrations WHERE name = '$migrationName'");
if ($migCheck && $migCheck->num_rows === 0) {
    if (!$stageColJustAdded) {
        $mysqli->query('UPDATE casa_construction_items SET stage = CASE stage WHEN 6 THEN 7 WHEN 7 THEN 8 WHEN 8 THEN 9 ELSE stage END');
    }
    $mysqli->query("INSERT IGNORE INTO casa_migrations (name) VALUES ('$migrationName')");
}

$items = [];
$stmt = $mysqli->prepare('SELECT id, name, price_estimate, price_actual, stage, achizitionat, montat FROM casa_construction_items WHERE house_id = ? ORDER BY sort_order, id');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    $items[] = $row;
}

$totalPoints = count($items) * 2;
$donePoints = 0;
$totalEstimate = 0;
$totalActual = 0;
foreach ($items as $item) {
    $donePoints += (int)$item['achizitionat'] + (int)$item['montat'];
    $totalEstimate += (float)$item['price_estimate'];
    $totalActual += (float)$item['price_actual'];
}
$overallPct = $totalPoints > 0 ? round($donePoints / $totalPoints * 100) : 0;

if (!$isOwner) {
    $totalEstimate = 0;
    $totalActual = 0;
    foreach ($items as &$item) {
        $item['price_estimate'] = 0;
        $item['price_actual'] = 0;
    }
    unset($item);
}

require_once __DIR__ . '/stage_defs.php';
$currentStage = casa_derive_stage($items, $stageCount);
casa_ensure_stage_folders($currentHouse['slug'], $stageLabels);
$currentStagePhotos = casa_stage_photo_files($currentHouse['slug'], $currentStage, $stageLabels[$currentStage]);
$currentStageFolder = casa_stage_folder_slug($currentStage, $stageLabels[$currentStage]);
$stageTagText = 'ETAPA ' . $currentStage . ' · ' . mb_strtoupper($stageLabels[$currentStage], 'UTF-8');
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Progres construcție</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  html { scroll-behavior: smooth; }
  body { line-height: 1.6; }
  a { color: var(--accent); text-decoration: none; }

  main { max-width: 1200px; margin: 0 auto; padding: 32px 24px 80px; }

  .stage-grid {
    display: grid;
    grid-template-columns: 1.3fr 1fr;
    gap: 30px;
    align-items: start;
    margin-bottom: 36px;
  }
  @media (max-width: 860px) {
    .stage-grid { grid-template-columns: 1fr; }
  }

  .stage-eyebrow {
    margin: 0;
    font-family: var(--mono);
    font-size: 0.72rem;
    font-weight: 500;
    letter-spacing: 0.09em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .stage-title {
    margin: 7px 0 0;
    font-family: var(--disp);
    font-size: 2.1rem;
    font-weight: 600;
    letter-spacing: -0.03em;
    color: var(--ink);
    transition: opacity 0.35s ease, transform 0.35s ease;
  }
  .stage-title.is-swapping { opacity: 0; transform: translateY(-4px); }

  .stage-rail-wrap { margin-top: 30px; position: relative; }
  .stage-rail-track {
    height: 2px;
    background: rgba(240,236,228,.12);
    border-radius: 2px;
  }
  .stage-rail-fill {
    height: 100%;
    background: var(--accent);
    border-radius: 2px;
    transition: width 0.5s cubic-bezier(0.22,1,0.36,1);
  }
  .stage-rail-nodes {
    position: absolute; inset: 0;
    display: flex; align-items: center; justify-content: space-between;
  }
  .stage-step {
    position: relative;
    display: flex; align-items: center; justify-content: center;
    width: 18px; height: 18px;
    padding: 0; margin: 0;
    border-radius: 50%;
    border: 1px solid rgba(240,236,228,.18);
    background: var(--panel);
    color: var(--ink-3);
    font-family: var(--mono);
    font-size: 0.62rem; font-weight: 400;
    transition: background 0.25s ease, border-color 0.25s ease, color 0.25s ease, width 0.25s ease, height 0.25s ease;
  }
  .stage-step.done { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 700; }
  .stage-step.active {
    width: 24px; height: 24px;
    background: var(--bg);
    border: 2px solid var(--accent);
    color: var(--accent);
    font-weight: 700; font-size: 0.7rem;
  }
  .stage-step .check { display: none; }
  .stage-step.done .num { display: none; }
  .stage-step.done .check { display: block; }

  .stage-rail-caption {
    display: flex; justify-content: space-between;
    margin-top: 16px;
    font-family: var(--mono);
    font-size: 0.65rem; color: var(--ink-3);
    text-transform: uppercase;
  }
  .stage-note {
    margin: 16px 0 0;
    font-size: 0.78rem;
    line-height: 1.55;
    color: var(--ink-3);
    max-width: 520px;
  }

  .overall-card {
    margin-top: 26px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 8px;
    padding: 17px 19px;
  }
  .overall-card .row { display: flex; align-items: baseline; justify-content: space-between; }
  .overall-card .row h2 {
    margin: 0; font-size: 0.9rem;
    font-family: var(--disp); font-weight: 600;
    color: var(--ink);
  }
  .overall-card .row .pct {
    font-family: var(--mono); font-size: 1.4rem; font-weight: 500;
    color: var(--accent);
  }
  .progress-bar { height: 8px; border-radius: 3px; background: var(--bg); border: 1px solid var(--line-soft); overflow: hidden; margin-top: 12px; }
  .progress-bar-fill { height: 100%; background: var(--accent); transition: width 0.3s ease; }
  .overall-card .cost-row {
    display: flex; justify-content: space-between; flex-wrap: wrap; gap: 6px 16px;
    margin-top: 13px;
    font-size: 0.78rem; color: var(--ink-2);
  }
  .overall-card .cost-row strong { font-family: var(--mono); font-weight: 500; color: var(--ink); }

  .stage-photo-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .stage-photo-grid.single-photo { grid-template-columns: 1fr; }
  .stage-photo-grid .stage-photo-frame {
    display: block;
    position: relative;
    aspect-ratio: 4 / 3;
    border-radius: 7px;
    overflow: hidden;
  }
  .stage-photo-grid.single-photo .stage-photo-frame { aspect-ratio: 16 / 11; }
  .stage-photo-grid img {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .stage-photo-empty {
    text-align: center;
    color: var(--ink-3);
    font-size: 0.78rem;
    line-height: 1.6;
    padding: 14px;
    border: 1px dashed rgba(240,236,228,.16);
    border-radius: 7px;
  }
  .stage-photo-empty code {
    font-family: var(--mono);
    font-size: 0.72rem;
    color: var(--ink);
  }

  .table-scroll { overflow-x: auto; }
  .items-grid { min-width: 780px; }
  .items-header, .item-row {
    display: grid;
    grid-template-columns: 52px minmax(0,1fr) 118px 118px 168px 96px 78px 34px;
    gap: 12px;
    align-items: center;
  }
  .items-header {
    padding: 12px 4px;
    font-family: var(--mono);
    font-size: 0.62rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--ink-3);
    border-bottom: 1px solid var(--line);
  }
  .item-row {
    padding: 9px 4px;
    border-bottom: 1px solid var(--line-soft);
  }
  .cell-reorder, .cell-check, .cell-delete {
    display: flex; align-items: center; justify-content: center; gap: 3px;
  }
  .cell-name { min-width: 0; }
  .cell-price { text-align: right; }

  .reorder-btn {
    background: transparent; border: 1px solid var(--line); color: var(--ink-3);
    width: 22px; height: 22px; border-radius: 4px; cursor: pointer; font-size: 0.6rem;
    display: inline-flex; align-items: center; justify-content: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .reorder-btn:hover { border-color: var(--accent); color: var(--accent); }
  .reorder-btn:disabled { opacity: 0.3; cursor: default; }
  .reorder-btn:disabled:hover { border-color: var(--line); color: var(--ink-3); }

  input.name-input {
    width: 100%; height: 32px;
    padding: 0 10px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.85rem;
  }
  input.name-input:focus { outline: none; border-color: var(--accent); }
  .item-row.is-complete .name-input { color: var(--ink-2); text-decoration: line-through; }
  .item-row:hover { background: rgba(217,164,65,0.04); }

  input.price-input {
    width: 100%; height: 32px;
    padding: 0 10px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--mono); font-size: 0.82rem; text-align: right;
  }
  input.price-input:focus { outline: none; border-color: var(--accent); }

  select.stage-select {
    width: 100%; height: 32px;
    padding: 0 9px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.78rem; cursor: pointer;
  }
  select.stage-select:focus { outline: none; border-color: var(--accent); }

  input[type=number].price-input,
  input[type=number]#newItemEstimate {
    -moz-appearance: textfield;
    appearance: textfield;
  }
  input[type=number].price-input::-webkit-outer-spin-button,
  input[type=number].price-input::-webkit-inner-spin-button,
  input[type=number]#newItemEstimate::-webkit-outer-spin-button,
  input[type=number]#newItemEstimate::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  input.cell-checkbox {
    appearance: none; -webkit-appearance: none;
    width: 17px; height: 17px;
    margin: 0;
    border-radius: 4px;
    border: 1px solid rgba(240,236,228,.22);
    background: var(--panel);
    cursor: pointer;
    position: relative;
  }
  input.cell-checkbox:checked {
    background: var(--good);
    border-color: var(--good);
  }
  input.cell-checkbox:checked::after {
    content: "✓";
    position: absolute; inset: 0;
    display: flex; align-items: center; justify-content: center;
    color: var(--on-accent);
    font-size: 0.68rem; font-weight: 700; line-height: 1;
  }

  .delete-btn {
    background: transparent; border: none; color: var(--ink-3);
    cursor: pointer; font-size: 0.72rem;
    display: inline-flex; align-items: center; justify-content: center;
    transition: color 0.2s ease;
  }
  .delete-btn:hover { color: var(--bad); }

  .add-row {
    display: grid;
    grid-template-columns: minmax(0,1fr) 150px 168px 96px;
    gap: 10px;
    margin-top: 20px;
  }
  @media (max-width: 700px) {
    .add-row { grid-template-columns: 1fr; }
  }
  .add-row input[type=text], .add-row input[type=number], .add-row select {
    height: 38px;
    padding: 0 12px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.85rem;
  }
  .add-row input[type=number] { font-family: var(--mono); }
  .add-row select { cursor: pointer; }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
  .add-row button {
    height: 38px;
    background: var(--accent);
    border: none;
    border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.82rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-row button:hover { background: #c6923a; }

  .empty-state {
    text-align: center; color: var(--ink-2); padding: 30px 20px;
    font-family: var(--mono); font-size: 0.85rem;
    border: 1px dashed var(--line); border-radius: 8px; margin-bottom: 10px;
  }


</style>
<link rel="stylesheet" href="/assets/casa-undo.css">
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span><?= htmlspecialchars($currentHouse['name']) ?></span></div>
    <nav id="heroNav">
      <a href="/progres.php" class="is-current">Construcție</a>
      <a href="/design/">Design</a>
      <a href="/links.php">Link-uri</a>
      <a href="/jurnal.php">Jurnal</a>
      <a href="/shopping.php">Lista de cumpărături</a>
      <a href="/index.php?logout=all" class="nav-exit">Ieși</a>
    </nav>
  </div>
  <span class="stage-tag" id="headerStageTag"><?= htmlspecialchars($stageTagText) ?></span>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>

  <div class="stage-grid">
    <div>
      <p class="stage-eyebrow">Etapa <span id="stageNum"><?= $currentStage ?></span> din <?= $stageCount ?></p>
      <h2 class="stage-title" id="stageLabel"><?= htmlspecialchars($stageLabels[$currentStage]) ?></h2>

      <div class="stage-rail-wrap">
        <div class="stage-rail-track">
          <div class="stage-rail-fill" id="railFill"></div>
        </div>
        <div class="stage-rail-nodes" id="stageStepper">
          <?php foreach ($stageLabels as $num => $label): ?>
            <span class="stage-step <?= $num == $currentStage ? 'active' : ($num < $currentStage ? 'done' : '') ?>"
                  data-stage="<?= $num ?>"
                  title="<?= htmlspecialchars($label) ?>">
              <span class="num"><?= $num ?></span>
              <span class="check">✓</span>
            </span>
          <?php endforeach; ?>
        </div>
      </div>
      <div class="stage-rail-caption">
        <span><?= htmlspecialchars($stageLabels[1]) ?></span>
        <span><?= htmlspecialchars($stageLabels[$stageCount]) ?></span>
      </div>
      <p class="stage-note">Calculat automat din lista „Progres general" de mai jos — pe baza etapei atribuite fiecărui element și a bifelor Achiziționat/Montat.</p>

      <div class="overall-card">
        <div class="row">
          <h2>Progres general</h2>
          <span class="pct" id="overallPct"><?= $overallPct ?>%</span>
        </div>
        <div class="progress-bar"><div class="progress-bar-fill" id="overallBar" style="width:<?= $overallPct ?>%"></div></div>
        <div class="cost-row">
          <span>Cost total estimat: <strong id="totalEstimate" title="<?= htmlspecialchars(casa_eur_title($totalEstimate)) ?>"><?= casa_format_lei($totalEstimate) ?></strong></span>
          <span>Cost real până acum: <strong id="totalActual" title="<?= htmlspecialchars(casa_eur_title($totalActual)) ?>"><?= casa_format_lei($totalActual) ?></strong></span>
        </div>
      </div>
    </div>

    <?php if ($isOwner): ?>
    <div id="stagePhotoArea">
      <?php if (empty($currentStagePhotos)): ?>
        <div class="stage-photo-empty" id="stagePhotoEmpty">
          Nicio poză pentru etapa asta încă.<br>
          Pune poze în <code id="stagePhotoFolder">casa/<?= htmlspecialchars($currentHouse['slug']) ?>/stage_photos/<?= htmlspecialchars($currentStageFolder) ?>/</code>
        </div>
      <?php else: ?>
        <div class="stage-photo-grid<?= count($currentStagePhotos) === 1 ? ' single-photo' : '' ?>" id="stagePhotoGrid">
          <?php foreach ($currentStagePhotos as $photo): ?>
            <div class="stage-photo-frame">
              <img src="<?= htmlspecialchars($photo) ?>" alt="<?= htmlspecialchars($stageLabels[$currentStage]) ?>" loading="lazy">
            </div>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    </div>
    <?php endif; ?>
  </div>

  <?php if (empty($items)): ?>
    <div class="empty-state" id="emptyState">Niciun element adăugat încă. Adaugă mai jos primul material sau lucrare de urmărit.</div>
  <?php endif; ?>

  <div class="table-scroll">
  <div class="items-grid" id="itemsTable" style="<?= empty($items) ? 'display:none' : '' ?>">
    <div class="items-header">
      <div class="cell-reorder">Ordine</div>
      <div class="cell-name">Material / lucrare</div>
      <div class="cell-price">Estimare (LEI)</div>
      <div class="cell-price">Preț real (LEI)</div>
      <div class="cell-stage">Etapă</div>
      <div class="cell-check">Achiziționat</div>
      <div class="cell-check">Montat</div>
      <div class="cell-delete"></div>
    </div>
    <div id="itemsBody">
      <?php foreach ($items as $item): ?>
        <div class="item-row<?= ($item['achizitionat'] && $item['montat']) ? ' is-complete' : '' ?>" data-id="<?= (int)$item['id'] ?>" data-stage="<?= (int)$item['stage'] ?>">
          <div class="cell-reorder">
            <button class="reorder-btn" data-dir="up" title="Mută mai sus">▲</button>
            <button class="reorder-btn" data-dir="down" title="Mută mai jos">▼</button>
          </div>
          <div class="cell-name"><input type="text" class="name-input" value="<?= htmlspecialchars($item['name']) ?>"></div>
          <div class="cell-price"><input type="number" class="price-input" data-field="price_estimate" min="0" step="0.01" value="<?= htmlspecialchars($item['price_estimate']) ?>" title="<?= htmlspecialchars(casa_eur_title((float)$item['price_estimate'])) ?>" <?= $isOwner ? '' : 'disabled' ?>></div>
          <div class="cell-price"><input type="number" class="price-input" data-field="price_actual" min="0" step="0.01" value="<?= htmlspecialchars($item['price_actual']) ?>" title="<?= htmlspecialchars(casa_eur_title((float)$item['price_actual'])) ?>" <?= $isOwner ? '' : 'disabled' ?>></div>
          <div class="cell-stage">
            <select class="stage-select">
              <?php foreach ($stageLabels as $num => $label): ?>
                <option value="<?= $num ?>" <?= $num == $item['stage'] ? 'selected' : '' ?>><?= $num ?>. <?= htmlspecialchars($label) ?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="cell-check"><input type="checkbox" class="cell-checkbox" data-field="achizitionat" <?= $item['achizitionat'] ? 'checked' : '' ?>></div>
          <div class="cell-check"><input type="checkbox" class="cell-checkbox" data-field="montat" <?= $item['montat'] ? 'checked' : '' ?>></div>
          <div class="cell-delete"><button class="delete-btn" title="Șterge">✕</button></div>
        </div>
      <?php endforeach; ?>
    </div>
  </div>
  </div>

  <div class="add-row">
    <input type="text" id="newItemName" placeholder="Ex: Țiglă, Fier beton, Instalație electrică...">
    <input type="number" id="newItemEstimate" placeholder="Estimare (LEI)" min="0" step="0.01" <?= $isOwner ? '' : 'value="0" disabled' ?>>
    <select id="newItemStage">
      <?php foreach ($stageLabels as $num => $label): ?>
        <option value="<?= $num ?>" <?= $num == $currentStage ? 'selected' : '' ?>><?= $num ?>. <?= htmlspecialchars($label) ?></option>
      <?php endforeach; ?>
    </select>
    <button id="addItemBtn">Adaugă</button>
  </div>

</main>

<?php casa_render_footer(); ?>

<script src="/assets/casa-undo.js"></script>
<script>
(function() {
  var toggle = document.getElementById('navToggle');
  var nav = document.getElementById('heroNav');
  if (!toggle || !nav) return;
  toggle.addEventListener('click', function() {
    var open = nav.classList.toggle('is-open');
    toggle.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
})();

var stageLabels = <?= json_encode($stageLabels, JSON_UNESCAPED_UNICODE) ?>;
var stageCount = <?= (int)$stageCount ?>;

(function() {
  var stepper = document.getElementById('stageStepper');
  var stageLabelEl = document.getElementById('stageLabel');
  var stageNumEl = document.getElementById('stageNum');
  var railFill = document.getElementById('railFill');
  var photoArea = document.getElementById('stagePhotoArea');
  var headerStageTag = document.getElementById('headerStageTag');
  var currentStage = <?= (int)$currentStage ?>;

  var houseSlug = <?= json_encode($currentHouse['slug']) ?>;

  function renderPhotos(photos, folder) {
    if (!photoArea) return;
    if (!photos.length) {
      photoArea.innerHTML = '<div class="stage-photo-empty">Nicio poză pentru etapa asta încă.<br>Pune poze în <code>casa/' + houseSlug + '/stage_photos/' + folder + '/</code></div>';
      return;
    }
    var html = '<div class="stage-photo-grid' + (photos.length === 1 ? ' single-photo' : '') + '">';
    photos.forEach(function(p) {
      html += '<div class="stage-photo-frame"><img src="' + p + '" alt="" loading="lazy"></div>';
    });
    html += '</div>';
    photoArea.innerHTML = html;
  }

  function applyStage(stage, animateTitle) {
    var pct = (stage - 1) / (stageCount - 1);

    stepper.querySelectorAll('.stage-step').forEach(function(node) {
      var s = parseInt(node.getAttribute('data-stage'));
      node.classList.toggle('active', s === stage);
      node.classList.toggle('done', s < stage);
    });

    railFill.style.width = (pct * 100) + '%';
    stageNumEl.textContent = stage;

    var changed = stage !== currentStage;
    currentStage = stage;

    if (animateTitle && changed) {
      stageLabelEl.classList.add('is-swapping');
      setTimeout(function() {
        stageLabelEl.textContent = stageLabels[stage];
        stageLabelEl.classList.remove('is-swapping');
      }, 200);
    } else {
      stageLabelEl.textContent = stageLabels[stage];
    }

    if (headerStageTag) headerStageTag.textContent = 'ETAPA ' + stage + ' · ' + stageLabels[stage].toUpperCase();

    if (changed && photoArea) {
      fetch('stage_photos_fetch.php?stage=' + stage)
        .then(function(res) { return res.json(); })
        .then(function(data) {
          if (data.ok) renderPhotos(data.photos, data.folder);
        })
        .catch(function() {});
    }
  }

  applyStage(currentStage, false);
  window.CasaStage = { apply: applyStage };
})();

(function() {
  var tbody = document.getElementById('itemsBody');
  var table = document.getElementById('itemsTable');
  var emptyState = document.getElementById('emptyState');
  var overallPct = document.getElementById('overallPct');
  var overallBar = document.getElementById('overallBar');
  var totalEstimateEl = document.getElementById('totalEstimate');
  var totalActualEl = document.getElementById('totalActual');

  var EUR_TO_LEI = 5.25;
  function formatLei(n) {
    return n.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' LEI';
  }
  function formatEurTitle(n) {
    return (n / EUR_TO_LEI).toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' EUR';
  }

  function deriveStage() {
    var rows = tbody.querySelectorAll('.item-row');
    if (!rows.length) return 1;
    var byStage = {};
    rows.forEach(function(row) {
      var s = parseInt(row.querySelector('.stage-select').value);
      var achiz = row.querySelector('input[data-field=achizitionat]').checked;
      var montat = row.querySelector('input[data-field=montat]').checked;
      if (!byStage[s]) byStage[s] = { total: 0, done: 0 };
      byStage[s].total++;
      if (achiz && montat) byStage[s].done++;
    });
    var stage = 1;
    for (var s = 1; s <= stageCount; s++) {
      var bucket = byStage[s];
      var complete = !bucket || bucket.done === bucket.total;
      if (complete) { stage = Math.min(s + 1, stageCount); }
      else { stage = s; break; }
    }
    return stage;
  }

  function refreshStageVisual() {
    if (window.CasaStage) window.CasaStage.apply(deriveStage(), true);
  }

  function updateOverall() {
    var rows = tbody.querySelectorAll('.item-row');
    var total = rows.length * 2;
    var done = 0;
    var totalEstimate = 0;
    var totalActual = 0;
    rows.forEach(function(row) {
      totalEstimate += parseFloat(row.querySelector('[data-field=price_estimate]').value) || 0;
      totalActual += parseFloat(row.querySelector('[data-field=price_actual]').value) || 0;
      row.querySelectorAll('input[type=checkbox]').forEach(function(cb) { if (cb.checked) done++; });
    });
    var pct = total > 0 ? Math.round(done / total * 100) : 0;
    overallPct.textContent = pct + '%';
    overallBar.style.width = pct + '%';
    totalEstimateEl.textContent = formatLei(totalEstimate);
    totalEstimateEl.title = formatEurTitle(totalEstimate);
    totalActualEl.textContent = formatLei(totalActual);
    totalActualEl.title = formatEurTitle(totalActual);
  }

  function wireRow(row) {
    var nameInput = row.querySelector('.name-input');
    nameInput.addEventListener('change', function() {
      var id = row.getAttribute('data-id');
      var name = nameInput.value.trim();
      if (!name) {
        alert('Numele nu poate fi gol.');
        nameInput.focus();
        return;
      }

      fetch('construction_name.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('save failed');
        nameInput.value = name;
      }).catch(function() {
        alert('Nu s-a putut salva numele. Încearcă din nou.');
      });
    });

    row.querySelectorAll('input[type=checkbox]').forEach(function(cb) {
      cb.addEventListener('change', function() {
        var id = row.getAttribute('data-id');
        var field = cb.getAttribute('data-field');
        var done = cb.checked;

        fetch('construction_update.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, field: field, done: done ? '1' : '0' }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('save failed');
          var boxes = row.querySelectorAll('input[type=checkbox]');
          var allDone = Array.prototype.every.call(boxes, function(b) { return b.checked; });
          row.classList.toggle('is-complete', allDone);
          updateOverall();
          refreshStageVisual();
        }).catch(function() {
          cb.checked = !done;
          alert('Nu s-a putut salva modificarea. Încearcă din nou.');
        });
      });
    });

    row.querySelectorAll('.price-input').forEach(function(priceInput) {
      priceInput.addEventListener('change', function() {
        var id = row.getAttribute('data-id');
        var field = priceInput.getAttribute('data-field');
        var price = parseFloat(priceInput.value);
        if (isNaN(price) || price < 0) price = 0;
        priceInput.value = price.toFixed(2);
        priceInput.title = formatEurTitle(price);

        fetch('construction_price.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, field: field, price: price }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('save failed');
          updateOverall();
        }).catch(function() {
          alert('Nu s-a putut salva prețul. Încearcă din nou.');
        });
      });
    });

    var stageSelect = row.querySelector('.stage-select');
    stageSelect.addEventListener('change', function() {
      var id = row.getAttribute('data-id');
      var previousStage = row.getAttribute('data-stage');
      var newStage = stageSelect.value;

      fetch('construction_item_stage.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, stage: newStage }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('save failed');
        row.setAttribute('data-stage', newStage);
        refreshStageVisual();
      }).catch(function() {
        stageSelect.value = previousStage;
        alert('Nu s-a putut salva etapa. Încearcă din nou.');
      });
    });

    row.querySelectorAll('.reorder-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var id = row.getAttribute('data-id');
        var direction = btn.getAttribute('data-dir');

        fetch('construction_reorder.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, direction: direction }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('reorder failed');
          if (!data.moved) return;
          if (direction === 'up' && row.previousElementSibling) {
            tbody.insertBefore(row, row.previousElementSibling);
          } else if (direction === 'down' && row.nextElementSibling) {
            tbody.insertBefore(row.nextElementSibling, row);
          }
        }).catch(function() {
          alert('Nu s-a putut reordona elementul. Încearcă din nou.');
        });
      });
    });

    row.querySelector('.delete-btn').addEventListener('click', function() {
      var id = row.getAttribute('data-id');
      var nextSibling = row.nextElementSibling;

      row.remove();
      updateOverall();
      refreshStageVisual();
      if (!tbody.querySelector('.item-row')) {
        table.style.display = 'none';
        if (emptyState) emptyState.style.display = '';
      }

      casaUndoAction({
        message: 'Element șters.',
        commit: function() {
          fetch('construction_delete.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ id: id }).toString()
          }).catch(function() {});
        },
        undo: function() {
          if (nextSibling && nextSibling.parentNode === tbody) tbody.insertBefore(row, nextSibling);
          else tbody.appendChild(row);
          table.style.display = '';
          if (emptyState) emptyState.style.display = 'none';
          updateOverall();
          refreshStageVisual();
        }
      });
    });
  }

  tbody.querySelectorAll('.item-row').forEach(wireRow);

  document.getElementById('addItemBtn').addEventListener('click', function() {
    var input = document.getElementById('newItemName');
    var estimateInput = document.getElementById('newItemEstimate');
    var stageSelect = document.getElementById('newItemStage');
    var name = input.value.trim();
    if (!name) return;
    var estimate = parseFloat(estimateInput.value);
    if (isNaN(estimate) || estimate < 0) estimate = 0;
    var stage = stageSelect.value;

    fetch('construction_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ name: name, price_estimate: estimate, stage: stage }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');

      if (emptyState) emptyState.style.display = 'none';
      table.style.display = '';

      var stageOptionsHtml = '';
      for (var s = 1; s <= stageCount; s++) {
        stageOptionsHtml += '<option value="' + s + '"' + (s == data.stage ? ' selected' : '') + '>' + s + '. ' + stageLabels[s] + '</option>';
      }

      var row = document.createElement('div');
      row.className = 'item-row';
      row.setAttribute('data-id', data.id);
      row.setAttribute('data-stage', data.stage);
      row.innerHTML =
        '<div class="cell-reorder"><button class="reorder-btn" data-dir="up" title="Mută mai sus">▲</button><button class="reorder-btn" data-dir="down" title="Mută mai jos">▼</button></div>' +
        '<div class="cell-name"><input type="text" class="name-input"></div>' +
        '<div class="cell-price"><input type="number" class="price-input" data-field="price_estimate" min="0" step="0.01"></div>' +
        '<div class="cell-price"><input type="number" class="price-input" data-field="price_actual" min="0" step="0.01" value="0.00"></div>' +
        '<div class="cell-stage"><select class="stage-select">' + stageOptionsHtml + '</select></div>' +
        '<div class="cell-check"><input type="checkbox" class="cell-checkbox" data-field="achizitionat"></div>' +
        '<div class="cell-check"><input type="checkbox" class="cell-checkbox" data-field="montat"></div>' +
        '<div class="cell-delete"><button class="delete-btn" title="Șterge">✕</button></div>';
      row.querySelector('.name-input').value = data.name;
      var estimateInputEl = row.querySelector('[data-field=price_estimate]');
      estimateInputEl.value = Number(data.price_estimate).toFixed(2);
      estimateInputEl.title = formatEurTitle(Number(data.price_estimate));
      row.querySelector('[data-field=price_actual]').title = formatEurTitle(0);
      tbody.appendChild(row);
      wireRow(row);
      updateOverall();
      refreshStageVisual();

      input.value = '';
      estimateInput.value = '';
      input.focus();
    }).catch(function() {
      alert('Nu s-a putut adăuga elementul. Încearcă din nou.');
    });
  });

  document.getElementById('newItemName').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') document.getElementById('addItemBtn').click();
  });
  document.getElementById('newItemEstimate').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') document.getElementById('addItemBtn').click();
  });
})();
</script>

</body>
</html>
