<?php
require_once __DIR__ . '/_auth.php';
// Personal page - chronological work log for the house: one row per entry (date, title, cost,
// optional note), newest first. Entries are user-managed straight from this page.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];
require_once __DIR__ . '/stage_defs.php';
$stageTagText = casa_current_stage_tag($mysqli, $houseId, $stageLabels, $stageCount);

// Every house has one password now (no more owner/guest split) - everyone who gets in sees everything.
$isOwner = true;

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_journal (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        entry_date DATE NOT NULL,
        title VARCHAR(150) NOT NULL,
        price DECIMAL(10,2) NOT NULL DEFAULT 0,
        comment VARCHAR(256) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY entry_date (entry_date)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

$entries = [];
$stmt = $mysqli->prepare('SELECT id, entry_date, title, price, comment FROM casa_journal WHERE house_id = ? ORDER BY entry_date DESC, id DESC');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    if (!$isOwner) $row['price'] = 0;
    $entries[] = $row;
}

$totalSpent = 0;
foreach ($entries as $entry) {
    $totalSpent += (float)$entry['price'];
}

// Group by "YYYY-MM" so the timeline reads month by month instead of one flat list.
$entriesByMonth = [];
foreach ($entries as $entry) {
    $entriesByMonth[substr($entry['entry_date'], 0, 7)][] = $entry;
}

$monthNames = [
    '01' => 'Ianuarie', '02' => 'Februarie', '03' => 'Martie', '04' => 'Aprilie',
    '05' => 'Mai', '06' => 'Iunie', '07' => 'Iulie', '08' => 'August',
    '09' => 'Septembrie', '10' => 'Octombrie', '11' => 'Noiembrie', '12' => 'Decembrie',
];
function casa_month_label(string $ym, array $monthNames): string
{
    [$year, $month] = explode('-', $ym);
    return ($monthNames[$month] ?? $month) . ' ' . $year;
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Jurnal</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  a { color: var(--accent); text-decoration: none; }

  main { max-width: 1200px; margin: 0 auto; padding: 40px 24px 80px; }

  .summary-card {
    display: flex; align-items: baseline; justify-content: space-between; flex-wrap: wrap; gap: 8px 20px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 18px 22px;
    margin-bottom: 28px;
    font-family: var(--mono);
    font-size: 0.85rem;
    color: var(--ink);
  }
  .summary-card strong { color: var(--accent); font-weight: 500; }

  .month-group { margin-bottom: 34px; }
  .month-label {
    margin: 0 0 14px;
    font-weight: 600;
    font-size: 1rem;
    color: var(--ink);
    border-bottom: 1px solid var(--line);
    padding-bottom: 8px;
    display: flex; align-items: baseline; justify-content: space-between; gap: 12px;
  }
  .month-label .month-total { font-family: var(--mono); font-weight: 400; font-size: 0.8rem; color: var(--ink-3); }

  .entry {
    display: flex; align-items: flex-start; gap: 14px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 8px;
    padding: 14px 16px;
    margin-bottom: 10px;
  }
  .entry-date {
    flex-shrink: 0;
    width: 58px;
    text-align: center;
    font-family: var(--mono);
    line-height: 1.2;
  }
  .entry-date .day { display: block; font-size: 1.3rem; color: var(--ink); }
  .entry-date .mon { display: block; font-size: 0.66rem; color: var(--ink-2); text-transform: uppercase; }
  .entry-main { flex: 1; min-width: 0; }
  .entry-title { font-weight: 600; font-size: 0.98rem; color: var(--ink); overflow-wrap: anywhere; }
  .entry-comment { margin-top: 3px; color: var(--ink-2); font-size: 0.85rem; font-style: italic; overflow-wrap: anywhere; }
  .entry-price {
    flex-shrink: 0;
    font-family: var(--mono);
    font-size: 0.95rem;
    color: var(--accent);
    white-space: nowrap;
  }
  .entry-actions { display: flex; gap: 6px; flex-shrink: 0; }
  .edit-btn, .delete-btn {
    background: transparent; border: 1px solid var(--line); color: var(--ink-3);
    width: 27px; height: 27px; border-radius: 5px; cursor: pointer; font-size: 0.9rem;
    display: inline-flex; align-items: center; justify-content: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .edit-btn:hover { border-color: var(--accent); color: var(--accent); }
  .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .entry-edit {
    display: none; flex-wrap: wrap; gap: 8px;
    background: var(--panel);
    border: 1px solid var(--accent);
    border-radius: 8px;
    padding: 14px 16px;
    margin-bottom: 10px;
  }
  .entry.is-editing { display: none; }
  .entry.is-editing + .entry-edit { display: flex; }
  .entry-edit input {
    padding: 8px 10px;
    background: var(--panel); border: 1px solid var(--line-soft); border-radius: 5px;
    color: var(--ink); font-size: 0.9rem; font-family: var(--disp);
  }
  .entry-edit input[name=edit-date] { width: 150px; font-family: var(--mono); }
  .entry-edit input[name=edit-title] { flex: 1; min-width: 200px; }
  .entry-edit input[name=edit-price] { width: 120px; font-family: var(--mono); text-align: right; }
  .entry-edit input[name=edit-comment] { flex-basis: 100%; }
  .entry-edit input:focus { outline: none; border-color: var(--accent); }
  .entry-edit button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .entry-edit .save-btn { background: var(--accent); color: var(--on-accent); }
  .entry-edit .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 40px 20px; border: 1px dashed var(--line); border-radius: 8px; margin-bottom: 28px;
  }

  .add-toggle-btn {
    display: block; width: 100%;
    margin: -12px 0 28px;
    padding: 11px 14px;
    border: 1px dashed var(--line); border-radius: 8px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.88rem; font-weight: 600;
    cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-toggle-btn:hover { border-color: var(--accent); color: var(--accent); border-style: solid; }

  .add-backdrop {
    position: fixed; inset: 0; z-index: 600;
    background: rgba(0,0,0,0.55);
    display: flex; align-items: center; justify-content: center;
    padding: 16px;
  }
  .add-backdrop[hidden] { display: none; }
  .add-card {
    width: 100%; max-width: 520px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--accent);
    border-radius: 10px;
    padding: 22px 24px;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .add-card-head { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 16px; }
  .add-card h2 {
    margin: 0;
    font-family: var(--disp); font-weight: 600;
    font-size: 1.1rem; color: var(--ink);
  }
  .add-card-close {
    flex-shrink: 0;
    width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center;
    border: none; border-radius: 50%;
    background: transparent; color: var(--ink-2);
    font-size: 0.95rem; cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .add-card-close:hover { background: rgba(210,105,79,0.2); color: var(--bad); }
  .add-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .add-row input {
    min-width: 0;
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-size: 0.95rem; font-family: var(--disp);
  }
  .add-row input[name=date] { font-family: var(--mono); }
  .add-row input[name=price] { font-family: var(--mono); text-align: right; }
  .add-row input[name=title],
  .add-row input[name=comment],
  .add-row button { grid-column: 1 / -1; }
  .add-row input:focus { outline: none; border-color: var(--accent); }
  .add-row button {
    padding: 10px 22px;
    background: var(--accent);
    border: none;
    border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-row button:hover { background: #c6923a; }

  input[type=number] { -moz-appearance: textfield; appearance: textfield; }
  input[type=number]::-webkit-outer-spin-button,
  input[type=number]::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }

  /* Pe telefon nu incap data + titlu + pret + butoane pe un rand: pretul coboara sub titlu,
     iar butoanele raman in dreapta sus. */
  @media (max-width: 600px) {
    main { padding: 24px 14px 60px; }
    .entry {
      display: grid;
      grid-template-columns: 40px 1fr auto;
      grid-template-areas:
        "date main  actions"
        "date price actions";
      column-gap: 10px; row-gap: 4px;
      padding: 11px 12px;
    }
    .entry-date { grid-area: date; width: auto; }
    .entry-date .day { font-size: 1.05rem; }
    .entry-date .mon { font-size: 0.6rem; }
    .entry-main { grid-area: main; }
    .entry-title { font-size: 0.86rem; line-height: 1.35; }
    .entry-comment { font-size: 0.76rem; }
    .entry-price { grid-area: price; font-size: 0.8rem; }
    .entry-actions { grid-area: actions; align-self: start; gap: 4px; }
    .edit-btn, .delete-btn { width: 25px; height: 25px; font-size: 0.8rem; }

    .summary-card { flex-direction: column; align-items: flex-start; gap: 4px; padding: 14px 16px; font-size: 0.8rem; }
    .month-label { font-size: 0.92rem; }

    .entry-edit input[name=edit-date],
    .entry-edit input[name=edit-price],
    .entry-edit input[name=edit-title] { width: 100%; min-width: 0; flex-basis: 100%; }
    .add-toggle-btn { margin: -14px 0 22px; }
    .add-card { padding: 18px 16px; }
  }
</style>
<link rel="stylesheet" href="/assets/casa-undo.css">
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span><?= htmlspecialchars($currentHouse['name']) ?></span></div>
    <nav id="heroNav">
      <a href="/progres.php">Construcție</a>
      <a href="/design/">Design</a>
      <a href="/links.php">Link-uri</a>
      <a href="/jurnal.php" class="is-current">Jurnal</a>
      <a href="/shopping.php">Lista de cumpărături</a>
      <a href="/index.php?logout=all" class="nav-exit">Ieși</a>
    </nav>
  </div>
  <span class="stage-tag"><?= htmlspecialchars($stageTagText) ?></span>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>

  <div class="summary-card">
    <span id="entryCountLabel"><?= count($entries) ?> intrări în jurnal</span>
    <span>Total cheltuit: <strong id="totalSpentLabel" title="<?= htmlspecialchars(casa_eur_title($totalSpent)) ?>"><?= casa_format_lei($totalSpent) ?></strong></span>
  </div>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă în jurnal</button>

  <?php if (empty($entries)): ?>
    <div class="empty-state" id="journalEmptyState">Jurnalul e gol. Adaugă prima intrare cu butonul de mai sus.</div>
  <?php else: ?>
    <?php foreach ($entriesByMonth as $ym => $monthEntries): ?>
      <?php
        $monthTotal = 0;
        foreach ($monthEntries as $e) $monthTotal += (float)$e['price'];
      ?>
      <div class="month-group">
        <h2 class="month-label">
          <?= htmlspecialchars(casa_month_label($ym, $monthNames)) ?>
          <span class="month-total" title="<?= htmlspecialchars(casa_eur_title($monthTotal)) ?>"><?= casa_format_lei($monthTotal) ?></span>
        </h2>

        <?php foreach ($monthEntries as $entry): ?>
          <?php
            $ts = strtotime($entry['entry_date']);
            $day = date('d', $ts);
            $monShort = mb_substr($monthNames[date('m', $ts)] ?? '', 0, 3);
          ?>
          <div class="entry" data-id="<?= (int)$entry['id'] ?>" data-price="<?= htmlspecialchars($entry['price']) ?>">
            <div class="entry-date">
              <span class="day"><?= $day ?></span>
              <span class="mon"><?= htmlspecialchars($monShort) ?></span>
            </div>
            <div class="entry-main">
              <div class="entry-title"><?= htmlspecialchars($entry['title']) ?></div>
              <?php if (!empty($entry['comment'])): ?>
                <div class="entry-comment"><?= htmlspecialchars($entry['comment']) ?></div>
              <?php endif; ?>
            </div>
            <div class="entry-price" title="<?= htmlspecialchars(casa_eur_title((float)$entry['price'])) ?>"><?= casa_format_lei((float)$entry['price']) ?></div>
            <div class="entry-actions">
              <button class="edit-btn" title="Editează">✎</button>
              <button class="delete-btn" title="Șterge">✕</button>
            </div>
          </div>
          <div class="entry-edit">
            <input type="date" name="edit-date" value="<?= htmlspecialchars($entry['entry_date']) ?>">
            <input type="text" name="edit-title" value="<?= htmlspecialchars($entry['title']) ?>" maxlength="150" placeholder="Titlu">
            <input type="number" name="edit-price" value="<?= htmlspecialchars($entry['price']) ?>" min="0" step="0.01" placeholder="Preț" title="<?= htmlspecialchars(casa_eur_title((float)$entry['price'])) ?>" <?= $isOwner ? '' : 'disabled' ?>>
            <input type="text" name="edit-comment" value="<?= htmlspecialchars($entry['comment'] ?? '') ?>" maxlength="256" placeholder="Comentariu (opțional, max 256 caractere)">
            <button type="button" class="save-btn">Salvează</button>
            <button type="button" class="cancel-btn">Anulează</button>
          </div>
        <?php endforeach; ?>
      </div>
    <?php endforeach; ?>
  <?php endif; ?>

</main>

<div class="add-backdrop" id="addBackdrop" hidden>
  <div class="add-card" role="dialog" aria-modal="true" aria-labelledby="addCardTitle">
    <div class="add-card-head">
      <h2 id="addCardTitle">Adaugă în jurnal</h2>
      <button type="button" class="add-card-close" id="addCardClose" title="Închide">✕</button>
    </div>
    <div class="add-row">
      <input type="date" name="date" id="newDate" value="<?= date('Y-m-d') ?>">
      <input type="number" name="price" id="newPrice" min="0" step="0.01" placeholder="Preț (LEI)" <?= $isOwner ? '' : 'value="0" disabled' ?>>
      <input type="text" name="title" id="newTitle" maxlength="150" placeholder="Ce s-a făcut (ex: Turnat fundația)">
      <input type="text" name="comment" id="newComment" maxlength="256" placeholder="Comentariu (opțional, max 256 caractere)">
      <button id="addEntryBtn">Adaugă</button>
    </div>
  </div>
</div>

<?php casa_render_footer(); ?>

<script src="/assets/casa-undo.js"></script>
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
})();

(function() {
  var addBtn = document.getElementById('addEntryBtn');
  var dateInput = document.getElementById('newDate');
  var titleInput = document.getElementById('newTitle');
  var priceInput = document.getElementById('newPrice');
  var commentInput = document.getElementById('newComment');
  priceInput.addEventListener('input', function() {
    var p = parseFloat(priceInput.value);
    priceInput.title = formatEurTitle(isNaN(p) ? 0 : p);
  });

  var EUR_TO_LEI = 5.25;
  function formatLei(n) {
    return n.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' LEI';
  }
  function formatEurTitle(n) {
    return (n / EUR_TO_LEI).toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' EUR';
  }

  function refreshJournalTotals() {
    var grandTotal = 0;
    document.querySelectorAll('.month-group').forEach(function(group) {
      var monthTotal = 0;
      var entries = group.querySelectorAll('.entry');
      entries.forEach(function(e) {
        monthTotal += parseFloat(e.getAttribute('data-price')) || 0;
      });
      var monthTotalEl = group.querySelector('.month-total');
      if (monthTotalEl) { monthTotalEl.textContent = formatLei(monthTotal); monthTotalEl.title = formatEurTitle(monthTotal); }
      group.style.display = entries.length === 0 ? 'none' : '';
      grandTotal += monthTotal;
    });

    var count = document.querySelectorAll('.entry').length;
    var countLabel = document.getElementById('entryCountLabel');
    if (countLabel) countLabel.textContent = count + ' intrări în jurnal';
    var totalLabel = document.getElementById('totalSpentLabel');
    if (totalLabel) { totalLabel.textContent = formatLei(grandTotal); totalLabel.title = formatEurTitle(grandTotal); }

    var emptyState = document.getElementById('journalEmptyState');
    if (count === 0) {
      if (!emptyState) {
        emptyState = document.createElement('div');
        emptyState.className = 'empty-state';
        emptyState.id = 'journalEmptyState';
        emptyState.textContent = 'Jurnalul e gol. Adaugă prima intrare cu butonul de mai sus.';
        document.getElementById('addToggleBtn').after(emptyState);
      }
    } else if (emptyState) {
      emptyState.remove();
    }
  }

  document.querySelectorAll('.delete-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var entry = btn.closest('.entry');
      var editRow = entry.nextElementSibling;
      var id = entry.getAttribute('data-id');
      var parent = entry.parentNode;
      var nextSibling = editRow.nextSibling;

      entry.remove();
      editRow.remove();
      refreshJournalTotals();

      casaUndoAction({
        message: 'Intrare ștearsă din jurnal.',
        commit: function() {
          fetch('jurnal_delete.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ id: id }).toString()
          }).catch(function() {});
        },
        undo: function() {
          if (nextSibling && nextSibling.parentNode === parent) {
            parent.insertBefore(entry, nextSibling);
            parent.insertBefore(editRow, nextSibling);
          } else {
            parent.appendChild(entry);
            parent.appendChild(editRow);
          }
          refreshJournalTotals();
        }
      });
    });
  });

  document.querySelectorAll('.edit-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      btn.closest('.entry').classList.add('is-editing');
    });
  });

  document.querySelectorAll('.entry-edit').forEach(function(editRow) {
    var entry = editRow.previousElementSibling;
    var id = entry.getAttribute('data-id');

    var editPriceInput = editRow.querySelector('[name=edit-price]');
    editPriceInput.addEventListener('input', function() {
      var p = parseFloat(editPriceInput.value);
      editPriceInput.title = formatEurTitle(isNaN(p) ? 0 : p);
    });

    editRow.querySelector('.cancel-btn').addEventListener('click', function() {
      entry.classList.remove('is-editing');
    });

    editRow.querySelector('.save-btn').addEventListener('click', function() {
      var date = editRow.querySelector('[name=edit-date]').value;
      var title = editRow.querySelector('[name=edit-title]').value.trim();
      var price = parseFloat(editRow.querySelector('[name=edit-price]').value);
      var comment = editRow.querySelector('[name=edit-comment]').value.trim();
      if (!date || !title) {
        alert('Completează cel puțin data și titlul.');
        return;
      }
      if (isNaN(price) || price < 0) price = 0;

      fetch('jurnal_update.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, date: date, title: title, price: price, comment: comment }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('update failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva modificarea. Încearcă din nou.');
      });
    });
  });

  addBtn.addEventListener('click', function() {
    var date = dateInput.value;
    var title = titleInput.value.trim();
    var price = parseFloat(priceInput.value);
    var comment = commentInput.value.trim();
    if (!date || !title) {
      alert('Completează cel puțin data și titlul.');
      return;
    }
    if (isNaN(price) || price < 0) price = 0;

    fetch('jurnal_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ date: date, title: title, price: price, comment: comment }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut adăuga intrarea. Încearcă din nou.');
    });
  });

  [dateInput, titleInput, priceInput, commentInput].forEach(function(input) {
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') addBtn.click();
    });
  });

  var addBackdrop = document.getElementById('addBackdrop');
  function openAddPopup() {
    addBackdrop.hidden = false;
    titleInput.focus();
  }
  function closeAddPopup() {
    addBackdrop.hidden = true;
  }
  document.getElementById('addToggleBtn').addEventListener('click', openAddPopup);
  document.getElementById('addCardClose').addEventListener('click', closeAddPopup);
  addBackdrop.addEventListener('click', function(e) {
    if (e.target === addBackdrop) closeAddPopup();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && !addBackdrop.hidden) closeAddPopup();
  });
})();
</script>

</body>
</html>
