<?php
require_once __DIR__ . '/_auth.php';
// Personal page - a categorized collection of useful links for the house project (wallpaper shops,
// suppliers, inspiration, etc). Categories are free text, not a fixed list, so a new category is
// created just by typing a new name in the add form - no code change needed. Each link also belongs
// to one of the fixed rooms (same set as /design/) - that's the primary grouping shown on the
// page; category is kept as a small optional secondary tag.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];
require_once __DIR__ . '/stage_defs.php';
$stageTagText = casa_current_stage_tag($mysqli, $houseId, $stageLabels, $stageCount);

// Same room set/order/labels as casa/design/index.php, kept as a small local copy here since the
// two pages don't share an include for this - "others" is the catch-all default.
$casaRooms = casa_rooms_for_pages($mysqli, $houseId, $currentHouse['slug']);

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_links (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        category VARCHAR(100) NOT NULL,
        label VARCHAR(150) NULL,
        url VARCHAR(500) NOT NULL,
        comment VARCHAR(256) NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$hasCommentCol = $mysqli->query("SHOW COLUMNS FROM casa_links LIKE 'comment'");
if ($hasCommentCol && $hasCommentCol->num_rows === 0) {
    $mysqli->query('ALTER TABLE casa_links ADD COLUMN comment VARCHAR(256) NULL AFTER url');
}
$hasRoomCol = $mysqli->query("SHOW COLUMNS FROM casa_links LIKE 'room_slug'");
if ($hasRoomCol && $hasRoomCol->num_rows === 0) {
    $mysqli->query("ALTER TABLE casa_links ADD COLUMN room_slug VARCHAR(64) NOT NULL DEFAULT 'others' AFTER category");
}

// One-time seed of the links the user already had in mind, only if this house has never used it.
$countStmt = $mysqli->prepare('SELECT COUNT(*) AS c FROM casa_links WHERE house_id = ?');
$countStmt->bind_param('i', $houseId);
$countStmt->execute();
$countRes = $countStmt->get_result();
if ($countRes && (int)$countRes->fetch_assoc()['c'] === 0) {
    $seedStmt = $mysqli->prepare('INSERT INTO casa_links (category, label, url, sort_order, house_id) VALUES (?, NULL, ?, ?, ?)');
    $seedCategory = 'Link-uri tapet';
    $seedUrls = ['https://www.vladila.ro', 'https://rebelwalls.com/ro'];
    foreach ($seedUrls as $i => $seedUrl) {
        $order = $i + 1;
        $seedStmt->bind_param('ssii', $seedCategory, $seedUrl, $order, $houseId);
        $seedStmt->execute();
    }
}

$allLinks = [];
$stmt = $mysqli->prepare('SELECT id, category, room_slug, label, url, comment FROM casa_links WHERE house_id = ? ORDER BY sort_order, id');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    if (!isset($casaRooms[$row['room_slug']])) $row['room_slug'] = 'others';
    $allLinks[] = $row;
}

// Grouped by room, in the same fixed order as casa/design/ - only rooms that actually have a
// link show up, same behavior as the old free-text category grouping.
$links = [];
foreach ($casaRooms as $slug => $meta) {
    $roomLinks = array_values(array_filter($allLinks, function ($l) use ($slug) { return $l['room_slug'] === $slug; }));
    if ($roomLinks) $links[$slug] = $roomLinks;
}

function casa_link_display_label(array $link): string
{
    if (!empty($link['label'])) return $link['label'];
    $host = parse_url($link['url'], PHP_URL_HOST);
    return $host ? preg_replace('/^www\./', '', $host) : $link['url'];
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Linkuri utile</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  a { color: var(--accent); text-decoration: none; }

  main { max-width: 1200px; margin: 0 auto; padding: 40px 24px 80px; }

  .cat-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    margin-bottom: 16px;
  }
  .cat-card summary {
    list-style: none;
    cursor: pointer;
    display: flex; align-items: center; justify-content: space-between; gap: 10px;
    padding: 18px 24px;
    font-family: var(--disp); font-weight: 600;
    font-size: 1.1rem;
    color: var(--ink);
    border-radius: 8px;
  }
  .cat-card summary::-webkit-details-marker { display: none; }
  .cat-card summary:hover { background: var(--panel); }
  .cat-card[open] summary { border-radius: 8px 8px 0 0; }
  .cat-card summary::after {
    content: "";
    width: 8px; height: 8px;
    border-right: 2px solid var(--ink-2);
    border-bottom: 2px solid var(--ink-2);
    transform: rotate(-45deg);
    transition: transform 0.2s ease;
    flex-shrink: 0;
  }
  .cat-card[open] summary::after { transform: rotate(45deg); }
  .link-list { padding: 4px 24px 22px; }
  .link-row {
    display: flex; align-items: center; gap: 10px;
    padding: 10px 8px;
    margin: 0 -8px;
    border-radius: 5px;
    border-bottom: 1px solid var(--line-soft);
    transition: background 0.15s ease;
  }
  .link-row:hover { background: rgba(217,164,65,0.06); }
  .link-row:last-of-type { border-bottom: none; }
  .link-row .link-main {
    flex: 1;
    min-width: 0;
  }
  .link-row a.link-open {
    color: var(--ink);
    font-size: 0.95rem;
    display: flex; align-items: baseline; gap: 8px;
    min-width: 0;
  }
  .link-row a.link-open .link-label { font-weight: 600; }
  .link-row a.link-open .link-url {
    color: var(--ink-2);
    font-family: var(--mono);
    font-size: 0.78rem;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .link-row a.link-open:hover .link-label { color: var(--accent); }
  .link-category-tag {
    flex-shrink: 0;
    font-family: var(--mono);
    font-size: 0.68rem;
    color: var(--ink-2);
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 999px;
    padding: 1px 8px;
  }
  .link-comment {
    margin-top: 3px;
    color: var(--ink-2);
    font-size: 0.82rem;
    font-style: italic;
  }

  .edit-btn, .delete-btn {
    background: transparent; border: 1px solid var(--line); color: var(--ink-3);
    width: 27px; height: 27px; border-radius: 5px; cursor: pointer; font-size: 0.9rem;
    display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .edit-btn:hover { border-color: var(--accent); color: var(--accent); }
  .delete-btn:hover { border-color: var(--bad); color: var(--bad); }

  .link-edit-row { display: none; flex-wrap: wrap; gap: 8px; padding: 10px 0; border-bottom: 1px solid var(--line-soft); }
  .link-row.is-editing { display: none; }
  .link-row.is-editing + .link-edit-row { display: flex; }
  .link-edit-row input, .link-edit-row select {
    padding: 8px 10px;
    background: var(--panel); border: 1px solid var(--line-soft); border-radius: 5px;
    color: var(--ink); font-size: 0.88rem; font-family: var(--disp);
  }
  .link-edit-row select[name=edit-room] { width: 150px; }
  .link-edit-row input[name=edit-category] { width: 150px; }
  .link-edit-row input[name=edit-label] { width: 150px; }
  .link-edit-row input[name=edit-url] { flex: 1; min-width: 200px; font-family: var(--mono); }
  .link-edit-row input[name=edit-comment] { flex-basis: 100%; }
  .link-edit-row input:focus, .link-edit-row select:focus { outline: none; border-color: var(--accent); }
  .link-edit-row button {
    padding: 8px 16px; border-radius: 5px; cursor: pointer; border: none;
    font-family: var(--disp); font-weight: 600; font-size: 0.8rem;
  }
  .link-edit-row .save-btn { background: var(--accent); color: var(--on-accent); }
  .link-edit-row .cancel-btn { background: transparent; border: 1px solid var(--line); color: var(--ink-2); }

  .empty-state {
    text-align: center; color: var(--ink-2); font-family: var(--mono); font-size: 0.85rem;
    padding: 30px 20px; border: 1px dashed var(--line); border-radius: 4px; margin-bottom: 24px;
  }

  .add-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 22px 24px;
    margin-bottom: 32px;
  }
  .add-card h2 {
    margin: 0 0 14px;
    font-family: var(--disp); font-weight: 600;
    font-size: 1.1rem; color: var(--ink);
  }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input[type=text], .add-row input[type=url], .add-row select {
    padding: 10px 14px;
    background: var(--panel); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-size: 0.95rem; font-family: var(--disp);
  }
  .add-row select[name=room] { width: 170px; }
  .add-row input[name=category] { width: 200px; }
  .add-row input[name=label] { width: 200px; }
  .add-row input[name=url] { flex: 1; min-width: 220px; font-family: var(--mono); }
  .add-row input[name=comment] { flex-basis: 100%; }
  .add-row input:focus, .add-row select:focus { outline: none; border-color: var(--accent); }
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
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span><?= htmlspecialchars($currentHouse['name']) ?></span></div>
    <nav id="heroNav">
      <a href="/progres.php">Construcție</a>
      <a href="/design/">Design</a>
      <a href="/links.php" class="is-current">Link-uri</a>
      <a href="/jurnal.php">Jurnal</a>
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

  <div class="add-card">
    <h2>Adaugă link</h2>
    <div class="add-row">
      <select name="room" id="newLinkRoom">
        <?php foreach ($casaRooms as $slug => $meta): ?>
          <option value="<?= htmlspecialchars($slug) ?>" <?= $slug === 'others' ? 'selected' : '' ?>><?= htmlspecialchars($meta['icon']) ?> <?= htmlspecialchars($meta['name']) ?></option>
        <?php endforeach; ?>
      </select>
      <input type="text" name="category" id="newLinkCategory" placeholder="Categorie (opțional)">
      <input type="text" name="label" id="newLinkLabel" placeholder="Etichetă (opțional)">
      <input type="url" name="url" id="newLinkUrl" placeholder="https://...">
      <input type="text" name="comment" id="newLinkComment" maxlength="256" placeholder="Comentariu (opțional, max 256 caractere)">
      <button id="addLinkBtn">Adaugă</button>
    </div>
  </div>

  <?php if (empty($links)): ?>
    <div class="empty-state">Niciun link salvat încă. Adaugă primul mai sus.</div>
  <?php else: ?>
    <?php foreach ($links as $roomSlug => $roomLinks): ?>
      <details class="cat-card">
        <summary><span><?= htmlspecialchars($casaRooms[$roomSlug]['icon']) ?> <?= htmlspecialchars($casaRooms[$roomSlug]['name']) ?></span></summary>
        <div class="link-list" data-room="<?= htmlspecialchars($roomSlug) ?>">
          <?php foreach ($roomLinks as $link): ?>
            <div class="link-row" data-id="<?= (int)$link['id'] ?>">
              <div class="link-main">
                <a class="link-open" href="<?= htmlspecialchars($link['url']) ?>" target="_blank" rel="noopener noreferrer">
                  <span class="link-label"><?= htmlspecialchars(casa_link_display_label($link)) ?></span>
                  <span class="link-url"><?= htmlspecialchars($link['url']) ?></span>
                  <?php if (!empty($link['category'])): ?>
                    <span class="link-category-tag"><?= htmlspecialchars($link['category']) ?></span>
                  <?php endif; ?>
                </a>
                <?php if (!empty($link['comment'])): ?>
                  <div class="link-comment"><?= htmlspecialchars($link['comment']) ?></div>
                <?php endif; ?>
              </div>
              <button class="edit-btn" title="Editează">✎</button>
              <button class="delete-btn" title="Șterge">✕</button>
            </div>
            <div class="link-edit-row">
              <select name="edit-room">
                <?php foreach ($casaRooms as $slug => $meta): ?>
                  <option value="<?= htmlspecialchars($slug) ?>" <?= $slug === $roomSlug ? 'selected' : '' ?>><?= htmlspecialchars($meta['icon']) ?> <?= htmlspecialchars($meta['name']) ?></option>
                <?php endforeach; ?>
              </select>
              <input type="text" name="edit-category" value="<?= htmlspecialchars($link['category'] ?? '') ?>" placeholder="Categorie (opțional)">
              <input type="text" name="edit-label" value="<?= htmlspecialchars($link['label'] ?? '') ?>" placeholder="Etichetă (opțional)">
              <input type="url" name="edit-url" value="<?= htmlspecialchars($link['url']) ?>" placeholder="https://...">
              <input type="text" name="edit-comment" value="<?= htmlspecialchars($link['comment'] ?? '') ?>" maxlength="256" placeholder="Comentariu (opțional, max 256 caractere)">
              <button type="button" class="save-btn">Salvează</button>
              <button type="button" class="cancel-btn">Anulează</button>
            </div>
          <?php endforeach; ?>
        </div>
      </details>
    <?php endforeach; ?>
  <?php endif; ?>

</main>

<?php casa_render_footer(); ?>

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
  var addBtn = document.getElementById('addLinkBtn');
  var roomInput = document.getElementById('newLinkRoom');
  var categoryInput = document.getElementById('newLinkCategory');
  var labelInput = document.getElementById('newLinkLabel');
  var urlInput = document.getElementById('newLinkUrl');
  var commentInput = document.getElementById('newLinkComment');

  document.querySelectorAll('.delete-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var row = btn.closest('.link-row');
      var editRow = row.nextElementSibling;
      if (!confirm('Ștergi acest link?')) return;
      var id = row.getAttribute('data-id');
      fetch('links_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        var list = row.parentElement;
        row.remove();
        if (editRow && editRow.classList.contains('link-edit-row')) editRow.remove();
        if (!list.querySelector('.link-row')) {
          list.closest('.cat-card').remove();
        }
      }).catch(function() {
        alert('Nu s-a putut șterge linkul. Încearcă din nou.');
      });
    });
  });

  document.querySelectorAll('.edit-btn').forEach(function(btn) {
    btn.addEventListener('click', function() {
      var row = btn.closest('.link-row');
      row.classList.add('is-editing');
    });
  });

  document.querySelectorAll('.link-edit-row').forEach(function(editRow) {
    var row = editRow.previousElementSibling;
    var id = row.getAttribute('data-id');

    editRow.querySelector('.cancel-btn').addEventListener('click', function() {
      row.classList.remove('is-editing');
    });

    editRow.querySelector('.save-btn').addEventListener('click', function() {
      var room = editRow.querySelector('[name=edit-room]').value;
      var category = editRow.querySelector('[name=edit-category]').value.trim();
      var label = editRow.querySelector('[name=edit-label]').value.trim();
      var url = editRow.querySelector('[name=edit-url]').value.trim();
      var comment = editRow.querySelector('[name=edit-comment]').value.trim();
      if (!url) {
        alert('Completează cel puțin URL-ul.');
        return;
      }
      if (!/^https?:\/\//i.test(url)) url = 'https://' + url;

      fetch('links_update.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: id, room: room, category: category, label: label, url: url, comment: comment }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('update failed');
        location.reload();
      }).catch(function() {
        alert('Nu s-a putut salva modificarea. Verifică URL-ul și încearcă din nou.');
      });
    });
  });

  addBtn.addEventListener('click', function() {
    var room = roomInput.value;
    var category = categoryInput.value.trim();
    var label = labelInput.value.trim();
    var url = urlInput.value.trim();
    var comment = commentInput.value.trim();
    if (!url) {
      alert('Completează cel puțin URL-ul.');
      return;
    }
    if (!/^https?:\/\//i.test(url)) url = 'https://' + url;

    fetch('links_add.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ room: room, category: category, label: label, url: url, comment: comment }).toString()
    }).then(function(res) { return res.json(); }).then(function(data) {
      if (!data.ok) throw new Error('add failed');
      location.reload();
    }).catch(function() {
      alert('Nu s-a putut adăuga linkul. Verifică URL-ul și încearcă din nou.');
    });
  });

  [categoryInput, labelInput, urlInput, commentInput].forEach(function(input) {
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') addBtn.click();
    });
  });
})();
</script>

</body>
</html>
