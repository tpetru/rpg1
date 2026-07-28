<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

// Los Santos city bounds in game coordinates (approximate) - the map shows ONLY this area
define('LS_MIN_X', -732.0); // -10% (less zoomed out)
define('LS_MAX_X', 3000.0);
define('LS_MIN_Y', -3000.0);
define('LS_MAX_Y', 888.0);  // -10% (less zoomed out)

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

// Calibration for the real map image (sanandreas.jpg = the full San Andreas state map): the image
// covers the entire game world, -3000..3000 on X/Y. We compute how big the image needs to be
// rendered (in % of the visible frame) and what offset (left/top, also in %) to show ONLY the
// Los Santos area, aligned with the transform above (ucp_world_to_pct). We use an absolutely
// positioned <img> (not background-size) so it's easy to check/debug in the browser.
define('WORLD_MIN', -3000.0);
define('WORLD_MAX', 3000.0);
$worldSpan  = WORLD_MAX - WORLD_MIN;
$cropWFrac  = (LS_MAX_X - LS_MIN_X) / $worldSpan; // % of the image width that represents Los Santos
$cropHFrac  = (LS_MAX_Y - LS_MIN_Y) / $worldSpan;
$mapImgSizeX = round((1 / $cropWFrac) * 100, 2); // image width, in % of the frame (>100% = zoom)
$mapImgSizeY = round((1 / $cropHFrac) * 100, 2);
$cropX0Frac = (LS_MIN_X - WORLD_MIN) / $worldSpan;
$cropY0Frac = (WORLD_MAX - LS_MAX_Y) / $worldSpan; // Y flipped (north = up in the image)
$mapImgLeft = round((100 - $mapImgSizeX) * $cropX0Frac / (1 - $cropWFrac), 2);
$mapImgTop  = round((100 - $mapImgSizeY) * $cropY0Frac / (1 - $cropHFrac), 2);

$allBusinesses = $mysqli->query("SELECT `id`,`name`,`loc_x`,`loc_y`,`owned`,`owner`,`is_for_sale` FROM `businesses` WHERE `loc_x` != 0 OR `loc_y` != 0")->fetch_all(MYSQLI_ASSOC);
$allShops      = $mysqli->query("SELECT `shopID`,`shopLocX`,`shopLocY` FROM `shops` WHERE `shopLocX` != 0 OR `shopLocY` != 0")->fetch_all(MYSQLI_ASSOC);
$allFastfood   = $mysqli->query("SELECT `ffID`,`ffName`,`ffType`,`ffLocX`,`ffLocY` FROM `fastfood` WHERE `ffLocX` != 0 OR `ffLocY` != 0")->fetch_all(MYSQLI_ASSOC);
$allFactions   = $mysqli->query("SELECT `id`,`name`,`lead`,`hq_x`,`hq_y` FROM `factions` WHERE `hq_x` != 0 OR `hq_y` != 0")->fetch_all(MYSQLI_ASSOC);
$allHouses     = $mysqli->query("SELECT `id`,`type`,`loc_x`,`loc_y`,`owned`,`owner`,`is_for_sale` FROM `houses` WHERE `loc_x` != 0 OR `loc_y` != 0")->fetch_all(MYSQLI_ASSOC);
$allHotels     = $mysqli->query("SELECT `id`,`loc_x`,`loc_y`,`owned`,`owner`,`is_for_sale` FROM `hotels` WHERE `loc_x` != 0 OR `loc_y` != 0")->fetch_all(MYSQLI_ASSOC);
$allAtms       = $mysqli->query("SELECT `atmID`,`atmLocX`,`atmLocY`,`atmBankOwner` FROM `atms` WHERE `atmLocX` != 0 OR `atmLocY` != 0")->fetch_all(MYSQLI_ASSOC);
$allFarms      = $mysqli->query("SELECT `id`,`name`,`x`,`y`,`isOwned`,`owner`,`is_for_sale` FROM `farms` WHERE `x` != 0 OR `y` != 0")->fetch_all(MYSQLI_ASSOC);
$allLocations  = $mysqli->query("SELECT `locID`,`locName`,`locX`,`locY`,`locCategory` FROM `locations_admin` WHERE `locForGPS` = 1")->fetch_all(MYSQLI_ASSOC);

$businesses = array_values(array_filter($allBusinesses, function($b) { return ucp_in_los_santos($b['loc_x'], $b['loc_y']); }));
$shops      = array_values(array_filter($allShops, function($s) { return ucp_in_los_santos($s['shopLocX'], $s['shopLocY']); }));
$fastfood   = array_values(array_filter($allFastfood, function($f) { return ucp_in_los_santos($f['ffLocX'], $f['ffLocY']); }));
$factions   = array_values(array_filter($allFactions, function($fac) { return ucp_in_los_santos($fac['hq_x'], $fac['hq_y']); }));
$houses     = array_values(array_filter($allHouses, function($h) { return ucp_in_los_santos($h['loc_x'], $h['loc_y']); }));
$hotels     = array_values(array_filter($allHotels, function($h) { return ucp_in_los_santos($h['loc_x'], $h['loc_y']); }));
$atms       = array_values(array_filter($allAtms, function($a) { return ucp_in_los_santos($a['atmLocX'], $a['atmLocY']); }));
$farms      = array_values(array_filter($allFarms, function($f) { return ucp_in_los_santos($f['x'], $f['y']); }));
$locationsInLS = array_values(array_filter($allLocations, function($l) { return ucp_in_los_santos($l['locX'], $l['locY']); }));
$jobLocations  = array_values(array_filter($locationsInLS, function($l) { return strcasecmp($l['locCategory'], 'Job') === 0; }));
$locations     = array_values(array_filter($locationsInLS, function($l) { return strcasecmp($l['locCategory'], 'Job') !== 0; }));

$ffTypeName   = [1 => 'Pizza', 2 => 'Burger', 3 => 'Cluckin Bell', 4 => 'Desert'];
$houseTypeName = [1 => 'Villa', 2 => 'City House', 3 => 'Apartment', 4 => 'Countryside House'];

// Name of the "bank" business by id (for the ATM tooltips) - looked up in the full, unfiltered list
$bizNameById = [];
foreach ($allBusinesses as $b) { $bizNameById[(int)$b['id']] = $b['name']; }

// Renders the "[ ForSale ]" or "[ owner name ]" line - an unowned house/business/hotel/farm
// is treated as "for sale" (it can be bought with the usual command), same as isForSale explicit
function ucp_owner_line($owned, $ownerName, $isForSale) {
    if ($isForSale || !$owned) return '[ ForSale ]';
    return '[ ' . ucp_escape($ownerName) . ' ]';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Los Santos Map</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  main { max-width: 1400px; }
  .map-wrap { max-width: 1400px; margin: 0 auto; }
  .map-legend-actions { display: flex; gap: 8px; margin-bottom: 10px; }
  .map-legend-actions button {
    background: var(--panel-2); color: var(--text); border: 1px solid var(--border);
    border-radius: 999px; padding: 5px 12px; font-size: 0.8rem; cursor: pointer;
  }
  .map-legend-actions button:hover { border-color: var(--accent); color: var(--accent); }
  .map-legend { display: flex; flex-wrap: wrap; gap: 14px; margin-bottom: 14px; }
  .map-legend label { display: flex; align-items: center; gap: 7px; font-size: 0.88rem; color: var(--text); cursor: pointer; user-select: none; }
  .map-legend input { accent-color: var(--accent); }
  .legend-dot { width: 11px; height: 11px; border-radius: 50%; display: inline-block; border: 1px solid rgba(255,255,255,0.4); }
  .dot-biz { background: #ffcc00; }
  .dot-shop { background: #5b9dff; }
  .dot-food { background: #ff5d5d; }
  .dot-faction { background: #3ecf8e; }
  .dot-house { background: #ff8c42; }
  .dot-hotel { background: #b46eff; }
  .dot-atm { background: #14b8a6; }
  .dot-farm { background: #a3e635; }
  .dot-loc { background: #f472b6; }
  .dot-job { background: #000000; }

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
  .city-label {
    position: absolute; transform: translate(-50%, -50%);
    color: rgba(255,255,255,0.45); font-size: 0.78rem; letter-spacing: 0.5px;
    pointer-events: none; white-space: nowrap; text-transform: uppercase;
  }
  .pin {
    position: absolute; width: 16px; height: 16px; border-radius: 50%;
    transform: translate(-50%, -50%);
    border: 1px solid rgba(0,0,0,0.35);
    cursor: pointer;
    box-shadow: 0 0 4px rgba(0,0,0,0.6);
  }
  .pin:hover { width: 21px; height: 21px; z-index: 5; }
  .pin-biz { background: #ffcc00; }
  .pin-shop { background: #5b9dff; }
  .pin-food { background: #ff5d5d; }
  .pin-faction { background: #3ecf8e; width: 19px; height: 19px; }
  .pin-house { background: #ff8c42; }
  .pin-hotel { background: #b46eff; }
  .pin-atm { background: #14b8a6; }
  .pin-farm { background: #a3e635; }
  .pin-loc { background: #f472b6; }
  .pin-job { background: #000000; border-color: rgba(255,255,255,0.5); }

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

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <h1>🗺️ Los Santos Map</h1>

  <div class="map-wrap">
    <div class="card">
      <div class="map-legend-actions">
        <button type="button" id="checkAllBtn">Check All</button>
        <button type="button" id="uncheckAllBtn">Uncheck All</button>
      </div>
      <div class="map-legend">
        <label><input type="checkbox" checked data-cat="biz"><span class="legend-dot dot-biz"></span>Businesses (<?= count($businesses) ?>)</label>
        <label><input type="checkbox" checked data-cat="shop"><span class="legend-dot dot-shop"></span>Shops (<?= count($shops) ?>)</label>
        <label><input type="checkbox" checked data-cat="food"><span class="legend-dot dot-food"></span>Fast-food (<?= count($fastfood) ?>)</label>
        <label><input type="checkbox" checked data-cat="faction"><span class="legend-dot dot-faction"></span>Factions (<?= count($factions) ?>)</label>
        <label><input type="checkbox" checked data-cat="house"><span class="legend-dot dot-house"></span>Houses (<?= count($houses) ?>)</label>
        <label><input type="checkbox" checked data-cat="hotel"><span class="legend-dot dot-hotel"></span>Hotels (<?= count($hotels) ?>)</label>
        <label><input type="checkbox" checked data-cat="atm"><span class="legend-dot dot-atm"></span>ATMs (<?= count($atms) ?>)</label>
        <label><input type="checkbox" checked data-cat="farm"><span class="legend-dot dot-farm"></span>Farms (<?= count($farms) ?>)</label>
        <label><input type="checkbox" checked data-cat="loc"><span class="legend-dot dot-loc"></span>Locations (<?= count($locations) ?>)</label>
        <label><input type="checkbox" checked data-cat="job"><span class="legend-dot dot-job"></span>Jobs (<?= count($jobLocations) ?>)</label>
      </div>

      <div class="map-frame" id="mapFrame">
        <img class="map-img" src="assets/img/maps/sanandreas.jpg?v=1" alt="San Andreas Map"
             style="width:<?= $mapImgSizeX ?>%; height:<?= $mapImgSizeY ?>%; left:<?= $mapImgLeft ?>%; top:<?= $mapImgTop ?>%;">
        <div class="map-shade"></div>

        <?php foreach ($businesses as $b): [$px, $py] = ucp_world_to_pct($b['loc_x'], $b['loc_y']); ?>
          <div class="pin pin-biz" data-cat="biz" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Business #<?= (int)$b['id'] ?> ]<br>[ <?= ucp_escape($b['name']) ?> ]<br><?= ucp_owner_line($b['owned'], $b['owner'], $b['is_for_sale']) ?></div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($shops as $s): [$px, $py] = ucp_world_to_pct($s['shopLocX'], $s['shopLocY']); ?>
          <div class="pin pin-shop" data-cat="shop" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Shop #<?= (int)$s['shopID'] ?> ]</div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($fastfood as $f): [$px, $py] = ucp_world_to_pct($f['ffLocX'], $f['ffLocY']); ?>
          <div class="pin pin-food" data-cat="food" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ FastFood #<?= (int)$f['ffID'] ?> ]<br>[ <?= ucp_escape($ffTypeName[(int)$f['ffType']] ?? '?') ?> ]<br>[ <?= ucp_escape($f['ffName']) ?> ]</div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($factions as $fac): [$px, $py] = ucp_world_to_pct($fac['hq_x'], $fac['hq_y']); ?>
          <div class="pin pin-faction" data-cat="faction" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ HQ #<?= (int)$fac['id'] ?> ]<br>[ <?= ucp_escape($fac['name']) ?> ]<br>[ <?= $fac['lead'] !== '' ? 'Lead: ' . ucp_escape($fac['lead']) : '-' ?> ]</div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($houses as $h): [$px, $py] = ucp_world_to_pct($h['loc_x'], $h['loc_y']); ?>
          <div class="pin pin-house" data-cat="house" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ House #<?= (int)$h['id'] ?> ]<br>[ <?= ucp_escape($houseTypeName[(int)$h['type']] ?? 'Unknown') ?> ]<br><?= ucp_owner_line($h['owned'], $h['owner'], $h['is_for_sale']) ?></div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($hotels as $htl): [$px, $py] = ucp_world_to_pct($htl['loc_x'], $htl['loc_y']); ?>
          <div class="pin pin-hotel" data-cat="hotel" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Hotel #<?= (int)$htl['id'] ?> ]<br><?= ucp_owner_line($htl['owned'], $htl['owner'], $htl['is_for_sale']) ?></div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($atms as $a): [$px, $py] = ucp_world_to_pct($a['atmLocX'], $a['atmLocY']); ?>
          <div class="pin pin-atm" data-cat="atm" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ ATM #<?= (int)$a['atmID'] ?> ]<br>[ Bank: <?= ucp_escape($bizNameById[(int)$a['atmBankOwner']] ?? 'Unknown') ?> ]</div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($farms as $f): [$px, $py] = ucp_world_to_pct($f['x'], $f['y']); ?>
          <div class="pin pin-farm" data-cat="farm" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Farm #<?= (int)$f['id'] ?> ]<br>[ <?= ucp_escape($f['name']) ?> ]<br><?= ucp_owner_line($f['isOwned'], $f['owner'], $f['is_for_sale']) ?></div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($locations as $l): [$px, $py] = ucp_world_to_pct($l['locX'], $l['locY']); ?>
          <div class="pin pin-loc" data-cat="loc" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Location ]<br>[ <?= ucp_escape($l['locName']) ?> ]</div>
          </div>
        <?php endforeach; ?>

        <?php foreach ($jobLocations as $l): [$px, $py] = ucp_world_to_pct($l['locX'], $l['locY']); ?>
          <div class="pin pin-job" data-cat="job" style="left:<?= $px ?>%; top:<?= $py ?>%">
            <div class="pin-tooltip">[ Job ]<br>[ <?= ucp_escape($l['locName']) ?> ]</div>
          </div>
        <?php endforeach; ?>
      </div>

      <p class="map-note">San Andreas map, zoomed in on the Los Santos area. Alignment is approximate (calibrated against the standard game world limits, -3000..3000); points outside the city are not shown. Hover over a point for details.</p>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

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

document.getElementById('checkAllBtn').addEventListener('click', function() {
  document.querySelectorAll('.map-legend input[type=checkbox]').forEach(function(cb) {
    cb.checked = true;
    cb.dispatchEvent(new Event('change'));
  });
});
document.getElementById('uncheckAllBtn').addEventListener('click', function() {
  document.querySelectorAll('.map-legend input[type=checkbox]').forEach(function(cb) {
    cb.checked = false;
    cb.dispatchEvent(new Event('change'));
  });
});
</script>

</body>
</html>
