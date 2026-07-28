<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

$pid = ucp_current_player_id();

$stmt = $mysqli->prepare("SELECT * FROM `players` WHERE `id` = ? LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$player = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$player) {
    ucp_logout();
    header('Location: index.php');
    exit;
}

// Owned personal vehicles
$stmt = $mysqli->prepare("SELECT * FROM `vehicles_personal` WHERE `owner_id` = ? ORDER BY `id` ASC");
$stmt->bind_param('i', $pid);
$stmt->execute();
$vehicles = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

// Personal caravan (if owned)
$caravan = null;
if ((int)$player['caravan_key'] > 0) {
    $stmt = $mysqli->prepare("SELECT * FROM `rulote_personale` WHERE `rOwner` = ? AND `rOwned` = 1 LIMIT 1");
    $stmt->bind_param('i', $pid);
    $stmt->execute();
    $caravan = $stmt->get_result()->fetch_assoc();
    $stmt->close();
}

// Active rent (house/apartment or hotel) - see /renthouse, /rentappartment, /renthotel in the gamemode
$rentLabel = null;
if ((int)$player['rent_house'] > 0) {
    $rentLabel = 'House/apartment #' . (int)$player['rent_house'];
} elseif ((int)$player['rent_hotel'] > 0) {
    $rentLabel = 'Hotel #' . (int)$player['rent_hotel'];
}

// Owned farm - not a column in `players`, the source of truth is `farms`.`owner_id` (see Farm_SyncPlayerKey in the gamemode)
$stmt = $mysqli->prepare("SELECT * FROM `farms` WHERE `owner_id` = ? AND `isOwned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$farm = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Owned house (full details for the dedicated card)
$stmt = $mysqli->prepare("SELECT * FROM `houses` WHERE `owner_id` = ? AND `owned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$myHouse = $stmt->get_result()->fetch_assoc();
$stmt->close();
$houseTypeName = [1 => 'Villa', 2 => 'City House', 3 => 'Apartment', 4 => 'Countryside House'];

// House tree (if one is planted, see tree_id / `trees` table)
$houseTree = null;
if ($myHouse && (int)$myHouse['tree_id'] > 0) {
    $stmt = $mysqli->prepare("SELECT * FROM `trees` WHERE `treeId` = ? LIMIT 1");
    $stmt->bind_param('i', $myHouse['tree_id']);
    $stmt->execute();
    $houseTree = $stmt->get_result()->fetch_assoc();
    $stmt->close();
}

// House animals (see `animals` table, aHouseID)
$houseAnimals = [];
if ($myHouse) {
    $stmt = $mysqli->prepare("SELECT * FROM `animals` WHERE `aHouseID` = ? ORDER BY `aID` ASC");
    $stmt->bind_param('i', $myHouse['id']);
    $stmt->execute();
    $houseAnimals = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
}

// Individual farm equipment (each with its own wear) - newer table, may not exist yet if
// the gamemode hasn't started at least once after it was added (CREATE TABLE IF NOT EXISTS in bare.pwn)
$farmEquipment = [];
if ($farm) {
    try {
        $stmt = $mysqli->prepare("SELECT * FROM `farm_equipment` WHERE `farm_id` = ? ORDER BY `model` ASC, `id` ASC");
        $stmt->bind_param('i', $farm['id']);
        $stmt->execute();
        $farmEquipment = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
    } catch (mysqli_sql_exception $e) {
        $farmEquipment = null; // table doesn't exist yet - use the simple totals fallback
    }
}

$farmEquipTypes = [
    531 => ['Tractor', 16],
    486 => ['Bulldozer', 6],
    532 => ['Combine', 11],
    403 => ['Truck', 12],
    450 => ['Trailer', 15],
];

$fridgeItems = [
    'fridge_milk'   => ['Milk', 'cartons', 20],
    'fridge_banana' => ['Bananas', 'pcs', 30],
    'fridge_water'  => ['Water', 'L', 25],
    'fridge_juice'  => ['Juice', 'bottles', 20],
    'fridge_beer'   => ['Beer', 'cans', 50],
];

// Owned business (full details for the dedicated card)
$stmt = $mysqli->prepare("SELECT * FROM `businesses` WHERE `owner_id` = ? AND `owned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$myBusiness = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Owned hotel (full details for the dedicated card)
$stmt = $mysqli->prepare("SELECT * FROM `hotels` WHERE `owner_id` = ? AND `owned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$myHotel = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Current room occupancy of the owned hotel: renting is tracked per-tenant in `players`.`rent_hotel`, not on the `hotels` row
$myHotelRenterCount = 0;
if ($myHotel) {
    $stmt = $mysqli->prepare("SELECT COUNT(*) AS `cnt` FROM `players` WHERE `rent_hotel` = ?");
    $stmt->bind_param('i', $myHotel['id']);
    $stmt->execute();
    $myHotelRenterCount = (int)$stmt->get_result()->fetch_assoc()['cnt'];
    $stmt->close();
}

// The player's skin is now persisted per player in the `players`.`skin` column (implemented: /skins, /wardrobe).
$skinId = (int)$player['skin'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Dashboard</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <h1>Welcome, <?= ucp_escape($player['username']) ?></h1>

  <div class="grid-3">
    <div class="card">
      <h2>👤 Your account</h2>
      <table>
        <tr><th>Level</th><td><?= (int)$player['level'] ?></td></tr>
        <tr><th>RP</th><td><?= (int)$player['rp'] ?></td></tr>
        <tr><th>Cash</th><td>$<?= ucp_money($player['money']) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($player['bank']) ?></td></tr>
        <tr><th>Faction</th><td><?= ucp_escape(ucp_faction_name($player['faction'])) ?><?= $player['faction'] > 0 ? ' (rank ' . (int)$player['faction_rank'] . ')' : '' ?></td></tr>
        <tr><th>Admin level</th><td><?= (int)$player['admin_level'] ?></td></tr>
        <tr><th>Rent</th><td><?= $rentLabel ? ucp_escape($rentLabel) : 'No active rent' ?></td></tr>
      </table>
    </div>

    <div class="card">
      <h2>🪪 Driving licenses</h2>
      <table>
        <?php
        $licenses = [
            'A (motorcycles)' => $player['driving_lic_a_exp'],
            'B (cars)' => $player['driving_lic_b_exp'],
            'C (trucks)' => $player['driving_lic_c_exp'],
            'D (buses)' => $player['driving_lic_d_exp'],
            'P (plane)' => $player['airplane_lic_a_exp'],
            'H (helicopter)' => $player['airplane_lic_h_exp'],
        ];
        foreach ($licenses as $cat => $exp):
            $st = ucp_license_status($exp);
            $hasDate = !empty($exp) && $exp !== '0000-00-00';
        ?>
          <tr>
            <th>Category <?= $cat ?></th>
            <td>
              <span class="pill <?= $st['ok'] ? 'pill-ok' : 'pill-bad' ?>">
                <?php if ($hasDate): ?>
                  <?= date('d.m.Y', strtotime($exp)) ?> (<?= $st['ok'] ? $st['label'] : 'expired' ?>)
                <?php else: ?>
                  <?= ucp_escape($st['label']) ?>
                <?php endif; ?>
              </span>
            </td>
          </tr>
        <?php endforeach; ?>
      </table>
    </div>

    <div class="card skin-card">
      <h2>🧍 Your skin</h2>
      <div class="skin-box">
        <img src="assets/img/skins/skin_<?= (int)$skinId ?>.png" alt="Skin <?= (int)$skinId ?>"
             onerror="this.parentElement.innerHTML='Skin #<?= (int)$skinId ?><br>(no image)';">
      </div>
      <p style="color:var(--muted); margin:10px 0 0">Model #<?= (int)$skinId ?>. Change it in-game with <code>/skins</code>
      (buy new outfits) or <code>/wardrobe</code> (switch for free between owned ones).</p>
    </div>
  </div>

  <div class="card">
    <h2>🚗 Your cars (<?= count($vehicles) ?>)</h2>
    <?php if (!$vehicles): ?>
      <p style="color:var(--muted)">You don't own any personal vehicles.</p>
    <?php else: ?>
      <table>
        <tr><th>ID</th><th>Picture</th><th>Model</th><th>Plate</th><th>First registration</th><th>Dirty</th><th>Insurance</th><th>Medkit</th><th>Extinguisher</th><th>Inspection</th></tr>
        <?php foreach ($vehicles as $v):
            $ins = ucp_doc_status($v['insurance_exp']);
            $med = ucp_doc_status($v['medkit_exp']);
            $ext = ucp_doc_status($v['extinguisher_exp']);
            $itp = ucp_doc_status($v['itp_exp']);
            $dirtyPct = max(0, min(100, (int)$v['dirty']));
            if ($dirtyPct >= 90)     $dirtyTier = 'bad';  // VEHICLE_DIRTY_LOCK - engine won't start
            elseif ($dirtyPct >= 75) $dirtyTier = 'warn'; // VEHICLE_DIRTY_WARN
            elseif ($dirtyPct >= 40) $dirtyTier = 'good';
            else                     $dirtyTier = 'ok';
        ?>
        <tr>
          <td>#<?= (int)$v['id'] ?></td>
          <td>
            <img src="<?= ucp_escape(ucp_vehicle_image($v['model_id'])) ?>" alt="<?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?>"
                 style="width:90px; height:60px; object-fit:contain; background:var(--panel-2); border-radius:6px;"
                 onerror="this.style.display='none';">
          </td>
          <td><?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?></td>
          <td><?= ucp_escape($v['plate'] ?? '—') ?></td>
          <td><?= $v['first_registration'] ? date('d.m.Y', strtotime($v['first_registration'])) : '—' ?></td>
          <td>
            <span class="meter"><span class="meter-fill <?= $dirtyTier ?>" style="width:<?= $dirtyPct ?>%"></span></span>
            <span class="meter-label"><?= $dirtyPct ?>%</span>
          </td>
          <td><span class="pill pill-<?= ucp_doc_tier($ins) ?>"><?= ucp_escape($ins['label']) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($med) ?>"><?= ucp_escape($med['label']) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($ext) ?>"><?= ucp_escape($ext['label']) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($itp) ?>"><?= ucp_escape($itp['label']) ?></span></td>
        </tr>
        <?php endforeach; ?>
      </table>
    <?php endif; ?>
  </div>

    <?php if ($myHouse): ?>
    <div class="card">
      <h2>🏠 Your house</h2>
      <table>
        <tr><th>Name</th><td><?= ucp_escape($myHouse['name']) ?> (ID #<?= (int)$myHouse['id'] ?>)</td></tr>
        <tr><th>Type</th><td><?= ucp_escape($houseTypeName[(int)$myHouse['type']] ?? 'Unknown') ?></td></tr>
        <tr><th>Price</th><td>$<?= ucp_money($myHouse['price']) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($myHouse['bank']) ?></td></tr>
        <tr><th>For sale</th><td><span class="pill <?= $myHouse['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myHouse['is_for_sale'] ? 'Yes' : 'No' ?></span></td></tr>
        <tr><th>Rentable</th><td><?= $myHouse['is_rentable'] ? ('Yes — $' . ucp_money($myHouse['rent_price']) . '/PayDay') : 'No' ?></td></tr>
        <?php if ((int)$myHouse['type'] === 3 && (int)$myHouse['issue'] > 0): ?>
        <tr><th>Active issue</th><td><span class="pill pill-bad">Yes (code <?= (int)$myHouse['issue'] ?>) — requires Electrician</span></td></tr>
        <?php endif; ?>
      </table>

      <h3 style="margin:16px 0 6px">🧊 Fridge</h3>
      <?php if (!$myHouse['has_fridge']): ?>
        <p style="color:var(--muted); margin:4px 0">No fridge. Buy one with <code>/house upgrade frigde</code> ($10,000).</p>
      <?php else: ?>
        <?php $fridgeBroken = (int)$myHouse['fridge_expire'] > 0 && time() >= (int)$myHouse['fridge_expire']; ?>
        <p style="margin:4px 0">
          Status:
          <?php if ($fridgeBroken): ?>
            <span class="pill pill-bad">Broken</span> — contents were lost, needs replacement (<code>/house upgrade frigde</code>, $10,000)
          <?php else: ?>
            <span class="pill pill-ok">Working</span>
            <?php if ((int)$myHouse['fridge_expire'] > 0): ?>
              — breaks on <strong><?= date('d.m.Y H:i', (int)$myHouse['fridge_expire']) ?></strong>
              (<?= max(0, (int)floor(((int)$myHouse['fridge_expire'] - time()) / 86400)) ?> days left)
            <?php endif; ?>
          <?php endif; ?>
        </p>
        <table>
          <tr><th>Food</th><th>Quantity</th><th>Capacity</th></tr>
          <?php foreach ($fridgeItems as $col => [$label, $unit, $max]): ?>
          <tr>
            <td><?= ucp_escape($label) ?></td>
            <td><?= $fridgeBroken ? 0 : (int)$myHouse[$col] ?> <?= $unit ?></td>
            <td><?= $max ?> <?= $unit ?></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🛏️ Bed</h3>
      <?php if (!$myHouse['has_bed']): ?>
        <p style="color:var(--muted); margin:4px 0">No bed. Buy one with <code>/house upgrade bed</code> ($7,500).</p>
      <?php else: ?>
        <?php $bedBroken = (int)$myHouse['bed_expire'] > 0 && time() >= (int)$myHouse['bed_expire']; ?>
        <p style="margin:4px 0">
          Status:
          <?php if ($bedBroken): ?>
            <span class="pill pill-bad">Broken</span> — needs replacement (<code>/house upgrade bed</code>, $7,500)
          <?php else: ?>
            <span class="pill pill-ok">Working</span>
            <?php if ((int)$myHouse['bed_expire'] > 0): ?>
              — breaks on <strong><?= date('d.m.Y H:i', (int)$myHouse['bed_expire']) ?></strong>
              (<?= max(0, (int)floor(((int)$myHouse['bed_expire'] - time()) / 86400)) ?> days left)
            <?php endif; ?>
          <?php endif; ?>
        </p>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🌳 Tree</h3>
      <?php if (!$houseTree): ?>
        <p style="color:var(--muted); margin:4px 0">No tree planted. Buy one with <code>/house upgrade tree</code> ($20,000, City/Countryside House only).</p>
      <?php else: ?>
        <table>
          <tr><th>Name</th><td><?= ucp_escape($houseTree['treeName']) ?> (ID #<?= (int)$houseTree['treeId'] ?>)</td></tr>
          <tr><th>Planted on</th><td><?= (int)$houseTree['treePlantedDate'] > 0 ? date('d.m.Y H:i', (int)$houseTree['treePlantedDate']) : 'Unknown' ?></td></tr>
          <tr>
            <th>Fruit growth</th>
            <td>
              <?= (int)$houseTree['treeFruitStatus'] ?>/30
              <?php if ((int)$houseTree['treeFruitStatus'] >= 30): ?>
                <span class="pill pill-ok">Ready to harvest</span>
              <?php else: ?>
                <span style="color:var(--muted)">(+1 every PayDay, ~<?= 30 - (int)$houseTree['treeFruitStatus'] ?> PayDays until max)</span>
              <?php endif; ?>
            </td>
          </tr>
        </table>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🐄 Animals</h3>
      <?php if (!$houseAnimals): ?>
        <p style="color:var(--muted); margin:4px 0">No animals. Buy one with <code>/house upgrade animal [name]</code> ($5,000).</p>
      <?php else: ?>
        <table>
          <tr><th>#</th><th>Type</th><th>Name</th></tr>
          <?php foreach ($houseAnimals as $animal): ?>
          <tr>
            <td>#<?= (int)$animal['aID'] ?></td>
            <td><?= ucp_escape($animal['aDefaultName']) ?></td>
            <td><?= ucp_escape($animal['aName']) ?> <span style="color:var(--muted)">(rename in-game: <code>/renameanimal <?= (int)$animal['aID'] ?> [name]</code>)</span></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>
    </div>
    <?php endif; ?>

    <?php if ($myBusiness): ?>
    <div class="card">
      <h2>🏢 Your business</h2>
      <table>
        <tr><th>Name</th><td><?= ucp_escape($myBusiness['name']) ?> (ID #<?= (int)$myBusiness['id'] ?>)</td></tr>
        <tr><th>Price</th><td>$<?= ucp_money($myBusiness['price']) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($myBusiness['bank']) ?></td></tr>
        <tr><th>For sale</th><td><span class="pill <?= $myBusiness['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myBusiness['is_for_sale'] ? 'Yes' : 'No' ?></span></td></tr>
        <tr><th>ANAF</th><td><span class="pill <?= $myBusiness['anaf'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myBusiness['anaf'] ? 'Blocked' : 'OK' ?></span></td></tr>
      </table>
    </div>
    <?php endif; ?>

    <?php if ($farm): ?>
    <div class="card">
      <h2>🌾 Your farm</h2>
      <table>
        <tr><th>Name</th><td><?= ucp_escape($farm['name']) ?> (ID #<?= (int)$farm['id'] ?>)</td></tr>
        <tr><th>Price</th><td>$<?= ucp_money($farm['price']) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($farm['farmBank']) ?></td></tr>
        <tr><th>Harvest in storage</th><td><?= ucp_money($farm['farmRecolta']) ?> <span style="color:var(--muted)">(sell with <code>/farm deliver</code>)</span></td></tr>
        <tr><th>For sale</th><td><span class="pill <?= $farm['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $farm['is_for_sale'] ? 'Yes' : 'No' ?></span></td></tr>
        <tr><th>Current stage</th><td><?= $farm['isReadyToHarvest'] ? 'Ready to harvest' : ucp_escape($farm['nextStep']) ?></td></tr>
      </table>

      <h3 style="margin:16px 0 6px">🚜 Equipment</h3>
      <?php if ($farmEquipment === null): ?>
        <table>
          <tr><th>Type</th><th>Quantity</th></tr>
          <tr><td>Tractor</td><td><?= (int)$farm['tractors'] ?></td></tr>
          <tr><td>Combine</td><td><?= (int)$farm['combines'] ?></td></tr>
          <tr><td>Bulldozer</td><td><?= (int)$farm['dozers'] ?></td></tr>
          <tr><td>Truck</td><td><?= (int)$farm['trucks'] ?></td></tr>
          <tr><td>Trailer</td><td><?= (int)$farm['trailers'] ?></td></tr>
        </table>
      <?php elseif (!$farmEquipment): ?>
        <p style="color:var(--muted); margin:4px 0">No equipment. Buy with <code>/farm buy [tractor/dozer/combina/truck/trailer]</code>.</p>
      <?php else: ?>
        <table>
          <tr><th>Type</th><th>Health</th><th>Status</th></tr>
          <?php foreach ($farmEquipment as $eq):
              $eqInfo = $farmEquipTypes[(int)$eq['model']] ?? ['Unknown', 1];
              [$eqLabel, $eqMax] = $eqInfo;
              $eqBroken = (int)$eq['uses'] >= $eqMax;
              $eqHealth = (int)round(min(100, (int)$eq['uses'] / $eqMax * 100));
              if ($eqHealth >= 100)     { $eqTier = 'bad';  $eqWord = 'Broken'; }
              elseif ($eqHealth >= 70)  { $eqTier = 'warn'; $eqWord = 'Poor'; }
              elseif ($eqHealth >= 40)  { $eqTier = 'good'; $eqWord = 'Good'; }
              else                      { $eqTier = 'ok';   $eqWord = 'Excellent'; }
          ?>
          <tr>
            <td><?= ucp_escape($eqLabel) ?> (#<?= (int)$eq['id'] ?>)</td>
            <td>
              <span class="meter"><span class="meter-fill <?= $eqTier ?>" style="width:<?= $eqHealth ?>%"></span></span>
              <span class="meter-label"><?= $eqHealth ?>%</span>
            </td>
            <td><span class="pill pill-<?= $eqTier ?>"><?= $eqWord ?></span></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>
    </div>
    <?php endif; ?>

    <?php if ($myHotel): ?>
    <div class="card">
      <h2>🏨 Your hotel</h2>
      <table>
        <tr><th>Name</th><td><?= ucp_escape($myHotel['name']) ?> (ID #<?= (int)$myHotel['id'] ?>)</td></tr>
        <tr><th>Price</th><td>$<?= ucp_money($myHotel['price']) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($myHotel['bank']) ?></td></tr>
        <tr><th>For sale</th><td><span class="pill <?= $myHotel['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myHotel['is_for_sale'] ? 'Yes' : 'No' ?></span></td></tr>
        <tr><th>Rentable</th><td><?= $myHotel['is_rentable'] ? ('Yes — $' . ucp_money($myHotel['rent_price']) . '/PayDay') : 'No' ?></td></tr>
        <?php if ($myHotel['is_rentable']): ?>
        <tr><th>Rooms taken</th><td><?= $myHotelRenterCount ?>/<?= (int)($myHotel['capacity'] ?? 5) ?></td></tr>
        <?php endif; ?>
      </table>
    </div>
    <?php endif; ?>

    <?php
    $caravanImg = [
        1 => 'https://files.prineside.com/gtasa_samp_model_id/white/3174_w.jpg',
        2 => 'https://files.prineside.com/gtasa_samp_model_id/white/3171_w.jpg',
        3 => 'https://files.prineside.com/gtasa_samp_model_id/white/3172_w.jpg',
    ];
    ?>
    <?php if ($caravan): ?>
    <div class="card">
      <h2>🚐 Your caravan</h2>
      <table>
        <tr>
          <td rowspan="4" class="caravan-box">
            <img src="<?= ucp_escape($caravanImg[(int)$player['caravan_key']] ?? '') ?>" alt="Caravan type <?= (int)$player['caravan_key'] ?>"
                 onerror="this.parentElement.innerHTML='(no image)';">
          </td>
          <th>Type</th><td><?= ucp_escape($caravan['rName']) ?> (#<?= (int)$player['caravan_key'] ?>)</td>
        </tr>
        <tr><th>Size</th><td><?= number_format((float)$caravan['rSize'], 2) ?>m</td></tr>
        <tr><th>Weight</th><td><?= (int)$caravan['rWeight'] ?>kg</td></tr>
        <tr><th>Status</th><td><?= $caravan['rCamping'] ? 'Camping' : 'Parked' ?></td></tr>
      </table>
    </div>
    <?php endif; ?>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
