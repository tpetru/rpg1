<?php
// Pagina de sine statatoare (fara header-ul/branding-ul site-ului), in acelasi stil vizual ca
// /cocktails.php si /cs/. Tine evidenta documentelor (nume + data expirarii), optional legate de
// o firma - utila ca sa nu uiti cand expira o asigurare/certificat/licenta etc.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

docs_ensure_tables($mysqli);
site_theme_init($mysqli);
docs_require_page_auth($mysqli);

$companies = []; // id => name, in ordinea adaugarii
$res = $mysqli->query('SELECT id, name, password FROM docs_companies ORDER BY sort_order ASC, id ASC');
$companyPasswords = []; // id => password (or '')
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $companies[(int)$row['id']] = $row['name'];
        $companyPasswords[(int)$row['id']] = $row['password'] ?? '';
    }
}

$lockedCompanyId = docs_locked_company_id();
$lockedCompanyName = $lockedCompanyId !== null ? ($companies[$lockedCompanyId] ?? 'Firmă ștearsă') : null;

$taskCounts = []; // doc_id => ['total' => n, 'done' => n]
$res = $mysqli->query('SELECT doc_id, COUNT(*) AS total, SUM(completed_at IS NOT NULL) AS done FROM docs_tasks GROUP BY doc_id');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $taskCounts[(int)$row['doc_id']] = ['total' => (int)$row['total'], 'done' => (int)$row['done']];
    }
}

$docs = [];
$res = $mysqli->query('SELECT id, name, company_id, expires_at FROM docs_items ORDER BY expires_at ASC, id ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $row['company_id'] = $row['company_id'] !== null ? (int)$row['company_id'] : null;
        $row['status'] = docs_status($row['expires_at']);
        $counts = $taskCounts[(int)$row['id']] ?? ['total' => 0, 'done' => 0];
        $row['task_total'] = $counts['total'];
        $row['task_done'] = $counts['done'];
        $row['task_pct'] = $counts['total'] > 0 ? (int)round($counts['done'] * 100 / $counts['total']) : null;
        $docs[] = $row;
    }
}

if ($lockedCompanyName !== null) {
    $docs = array_values(array_filter($docs, fn($d) => $d['company_id'] === $lockedCompanyId));
}

$noCompanyCount = count(array_filter($docs, fn($d) => $d['company_id'] === null));
$statusLabels = ['expired' => 'Expirat', 'soon' => 'Expiră curând', 'valid' => 'Valabil'];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Documente</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 1200px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .add-toggle-btn {
    display: block; width: 100%;
    padding: 11px 14px;
    margin-bottom: 20px;
    border: 1px dashed rgba(240,236,228,.16); border-radius: 6px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.82rem;
    cursor: pointer; text-align: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }

  .add-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 20px 22px;
    margin-bottom: 26px;
  }
  .add-card[hidden] { display: none; }
  .add-card h2 {
    margin: 0 0 14px;
    font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink);
  }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input, .add-row select {
    padding: 10px 14px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row input[name=name] { flex: 1 1 220px; }
  .add-row select[name=company_id] { width: 170px; }
  .add-row input[name=expires_at] { width: 155px; font-family: var(--mono); }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
  .add-btn {
    width: 100%; margin-top: 10px;
    padding: 11px 18px;
    background: var(--accent); border: none; border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-btn:hover { background: #c6923a; }

  .toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; margin-bottom: 18px; }
  .search-input {
    flex: 1 1 220px;
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .search-input:focus { outline: none; border-color: var(--accent); }
  .search-input::placeholder { color: var(--ink-3); }

  .filter-bar { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; }
  .filter-btn {
    font-size: 0.78rem; padding: 5px 12px; border-radius: 14px;
    border: 1px solid var(--line); color: var(--ink-2);
    background: transparent; cursor: pointer; font-family: var(--disp);
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .filter-btn .count { font-family: var(--mono); font-size: 0.7rem; }
  .filter-btn.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }
  .filter-btn:hover:not(.is-active) { border-color: var(--accent); color: var(--ink); }

  /* Burger cu filtrele de firma, pentru mobil - ca sa poti filtra fara sa derulezi inapoi sus */
  .filter-burger-btn {
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
  .filter-burger-btn span { display: block; width: 22px; height: 2px; background: var(--accent); border-radius: 2px; transition: transform 0.25s ease, opacity 0.2s ease; }
  .filter-burger-btn.is-open span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
  .filter-burger-btn.is-open span:nth-child(2) { opacity: 0; }
  .filter-burger-btn.is-open span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }

  .filter-burger-panel {
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
  .filter-burger-panel.is-open { display: block; }
  .filter-burger-panel .burger-title {
    text-align: center;
    font-weight: 600;
    font-size: 0.72rem;
    color: var(--accent);
    margin: 2px 0 10px;
  }
  .filter-burger-panel .burger-links {
    display: flex; flex-direction: column; gap: 6px;
  }
  .filter-burger-panel .burger-links button {
    display: flex; align-items: center; gap: 10px;
    width: 100%;
    padding: 9px 10px;
    border: 1px solid var(--line-soft);
    border-radius: 8px;
    background: var(--panel);
    color: var(--ink);
    font-family: var(--disp);
    font-weight: 500;
    font-size: 0.76rem;
    text-align: left;
    cursor: pointer;
  }
  .filter-burger-panel .burger-links button .count { font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); margin-left: auto; }
  .filter-burger-panel .burger-links button.is-active {
    background: var(--accent);
    border-color: var(--accent);
    color: var(--on-accent);
  }
  .filter-burger-panel .burger-links button.is-active .count { color: var(--on-accent); }
  @media (max-width: 700px) {
    .filter-burger-btn { display: flex; }
  }

  .manage-companies {
    background: var(--panel);
    border: 1px solid var(--line); border-radius: 8px;
    padding: 14px 18px; margin: 0 0 26px;
  }
  .manage-companies summary {
    cursor: pointer; font-family: var(--disp); font-weight: 600; font-size: 0.82rem; color: var(--ink);
  }
  .manage-companies summary:hover { color: var(--accent); }
  .company-manage-list { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 14px; }
  .company-chip {
    display: flex; flex-direction: column; gap: 6px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 10px;
    padding: 8px 10px; font-size: 0.82rem; width: 190px;
  }
  .company-chip-row { display: flex; align-items: center; gap: 6px; }
  .company-chip input {
    background: transparent; border: none; color: var(--ink); font-size: 0.82rem;
    padding: 2px 0; font-family: var(--disp);
  }
  .company-chip .company-name-input { flex: 1; min-width: 0; font-weight: 600; }
  .company-chip input:focus { outline: none; border-bottom: 1px solid var(--accent); }
  .company-chip button {
    background: transparent; border: none; color: var(--ink-3); cursor: pointer;
    width: 20px; height: 20px; border-radius: 50%; font-size: 0.85rem; line-height: 1; flex-shrink: 0;
  }
  .company-chip button:hover { background: rgba(210,105,79,.15); color: var(--bad); }
  .company-password-row { display: flex; align-items: center; gap: 6px; border-top: 1px solid var(--line-soft); padding-top: 6px; }
  .company-password-row label { font-family: var(--mono); font-size: 0.68rem; color: var(--ink-3); white-space: nowrap; }
  .company-password-input {
    flex: 1; min-width: 0;
    font-family: var(--mono); font-size: 0.78rem;
  }
  .company-password-input::placeholder { color: var(--ink-3); font-family: var(--disp); }
  .add-company-row { display: flex; gap: 8px; margin-top: 14px; }
  .add-company-row input {
    padding: 8px 12px; background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-size: 0.85rem; width: 180px; font-family: var(--disp);
  }
  .add-company-row input:focus { outline: none; border-color: var(--accent); }
  .add-company-row button {
    padding: 8px 16px; border: 1px solid var(--line); border-radius: 5px;
    background: transparent; color: var(--ink-2); font-family: var(--disp); font-weight: 600; font-size: 0.78rem; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-company-row button:hover { border-color: var(--accent); color: var(--accent); }

  .doc-list { display: flex; flex-direction: column; gap: 2px; }
  .doc-row {
    display: grid;
    grid-template-columns: 1fr 160px 168px 78px;
    align-items: center;
    gap: 16px;
    padding: 14px 4px;
    border-bottom: 1px solid var(--line-soft);
  }
  .doc-row[hidden] { display: none; }
  .doc-row.status-expired { border-left: 2px solid var(--bad); padding-left: 14px; background: rgba(210,105,79,0.05); border-radius: 0 5px 5px 0; }
  .doc-row.status-soon { border-left: 2px solid var(--accent); padding-left: 14px; background: rgba(217,164,65,0.05); border-radius: 0 5px 5px 0; }

  .doc-name { font-size: 0.94rem; font-weight: 600; color: var(--ink); }
  .doc-progress {
    display: flex; align-items: center; gap: 6px;
    margin-top: 5px;
  }
  .doc-progress-bar {
    width: 60px; height: 5px; border-radius: 3px;
    background: var(--line-soft); overflow: hidden; flex-shrink: 0;
  }
  .doc-progress-bar span { display: block; height: 100%; background: var(--good); border-radius: 3px; }
  .doc-progress-label {
    font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3);
  }
  .doc-progress.is-complete .doc-progress-label { color: var(--good); }

  .doc-company { font-size: 0.78rem; color: var(--ink-2); }
  .doc-company.is-empty { color: var(--ink-3); font-style: italic; }

  .doc-expiry { text-align: right; }
  .doc-expiry-date { font-family: var(--mono); font-size: 0.85rem; color: var(--good); }
  .doc-row.status-soon .doc-expiry-date { color: var(--accent); }
  .doc-row.status-expired .doc-expiry-date { color: var(--bad); }
  .doc-expiry-flag { display: block; margin-top: 3px; font-family: var(--mono); font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--ink-3); }
  .doc-row.status-soon .doc-expiry-flag { color: var(--accent); }
  .doc-row.status-expired .doc-expiry-flag { color: var(--bad); }

  .doc-actions { display: flex; justify-content: flex-end; gap: 6px; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .doc-row.is-editing { display: none; }
  .doc-edit-row {
    display: none; flex-wrap: wrap; gap: 8px;
    background: var(--panel);
    border: 1px solid var(--accent);
    border-radius: 8px;
    padding: 14px 16px;
    margin-bottom: 4px;
  }
  .doc-row.is-editing + .doc-edit-row { display: flex; }
  .doc-edit-row input, .doc-edit-row select {
    padding: 8px 10px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .doc-edit-row input[name=edit-name] { flex: 1 1 220px; }
  .doc-edit-row select[name=edit-company] { width: 170px; }
  .doc-edit-row input[name=edit-expires] { width: 155px; font-family: var(--mono); }
  .doc-edit-row input:focus, .doc-edit-row select:focus { outline: none; border-color: var(--accent); }
  .doc-edit-row .edit-actions { display: flex; gap: 8px; margin-left: auto; }
  .doc-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .doc-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .doc-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .doc-edit-row .delete-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .doc-edit-row .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px; margin-bottom: 18px;
  }

  @media (max-width: 640px) {
    .doc-row { grid-template-columns: 1fr auto; }
    .doc-company { grid-column: 1 / 2; }
    .doc-expiry { grid-column: 2 / 3; grid-row: 1 / 3; }
    .doc-actions { grid-column: 1 / 3; justify-content: flex-start; }
  }

  .doc-row { cursor: pointer; }

  /* Popup cu task-urile unui document */
  .task-modal-overlay {
    position: fixed; inset: 0; z-index: 200;
    background: rgba(0,0,0,.55);
    display: flex; align-items: center; justify-content: center;
    padding: 20px;
  }
  .task-modal-overlay[hidden] { display: none; }
  .task-modal {
    width: 100%; max-width: 620px; max-height: 82vh;
    display: flex; flex-direction: column;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 10px;
    box-shadow: 0 20px 50px rgba(0,0,0,.5);
  }
  .task-modal-header {
    display: flex; align-items: center; gap: 10px;
    padding: 16px 18px;
    border-bottom: 1px solid var(--line-soft);
  }
  .task-modal-header h2 {
    flex: 1; margin: 0;
    font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink);
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .task-modal-close {
    width: 28px; height: 28px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 50%;
    color: var(--ink-3); cursor: pointer; font-size: 0.9rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .task-modal-close:hover { border-color: var(--bad); color: var(--bad); }
  .task-modal-body { padding: 16px 18px; overflow-y: auto; }

  .task-add-row { display: flex; gap: 8px; margin-bottom: 16px; }
  .task-add-row input {
    flex: 1;
    padding: 9px 12px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.86rem;
  }
  .task-add-row input:focus { outline: none; border-color: var(--accent); }
  .task-add-btn {
    padding: 9px 14px;
    background: var(--accent); border: none; border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.76rem;
    letter-spacing: 0.02em; text-transform: uppercase;
    cursor: pointer; white-space: nowrap;
    transition: background 0.2s ease;
  }
  .task-add-btn:hover { background: #c6923a; }

  .task-list { display: flex; flex-direction: column; gap: 8px; }
  .task-empty {
    text-align: center; color: var(--ink-3); font-family: var(--mono); font-size: 0.82rem;
    padding: 20px 10px;
  }
  .task-item {
    display: flex; align-items: flex-start; gap: 10px;
    padding: 10px 12px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
  }
  .task-check {
    flex-shrink: 0; margin-top: 1px;
    width: 20px; height: 20px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 50%;
    color: transparent; cursor: pointer; font-size: 0.7rem;
    transition: border-color 0.2s ease, background 0.2s ease, color 0.2s ease;
  }
  .task-check:hover { border-color: var(--accent); }
  .task-item.is-done .task-check { background: var(--good); border-color: var(--good); color: var(--panel); }
  .task-body { flex: 1; min-width: 0; }
  .task-text { font-size: 0.88rem; color: var(--ink); word-break: break-word; }
  .task-item.is-done .task-text { color: var(--ink-3); text-decoration: line-through; }
  .task-status {
    margin-top: 4px;
    font-family: var(--mono); font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--good);
  }
  .task-status-date {
    display: block; margin-top: 1px;
    font-family: var(--mono); font-size: 0.7rem; font-weight: 400; text-transform: none; letter-spacing: 0;
    color: var(--ink-3);
  }
  .task-delete {
    flex-shrink: 0;
    width: 22px; height: 22px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: none;
    color: var(--ink-3); cursor: pointer; font-size: 0.78rem;
    transition: color 0.2s ease;
  }
  .task-delete:hover { color: var(--bad); }
</style>
</head>
<body>

<header class="hero no-nav">
  <div class="wordmark"><strong>DOCS</strong></div>
</header>

<main>
  <h1><?= $lockedCompanyName !== null ? htmlspecialchars($lockedCompanyName) : 'Documente' ?></h1>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+  Adaugă document</button>

  <div class="add-card" id="addCard" hidden>
    <h2>Adaugă document</h2>
    <div class="add-row">
      <input type="text" name="name" id="newName" maxlength="<?= DOCS_NAME_MAX ?>" placeholder="Nume document" required>
      <?php if ($lockedCompanyName === null): ?>
        <select name="company_id" id="newCompany">
          <option value="0">Fără firmă</option>
          <?php foreach ($companies as $cid => $cname): ?>
            <option value="<?= $cid ?>"><?= htmlspecialchars($cname) ?></option>
          <?php endforeach; ?>
        </select>
      <?php else: ?>
        <select name="company_id" id="newCompany" disabled>
          <option value="<?= $lockedCompanyId ?>" selected><?= htmlspecialchars($lockedCompanyName) ?></option>
        </select>
      <?php endif; ?>
      <input type="date" name="expires_at" id="newExpires" required>
    </div>
    <button type="button" class="add-btn" id="addBtn">Adaugă document</button>
  </div>

  <div class="toolbar">
    <input type="text" class="search-input" id="searchInput" placeholder="Caută după nume...">
  </div>

  <?php if ($lockedCompanyName === null): ?>
    <div class="filter-bar" id="filterBar">
      <button class="filter-btn is-active" data-company="all">Toate <span class="count"><?= count($docs) ?></span></button>
      <?php foreach ($companies as $cid => $cname): ?>
        <?php $c = count(array_filter($docs, fn($d) => $d['company_id'] === $cid)); ?>
        <button class="filter-btn" data-company="<?= $cid ?>"><?= htmlspecialchars($cname) ?> <span class="count"><?= $c ?></span></button>
      <?php endforeach; ?>
      <?php if ($noCompanyCount > 0): ?>
        <button class="filter-btn" data-company="0">Fără firmă <span class="count"><?= $noCompanyCount ?></span></button>
      <?php endif; ?>
    </div>

    <button type="button" class="filter-burger-btn" id="filterBurgerBtn" aria-label="Filtre" aria-expanded="false">
      <span></span><span></span><span></span>
    </button>
    <div class="filter-burger-panel" id="filterBurgerPanel">
      <p class="burger-title">Filtrează după firmă</p>
      <div class="burger-links">
        <button type="button" class="is-active" data-company="all">Toate <span class="count"><?= count($docs) ?></span></button>
        <?php foreach ($companies as $cid => $cname): ?>
          <?php $c = count(array_filter($docs, fn($d) => $d['company_id'] === $cid)); ?>
          <button type="button" data-company="<?= $cid ?>"><?= htmlspecialchars($cname) ?> <span class="count"><?= $c ?></span></button>
        <?php endforeach; ?>
        <?php if ($noCompanyCount > 0): ?>
          <button type="button" data-company="0">Fără firmă <span class="count"><?= $noCompanyCount ?></span></button>
        <?php endif; ?>
      </div>
    </div>

    <details class="manage-companies">
      <summary>Administrează firmele (<?= count($companies) ?>)</summary>
      <div class="company-manage-list" id="companyManageList">
        <?php foreach ($companies as $cid => $cname): ?>
          <span class="company-chip" data-id="<?= $cid ?>">
            <span class="company-chip-row">
              <input type="text" class="company-name-input" maxlength="<?= DOCS_COMPANY_NAME_MAX ?>" value="<?= htmlspecialchars($cname) ?>">
              <button class="company-delete-btn" title="Șterge firma">✕</button>
            </span>
            <span class="company-password-row">
              <label for="companyPassword<?= $cid ?>">Parolă</label>
              <input type="text" id="companyPassword<?= $cid ?>" class="company-password-input" maxlength="<?= DOCS_COMPANY_PASSWORD_MAX ?>" value="<?= htmlspecialchars($companyPasswords[$cid] ?? '') ?>" placeholder="fără parolă">
            </span>
          </span>
        <?php endforeach; ?>
      </div>
      <div class="add-company-row">
        <input type="text" id="newCompanyName" maxlength="<?= DOCS_COMPANY_NAME_MAX ?>" placeholder="Firmă nouă">
        <button type="button" id="addCompanyBtn">+ Adaugă firmă</button>
      </div>
    </details>
  <?php endif; ?>

  <?php if (empty($docs)): ?>
    <div class="empty-state" id="emptyState">Niciun document adăugat încă. Adaugă primul mai sus.</div>
  <?php else: ?>
    <div class="doc-list" id="docList">
      <?php foreach ($docs as $doc): ?>
        <?php
          $companyName = $doc['company_id'] !== null ? ($companies[$doc['company_id']] ?? null) : null;
          $expiresDisplay = date('d.m.Y', strtotime($doc['expires_at']));
        ?>
        <div class="doc-row status-<?= $doc['status'] ?>" data-id="<?= $doc['id'] ?>" data-name="<?= htmlspecialchars(mb_strtolower($doc['name'])) ?>" data-company="<?= $doc['company_id'] ?? 0 ?>">
          <div class="doc-name">
            <span class="doc-name-text"><?= htmlspecialchars($doc['name']) ?></span>
            <?php if ($doc['task_total'] > 0): ?>
              <div class="doc-progress<?= $doc['task_pct'] === 100 ? ' is-complete' : '' ?>">
                <span class="doc-progress-bar"><span style="width: <?= $doc['task_pct'] ?>%"></span></span>
                <span class="doc-progress-label"><?= $doc['task_done'] ?>/<?= $doc['task_total'] ?> · <?= $doc['task_pct'] ?>%</span>
              </div>
            <?php endif; ?>
          </div>
          <div class="doc-company<?= $companyName === null ? ' is-empty' : '' ?>"><?= $companyName !== null ? htmlspecialchars($companyName) : 'Fără firmă' ?></div>
          <div class="doc-expiry">
            <span class="doc-expiry-date"><?= htmlspecialchars($expiresDisplay) ?></span>
            <span class="doc-expiry-flag"><?= htmlspecialchars($statusLabels[$doc['status']]) ?></span>
          </div>
          <div class="doc-actions">
            <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
            <button type="button" class="icon-btn delete-btn" title="Șterge">✕</button>
          </div>
        </div>
        <div class="doc-edit-row">
          <input type="text" name="edit-name" maxlength="<?= DOCS_NAME_MAX ?>" value="<?= htmlspecialchars($doc['name']) ?>" placeholder="Nume document">
          <?php if ($lockedCompanyName === null): ?>
            <select name="edit-company">
              <option value="0">Fără firmă</option>
              <?php foreach ($companies as $cid => $cname): ?>
                <option value="<?= $cid ?>"<?= $cid === $doc['company_id'] ? ' selected' : '' ?>><?= htmlspecialchars($cname) ?></option>
              <?php endforeach; ?>
            </select>
          <?php else: ?>
            <select name="edit-company" disabled>
              <option value="<?= $lockedCompanyId ?>" selected><?= htmlspecialchars($lockedCompanyName) ?></option>
            </select>
          <?php endif; ?>
          <input type="date" name="edit-expires" value="<?= htmlspecialchars($doc['expires_at']) ?>">
          <div class="edit-actions">
            <button type="button" class="save-btn">Salvează</button>
            <button type="button" class="cancel-btn">Anulează</button>
            <button type="button" class="delete-btn">Șterge</button>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

</main>

<?php site_render_footer(); ?>

<div class="task-modal-overlay" id="taskModalOverlay" hidden>
  <div class="task-modal">
    <div class="task-modal-header">
      <h2 id="taskModalTitle"></h2>
      <button type="button" class="task-modal-close" id="taskModalClose" aria-label="Închide">✕</button>
    </div>
    <div class="task-modal-body">
      <div class="task-add-row">
        <input type="text" id="taskNewText" maxlength="<?= DOCS_TASK_TEXT_MAX ?>" placeholder="Task nou...">
        <button type="button" class="task-add-btn" id="taskAddBtn">ADAUGĂ TASK</button>
      </div>
      <div class="task-list" id="taskList"></div>
    </div>
  </div>
</div>

<script>
(function() {
  var addToggleBtn = document.getElementById('addToggleBtn');
  var addCard = document.getElementById('addCard');
  if (addToggleBtn && addCard) {
    addToggleBtn.addEventListener('click', function() {
      addCard.hidden = !addCard.hidden;
      if (!addCard.hidden) document.getElementById('newName').focus();
    });
  }

  var searchInput = document.getElementById('searchInput');
  var filterBar = document.getElementById('filterBar');
  var list = document.getElementById('docList');
  var allFilterBtns = document.querySelectorAll('#filterBar .filter-btn, #filterBurgerPanel .burger-links button');
  var activeCompany = 'all';

  function applyFilters() {
    if (!list) return;
    var query = (searchInput.value || '').trim().toLowerCase();
    list.querySelectorAll('.doc-row').forEach(function(row) {
      var matchCompany = activeCompany === 'all' || row.getAttribute('data-company') === activeCompany;
      var matchSearch = !query || row.getAttribute('data-name').indexOf(query) !== -1;
      var visible = matchCompany && matchSearch;
      row.hidden = !visible;
      var editRow = row.nextElementSibling;
      if (editRow && editRow.classList.contains('doc-edit-row') && !visible) {
        row.classList.remove('is-editing');
      }
    });
  }

  if (searchInput) searchInput.addEventListener('input', applyFilters);

  function selectCompanyFilter(company) {
    activeCompany = company;
    allFilterBtns.forEach(function(b) { b.classList.toggle('is-active', b.getAttribute('data-company') === company); });
    applyFilters();
  }

  allFilterBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      selectCompanyFilter(btn.getAttribute('data-company'));
    });
  });

  // Burger cu filtrele (ecrane inguste unde bara de filtre de sus nu mai e la indemana dupa scroll)
  var filterBurgerBtn = document.getElementById('filterBurgerBtn');
  var filterBurgerPanel = document.getElementById('filterBurgerPanel');
  if (filterBurgerBtn && filterBurgerPanel) {
    var closeFilterBurger = function() {
      filterBurgerPanel.classList.remove('is-open');
      filterBurgerBtn.classList.remove('is-open');
      filterBurgerBtn.setAttribute('aria-expanded', 'false');
    };
    filterBurgerBtn.addEventListener('click', function() {
      var open = filterBurgerPanel.classList.toggle('is-open');
      filterBurgerBtn.classList.toggle('is-open', open);
      filterBurgerBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    filterBurgerPanel.querySelectorAll('button').forEach(function(b) {
      b.addEventListener('click', closeFilterBurger);
    });
    document.addEventListener('click', function(e) {
      if (!filterBurgerPanel.classList.contains('is-open')) return;
      if (filterBurgerPanel.contains(e.target) || filterBurgerBtn.contains(e.target)) return;
      closeFilterBurger();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') closeFilterBurger();
    });
  }

  // Administrare firme: adauga / redenumeste / sterge
  var companyManageList = document.getElementById('companyManageList');
  var addCompanyBtn = document.getElementById('addCompanyBtn');
  var newCompanyName = document.getElementById('newCompanyName');
  var newCompanySelect = document.getElementById('newCompany');

  function bindCompanyChip(chip) {
    var id = chip.getAttribute('data-id');
    var input = chip.querySelector('.company-name-input');
    var original = input.value;

    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { input.blur(); }
    });
    input.addEventListener('blur', function() {
      var name = input.value.trim();
      if (!name || name === original) { input.value = original; return; }
      fetch('company_rename.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('rename failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut redenumi firma (poate există deja o firmă cu acest nume).');
        input.value = original;
      });
    });

    var passwordInput = chip.querySelector('.company-password-input');
    var originalPassword = passwordInput.value;

    passwordInput.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { passwordInput.blur(); }
    });
    passwordInput.addEventListener('blur', function() {
      var password = passwordInput.value.trim();
      if (password === originalPassword) return;
      fetch('company_password.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, password: password }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('password update failed');
        originalPassword = password;
      }).catch(function() {
        alert('Nu s-a putut salva parola. Încearcă din nou.');
        passwordInput.value = originalPassword;
      });
    });

    chip.querySelector('.company-delete-btn').addEventListener('click', function() {
      if (!confirm('Ștergi această firmă? Documentele ei rămân, dar devin "Fără firmă".')) return;
      fetch('company_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge firma. Încearcă din nou.');
      });
    });
  }
  if (companyManageList) {
    companyManageList.querySelectorAll('.company-chip').forEach(bindCompanyChip);
  }

  if (addCompanyBtn) {
    addCompanyBtn.addEventListener('click', function() {
      var name = newCompanyName.value.trim();
      if (!name) return;
      fetch('company_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut adăuga firma (poate există deja o firmă cu acest nume).');
      });
    });
  }

  function wireRow(row) {
    var id = row.getAttribute('data-id');
    var editRow = row.nextElementSibling;
    var docName = row.querySelector('.doc-name-text').textContent;

    row.addEventListener('click', function(e) {
      if (e.target.closest('.doc-actions')) return;
      openTaskModal(id, docName);
    });

    row.querySelector('.edit-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      row.classList.add('is-editing');
    });

    if (!editRow || !editRow.classList.contains('doc-edit-row')) return;

    editRow.querySelector('.cancel-btn').addEventListener('click', function() {
      row.classList.remove('is-editing');
    });

    editRow.querySelector('.save-btn').addEventListener('click', function() {
      var name = editRow.querySelector('[name=edit-name]').value.trim();
      var companyId = editRow.querySelector('[name=edit-company]').value;
      var expires = editRow.querySelector('[name=edit-expires]').value;
      if (!name || !expires) {
        alert('Completează numele și data expirării.');
        return;
      }
      fetch('update_doc.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, name: name, company_id: companyId, expires_at: expires }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('update failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva modificarea. Încearcă din nou.');
      });
    });

    row.querySelector('.delete-btn').addEventListener('click', deleteDoc);
    editRow.querySelector('.delete-btn').addEventListener('click', deleteDoc);

    function deleteDoc() {
      if (!confirm('Ștergi acest document?')) return;
      fetch('delete_doc.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge documentul. Încearcă din nou.');
      });
    }
  }

  if (list) list.querySelectorAll('.doc-row').forEach(wireRow);

  // Popup cu task-urile unui document
  var taskModalOverlay = document.getElementById('taskModalOverlay');
  var taskModalTitle = document.getElementById('taskModalTitle');
  var taskModalClose = document.getElementById('taskModalClose');
  var taskList = document.getElementById('taskList');
  var taskNewText = document.getElementById('taskNewText');
  var taskAddBtn = document.getElementById('taskAddBtn');
  var currentDocId = null;

  function formatTaskDate(dateStr) {
    var parts = dateStr.split('-');
    return parts[2] + '.' + parts[1] + '.' + parts[0];
  }

  function renderTask(task) {
    var item = document.createElement('div');
    item.className = 'task-item' + (task.completed_at ? ' is-done' : '');
    item.setAttribute('data-id', task.id);

    var check = document.createElement('button');
    check.type = 'button';
    check.className = 'task-check';
    check.textContent = '✓';
    check.title = task.completed_at ? 'Marchează ca incomplet' : 'Marchează ca și complet';
    check.addEventListener('click', function() {
      fetch('task_toggle.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: task.id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('toggle failed');
        task.completed_at = data.completed_at;
        var newItem = renderTask(task);
        item.replaceWith(newItem);
        updateDocProgress();
      }).catch(function() {
        alert('Nu s-a putut actualiza task-ul. Încearcă din nou.');
      });
    });

    var body = document.createElement('div');
    body.className = 'task-body';
    var text = document.createElement('div');
    text.className = 'task-text';
    text.textContent = task.text;
    body.appendChild(text);
    if (task.completed_at) {
      var status = document.createElement('div');
      status.className = 'task-status';
      status.textContent = 'COMPLETED';
      var statusDate = document.createElement('span');
      statusDate.className = 'task-status-date';
      statusDate.textContent = formatTaskDate(task.completed_at);
      status.appendChild(statusDate);
      body.appendChild(status);
    }

    var del = document.createElement('button');
    del.type = 'button';
    del.className = 'task-delete';
    del.textContent = '✕';
    del.title = 'Șterge task';
    del.addEventListener('click', function() {
      if (!confirm('Ștergi acest task?')) return;
      fetch('task_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: task.id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        item.remove();
        if (!taskList.querySelector('.task-item')) renderEmptyTaskState();
        updateDocProgress();
      }).catch(function() {
        alert('Nu s-a putut șterge task-ul. Încearcă din nou.');
      });
    });

    item.appendChild(check);
    item.appendChild(body);
    item.appendChild(del);
    return item;
  }

  function renderEmptyTaskState() {
    taskList.innerHTML = '<div class="task-empty">Niciun task adăugat încă.</div>';
  }

  function updateDocProgress() {
    if (!currentDocId || !list) return;
    var row = list.querySelector('.doc-row[data-id="' + currentDocId + '"]');
    if (!row) return;
    var items = taskList.querySelectorAll('.task-item');
    var total = items.length;
    var done = taskList.querySelectorAll('.task-item.is-done').length;
    var nameEl = row.querySelector('.doc-name');
    var progressEl = nameEl.querySelector('.doc-progress');

    if (total === 0) {
      if (progressEl) progressEl.remove();
      return;
    }

    var pct = Math.round(done * 100 / total);
    if (!progressEl) {
      progressEl = document.createElement('div');
      progressEl.className = 'doc-progress';
      progressEl.innerHTML = '<span class="doc-progress-bar"><span></span></span><span class="doc-progress-label"></span>';
      nameEl.appendChild(progressEl);
    }
    progressEl.classList.toggle('is-complete', pct === 100);
    progressEl.querySelector('.doc-progress-bar span').style.width = pct + '%';
    progressEl.querySelector('.doc-progress-label').textContent = done + '/' + total + ' · ' + pct + '%';
  }

  function openTaskModal(docId, docName) {
    currentDocId = docId;
    taskModalTitle.textContent = docName;
    taskList.innerHTML = '<div class="task-empty">Se încarcă...</div>';
    taskNewText.value = '';
    taskModalOverlay.hidden = false;
    fetch('task_list.php?doc_id=' + encodeURIComponent(docId))
      .then(function(res) { return res.json(); })
      .then(function(data) {
        if (!data.ok) throw new Error('list failed');
        taskList.innerHTML = '';
        if (data.tasks.length === 0) {
          renderEmptyTaskState();
        } else {
          data.tasks.forEach(function(task) { taskList.appendChild(renderTask(task)); });
        }
      }).catch(function() {
        taskList.innerHTML = '<div class="task-empty">Nu s-au putut încărca task-urile.</div>';
      });
  }

  function closeTaskModal() {
    taskModalOverlay.hidden = true;
    currentDocId = null;
  }

  taskModalClose.addEventListener('click', closeTaskModal);
  taskModalOverlay.addEventListener('click', function(e) {
    if (e.target === taskModalOverlay) closeTaskModal();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && !taskModalOverlay.hidden) closeTaskModal();
  });

  function addTask() {
    var text = taskNewText.value.trim();
    if (!text || !currentDocId) return;
    fetch('task_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ doc_id: currentDocId, text: text }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      var emptyState = taskList.querySelector('.task-empty');
      if (emptyState) emptyState.remove();
      taskList.appendChild(renderTask({ id: data.id, text: data.text, completed_at: data.completed_at }));
      taskNewText.value = '';
      taskNewText.focus();
      updateDocProgress();
    }).catch(function() {
      alert('Nu s-a putut adăuga task-ul. Încearcă din nou.');
    });
  }

  taskAddBtn.addEventListener('click', addTask);
  taskNewText.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') addTask();
  });

  var addBtn = document.getElementById('addBtn');
  var newName = document.getElementById('newName');
  var newExpires = document.getElementById('newExpires');
  addBtn.addEventListener('click', function() {
    var name = newName.value.trim();
    var companyId = newCompanySelect.value;
    var expires = newExpires.value;
    if (!name || !expires) {
      alert('Completează numele și data expirării.');
      return;
    }
    fetch('add_doc.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ name: name, company_id: companyId, expires_at: expires }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut adăuga documentul. Încearcă din nou.');
    });
  });

  newName.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') addBtn.click();
  });
})();
</script>

</body>
</html>
