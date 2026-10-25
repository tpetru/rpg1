<?php
require_once __DIR__ . '/_auth.php';
casa_require_admin_auth();
// Pagina de admin cu furnizorii de materiale. Lista e globala (nu tine de o casa anume) - vezi
// _suppliers.php. Filtrarea se face in pagina, pe lista deja incarcata: sunt zeci de randuri, nu
// mii, deci nu merita un drum in plus la server pentru fiecare bifa.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_suppliers.php';

$suppliers = casa_suppliers_all($mysqli);

// Categoriile existente, pentru pastilele de filtrare si pentru sugestiile din formular.
$categories = [];
$subcategories = [];
foreach ($suppliers as $s) {
    if ($s['category'] !== '') $categories[$s['category']] = ($categories[$s['category']] ?? 0) + 1;
    if ($s['subcategory'] !== '') $subcategories[$s['subcategory']] = true;
}
ksort($categories, SORT_NATURAL | SORT_FLAG_CASE);
ksort($subcategories, SORT_NATURAL | SORT_FLAG_CASE);
$noCategoryCount = count(array_filter($suppliers, fn($s) => $s['category'] === ''));
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Furnizori</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  main { max-width: 1100px; margin: 0 auto; padding: 44px 24px 60px; }
  h1 { margin: 0 0 8px; font-family: var(--disp); font-size: 1.9rem; font-weight: 600; color: var(--ink); }
  main > p.sub { margin: 0 0 28px; color: var(--ink-2); font-size: 0.95rem; }
  .top-links { display: flex; justify-content: flex-end; gap: 18px; margin-bottom: 26px; font-size: 0.82rem; }
  .top-links a { color: var(--ink-3); }
  .top-links a:hover { color: var(--accent); }

  .add-card {
    background: var(--panel);
    border: 1px solid var(--line); border-radius: 8px;
    padding: 18px 20px; margin-bottom: 26px;
  }
  .add-card h2 { margin: 0 0 14px; font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--ink); }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input {
    padding: 9px 13px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-size: 0.9rem; font-family: var(--disp);
  }
  .add-row input:focus { outline: none; border-color: var(--accent); }
  .add-row input[name=name] { flex: 2 1 200px; }
  .add-row input[name=category], .add-row input[name=subcategory] { flex: 1 1 140px; }
  .add-row input[name=tags] { flex: 1 1 170px; }
  .add-row input[name=url] { flex: 2 1 220px; }
  .add-row button {
    padding: 9px 20px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer; transition: background 0.2s ease;
  }
  .add-error { margin: 12px 0 0; color: var(--bad); font-size: 0.85rem; }

  .toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; margin-bottom: 12px; }
  .search-input {
    flex: 1 1 240px; padding: 9px 13px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .search-input:focus { outline: none; border-color: var(--accent); }
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

  .supplier-list { display: flex; flex-direction: column; }
  .supplier-row {
    display: grid;
    grid-template-columns: 62px 1fr 150px 150px 1fr 34px;
    align-items: center; gap: 14px;
    padding: 11px 4px;
    border-bottom: 1px solid var(--line-soft);
  }
  .supplier-row[hidden] { display: none; }
  .list-head { color: var(--ink-3); font-family: var(--mono); font-size: 0.62rem;
    text-transform: uppercase; letter-spacing: 0.07em; border-bottom: 1px solid var(--line); }
  .cell-order { display: flex; gap: 4px; }
  .reorder-btn {
    width: 26px; height: 26px; line-height: 1;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.7rem;
  }
  .reorder-btn:hover:not(:disabled) { border-color: var(--accent); color: var(--accent); }
  .reorder-btn:disabled { opacity: 0.3; cursor: default; }
  .supplier-name { font-size: 0.94rem; font-weight: 600; color: var(--ink); overflow-wrap: anywhere; }
  .supplier-name a { color: inherit; text-decoration: none; }
  .supplier-name a:hover { color: var(--accent); text-decoration: underline; text-underline-offset: 3px; }
  .supplier-cat { font-size: 0.82rem; color: var(--ink-2); }
  .supplier-cat.is-empty { color: var(--ink-3); font-style: italic; }
  .supplier-tags { display: flex; flex-wrap: wrap; gap: 5px; }
  .tag {
    font-size: 0.72rem; color: var(--ink-2);
    background: var(--panel); border: 1px solid var(--line-soft);
    border-radius: 10px; padding: 2px 9px;
  }
  .delete-btn {
    width: 26px; height: 26px; line-height: 1;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.75rem;
  }
  .delete-btn:hover { border-color: var(--bad); color: var(--bad); }
  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 36px 20px; border: 1px dashed var(--line); border-radius: 8px;
  }

  @media (max-width: 820px) {
    .supplier-row { grid-template-columns: 62px 1fr 34px; row-gap: 4px; }
    .list-head { display: none; }
    .supplier-cat, .supplier-tags { grid-column: 2 / 3; }
  }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span>admin</span></div>
  </div>
</header>

<main>
  <div class="top-links">
    <a class="back-link" href="/admin.php"><span class="arrow">←</span> Case</a>
    <a href="/admin.php?logout">Ieși din admin</a>
  </div>

  <h1>Furnizori</h1>
  <p class="sub">Lista de furnizori de materiale, comună tuturor caselor.</p>

  <div class="add-card">
    <h2>Adaugă furnizor</h2>
    <div class="add-row">
      <input type="text" name="name" id="newName" maxlength="<?= CASA_SUPPLIER_NAME_MAX ?>" placeholder="Nume" required>
      <input type="text" name="category" id="newCategory" maxlength="<?= CASA_SUPPLIER_CATEGORY_MAX ?>" placeholder="Categorie" list="categoryList">
      <input type="text" name="subcategory" id="newSubcategory" maxlength="<?= CASA_SUPPLIER_CATEGORY_MAX ?>" placeholder="Subcategorie" list="subcategoryList">
      <input type="text" name="tags" id="newTags" maxlength="<?= CASA_SUPPLIER_TAGS_MAX ?>" placeholder="Tag-uri, separate prin virgulă">
      <input type="text" name="url" id="newUrl" maxlength="<?= CASA_SUPPLIER_URL_MAX ?>" placeholder="Link">
      <button type="button" id="addBtn">Adaugă</button>
    </div>
    <p class="add-error" id="addError" hidden></p>
    <datalist id="categoryList">
      <?php foreach (array_keys($categories) as $cat): ?><option value="<?= htmlspecialchars($cat) ?>"></option><?php endforeach; ?>
    </datalist>
    <datalist id="subcategoryList">
      <?php foreach (array_keys($subcategories) as $sub): ?><option value="<?= htmlspecialchars($sub) ?>"></option><?php endforeach; ?>
    </datalist>
  </div>

  <div class="toolbar">
    <input type="text" class="search-input" id="searchInput" placeholder="Caută după nume, subcategorie sau tag...">
  </div>

  <div class="filter-bar" id="filterBar">
    <button type="button" class="filter-btn is-active" data-category="all">Toate <span class="count"><?= count($suppliers) ?></span></button>
    <?php foreach ($categories as $cat => $count): ?>
      <button type="button" class="filter-btn" data-category="<?= htmlspecialchars($cat) ?>"><?= htmlspecialchars($cat) ?> <span class="count"><?= $count ?></span></button>
    <?php endforeach; ?>
    <?php if ($noCategoryCount > 0): ?>
      <button type="button" class="filter-btn" data-category="">Fără categorie <span class="count"><?= $noCategoryCount ?></span></button>
    <?php endif; ?>
  </div>

  <?php if (empty($suppliers)): ?>
    <div class="empty-state">Niciun furnizor încă. Adaugă primul mai sus.</div>
  <?php else: ?>
    <div class="supplier-row list-head">
      <span>Ordine</span><span>Nume</span><span>Categorie</span><span>Subcategorie</span><span>Tag-uri</span><span></span>
    </div>
    <div class="supplier-list" id="supplierList">
      <?php foreach ($suppliers as $i => $s): ?>
        <div class="supplier-row" data-id="<?= $s['id'] ?>"
             data-category="<?= htmlspecialchars($s['category']) ?>"
             data-search="<?= htmlspecialchars(mb_strtolower($s['name'] . ' ' . $s['subcategory'] . ' ' . $s['tags'])) ?>">
          <span class="cell-order">
            <button type="button" class="reorder-btn" data-dir="up" title="Mută mai sus"<?= $i === 0 ? ' disabled' : '' ?>>▲</button>
            <button type="button" class="reorder-btn" data-dir="down" title="Mută mai jos"<?= $i === count($suppliers) - 1 ? ' disabled' : '' ?>>▼</button>
          </span>
          <span class="supplier-name">
            <?php if ($s['url'] !== ''): ?>
              <a href="<?= htmlspecialchars($s['url']) ?>" target="_blank" rel="noopener"><?= htmlspecialchars($s['name']) ?> ↗</a>
            <?php else: ?>
              <?= htmlspecialchars($s['name']) ?>
            <?php endif; ?>
          </span>
          <span class="supplier-cat<?= $s['category'] === '' ? ' is-empty' : '' ?>"><?= $s['category'] !== '' ? htmlspecialchars($s['category']) : '—' ?></span>
          <span class="supplier-cat<?= $s['subcategory'] === '' ? ' is-empty' : '' ?>"><?= $s['subcategory'] !== '' ? htmlspecialchars($s['subcategory']) : '—' ?></span>
          <span class="supplier-tags">
            <?php foreach (casa_supplier_tag_list($s['tags']) as $tag): ?>
              <span class="tag"><?= htmlspecialchars($tag) ?></span>
            <?php endforeach; ?>
          </span>
          <span><button type="button" class="delete-btn" title="Șterge furnizorul">✕</button></span>
        </div>
      <?php endforeach; ?>
    </div>
    <div class="empty-state" id="noMatches" hidden>Niciun furnizor nu se potrivește filtrelor.</div>
  <?php endif; ?>
</main>

<?php casa_render_footer(); ?>

<script>
(function() {
  // ---------- adăugare ----------
  var addBtn = document.getElementById('addBtn');
  var addError = document.getElementById('addError');
  var fields = {
    name: document.getElementById('newName'),
    category: document.getElementById('newCategory'),
    subcategory: document.getElementById('newSubcategory'),
    tags: document.getElementById('newTags'),
    url: document.getElementById('newUrl')
  };

  function addSupplier() {
    var body = new URLSearchParams();
    Object.keys(fields).forEach(function(k) { body.set(k, fields[k].value.trim()); });
    if (!body.get('name')) { fields.name.focus(); return; }

    addBtn.disabled = true;
    addError.hidden = true;
    fetch('furnizori_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    }).then(function(res) { return res.json().then(function(d) { return { ok: res.ok, data: d }; }); })
      .then(function(r) {
        if (!r.ok || !r.data.ok) throw new Error(r.data.error || 'Nu s-a putut adăuga furnizorul.');
        location.reload();
      }).catch(function(err) {
        addError.textContent = err.message;
        addError.hidden = false;
        addBtn.disabled = false;
      });
  }
  addBtn.addEventListener('click', addSupplier);
  Object.keys(fields).forEach(function(k) {
    fields[k].addEventListener('keydown', function(e) { if (e.key === 'Enter') addSupplier(); });
  });

  var list = document.getElementById('supplierList');
  if (!list) return;

  // ---------- filtrare (în pagină) ----------
  var searchInput = document.getElementById('searchInput');
  var noMatches = document.getElementById('noMatches');
  var filterBtns = document.querySelectorAll('#filterBar .filter-btn');
  var activeCategory = 'all';

  function applyFilters() {
    var query = (searchInput.value || '').trim().toLowerCase();
    var shown = 0;
    list.querySelectorAll('.supplier-row').forEach(function(row) {
      var matchCat = activeCategory === 'all' || row.getAttribute('data-category') === activeCategory;
      var matchText = !query || row.getAttribute('data-search').indexOf(query) !== -1;
      var visible = matchCat && matchText;
      row.hidden = !visible;
      if (visible) shown++;
    });
    noMatches.hidden = shown > 0;
  }
  searchInput.addEventListener('input', applyFilters);
  filterBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      activeCategory = btn.getAttribute('data-category');
      filterBtns.forEach(function(b) { b.classList.toggle('is-active', b === btn); });
      applyFilters();
    });
  });

  // ---------- reordonare / ștergere ----------
  list.querySelectorAll('.supplier-row').forEach(function(row) {
    var id = row.getAttribute('data-id');

    row.querySelectorAll('.reorder-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        row.querySelectorAll('.reorder-btn').forEach(function(b) { b.disabled = true; });
        fetch('furnizori_reorder.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, direction: btn.getAttribute('data-dir') }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('reorder failed');
          if (data.moved) location.reload();
          else row.querySelectorAll('.reorder-btn').forEach(function(b) { b.disabled = false; });
        }).catch(function() {
          alert('Nu s-a putut muta furnizorul. Încearcă din nou.');
          row.querySelectorAll('.reorder-btn').forEach(function(b) { b.disabled = false; });
        });
      });
    });

    row.querySelector('.delete-btn').addEventListener('click', function() {
      var name = row.querySelector('.supplier-name').textContent.trim();
      if (!confirm('Ștergi furnizorul „' + name.replace(' ↗', '') + '”?')) return;
      fetch('furnizori_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge furnizorul. Încearcă din nou.');
      });
    });
  });
})();
</script>

</body>
</html>
