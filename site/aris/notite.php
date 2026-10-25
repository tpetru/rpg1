<?php
// Lista meselor care au o observație atașată (camp "notite") - loc unde poti revedea rapid ce
// probleme/reactii/refuzuri au fost notate, fara sa cauti zi cu zi prin calendar.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);
aris_require_page_auth();
aris_ensure_tables($mysqli);

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
})();
</script>

</body>
</html>
