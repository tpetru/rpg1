<?php
// Retete - fiecare reteta e un nume + o lista de alimente cu gramaj. Folosite ca sursa a unei
// mese pe /aris/ (in loc de un singur aliment sau text liber).
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

$foods = [];
$res = $mysqli->query('SELECT id, name FROM aris_foods ORDER BY name ASC');
if ($res) while ($row = $res->fetch_assoc()) $foods[(int)$row['id']] = $row['name'];

$recipes = [];
$res = $mysqli->query('SELECT id, name FROM aris_recipes ORDER BY name ASC');
if ($res) while ($row = $res->fetch_assoc()) $recipes[(int)$row['id']] = ['name' => $row['name'], 'items' => []];

$res = $mysqli->query(
    'SELECT ri.recipe_id, ri.food_id, ri.grams, f.name AS food_name
     FROM aris_recipe_items ri LEFT JOIN aris_foods f ON f.id = ri.food_id
     ORDER BY ri.recipe_id ASC, ri.sort_order ASC, ri.id ASC'
);
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $rid = (int)$row['recipe_id'];
        if (isset($recipes[$rid])) {
            $recipes[$rid]['items'][] = [
                'food_id' => $row['food_id'] !== null ? (int)$row['food_id'] : null,
                'food_name' => $row['food_name'],
                'grams' => $row['grams'] !== null ? (int)$row['grams'] : null,
            ];
        }
    }
}

// De cate ori i-a fost data fiecare reteta ca masa.
$recipeGivenCount = [];
$res = $mysqli->query('SELECT recipe_id, COUNT(*) AS cnt FROM aris_meals WHERE recipe_id IS NOT NULL GROUP BY recipe_id');
if ($res) while ($row = $res->fetch_assoc()) $recipeGivenCount[(int)$row['recipe_id']] = (int)$row['cnt'];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Rețete</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 900px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .add-toggle-btn {
    display: block; width: 100%;
    padding: 11px 14px; margin-bottom: 26px;
    border: 1px dashed rgba(240,236,228,.16); border-radius: 6px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.82rem;
    cursor: pointer; text-align: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }

  .recipe-form-card {
    background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
    padding: 20px 22px; margin-bottom: 26px;
  }
  .recipe-form-card[hidden] { display: none; }
  .recipe-form-card h2 { margin: 0 0 14px; font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink); }
  .recipe-name-input {
    width: 100%; padding: 10px 14px; margin-bottom: 14px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.95rem; font-weight: 600;
  }
  .recipe-name-input:focus { outline: none; border-color: var(--accent); }

  .ingredient-rows { display: flex; flex-direction: column; gap: 8px; margin-bottom: 10px; }
  .ingredient-row { display: flex; gap: 8px; align-items: center; }
  .ingredient-row .ingredient-food-name {
    flex: 1 1 auto;
    padding: 9px 12px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .ingredient-row .grams-input {
    width: 100px;
    padding: 9px 12px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--mono); font-size: 0.88rem;
  }
  .ingredient-row .ingredient-food-name:focus, .ingredient-row .grams-input:focus { outline: none; border-color: var(--accent); }
  .ingredient-row .remove-ingredient-btn {
    flex-shrink: 0; width: 32px; height: 32px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink-3); cursor: pointer; font-size: 0.85rem;
  }
  .ingredient-row .remove-ingredient-btn:hover { border-color: var(--bad); color: var(--bad); }

  .add-ingredient-btn {
    align-self: flex-start;
    padding: 7px 14px; margin-bottom: 14px;
    border: 1px solid var(--line); border-radius: 6px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.8rem; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-ingredient-btn:hover { border-color: var(--accent); color: var(--accent); }

  .recipe-form-actions { display: flex; gap: 8px; }
  .recipe-form-actions button {
    padding: 10px 18px; border-radius: 6px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
  }
  .recipe-form-actions .save-btn { background: var(--accent); color: var(--on-accent); flex: 1; }
  .recipe-form-actions .save-btn:hover { background: #c6923a; }
  .recipe-form-actions .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }

  .recipe-list { display: flex; flex-direction: column; gap: 12px; }
  .recipe-card {
    background: var(--panel); border: 1px solid rgba(240,236,228,.09); border-radius: 8px;
    padding: 16px 18px;
  }
  .recipe-card[hidden] { display: none; }
  .recipe-card-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; }
  .recipe-card-head h3 { margin: 0; font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink); }
  .recipe-given-stat { display: block; margin-top: 3px; font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); }
  .recipe-given-stat strong { color: var(--ink-2); font-weight: 500; }
  .recipe-card-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .recipe-ingredients { display: flex; flex-wrap: wrap; gap: 6px; }
  .ingredient-chip {
    font-size: 0.78rem; color: var(--ink-2);
    background: rgba(240,236,228,.06); border-radius: 10px; padding: 3px 10px;
  }
  .ingredient-chip .grams { font-family: var(--mono); color: var(--ink-3); }
  .ingredient-chip.is-empty { color: var(--ink-3); font-style: italic; }

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
    <nav id="heroNav"><?php aris_render_nav('retete'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Rețete</h1>

  <datalist id="foodsDatalist">
    <?php foreach ($foods as $fname): ?>
      <option value="<?= htmlspecialchars($fname) ?>">
    <?php endforeach; ?>
  </datalist>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă rețetă</button>

  <div class="recipe-form-card" id="addCard" hidden>
    <h2>Rețetă nouă</h2>
    <input type="text" class="recipe-name-input" id="newRecipeName" maxlength="<?= ARIS_RECIPE_NAME_MAX ?>" placeholder="Numele rețetei">
    <div class="ingredient-rows" id="newIngredientRows"></div>
    <button type="button" class="add-ingredient-btn" id="addIngredientBtn">+ Adaugă aliment</button>
    <div class="recipe-form-actions">
      <button type="button" class="save-btn" id="saveRecipeBtn">Salvează rețeta</button>
      <button type="button" class="cancel-btn" id="cancelAddBtn">Anulează</button>
    </div>
  </div>

  <?php if (empty($recipes)): ?>
    <div class="empty-state" id="emptyState">Nicio rețetă adăugată încă. Adaugă prima mai sus.</div>
  <?php else: ?>
    <div class="recipe-list" id="recipeList">
      <?php foreach ($recipes as $rid => $recipe): ?>
        <div class="recipe-card" data-id="<?= $rid ?>">
          <div class="recipe-card-view">
            <div class="recipe-card-head">
              <div>
                <h3><?= htmlspecialchars($recipe['name']) ?></h3>
                <?php $givenCount = $recipeGivenCount[$rid] ?? 0; ?>
                <span class="recipe-given-stat">Dat de <strong><?= $givenCount ?></strong> <?= $givenCount === 1 ? 'oară' : 'ori' ?></span>
              </div>
              <div class="recipe-card-actions">
                <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
                <button type="button" class="icon-btn delete-btn" title="Șterge">✕</button>
              </div>
            </div>
            <div class="recipe-ingredients">
              <?php if (empty($recipe['items'])): ?>
                <span class="ingredient-chip is-empty">Fără ingrediente</span>
              <?php else: ?>
                <?php foreach ($recipe['items'] as $item): ?>
                  <span class="ingredient-chip"><?= htmlspecialchars($item['food_name'] ?? 'Aliment șters') ?><?php if ($item['grams']): ?> <span class="grams"><?= $item['grams'] ?>g</span><?php endif; ?></span>
                <?php endforeach; ?>
              <?php endif; ?>
            </div>
          </div>
          <div class="recipe-form-card recipe-edit-card" hidden>
            <h2>Editează rețeta</h2>
            <input type="text" class="recipe-name-input edit-recipe-name" maxlength="<?= ARIS_RECIPE_NAME_MAX ?>" value="<?= htmlspecialchars($recipe['name']) ?>">
            <div class="ingredient-rows edit-ingredient-rows"></div>
            <button type="button" class="add-ingredient-btn edit-add-ingredient-btn">+ Adaugă aliment</button>
            <div class="recipe-form-actions">
              <button type="button" class="save-btn edit-save-btn">Salvează rețeta</button>
              <button type="button" class="cancel-btn edit-cancel-btn">Anulează</button>
            </div>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

</main>

<?php site_render_footer(); ?>

<script>
var ARIS_RECIPES = <?= json_encode($recipes, JSON_UNESCAPED_UNICODE) ?>;

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

  function createIngredientRow(foodName, grams) {
    var row = document.createElement('div');
    row.className = 'ingredient-row';
    var nameVal = foodName ? foodName.replace(/"/g, '&quot;') : '';
    row.innerHTML =
      '<input type="text" class="ingredient-food-name" list="foodsDatalist" placeholder="Numele alimentului" value="' + nameVal + '">' +
      '<input type="number" class="grams-input" min="1" placeholder="grame" value="' + (grams || '') + '">' +
      '<button type="button" class="remove-ingredient-btn" title="Șterge alimentul">✕</button>';
    row.querySelector('.remove-ingredient-btn').addEventListener('click', function() {
      row.remove();
    });
    return row;
  }

  // Numele alimentelor sunt text liber - daca exista deja in db (indiferent de majuscule/plural
  // apropiat) se refoloseste, altfel se creaza automat (vezi aris_find_or_create_food in PHP).
  function collectIngredients(container) {
    var foodNames = [];
    var grams = [];
    container.querySelectorAll('.ingredient-row').forEach(function(row) {
      var name = row.querySelector('.ingredient-food-name').value.trim();
      var g = row.querySelector('.grams-input').value;
      if (name) {
        foodNames.push(name);
        grams.push(g || '');
      }
    });
    return { foodNames: foodNames, grams: grams };
  }

  // Formularul de adaugare
  var addToggleBtn = document.getElementById('addToggleBtn');
  var addCard = document.getElementById('addCard');
  var newIngredientRows = document.getElementById('newIngredientRows');
  var addIngredientBtn = document.getElementById('addIngredientBtn');
  var newRecipeName = document.getElementById('newRecipeName');
  var saveRecipeBtn = document.getElementById('saveRecipeBtn');
  var cancelAddBtn = document.getElementById('cancelAddBtn');

  function resetAddForm() {
    newRecipeName.value = '';
    newIngredientRows.innerHTML = '';
    newIngredientRows.appendChild(createIngredientRow(null, ''));
  }

  if (addToggleBtn && addCard) {
    addToggleBtn.addEventListener('click', function() {
      addCard.hidden = !addCard.hidden;
      if (!addCard.hidden) {
        resetAddForm();
        newRecipeName.focus();
      }
    });
  }
  if (addIngredientBtn) {
    addIngredientBtn.addEventListener('click', function() {
      newIngredientRows.appendChild(createIngredientRow(null, ''));
    });
  }
  if (cancelAddBtn) {
    cancelAddBtn.addEventListener('click', function() { addCard.hidden = true; });
  }
  if (saveRecipeBtn) {
    saveRecipeBtn.addEventListener('click', function() {
      var name = newRecipeName.value.trim();
      var ing = collectIngredients(newIngredientRows);
      if (!name || ing.foodNames.length === 0) {
        alert('Completează numele și cel puțin un aliment.');
        return;
      }
      var body = new URLSearchParams({ name: name });
      ing.foodNames.forEach(function(f) { body.append('food_name[]', f); });
      ing.grams.forEach(function(g) { body.append('grams[]', g); });
      fetch('recipe_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva rețeta. Încearcă din nou.');
      });
    });
  }

  // Cardurile existente: editare / stergere
  document.querySelectorAll('.recipe-card').forEach(function(card) {
    var id = card.getAttribute('data-id');
    var viewEl = card.querySelector('.recipe-card-view');
    var editEl = card.querySelector('.recipe-edit-card');
    var editRows = editEl.querySelector('.edit-ingredient-rows');
    var editName = editEl.querySelector('.edit-recipe-name');

    card.querySelector('.edit-btn').addEventListener('click', function() {
      editRows.innerHTML = '';
      var recipe = ARIS_RECIPES[id];
      if (recipe && recipe.items.length) {
        recipe.items.forEach(function(item) {
          editRows.appendChild(createIngredientRow(item.food_name, item.grams));
        });
      } else {
        editRows.appendChild(createIngredientRow(null, ''));
      }
      editName.value = recipe ? recipe.name : '';
      viewEl.hidden = true;
      editEl.hidden = false;
    });

    editEl.querySelector('.edit-cancel-btn').addEventListener('click', function() {
      editEl.hidden = true;
      viewEl.hidden = false;
    });
    editEl.querySelector('.edit-add-ingredient-btn').addEventListener('click', function() {
      editRows.appendChild(createIngredientRow(null, ''));
    });
    editEl.querySelector('.edit-save-btn').addEventListener('click', function() {
      var name = editName.value.trim();
      var ing = collectIngredients(editRows);
      if (!name || ing.foodNames.length === 0) {
        alert('Completează numele și cel puțin un aliment.');
        return;
      }
      var body = new URLSearchParams({ id: id, name: name });
      ing.foodNames.forEach(function(f) { body.append('food_name[]', f); });
      ing.grams.forEach(function(g) { body.append('grams[]', g); });
      fetch('recipe_update.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body.toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('update failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva rețeta. Încearcă din nou.');
      });
    });

    card.querySelector('.delete-btn').addEventListener('click', function() {
      if (!confirm('Ștergi această rețetă?')) return;
      fetch('recipe_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge rețeta. Încearcă din nou.');
      });
    });
  });
})();
</script>

</body>
</html>
