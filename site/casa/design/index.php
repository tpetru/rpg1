<?php
require_once __DIR__ . '/../_auth.php';
// Personal page - design interior for our own house. Scans subdirectories of this folder;
// each subdirectory is a "room" (nume_camera) and its images are shown in that room's gallery.
// Add a room by creating /design/<nume_camera>/ and dropping photos inside - no code change needed.

require_once __DIR__ . '/checklist_defs.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_house_auth($mysqli);
$houseId = $currentHouse['id'];

// Every house has one password now (no more owner/guest split) - everyone who gets in sees everything.
$isOwner = true;
require_once __DIR__ . '/../stage_defs.php';
$stageTagText = casa_current_stage_tag($mysqli, $houseId, $stageLabels, $stageCount);

casa_design_checklist_ensure_schema($mysqli, $casaChecklistDefs);
$checklistItemsLookup = casa_design_checklist_items($mysqli, $houseId);

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_notes (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        note VARCHAR(500) NOT NULL,
        author VARCHAR(60) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY room_slug (room_slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query('ALTER TABLE casa_design_notes ADD COLUMN IF NOT EXISTS author VARCHAR(60) NULL AFTER note');

$notesLookup = [];
$stmt = $mysqli->prepare('SELECT id, room_slug, note, author, created_at FROM casa_design_notes WHERE house_id = ? ORDER BY created_at DESC, id DESC');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$notesResult = $stmt->get_result();
while ($row = $notesResult->fetch_assoc()) {
    $notesLookup[$row['room_slug']][] = [
        'id' => (int)$row['id'],
        'note' => $row['note'],
        'author' => $row['author'] !== null && $row['author'] !== '' ? $row['author'] : 'Anonim',
        'date' => date('d.m.Y H:i', strtotime($row['created_at'])),
        'dateShort' => date('d.m', strtotime($row['created_at'])),
    ];
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_photo_ratings (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        ip VARCHAR(45) NOT NULL,
        rating TINYINT UNSIGNED NOT NULL DEFAULT 0,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY room_filename_ip (room_slug, filename, ip)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

// Ratings are personal per visitor (identified by IP), not shared/global - each IP only ever
// sees and edits its own rating for a given photo.
$viewerIp = $_SERVER['REMOTE_ADDR'] ?? '';
$ratingLookup = [];
$ratingStmt = $mysqli->prepare('SELECT room_slug, filename, rating FROM casa_design_photo_ratings WHERE ip = ? AND house_id = ?');
$ratingStmt->bind_param('si', $viewerIp, $houseId);
$ratingStmt->execute();
$ratingResult = $ratingStmt->get_result();
while ($row = $ratingResult->fetch_assoc()) {
    $ratingLookup[$row['room_slug']][$row['filename']] = (int)$row['rating'];
}

// Aggregate across every visitor's rating, for the "2.4/5 (99)" line shown next to the stars.
$ratingStatsLookup = [];
$stmt = $mysqli->prepare('SELECT room_slug, filename, AVG(rating) AS avg_rating, COUNT(*) AS vote_count FROM casa_design_photo_ratings WHERE house_id = ? GROUP BY room_slug, filename');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$statsResult = $stmt->get_result();
while ($row = $statsResult->fetch_assoc()) {
    $ratingStatsLookup[$row['room_slug']][$row['filename']] = [
        'avg' => (float)$row['avg_rating'],
        'count' => (int)$row['vote_count'],
    ];
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_photo_meta (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        uploader VARCHAR(60) NULL,
        uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY room_filename (room_slug, filename)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

$uploaderLookup = [];
$stmt = $mysqli->prepare('SELECT room_slug, filename, uploader FROM casa_design_photo_meta WHERE house_id = ?');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$uploaderResult = $stmt->get_result();
while ($row = $uploaderResult->fetch_assoc()) {
    $uploaderLookup[$row['room_slug']][$row['filename']] = $row['uploader'];
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_photo_winners (
        room_slug VARCHAR(64) NOT NULL,
        filename VARCHAR(255) NOT NULL,
        crowned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (room_slug, filename)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);

// Shared/global flag (unlike the personal per-IP rating) - the crown marks THE winning photo,
// the same for every visitor, not a personal favorite.
$winnerLookup = [];
$stmt = $mysqli->prepare('SELECT room_slug, filename FROM casa_design_photo_winners WHERE house_id = ?');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$winnerResult = $stmt->get_result();
while ($row = $winnerResult->fetch_assoc()) {
    $winnerLookup[$row['room_slug']][$row['filename']] = true;
}

$mysqli->query(
    'CREATE TABLE IF NOT EXISTS casa_design_colors (
        room_slug VARCHAR(64) NOT NULL,
        colors TEXT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (room_slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
);
$mysqli->query('ALTER TABLE casa_design_colors MODIFY COLUMN colors TEXT NOT NULL');

// Each room's colors are stored as a JSON array of {id, hex, label} chips. A value that isn't
// valid JSON is a leftover from the plain-text version of this field - kept as a single chip
// (with the theme's accent as a placeholder swatch) so nothing typed there gets lost.
function casa_parse_room_colors(?string $raw): array
{
    $raw = (string)($raw ?? '');
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        $out = [];
        foreach ($decoded as $entry) {
            if (!is_array($entry) || empty($entry['label'])) continue;
            $hex = $entry['hex'] ?? '';
            $out[] = [
                'id' => (string)($entry['id'] ?? uniqid('c')),
                'hex' => preg_match('/^#[0-9a-f]{6}$/i', $hex) ? $hex : '#d9a441',
                'label' => (string)$entry['label'],
            ];
        }
        return $out;
    }
    $raw = trim($raw);
    if ($raw === '') return [];
    return [['id' => 'legacy', 'hex' => '#d9a441', 'label' => $raw]];
}

$colorsLookup = [];
$stmt = $mysqli->prepare('SELECT room_slug, colors FROM casa_design_colors WHERE house_id = ?');
$stmt->bind_param('i', $houseId);
$stmt->execute();
$colorsResult = $stmt->get_result();
while ($row = $colorsResult->fetch_assoc()) {
    $colorsLookup[$row['room_slug']] = casa_parse_room_colors($row['colors']);
}

// Shopping tab: products tracked on shopping.php, grouped by the same room slug, with their latest
// successful price (per m2 when the shop sells by the box - see _price_check.php) and a quantity.
$mysqli->query('ALTER TABLE casa_price_products ADD COLUMN IF NOT EXISTS quantity DECIMAL(10,2) NOT NULL DEFAULT 1');
$mysqli->query('ALTER TABLE casa_price_history ADD COLUMN IF NOT EXISTS unit_price DECIMAL(10,2) NULL AFTER currency');
$shoppingLookup = [];
$stmt = $mysqli->prepare(
    'SELECT p.id, p.name, p.url, p.room_slug, p.quantity,
        (SELECT h.price FROM casa_price_history h WHERE h.product_id = p.id AND h.ok = 1 ORDER BY h.checked_at DESC, h.id DESC LIMIT 1) AS price,
        (SELECT h.unit_price FROM casa_price_history h WHERE h.product_id = p.id AND h.ok = 1 ORDER BY h.checked_at DESC, h.id DESC LIMIT 1) AS unit_price
     FROM casa_price_products p WHERE p.house_id = ? ORDER BY p.sort_order, p.id'
);
$stmt->bind_param('i', $houseId);
$stmt->execute();
$shoppingResult = $stmt->get_result();
while ($row = $shoppingResult->fetch_assoc()) {
    $shoppingLookup[$row['room_slug']][] = $row;
}

$baseDir = casa_house_dir($currentHouse['slug']) . '/design';
casa_make_dir($baseDir);
$imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

// Custom display names set from the room's rename button (see room_rename.php) - take priority
// over both the hardcoded overrides above and the auto-derived title-cased folder name.
$roomMeta = casa_design_room_meta($mysqli, $houseId);

$rooms = [];
foreach (scandir($baseDir) as $entry) {
    if ($entry === '.' || $entry === '..') continue;
    $fullPath = $baseDir . '/' . $entry;
    if (!is_dir($fullPath)) continue;

    $imageFiles = [];
    foreach (scandir($fullPath) as $file) {
        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        if (in_array($ext, $imageExtensions, true)) {
            $imageFiles[] = $file;
        }
    }
    sort($imageFiles, SORT_NATURAL | SORT_FLAG_CASE);

    $images = [];
    foreach ($imageFiles as $file) {
        $rating = $ratingLookup[$entry][$file] ?? 0;
        $stats = $ratingStatsLookup[$entry][$file] ?? ['avg' => 0, 'count' => 0];
        $uploader = $uploaderLookup[$entry][$file] ?? null;
        $images[] = [
            'filename' => $file,
            'href' => '/' . rawurlencode($currentHouse['slug']) . '/design/' . $entry . '/' . rawurlencode($file),
            'rating' => $rating,
            'avg' => $stats['avg'],
            'voteCount' => $stats['count'],
            'uploader' => $uploader,
            'isWinner' => isset($winnerLookup[$entry][$file]),
        ];
    }
    // Winning photos (crowned) sort first; usort is stable in PHP 8+ so ties keep their filename order.
    usort($images, function ($a, $b) { return $b['isWinner'] <=> $a['isWinner']; });

    $rooms[] = ['slug' => $entry, 'name' => casa_design_room_name($entry, $roomMeta), 'images' => $images];
}
// Ordinea implicita a camerelor, sau cea pusa de tine din sagetile de mutare - vezi _house.php.
$rooms = casa_design_sort_rooms($rooms, $roomMeta);

// Short codes for the floating nav buttons, so each room reads at a glance instead of showing an
// identical door icon for every one of them.
$roomLetterCodes = [
    'living' => 'L',
    'bucatarie' => 'B',
    'dormitor_matrimonial' => 'D1',
    'dormitor2' => 'D2',
    'dormitor3' => 'D3',
    'baie_dus' => 'Bd',
    'baie_cada' => 'Bc',
    'hol' => 'H',
    'terasa' => 'T',
    'exterior' => 'Ex',
    'others' => 'O',
];
function casa_room_letter_code(string $slug, array $roomLetterCodes): string
{
    if (isset($roomLetterCodes[$slug])) return $roomLetterCodes[$slug];
    return mb_strtoupper(mb_substr($slug, 0, 1));
}

// Small glyph per room, purely decorative - gives each title bar an identity beyond text alone.
$roomIcons = [
    'living' => '🛋️',
    'bucatarie' => '🍳',
    'dormitor_matrimonial' => '🛏️',
    'dormitor2' => '🛏️',
    'dormitor3' => '🛏️',
    'baie_dus' => '🚿',
    'baie_cada' => '🛁',
    'hol' => '🚪',
    'terasa' => '🌿',
    'exterior' => '🏡',
    'others' => '✨',
];
function casa_room_icon(string $slug, array $roomIcons): string
{
    return $roomIcons[$slug] ?? '🏠';
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Design interior</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/../assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  a { color: var(--accent); text-decoration: none; }

  main { max-width: 1200px; margin: 0 auto; padding: 40px 24px 80px; }

  .room-nav {
    display: flex; flex-direction: column; gap: 10px;
    margin-bottom: 48px;
  }
  .room-nav-row {
    display: flex; flex-wrap: wrap; gap: 10px; justify-content: center;
  }
  .room-nav a {
    display: inline-flex; align-items: center;
    padding: 6px 13px;
    border: none;
    border-radius: 14px;
    background: transparent;
    color: var(--ink-2);
    font-family: var(--disp);
    font-weight: 500;
    font-size: 0.82rem;
    line-height: 1.2;
    white-space: nowrap;
    transition: color 0.2s ease, background 0.2s ease;
  }
  .room-nav a:hover { color: var(--ink); }
  .room-nav a.is-active {
    background: rgba(240,236,228,.08);
    color: var(--ink);
  }

  .room-add-form {
    display: flex; justify-content: center; gap: 8px;
    margin: -30px 0 48px;
  }
  .room-add-form input {
    width: 160px;
    padding: 7px 13px;
    border: 1px dashed var(--line);
    border-radius: 14px;
    background: transparent;
    color: var(--ink);
    font-family: var(--disp);
    font-size: 0.8rem;
    text-align: center;
  }
  .room-add-form input:focus { outline: none; border-color: var(--accent); border-style: solid; }
  .room-add-form input::placeholder { color: var(--ink-3); }
  .room-add-form button {
    padding: 7px 16px;
    border: none;
    border-radius: 14px;
    background: var(--accent);
    color: var(--on-accent);
    font-family: var(--disp);
    font-weight: 600;
    font-size: 0.78rem;
    cursor: pointer;
  }

  /* Meniu plutitor cu camerele, in dreapta - acelasi tipar ca .section-nav de pe site-ul RPG */
  .room-floating-nav {
    position: fixed;
    top: 50%;
    right: 18px;
    transform: translateY(-50%);
    display: flex;
    flex-direction: column;
    gap: 6px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 10px 7px;
    z-index: 150;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .room-floating-nav a {
    position: relative;
    display: flex; align-items: center; justify-content: center;
    width: 36px; height: 36px;
    border-radius: 9px;
    font-family: var(--disp);
    font-weight: 700;
    letter-spacing: 0.2px;
    font-size: 0.85rem;
    text-decoration: none;
    color: var(--ink);
    transition: background 0.15s ease, transform 0.15s ease;
  }
  .room-floating-nav a:hover { background: var(--panel); }
  .room-floating-nav a.is-active { background: var(--accent); color: var(--on-accent); }
  .room-floating-nav a.is-active:hover { background: var(--accent); }
  .room-floating-nav a:hover::after {
    content: attr(title);
    position: absolute;
    right: 46px;
    background: var(--panel);
    border: 1px solid var(--line);
    color: var(--ink);
    font-size: 0.78rem;
    padding: 4px 8px;
    border-radius: 6px;
    white-space: nowrap;
    pointer-events: none;
  }
  @media (max-width: 1100px) {
    .room-floating-nav { display: none; } /* nu mai e loc langa continut */
  }

  /* Burger cu camerele, pentru ecrane inguste unde meniul plutitor lateral nu incape */
  .room-burger-btn {
    display: none;
    position: fixed; right: 16px; bottom: 16px;
    z-index: 160;
    width: 52px; height: 52px;
    align-items: center; justify-content: center;
    flex-direction: column; gap: 5px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    cursor: pointer;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .room-burger-btn span { display: block; width: 22px; height: 2px; background: var(--accent); border-radius: 2px; transition: transform 0.25s ease, opacity 0.2s ease; }
  .room-burger-btn.is-open span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
  .room-burger-btn.is-open span:nth-child(2) { opacity: 0; }
  .room-burger-btn.is-open span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }

  .room-burger-panel {
    display: none;
    position: fixed;
    right: 16px;
    bottom: 80px;
    z-index: 155;
    width: 230px;
    max-width: calc(100vw - 32px);
    max-height: 65vh;
    overflow-y: auto;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 14px;
    padding: 12px;
    box-shadow: 0 14px 34px rgba(0,0,0,0.5);
  }
  .room-burger-panel.is-open { display: block; }
  .room-burger-panel .burger-title {
    text-align: center;
    font-weight: 600;
    font-size: 0.72rem;
    color: var(--accent);
    margin: 2px 0 10px;
  }
  .room-burger-panel .burger-links {
    display: flex; flex-direction: column; gap: 6px;
  }
  .room-burger-panel .burger-links a {
    display: flex; align-items: center; gap: 10px;
    padding: 9px 10px;
    border: 1px solid var(--line-soft);
    border-radius: 8px;
    background: var(--panel);
    color: var(--ink);
    font-weight: 500;
    font-size: 0.76rem;
    text-align: left;
  }
  .room-burger-panel .burger-links a .room-nav-icon {
    flex-shrink: 0;
    width: 20px;
    text-align: center;
    font-size: 1.05rem;
  }
  .room-burger-panel .burger-links a.is-active {
    background: var(--accent);
    border-color: var(--accent);
    color: var(--on-accent);
  }

  @media (max-width: 1100px) {
    .room-burger-btn { display: flex; }
    .room-nav { display: none; } /* inlocuit de burger pe ecrane mici */
  }

  section.room { margin-bottom: 64px; scroll-margin-top: 20px; }
  .room-heading {
    display: flex;
    align-items: baseline;
    gap: 16px;
    margin: 0 0 12px;
  }
  section.room h2 {
    flex-shrink: 0;
    font-family: var(--disp);
    font-weight: 600;
    font-size: 1.75rem;
    letter-spacing: -0.03em;
    margin: 0;
    color: var(--ink);
  }
  .room-title-text { min-width: 0; }
  .room-title-input {
    min-width: 0; flex: 1 1 auto; max-width: 320px;
    font-family: var(--disp); font-weight: 600; font-size: 1.4rem; letter-spacing: -0.02em;
    background: transparent; border: none; border-bottom: 1px dashed var(--accent);
    color: var(--ink); padding: 0 0 2px;
  }
  .room-title-input:focus { outline: none; }
  .room-title-input[hidden] { display: none; }
  .room-move-btn:hover:not(:disabled) { border-color: var(--accent); color: var(--accent); }
  .room-move-btn:disabled { opacity: 0.3; cursor: default; }
  .room-rename-btn, .room-delete-btn, .room-move-btn, .room-title-save-btn, .room-title-cancel-btn {
    flex-shrink: 0;
    width: 26px; height: 26px;
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink-3); cursor: pointer; font-size: 0.8rem;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .room-rename-btn:hover, .room-title-save-btn:hover { border-color: var(--accent); color: var(--accent); }
  .room-delete-btn:hover { border-color: var(--bad); color: var(--bad); }
  .room-title-save-btn[hidden], .room-title-cancel-btn[hidden] { display: none; }
  .room-rename-btn[hidden], .room-delete-btn[hidden] { display: none; }
  .room-title-text[hidden] { display: none; }
  /* Shared: isolates an emoji into its own tight, centered box so its font's odd internal vertical
     metrics can't throw off alignment next to regular text/numbers sharing the same line. */
  .chip-icon { display: inline-flex; align-items: center; line-height: 1; font-size: 0.85rem; }
  .room-title-status {
    flex-shrink: 0;
    font-size: 0.78rem;
    color: var(--ink-2);
  }
  .room-title-status strong {
    font-family: var(--mono);
    font-weight: 500;
    color: var(--accent);
  }
  .room-heading-spacer { flex: 1 1 auto; }
  .room-title-index {
    flex-shrink: 0;
    font-family: var(--mono);
    font-weight: 400;
    letter-spacing: 0.5px;
    font-size: 0.72rem;
    color: var(--ink-3);
  }
  @media (max-width: 640px) {
    section.room h2 { font-size: 1.35rem; }
    .room-title-index { display: none; }
  }
  section.room .count { color: var(--ink-2); font-family: var(--mono); font-size: 0.8rem; margin: 0 0 18px; }

  .room-body {
    width: 100%;
    min-width: 0;
  }
  @media (max-width: 640px) {
    /* On mobile the rooms are one long scroll, and the big desktop title banner is the only thing
       that tells you which room you're in. Pin it right under the site header while you scroll
       through that room's open tab, so switching rooms - or just losing track after a long
       scroll - stays obvious, the way the desktop layout already makes obvious for free. */
    .room-heading {
      position: sticky;
      top: var(--header-h, 64px);
      z-index: 20;
      background: var(--bg);
      padding: 10px 0;
    }
  }

  /* Tabs replace the old stacked spoilers (Checklist/Notite/Culori/Poze) - one segmented-control
     style track to switch between, one panel visible at a time, instead of 4 separate collapsible
     boxes. A single scrollable row (never wraps) so it stays clean on narrow/mobile screens too. */
  .room-tabs {
    display: flex;
    flex-wrap: nowrap;
    gap: 3px;
    margin-bottom: 16px;
    padding: 4px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 12px;
    overflow-x: auto;
    scrollbar-width: none;
  }
  .room-tabs::-webkit-scrollbar { display: none; }
  .room-tab-btn {
    display: inline-flex; align-items: center; gap: 6px;
    flex-shrink: 0;
    padding: 8px 14px;
    border: none;
    border-radius: 9px;
    background: transparent;
    color: var(--ink-2);
    font-weight: 600;
    letter-spacing: 0.2px;
    font-size: 0.8rem;
    white-space: nowrap;
    cursor: pointer;
    transition: color 0.2s ease, background 0.2s ease, box-shadow 0.2s ease;
  }
  .room-tab-btn:hover { color: var(--ink); background: rgba(255,255,255,0.04); }
  .room-tab-btn.is-active {
    background: var(--accent);
    color: var(--on-accent);
  }
  .room-tab-btn.is-active:hover { background: var(--accent); }
  /* Icon/label/badge are each their own tight flex item (line-height:1, no inherited leading) so
     emoji - whose fonts often have odd internal vertical metrics - can't throw off the centering
     the way it would sharing a line box with regular text. The icon also gets a fixed width, so
     the label starts at the same visual offset in every tab regardless of how wide that emoji's
     own glyph happens to be - the kind of alignment that matters once you look for it. */
  .room-tab-btn .tab-label,
  .room-tab-btn .tab-badge {
    display: inline-flex;
    align-items: center;
    line-height: 1;
  }
  .room-tab-btn .tab-label { margin-right: 1px; }
  .room-tab-btn .tab-badge {
    justify-content: center;
    min-width: 15px;
    font-family: var(--mono);
    font-variant-numeric: tabular-nums;
    font-weight: 500;
    font-size: 0.7rem;
    color: var(--ink-3);
    background: rgba(240,236,228,.08);
    border-radius: 999px;
    padding: 3px 6px;
  }
  .room-tab-btn.is-active .tab-badge { color: var(--on-accent); background: rgba(23,20,13,0.18); }

  .room-tab-panel {
    margin-bottom: 24px;
  }

  .notes-list { display: flex; flex-direction: column; margin-bottom: 14px; }
  .note-item {
    display: grid;
    grid-template-columns: 58px minmax(0, 1fr);
    gap: 16px;
    padding: 14px 0;
    border-bottom: 1px solid var(--line-soft);
  }
  .note-date-col {
    font-family: var(--mono);
    font-weight: 500;
    font-size: 0.7rem;
    color: var(--ink-3);
    padding-top: 2px;
  }
  .note-body { min-width: 0; }
  .note-text { font-size: 0.88rem; color: var(--ink); white-space: pre-wrap; word-break: break-word; }
  .note-meta { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 7px; }
  .note-date { font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); }
  .note-author { font-weight: inherit; color: inherit; }
  .note-actions { display: flex; gap: 8px; }
  .note-edit-btn, .note-delete-btn {
    flex-shrink: 0;
    background: transparent; border: none; color: var(--ink-3);
    cursor: pointer; font-size: 0.75rem;
    display: inline-flex; align-items: center; justify-content: center;
    transition: color 0.2s ease;
  }
  .note-edit-btn:hover { color: var(--accent); }
  .note-delete-btn:hover { color: var(--bad); }
  .note-edit-row { display: none; flex-direction: column; gap: 6px; margin-top: 8px; }
  .note-item.is-editing .note-text,
  .note-item.is-editing .note-meta { display: none; }
  .note-item.is-editing .note-edit-row { display: flex; }
  .note-edit-input {
    width: 100%; min-height: 60px; resize: vertical;
    padding: 8px 10px;
    background: var(--panel); border: 1px solid var(--accent); border-radius: 4px;
    color: var(--ink); font-family: inherit; font-size: 0.85rem;
  }
  .note-edit-input:focus { outline: none; }
  .note-edit-actions { display: flex; gap: 6px; }
  .note-edit-save-btn, .note-edit-cancel-btn {
    padding: 6px 14px; border-radius: 3px; cursor: pointer;
    font-weight: 700; font-size: 0.72rem; text-transform: uppercase;
  }
  .note-edit-save-btn { background: var(--accent); border: none; color: var(--on-accent); }
  .note-edit-save-btn:hover { background: #c6923a; }
  .note-edit-cancel-btn { background: transparent; border: 1px solid var(--line-soft); color: var(--ink-2); }
  .notes-empty {
    color: var(--ink-2); font-family: var(--mono); font-size: 0.8rem;
    margin: 0 0 14px;
  }
  .note-add-row {
    display: flex; flex-direction: column; gap: 12px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 7px;
    padding: 11px 13px;
    transition: border-color 0.2s ease;
  }
  .note-add-row:focus-within { border-color: var(--accent); }
  .note-input {
    width: 100%; min-height: 60px; resize: vertical;
    padding: 0;
    background: transparent; border: none;
    color: var(--ink); font-family: inherit; font-size: 0.88rem;
  }
  .note-input:focus { outline: none; }
  .note-add-footer { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .note-charcount { font-family: var(--mono); font-size: 0.7rem; color: var(--ink-3); }
  .note-charcount.is-over { color: var(--bad); }
  .note-add-btn {
    flex-shrink: 0;
    padding: 8px 18px;
    background: var(--accent);
    border: none;
    border-radius: 6px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600;
    font-size: 0.78rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .note-add-btn:hover { background: #c6923a; }
  .note-add-btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .checklist {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 14px;
    margin-bottom: 8px;
  }
  @media (max-width: 820px) {
    .checklist { grid-template-columns: repeat(2, 1fr); }
  }
  @media (max-width: 480px) {
    .checklist { grid-template-columns: 1fr; }
  }
  .checklist-cat {
    display: flex; flex-direction: column;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 16px 18px;
  }

  .cat-header {
    display: flex; align-items: center; justify-content: space-between;
    gap: 8px;
    margin-bottom: 8px;
  }
  .cat-header h4 {
    margin: 0;
    font-family: var(--disp); font-weight: 600;
    font-size: 0.9rem;
    color: var(--ink);
  }
  .cat-badge {
    flex-shrink: 0;
    padding: 2px 9px;
    border-radius: 999px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    color: var(--ink-2);
    font-family: var(--mono); font-weight: 400; font-size: 0.7rem;
  }
  .cat-badge.is-complete {
    color: var(--on-accent);
    border-color: var(--good);
    background: var(--good);
  }

  .cat-cost-summary {
    display: flex; justify-content: space-between; gap: 10px;
    margin-bottom: 8px;
    font-family: var(--mono); font-size: 0.7rem; color: var(--ink-2);
  }

  .cat-progress {
    height: 4px;
    border-radius: 2px;
    background: var(--panel);
    overflow: hidden;
    margin-bottom: 14px;
  }
  .cat-progress-bar {
    height: 100%;
    background: var(--accent);
    transition: width 0.3s ease;
  }

  .item-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 10px; }
  .checklist-item {
    border: 1px solid var(--line-soft);
    border-radius: 6px;
    padding: 8px 10px;
  }
  .item-head { display: flex; align-items: center; gap: 6px; margin-bottom: 6px; }
  .item-name { flex: 1; min-width: 0; font-family: var(--disp); font-weight: 600; font-size: 0.83rem; color: var(--ink); overflow-wrap: anywhere; }
  .item-edit-btn {
    flex-shrink: 0;
    width: 20px; height: 20px;
    display: flex; align-items: center; justify-content: center;
    border: none; border-radius: 50%;
    background: transparent;
    color: var(--ink-2);
    font-size: 0.78rem;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .item-edit-btn:hover { border-color: var(--accent); color: var(--accent); background: rgba(217,164,65,0.12); }
  .item-flags { display: flex; gap: 12px; margin-bottom: 4px; }
  .item-flag {
    display: inline-flex; align-items: center;
    font-size: 0.78rem;
    color: var(--ink-3);
    position: relative;
    padding-left: 16px;
    cursor: pointer;
    user-select: none;
  }
  .item-flag input[type=checkbox] {
    position: absolute; width: 1px; height: 1px; margin: -1px; padding: 0;
    overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; border: 0;
  }
  .item-flag::before {
    content: '';
    position: absolute; left: 0; top: 50%; transform: translateY(-50%);
    width: 10px; height: 10px;
    border-radius: 50%;
    border: 1px solid var(--line);
    transition: background 0.15s ease, border-color 0.15s ease;
  }
  .item-flag:hover::before { border-color: var(--accent); }
  .item-flag.is-done { color: var(--ink); }
  .item-flag.is-done::before { background: var(--accent); border-color: var(--accent); }
  .item-cost-summary {
    display: flex; gap: 14px;
    font-family: var(--mono); font-size: 0.72rem; color: var(--ink-2);
  }
  .item-add-btn {
    align-self: flex-start;
    padding: 6px 14px;
    border: 1px dashed var(--line);
    border-radius: 12px;
    background: transparent;
    color: var(--ink-2);
    font-family: var(--disp);
    font-weight: 500;
    font-size: 0.78rem;
    cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .item-add-btn:hover { border-color: var(--accent); color: var(--accent); border-style: solid; }

  .item-modal-backdrop {
    position: fixed; inset: 0; z-index: 600;
    background: rgba(0,0,0,0.55);
    display: flex; align-items: center; justify-content: center;
    padding: 20px;
  }
  .item-modal-backdrop[hidden] { display: none; }
  .item-modal {
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--accent);
    border-radius: 10px;
    padding: 22px 24px;
    max-width: 380px; width: 100%;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .item-modal h2 { margin: 0 0 16px; font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--ink); }
  .item-modal-field { display: flex; flex-direction: column; gap: 5px; margin-bottom: 14px; }
  .item-modal-field span { font-family: var(--mono); font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.5px; color: var(--ink-2); }
  .item-modal-field input {
    padding: 9px 11px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-family: var(--disp); font-size: 0.9rem;
  }
  .item-modal-field input:focus { outline: none; border-color: var(--accent); }
  .item-modal-steps { display: flex; gap: 18px; margin-bottom: 14px; }
  .item-modal .cat-prices { margin-top: 0; padding-top: 0; border-top: none; margin-bottom: 4px; }
  .item-modal-actions { display: flex; align-items: center; gap: 10px; margin-top: 18px; }
  .item-modal-spacer { flex: 1; }
  .item-modal-actions button {
    padding: 8px 18px; border: none; border-radius: 6px;
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem; cursor: pointer;
  }
  .item-modal-save { background: var(--accent); color: var(--on-accent); }
  .item-modal-cancel { background: transparent; border: 1px solid var(--line) !important; color: var(--ink-2); }
  .item-modal-delete { background: transparent; border: 1px solid var(--bad) !important; color: var(--bad); }
  .item-modal-delete[hidden] { display: none; }

  .cat-steps {
    display: flex; flex-direction: column; gap: 1px;
    margin-bottom: 14px;
  }
  .step-row {
    display: flex; align-items: center; gap: 9px;
    padding: 5px 6px;
    margin: 0 -6px;
    border-radius: 4px;
    font-size: 0.87rem;
    color: var(--ink);
    cursor: pointer;
    transition: background 0.15s ease;
  }
  .step-row:hover { background: rgba(217,164,65,0.06); }
  .step-row input[type=checkbox] {
    appearance: none; -webkit-appearance: none;
    width: 18px; height: 18px; flex-shrink: 0;
    margin: 0;
    border: 1.5px solid var(--line);
    border-radius: 5px;
    background: var(--panel);
    cursor: pointer;
    position: relative;
    transition: background 0.15s ease, border-color 0.15s ease;
  }
  .step-row input[type=checkbox]:hover { border-color: var(--accent); }
  .step-row input[type=checkbox]:checked {
    background: var(--accent);
    border-color: var(--accent);
  }
  .step-row input[type=checkbox]:checked::after {
    content: '';
    position: absolute;
    left: 5px; top: 1px;
    width: 5px; height: 9px;
    border: solid var(--on-accent);
    border-width: 0 2px 2px 0;
    transform: rotate(45deg);
  }
  .step-row.is-done { color: var(--ink-2); }
  .step-row.is-done span { text-decoration: line-through; }

  .cat-prices {
    display: grid; grid-template-columns: 1fr 1fr; gap: 10px;
    margin-top: auto;
    padding-top: 12px;
    border-top: 1px solid var(--line-soft);
  }
  .price-field { display: flex; flex-direction: column; gap: 4px; }
  .price-field-label {
    font-family: var(--mono);
    font-size: 0.62rem;
    color: var(--ink-2);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .price-field .price-input {
    width: 100%;
    padding: 6px 8px;
    background: var(--panel); border: 1px solid var(--line-soft); border-radius: 3px;
    color: var(--ink); font-family: var(--mono); font-size: 0.85rem; text-align: right;
  }
  .price-field .price-input:focus { outline: none; border-color: var(--accent); }
  input[type=number].price-input { -moz-appearance: textfield; appearance: textfield; }
  input[type=number].price-input::-webkit-outer-spin-button,
  input[type=number].price-input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
  .room-progress {
    height: 3px;
    border-radius: 2px;
    background: rgba(240,236,228,.1);
    overflow: hidden;
    margin: 0 0 18px;
  }
  .room-progress-bar {
    height: 100%;
    background: var(--accent);
    transition: width 0.3s ease;
  }
  .shopping-empty { color: var(--ink-2); font-size: 0.88rem; margin: 4px 0; }
  .shopping-empty a { color: var(--accent); }
  .shopping-table-wrap { overflow-x: auto; }
  .shopping-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  .shopping-table th {
    text-align: left; padding: 8px 10px;
    font: 500 0.72rem var(--mono); text-transform: uppercase; letter-spacing: 0.5px;
    color: var(--ink-2); border-bottom: 1px solid var(--line);
  }
  .shopping-table td { padding: 10px; border-bottom: 1px solid var(--line-soft); }
  .shopping-table .sp-name a { color: var(--ink); text-decoration: none; }
  .shopping-table .sp-name a:hover { color: var(--accent); }
  .shopping-table .sp-unit, .shopping-table .sp-total, .shopping-table .sp-grand { font-family: var(--mono); white-space: nowrap; }
  .shopping-table .sp-qty {
    width: 90px; padding: 6px 8px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 5px;
    color: var(--ink); font-family: var(--mono); font-size: 0.88rem;
  }
  .shopping-table .sp-qty:focus { outline: none; border-color: var(--accent); }
  .shopping-table tfoot td { font-weight: 700; color: var(--accent); border-bottom: none; }
  .cost-stats { display: flex; flex-wrap: wrap; gap: 16px; }
  .cost-stat {
    flex: 1 1 160px;
    display: flex; flex-direction: column; gap: 4px;
    padding: 14px 16px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 8px;
  }
  .cost-stat-label {
    font-family: var(--mono);
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--ink-2);
  }
  .cost-stat-value {
    font-family: var(--disp);
    font-weight: 700;
    font-size: 1.4rem;
    color: var(--accent);
  }
  .color-chips { display: flex; flex-wrap: wrap; gap: 8px; }
  .color-chips:not(:empty) { margin-bottom: 10px; }
  .color-chip {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    padding: 4px 6px 4px 8px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 999px;
    font-size: 0.8rem;
    color: var(--ink);
  }
  .color-chip-swatch {
    width: 15px; height: 15px;
    border-radius: 50%;
    border: 1px solid rgba(255,255,255,0.25);
    flex-shrink: 0;
  }
  .color-chip-remove {
    flex-shrink: 0;
    width: 17px; height: 17px;
    display: flex; align-items: center; justify-content: center;
    border: none;
    border-radius: 50%;
    background: transparent;
    color: var(--ink-2);
    font-size: 0.85rem;
    line-height: 1;
    cursor: pointer;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .color-chip-remove:hover { background: rgba(210,105,79,0.2); color: var(--bad); }
  .color-chip-add { display: flex; align-items: center; gap: 8px; }
  .color-chip-picker {
    flex-shrink: 0;
    width: 30px; height: 30px;
    padding: 2px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 7px;
    cursor: pointer;
  }
  .color-chip-input {
    flex: 1;
    min-width: 0;
    padding: 7px 12px;
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 999px;
    color: var(--ink);
    font-size: 0.82rem;
  }
  .color-chip-input:focus { outline: none; border-color: var(--accent); }
  .color-chip-input::placeholder { color: var(--ink-2); opacity: 0.7; }
  .color-chip-add-btn {
    flex-shrink: 0;
    padding: 7px 14px;
    background: var(--accent);
    border: none;
    border-radius: 999px;
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600;
    font-size: 0.72rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .color-chip-add-btn:hover { background: #c6923a; }

  .gallery {
    display: grid;
    grid-template-columns: repeat(auto-fill, 200px);
    justify-content: center;
    gap: 12px;
  }
  .gallery a {
    display: block;
    width: 200px;
    height: 250px;
    border-radius: 4px;
    overflow: hidden;
    border: 1px solid var(--line-soft);
    transition: border-color 0.2s ease;
  }
  .gallery a:hover { border-color: var(--accent); }
  .gallery-item-wrap.is-winner .gallery-item {
    outline: 2px solid var(--accent);
    outline-offset: -2px;
  }
  .gallery img {
    width: 100%; height: 100%;
    object-fit: cover;
    display: block;
    transition: transform 0.2s ease;
  }
  .gallery a:hover img { transform: scale(1.05); }

  .gallery-item-wrap { display: flex; flex-direction: column; gap: 6px; }

  /* The photo itself, with the crown/delete/uploader badges floating on top of it - a modern
     overlay pattern (like Google Photos/Unsplash cards) instead of cramming icons + text into a
     separate row below a tiny thumbnail. */
  .photo-frame { position: relative; }
  .photo-frame .gallery-item { display: block; }

  .photo-badges {
    position: absolute;
    top: 8px; right: 8px;
    display: flex;
    gap: 6px;
  }
  .photo-badge-btn {
    width: 26px; height: 26px;
    margin: 0; padding: 0;
    border-radius: 5px;
    display: flex; align-items: center; justify-content: center;
    background: rgba(18,17,15,.8);
    border: 1px solid var(--line);
    cursor: pointer;
    font-family: inherit;
    line-height: 1;
    color: var(--ink-3);
    transition: color 0.15s ease, background 0.15s ease;
  }

  .photo-crown-btn:hover { color: var(--accent); background: rgba(217,164,65,.15); }
  .photo-crown-btn.is-winner { color: var(--accent); }
  .photo-delete-btn { font-size: 0.68rem; }
  .photo-delete-btn:hover { color: var(--bad); background: rgba(210,105,79,0.15); }

  .photo-uploader {
    position: absolute;
    bottom: 8px; left: 8px;
    max-width: calc(100% - 16px);
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    background: rgba(18,17,15,.85);
    border-radius: 999px;
    padding: 3px 8px;
    font-family: var(--mono);
    font-size: 0.64rem;
    color: var(--ink-2);
  }

  /* Clean footer below the photo: interactive stars on the left, aggregate rating pill on the right */
  .photo-footer { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
  .photo-rating { display: flex; align-items: center; gap: 2px; }
  .photo-rating .star {
    cursor: pointer;
    font-size: 0.95rem;
    line-height: 1;
    color: var(--line);
    transition: color 0.15s ease, transform 0.15s ease;
  }
  .photo-rating .star:hover { transform: scale(1.15); }
  .photo-rating .star.is-filled { color: #e8c468; }
  .photo-rating-avg {
    flex-shrink: 0;
    font-family: var(--mono);
    font-size: 0.68rem;
    color: var(--ink-2);
    background: var(--panel);
    border: 1px solid var(--line-soft);
    border-radius: 999px;
    padding: 2px 8px;
    white-space: nowrap;
  }

  .upload-row { margin-top: 14px; }
  .upload-btn {
    display: flex; align-items: center; justify-content: center; gap: 8px;
    width: 100%;
    padding: 12px 18px;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: var(--panel);
    color: var(--ink);
    font-family: var(--disp); font-weight: 500;
    font-size: 0.82rem;
    cursor: pointer;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  .upload-btn:hover { border-color: var(--accent); color: var(--accent); }
  .upload-btn.is-uploading { opacity: 0.6; pointer-events: none; }

  /* Eroarea de upload apare ca popup, nu ca banda sus in pagina: dupa upload browserul sare la
     camera (#slug), deci o banda de sus ar ramane in afara ecranului tocmai cand conteaza. */
  .upload-error-backdrop {
    position: fixed; inset: 0; z-index: 600;
    background: rgba(0,0,0,0.55);
    display: flex; align-items: center; justify-content: center;
    padding: 20px;
  }
  .upload-error-backdrop[hidden] { display: none; }
  .upload-error-modal {
    background: var(--panel);
    border: 1px solid var(--line);
    border-top: 3px solid var(--bad);
    border-radius: 10px;
    padding: 22px 24px;
    max-width: 480px; width: 100%;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
  }
  .upload-error-modal h2 {
    margin: 0 0 10px;
    font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--bad);
  }
  .upload-error-modal p { margin: 0; color: var(--ink); font-size: 0.9rem; line-height: 1.5; }
  .upload-error-modal code {
    display: block; margin-top: 12px;
    padding: 9px 11px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    font-family: var(--mono); font-size: 0.76rem; color: var(--ink-2);
    overflow-wrap: anywhere;
  }
  .upload-error-actions { display: flex; justify-content: flex-end; margin-top: 18px; }
  .upload-error-actions button {
    padding: 8px 20px; border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem; cursor: pointer;
  }

  .empty-state, .empty-room {
    text-align: center;
    color: var(--ink-2);
    font-family: var(--mono);
    font-size: 0.85rem;
    padding: 40px 20px;
    border: 1px dashed var(--line);
    border-radius: 8px;
  }
  .empty-state code, .empty-room code {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 5px;
    padding: 2px 8px;
    font-family: var(--mono);
  }

  /* Lightbox */
  #lightbox {
    position: fixed; inset: 0; z-index: 1000;
    background: rgba(10,9,8,0.94);
    display: none;
    align-items: center; justify-content: center;
    padding: 24px;
  }
  #lightbox.is-open { display: flex; }
  #lightbox img {
    max-width: 100%; max-height: 100%;
    border-radius: 6px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.6);
  }
  #lightbox .lb-close, #lightbox .lb-prev, #lightbox .lb-next {
    position: absolute;
    background: var(--panel);
    border: 1px solid var(--line);
    color: var(--ink);
    width: 42px; height: 42px;
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    cursor: pointer;
    font-size: 1.2rem;
    user-select: none;
    transition: border-color 0.2s ease, color 0.2s ease;
  }
  #lightbox .lb-close:hover, #lightbox .lb-prev:hover, #lightbox .lb-next:hover { border-color: var(--accent); color: var(--accent); }
  #lightbox .lb-close { top: 20px; right: 20px; }
  #lightbox .lb-prev { left: 20px; top: 50%; transform: translateY(-50%); }
  #lightbox .lb-next { right: 20px; top: 50%; transform: translateY(-50%); }
</style>
<link rel="stylesheet" href="/assets/casa-undo.css">
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span><?= htmlspecialchars($currentHouse['name']) ?></span></div>
    <nav id="heroNav">
      <a href="/progres.php">Construcție</a>
      <a href="/design/" class="is-current">Design</a>
      <a href="/links.php">Link-uri</a>
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

<?php if (!empty($_GET['upload_error'])): ?>
  <?php
    $uploadErrorMessages = [
        'bad_room' => 'Camera nu a fost recunoscută.',
        'too_big_for_server' => 'Poza e prea mare pentru limita serverului (post_max_size, acum: ' . ini_get('post_max_size') . ').',
        'no_file' => 'Nu a fost primit niciun fișier.',
        'bad_extension' => 'Extensia fișierului nu e acceptată (acceptate: jpg, png, gif, webp).',
        'too_big' => 'Poza depășește limita de 15 MB.',
        'not_an_image' => 'Fișierul nu pare să fie o imagine validă (getimagesize a eșuat).',
        'save_failed' => 'Fișierul a fost primit dar nu a putut fi salvat pe disc.',
        'upload_error_1' => 'Fișierul depășește upload_max_filesize din configurația serverului (acum: ' . ini_get('upload_max_filesize') . ').',
        'upload_error_2' => 'Fișierul depășește limita MAX_FILE_SIZE din formular.',
        'upload_error_3' => 'Fișierul a fost încărcat doar parțial (conexiune întreruptă?).',
        'upload_error_4' => 'Niciun fișier nu a fost selectat.',
        'upload_error_6' => 'Lipsește folderul temporar de pe server.',
        'upload_error_7' => 'Serverul nu a putut scrie fișierul pe disc.',
        'upload_error_8' => 'Upload oprit de o extensie PHP.',
    ];
    $uploadErrorCode = $_GET['upload_error'];
    $uploadErrorMsg = $uploadErrorMessages[$uploadErrorCode] ?? ('Eroare necunoscută la upload (cod: ' . htmlspecialchars($uploadErrorCode) . ').');
  ?>
  <div class="upload-error-backdrop" id="uploadErrorBackdrop">
    <div class="upload-error-modal" role="dialog" aria-modal="true" aria-labelledby="uploadErrorTitle">
      <h2 id="uploadErrorTitle">Poza nu a putut fi încărcată</h2>
      <p><?= htmlspecialchars($uploadErrorMsg) ?></p>
      <?php if (!empty($_GET['upload_detail'])): ?>
        <code><?= htmlspecialchars($_GET['upload_detail']) ?></code>
      <?php endif; ?>
      <div class="upload-error-actions">
        <button type="button" id="uploadErrorClose">Am înțeles</button>
      </div>
    </div>
  </div>
<?php endif; ?>

<div class="item-modal-backdrop" id="itemModalBackdrop" hidden>
  <div class="item-modal" role="dialog" aria-modal="true" aria-labelledby="itemModalTitle">
    <h2 id="itemModalTitle">Item nou</h2>
    <div class="item-modal-field">
      <span>Nume</span>
      <input type="text" id="itemModalName" maxlength="150" required>
    </div>
    <div class="item-modal-steps">
      <label class="step-row">
        <input type="checkbox" id="itemModalCumparat">
        <span>Cumpărat</span>
      </label>
      <label class="step-row">
        <input type="checkbox" id="itemModalMontat">
        <span>Montat</span>
      </label>
    </div>
    <div class="cat-prices">
      <div class="price-field">
        <span class="price-field-label">Estimativ</span>
        <input type="number" class="price-input" id="itemModalEstimate" min="0" step="0.01">
      </div>
      <div class="price-field">
        <span class="price-field-label">Real</span>
        <input type="number" class="price-input" id="itemModalActual" min="0" step="0.01">
      </div>
    </div>
    <div class="item-modal-actions">
      <button type="button" class="item-modal-delete" id="itemModalDelete" hidden>Șterge</button>
      <span class="item-modal-spacer"></span>
      <button type="button" class="item-modal-cancel" id="itemModalCancel">Anulează</button>
      <button type="button" class="item-modal-save" id="itemModalSave">Salvează</button>
    </div>
  </div>
</div>

<?php if (empty($rooms)): ?>
  <div class="empty-state">
    <p>Nu există încă nicio cameră adăugată.</p>
  </div>
  <form class="room-add-form" method="post" action="room_add.php">
    <input type="text" name="name" maxlength="60" placeholder="+ Cameră nouă" required>
    <button type="submit">Adaugă</button>
  </form>
<?php else: ?>

  <?php
    // Forced 2-row layout requested by the user, regardless of viewport width - split dynamically
    // (in the same order the rooms already sort in) so a newly added room always shows up here too,
    // instead of a fixed slug list that only ever covered the rooms that existed at the time.
    $roomsBySlug = [];
    foreach ($rooms as $room) $roomsBySlug[$room['slug']] = $room;
    $navRows = array_chunk($rooms, (int)ceil(count($rooms) / 2));
  ?>
  <nav class="room-nav">
    <?php foreach ($navRows as $rowRooms): ?>
      <div class="room-nav-row">
        <?php foreach ($rowRooms as $room): ?>
          <a href="#<?= htmlspecialchars($room['slug']) ?>"><?= htmlspecialchars($room['name']) ?></a>
        <?php endforeach; ?>
      </div>
    <?php endforeach; ?>
  </nav>

  <form class="room-add-form" method="post" action="room_add.php">
    <input type="text" name="name" maxlength="60" placeholder="+ Cameră nouă" required>
    <button type="submit">Adaugă</button>
  </form>

  <nav class="room-floating-nav" aria-label="Sari la camera">
    <?php foreach ($rooms as $room): ?>
      <a href="#<?= htmlspecialchars($room['slug']) ?>" title="<?= htmlspecialchars($room['name']) ?>"><span><?= htmlspecialchars(casa_room_letter_code($room['slug'], $roomLetterCodes)) ?></span></a>
    <?php endforeach; ?>
  </nav>

  <button type="button" class="room-burger-btn" id="roomBurgerBtn" aria-label="Camere" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <div class="room-burger-panel" id="roomBurgerPanel">
    <p class="burger-title">Camere</p>
    <div class="burger-links">
      <?php foreach ($rooms as $room): ?>
        <a href="#<?= htmlspecialchars($room['slug']) ?>"><span class="room-nav-icon"><?= casa_room_icon($room['slug'], $roomIcons) ?></span><?= htmlspecialchars($room['name']) ?></a>
      <?php endforeach; ?>
    </div>
  </div>

  <?php foreach ($rooms as $roomIdx => $room): ?>
    <?php
      $totalSteps = 0;
      $doneSteps = 0;
      foreach ($casaChecklistDefs as $catKey => $cat) {
          foreach ($checklistItemsLookup[$room['slug']][$catKey] ?? [] as $item) {
              $totalSteps += 2;
              if ($item['cumparat']) $doneSteps++;
              if ($item['montat']) $doneSteps++;
          }
      }
      $roomPct = $totalSteps > 0 ? round($doneSteps / $totalSteps * 100) : 0;
    ?>
    <section class="room" id="<?= htmlspecialchars($room['slug']) ?>" data-room-slug="<?= htmlspecialchars($room['slug']) ?>">
      <div class="room-heading">
        <h2><span class="room-title-text"><?= htmlspecialchars($room['name']) ?></span></h2>
        <input type="text" class="room-title-input" value="<?= htmlspecialchars($room['name']) ?>" maxlength="100" hidden>
        <button type="button" class="room-title-save-btn" title="Salvează" hidden>✓</button>
        <button type="button" class="room-title-cancel-btn" title="Anulează" hidden>✕</button>
        <button type="button" class="room-rename-btn" title="Redenumește camera">✎</button>
        <button type="button" class="room-move-btn" data-dir="up" title="Mută camera mai sus"<?= $roomIdx === 0 ? ' disabled' : '' ?>>▲</button>
        <button type="button" class="room-move-btn" data-dir="down" title="Mută camera mai jos"<?= $roomIdx === count($rooms) - 1 ? ' disabled' : '' ?>>▼</button>
        <button type="button" class="room-delete-btn" title="Șterge camera">🗑</button>
        <span class="room-title-status">Status: <strong><?= $roomPct ?>%</strong></span>
        <span class="room-heading-spacer"></span>
        <span class="room-title-index"><?= str_pad($roomIdx + 1, 2, '0', STR_PAD_LEFT) ?> / <?= str_pad(count($rooms), 2, '0', STR_PAD_LEFT) ?></span>
      </div>

        <div class="room-body">

      <?php
        $roomEstimateTotal = 0;
        $roomActualTotal = 0;
        if ($isOwner) {
            foreach ($casaChecklistDefs as $catKey => $cat) {
                foreach ($checklistItemsLookup[$room['slug']][$catKey] ?? [] as $item) {
                    $roomEstimateTotal += $item['price_estimate'];
                    $roomActualTotal += $item['price_actual'];
                }
            }
        }
      ?>
      <div class="room-progress"><div class="room-progress-bar" style="width:<?= $roomPct ?>%"></div></div>

      <?php
        $roomColors = $colorsLookup[$room['slug']] ?? [];
        $roomNotes = $notesLookup[$room['slug']] ?? [];
        $roomShopping = $shoppingLookup[$room['slug']] ?? [];
      ?>
      <div class="room-tabs" role="tablist">
        <button type="button" class="room-tab-btn" data-tab="notes"><span class="tab-label">Notițe</span><span class="tab-badge"><?= count($roomNotes) ?></span></button>
        <?php if ($isOwner): ?>
          <button type="button" class="room-tab-btn" data-tab="photos"><span class="tab-label">Poze</span><span class="tab-badge"><?= count($room['images']) ?></span></button>
        <?php endif; ?>
        <button type="button" class="room-tab-btn" data-tab="colors"><span class="tab-label">Culori</span><span class="tab-badge"><?= count($roomColors) ?></span></button>
        <button type="button" class="room-tab-btn" data-tab="checklist"><span class="tab-label">Checklist</span></button>
        <button type="button" class="room-tab-btn" data-tab="cost"><span class="tab-label">Cost</span></button>
        <button type="button" class="room-tab-btn" data-tab="shopping"><span class="tab-label">Shopping</span><span class="tab-badge"><?= count($roomShopping) ?></span></button>
      </div>

      <div class="room-tab-panel" data-tab="notes" hidden>
        <div class="notes" data-room="<?= htmlspecialchars($room['slug']) ?>">
          <div class="notes-list">
            <?php foreach ($roomNotes as $note): ?>
              <div class="note-item" data-id="<?= $note['id'] ?>">
                <div class="note-date-col"><?= htmlspecialchars($note['dateShort']) ?></div>
                <div class="note-body">
                  <div class="note-text" data-raw="<?= htmlspecialchars($note['note']) ?>"><?= nl2br(htmlspecialchars($note['note'])) ?></div>
                  <div class="note-meta">
                    <span class="note-date"><span class="note-author"><?= htmlspecialchars($note['author']) ?></span> · <?= htmlspecialchars($note['date']) ?></span>
                    <div class="note-actions">
                      <button class="note-edit-btn" title="Editează notița">✎</button>
                      <button class="note-delete-btn" title="Șterge notița">✕</button>
                    </div>
                  </div>
                  <div class="note-edit-row">
                    <textarea class="note-edit-input" maxlength="500"><?= htmlspecialchars($note['note']) ?></textarea>
                    <div class="note-add-footer">
                      <span class="note-charcount">0/500</span>
                      <div class="note-edit-actions">
                        <button type="button" class="note-edit-save-btn">Salvează</button>
                        <button type="button" class="note-edit-cancel-btn">Anulează</button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <?php endforeach; ?>
          </div>
          <?php if (empty($roomNotes)): ?>
            <p class="notes-empty notes-empty-marker">Nicio notiță încă.</p>
          <?php endif; ?>
          <div class="note-add-row">
            <textarea class="note-input" maxlength="500" placeholder="Notiță nouă (max 500 caractere)..."></textarea>
            <div class="note-add-footer">
              <span class="note-charcount">0/500</span>
              <button type="button" class="note-add-btn">Adaugă notiță</button>
            </div>
          </div>
        </div>
      </div>

      <div class="room-tab-panel" data-tab="colors" hidden>
        <div class="color-chips" data-room="<?= htmlspecialchars($room['slug']) ?>">
          <?php foreach ($roomColors as $c): ?>
            <span class="color-chip" data-id="<?= htmlspecialchars($c['id']) ?>">
              <span class="color-chip-swatch" style="background:<?= htmlspecialchars($c['hex']) ?>"></span>
              <span class="color-chip-label"><?= htmlspecialchars($c['label']) ?></span>
              <button type="button" class="color-chip-remove" title="Șterge culoarea">×</button>
            </span>
          <?php endforeach; ?>
        </div>
        <div class="color-chip-add">
          <input type="color" class="color-chip-picker" value="#d9a441" title="Alege culoarea">
          <input type="text" class="color-chip-input" maxlength="60" placeholder="ex: Pereți living, RAL 9010...">
          <button type="button" class="color-chip-add-btn">+ Adaugă</button>
        </div>
      </div>

      <?php if ($isOwner): ?>
      <div class="room-tab-panel" data-tab="photos" hidden>
        <?php if (empty($room['images'])): ?>
          <div class="empty-room">Niciun poză în acest folder încă.</div>
        <?php else: ?>
          <div class="gallery" data-room="<?= htmlspecialchars($room['slug']) ?>">
            <?php foreach ($room['images'] as $img): ?>
              <div class="gallery-item-wrap<?= $img['isWinner'] ? ' is-winner' : '' ?>" data-filename="<?= htmlspecialchars($img['filename']) ?>">
                <div class="photo-frame">
                  <a href="<?= htmlspecialchars($img['href']) ?>" class="gallery-item">
                    <img src="<?= htmlspecialchars($img['href']) ?>" alt="<?= htmlspecialchars($room['name']) ?>" loading="lazy">
                  </a>
                  <div class="photo-badges">
                    <button type="button" class="photo-badge-btn photo-crown-btn<?= $img['isWinner'] ? ' is-winner' : '' ?>" title="Marchează drept poza câștigătoare">
                      <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7z"/></svg>
                    </button>
                    <button type="button" class="photo-badge-btn photo-delete-btn" title="Șterge poza">✕</button>
                  </div>
                  <span class="photo-uploader"><?= htmlspecialchars($img['uploader'] !== null && $img['uploader'] !== '' ? $img['uploader'] : 'Anonim') ?></span>
                </div>
                <div class="photo-footer">
                  <div class="photo-rating" data-rating="<?= $img['rating'] ?>">
                    <?php for ($s = 1; $s <= 5; $s++): ?>
                      <span class="star<?= $s <= $img['rating'] ? ' is-filled' : '' ?>" data-value="<?= $s ?>">★</span>
                    <?php endfor; ?>
                  </div>
                  <span class="photo-rating-avg"<?= $img['voteCount'] === 0 ? ' hidden' : '' ?>>
                    <?= number_format($img['avg'], 1) ?>/5 (<?= $img['voteCount'] ?>)
                  </span>
                </div>
              </div>
            <?php endforeach; ?>
          </div>
        <?php endif; ?>

        <div class="upload-row">
          <form class="upload-form" method="post" action="upload.php" enctype="multipart/form-data">
            <input type="hidden" name="room" value="<?= htmlspecialchars($room['slug']) ?>">
            <label class="upload-btn">
              Adaugă poză
              <input type="file" name="photo" accept="image/*" hidden>
            </label>
          </form>
        </div>
      </div>
      <?php endif; ?>

      <div class="room-tab-panel" data-tab="cost" hidden>
        <div class="cost-stats">
          <div class="cost-stat">
            <span class="cost-stat-label">Estimat</span>
            <span class="cost-stat-value" title="<?= htmlspecialchars(casa_eur_title($roomEstimateTotal)) ?>"><?= casa_format_lei($roomEstimateTotal) ?></span>
          </div>
          <div class="cost-stat">
            <span class="cost-stat-label">Cheltuit</span>
            <span class="cost-stat-value" title="<?= htmlspecialchars(casa_eur_title($roomActualTotal)) ?>"><?= casa_format_lei($roomActualTotal) ?></span>
          </div>
        </div>
      </div>

      <div class="room-tab-panel" data-tab="shopping" hidden>
        <?php if (!$roomShopping): ?>
          <p class="shopping-empty">Niciun produs în această cameră. Adaugă produse din <a href="/shopping.php">Lista de cumpărături</a>.</p>
        <?php else: ?>
        <div class="shopping-table-wrap">
        <table class="shopping-table">
          <thead><tr><th>Produs</th><th>Cantitate</th><th>Preț / u.m.</th><th>Preț total</th></tr></thead>
          <tbody>
          <?php $roomShoppingTotal = 0; foreach ($roomShopping as $sp):
            $spPrice = $sp['price'] !== null ? (float)$sp['price'] : null;
            $spQty = (float)$sp['quantity'];
            $spTotal = $spPrice !== null ? $spPrice * $spQty : null;
            if ($spTotal !== null) $roomShoppingTotal += $spTotal;
          ?>
            <tr data-id="<?= (int)$sp['id'] ?>" data-price="<?= $spPrice !== null ? $spPrice : '' ?>">
              <td class="sp-name"><a href="<?= htmlspecialchars($sp['url']) ?>" target="_blank" rel="noopener noreferrer"><?= htmlspecialchars($sp['name']) ?></a></td>
              <td><input type="number" class="sp-qty" min="0" step="any" value="<?= htmlspecialchars((string)($spQty + 0)) ?>"></td>
              <td class="sp-unit"><?= $spPrice !== null ? number_format($spPrice, 2, ',', '.') . ' LEI' . (!empty($sp['unit_price']) ? '/mp' : '') : '—' ?></td>
              <td class="sp-total"><?= $spTotal !== null ? number_format($spTotal, 2, ',', '.') . ' LEI' : '—' ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
          <tfoot><tr><td colspan="3">Total cameră</td><td class="sp-grand"><?= number_format($roomShoppingTotal, 2, ',', '.') ?> LEI</td></tr></tfoot>
        </table>
        </div>
        <?php endif; ?>
      </div>

      <div class="room-tab-panel" data-tab="checklist" hidden>
        <div class="checklist" data-room="<?= htmlspecialchars($room['slug']) ?>">
        <?php foreach ($casaChecklistDefs as $catKey => $cat): ?>
          <?php
            $catItems = $checklistItemsLookup[$room['slug']][$catKey] ?? [];
            $catTotal = count($catItems) * 2;
            $catDone = 0;
            foreach ($catItems as $item) {
                if ($item['cumparat']) $catDone++;
                if ($item['montat']) $catDone++;
            }
          ?>
          <?php $catPct = $catTotal > 0 ? round($catDone / $catTotal * 100) : 0; ?>
          <?php
            $catEstimateTotal = 0;
            $catActualTotal = 0;
            foreach ($catItems as $item) {
                $catEstimateTotal += $item['price_estimate'];
                $catActualTotal += $item['price_actual'];
            }
          ?>
          <div class="checklist-cat">
            <div class="cat-header">
              <h4><?= htmlspecialchars($cat['label']) ?></h4>
              <span class="cat-badge<?= $catTotal > 0 && $catDone === $catTotal ? ' is-complete' : '' ?>"><?= $catDone ?>/<?= $catTotal ?></span>
            </div>
            <div class="cat-cost-summary">
              <span title="<?= htmlspecialchars(casa_eur_title($catEstimateTotal)) ?>">Cost estimat: <?= casa_format_lei($catEstimateTotal) ?></span>
              <span title="<?= htmlspecialchars(casa_eur_title($catActualTotal)) ?>">Cost real: <?= casa_format_lei($catActualTotal) ?></span>
            </div>
            <div class="cat-progress"><div class="cat-progress-bar" style="width:<?= $catPct ?>%"></div></div>

            <div class="item-list" data-category="<?= htmlspecialchars($catKey) ?>">
              <?php foreach ($catItems as $item): ?>
                <div class="checklist-item"
                     data-item-id="<?= $item['id'] ?>"
                     data-name="<?= htmlspecialchars($item['name'], ENT_QUOTES) ?>"
                     data-cumparat="<?= $item['cumparat'] ? '1' : '0' ?>"
                     data-montat="<?= $item['montat'] ? '1' : '0' ?>"
                     data-price-estimate="<?= htmlspecialchars($item['price_estimate']) ?>"
                     data-price-actual="<?= htmlspecialchars($item['price_actual']) ?>">
                  <div class="item-head">
                    <span class="item-name"><?= htmlspecialchars($item['name']) ?></span>
                    <?php if ($isOwner): ?>
                      <button type="button" class="item-edit-btn" title="Editează item">✎</button>
                    <?php endif; ?>
                  </div>
                  <div class="item-flags">
                    <label class="item-flag<?= $item['cumparat'] ? ' is-done' : '' ?>">
                      <input type="checkbox" data-field="cumparat" <?= $item['cumparat'] ? 'checked' : '' ?> <?= $isOwner ? '' : 'disabled' ?>>
                      <span>Cumpărat</span>
                    </label>
                    <label class="item-flag<?= $item['montat'] ? ' is-done' : '' ?>">
                      <input type="checkbox" data-field="montat" <?= $item['montat'] ? 'checked' : '' ?> <?= $isOwner ? '' : 'disabled' ?>>
                      <span>Montat</span>
                    </label>
                  </div>
                  <?php if ($isOwner): ?>
                    <div class="item-cost-summary">
                      <span title="<?= htmlspecialchars(casa_eur_title($item['price_estimate'])) ?>">Est: <?= casa_format_lei($item['price_estimate']) ?></span>
                      <span title="<?= htmlspecialchars(casa_eur_title($item['price_actual'])) ?>">Real: <?= casa_format_lei($item['price_actual']) ?></span>
                    </div>
                  <?php endif; ?>
                </div>
              <?php endforeach; ?>
            </div>

            <?php if ($isOwner): ?>
              <button type="button" class="item-add-btn" data-room="<?= htmlspecialchars($room['slug']) ?>" data-category="<?= htmlspecialchars($catKey) ?>">+ Adaugă item</button>
            <?php endif; ?>
          </div>
        <?php endforeach; ?>
        </div>
      </div>

        </div>
    </section>
  <?php endforeach; ?>

<?php endif; ?>

</main>

<?php casa_render_footer(); ?>

<div id="lightbox">
  <span class="lb-close" id="lbClose">✕</span>
  <span class="lb-prev" id="lbPrev">‹</span>
  <img id="lbImg" src="" alt="">
  <span class="lb-next" id="lbNext">›</span>
</div>

<script src="/assets/casa-undo.js"></script>
<script>
(function() {
  // Preturile sunt in LEI nativ - vezi casa_format_lei()/casa_eur_title() in _house.php, care fac
  // acelasi lucru server-side. Tooltip-ul de pe totaluri arata doar echivalentul in EUR, ca reper.
  var EUR_TO_LEI = 5.25;
  function formatLei(amountLei) {
    return amountLei.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' LEI';
  }
  function formatEurTitle(amountLei) {
    return (amountLei / EUR_TO_LEI).toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' EUR';
  }

  // Shopping tab: editing Cantitate saves it (debounced) and recomputes row + room totals.
  document.querySelectorAll('.shopping-table').forEach(function(table) {
    function fmt(n) { return n.toLocaleString('ro-RO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' LEI'; }
    function recompute() {
      var grand = 0;
      table.querySelectorAll('tbody tr').forEach(function(tr) {
        var price = tr.getAttribute('data-price');
        var cell = tr.querySelector('.sp-total');
        if (price === '') { cell.textContent = '—'; return; }
        var qty = parseFloat(tr.querySelector('.sp-qty').value.replace(',', '.'));
        var total = (isNaN(qty) ? 0 : qty) * parseFloat(price);
        cell.textContent = fmt(total);
        grand += total;
      });
      table.querySelector('.sp-grand').textContent = fmt(grand);
    }
    table.querySelectorAll('.sp-qty').forEach(function(input) {
      var timer = null;
      input.addEventListener('input', function() {
        recompute();
        clearTimeout(timer);
        timer = setTimeout(function() {
          var qty = input.value.replace(',', '.');
          if (qty === '' || isNaN(parseFloat(qty)) || parseFloat(qty) < 0) return;
          fetch('/design/shopping_qty.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'id=' + encodeURIComponent(input.closest('tr').getAttribute('data-id')) + '&quantity=' + encodeURIComponent(qty)
          });
        }, 500);
      });
    });
  });

  // Room tabs (Checklist/Notițe/Culori/Poze) - one panel visible at a time per room.
  document.querySelectorAll('.room').forEach(function(room) {
    var tabBtns = Array.prototype.slice.call(room.querySelectorAll('.room-tab-btn'));
    var panels = Array.prototype.slice.call(room.querySelectorAll('.room-tab-panel'));
    if (!tabBtns.length) return;
    tabBtns.forEach(function(btn) {
      btn.addEventListener('click', function() {
        var tab = btn.getAttribute('data-tab');
        var wasActive = btn.classList.contains('is-active');
        if (wasActive) {
          // Clicking the already-open tab again collapses it, back to no tab active.
          tabBtns.forEach(function(b) { b.classList.remove('is-active'); });
          panels.forEach(function(p) { p.hidden = true; });
        } else {
          tabBtns.forEach(function(b) { b.classList.toggle('is-active', b === btn); });
          panels.forEach(function(p) { p.hidden = p.getAttribute('data-tab') !== tab; });
        }
      });
    });
  });

  // Popup-ul de eroare la upload: se inchide din buton, din fundal sau cu Escape. La inchidere
  // curatam si parametrii din URL, ca un refresh sa nu reafiseze aceeasi eroare deja citita.
  (function uploadErrorPopup() {
    var backdrop = document.getElementById('uploadErrorBackdrop');
    if (!backdrop) return;

    function close() {
      backdrop.hidden = true;
      var url = new URL(location.href);
      url.searchParams.delete('upload_error');
      url.searchParams.delete('upload_detail');
      history.replaceState(null, '', url.pathname + url.search + url.hash);
    }
    document.getElementById('uploadErrorClose').addEventListener('click', close);
    backdrop.addEventListener('click', function(e) { if (e.target === backdrop) close(); });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && !backdrop.hidden) close();
    });
  })();

  // Uploadul de poze e singura actiune care reincarca pagina, iar panourile pornesc inchise - deci
  // spoilerul din care tocmai ai urcat poza s-ar inchide singur. upload.php intoarce "?tab=photos"
  // plus camera in hash, iar aici redeschidem acel panou. Dam click pe buton in loc sa umblam la
  // clase, ca sa treaca prin exact aceeasi logica de comutare ca un click al utilizatorului.
  (function restoreTabFromUrl() {
    var tab = new URLSearchParams(location.search).get('tab');
    var slug = decodeURIComponent((location.hash || '').replace(/^#/, ''));
    if (!tab || !slug) return;
    var room = document.querySelector('.room[data-room-slug="' + slug + '"]');
    if (!room) return;
    var btn = room.querySelector('.room-tab-btn[data-tab="' + tab + '"]');
    if (btn && !btn.classList.contains('is-active')) btn.click();
  })();

  // Finds the little count/percent badge inside a room's tab button for a given tab name - used
  // to keep it in sync after an add/delete/toggle inside that tab's panel, without a reload.
  function roomTabBadge(el, tabName) {
    var room = el.closest('.room');
    if (!room) return null;
    return room.querySelector('.room-tab-btn[data-tab="' + tabName + '"] .tab-badge');
  }

  var lightbox = document.getElementById('lightbox');
  var lbImg = document.getElementById('lbImg');
  var currentGroup = [];
  var currentIndex = 0;

  function openLightbox(group, index) {
    currentGroup = group;
    currentIndex = index;
    lbImg.src = currentGroup[currentIndex];
    lightbox.classList.add('is-open');
  }
  function closeLightbox() { lightbox.classList.remove('is-open'); }
  function show(delta) {
    currentIndex = (currentIndex + delta + currentGroup.length) % currentGroup.length;
    lbImg.src = currentGroup[currentIndex];
  }

  document.querySelectorAll('.gallery').forEach(function(gallery) {
    var room = gallery.getAttribute('data-room');
    var wraps = Array.prototype.slice.call(gallery.querySelectorAll('.gallery-item-wrap'));
    // hrefs stays index-aligned with wraps, both for the lightbox's prev/next and so a rating
    // change (which renames the file) or a delete can patch just its own slot in place.
    var hrefs = wraps.map(function(wrap) { return wrap.querySelector('.gallery-item').getAttribute('href'); });

    wraps.forEach(function(wrap, i) {
      wrap.querySelector('.gallery-item').addEventListener('click', function(e) {
        e.preventDefault();
        openLightbox(hrefs, wraps.indexOf(wrap));
      });
    });

    function refreshGalleryCounts() {
      var remaining = gallery.querySelectorAll('.gallery-item-wrap').length;
      var photosSpoilerPct = roomTabBadge(gallery, 'photos');
      if (photosSpoilerPct) photosSpoilerPct.textContent = remaining;

      var emptyMsg = gallery.parentNode.querySelector('.empty-room');
      if (remaining === 0) {
        gallery.style.display = 'none';
        if (!emptyMsg) {
          emptyMsg = document.createElement('div');
          emptyMsg.className = 'empty-room';
          emptyMsg.textContent = 'Niciun poză în acest folder încă.';
          gallery.after(emptyMsg);
        }
      } else {
        gallery.style.display = '';
        if (emptyMsg) emptyMsg.remove();
      }
    }

    wraps.forEach(function(wrap) {
      var btn = wrap.querySelector('.photo-delete-btn');
      btn.addEventListener('click', function() {
        var filename = wrap.getAttribute('data-filename');
        var parent = wrap.parentNode;
        var nextSibling = wrap.nextSibling;
        var idx = wraps.indexOf(wrap);
        var href = idx !== -1 ? hrefs[idx] : null;

        wrap.remove();
        if (idx !== -1) { wraps.splice(idx, 1); hrefs.splice(idx, 1); }
        refreshGalleryCounts();

        casaUndoAction({
          message: 'Poză ștearsă.',
          commit: function() {
            fetch('delete_photo.php', {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({ room: room, filename: filename }).toString()
            }).catch(function() {});
          },
          undo: function() {
            if (nextSibling && nextSibling.parentNode === parent) parent.insertBefore(wrap, nextSibling);
            else parent.appendChild(wrap);
            var insertAt = idx !== -1 ? idx : wraps.length;
            wraps.splice(insertAt, 0, wrap);
            hrefs.splice(insertAt, 0, href);
            refreshGalleryCounts();
          }
        });
      });
    });

    wraps.forEach(function(wrap) {
      var ratingBox = wrap.querySelector('.photo-rating');
      if (!ratingBox) return;
      var avgEl = wrap.querySelector('.photo-rating-avg');
      var stars = Array.prototype.slice.call(ratingBox.querySelectorAll('.star'));

      function paintStars(upTo) {
        stars.forEach(function(s) {
          s.classList.toggle('is-filled', parseInt(s.getAttribute('data-value'), 10) <= upTo);
        });
      }

      stars.forEach(function(star) {
        star.addEventListener('mouseenter', function() {
          paintStars(parseInt(star.getAttribute('data-value'), 10));
        });
        star.addEventListener('click', function() {
          var value = parseInt(star.getAttribute('data-value'), 10);
          var current = parseInt(ratingBox.getAttribute('data-rating'), 10) || 0;
          var newRating = value === current ? 0 : value; // clicking the current rating clears it

          fetch('rate_photo.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ room: room, filename: wrap.getAttribute('data-filename'), rating: newRating }).toString()
          }).then(function(res) { return res.json(); }).then(function(data) {
            if (!data.ok) throw new Error('rate failed');
            ratingBox.setAttribute('data-rating', data.rating);
            paintStars(data.rating);
            if (avgEl) {
              if (data.voteCount > 0) {
                avgEl.hidden = false;
                avgEl.textContent = data.avg.toFixed(1) + '/5 (' + data.voteCount + ')';
              } else {
                avgEl.hidden = true;
              }
            }
          }).catch(function() {
            paintStars(parseInt(ratingBox.getAttribute('data-rating'), 10) || 0);
            alert('Nu s-a putut salva ratingul. Încearcă din nou.');
          });
        });
      });

      ratingBox.addEventListener('mouseleave', function() {
        paintStars(parseInt(ratingBox.getAttribute('data-rating'), 10) || 0);
      });
    });

    wraps.forEach(function(wrap) {
      var crownBtn = wrap.querySelector('.photo-crown-btn');
      if (!crownBtn) return;
      crownBtn.addEventListener('click', function() {
        var newWinner = !crownBtn.classList.contains('is-winner');

        fetch('crown_photo.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ room: room, filename: wrap.getAttribute('data-filename'), winner: newWinner ? '1' : '0' }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('crown failed');
          crownBtn.classList.toggle('is-winner', data.winner);
          wrap.classList.toggle('is-winner', data.winner);

          if (data.winner) {
            // Winning photos sort first - move it to the front, both in the DOM and in the
            // wraps/hrefs arrays the lightbox's prev/next relies on.
            gallery.insertBefore(wrap, gallery.firstChild);
            var idx = wraps.indexOf(wrap);
            if (idx > 0) {
              wraps.splice(idx, 1);
              wraps.unshift(wrap);
              hrefs.unshift(hrefs.splice(idx, 1)[0]);
            }
          }
        }).catch(function() {
          alert('Nu s-a putut salva. Încearcă din nou.');
        });
      });
    });
  });

  document.querySelectorAll('.color-chips').forEach(function(chipsBox) {
    var room = chipsBox.getAttribute('data-room');
    var panel = chipsBox.closest('.room-tab-panel');
    var picker = panel.querySelector('.color-chip-picker');
    var input = panel.querySelector('.color-chip-input');
    var addBtn = panel.querySelector('.color-chip-add-btn');

    function updateBadge() {
      var badge = roomTabBadge(chipsBox, 'colors');
      if (badge) badge.textContent = chipsBox.querySelectorAll('.color-chip').length;
    }

    function wireRemove(chip) {
      chip.querySelector('.color-chip-remove').addEventListener('click', function() {
        var id = chip.getAttribute('data-id');
        fetch('colors_delete.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ room: room, id: id }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('delete failed');
          chip.remove();
          updateBadge();
        }).catch(function() {
          alert('Nu s-a putut șterge culoarea. Încearcă din nou.');
        });
      });
    }

    function addChip(id, hex, label) {
      var chip = document.createElement('span');
      chip.className = 'color-chip';
      chip.setAttribute('data-id', id);
      chip.innerHTML =
        '<span class="color-chip-swatch"></span>' +
        '<span class="color-chip-label"></span>' +
        '<button type="button" class="color-chip-remove" title="Șterge culoarea">×</button>';
      chip.querySelector('.color-chip-swatch').style.background = hex;
      chip.querySelector('.color-chip-label').textContent = label;
      wireRemove(chip);
      chipsBox.appendChild(chip);
      updateBadge();
    }

    chipsBox.querySelectorAll('.color-chip').forEach(wireRemove);

    function submitAdd() {
      var label = input.value.trim();
      if (!label) return;
      var hex = picker.value;

      fetch('colors_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ room: room, hex: hex, label: label }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');
        addChip(data.id, data.hex, data.label);
        input.value = '';
      }).catch(function() {
        alert('Nu s-a putut adăuga culoarea. Încearcă din nou.');
      });
    }

    addBtn.addEventListener('click', submitAdd);
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); submitAdd(); }
    });
  });

  (function itemModal() {
    var backdrop = document.getElementById('itemModalBackdrop');
    if (!backdrop) return;
    var title = document.getElementById('itemModalTitle');
    var nameInput = document.getElementById('itemModalName');
    var cumparatInput = document.getElementById('itemModalCumparat');
    var montatInput = document.getElementById('itemModalMontat');
    var estimateInput = document.getElementById('itemModalEstimate');
    var actualInput = document.getElementById('itemModalActual');
    var deleteBtn = document.getElementById('itemModalDelete');
    var cancelBtn = document.getElementById('itemModalCancel');
    var saveBtn = document.getElementById('itemModalSave');

    var current = null; // { mode: 'add'|'edit', itemBox, room, category }

    function close() {
      backdrop.hidden = true;
      current = null;
    }

    function openAdd(addBtn) {
      current = { mode: 'add', addBtn: addBtn, room: addBtn.getAttribute('data-room'), category: addBtn.getAttribute('data-category') };
      title.textContent = 'Item nou';
      nameInput.value = '';
      cumparatInput.checked = false;
      montatInput.checked = false;
      estimateInput.value = '';
      actualInput.value = '';
      deleteBtn.hidden = true;
      backdrop.hidden = false;
      nameInput.focus();
    }

    function openEdit(itemBox) {
      current = { mode: 'edit', itemBox: itemBox };
      title.textContent = 'Editează item';
      nameInput.value = itemBox.getAttribute('data-name') || '';
      cumparatInput.checked = itemBox.getAttribute('data-cumparat') === '1';
      montatInput.checked = itemBox.getAttribute('data-montat') === '1';
      estimateInput.value = itemBox.getAttribute('data-price-estimate') || '0';
      actualInput.value = itemBox.getAttribute('data-price-actual') || '0';
      deleteBtn.hidden = false;
      backdrop.hidden = false;
      nameInput.focus();
    }

    function wireEditBtn(btn) {
      btn.addEventListener('click', function() { openEdit(btn.closest('.checklist-item')); });
    }

    function wireFlagCheckboxes(itemBox) {
      itemBox.querySelectorAll('.item-flag input[type=checkbox]').forEach(function(checkbox) {
        checkbox.addEventListener('change', function() {
          var field = checkbox.getAttribute('data-field');
          var done = checkbox.checked;
          var label = checkbox.closest('.item-flag');
          label.classList.toggle('is-done', done);
          checkbox.disabled = true;

          saveItemField(itemBox.getAttribute('data-item-id'), field, done ? '1' : '0').then(function() {
            itemBox.setAttribute('data-' + field, done ? '1' : '0');
            var checklist = itemBox.closest('.checklist');
            var progressBar = checklist.closest('.room').querySelector('.room-progress-bar');
            updateCounts(checklist, progressBar);
          }).catch(function() {
            checkbox.checked = !done;
            label.classList.toggle('is-done', !done);
            alert('Nu s-a putut salva modificarea. Încearcă din nou.');
          }).finally(function() {
            checkbox.disabled = false;
          });
        });
      });
    }

    function createItemElement(item) {
      var box = document.createElement('div');
      box.className = 'checklist-item';
      box.setAttribute('data-item-id', item.id);
      box.setAttribute('data-name', item.name);
      box.setAttribute('data-cumparat', item.cumparat ? '1' : '0');
      box.setAttribute('data-montat', item.montat ? '1' : '0');
      box.setAttribute('data-price-estimate', item.price_estimate);
      box.setAttribute('data-price-actual', item.price_actual);
      box.innerHTML =
        '<div class="item-head">' +
          '<span class="item-name"></span>' +
          '<button type="button" class="item-edit-btn" title="Editează item">✎</button>' +
        '</div>' +
        '<div class="item-flags">' +
          '<label class="item-flag' + (item.cumparat ? ' is-done' : '') + '"><input type="checkbox" data-field="cumparat"' + (item.cumparat ? ' checked' : '') + '><span>Cumpărat</span></label>' +
          '<label class="item-flag' + (item.montat ? ' is-done' : '') + '"><input type="checkbox" data-field="montat"' + (item.montat ? ' checked' : '') + '><span>Montat</span></label>' +
        '</div>' +
        '<div class="item-cost-summary"><span></span><span></span></div>';
      box.querySelector('.item-name').textContent = item.name;
      var costEls = box.querySelectorAll('.item-cost-summary span');
      costEls[0].textContent = 'Est: ' + formatLei(item.price_estimate);
      costEls[0].title = formatEurTitle(item.price_estimate);
      costEls[1].textContent = 'Real: ' + formatLei(item.price_actual);
      costEls[1].title = formatEurTitle(item.price_actual);
      wireEditBtn(box.querySelector('.item-edit-btn'));
      wireFlagCheckboxes(box);
      return box;
    }

    document.querySelectorAll('.item-add-btn').forEach(function(btn) {
      btn.addEventListener('click', function() { openAdd(btn); });
    });
    document.querySelectorAll('.item-edit-btn').forEach(wireEditBtn);
    document.querySelectorAll('.checklist-item').forEach(wireFlagCheckboxes);

    cancelBtn.addEventListener('click', close);
    backdrop.addEventListener('click', function(e) { if (e.target === backdrop) close(); });
    document.addEventListener('keydown', function(e) { if (e.key === 'Escape' && !backdrop.hidden) close(); });

    deleteBtn.addEventListener('click', function() {
      if (!current || current.mode !== 'edit') return;
      if (!confirm('Ștergi acest item din checklist?')) return;
      var itemBox = current.itemBox;
      var itemId = itemBox.getAttribute('data-item-id');
      deleteBtn.disabled = true;
      fetch('checklist_item_delete.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: itemId }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('delete failed');
        var checklist = itemBox.closest('.checklist');
        var progressBar = checklist.closest('.room').querySelector('.room-progress-bar');
        var catBox = itemBox.closest('.checklist-cat');
        itemBox.remove();
        updateCounts(checklist, progressBar);
        updateRoomCostSummary(checklist);
        updateCatCostSummary(catBox);
        close();
      }).catch(function() {
        alert('Nu s-a putut șterge. Încearcă din nou.');
      }).finally(function() {
        deleteBtn.disabled = false;
      });
    });

    saveBtn.addEventListener('click', function() {
      if (!current) return;
      var name = nameInput.value.trim();
      if (name === '') { alert('Numele nu poate fi gol.'); return; }
      var cumparat = cumparatInput.checked ? '1' : '0';
      var montat = montatInput.checked ? '1' : '0';
      var estimate = parseFloat(estimateInput.value); if (isNaN(estimate) || estimate < 0) estimate = 0;
      var actual = parseFloat(actualInput.value); if (isNaN(actual) || actual < 0) actual = 0;

      if (current.mode === 'add') {
        var addBtn = current.addBtn;
        saveBtn.disabled = true;
        fetch('checklist_item_add.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            room: current.room, category: current.category, name: name,
            cumparat: cumparat, montat: montat,
            price_estimate: estimate, price_actual: actual
          }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('add failed');
          var catBox = addBtn.closest('.checklist-cat');
          var itemList = catBox.querySelector('.item-list');
          itemList.appendChild(createItemElement(data.item));
          var checklist = addBtn.closest('.checklist');
          var progressBar = checklist.closest('.room').querySelector('.room-progress-bar');
          updateCounts(checklist, progressBar);
          updateRoomCostSummary(checklist);
          updateCatCostSummary(catBox);
          close();
        }).catch(function() {
          alert('Nu s-a putut adăuga. Încearcă din nou.');
        }).finally(function() {
          saveBtn.disabled = false;
        });
        return;
      }

      var itemBox = current.itemBox;
      var itemId = itemBox.getAttribute('data-item-id');
      saveBtn.disabled = true;
      Promise.all([
        saveItemField(itemId, 'name', name),
        saveItemField(itemId, 'cumparat', cumparat),
        saveItemField(itemId, 'montat', montat),
        saveItemField(itemId, 'price_estimate', estimate),
        saveItemField(itemId, 'price_actual', actual)
      ]).then(function() {
        itemBox.setAttribute('data-name', name);
        itemBox.setAttribute('data-cumparat', cumparat);
        itemBox.setAttribute('data-montat', montat);
        itemBox.setAttribute('data-price-estimate', estimate);
        itemBox.setAttribute('data-price-actual', actual);

        itemBox.querySelector('.item-name').textContent = name;
        var flags = itemBox.querySelectorAll('.item-flag');
        flags[0].classList.toggle('is-done', cumparat === '1');
        flags[0].querySelector('input[type=checkbox]').checked = cumparat === '1';
        flags[1].classList.toggle('is-done', montat === '1');
        flags[1].querySelector('input[type=checkbox]').checked = montat === '1';
        var costEls = itemBox.querySelectorAll('.item-cost-summary span');
        if (costEls.length === 2) {
          costEls[0].textContent = 'Est: ' + formatLei(estimate);
          costEls[0].title = formatEurTitle(estimate);
          costEls[1].textContent = 'Real: ' + formatLei(actual);
          costEls[1].title = formatEurTitle(actual);
        }

        var checklist = itemBox.closest('.checklist');
        var progressBar = checklist.closest('.room').querySelector('.room-progress-bar');
        updateCounts(checklist, progressBar);
        updateRoomCostSummary(checklist);
        updateCatCostSummary(itemBox.closest('.checklist-cat'));
        close();
      }).catch(function() {
        alert('Nu s-a putut salva. Încearcă din nou.');
      }).finally(function() {
        saveBtn.disabled = false;
      });
    });

    function saveItemField(itemId, field, value) {
      return fetch('checklist_item_update.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id: itemId, field: field, value: value }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('save failed');
        return data;
      });
    }

    function updateRoomCostSummary(checklist) {
      var costSummary = checklist.closest('.room').querySelector('.cost-stats');
      var costEls = costSummary ? costSummary.querySelectorAll('.cost-stat-value') : null;
      if (!costEls || costEls.length !== 2) return;
      var estimateTotal = 0, actualTotal = 0;
      checklist.querySelectorAll('.checklist-item').forEach(function(itemBox) {
        estimateTotal += parseFloat(itemBox.getAttribute('data-price-estimate')) || 0;
        actualTotal += parseFloat(itemBox.getAttribute('data-price-actual')) || 0;
      });
      costEls[0].textContent = formatLei(estimateTotal);
      costEls[0].title = formatEurTitle(estimateTotal);
      costEls[1].textContent = formatLei(actualTotal);
      costEls[1].title = formatEurTitle(actualTotal);
    }

    function updateCatCostSummary(catBox) {
      var costEls = catBox.querySelectorAll('.cat-cost-summary span');
      if (costEls.length !== 2) return;
      var estimateTotal = 0, actualTotal = 0;
      catBox.querySelectorAll('.checklist-item').forEach(function(itemBox) {
        estimateTotal += parseFloat(itemBox.getAttribute('data-price-estimate')) || 0;
        actualTotal += parseFloat(itemBox.getAttribute('data-price-actual')) || 0;
      });
      costEls[0].textContent = 'Cost estimat: ' + formatLei(estimateTotal);
      costEls[0].title = formatEurTitle(estimateTotal);
      costEls[1].textContent = 'Cost real: ' + formatLei(actualTotal);
      costEls[1].title = formatEurTitle(actualTotal);
    }
  })();

  document.querySelectorAll('.notes').forEach(function(notesBox) {
    var room = notesBox.getAttribute('data-room');
    var list = notesBox.querySelector('.notes-list');
    var input = notesBox.querySelector('.note-input');
    var charcount = notesBox.querySelector('.note-charcount');
    var addBtn = notesBox.querySelector('.note-add-btn');
    var spoilerCount = roomTabBadge(notesBox, 'notes');

    function updateSpoilerCount() {
      if (spoilerCount) spoilerCount.textContent = list.querySelectorAll('.note-item').length;
    }

    function updateCharcount() {
      var len = input.value.length;
      charcount.textContent = len + '/500';
      charcount.classList.toggle('is-over', len > 500);
      addBtn.disabled = len === 0 || len > 500;
    }

    function escapeHtml(s) {
      return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    function wireItem(item) {
      var textDiv = item.querySelector('.note-text');
      var editBtn = item.querySelector('.note-edit-btn');
      var delBtn = item.querySelector('.note-delete-btn');
      var editInput = item.querySelector('.note-edit-input');
      var editCharcount = item.querySelector('.note-edit-row .note-charcount');
      var saveBtn = item.querySelector('.note-edit-save-btn');
      var cancelBtn = item.querySelector('.note-edit-cancel-btn');

      function updateEditCharcount() {
        var len = editInput.value.length;
        editCharcount.textContent = len + '/500';
        editCharcount.classList.toggle('is-over', len > 500);
        saveBtn.disabled = len === 0 || len > 500;
      }

      function refreshEmptyMarker() {
        var existing = notesBox.querySelector('.notes-empty-marker');
        if (!list.querySelector('.note-item')) {
          if (!existing) {
            var empty = document.createElement('p');
            empty.className = 'notes-empty notes-empty-marker';
            empty.textContent = 'Nicio notiță încă.';
            list.after(empty);
          }
        } else if (existing) {
          existing.remove();
        }
      }

      delBtn.addEventListener('click', function() {
        var id = item.getAttribute('data-id');
        var parent = item.parentNode;
        var nextSibling = item.nextSibling;

        item.remove();
        updateSpoilerCount();
        refreshEmptyMarker();

        casaUndoAction({
          message: 'Notiță ștearsă.',
          commit: function() {
            fetch('notes_delete.php', {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({ id: id }).toString()
            }).catch(function() {});
          },
          undo: function() {
            if (nextSibling && nextSibling.parentNode === parent) parent.insertBefore(item, nextSibling);
            else parent.appendChild(item);
            updateSpoilerCount();
            refreshEmptyMarker();
          }
        });
      });

      editBtn.addEventListener('click', function() {
        editInput.value = textDiv.getAttribute('data-raw') || '';
        updateEditCharcount();
        item.classList.add('is-editing');
        editInput.focus();
      });

      cancelBtn.addEventListener('click', function() {
        item.classList.remove('is-editing');
      });

      editInput.addEventListener('input', updateEditCharcount);

      saveBtn.addEventListener('click', function() {
        var note = editInput.value.trim();
        if (!note || note.length > 500) return;
        var id = item.getAttribute('data-id');

        fetch('notes_update.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ id: id, note: note }).toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('update failed');
          textDiv.setAttribute('data-raw', data.note);
          textDiv.innerHTML = escapeHtml(data.note).replace(/\n/g, '<br>');
          item.classList.remove('is-editing');
        }).catch(function() {
          alert('Nu s-a putut salva notița. Încearcă din nou.');
        });
      });
    }

    notesBox.querySelectorAll('.note-item').forEach(wireItem);
    updateCharcount();

    input.addEventListener('input', updateCharcount);

    addBtn.addEventListener('click', function() {
      var note = input.value.trim();
      if (!note || note.length > 500) return;

      fetch('notes_add.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ room: room, note: note }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('add failed');

        var emptyMarker = notesBox.querySelector('.notes-empty-marker');
        if (emptyMarker) emptyMarker.remove();

        var item = document.createElement('div');
        item.className = 'note-item';
        item.setAttribute('data-id', data.id);
        item.innerHTML =
          '<div class="note-date-col"></div>' +
          '<div class="note-body">' +
            '<div class="note-text"></div>' +
            '<div class="note-meta">' +
              '<span class="note-date"><span class="note-author"></span> · <span class="note-date-value"></span></span>' +
              '<div class="note-actions">' +
                '<button class="note-edit-btn" title="Editează notița">✎</button>' +
                '<button class="note-delete-btn" title="Șterge notița">✕</button>' +
              '</div>' +
            '</div>' +
            '<div class="note-edit-row">' +
              '<textarea class="note-edit-input" maxlength="500"></textarea>' +
              '<div class="note-add-footer">' +
                '<span class="note-charcount">0/500</span>' +
                '<div class="note-edit-actions">' +
                  '<button type="button" class="note-edit-save-btn">Salvează</button>' +
                  '<button type="button" class="note-edit-cancel-btn">Anulează</button>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>';

        var textDiv = item.querySelector('.note-text');
        textDiv.setAttribute('data-raw', data.note);
        textDiv.innerHTML = escapeHtml(data.note).replace(/\n/g, '<br>');
        item.querySelector('.note-date-col').textContent = data.dateShort;
        item.querySelector('.note-author').textContent = data.author;
        item.querySelector('.note-date-value').textContent = data.date;

        list.insertBefore(item, list.firstChild);
        wireItem(item);
        updateSpoilerCount();

        input.value = '';
        updateCharcount();
      }).catch(function() {
        alert('Nu s-a putut salva notița. Încearcă din nou.');
      });
    });
  });

  function updateCounts(checklist, progressBar) {
    var totalAll = 0, doneAll = 0;
    checklist.querySelectorAll('.checklist-cat').forEach(function(catBox) {
      var flags = catBox.querySelectorAll('.item-flag');
      var doneCount = 0;
      flags.forEach(function(f) { if (f.classList.contains('is-done')) doneCount++; });
      var catPct = flags.length > 0 ? Math.round(doneCount / flags.length * 100) : 0;
      var badge = catBox.querySelector('.cat-badge');
      badge.textContent = doneCount + '/' + flags.length;
      badge.classList.toggle('is-complete', flags.length > 0 && doneCount === flags.length);
      catBox.querySelector('.cat-progress-bar').style.width = catPct + '%';
      totalAll += flags.length;
      doneAll += doneCount;
    });
    var pct = totalAll > 0 ? Math.round(doneAll / totalAll * 100) : 0;
    progressBar.style.width = pct + '%';
    var room = checklist.closest('.room');
    var statusEl = room ? room.querySelector('.room-title-status') : null;
    if (statusEl) statusEl.textContent = 'Status: ' + pct + '%';
  }

  document.querySelectorAll('.upload-form').forEach(function(form) {
    var input = form.querySelector('input[type=file]');
    var btn = form.querySelector('.upload-btn');
    input.addEventListener('change', function() {
      if (!input.files.length) return;
      btn.classList.add('is-uploading');
      btn.firstChild.textContent = '⏳ Se încarcă...';
      form.submit();
    });
  });

  document.getElementById('lbClose').addEventListener('click', closeLightbox);
  document.getElementById('lbPrev').addEventListener('click', function() { show(-1); });
  document.getElementById('lbNext').addEventListener('click', function() { show(1); });
  lightbox.addEventListener('click', function(e) { if (e.target === lightbox) closeLightbox(); });
  document.addEventListener('keydown', function(e) {
    if (!lightbox.classList.contains('is-open')) return;
    if (e.key === 'Escape') closeLightbox();
    if (e.key === 'ArrowLeft') show(-1);
    if (e.key === 'ArrowRight') show(1);
  });

  // Keeps --header-h in sync with the real (sticky) site header height, so each room's own
  // sticky title (mobile only, see CSS) tucks in right below it instead of overlapping or
  // leaving a gap - re-measured on resize and whenever the burger nav opens/closes, since that
  // changes the header's height on narrow screens.
  var heroHeader = document.querySelector('header.hero');
  function updateHeaderHeightVar() {
    if (heroHeader) document.documentElement.style.setProperty('--header-h', heroHeader.offsetHeight + 'px');
  }
  updateHeaderHeightVar();
  window.addEventListener('resize', updateHeaderHeightVar);

  // Burger cu meniul principal (Construcție/Design/Link-uri/Jurnal), pe ecrane inguste
  var navToggle = document.getElementById('navToggle');
  var heroNav = document.getElementById('heroNav');
  if (navToggle && heroNav) {
    navToggle.addEventListener('click', function() {
      var open = heroNav.classList.toggle('is-open');
      navToggle.classList.toggle('is-open', open);
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      updateHeaderHeightVar();
    });
  }

  // Burger cu camerele (ecrane inguste)
  var burgerBtn = document.getElementById('roomBurgerBtn');
  var burgerPanel = document.getElementById('roomBurgerPanel');
  if (burgerBtn && burgerPanel) {
    var closeBurger = function() {
      burgerPanel.classList.remove('is-open');
      burgerBtn.classList.remove('is-open');
      burgerBtn.setAttribute('aria-expanded', 'false');
    };
    burgerBtn.addEventListener('click', function() {
      var open = burgerPanel.classList.toggle('is-open');
      burgerBtn.classList.toggle('is-open', open);
      burgerBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    burgerPanel.querySelectorAll('a').forEach(function(a) {
      a.addEventListener('click', closeBurger);
    });
    document.addEventListener('click', function(e) {
      if (!burgerPanel.classList.contains('is-open')) return;
      if (burgerPanel.contains(e.target) || burgerBtn.contains(e.target)) return;
      closeBurger();
    });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') closeBurger();
    });
  }

  // Evidentiaza camera curenta (in toate meniurile) pe masura ce se deruleaza pagina
  var roomSections = document.querySelectorAll('section.room');
  var navLinks = document.querySelectorAll('.room-nav a, .room-floating-nav a, .room-burger-panel .burger-links a');
  if (roomSections.length && navLinks.length && 'IntersectionObserver' in window) {
    var setActive = function(slug) {
      navLinks.forEach(function(a) {
        a.classList.toggle('is-active', a.getAttribute('href') === '#' + slug);
      });
    };
    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) setActive(entry.target.id);
      });
    }, { rootMargin: '-40% 0px -55% 0px' }); // "activ" cand sectiunea trece prin banda din mijlocul ecranului
    roomSections.forEach(function(section) { observer.observe(section); });
    setActive(roomSections[0].id); // camera implicita, inainte de primul scroll
  }
})();

// Redenumire / ștergere cameră - butoanele din antetul fiecărei secțiuni de cameră.
(function() {
  document.querySelectorAll('section.room').forEach(function(room) {
    var slug = room.getAttribute('data-room-slug');
    var textEl = room.querySelector('.room-title-text');
    var input = room.querySelector('.room-title-input');
    var renameBtn = room.querySelector('.room-rename-btn');
    var deleteBtn = room.querySelector('.room-delete-btn');
    var saveBtn = room.querySelector('.room-title-save-btn');
    var cancelBtn = room.querySelector('.room-title-cancel-btn');
    var moveBtns = room.querySelectorAll('.room-move-btn');

    // Mutare cameră mai sus / mai jos. Ordinea se salvează pe server, apoi reîncărcăm pagina:
    // camerele au conținut greu (poze, checklist, note), deci le mutăm în DOM ar fi mai fragil
    // decât o reîncărcare simplă.
    moveBtns.forEach(function(btn) {
      btn.addEventListener('click', function() {
        moveBtns.forEach(function(b) { b.disabled = true; });
        var body = new URLSearchParams({ slug: slug, direction: btn.getAttribute('data-dir') });
        fetch('room_reorder.php', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body.toString()
        }).then(function(res) { return res.json(); }).then(function(data) {
          if (!data.ok) throw new Error('reorder failed');
          if (data.moved) location.reload();
          else moveBtns.forEach(function(b) { b.disabled = false; });
        }).catch(function() {
          alert('Nu s-a putut muta camera. Încearcă din nou.');
          moveBtns.forEach(function(b) { b.disabled = false; });
        });
      });
    });

    function enterEdit() {
      textEl.hidden = true;
      renameBtn.hidden = true;
      deleteBtn.hidden = true;
      moveBtns.forEach(function(b) { b.hidden = true; });
      input.hidden = false;
      saveBtn.hidden = false;
      cancelBtn.hidden = false;
      input.value = textEl.textContent;
      input.focus();
      input.select();
    }
    function exitEdit() {
      textEl.hidden = false;
      renameBtn.hidden = false;
      deleteBtn.hidden = false;
      moveBtns.forEach(function(b) { b.hidden = false; });
      input.hidden = true;
      saveBtn.hidden = true;
      cancelBtn.hidden = true;
    }

    renameBtn.addEventListener('click', enterEdit);
    cancelBtn.addEventListener('click', exitEdit);
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') { e.preventDefault(); saveBtn.click(); }
      if (e.key === 'Escape') exitEdit();
    });

    saveBtn.addEventListener('click', function() {
      var name = input.value.trim();
      if (!name) return;
      fetch('room_rename.php', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ slug: slug, name: name }).toString()
      }).then(function(res) { return res.json(); }).then(function(data) {
        if (!data.ok) throw new Error('rename failed');
        textEl.textContent = data.name;
        document.querySelectorAll('a[href="#' + slug + '"]').forEach(function(a) {
          if (a.hasAttribute('title')) a.setAttribute('title', data.name);
          var icon = a.querySelector('.room-nav-icon');
          if (icon) {
            // Burger-panel link: icon span + a trailing text node with the name - only replace that.
            a.lastChild.textContent = data.name;
          } else if (!a.closest('.room-floating-nav')) {
            // Plain room-nav link (no icon, no letter-code span) - safe to replace outright.
            a.textContent = data.name;
          }
        });
        exitEdit();
      }).catch(function() {
        alert('Nu s-a putut redenumi camera. Încearcă din nou.');
      });
    });

    deleteBtn.addEventListener('click', function() {
      if (!confirm('Ștergi camera "' + textEl.textContent + '" și toate pozele/notele/prețurile ei? Nu se poate anula.')) return;
      var form = document.createElement('form');
      form.method = 'post';
      form.action = 'room_delete.php';
      var slugInput = document.createElement('input');
      slugInput.type = 'hidden';
      slugInput.name = 'slug';
      slugInput.value = slug;
      form.appendChild(slugInput);
      document.body.appendChild(form);
      form.submit();
    });
  });
})();
</script>

</body>
</html>
