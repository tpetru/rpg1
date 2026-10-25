<?php
// Lista de alimente - folosita de /aris/ (mese), /aris/retete.php (ingrediente) si
// /aris/alergeni.php. Pagina de sine statatoare pentru a le administra (adauga/redenumeste/sterge),
// in loc sa fie ingropata intr-un panou pliabil pe pagina de plan.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

$foods = [];
$res = $mysqli->query('SELECT id, name FROM aris_foods ORDER BY name ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $foods[(int)$row['id']] = $row['name'];
    }
}

// De cate ori apare fiecare aliment in retete (numarul de linii-ingredient, nu de retete distincte
// - daca ar aparea de doua ori in aceeasi reteta, ar conta de doua ori).
$recipeUsage = [];
$res = $mysqli->query('SELECT food_id, COUNT(*) AS cnt FROM aris_recipe_items WHERE food_id IS NOT NULL GROUP BY food_id');
if ($res) while ($row = $res->fetch_assoc()) $recipeUsage[(int)$row['food_id']] = (int)$row['cnt'];

// De cate ori i-a fost dat efectiv copilului fiecare aliment - fie direct (masa cu acel aliment),
// fie ca parte a unei retete pe care a mancat-o.
$givenDirect = [];
$res = $mysqli->query('SELECT food_id, COUNT(*) AS cnt FROM aris_meals WHERE food_id IS NOT NULL GROUP BY food_id');
if ($res) while ($row = $res->fetch_assoc()) $givenDirect[(int)$row['food_id']] = (int)$row['cnt'];

$mealsByRecipe = [];
$res = $mysqli->query('SELECT recipe_id, COUNT(*) AS cnt FROM aris_meals WHERE recipe_id IS NOT NULL GROUP BY recipe_id');
if ($res) while ($row = $res->fetch_assoc()) $mealsByRecipe[(int)$row['recipe_id']] = (int)$row['cnt'];

$givenViaRecipe = [];
if (!empty($mealsByRecipe)) {
    $recipeIds = implode(',', array_map('intval', array_keys($mealsByRecipe)));
    $res = $mysqli->query("SELECT DISTINCT recipe_id, food_id FROM aris_recipe_items WHERE food_id IS NOT NULL AND recipe_id IN ($recipeIds)");
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $fid = (int)$row['food_id'];
            $rid = (int)$row['recipe_id'];
            $givenViaRecipe[$fid] = ($givenViaRecipe[$fid] ?? 0) + $mealsByRecipe[$rid];
        }
    }
}

$givenTotal = [];
foreach ($foods as $fid => $fname) {
    $givenTotal[$fid] = ($givenDirect[$fid] ?? 0) + ($givenViaRecipe[$fid] ?? 0);
}

// Statusul de alergen per aliment (doar pentru alimentele urmarite in /aris/alergeni.php):
// 'reaction' (rosu, !!!) daca a avut reactie, 'given' (verde, !) daca i-a fost dat si nu a avut
// reactie, 'not_given' (galben, !!) daca e pe lista dar inca nu i-a fost dat.
$allergenStatus = [];
$res = $mysqli->query('SELECT food_id, is_given, reaction FROM aris_allergens WHERE food_id IS NOT NULL');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $fid = (int)$row['food_id'];
        if ((int)$row['is_given'] !== 1) {
            $allergenStatus[$fid] = 'not_given';
        } elseif ($row['reaction'] !== null && trim($row['reaction']) !== '') {
            $allergenStatus[$fid] = 'reaction';
        } else {
            $allergenStatus[$fid] = 'given';
        }
    }
}
$allergenBadges = ['given' => ['!', 'good'], 'not_given' => ['!!', 'accent'], 'reaction' => ['!!!', 'bad']];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Alimente</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 700px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .add-row { display: flex; gap: 10px; margin-bottom: 26px; }
  .add-row input {
    flex: 1 1 auto; padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row input:focus { outline: none; border-color: var(--accent); }
  .add-row button {
    padding: 10px 18px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem; cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-row button:hover { background: #c6923a; }

  .food-list { display: flex; flex-direction: column; }
  .food-row {
    display: flex; align-items: center; gap: 12px;
    padding: 12px 4px;
    border-bottom: 1px solid var(--line-soft);
  }
  .food-row.is-editing { display: none; }
  .food-info { flex: 1; min-width: 0; }
  .food-name { font-size: 0.94rem; font-weight: 600; color: var(--ink); }
  .food-stats { display: flex; gap: 12px; margin-top: 3px; }
  .food-stat { font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); }
  .food-stat strong { color: var(--ink-2); font-weight: 500; }

  .food-allergen-col { width: 36px; flex-shrink: 0; text-align: center; }
  .allergen-mark { font-family: var(--mono); font-weight: 700; font-size: 0.85rem; cursor: default; }
  .allergen-mark.allergen-good { color: var(--good); }
  .allergen-mark.allergen-accent { color: var(--accent); }
  .allergen-mark.allergen-bad { color: var(--bad); }

  .food-list-head { display: flex; align-items: center; gap: 12px; padding: 0 4px 8px; border-bottom: 1px solid var(--line); margin-bottom: 4px; }
  .food-list-head .head-info { flex: 1; }
  .food-list-head span { font-family: var(--mono); font-size: 0.62rem; text-transform: uppercase; letter-spacing: 0.07em; color: var(--ink-3); }
  .food-list-head .head-allergen { width: 36px; flex-shrink: 0; text-align: center; }
  .food-list-head .head-actions { width: 66px; flex-shrink: 0; }

  .food-actions { display: flex; gap: 6px; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .food-edit-row {
    display: none; gap: 8px; align-items: center;
    background: var(--panel); border: 1px solid var(--accent); border-radius: 8px;
    padding: 10px 12px; margin-bottom: 4px;
  }
  .food-row.is-editing + .food-edit-row { display: flex; }
  .food-edit-row input {
    flex: 1; padding: 8px 10px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .food-edit-row input:focus { outline: none; border-color: var(--accent); }
  .food-edit-row .edit-actions { display: flex; gap: 8px; }
  .food-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .food-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .food-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .food-edit-row .delete-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .food-edit-row .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px;
  }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>ARIS</strong></div>
    <nav id="heroNav"><?php aris_render_nav('alimente'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Alimente</h1>

  <div class="add-row">
    <input type="text" id="newFoodName" maxlength="<?= ARIS_FOOD_NAME_MAX ?>" placeholder="Aliment nou">
    <button type="button" id="addFoodBtn">+ Adaugă aliment</button>
  </div>

  <?php if (empty($foods)): ?>
    <div class="empty-state" id="emptyState">Niciun aliment adăugat încă. Adaugă primul mai sus.</div>
  <?php else: ?>
    <div class="food-list-head">
      <div class="head-info"><span>Aliment</span></div>
      <div class="head-allergen"><span>Alergen</span></div>
      <div class="head-actions"></div>
    </div>
    <div class="food-list" id="foodList">
      <?php foreach ($foods as $fid => $fname): ?>
        <div class="food-row" data-id="<?= $fid ?>">
          <div class="food-info">
            <div class="food-name"><?= htmlspecialchars($fname) ?></div>
            <div class="food-stats">
              <span class="food-stat">Folosit în <strong><?= $recipeUsage[$fid] ?? 0 ?></strong> <?= ($recipeUsage[$fid] ?? 0) === 1 ? 'rețetă' : 'rețete' ?></span>
              <span class="food-stat">Dat de <strong><?= $givenTotal[$fid] ?></strong> <?= $givenTotal[$fid] === 1 ? 'oară' : 'ori' ?></span>
            </div>
          </div>
          <div class="food-allergen-col">
            <?php if (isset($allergenStatus[$fid])): [$mark, $color] = $allergenBadges[$allergenStatus[$fid]]; ?>
              <span class="allergen-mark allergen-<?= $color ?>" title="<?= $allergenStatus[$fid] === 'reaction' ? 'Alergen - a avut reacție' : ($allergenStatus[$fid] === 'given' ? 'Alergen - dat, fără reacție' : 'Alergen - încă nedat') ?>"><?= $mark ?></span>
            <?php endif; ?>
          </div>
          <div class="food-actions">
            <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
            <button type="button" class="icon-btn delete-btn" title="Șterge">✕</button>
          </div>
        </div>
        <div class="food-edit-row">
          <input type="text" name="edit-name" maxlength="<?= ARIS_FOOD_NAME_MAX ?>" value="<?= htmlspecialchars($fname) ?>">
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

  var addFoodBtn = document.getElementById('addFoodBtn');
  var newFoodName = document.getElementById('newFoodName');
  if (addFoodBtn) {
    addFoodBtn.addEventListener('click', function() {
      var name = newFoodName.value.trim();
      if (!name) return;
      fetch('food_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut adăuga alimentul (poate există deja unul cu acest nume).');
      });
    });
    newFoodName.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') addFoodBtn.click();
    });
  }

  function wireRow(row) {
    var id = row.getAttribute('data-id');
    var editRow = row.nextElementSibling;

    row.querySelector('.edit-btn').addEventListener('click', function() {
      row.classList.add('is-editing');
      editRow.querySelector('input').focus();
    });

    if (!editRow || !editRow.classList.contains('food-edit-row')) return;

    editRow.querySelector('.cancel-btn').addEventListener('click', function() {
      row.classList.remove('is-editing');
    });

    editRow.querySelector('input').addEventListener('keydown', function(e) {
      if (e.key === 'Enter') editRow.querySelector('.save-btn').click();
      if (e.key === 'Escape') row.classList.remove('is-editing');
    });

    editRow.querySelector('.save-btn').addEventListener('click', function() {
      var name = editRow.querySelector('input').value.trim();
      if (!name) {
        alert('Numele nu poate fi gol.');
        return;
      }
      fetch('food_rename.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('rename failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut redenumi alimentul (poate există deja unul cu acest nume).');
      });
    });

    row.querySelector('.delete-btn').addEventListener('click', deleteFood);
    editRow.querySelector('.delete-btn').addEventListener('click', deleteFood);

    function deleteFood() {
      if (!confirm('Ștergi acest aliment din listă? Mesele, rețetele sau alergenii care îl foloseau rămân, dar apar ca "Aliment șters".')) return;
      fetch('food_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge alimentul. Încearcă din nou.');
      });
    }
  }

  document.querySelectorAll('.food-row').forEach(wireRow);
})();
</script>

</body>
</html>
