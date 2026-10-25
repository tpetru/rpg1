<?php
// Pagina cu reels Instagram (executes/lineups video), separata de pozele static din /cs/<map>/.
// Fiecare reel are Harta + Echipa(T/CT) + Descriere, si e afisat cu embed-ul oficial Instagram.
require_once __DIR__ . '/../_defs.php';
require_once __DIR__ . '/../../includes/db.php';

cs_ensure_reels_table($mysqli);
site_theme_init($mysqli);

$reels = [];
$res = $mysqli->query('SELECT id, url, map_slug, team, description FROM cs_reels ORDER BY sort_order ASC, id DESC');
if ($res) {
    while ($row = $res->fetch_assoc()) {
        if (!isset($csReelMaps[$row['map_slug']])) continue;
        if (!isset($csReelTeams[$row['team']])) continue;
        $reels[] = $row;
    }
}

$addErrorMessages = [
    'bad_map'  => 'Harta selectată nu e validă.',
    'bad_team' => 'Echipa selectată nu e validă.',
    'bad_url'  => 'Link-ul nu pare a fi un reel/postare Instagram valid (ex: https://www.instagram.com/reel/XXXXXXX/).',
];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CS Lineups — Reels</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  :root { --c-t: #d9a441; --c-ct: #7fa3d1; }

  main { max-width: 1200px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .filter-group { margin-bottom: 14px; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .filter-label {
    font-family: var(--mono); font-size: 0.66rem; letter-spacing: 0.09em; text-transform: uppercase;
    color: var(--ink-3); flex-shrink: 0;
  }
  .filter-bar { display: flex; flex-wrap: wrap; gap: 8px; }
  .filter-btn {
    font-size: 0.78rem; padding: 5px 12px; border-radius: 14px;
    border: 1px solid var(--line); color: var(--ink-2);
    background: transparent; cursor: pointer; font-family: var(--disp);
    transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
  }
  .filter-btn .count { font-family: var(--mono); font-size: 0.7rem; }
  .filter-btn.is-active { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 500; }
  .filter-btn:hover:not(.is-active) { border-color: var(--accent); color: var(--ink); }

  .reel-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 360px));
    justify-content: center;
    gap: 18px;
    margin-top: 28px;
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
  .reel-body { padding: 13px 15px; display: flex; flex-direction: column; gap: 8px; }
  .reel-tags { display: flex; gap: 6px; flex-wrap: wrap; }
  .tag {
    padding: 2px 10px;
    border-radius: 10px;
    font-family: var(--mono); font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.06em;
    border: 1px solid currentColor;
  }
  .tag.map-tag { color: var(--ink-2); }
  .tag.team-tag[data-team=t]  { color: var(--c-t); }
  .tag.team-tag[data-team=ct] { color: var(--c-ct); }
  .reel-desc { font-size: 0.88rem; color: var(--ink); min-height: 1.2em; }
  .reel-desc:empty::before { content: "Fără descriere"; color: var(--ink-3); font-style: italic; }

  .reel-actions { display: flex; gap: 6px; margin-top: 2px; }
  .reel-actions button {
    flex: 1;
    padding: 6px 10px;
    background: transparent;
    border: 1px solid var(--line);
    border-radius: 5px;
    color: var(--ink-3);
    font-family: var(--mono); font-size: 0.72rem;
    cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .reel-actions .edit-btn:hover { border-color: var(--accent); color: var(--accent); }
  .reel-actions .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .reel-edit { display: none; flex-direction: column; gap: 8px; }
  .reel-card.is-editing .reel-view { display: none; }
  .reel-card.is-editing .reel-edit { display: flex; }
  .reel-edit input, .reel-edit select {
    padding: 8px 10px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--disp); font-size: 0.88rem;
  }
  .reel-edit input:focus, .reel-edit select:focus { outline: none; border-color: var(--accent); }
  .reel-edit .edit-row { display: flex; gap: 8px; }
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
    display: block; width: 100%; margin: 20px 0 24px;
    padding: 11px 14px;
    border: 1px dashed rgba(240,236,228,.16); border-radius: 6px;
    background: transparent; color: var(--ink-2);
    font-family: var(--disp); font-size: 0.82rem;
    cursor: pointer; text-align: center;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .add-toggle-btn:hover { border-color: var(--accent); color: var(--accent); }

  .add-card-backdrop {
    position: fixed; inset: 0; z-index: 600;
    background: rgba(0,0,0,0.55);
    display: flex; align-items: center; justify-content: center;
    padding: 20px;
  }
  .add-card-backdrop[hidden] { display: none; }
  .add-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--accent);
    border-radius: 10px;
    padding: 22px 24px;
    max-width: 560px; width: 100%;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .add-card-head { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-bottom: 14px; }
  .add-card h2 {
    margin: 0;
    font-family: var(--disp); font-weight: 600; font-size: 1rem; color: var(--ink);
  }
  .add-card-close {
    flex-shrink: 0;
    width: 26px; height: 26px;
    display: flex; align-items: center; justify-content: center;
    border: none; border-radius: 50%;
    background: transparent;
    color: var(--ink-2);
    font-size: 0.9rem;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .add-card-close:hover { background: rgba(210,105,79,0.2); color: var(--bad); }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  .add-row input[type=text], .add-row input[type=url], .add-row select {
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .add-row input[name=url] { flex: 2 1 260px; font-family: var(--mono); }
  .add-row input[name=description] { flex: 1 1 200px; }
  .add-row select { width: 140px; }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
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

  .add-error-banner {
    padding: 11px 15px; margin-bottom: 20px;
    border-left: 2px solid var(--bad); border-radius: 0 6px 6px 0;
    background: rgba(210,105,79,.08);
    color: var(--ink); font-size: 0.85rem;
  }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CS</strong><span>lineups</span></div>
    <nav id="heroNav">
      <a href="/cs/reels/" class="is-current">Reels</a>
      <a href="/cs/profile.php">Profil</a>
    </nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Reels</h1>

  <button type="button" class="add-toggle-btn" id="addToggleBtn">+ Adaugă reel</button>

  <div class="add-card-backdrop" id="addCardBackdrop" hidden>
    <div class="add-card" id="addCard" role="dialog" aria-modal="true" aria-labelledby="addCardTitle">
      <div class="add-card-head">
        <h2 id="addCardTitle">Adaugă reel</h2>
        <button type="button" class="add-card-close" id="addCardClose" title="Închide">✕</button>
      </div>
      <form class="add-form" method="post" action="/cs/reels/add_reel.php">
        <div class="add-row">
          <input type="url" name="url" placeholder="Link Instagram reel (https://www.instagram.com/reel/...)" required>
          <select name="map">
            <?php foreach ($csReelMaps as $slug => $name): ?>
              <option value="<?= htmlspecialchars($slug) ?>"><?= htmlspecialchars($name) ?></option>
            <?php endforeach; ?>
          </select>
          <select name="team">
            <?php foreach ($csReelTeams as $key => $name): ?>
              <option value="<?= htmlspecialchars($key) ?>"><?= htmlspecialchars($name) ?></option>
            <?php endforeach; ?>
          </select>
          <input type="text" name="description" maxlength="128" placeholder="Descriere scurtă (max 128 caractere)">
        </div>
        <button type="submit" class="add-btn">Adaugă reel</button>
      </form>
    </div>
  </div>

  <?php if (!empty($_GET['add_error'])): ?>
    <?php
      $code = $_GET['add_error'];
      $msg = $addErrorMessages[$code] ?? ('Eroare necunoscută (cod: ' . $code . ').');
    ?>
    <div class="add-error-banner">Nu s-a putut adăuga reel-ul. <?= htmlspecialchars($msg) ?></div>
  <?php endif; ?>

  <div class="filter-group">
    <span class="filter-label">Hartă</span>
    <div class="filter-bar" id="mapFilterBar">
      <button class="filter-btn is-active" data-map="all">Toate <span class="count"><?= count($reels) ?></span></button>
      <?php foreach ($csReelMaps as $slug => $name): ?>
        <?php $c = count(array_filter($reels, fn($r) => $r['map_slug'] === $slug)); ?>
        <button class="filter-btn" data-map="<?= htmlspecialchars($slug) ?>"><?= htmlspecialchars($name) ?> <span class="count"><?= $c ?></span></button>
      <?php endforeach; ?>
    </div>
  </div>

  <div class="filter-group">
    <span class="filter-label">Echipă</span>
    <div class="filter-bar" id="teamFilterBar">
      <button class="filter-btn is-active" data-team="all">Toate <span class="count"><?= count($reels) ?></span></button>
      <?php foreach ($csReelTeams as $key => $name): ?>
        <?php $c = count(array_filter($reels, fn($r) => $r['team'] === $key)); ?>
        <button class="filter-btn" data-team="<?= htmlspecialchars($key) ?>"><?= htmlspecialchars($name) ?> <span class="count"><?= $c ?></span></button>
      <?php endforeach; ?>
    </div>
  </div>

  <?php if (empty($reels)): ?>
    <div class="empty-state">Niciun reel adăugat încă. Adaugă primul mai jos.</div>
  <?php else: ?>
    <div class="reel-grid" id="reelGrid">
      <?php foreach ($reels as $reel): ?>
        <div class="reel-card" data-id="<?= (int)$reel['id'] ?>" data-map="<?= htmlspecialchars($reel['map_slug']) ?>" data-team="<?= htmlspecialchars($reel['team']) ?>">
          <div class="reel-embed">
            <blockquote class="instagram-media" data-instgrm-permalink="<?= htmlspecialchars($reel['url']) ?>" data-instgrm-version="14"></blockquote>
          </div>
          <div class="reel-body">
            <div class="reel-view">
              <div class="reel-tags">
                <span class="tag map-tag"><?= htmlspecialchars($csReelMaps[$reel['map_slug']]) ?></span>
                <span class="tag team-tag" data-team="<?= htmlspecialchars($reel['team']) ?>"><?= htmlspecialchars($csReelTeams[$reel['team']]) ?></span>
              </div>
              <div class="reel-desc"><?= htmlspecialchars($reel['description'] ?? '') ?></div>
              <div class="reel-actions">
                <button class="edit-btn">✎ Editează</button>
                <button class="delete-btn">✕ Șterge</button>
              </div>
            </div>
            <div class="reel-edit">
              <input type="text" class="edit-desc" maxlength="128" value="<?= htmlspecialchars($reel['description'] ?? '') ?>" placeholder="Descriere scurtă (max 128 caractere)">
              <div class="edit-row">
                <select class="edit-map">
                  <?php foreach ($csReelMaps as $slug => $name): ?>
                    <option value="<?= htmlspecialchars($slug) ?>"<?= $slug === $reel['map_slug'] ? ' selected' : '' ?>><?= htmlspecialchars($name) ?></option>
                  <?php endforeach; ?>
                </select>
                <select class="edit-team">
                  <?php foreach ($csReelTeams as $key => $name): ?>
                    <option value="<?= htmlspecialchars($key) ?>"<?= $key === $reel['team'] ? ' selected' : '' ?>><?= htmlspecialchars($name) ?></option>
                  <?php endforeach; ?>
                </select>
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

</main>

<?php site_render_footer(); ?>

<script async src="//www.instagram.com/embed.js"></script>
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

  var addToggleBtn = document.getElementById('addToggleBtn');
  var addCardBackdrop = document.getElementById('addCardBackdrop');
  var addCard = document.getElementById('addCard');
  var addCardClose = document.getElementById('addCardClose');
  if (addToggleBtn && addCardBackdrop) {
    function openAddCard() {
      addCardBackdrop.hidden = false;
      addCardBackdrop.querySelector('input[name=url]').focus();
    }
    function closeAddCard() {
      addCardBackdrop.hidden = true;
    }
    addToggleBtn.addEventListener('click', openAddCard);
    addCardClose.addEventListener('click', closeAddCard);
    addCardBackdrop.addEventListener('click', function(e) {
      if (e.target === addCardBackdrop) closeAddCard();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && !addCardBackdrop.hidden) closeAddCard();
    });
    <?php if (!empty($_GET['add_error'])): ?>
    openAddCard();
    <?php endif; ?>
  }

  var mapBar = document.getElementById('mapFilterBar');
  var teamBar = document.getElementById('teamFilterBar');
  var grid = document.getElementById('reelGrid');
  var activeMap = 'all';
  var activeTeam = 'all';

  function applyFilters() {
    if (!grid) return;
    grid.querySelectorAll('.reel-card').forEach(function(card) {
      var matchMap = activeMap === 'all' || card.getAttribute('data-map') === activeMap;
      var matchTeam = activeTeam === 'all' || card.getAttribute('data-team') === activeTeam;
      card.classList.toggle('is-hidden', !(matchMap && matchTeam));
    });
  }

  if (mapBar) {
    mapBar.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        activeMap = btn.getAttribute('data-map');
        mapBar.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.toggle('is-active', b === btn); });
        applyFilters();
      });
    });
  }

  if (teamBar) {
    teamBar.querySelectorAll('.filter-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        activeTeam = btn.getAttribute('data-team');
        teamBar.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.toggle('is-active', b === btn); });
        applyFilters();
      });
    });
  }

  if (grid) {
    grid.querySelectorAll('.reel-card').forEach(function(card) {
      var id = card.getAttribute('data-id');

      card.querySelector('.edit-btn').addEventListener('click', function() {
        card.classList.add('is-editing');
      });
      card.querySelector('.cancel-btn').addEventListener('click', function() {
        card.classList.remove('is-editing');
      });

      card.querySelector('.save-btn').addEventListener('click', function() {
        var desc = card.querySelector('.edit-desc').value.trim();
        var map = card.querySelector('.edit-map').value;
        var team = card.querySelector('.edit-team').value;

        fetch('/cs/reels/update_reel.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, map: map, team: team, description: desc }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('save failed');
          location.reload();
        }).catch(function() {
          alert('Nu s-a putut salva. Încearcă din nou.');
        });
      });

      card.querySelector('.delete-btn').addEventListener('click', function() {
        if (!confirm('Ștergi acest reel?')) return;
        fetch('/cs/reels/delete_reel.php', {
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
