<?php
// Reels Instagram cu cocktail-uri, cu filtre custom (userul poate adauga/redenumi/sterge).
// Pagina de sine statatoare, in acelasi stil vizual ca /cs/ - fara header-ul/branding-ul site-ului.
require_once __DIR__ . '/cocktails/_defs.php';
require_once __DIR__ . '/includes/db.php';

cocktail_ensure_tables($mysqli);
site_theme_init($mysqli);

$filters = [];
$res = $mysqli->query('SELECT id, name FROM cocktail_filters ORDER BY sort_order ASC, id ASC');
if ($res) while ($row = $res->fetch_assoc()) $filters[(int)$row['id']] = $row['name'];

$filtersByReel = cocktail_filters_by_reel($mysqli);

$reels = [];
$res = $mysqli->query('SELECT id, url, description FROM cocktail_reels ORDER BY sort_order ASC, id DESC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $row['filter_ids'] = $filtersByReel[(int)$row['id']] ?? [];
        $reels[] = $row;
    }
}

$addErrorMessages = [
    'bad_url' => 'Link-ul nu pare a fi un reel/postare Instagram valid (ex: https://www.instagram.com/reel/XXXXXXX/).',
];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Cocktails</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 1200px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .filter-bar { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 18px; }
  .filter-btn {
    font-size: 0.78rem; padding: 5px 12px; border-radius: 14px;
    border: 1px solid var(--line); color: var(--ink-2);
    background: transparent; cursor: pointer; font-family: var(--disp);
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .filter-btn .count { font-family: var(--mono); font-size: 0.7rem; }
  .filter-btn.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }
  .filter-btn:hover:not(.is-active) { border-color: var(--accent); color: var(--ink); }

  .manage-filters {
    background: var(--panel);
    border: 1px solid var(--line); border-radius: 8px;
    padding: 14px 18px; margin: 0 0 26px;
  }
  .manage-filters summary {
    cursor: pointer; font-family: var(--disp); font-weight: 600; font-size: 0.82rem; color: var(--ink);
  }
  .manage-filters summary:hover { color: var(--accent); }
  .filter-manage-list { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
  .filter-chip {
    display: flex; align-items: center; gap: 6px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 14px;
    padding: 4px 6px 4px 12px; font-size: 0.82rem;
  }
  .filter-chip input {
    background: transparent; border: none; color: var(--ink); font-size: 0.82rem;
    width: 90px; padding: 2px 0; font-family: var(--disp);
  }
  .filter-chip input:focus { outline: none; border-bottom: 1px solid var(--accent); }
  .filter-chip button {
    background: transparent; border: none; color: var(--ink-3); cursor: pointer;
    width: 20px; height: 20px; border-radius: 50%; font-size: 0.85rem; line-height: 1;
  }
  .filter-chip button:hover { background: rgba(210,105,79,.15); color: var(--bad); }
  .add-filter-row { display: flex; gap: 8px; margin-top: 14px; }
  .add-filter-row input {
    padding: 8px 12px; background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-size: 0.85rem; width: 180px; font-family: var(--disp);
  }
  .add-filter-row input:focus { outline: none; border-color: var(--accent); }
  .add-filter-row button {
    padding: 8px 16px; border: 1px solid var(--line); border-radius: 5px;
    background: transparent; color: var(--ink-2); font-family: var(--disp); font-weight: 600; font-size: 0.78rem; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-filter-row button:hover { border-color: var(--accent); color: var(--accent); }

  .reel-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 360px));
    justify-content: center;
    gap: 18px;
  }
  .reel-card {
    display: flex; flex-direction: column;
    background: var(--panel);
    border: 1px solid rgba(240,236,228,.09);
    border-radius: 9px;
    overflow: hidden;
  }
  .reel-card.is-hidden { display: none; }
  .reel-embed { background: #000; min-height: 200px; }
  .reel-embed iframe, .reel-embed blockquote { width: 100% !important; margin: 0 !important; }
  .reel-fallback-link {
    display: block; text-align: center;
    padding: 7px 10px;
    background: var(--bg);
    border-bottom: 1px solid var(--line-soft);
    color: var(--ink-3);
    font-family: var(--mono); font-size: 0.7rem;
  }
  .reel-fallback-link:hover { color: var(--accent); }
  .reel-body { padding: 13px 15px; display: flex; flex-direction: column; gap: 8px; }
  .reel-tags { display: flex; gap: 6px; flex-wrap: wrap; }
  .tag {
    padding: 2px 10px; border-radius: 10px;
    font-family: var(--mono); font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.06em;
    border: 1px solid currentColor; color: var(--accent);
  }
  .tag.empty { color: var(--ink-3); border-style: dashed; }
  .reel-desc { font-size: 0.88rem; color: var(--ink); min-height: 1.2em; white-space: pre-wrap; }
  .reel-desc:empty::before { content: "Fără descriere"; color: var(--ink-3); font-style: italic; }

  .reel-actions { display: flex; gap: 6px; margin-top: 2px; }
  .reel-actions button {
    flex: 1; padding: 6px 10px; background: transparent; border: 1px solid var(--line);
    border-radius: 5px; color: var(--ink-3); font-family: var(--mono); font-size: 0.72rem; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .reel-actions .edit-btn:hover { border-color: var(--accent); color: var(--accent); }
  .reel-actions .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .reel-edit { display: none; flex-direction: column; gap: 8px; }
  .reel-card.is-editing .reel-view { display: none; }
  .reel-card.is-editing .reel-edit { display: flex; }
  .reel-edit textarea {
    padding: 8px 10px; background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-size: 0.85rem; font-family: inherit; resize: vertical; min-height: 54px;
  }
  .reel-edit textarea:focus { outline: none; border-color: var(--accent); }
  .reel-edit .edit-filters { display: flex; flex-wrap: wrap; gap: 6px; }
  .reel-edit .edit-filter-toggle {
    padding: 4px 10px; border-radius: 14px; border: 1px solid var(--line); background: var(--bg);
    color: var(--ink-2); font-family: var(--mono); font-size: 0.7rem; cursor: pointer;
  }
  .reel-edit .edit-filter-toggle.is-on { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
  .reel-edit .edit-actions { display: flex; gap: 8px; }
  .reel-edit .edit-actions button {
    flex: 1; padding: 8px 10px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .reel-edit .save-btn { background: var(--accent); color: var(--on-accent); }
  .reel-edit .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px;
  }

  .add-toggle-btn {
    display: block; width: 100%; margin-top: 28px;
    padding: 11px 14px;
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
    margin-top: 14px;
  }
  .add-card[hidden] { display: none; }
  .add-card h2 {
    margin: 0 0 14px;
    font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink);
  }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input[type=url] {
    flex: 1 1 260px; padding: 10px 14px; background: var(--panel); border: 1px solid var(--line);
    border-radius: 6px; color: var(--ink); font-family: var(--mono); font-size: 0.9rem;
  }
  .add-row textarea {
    flex: 1 1 100%; padding: 10px 14px; background: var(--panel); border: 1px solid var(--line);
    border-radius: 6px; color: var(--ink); font-size: 0.9rem; font-family: var(--disp); resize: vertical; min-height: 60px;
  }
  .add-row input:focus, .add-row textarea:focus { outline: none; border-color: var(--accent); }
  .char-count { font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); text-align: right; width: 100%; margin-top: -6px; }
  .add-filters { display: flex; flex-wrap: wrap; gap: 6px; width: 100%; }
  .add-filter-toggle {
    padding: 5px 12px; border-radius: 14px; border: 1px solid var(--line); background: var(--bg);
    color: var(--ink-2); font-family: var(--mono); font-size: 0.75rem; cursor: pointer;
  }
  .add-filter-toggle.is-on { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
  .add-btn {
    width: 100%; margin-top: 4px;
    padding: 11px 18px;
    background: var(--accent); border: none; border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-btn:hover { background: #c6923a; }

  .add-error-banner {
    padding: 11px 15px; margin-bottom: 20px;
    border-left: 2px solid var(--bad); border-radius: 0 6px 6px 0;
    background: rgba(210,105,79,.08);
    color: var(--ink); font-size: 0.85rem;
  }
</style>
</head>
<body>

<header class="hero no-nav">
  <div class="wordmark"><strong>COCKTAILS</strong></div>
</header>

<main>
  <h1>Cocktails</h1>

  <?php if (!empty($_GET['add_error'])): ?>
    <?php
      $code = $_GET['add_error'];
      $msg = $addErrorMessages[$code] ?? ('Eroare necunoscută (cod: ' . $code . ').');
    ?>
    <div class="add-error-banner">Nu s-a putut adăuga reel-ul. <?= htmlspecialchars($msg) ?></div>
  <?php endif; ?>

  <div class="filter-bar" id="filterBar">
    <button class="filter-btn is-active" data-filter="all">Toate <span class="count"><?= count($reels) ?></span></button>
    <?php foreach ($filters as $fid => $fname): ?>
      <?php $c = count(array_filter($reels, fn($r) => in_array($fid, $r['filter_ids'], true))); ?>
      <button class="filter-btn" data-filter="<?= $fid ?>"><?= htmlspecialchars($fname) ?> <span class="count"><?= $c ?></span></button>
    <?php endforeach; ?>
  </div>

  <details class="manage-filters">
    <summary>Administrează filtrele (<?= count($filters) ?>)</summary>
    <div class="filter-manage-list" id="filterManageList">
      <?php foreach ($filters as $fid => $fname): ?>
        <span class="filter-chip" data-id="<?= $fid ?>">
          <input type="text" class="filter-name-input" maxlength="<?= COCKTAIL_FILTER_NAME_MAX ?>" value="<?= htmlspecialchars($fname) ?>">
          <button class="filter-delete-btn" title="Șterge filtrul">✕</button>
        </span>
      <?php endforeach; ?>
    </div>
    <div class="add-filter-row">
      <input type="text" id="newFilterName" maxlength="<?= COCKTAIL_FILTER_NAME_MAX ?>" placeholder="Filtru nou (ex: rum, sour, tiki)">
      <button type="button" id="addFilterBtn">+ Adaugă filtru</button>
    </div>
  </details>

  <?php if (empty($reels)): ?>
    <div class="empty-state">Niciun reel adăugat încă. Adaugă primul mai jos.</div>
  <?php else: ?>
    <div class="reel-grid" id="reelGrid">
      <?php foreach ($reels as $reel): ?>
        <div class="reel-card" data-id="<?= (int)$reel['id'] ?>" data-filters="<?= htmlspecialchars(implode(',', $reel['filter_ids'])) ?>">
          <div class="reel-embed">
            <blockquote class="instagram-media" data-instgrm-permalink="<?= htmlspecialchars($reel['url']) ?>" data-instgrm-version="14"></blockquote>
          </div>
          <a class="reel-fallback-link" href="<?= htmlspecialchars($reel['url']) ?>" target="_blank" rel="noopener">Vezi pe Instagram ↗</a>
          <div class="reel-body">
            <div class="reel-view">
              <div class="reel-tags">
                <?php if ($reel['filter_ids']): ?>
                  <?php foreach ($reel['filter_ids'] as $fid): ?>
                    <?php if (isset($filters[$fid])): ?>
                      <span class="tag"><?= htmlspecialchars($filters[$fid]) ?></span>
                    <?php endif; ?>
                  <?php endforeach; ?>
                <?php else: ?>
                  <span class="tag empty">Fără filtru</span>
                <?php endif; ?>
              </div>
              <div class="reel-desc"><?= htmlspecialchars($reel['description'] ?? '') ?></div>
              <div class="reel-actions">
                <button class="edit-btn">✎ Editează</button>
                <button class="delete-btn">✕ Șterge</button>
              </div>
            </div>
            <div class="reel-edit">
              <textarea class="edit-desc" maxlength="<?= COCKTAIL_DESC_MAX ?>" placeholder="Descriere (max <?= COCKTAIL_DESC_MAX ?> caractere)"><?= htmlspecialchars($reel['description'] ?? '') ?></textarea>
              <div class="edit-filters">
                <?php foreach ($filters as $fid => $fname): ?>
                  <button type="button" class="edit-filter-toggle<?= in_array($fid, $reel['filter_ids'], true) ? ' is-on' : '' ?>" data-filter-id="<?= $fid ?>"><?= htmlspecialchars($fname) ?></button>
                <?php endforeach; ?>
              </div>
              <div class="edit-actions">
                <button class="save-btn">Salvează</button>
                <button class="cancel-btn">Anulează</button>
              </div>
            </div>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă reel</button>

  <div class="add-card" id="addCard" hidden>
    <h2>Adaugă reel</h2>
    <form class="add-form" method="post" action="/cocktails/add_reel.php">
      <div class="add-row">
        <input type="url" name="url" placeholder="Link Instagram reel (https://www.instagram.com/reel/...)" required>
        <textarea name="description" id="addDescription" maxlength="<?= COCKTAIL_DESC_MAX ?>" placeholder="Descriere (max <?= COCKTAIL_DESC_MAX ?> caractere)"></textarea>
        <span class="char-count"><span id="addDescCount">0</span>/<?= COCKTAIL_DESC_MAX ?></span>
        <div class="add-filters" id="addFilters">
          <?php foreach ($filters as $fid => $fname): ?>
            <button type="button" class="add-filter-toggle" data-filter-id="<?= $fid ?>"><?= htmlspecialchars($fname) ?></button>
          <?php endforeach; ?>
        </div>
      </div>
      <button type="submit" class="add-btn">Adaugă reel</button>
    </form>
  </div>

</main>

<?php site_render_footer(); ?>

<script async src="//www.instagram.com/embed.js"></script>
<script>
(function() {
  var addToggleBtn = document.getElementById('addToggleBtn');
  var addCard = document.getElementById('addCard');
  if (addToggleBtn && addCard) {
    addToggleBtn.addEventListener('click', function() {
      addCard.hidden = !addCard.hidden;
      if (!addCard.hidden) addCard.querySelector('input[name=url]').focus();
    });
  }

  // Filtrare pe categorie (custom, definita de user)
  var filterBar = document.getElementById('filterBar');
  var grid = document.getElementById('reelGrid');
  if (filterBar && grid) {
    filterBar.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var filterId = btn.getAttribute('data-filter');
        filterBar.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.toggle('is-active', b === btn); });
        grid.querySelectorAll('.reel-card').forEach(function(card) {
          var ids = (card.getAttribute('data-filters') || '').split(',');
          card.classList.toggle('is-hidden', filterId !== 'all' && ids.indexOf(filterId) === -1);
        });
      });
    });
  }

  // Formularul de adaugare: toggle filtre (hidden inputs) + contor caractere
  var addForm = document.querySelector('.add-form');
  if (addForm) {
    var addFilters = document.getElementById('addFilters');
    addFilters.querySelectorAll('.add-filter-toggle').forEach(function(btn) {
      btn.addEventListener('click', function() {
        btn.classList.toggle('is-on');
      });
    });
    addForm.addEventListener('submit', function() {
      addFilters.querySelectorAll('.add-filter-toggle.is-on').forEach(function(btn) {
        var input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'filters[]';
        input.value = btn.getAttribute('data-filter-id');
        addForm.appendChild(input);
      });
    });

    var descArea = document.getElementById('addDescription');
    var descCount = document.getElementById('addDescCount');
    descArea.addEventListener('input', function() {
      descCount.textContent = descArea.value.length;
    });
  }

  // Administrare filtre: adauga / redenumeste / sterge
  var filterManageList = document.getElementById('filterManageList');
  var addFilterBtn = document.getElementById('addFilterBtn');
  var newFilterName = document.getElementById('newFilterName');

  function addFilterChip(id, name) {
    var chip = document.createElement('span');
    chip.className = 'filter-chip';
    chip.setAttribute('data-id', id);
    chip.innerHTML = '<input type="text" class="filter-name-input" maxlength="<?= COCKTAIL_FILTER_NAME_MAX ?>" value="">' +
                      '<button class="filter-delete-btn" title="Șterge filtrul">✕</button>';
    chip.querySelector('.filter-name-input').value = name;
    filterManageList.appendChild(chip);
    bindFilterChip(chip);

    var filterBarBtn = document.createElement('button');
    filterBarBtn.className = 'filter-btn';
    filterBarBtn.setAttribute('data-filter', id);
    filterBarBtn.innerHTML = name + ' <span class="count">0</span>';
    filterBar.appendChild(filterBarBtn);
    filterBarBtn.addEventListener('click', function() {
      filterBar.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.toggle('is-active', b === filterBarBtn); });
      grid && grid.querySelectorAll('.reel-card').forEach(function(card) {
        var ids = (card.getAttribute('data-filters') || '').split(',');
        card.classList.toggle('is-hidden', ids.indexOf(String(id)) === -1);
      });
    });

    var addToggle = document.createElement('button');
    addToggle.type = 'button';
    addToggle.className = 'add-filter-toggle';
    addToggle.setAttribute('data-filter-id', id);
    addToggle.textContent = name;
    addToggle.addEventListener('click', function() { addToggle.classList.toggle('is-on'); });
    document.getElementById('addFilters').appendChild(addToggle);
  }

  if (addFilterBtn) {
    addFilterBtn.addEventListener('click', function() {
      var name = newFilterName.value.trim();
      if (!name) return;
      fetch('/cocktails/filter_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        addFilterChip(data.id, data.name);
        newFilterName.value = '';
      }).catch(function() {
        alert('Nu s-a putut adăuga filtrul. Încearcă din nou.');
      });
    });
  }

  function bindFilterChip(chip) {
    var id = chip.getAttribute('data-id');
    var input = chip.querySelector('.filter-name-input');
    var original = input.value;

    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { input.blur(); }
    });
    input.addEventListener('blur', function() {
      var name = input.value.trim();
      if (!name || name === original) { input.value = original; return; }
      fetch('/cocktails/filter_rename.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('rename failed');
        original = name;
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut redenumi filtrul (poate există deja un filtru cu acest nume).');
        input.value = original;
      });
    });

    chip.querySelector('.filter-delete-btn').addEventListener('click', function() {
      if (!confirm('Ștergi acest filtru? Va fi scos și de pe reels-urile care îl folosesc.')) return;
      fetch('/cocktails/filter_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge filtrul. Încearcă din nou.');
      });
    });
  }
  if (filterManageList) {
    filterManageList.querySelectorAll('.filter-chip').forEach(bindFilterChip);
  }

  // Reels: editare / stergere
  if (grid) {
    grid.querySelectorAll('.reel-card').forEach(function(card) {
      var id = card.getAttribute('data-id');

      card.querySelector('.edit-btn').addEventListener('click', function() {
        card.classList.add('is-editing');
      });
      card.querySelector('.cancel-btn').addEventListener('click', function() {
        card.classList.remove('is-editing');
      });

      card.querySelectorAll('.edit-filter-toggle').forEach(function(btn) {
        btn.addEventListener('click', function() { btn.classList.toggle('is-on'); });
      });

      card.querySelector('.save-btn').addEventListener('click', function() {
        var desc = card.querySelector('.edit-desc').value.trim();
        var filterIds = [];
        card.querySelectorAll('.edit-filter-toggle.is-on').forEach(function(btn) {
          filterIds.push(btn.getAttribute('data-filter-id'));
        });

        var body = new URLSearchParams({ id: id, description: desc });
        filterIds.forEach(function(fid) { body.append('filters[]', fid); });

        fetch('/cocktails/update_reel.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body.toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('save failed');
          location.reload();
        }).catch(function() {
          alert('Nu s-a putut salva. Încearcă din nou.');
        });
      });

      card.querySelector('.delete-btn').addEventListener('click', function() {
        if (!confirm('Ștergi acest reel?')) return;
        fetch('/cocktails/delete_reel.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('delete failed');
          location.reload();
        }).catch(function() {
          alert('Nu s-a putut șterge reel-ul. Încearcă din nou.');
        });
      });
    });
  }
})();
</script>

</body>
</html>
