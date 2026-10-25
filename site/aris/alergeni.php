<?php
// Checklist de alergeni relevanti (fiecare rand e un aliment din lista comuna): o bifa daca i-a
// fost dat deja copilului, plus data si reactia avuta, cand e cazul.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

$foods = [];
$res = $mysqli->query('SELECT id, name FROM aris_foods ORDER BY name ASC');
if ($res) while ($row = $res->fetch_assoc()) $foods[(int)$row['id']] = $row['name'];

$allergens = [];
$res = $mysqli->query(
    'SELECT a.id, a.food_id, a.is_given, a.used_on, a.reaction, f.name AS food_name, f.is_allergic
     FROM aris_allergens a LEFT JOIN aris_foods f ON f.id = a.food_id
     ORDER BY a.sort_order ASC, a.id ASC'
);
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $row['is_given'] = (int)$row['is_given'] === 1;
        $row['food_id'] = $row['food_id'] !== null ? (int)$row['food_id'] : null;
        $row['is_allergic'] = (int)$row['is_allergic'] === 1;
        $allergens[] = $row;
    }
}

$usedFoodIds = array_filter(array_column($allergens, 'food_id'));
$availableFoods = array_diff_key($foods, array_flip($usedFoodIds));

$givenCount = count(array_filter($allergens, fn($a) => $a['is_given']));
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Alergeni</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 900px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 6px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }
  .progress-note { margin: 0 0 26px; font-size: 0.88rem; color: var(--ink-2); }
  .progress-note strong { color: var(--accent); font-weight: 600; }

  .add-row { display: flex; gap: 10px; margin-bottom: 26px; }
  .add-row select {
    flex: 1 1 auto; padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row select:focus { outline: none; border-color: var(--accent); }
  .add-row button {
    padding: 10px 18px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem; cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-row button:hover { background: #c6923a; }

  .allergen-list { display: flex; flex-direction: column; }
  .allergen-row {
    display: grid;
    grid-template-columns: 34px 1fr 140px 1fr 40px 78px;
    align-items: center;
    gap: 14px;
    padding: 13px 4px;
    border-bottom: 1px solid var(--line-soft);
  }

  .allergic-toggle {
    justify-self: center;
    width: 40px; height: 26px;
    font-family: var(--mono); font-weight: 600; font-size: 0.7rem;
    border: 1px solid var(--line); border-radius: 5px;
    background: transparent; color: var(--ink-3); cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease;
  }
  .allergic-toggle:hover { border-color: var(--accent); color: var(--accent); }
  .allergic-toggle.is-allergic { background: rgba(210,105,79,.12); border-color: var(--bad); color: var(--bad); }
  .allergic-toggle.is-allergic:hover { border-color: var(--bad); color: var(--bad); }
  .allergen-row.is-given { border-left: 2px solid var(--good); padding-left: 14px; background: rgba(157,191,122,0.05); border-radius: 0 5px 5px 0; }

  .given-checkbox {
    appearance: none; width: 20px; height: 20px; border-radius: 5px;
    border: 1px solid rgba(240,236,228,.22); background: var(--panel); cursor: pointer;
    position: relative;
  }
  .given-checkbox:checked { background: var(--good); border-color: var(--good); }
  .given-checkbox:checked::after {
    content: "✓"; position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    color: var(--on-accent); font-size: 13px; font-weight: 700;
  }

  .allergen-food { font-size: 0.92rem; font-weight: 600; color: var(--ink); }
  .allergen-food.is-empty { color: var(--ink-3); font-style: italic; font-weight: 400; }
  .allergen-date { font-family: var(--mono); font-size: 0.8rem; color: var(--ink-2); }
  .allergen-date.is-empty { color: var(--ink-3); }
  .allergen-reaction { font-size: 0.82rem; color: var(--ink-3); font-style: italic; }

  .allergen-actions { display: flex; justify-content: flex-end; gap: 6px; }
  .icon-btn {
    width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .icon-btn:hover { border-color: var(--accent); color: var(--accent); }
  .icon-btn.delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .allergen-row.is-editing { display: none; }
  .allergen-edit-row {
    display: none; flex-wrap: wrap; gap: 8px;
    background: var(--panel); border: 1px solid var(--accent); border-radius: 8px;
    padding: 14px 16px; margin-bottom: 4px;
  }
  .allergen-row.is-editing + .allergen-edit-row { display: flex; }
  .allergen-edit-row select, .allergen-edit-row input {
    padding: 8px 10px;
    background: var(--bg); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .allergen-edit-row select[name=edit-food] { width: 170px; }
  .allergen-edit-row input[name=edit-date] { width: 150px; font-family: var(--mono); }
  .allergen-edit-row input[name=edit-reaction] { flex: 1 1 200px; }
  .allergen-edit-row label { display: flex; align-items: center; gap: 6px; font-size: 0.82rem; color: var(--ink-2); }
  .allergen-edit-row select:focus, .allergen-edit-row input:focus { outline: none; border-color: var(--accent); }
  .allergen-edit-row .edit-actions { display: flex; gap: 8px; margin-left: auto; }
  .allergen-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .allergen-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .allergen-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .allergen-edit-row .delete-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }
  .allergen-edit-row .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px;
  }

  @media (max-width: 640px) {
    .allergen-row { grid-template-columns: 24px 1fr auto; }
    .allergen-date, .allergen-reaction { grid-column: 2 / 3; }
    .allergic-toggle { grid-column: 2 / 3; justify-self: start; }
    .allergen-actions { grid-column: 3 / 4; grid-row: 1 / 5; align-items: flex-start; }
  }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>ARIS</strong></div>
    <nav id="heroNav"><?php aris_render_nav('alergeni'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Alergeni</h1>
  <p class="progress-note">Introduși până acum: <strong id="progressCount"><?= $givenCount ?> din <?= count($allergens) ?></strong></p>

  <div class="add-row">
    <select id="newAllergenFood">
      <option value="0" disabled selected>Alege alimentul de urmărit</option>
      <?php foreach ($availableFoods as $fid => $fname): ?>
        <option value="<?= $fid ?>"><?= htmlspecialchars($fname) ?></option>
      <?php endforeach; ?>
    </select>
    <button type="button" id="addAllergenBtn">+ Adaugă alergen</button>
  </div>

  <?php if (empty($allergens)): ?>
    <div class="empty-state" id="emptyState">Niciun alergen adăugat încă. Adaugă primul mai sus.</div>
  <?php else: ?>
    <div class="allergen-list" id="allergenList">
      <?php foreach ($allergens as $a): ?>
        <div class="allergen-row<?= $a['is_given'] ? ' is-given' : '' ?>" data-id="<?= $a['id'] ?>">
          <input type="checkbox" class="given-checkbox" <?= $a['is_given'] ? 'checked' : '' ?>>
          <div class="allergen-food<?= $a['food_name'] === null ? ' is-empty' : '' ?>"><?= $a['food_name'] !== null ? htmlspecialchars($a['food_name']) : 'Aliment șters' ?></div>
          <div class="allergen-date<?= $a['used_on'] === null ? ' is-empty' : '' ?>"><?= $a['used_on'] !== null ? htmlspecialchars(aris_ro_date($a['used_on'])) : '—' ?></div>
          <div class="allergen-reaction"><?= $a['reaction'] !== null ? htmlspecialchars($a['reaction']) : '' ?></div>
          <?php if ($a['food_id'] !== null): ?>
            <button type="button" class="allergic-toggle<?= $a['is_allergic'] ? ' is-allergic' : '' ?>" data-food-id="<?= $a['food_id'] ?>" title="Alergic confirmat?"><?= $a['is_allergic'] ? 'DA' : 'NU' ?></button>
          <?php else: ?>
            <span></span>
          <?php endif; ?>
          <div class="allergen-actions">
            <button type="button" class="icon-btn edit-btn" title="Editează">✎</button>
            <button type="button" class="icon-btn delete-btn" title="Șterge">✕</button>
          </div>
        </div>
        <div class="allergen-edit-row">
          <select name="edit-food">
            <?php foreach ($foods as $fid => $fname): ?>
              <option value="<?= $fid ?>"<?= $fid === $a['food_id'] ? ' selected' : '' ?>><?= htmlspecialchars($fname) ?></option>
            <?php endforeach; ?>
          </select>
          <input type="date" name="edit-date" value="<?= htmlspecialchars($a['used_on'] ?? '') ?>">
          <input type="text" name="edit-reaction" maxlength="<?= ARIS_REACTION_MAX ?>" value="<?= htmlspecialchars($a['reaction'] ?? '') ?>" placeholder="Reacție (opțional)">
          <label><input type="checkbox" name="edit-given" <?= $a['is_given'] ? 'checked' : '' ?>> Dat</label>
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

  var addAllergenBtn = document.getElementById('addAllergenBtn');
  var newAllergenFood = document.getElementById('newAllergenFood');
  if (addAllergenBtn) {
    addAllergenBtn.addEventListener('click', function() {
      var foodId = newAllergenFood.value;
      if (!foodId || foodId === '0') {
        alert('Alege un aliment.');
        return;
      }
      fetch('allergen_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ food_id: foodId }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut adăuga alergenul. Încearcă din nou.');
      });
    });
  }

  function wireRow(row) {
    var id = row.getAttribute('data-id');
    var editRow = row.nextElementSibling;

    row.querySelector('.given-checkbox').addEventListener('change', function(e) {
      fetch('allergen_toggle.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, is_given: e.target.checked ? '1' : '0' }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('toggle failed');
        row.classList.toggle('is-given', e.target.checked);
        // Formularul de editare are propria bifa "Dat" - trebuie tinuta in sincron, altfel
        // deschiderea editarii dupa asta si apasarea Salveaza ar rescrie starea cu valoarea veche.
        var editGivenCheckbox = editRow && editRow.querySelector('[name=edit-given]');
        if (editGivenCheckbox) editGivenCheckbox.checked = e.target.checked;
        var progressCount = document.getElementById('progressCount');
        if (progressCount) {
          var givenNow = document.querySelectorAll('.given-checkbox:checked').length;
          var total = document.querySelectorAll('.given-checkbox').length;
          progressCount.textContent = givenNow + ' din ' + total;
        }
      }).catch(function() {
        alert('Nu s-a putut salva. Încearcă din nou.');
        e.target.checked = !e.target.checked;
      });
    });

    row.querySelector('.edit-btn').addEventListener('click', function() {
      row.classList.add('is-editing');
    });

    if (!editRow || !editRow.classList.contains('allergen-edit-row')) return;

    editRow.querySelector('.cancel-btn').addEventListener('click', function() {
      row.classList.remove('is-editing');
    });

    editRow.querySelector('.save-btn').addEventListener('click', function() {
      var foodId = editRow.querySelector('[name=edit-food]').value;
      var date = editRow.querySelector('[name=edit-date]').value;
      var reaction = editRow.querySelector('[name=edit-reaction]').value.trim();
      var given = editRow.querySelector('[name=edit-given]').checked;
      fetch('allergen_update.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, food_id: foodId, used_on: date, reaction: reaction, is_given: given ? '1' : '0' }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('update failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva modificarea. Încearcă din nou.');
      });
    });

    row.querySelector('.delete-btn').addEventListener('click', deleteAllergen);
    editRow.querySelector('.delete-btn').addEventListener('click', deleteAllergen);

    function deleteAllergen() {
      if (!confirm('Ștergi acest alergen din listă?')) return;
      fetch('allergen_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut șterge. Încearcă din nou.');
      });
    }
  }

  document.querySelectorAll('.allergen-row').forEach(wireRow);

  document.querySelectorAll('.allergic-toggle').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var id = btn.getAttribute('data-food-id');
      var next = !btn.classList.contains('is-allergic');
      fetch('food_toggle_allergic.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, is_allergic: next ? '1' : '0' }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('toggle failed');
        btn.classList.toggle('is-allergic', next);
        btn.textContent = next ? 'DA' : 'NU';
      }).catch(function() {
        alert('Nu s-a putut salva. Încearcă din nou.');
      });
    });
  });
})();
</script>

</body>
</html>
