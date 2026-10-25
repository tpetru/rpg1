<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

// Los Santos city bounds in game coordinates (approximate) - the map shows ONLY this area.
// Same calibration as maps.php, reused verbatim so the two maps line up pixel-for-pixel.
define('LS_MIN_X', -732.0);
define('LS_MAX_X', 3000.0);
define('LS_MIN_Y', -3000.0);
define('LS_MAX_Y', 888.0);

// Converts game coordinates to percentages on the map (0-100, Y flipped: north = up)
function ucp_world_to_pct($x, $y) {
    $px = (((float)$x - LS_MIN_X) / (LS_MAX_X - LS_MIN_X)) * 100.0;
    $py = 100.0 - (((float)$y - LS_MIN_Y) / (LS_MAX_Y - LS_MIN_Y)) * 100.0;
    $px = max(0.5, min(99.5, $px));
    $py = max(0.5, min(99.5, $py));
    return [$px, $py];
}

// True if the point falls inside the Los Santos zone defined above
function ucp_in_los_santos($x, $y) {
    $x = (float)$x; $y = (float)$y;
    return $x >= LS_MIN_X && $x <= LS_MAX_X && $y >= LS_MIN_Y && $y <= LS_MAX_Y;
}

define('WORLD_MIN', -3000.0);
define('WORLD_MAX', 3000.0);
$worldSpan  = WORLD_MAX - WORLD_MIN;
$cropWFrac  = (LS_MAX_X - LS_MIN_X) / $worldSpan;
$cropHFrac  = (LS_MAX_Y - LS_MIN_Y) / $worldSpan;
$mapImgSizeX = round((1 / $cropWFrac) * 100, 2);
$mapImgSizeY = round((1 / $cropHFrac) * 100, 2);
$cropX0Frac = (LS_MIN_X - WORLD_MIN) / $worldSpan;
$cropY0Frac = (WORLD_MAX - LS_MAX_Y) / $worldSpan;
$mapImgLeft = round((100 - $mapImgSizeX) * $cropX0Frac / (1 - $cropWFrac), 2);
$mapImgTop  = round((100 - $mapImgSizeY) * $cropY0Frac / (1 - $cropHFrac), 2);

$pid = ucp_current_player_id();

// event_* tables are created by the gamemode on startup (CREATE TABLE IF NOT EXISTS) - may not
// exist yet on a fresh DB that hasn't had the gamemode run since this feature was added.
try {
    $res = $mysqli->query("SELECT `name`, `state` FROM `event_config` WHERE `id` = 1 LIMIT 1");
    $eventConfig = $res ? $res->fetch_assoc() : null;
} catch (mysqli_sql_exception $e) {
    $eventConfig = null;
}
$eventName  = $eventConfig['name'] ?? 'Holiday';
$eventState = $eventConfig ? (int)$eventConfig['state'] : 0;
$eventStateLabel = [0 => t('Inactive'), 1 => t('Stopped'), 2 => t('Paused'), 3 => t('Active')][$eventState] ?? t('Inactive');

// One row per placed quest object, joined to its quest (for the name + enabled flag) and left-joined
// to this player's own pickups (for the visited flag) - a point never reappears as "visited" for
// anyone else, it's tracked per player just like in-game.
try {
    $stmt = $mysqli->prepare(
        "SELECT o.id, o.x, o.y, q.name AS quest_name, q.enabled AS quest_enabled,
                (p.object_id IS NOT NULL) AS visited
         FROM `event_objects` o
         JOIN `event_quests` q ON q.quest_key = o.quest_key
         LEFT JOIN `event_pickups` p ON p.object_id = o.id AND p.pID = ?
         ORDER BY o.id ASC"
    );
    $stmt->bind_param('i', $pid);
    $stmt->execute();
    $allQuestPoints = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
} catch (mysqli_sql_exception $e) {
    $allQuestPoints = [];
}

$questPoints = array_values(array_filter($allQuestPoints, function ($p) { return ucp_in_los_santos($p['x'], $p['y']); }));

// Bucket each point into exactly one of the 3 states - disabled wins even if it was already
// visited before an admin turned its quest off, since a disabled quest can't be worked on anymore.
$disabledPoints   = [];
$notVisitedPoints = [];
$visitedPoints    = [];
foreach ($questPoints as $p) {
    if (!$p['quest_enabled'])   $disabledPoints[] = $p;
    elseif ($p['visited'])      $visitedPoints[] = $p;
    else                        $notVisitedPoints[] = $p;
}
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Holiday Quest Map</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  main { max-width: 1400px; }
  .map-wrap { max-width: 1400px; margin: 0 auto; }
  .event-note { color: var(--muted); font-size: 0.85rem; margin: 0 0 14px; }
  .event-note strong { color: var(--text); font-weight: 600; }
  .map-legend-actions { display: flex; gap: 8px; margin-bottom: 10px; }
  .map-legend-actions button {
    background: var(--panel-2); color: var(--text); border: 1px solid var(--border);
    border-radius: 999px; padding: 5px 12px; font-size: 0.8rem; cursor: pointer;
  }
  .map-legend-actions button:hover { border-color: var(--accent-soft); color: var(--accent); }
  .map-legend { display: flex; flex-wrap: wrap; gap: 14px; margin-bottom: 14px; }
  .map-legend label { display: flex; align-items: center; gap: 7px; font-size: 0.88rem; color: var(--text); cursor: pointer; user-select: none; }
  .map-legend input { accent-color: var(--accent); }
  .legend-dot { width: 11px; height: 11px; border-radius: 50%; display: inline-block; border: 1px solid rgba(255,255,255,0.4); }
  .dot-disabled { background: #000000; }
  .dot-notvisited { background: #ef4444; }
  .dot-visited { background: #22c55e; }

  .map-frame {
    position: relative;
    width: 100%;
    aspect-ratio: 1 / 1;
    border-radius: 12px;
    overflow: hidden;
    border: 1px solid var(--border);
    background-color: #0a1a2b;
  }
  .map-img {
    position: absolute;
    max-width: none;
    max-height: none;
  }
  .map-shade {
    position: absolute; inset: 0;
    background: linear-gradient(180deg, rgba(10,20,30,0.15), rgba(10,20,30,0.35));
    pointer-events: none;
  }
  .pin {
    position: absolute; width: 16px; height: 16px; border-radius: 50%;
    transform: translate(-50%, -50%);
    border: 1px solid rgba(0,0,0,0.35);
    cursor: pointer;
    box-shadow: 0 0 4px rgba(0,0,0,0.6);
  }
  .pin:hover { width: 21px; height: 21px; z-index: 5; }
  .pin-disabled { background: #000000; border-color: rgba(255,255,255,0.5); }
  .pin-notvisited { background: #ef4444; }
  .pin-visited { background: #22c55e; }

  .pin-tooltip {
    position: absolute; bottom: 130%; left: 50%; transform: translateX(-50%);
    background: #11141b; border: 1px solid var(--border); border-radius: 6px;
    padding: 6px 10px; font-size: 0.76rem; white-space: nowrap;
    line-height: 1.5; text-align: center;
    opacity: 0; pointer-events: none; transition: opacity 0.1s;
  }
  .pin:hover .pin-tooltip { opacity: 1; }

  .map-note { color: var(--muted); font-size: 0.8rem; margin-top: 10px; }
</style>
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>🎁 <?= t('Holiday Quest Map') ?></h1>
  <p class="event-note"><?= t('Event:') ?> <strong><?= ucp_escape($eventName) ?></strong> — <?= $eventStateLabel ?></p>

  <div class="map-wrap">
    <div class="card">
      <?php if (empty($questPoints)): ?>
        <p class="map-note"><?= t('No quest points have been placed yet.') ?></p>
      <?php else: ?>
        <div class="map-legend-actions">
          <button type="button" id="checkAllBtn"><?= t('Check All') ?></button>
          <button type="button" id="uncheckAllBtn"><?= t('Uncheck All') ?></button>
        </div>
        <div class="map-legend">
          <label><input type="checkbox" checked data-cat="disabled"><span class="legend-dot dot-disabled"></span><?= t('Disabled quest') ?> (<?= count($disabledPoints) ?>)</label>
          <label><input type="checkbox" checked data-cat="notvisited"><span class="legend-dot dot-notvisited"></span><?= t('Not visited') ?> (<?= count($notVisitedPoints) ?>)</label>
          <label><input type="checkbox" checked data-cat="visited"><span class="legend-dot dot-visited"></span><?= t('Visited') ?> (<?= count($visitedPoints) ?>)</label>
        </div>

        <div class="map-frame" id="mapFrame">
          <img class="map-img" src="assets/img/maps/sanandreas.jpg?v=1" alt="San Andreas Map"
               style="width:<?= $mapImgSizeX ?>%; height:<?= $mapImgSizeY ?>%; left:<?= $mapImgLeft ?>%; top:<?= $mapImgTop ?>%;">
          <div class="map-shade"></div>

          <?php foreach ($disabledPoints as $p): [$px, $py] = ucp_world_to_pct($p['x'], $p['y']); ?>
            <div class="pin pin-disabled" data-cat="disabled" style="left:<?= $px ?>%; top:<?= $py ?>%">
              <div class="pin-tooltip">[ <?= ucp_escape($p['quest_name']) ?> ]<br>[ <?= t('Disabled') ?> ]</div>
            </div>
          <?php endforeach; ?>

          <?php foreach ($notVisitedPoints as $p): [$px, $py] = ucp_world_to_pct($p['x'], $p['y']); ?>
            <div class="pin pin-notvisited" data-cat="notvisited" style="left:<?= $px ?>%; top:<?= $py ?>%">
              <div class="pin-tooltip">[ <?= ucp_escape($p['quest_name']) ?> ]<br>[ <?= t('Not visited') ?> ]</div>
            </div>
          <?php endforeach; ?>

          <?php foreach ($visitedPoints as $p): [$px, $py] = ucp_world_to_pct($p['x'], $p['y']); ?>
            <div class="pin pin-visited" data-cat="visited" style="left:<?= $px ?>%; top:<?= $py ?>%">
              <div class="pin-tooltip">[ <?= ucp_escape($p['quest_name']) ?> ]<br>[ <?= t('Visited') ?> ]</div>
            </div>
          <?php endforeach; ?>
        </div>

        <p class="map-note"><?= t('San Andreas map, zoomed in on the Los Santos area. Points outside the city are not shown. Hover over a point for details.') ?></p>
      <?php endif; ?>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

<script>
document.querySelectorAll('.map-legend input[type=checkbox]').forEach(function(cb) {
  cb.addEventListener('change', function() {
    var cat = this.dataset.cat;
    var show = this.checked;
    document.querySelectorAll('.pin[data-cat="' + cat + '"]').forEach(function(pin) {
      pin.style.display = show ? '' : 'none';
    });
  });
});

var checkAllBtn = document.getElementById('checkAllBtn');
var uncheckAllBtn = document.getElementById('uncheckAllBtn');
if (checkAllBtn) {
  checkAllBtn.addEventListener('click', function() {
    document.querySelectorAll('.map-legend input[type=checkbox]').forEach(function(cb) {
      cb.checked = true;
      cb.dispatchEvent(new Event('change'));
    });
  });
}
if (uncheckAllBtn) {
  uncheckAllBtn.addEventListener('click', function() {
    document.querySelectorAll('.map-legend input[type=checkbox]').forEach(function(cb) {
      cb.checked = false;
      cb.dispatchEvent(new Event('change'));
    });
  });
}
</script>

</body>
</html>
