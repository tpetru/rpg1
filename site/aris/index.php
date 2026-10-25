<?php
// Pagina de sine statatoare (fara header-ul/branding-ul site-ului), in acelasi stil vizual ca
// /docs.php si /cocktails.php. Planul de hranire al lui Aris: ce i-am dat sa manance (sau ce
// planuim sa ii dam) in fiecare zi, cu cantitate si observatii per masa. Sursa unei mese e exact
// una dintre: un aliment din lista, o reteta salvata, sau text scris liber.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

$foods = []; // id => name, in ordinea adaugarii
$res = $mysqli->query('SELECT id, name FROM aris_foods ORDER BY name ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $foods[(int)$row['id']] = $row['name'];
    }
}

$recipes = []; // id => name
$res = $mysqli->query('SELECT id, name FROM aris_recipes ORDER BY name ASC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $recipes[(int)$row['id']] = $row['name'];
    }
}

// Doar saptamana curenta (Luni - Duminica) - istoricul complet ramane pe /aris/calendar.php.
$today = new DateTime('today');
$weekStart = (clone $today)->modify('monday this week');
$weekEnd = (clone $weekStart)->modify('+6 days');
$weekStartStr = $weekStart->format('Y-m-d');
$weekEndStr = $weekEnd->format('Y-m-d');

$meals = [];
$stmt = $mysqli->prepare(
    'SELECT m.id, m.meal_date, m.food_id, m.recipe_id, m.custom_text, m.quantity, m.notes,
            f.name AS food_name, r.name AS recipe_name
     FROM aris_meals m
     LEFT JOIN aris_foods f ON f.id = m.food_id
     LEFT JOIN aris_recipes r ON r.id = m.recipe_id
     WHERE m.meal_date BETWEEN ? AND ?
     ORDER BY m.meal_date ASC, m.id ASC'
);
$stmt->bind_param('ss', $weekStartStr, $weekEndStr);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    $row['food_id'] = $row['food_id'] !== null ? (int)$row['food_id'] : null;
    $row['recipe_id'] = $row['recipe_id'] !== null ? (int)$row['recipe_id'] : null;
    $row['status'] = aris_meal_status($row['meal_date']);
    $row['label'] = aris_meal_label($row['food_name'], $row['recipe_name'], $row['custom_text']);
    $meals[] = $row;
}

$mealsByDate = [];
foreach ($meals as $meal) {
    $mealsByDate[$meal['meal_date']][] = $meal;
}

// Detaliile complete ale fiecarei mese (ingrediente, cantitate, observatii) - folosite de popup-ul
// unic care acopera atat vizualizarea cat si editarea/stergerea unei mese.
$mealDetails = aris_build_meal_details($mysqli, $mealsByDate);

$currentAge = aris_age_at(date('Y-m-d'));

// Lista de cumparaturi: toate alimentele din retetele folosite in mesele saptamanii curente,
// cu bifa AVEM/NU AVEM per aliment.
$shoppingList = aris_shopping_list($mysqli, $weekStartStr);

// Vine de pe /aris/calendar.php cand dai click pe "+" intr-o zi - deschide formularul cu data
// deja completata, in loc sa fie nevoie sa o retastezi.
$prefillDate = $_GET['date'] ?? '';
$prefillDateTs = DateTime::createFromFormat('Y-m-d', $prefillDate);
if (!$prefillDateTs || $prefillDateTs->format('Y-m-d') !== $prefillDate) {
    $prefillDate = date('Y-m-d');
}
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Plan de hrănire</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 900px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 6px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }
  .age-banner { margin: 0 0 26px; font-size: 0.88rem; color: var(--ink-2); }
  .age-banner strong { color: var(--accent); font-weight: 600; }

  .week-heading {
    display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap;
    padding-bottom: 9px; margin: 30px 0 4px;
    border-bottom: 1px solid var(--line);
  }
  .week-label { font-family: var(--disp); font-weight: 600; font-size: 0.94rem; color: var(--ink); }
  .week-range { font-family: var(--mono); font-size: 0.72rem; color: var(--ink-3); }

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

  .shopping-toggle-btn {
    display: block; width: 100%;
    padding: 11px 14px;
    margin-bottom: 26px;
    border: 1px solid var(--line); border-radius: 6px;
    background: var(--panel); color: var(--ink-2);
    font-family: var(--disp); font-size: 0.82rem; font-weight: 500;
    cursor: pointer; text-align: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .shopping-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }
  .shopping-count { font-family: var(--mono); font-size: 0.72rem; color: var(--accent); }

  .shopping-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .shopping-modal-backdrop.is-open { display: flex; }
  .shopping-modal {
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 22px 24px; max-width: 460px; width: 100%; max-height: 80vh; overflow-y: auto;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .shopping-modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
  .shopping-modal h2 { margin: 0; font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink); }
  .shopping-modal-range { display: block; margin-top: 4px; font-family: var(--mono); font-size: 0.72rem; color: var(--ink-3); }
  .shopping-modal-close {
    flex-shrink: 0; width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
  }
  .shopping-modal-close:hover { border-color: var(--bad); color: var(--bad); }

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
  .shopping-empty { margin: 0; font-size: 0.85rem; color: var(--ink-3); font-style: italic; }
  .shopping-list { display: flex; flex-direction: column; }
  .shopping-item {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 2px; border-bottom: 1px solid var(--line-soft);
  }
  .shopping-item-name { flex: 1; min-width: 0; font-size: 0.9rem; color: var(--ink); overflow-wrap: anywhere; }
  .have-toggle {
    flex-shrink: 0; width: 92px; text-align: center; white-space: nowrap;
    padding: 6px 8px; border-radius: 14px;
    font-family: var(--mono); font-weight: 600; font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.04em;
    border: 1px solid var(--line); background: transparent; color: var(--ink-3); cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease;
  }
  .have-toggle.have-no { border-color: var(--bad); color: var(--bad); background: rgba(210,105,79,.1); }
  .have-toggle.have-yes { border-color: var(--good); color: var(--good); background: rgba(157,191,122,.1); }
  .shopping-item-remove {
    flex-shrink: 0; width: 26px; height: 26px; border-radius: 50%;
    border: 1px solid transparent; background: transparent; color: var(--ink-3);
    font-size: 0.78rem; line-height: 1; cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .shopping-item-remove:hover { border-color: var(--bad); color: var(--bad); }
  .shopping-add-row { display: flex; gap: 8px; margin-top: 14px; }
  .shopping-add-input {
    flex: 1; padding: 9px 12px; border-radius: 8px;
    border: 1px solid var(--line); background: var(--bg); color: var(--ink);
    font-family: inherit; font-size: 0.86rem;
  }
  .shopping-add-input:focus { outline: none; border-color: var(--accent); }
  .shopping-add-btn {
    flex-shrink: 0; padding: 9px 16px; border-radius: 8px;
    border: 1px solid var(--accent); background: transparent; color: var(--accent);
    font-family: inherit; font-weight: 600; font-size: 0.86rem; cursor: pointer;
    transition: background 0.2s ease, color 0.2s ease;
  }
  .shopping-add-btn:hover { background: var(--accent); color: var(--on-accent); }

  .add-modal-backdrop {
    display: none;
    position: fixed; inset: 0; z-index: 500;
    background: rgba(0,0,0,0.55);
    align-items: center; justify-content: center;
    padding: 20px;
  }
  .add-modal-backdrop.is-open { display: flex; }
  .add-modal {
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
    padding: 22px 24px; max-width: 480px; width: 100%; max-height: 85vh; overflow-y: auto;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .add-modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
  .add-modal h2 { margin: 0; font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink); }
  .add-modal-close {
    flex-shrink: 0; width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
  }
  .add-modal-close:hover { border-color: var(--bad); color: var(--bad); }

  .source-toggle { display: flex; gap: 6px; margin-bottom: 12px; }
  .source-toggle button {
    padding: 6px 14px; border-radius: 14px; border: 1px solid var(--line);
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.78rem; cursor: pointer;
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .source-toggle button.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }

  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input, .add-row select {
    padding: 10px 14px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row input[name=meal_date] { width: 155px; font-family: var(--mono); }
  .add-row select[name=food_id], .add-row select[name=recipe_id] { width: 180px; }
  .add-row input[name=custom_text] { flex: 1 1 200px; }
  .add-row input[name=quantity] { width: 140px; }
  .add-row input[name=notes] { flex: 1 1 220px; }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
  .source-field[hidden] { display: none; }
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

  .day-group { margin-top: 30px; }
  .day-header {
    display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap;
    padding-bottom: 9px; margin-bottom: 4px;
    border-bottom: 1px solid var(--line);
  }
  .day-header .day-date { font-family: var(--disp); font-weight: 600; font-size: 0.94rem; color: var(--ink); }
  .day-header .day-age { font-family: var(--mono); font-size: 0.72rem; color: var(--ink-3); }
  .day-header .day-total { margin-left: auto; font-family: var(--mono); font-size: 0.72rem; color: var(--accent); }

  .meal-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: center;
    gap: 16px;
    padding: 13px 4px;
    border-bottom: 1px solid var(--line-soft);
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .meal-row:hover { background: rgba(240,236,228,.03); }
  .meal-row.status-given { border-left: 2px solid var(--good); padding-left: 14px; background: rgba(157,191,122,0.05); border-radius: 0 5px 5px 0; }
  .meal-row.status-planned { border-left: 2px solid var(--accent); padding-left: 14px; background: rgba(217,164,65,0.05); border-radius: 0 5px 5px 0; }

  .meal-food { font-size: 0.92rem; font-weight: 600; color: var(--ink); }
  .meal-food.is-empty { color: var(--ink-3); font-style: italic; font-weight: 400; }
  .meal-source-tag { font-family: var(--mono); font-size: 0.62rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-3); margin-left: 6px; font-weight: 400; }

  .meal-notes { font-size: 0.82rem; color: var(--ink-3); font-style: italic; }

  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

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

  .meal-modal-actions { display: flex; gap: 8px; margin-top: 16px; }
  .meal-modal-actions .icon-btn { width: auto; padding: 0 14px; gap: 6px; font-family: var(--disp); font-size: 0.78rem; }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px; margin-bottom: 18px;
  }

  @media (max-width: 640px) {
    .meal-row { grid-template-columns: 1fr; }
  }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>ARIS</strong></div>
    <nav id="heroNav"><?php aris_render_nav('plan'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Plan de hrănire</h1>
  <p class="age-banner">Aris are acum: <strong><?= htmlspecialchars($currentAge ?? '—') ?></strong></p>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă masă</button>

  <button type="button" class="shopping-toggle-btn" id="shoppingToggleBtn">Lista de cumpărături <span class="shopping-count" id="shoppingCount"<?= empty($shoppingList) ? ' hidden' : '' ?>><?= count($shoppingList) ?></span></button>

  <div class="shopping-modal-backdrop" id="shoppingModalBackdrop">
    <div class="shopping-modal" role="dialog" aria-modal="true">
      <div class="shopping-modal-head">
        <div>
          <h2>Lista de cumpărături</h2>
          <span class="shopping-modal-range"><?= htmlspecialchars(aris_ro_date($weekStartStr)) ?> – <?= htmlspecialchars(aris_ro_date($weekEndStr)) ?></span>
        </div>
        <button type="button" class="shopping-modal-close" id="shoppingModalClose" title="Închide">✕</button>
      </div>
      <div class="shopping-list" id="shoppingList">
        <?php if (empty($shoppingList)): ?>
          <p class="shopping-empty" id="shoppingEmpty">Nicio rețetă folosită săptămâna aceasta încă - adaugă mese cu rețetă sau un articol mai jos.</p>
        <?php endif; ?>
        <?php foreach ($shoppingList as $key => $item): ?>
          <div class="shopping-item" data-type="<?= $item['type'] ?>" data-id="<?= $item['id'] ?>">
            <span class="shopping-item-name"><?= htmlspecialchars($item['name']) ?></span>
            <button type="button" class="have-toggle<?= $item['have_it'] ? ' have-yes' : ' have-no' ?>"><?= $item['have_it'] ? 'AVEM' : 'NU AVEM' ?></button>
            <button type="button" class="shopping-item-remove" title="Scoate din listă">✕</button>
          </div>
        <?php endforeach; ?>
      </div>
      <div class="shopping-add-row">
        <input type="text" id="shoppingAddInput" class="shopping-add-input" placeholder="Adaugă un articol..." maxlength="80">
        <button type="button" class="shopping-add-btn" id="shoppingAddBtn">Adaugă</button>
      </div>
    </div>
  </div>

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
          <button type="button" class="icon-btn delete-btn" id="mealModalDeleteBtn" title="Șterge">✕ Șterge</button>
        </div>
      </div>

      <div class="meal-edit-row" id="mealModalEdit" hidden>
        <div class="source-toggle" id="mealModalSourceToggle">
          <button type="button" data-source="food">Aliment</button>
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

  <div class="week-heading">
    <span class="week-label">Săptămâna curentă</span>
    <span class="week-range"><?= htmlspecialchars(aris_ro_date($weekStartStr)) ?> – <?= htmlspecialchars(aris_ro_date($weekEndStr)) ?></span>
  </div>

  <div class="add-modal-backdrop<?= isset($_GET['date']) ? ' is-open' : '' ?>" id="addModalBackdrop">
    <div class="add-modal" role="dialog" aria-modal="true">
      <div class="add-modal-head">
        <h2>Adaugă masă</h2>
        <button type="button" class="add-modal-close" id="addModalClose" title="Închide">✕</button>
      </div>
      <div class="source-toggle" id="newSourceToggle">
        <button type="button" data-source="food">Aliment</button>
        <button type="button" data-source="recipe">Rețetă</button>
        <button type="button" class="is-active" data-source="custom">Personalizat</button>
      </div>
      <div class="add-row">
        <input type="date" name="meal_date" id="newDate" value="<?= htmlspecialchars($prefillDate) ?>" required>
        <select name="food_id" id="newFood" class="source-field" data-source="food" hidden>
          <option value="0" disabled selected>Alege alimentul</option>
          <?php foreach ($foods as $fid => $fname): ?>
            <option value="<?= $fid ?>"><?= htmlspecialchars($fname) ?></option>
          <?php endforeach; ?>
        </select>
        <select name="recipe_id" id="newRecipe" class="source-field" data-source="recipe" hidden>
          <option value="0" disabled selected>Alege rețeta</option>
          <?php foreach ($recipes as $rid => $rname): ?>
            <option value="<?= $rid ?>"><?= htmlspecialchars($rname) ?></option>
          <?php endforeach; ?>
        </select>
        <input type="text" name="custom_text" id="newCustom" class="source-field" data-source="custom" maxlength="<?= ARIS_CUSTOM_TEXT_MAX ?>" placeholder="Ce i-ai dat să mănânce">
        <input type="text" name="quantity" id="newQuantity" maxlength="<?= ARIS_QUANTITY_MAX ?>" placeholder="Cantitate (ex: 50g)">
        <input type="text" name="notes" id="newNotes" maxlength="<?= ARIS_NOTES_MAX ?>" placeholder="Observații (opțional)">
      </div>
      <button type="button" class="add-btn" id="addBtn">Adaugă masă</button>
    </div>
  </div>

  <?php if (empty($meals)): ?>
    <div class="empty-state" id="emptyState">Nicio masă pentru săptămâna aceasta încă. Adaugă una mai sus.</div>
  <?php else: ?>
    <?php foreach ($mealsByDate as $date => $dayMeals): ?>
      <div class="day-group">
        <?php $dayTotalGrams = aris_day_total_grams($dayMeals); ?>
        <div class="day-header">
          <span class="day-date"><?= htmlspecialchars(aris_ro_date_with_weekday($date)) ?></span>
          <span class="day-age"><?= htmlspecialchars(aris_age_at($date) ?? '') ?></span>
          <?php if ($dayTotalGrams !== null): ?>
            <span class="day-total"><?= $dayTotalGrams ?>g total</span>
          <?php endif; ?>
        </div>
        <?php foreach ($dayMeals as $meal): ?>
          <?php $sourceLabels = ['recipe' => 'Rețetă', 'custom' => 'Personalizat', 'food' => '', 'deleted' => '']; ?>
          <div class="meal-row status-<?= $meal['status'] ?>" data-id="<?= $meal['id'] ?>">
            <div class="meal-food<?= $meal['label']['type'] === 'deleted' ? ' is-empty' : '' ?>">
              <?= htmlspecialchars($meal['label']['label']) ?><?php if ($sourceLabels[$meal['label']['type']]): ?><span class="meal-source-tag"><?= htmlspecialchars($sourceLabels[$meal['label']['type']]) ?></span><?php endif; ?>
            </div>
            <div class="meal-notes"><?= $meal['notes'] !== null ? htmlspecialchars($meal['notes']) : '' ?></div>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endforeach; ?>
  <?php endif; ?>

</main>

<?php site_render_footer(); ?>

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

  var newSourceToggle = document.getElementById('newSourceToggle');
  var addModalBackdrop = document.getElementById('addModalBackdrop');
  if (newSourceToggle) wireSourceToggle(newSourceToggle, addModalBackdrop);

  var addToggleBtn = document.getElementById('addToggleBtn');
  var addModalClose = document.getElementById('addModalClose');
  if (addToggleBtn && addModalBackdrop) {
    var closeAddModal = function() { addModalBackdrop.classList.remove('is-open'); };
    addToggleBtn.addEventListener('click', function() {
      addModalBackdrop.classList.add('is-open');
      document.getElementById('newDate').focus();
    });
    addModalClose.addEventListener('click', closeAddModal);
    addModalBackdrop.addEventListener('click', function(e) {
      if (e.target === addModalBackdrop) closeAddModal();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && addModalBackdrop.classList.contains('is-open')) closeAddModal();
    });
  }

  var shoppingToggleBtn = document.getElementById('shoppingToggleBtn');
  var shoppingModalBackdrop = document.getElementById('shoppingModalBackdrop');
  var shoppingModalClose = document.getElementById('shoppingModalClose');
  if (shoppingToggleBtn && shoppingModalBackdrop) {
    var closeShoppingModal = function() { shoppingModalBackdrop.classList.remove('is-open'); };
    shoppingToggleBtn.addEventListener('click', function() {
      shoppingModalBackdrop.classList.add('is-open');
    });
    shoppingModalClose.addEventListener('click', closeShoppingModal);
    shoppingModalBackdrop.addEventListener('click', function(e) {
      if (e.target === shoppingModalBackdrop) closeShoppingModal();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') closeShoppingModal();
    });
  }

  var shoppingList = document.getElementById('shoppingList');
  var shoppingEmpty = document.getElementById('shoppingEmpty');
  var shoppingCount = document.getElementById('shoppingCount');
  var shoppingWeekStart = '<?= htmlspecialchars($weekStartStr) ?>';

  function updateShoppingCount() {
    var n = shoppingList.querySelectorAll('.shopping-item').length;
    shoppingCount.textContent = n;
    shoppingCount.hidden = n === 0;
    if (shoppingEmpty) shoppingEmpty.hidden = n > 0;
  }

  function makeShoppingItem(type, id, name, haveIt) {
    var row = document.createElement('div');
    row.className = 'shopping-item';
    row.setAttribute('data-type', type);
    row.setAttribute('data-id', id);
    var nameSpan = document.createElement('span');
    nameSpan.className = 'shopping-item-name';
    nameSpan.textContent = name;
    var toggleBtn = document.createElement('button');
    toggleBtn.type = 'button';
    toggleBtn.className = 'have-toggle' + (haveIt ? ' have-yes' : ' have-no');
    toggleBtn.textContent = haveIt ? 'AVEM' : 'NU AVEM';
    var removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'shopping-item-remove';
    removeBtn.title = 'Scoate din listă';
    removeBtn.textContent = '✕';
    row.appendChild(nameSpan);
    row.appendChild(toggleBtn);
    row.appendChild(removeBtn);
    return row;
  }

  if (shoppingList) {
    shoppingList.addEventListener('click', function(e) {
      var item = e.target.closest('.shopping-item');
      if (!item) return;
      var type = item.getAttribute('data-type');
      var id = item.getAttribute('data-id');

      if (e.target.classList.contains('have-toggle')) {
        var btn = e.target;
        var next = !btn.classList.contains('have-yes');
        fetch('shopping_toggle.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ type: type, id: id, week_start: shoppingWeekStart, have_it: next ? '1' : '0' }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('toggle failed');
          btn.classList.toggle('have-yes', next);
          btn.classList.toggle('have-no', !next);
          btn.textContent = next ? 'AVEM' : 'NU AVEM';
        }).catch(function() {
          alert('Nu s-a putut salva. Încearcă din nou.');
        });
        return;
      }

      if (e.target.classList.contains('shopping-item-remove')) {
        fetch('shopping_remove_item.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ type: type, id: id, week_start: shoppingWeekStart }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('remove failed');
          item.remove();
          updateShoppingCount();
        }).catch(function() {
          alert('Nu s-a putut șterge. Încearcă din nou.');
        });
      }
    });
  }

  var shoppingAddInput = document.getElementById('shoppingAddInput');
  var shoppingAddBtn = document.getElementById('shoppingAddBtn');
  if (shoppingAddBtn && shoppingAddInput) {
    var submitShoppingAdd = function() {
      var name = shoppingAddInput.value.trim();
      if (name === '') return;
      fetch('shopping_add_item.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ name: name, week_start: shoppingWeekStart }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        shoppingList.appendChild(makeShoppingItem('extra', data.id, name, false));
        updateShoppingCount();
        shoppingAddInput.value = '';
        shoppingAddInput.focus();
      }).catch(function() {
        alert('Nu s-a putut adăuga. Încearcă din nou.');
      });
    };
    shoppingAddBtn.addEventListener('click', submitShoppingAdd);
    shoppingAddInput.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); submitShoppingAdd(); }
    });
  }

  // Popup unic de detalii masa - acopera vizualizarea, editarea si stergerea (un click pe card
  // deschide vizualizarea; butonul Editează din popup comuta pe formularul de editare).
  var mealModalBackdrop = document.getElementById('mealModalBackdrop');
  var mealModalTitle = document.getElementById('mealModalTitle');
  var mealModalMeta = document.getElementById('mealModalMeta');
  var mealModalView = document.getElementById('mealModalView');
  var mealModalEdit = document.getElementById('mealModalEdit');
  var mealModalIngSection = document.getElementById('mealModalIngredientsSection');
  var mealModalIngList = document.getElementById('mealModalIngredients');
  var mealModalQtySection = document.getElementById('mealModalQuantitySection');
  var mealModalQtyEl = document.getElementById('mealModalQuantity');
  var mealModalNotesSection = document.getElementById('mealModalNotesSection');
  var mealModalNotesEl = document.getElementById('mealModalNotes');
  var mealModalSourceToggle = document.getElementById('mealModalSourceToggle');
  var mealModalEditDate = document.getElementById('mealModalEditDate');
  var mealModalEditFood = document.getElementById('mealModalEditFood');
  var mealModalEditRecipe = document.getElementById('mealModalEditRecipe');
  var mealModalEditCustom = document.getElementById('mealModalEditCustom');
  var mealModalEditQuantity = document.getElementById('mealModalEditQuantity');
  var mealModalEditNotes = document.getElementById('mealModalEditNotes');
  var currentMealId = null;

  if (mealModalSourceToggle) wireSourceToggle(mealModalSourceToggle, mealModalEdit);

  function openMealModal(id) {
    var d = ARIS_MEAL_DETAILS[id];
    if (!d) return;
    currentMealId = id;
    mealModalTitle.textContent = d.label;
    mealModalMeta.innerHTML = d.date + (d.age ? ' · <span class="age">' + d.age + '</span>' : '');

    if (d.ingredients && d.ingredients.length) {
      mealModalIngList.innerHTML = '';
      d.ingredients.forEach(function(ing) {
        var row = document.createElement('div');
        row.className = 'meal-modal-ingredient';
        row.innerHTML = '<span>' + ing.name + '</span><span class="grams">' + (ing.grams ? ing.grams + 'g' : '—') + '</span>';
        mealModalIngList.appendChild(row);
      });
      mealModalIngSection.hidden = false;
    } else {
      mealModalIngSection.hidden = true;
    }

    if (d.quantity) {
      mealModalQtyEl.textContent = d.quantity;
      mealModalQtySection.hidden = false;
    } else {
      mealModalQtySection.hidden = true;
    }

    if (d.notes) {
      mealModalNotesEl.textContent = d.notes;
      mealModalNotesSection.hidden = false;
    } else {
      mealModalNotesSection.hidden = true;
    }

    mealModalView.hidden = false;
    mealModalEdit.hidden = true;
    mealModalBackdrop.classList.add('is-open');
  }

  function closeMealModal() {
    mealModalBackdrop.classList.remove('is-open');
    currentMealId = null;
  }

  document.querySelectorAll('.meal-row').forEach(function(row) {
    row.addEventListener('click', function() {
      openMealModal(row.getAttribute('data-id'));
    });
  });

  document.getElementById('mealModalClose').addEventListener('click', closeMealModal);
  mealModalBackdrop.addEventListener('click', function(e) {
    if (e.target === mealModalBackdrop) closeMealModal();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && mealModalBackdrop.classList.contains('is-open')) closeMealModal();
  });

  document.getElementById('mealModalEditBtn').addEventListener('click', function() {
    var d = ARIS_MEAL_DETAILS[currentMealId];
    if (!d) return;
    mealModalEditDate.value = d.mealDate;
    mealModalEditQuantity.value = d.quantity || '';
    mealModalEditNotes.value = d.notes || '';

    var sourceBtn = mealModalSourceToggle.querySelector('[data-source="' + d.source + '"]');
    if (sourceBtn) sourceBtn.click();

    if (d.source === 'food') mealModalEditFood.value = d.foodId || '0';
    if (d.source === 'recipe') mealModalEditRecipe.value = d.recipeId || '0';
    if (d.source === 'custom') mealModalEditCustom.value = d.customText || '';

    mealModalView.hidden = true;
    mealModalEdit.hidden = false;
  });

  document.getElementById('mealModalCancelBtn').addEventListener('click', function() {
    mealModalView.hidden = false;
    mealModalEdit.hidden = true;
  });

  document.getElementById('mealModalSaveBtn').addEventListener('click', function() {
    var mealDate = mealModalEditDate.value;
    var source = activeSource(mealModalSourceToggle);
    var quantity = mealModalEditQuantity.value.trim();
    var notes = mealModalEditNotes.value.trim();
    if (!mealDate) {
      alert('Completează data.');
      return;
    }
    var payload = { id: currentMealId, meal_date: mealDate, source: source, quantity: quantity, notes: notes };
    if (source === 'food') {
      if (!mealModalEditFood.value || mealModalEditFood.value === '0') { alert('Alege un aliment.'); return; }
      payload.food_id = mealModalEditFood.value;
    } else if (source === 'recipe') {
      if (!mealModalEditRecipe.value || mealModalEditRecipe.value === '0') { alert('Alege o rețetă.'); return; }
      payload.recipe_id = mealModalEditRecipe.value;
    } else {
      if (!mealModalEditCustom.value.trim()) { alert('Scrie ce i-ai dat să mănânce.'); return; }
      payload.custom_text = mealModalEditCustom.value.trim();
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

  document.getElementById('mealModalDeleteBtn').addEventListener('click', function() {
    if (!confirm('Ștergi această masă?')) return;
    fetch('delete_meal.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ id: currentMealId }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('delete failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut șterge masa. Încearcă din nou.');
    });
  });

  var addBtn = document.getElementById('addBtn');
  var newDate = document.getElementById('newDate');
  var newFood = document.getElementById('newFood');
  var newRecipe = document.getElementById('newRecipe');
  var newCustom = document.getElementById('newCustom');
  var newQuantity = document.getElementById('newQuantity');
  var newNotes = document.getElementById('newNotes');
  addBtn.addEventListener('click', function() {
    var mealDate = newDate.value;
    var source = activeSource(newSourceToggle);
    var quantity = newQuantity.value.trim();
    var notes = newNotes.value.trim();
    if (!mealDate) {
      alert('Completează data.');
      return;
    }
    var payload = { meal_date: mealDate, source: source, quantity: quantity, notes: notes };
    if (source === 'food') {
      if (!newFood.value || newFood.value === '0') { alert('Alege un aliment.'); return; }
      payload.food_id = newFood.value;
    } else if (source === 'recipe') {
      if (!newRecipe.value || newRecipe.value === '0') { alert('Alege o rețetă.'); return; }
      payload.recipe_id = newRecipe.value;
    } else {
      if (!newCustom.value.trim()) { alert('Scrie ce i-ai dat să mănânce.'); return; }
      payload.custom_text = newCustom.value.trim();
    }
    fetch('add_meal.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(payload).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut adăuga masa. Încearcă din nou.');
    });
  });

  [newQuantity, newNotes, newCustom].forEach(function(input) {
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') addBtn.click();
    });
  });
})();
</script>

</body>
</html>
