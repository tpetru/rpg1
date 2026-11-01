<?php
// Notite: sus, notite libere (text + data si ora adaugarii, tabelul aris_notes); jos, lista meselor
// care au o observație atașată (camp "notes") - loc unde poti revedea rapid ce
// probleme/reactii/refuzuri au fost notate, fara sa cauti zi cu zi prin calendar.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

$notes = [];
$res = $mysqli->query('SELECT id, body, created_at FROM aris_notes ORDER BY created_at DESC, id DESC');
if ($res) {
    while ($row = $res->fetch_assoc()) $notes[] = $row;
}

$meals = [];
$res = $mysqli->query(
    "SELECT m.id, m.meal_date, m.food_id, m.recipe_id, m.custom_text, m.quantity, m.notes,
            f.name AS food_name, r.name AS recipe_name
     FROM aris_meals m
     LEFT JOIN aris_foods f ON f.id = m.food_id
     LEFT JOIN aris_recipes r ON r.id = m.recipe_id
     WHERE m.notes IS NOT NULL AND TRIM(m.notes) != ''
     ORDER BY m.meal_date DESC, m.id DESC"
);
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $row['label'] = aris_meal_label($row['food_name'], $row['recipe_name'], $row['custom_text']);
        $meals[] = $row;
    }
}
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris — Notițe</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 700px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 6px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }
  .sub { margin: 0 0 26px; font-size: 0.88rem; color: var(--ink-2); }

  .add-note { display: flex; flex-direction: column; gap: 8px; margin-bottom: 22px; }
  .add-note textarea {
    width: 100%; box-sizing: border-box; min-height: 84px; resize: vertical;
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem; line-height: 1.45;
  }
  .add-note textarea:focus { outline: none; border-color: var(--accent); }
  .add-note-foot { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .add-note-hint { font-family: var(--mono); font-size: 0.68rem; color: var(--ink-3); }
  .add-note button {
    padding: 10px 18px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem; cursor: pointer;
    transition: background 0.2s ease;
  }
  .add-note button:hover { background: #c6923a; }
  .add-note button:disabled { opacity: 0.6; cursor: default; }

  .note-list { display: flex; flex-direction: column; gap: 10px; margin-bottom: 40px; }
  .note-row {
    display: flex; gap: 14px; align-items: flex-start;
    padding: 14px 16px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 8px;
  }
  .note-when {
    flex-shrink: 0; width: 84px;
    font-family: var(--mono); font-size: 0.72rem; color: var(--ink-3); line-height: 1.4;
  }
  .note-when strong { display: block; color: var(--ink-2); font-weight: 500; }
  .note-body { flex: 1; min-width: 0; font-size: 0.9rem; color: var(--ink); white-space: pre-wrap; overflow-wrap: anywhere; }
  .note-delete {
    flex-shrink: 0; width: 27px; height: 27px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .note-delete:hover { border-color: var(--bad); color: var(--bad); }

  main h2 { margin: 0 0 6px; font-size: 1.25rem; font-weight: 600; letter-spacing: -0.02em; color: var(--ink); }

  .problem-list { display: flex; flex-direction: column; gap: 10px; }
  .problem-row {
    display: flex; gap: 14px;
    padding: 14px 16px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 8px;
  }
  .problem-date {
    flex-shrink: 0; width: 64px;
    font-family: var(--mono); font-size: 0.72rem; color: var(--ink-3);
    line-height: 1.4;
  }
  .problem-main { flex: 1; min-width: 0; }
  .problem-meal { font-size: 0.94rem; font-weight: 600; color: var(--ink); }
  .problem-meal-tag {
    margin-left: 6px;
    font-family: var(--mono); font-size: 0.6rem; text-transform: uppercase; letter-spacing: 0.05em;
    color: var(--ink-3);
  }
  .problem-note { margin-top: 5px; font-size: 0.86rem; color: var(--ink-2); font-style: italic; white-space: pre-wrap; }

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
    <nav id="heroNav"><?php aris_render_nav('notite'); ?></nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Notițe</h1>
  <p class="sub">Notițe libere, cu data și ora la care au fost adăugate. Cele mai recente primele.</p>

  <div class="add-note">
    <textarea id="newNoteBody" maxlength="<?= ARIS_FREE_NOTE_MAX ?>" placeholder="Scrie o notiță…"></textarea>
    <div class="add-note-foot">
      <span class="add-note-hint">Ctrl+Enter pentru a salva</span>
      <button type="button" id="addNoteBtn">Adaugă notița</button>
    </div>
  </div>

  <?php if (empty($notes)): ?>
    <div class="empty-state" style="margin-bottom: 40px;">Nicio notiță încă.</div>
  <?php else: ?>
    <div class="note-list">
      <?php foreach ($notes as $note): $ts = strtotime($note['created_at']); ?>
        <div class="note-row" data-id="<?= (int)$note['id'] ?>">
          <div class="note-when">
            <strong><?= htmlspecialchars(date('d.m.Y', $ts)) ?></strong>
            <?= htmlspecialchars(date('H:i', $ts)) ?>
          </div>
          <div class="note-body"><?= htmlspecialchars($note['body']) ?></div>
          <button type="button" class="note-delete" title="Șterge notița" aria-label="Șterge notița">✕</button>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <h2>Observații la mese</h2>
  <p class="sub">Toate mesele cu o observație atașată, cele mai recente primele.</p>

  <?php if (empty($meals)): ?>
    <div class="empty-state">Nicio masă cu observație încă.</div>
  <?php else: ?>
    <div class="problem-list">
      <?php foreach ($meals as $meal): ?>
        <div class="problem-row">
          <div class="problem-date"><?= htmlspecialchars(aris_ro_date($meal['meal_date'])) ?></div>
          <div class="problem-main">
            <div class="problem-meal">
              <?= htmlspecialchars($meal['label']['label']) ?><?php if ($meal['quantity']): ?> <span class="problem-meal-tag"><?= htmlspecialchars($meal['quantity']) ?></span><?php endif; ?>
            </div>
            <div class="problem-note"><?= nl2br(htmlspecialchars($meal['notes'])) ?></div>
          </div>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>
</main>

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

  var addNoteBtn = document.getElementById('addNoteBtn');
  var newNoteBody = document.getElementById('newNoteBody');
  if (addNoteBtn) {
    addNoteBtn.addEventListener('click', function() {
      var body = newNoteBody.value.trim();
      if (!body) return;
      addNoteBtn.disabled = true;
      fetch('note_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ body: body }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        location.reload();
      }).catch(function() {
        addNoteBtn.disabled = false;
        alert('Nu s-a putut salva notița. Încearcă din nou.');
      });
    });
    newNoteBody.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) addNoteBtn.click();
    });
  }

  document.querySelectorAll('.note-row').forEach(function(row) {
    row.querySelector('.note-delete').addEventListener('click', function() {
      if (!confirm('Ștergi această notiță?')) return;
      fetch('note_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: row.getAttribute('data-id') }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        row.remove();
      }).catch(function() {
        alert('Nu s-a putut șterge notița. Încearcă din nou.');
      });
    });
  });
})();
</script>

</body>
</html>
