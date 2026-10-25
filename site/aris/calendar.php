<?php
// Vedere lunara a planului de hranire - acelasi istoric ca /aris/, dar asezat pe un calendar ca
// sa vezi dintr-o privire zilele cu/fara masa, si sa navighezi usor intre luni trecute/viitoare.
// Un click pe o masa deschide un popup cu detaliile complete (ingrediente, cantitati, varsta).
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

// Pentru formularul de editare din popup-ul de masa (aceleasi liste ca pe /aris/).
$foods = [];
$res = $mysqli->query('SELECT id, name FROM aris_foods ORDER BY name ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $foods[(int)$row['id']] = $row['name'];
    }
}
$recipes = [];
$res = $mysqli->query('SELECT id, name FROM aris_recipes ORDER BY name ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $recipes[(int)$row['id']] = $row['name'];
    }
}

$ym = $_GET['ym'] ?? date('Y-m');
if (!preg_match('/^\d{4}-\d{2}$/', $ym)) {
    $ym = date('Y-m');
}
$monthStart = DateTime::createFromFormat('Y-m-d', $ym . '-01');
if (!$monthStart) {
    $monthStart = new DateTime(date('Y-m-01'));
}
$year = (int)$monthStart->format('Y');
$month = (int)$monthStart->format('n');
$daysInMonth = (int)$monthStart->format('t');
$firstWeekday = (int)$monthStart->format('N'); // 1=Luni .. 7=Duminica
$today = date('Y-m-d');

$prevYm = (clone $monthStart)->modify('-1 month')->format('Y-m');
$nextYm = (clone $monthStart)->modify('+1 month')->format('Y-m');

$monthStartStr = $monthStart->format('Y-m-d');
$monthEndStr = (clone $monthStart)->modify('last day of this month')->format('Y-m-d');

$mealsByDate = [];
$stmt = $mysqli->prepare(
    'SELECT m.id, m.meal_date, m.food_id, m.recipe_id, m.custom_text, m.quantity, m.notes,
            f.name AS food_name, r.name AS recipe_name
     FROM aris_meals m
     LEFT JOIN aris_foods f ON f.id = m.food_id
     LEFT JOIN aris_recipes r ON r.id = m.recipe_id
     WHERE m.meal_date BETWEEN ? AND ?
     ORDER BY m.meal_date ASC, m.id ASC'
);
$stmt->bind_param('ss', $monthStartStr, $monthEndStr);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    $row['food_id'] = $row['food_id'] !== null ? (int)$row['food_id'] : null;
    $row['recipe_id'] = $row['recipe_id'] !== null ? (int)$row['recipe_id'] : null;
    $row['label'] = aris_meal_label($row['food_name'], $row['recipe_name'], $row['custom_text']);
    $mealsByDate[$row['meal_date']][] = $row;
}

// Grila de 7 coloane, saptamana incepe Luni: goluri inainte de ziua 1, apoi zilele lunii.
$cells = array_fill(0, $firstWeekday - 1, null);
for ($d = 1; $d <= $daysInMonth; $d++) {
    $cells[] = $d;
}
while (count($cells) % 7 !== 0) {
    $cells[] = null;
}

// Detaliile complete ale fiecarei mese din luna asta, indexate dupa id - folosite de popup.
$mealDetails = aris_build_meal_details($mysqli, $mealsByDate);
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Calendar mese</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 1000px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .month-nav {
    display: flex; align-items: center; justify-content: space-between;
    margin-bottom: 20px;
  }
  .month-nav .month-label { font-family: var(--disp); font-weight: 600; font-size: 1.1rem; color: var(--ink); text-transform: capitalize; }
  .month-nav-links { display: flex; gap: 8px; align-items: center; }
  .month-nav a, .month-nav .today-link {
    display: inline-flex; align-items: center; justify-content: center;
    padding: 7px 12px;
    border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink-2); font-family: var(--disp); font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .month-nav a:hover, .month-nav .today-link:hover { border-color: var(--accent); color: var(--accent); }

  .weekday-row { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; margin-bottom: 6px; }
  .weekday-row span {
    text-align: center; font-family: var(--mono); font-size: 0.66rem; letter-spacing: 0.08em;
    text-transform: uppercase; color: var(--ink-3); padding-bottom: 6px;
  }

  .cal-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px; }
  .cal-cell {
    height: 96px;
    overflow: hidden;
    background: var(--panel);
    border: 1px solid rgba(240,236,228,.09);
    border-radius: 7px;
    padding: 7px 8px;
    display: flex; flex-direction: column; gap: 4px;
  }
  .cal-cell.is-empty { background: transparent; border-color: transparent; }
  .cal-cell.is-today { border-color: var(--accent); }
  .cal-cell .cell-head { display: flex; align-items: center; justify-content: space-between; }
  .cal-cell .day-num { font-family: var(--mono); font-size: 0.78rem; color: var(--ink-2); }
  .cal-cell.is-today .day-num { color: var(--accent); font-weight: 700; }
  .cal-cell .add-day-btn {
    font-family: var(--mono); font-size: 0.78rem; color: var(--ink-3); text-decoration: none;
    opacity: 0; transition: opacity 0.15s ease;
  }
  .cal-cell:hover .add-day-btn { opacity: 1; }
  .add-day-btn:hover { color: var(--accent); }

  .cell-meals { display: flex; flex-direction: column; gap: 3px; overflow: hidden; }
  .cell-meal {
    font-size: 0.68rem; line-height: 1.35;
    color: var(--good);
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    cursor: pointer; background: none; border: none; padding: 0; text-align: left; font-family: var(--disp);
  }
  .cell-meal:hover { text-decoration: underline; }
  .cell-meal.is-planned { color: var(--accent); }
  .cell-meal .qty { color: var(--ink-3); font-family: var(--mono); }
  .cell-more { font-size: 0.66rem; color: var(--ink-3); font-family: var(--mono); }

  @media (max-width: 700px) {
    .cal-cell { height: 64px; padding: 5px 5px; }
    .cell-meal { font-size: 0.6rem; }
    .weekday-row span { font-size: 0.58rem; }
  }

  .meal-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .meal-modal-backdrop.is-open { display: flex; }
  .meal-modal {
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 24px 26px; max-width: 440px; width: 100%; max-height: 85vh; overflow-y: auto;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .meal-modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 4px; }
  .meal-modal-title { font-family: var(--disp); font-weight: 600; font-size: 1.15rem; color: var(--ink); margin: 0; }
  .meal-modal-close {
    flex-shrink: 0; width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
  }
  .meal-modal-close:hover { border-color: var(--bad); color: var(--bad); }
  .meal-modal-meta { font-family: var(--mono); font-size: 0.76rem; color: var(--ink-3); margin: 0 0 18px; }
  .meal-modal-meta .age { color: var(--accent); }
  .meal-modal-section { margin-bottom: 14px; }
  .meal-modal-section .label { font-family: var(--mono); font-size: 0.64rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--ink-3); margin-bottom: 6px; }
  .meal-modal-ingredients { display: flex; flex-direction: column; gap: 5px; }
  .meal-modal-ingredient { display: flex; justify-content: space-between; font-size: 0.86rem; color: var(--ink); border-bottom: 1px solid var(--line-soft); padding-bottom: 5px; }
  .meal-modal-ingredient .grams { font-family: var(--mono); color: var(--ink-2); }
  .meal-modal-quantity { font-size: 0.86rem; color: var(--ink); }
  .meal-modal-notes { font-size: 0.84rem; color: var(--ink-2); font-style: italic; }

  .meal-modal-actions { display: flex; gap: 8px; margin-top: 16px; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .meal-modal-actions .icon-btn { width: auto; padding: 0 14px; gap: 6px; font-family: var(--disp); font-size: 0.78rem; }

  .source-toggle { display: flex; gap: 6px; margin-bottom: 12px; }
  .source-toggle button {
    padding: 6px 14px; border-radius: 14px; border: 1px solid var(--line);
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.78rem; cursor: pointer;
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .source-toggle button.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }
  .source-field[hidden] { display: none; }

  .meal-edit-row { display: flex; flex-direction: column; gap: 8px; }
  .meal-edit-row[hidden] { display: none; }
  .meal-edit-row .edit-row { display: flex; flex-wrap: wrap; gap: 8px; }
  .meal-edit-row input, .meal-edit-row select {
    padding: 8px 10px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .meal-edit-row input.edit-date { width: 150px; font-family: var(--mono); }
  .meal-edit-row select.edit-food, .meal-edit-row select.edit-recipe { width: 170px; }
  .meal-edit-row input.edit-custom { flex: 1 1 180px; }
  .meal-edit-row input.edit-quantity { width: 130px; }
  .meal-edit-row input.edit-notes { flex: 1 1 200px; }
  .meal-edit-row input:focus, .meal-edit-row select:focus { outline: none; border-color: var(--accent); }
  .meal-edit-row .edit-actions { display: flex; gap: 8px; margin-left: auto; margin-top: 4px; }
  .meal-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .meal-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .meal-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>ARIS</strong></div>
    <nav id="heroNav"><?php aris_render_nav('calendar'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Calendar mese</h1>

  <div class="month-nav">
    <a href="?ym=<?= htmlspecialchars($prevYm) ?>">‹ Luna trecută</a>
    <div class="month-nav-links">
      <span class="month-label"><?= htmlspecialchars(aris_ro_month_year($month, $year)) ?></span>
      <?php if ($ym !== date('Y-m')): ?>
        <a class="today-link" href="?ym=<?= date('Y-m') ?>">Azi</a>
      <?php endif; ?>
    </div>
    <a href="?ym=<?= htmlspecialchars($nextYm) ?>">Luna viitoare ›</a>
  </div>

  <div class="weekday-row">
    <?php foreach (ARIS_WEEKDAYS_RO_SHORT as $wd): ?>
      <span><?= htmlspecialchars($wd) ?></span>
    <?php endforeach; ?>
  </div>

  <div class="cal-grid">
    <?php foreach ($cells as $day): ?>
      <?php if ($day === null): ?>
        <div class="cal-cell is-empty"></div>
      <?php else: ?>
        <?php
          $cellDate = sprintf('%04d-%02d-%02d', $year, $month, $day);
          $dayMeals = $mealsByDate[$cellDate] ?? [];
          $isToday = $cellDate === $today;
          $visibleMeals = array_slice($dayMeals, 0, 3);
          $extraCount = count($dayMeals) - count($visibleMeals);
        ?>
        <div class="cal-cell<?= $isToday ? ' is-today' : '' ?>">
          <div class="cell-head">
            <span class="day-num"><?= $day ?></span>
            <a class="add-day-btn" href="/?date=<?= $cellDate ?>" title="Adaugă masă în această zi">+</a>
          </div>
          <div class="cell-meals">
            <?php foreach ($visibleMeals as $meal): ?>
              <?php $isPlanned = strtotime($meal['meal_date']) > strtotime('today'); ?>
              <button type="button" class="cell-meal<?= $isPlanned ? ' is-planned' : '' ?>" data-meal-id="<?= $meal['id'] ?>" title="<?= htmlspecialchars($meal['label']['label'] . ($meal['quantity'] ? ' · ' . $meal['quantity'] : '')) ?>">
                <?= htmlspecialchars($meal['label']['label']) ?><?php if ($meal['quantity']): ?> <span class="qty"><?= htmlspecialchars($meal['quantity']) ?></span><?php endif; ?>
              </button>
            <?php endforeach; ?>
            <?php if ($extraCount > 0): ?>
              <span class="cell-more">+<?= $extraCount ?> altele</span>
            <?php endif; ?>
          </div>
        </div>
      <?php endif; ?>
    <?php endforeach; ?>
  </div>

</main>

<?php site_render_footer(); ?>

<div class="meal-modal-backdrop" id="mealModalBackdrop">
  <div class="meal-modal" id="mealModal" role="dialog" aria-modal="true">
    <div class="meal-modal-head">
      <h3 class="meal-modal-title" id="mealModalTitle"></h3>
      <button type="button" class="meal-modal-close" id="mealModalClose" title="Închide">✕</button>
    </div>
    <p class="meal-modal-meta" id="mealModalMeta"></p>

    <div id="mealModalView">
      <div class="meal-modal-section" id="mealModalIngredientsSection" hidden>
        <div class="label">Ingrediente</div>
        <div class="meal-modal-ingredients" id="mealModalIngredients"></div>
      </div>
      <div class="meal-modal-section" id="mealModalQuantitySection" hidden>
        <div class="label">Cantitate</div>
        <div class="meal-modal-quantity" id="mealModalQuantity"></div>
      </div>
      <div class="meal-modal-section" id="mealModalNotesSection" hidden>
        <div class="label">Observații</div>
        <div class="meal-modal-notes" id="mealModalNotes"></div>
      </div>
      <div class="meal-modal-actions">
        <button type="button" class="icon-btn" id="mealModalEditBtn" title="Editează">✎ Editează</button>
        <button type="button" class="icon-btn" id="mealModalAddNoteBtn" title="Adaugă notiță">📝 Adaugă notiță</button>
      </div>
    </div>

    <div class="meal-edit-row" id="mealModalEdit" hidden>
      <div class="source-toggle" id="mealModalSourceToggle">
        <button type="button" class="is-active" data-source="food">Aliment</button>
        <button type="button" data-source="recipe">Rețetă</button>
        <button type="button" data-source="custom">Personalizat</button>
      </div>
      <div class="edit-row">
        <input type="date" class="edit-date" id="mealModalEditDate">
        <select class="source-field edit-food" id="mealModalEditFood" data-source="food">
          <option value="0" disabled>Alege alimentul</option>
          <?php foreach ($foods as $fid => $fname): ?>
            <option value="<?= $fid ?>"><?= htmlspecialchars($fname) ?></option>
          <?php endforeach; ?>
        </select>
        <select class="source-field edit-recipe" id="mealModalEditRecipe" data-source="recipe" hidden>
          <option value="0" disabled>Alege rețeta</option>
          <?php foreach ($recipes as $rid => $rname): ?>
            <option value="<?= $rid ?>"><?= htmlspecialchars($rname) ?></option>
          <?php endforeach; ?>
        </select>
        <input type="text" class="source-field edit-custom" id="mealModalEditCustom" data-source="custom" hidden maxlength="<?= ARIS_CUSTOM_TEXT_MAX ?>" placeholder="Ce i-ai dat să mănânce">
        <input type="text" class="edit-quantity" id="mealModalEditQuantity" maxlength="<?= ARIS_QUANTITY_MAX ?>" placeholder="Cantitate (ex: 50g)">
        <input type="text" class="edit-notes" id="mealModalEditNotes" maxlength="<?= ARIS_NOTES_MAX ?>" placeholder="Observații (opțional)">
      </div>
      <div class="edit-actions">
        <button type="button" class="save-btn" id="mealModalSaveBtn">Salvează</button>
        <button type="button" class="cancel-btn" id="mealModalCancelBtn">Anulează</button>
      </div>
    </div>
  </div>
</div>

<script>
var ARIS_MEAL_DETAILS = <?= json_encode($mealDetails, JSON_UNESCAPED_UNICODE) ?>;

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

  var backdrop = document.getElementById('mealModalBackdrop');
  var modal = document.getElementById('mealModal');
  var titleEl = document.getElementById('mealModalTitle');
  var metaEl = document.getElementById('mealModalMeta');
  var viewEl = document.getElementById('mealModalView');
  var editEl = document.getElementById('mealModalEdit');
  var ingSection = document.getElementById('mealModalIngredientsSection');
  var ingList = document.getElementById('mealModalIngredients');
  var qtySection = document.getElementById('mealModalQuantitySection');
  var qtyEl = document.getElementById('mealModalQuantity');
  var notesSection = document.getElementById('mealModalNotesSection');
  var notesEl = document.getElementById('mealModalNotes');
  var sourceToggle = document.getElementById('mealModalSourceToggle');
  var editDate = document.getElementById('mealModalEditDate');
  var editFood = document.getElementById('mealModalEditFood');
  var editRecipe = document.getElementById('mealModalEditRecipe');
  var editCustom = document.getElementById('mealModalEditCustom');
  var editQuantity = document.getElementById('mealModalEditQuantity');
  var editNotes = document.getElementById('mealModalEditNotes');
  var currentMealId = null;

  // Comutatorul Aliment / Rețetă / Personalizat - arata campul potrivit, ascunde restul.
  function wireSourceToggle(toggleEl, fieldsContainer) {
    toggleEl.querySelectorAll('button').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var source = btn.getAttribute('data-source');
        toggleEl.querySelectorAll('button').forEach(function(b) { b.classList.toggle('is-active', b === btn); });
        fieldsContainer.querySelectorAll('.source-field').forEach(function(f) {
          f.hidden = f.getAttribute('data-source') !== source;
        });
      });
    });
  }
  function activeSource(toggleEl) {
    var active = toggleEl.querySelector('button.is-active');
    return active ? active.getAttribute('data-source') : 'food';
  }
  if (sourceToggle) wireSourceToggle(sourceToggle, editEl);

  function openMeal(id) {
    var d = ARIS_MEAL_DETAILS[id];
    if (!d) return;
    currentMealId = id;
    titleEl.textContent = d.label;
    metaEl.innerHTML = d.date + (d.age ? ' · <span class="age">' + d.age + '</span>' : '');

    if (d.ingredients && d.ingredients.length) {
      ingList.innerHTML = '';
      d.ingredients.forEach(function(ing) {
        var row = document.createElement('div');
        row.className = 'meal-modal-ingredient';
        row.innerHTML = '<span>' + ing.name + '</span><span class="grams">' + (ing.grams ? ing.grams + 'g' : '—') + '</span>';
        ingList.appendChild(row);
      });
      ingSection.hidden = false;
    } else {
      ingSection.hidden = true;
    }

    if (d.quantity) {
      qtyEl.textContent = d.quantity;
      qtySection.hidden = false;
    } else {
      qtySection.hidden = true;
    }

    if (d.notes) {
      notesEl.textContent = d.notes;
      notesSection.hidden = false;
    } else {
      notesSection.hidden = true;
    }

    viewEl.hidden = false;
    editEl.hidden = true;
    backdrop.classList.add('is-open');
  }

  function closeModal() {
    backdrop.classList.remove('is-open');
    currentMealId = null;
  }

  function enterEdit(focusNotes) {
    var d = ARIS_MEAL_DETAILS[currentMealId];
    if (!d) return;
    editDate.value = d.mealDate;
    editQuantity.value = d.quantity || '';
    editNotes.value = d.notes || '';

    var sourceBtn = sourceToggle.querySelector('[data-source="' + d.source + '"]');
    if (sourceBtn) sourceBtn.click();

    if (d.source === 'food') editFood.value = d.foodId || '0';
    if (d.source === 'recipe') editRecipe.value = d.recipeId || '0';
    if (d.source === 'custom') editCustom.value = d.customText || '';

    viewEl.hidden = true;
    editEl.hidden = false;

    if (focusNotes) {
      editNotes.focus();
    }
  }

  document.querySelectorAll('.cell-meal').forEach(function(btn) {
    btn.addEventListener('click', function() {
      openMeal(btn.getAttribute('data-meal-id'));
    });
  });

  document.getElementById('mealModalClose').addEventListener('click', closeModal);
  backdrop.addEventListener('click', function(e) {
    if (e.target === backdrop) closeModal();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeModal();
  });

  document.getElementById('mealModalEditBtn').addEventListener('click', function() {
    enterEdit(false);
  });
  document.getElementById('mealModalAddNoteBtn').addEventListener('click', function() {
    enterEdit(true);
  });
  document.getElementById('mealModalCancelBtn').addEventListener('click', function() {
    viewEl.hidden = false;
    editEl.hidden = true;
  });

  document.getElementById('mealModalSaveBtn').addEventListener('click', function() {
    var mealDate = editDate.value;
    var source = activeSource(sourceToggle);
    var quantity = editQuantity.value.trim();
    var notes = editNotes.value.trim();
    if (!mealDate) {
      alert('Completează data.');
      return;
    }
    var payload = { id: currentMealId, meal_date: mealDate, source: source, quantity: quantity, notes: notes };
    if (source === 'food') {
      if (!editFood.value || editFood.value === '0') { alert('Alege un aliment.'); return; }
      payload.food_id = editFood.value;
    } else if (source === 'recipe') {
      if (!editRecipe.value || editRecipe.value === '0') { alert('Alege o rețetă.'); return; }
      payload.recipe_id = editRecipe.value;
    } else {
      if (!editCustom.value.trim()) { alert('Scrie ce i-ai dat să mănânce.'); return; }
      payload.custom_text = editCustom.value.trim();
    }
    fetch('update_meal.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(payload).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('update failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut salva modificarea. Încearcă din nou.');
    });
  });
})();
</script>

</body>
</html>
