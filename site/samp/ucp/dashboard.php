<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
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

// Ban status - `bans` is keyed by username/IP, not player id (see Ban_Check in the gamemode)
$stmt = $mysqli->prepare("SELECT * FROM `bans` WHERE `username` = ? LIMIT 1");
$stmt->bind_param('s', $player['username']);
$stmt->execute();
$activeBan = $stmt->get_result()->fetch_assoc();
$stmt->close();
if ($activeBan && (int)$activeBan['expire'] !== 0 && time() >= (int)$activeBan['expire']) {
    $activeBan = null; // expired temp ban - gamemode deletes it lazily on next login attempt
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

// Owned farm - not a column in `players`, the source of truth is `farms`.`owner_id` (see Farm_SyncPlayerKey in the gamemode)
$stmt = $mysqli->prepare("SELECT * FROM `farms` WHERE `owner_id` = ? AND `isOwned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$farm = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Owned forest - not a column in `players`, the source of truth is `forests`.`ownerId`
$stmt = $mysqli->prepare("SELECT * FROM `forests` WHERE `ownerId` = ? LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$forest = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Owned house (full details for the dedicated card)
$stmt = $mysqli->prepare("SELECT * FROM `houses` WHERE `owner_id` = ? AND `owned` = 1 LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$myHouse = $stmt->get_result()->fetch_assoc();
$stmt->close();
$houseTypeName = [1 => 'Villa', 2 => 'City House', 3 => 'Apartment', 4 => 'Countryside House'];

// House tree (if one is planted, see tree_id / `houses_tree` table)
$houseTree = null;
if ($myHouse && (int)$myHouse['tree_id'] > 0) {
    $stmt = $mysqli->prepare("SELECT * FROM `houses_tree` WHERE `treeId` = ? LIMIT 1");
    $stmt->bind_param('i', $myHouse['tree_id']);
    $stmt->execute();
    $houseTree = $stmt->get_result()->fetch_assoc();
    $stmt->close();
}

// House animals (see `houses_animals` table, aHouseID)
$houseAnimals = [];
if ($myHouse) {
    $stmt = $mysqli->prepare("SELECT * FROM `houses_animals` WHERE `aHouseID` = ? ORDER BY `aID` ASC");
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

// Owned billboard (full details for the dedicated card) - `bb_key` on `players` mirrors `billboards`.`bbOwnerId`
// `billboards` is created by the gamemode on startup (CREATE TABLE IF NOT EXISTS) - may not exist yet if it hasn't run since this feature was added
$myBillboard = null;
try {
    $stmt = $mysqli->prepare("SELECT * FROM `billboards` WHERE `bbOwnerId` = ? LIMIT 1");
    $stmt->bind_param('i', $pid);
    $stmt->execute();
    $myBillboard = $stmt->get_result()->fetch_assoc();
    $stmt->close();
} catch (mysqli_sql_exception $e) {
    $myBillboard = null; // table doesn't exist yet
}

// The player's skin is now persisted per player in the `players`.`skin` column (implemented: /skins, /wardrobe).
$skinId = (int)$player['skin'];

// Owned skins (the player's "collection", bought via /skins) - see `player_skins` table.
// A skin can be bought more than once (`qty`), so it gets one column per copy owned.
$stmt = $mysqli->prepare("SELECT `skin_id`, `qty` FROM `player_skins` WHERE `player_id` = ? ORDER BY `skin_id` ASC");
$stmt->bind_param('i', $pid);
$stmt->execute();
$ownedSkins = [];
foreach ($stmt->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
    for ($n = 0; $n < max(1, (int)$row['qty']); $n++) {
        $ownedSkins[] = (int)$row['skin_id'];
    }
}
$stmt->close();
$ownedSkinCount = count($ownedSkins);
if ($ownedSkinCount > 15 && $ownedSkinCount <= 30) {
    // split evenly across 2 rows instead of a full 15 + a short remainder
    $ownedSkinChunks = array_chunk($ownedSkins, (int)ceil($ownedSkinCount / 2));
} else {
    $ownedSkinChunks = array_chunk($ownedSkins, 15);
}
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Dashboard</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<?php
$sectionNav = [
    ['card-account',     '👤', 'Account'],
    ['card-licenses',    '🪪', 'Licenses'],
    ['card-skin',        '🧍', 'Skin'],
    ['card-collections', '👕', 'Skin collections'],
    ['card-cars',        '🚗', 'Cars'],
];
$sectionNav[] = ['card-house',    '🏠', 'House'];
$sectionNav[] = ['card-business', '🏢', 'Business'];
$sectionNav[] = ['card-farm',     '🌾', 'Farm'];
$sectionNav[] = ['card-forest',   '🌲', 'Forest'];
$sectionNav[] = ['card-hotel',    '🏨', 'Hotel'];
$sectionNav[] = ['card-billboard', '📢', 'Billboard'];
$sectionNav[] = ['card-caravan',  '🚐', 'Caravan'];
?>
<nav class="section-nav" aria-label="<?= t('Jump to section') ?>">
  <?php foreach ($sectionNav as [$anchorId, $icon, $label]): ?>
  <a href="#<?= $anchorId ?>" title="<?= ucp_escape(t($label)) ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>

<main>
  <h1><?= t('Welcome,') ?> <?= ucp_escape($player['username']) ?><?php if ($player['register_date']): ?> <span style="font-style:italic; font-weight:300; font-size:0.6em; color:var(--muted);">(<?= t('Member since') ?> <?= ucp_escape(date('Y-m-d', strtotime($player['register_date']))) ?>)</span><?php endif; ?></h1>

  <div class="grid-3">
    <div class="card" id="card-account">
      <h2>👤 <?= t('Your account') ?></h2>
      <table>
        <tr><th><?= t('Level') ?></th><td><?= (int)$player['level'] ?></td></tr>
        <tr><th><?= t('RP') ?></th><td><?= (int)$player['rp'] ?></td></tr>
        <tr><th><?= t('Cash') ?></th><td>$<?= ucp_money($player['money']) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($player['bank']) ?></td></tr>
        <tr><th><?= t('Faction') ?></th><td><?= ucp_escape(ucp_faction_name($player['faction'])) ?><?= $player['faction'] > 0 ? ' (' . t('rank') . ' ' . (int)$player['faction_rank'] . ')' : '' ?></td></tr>
        <tr><th><?= t('Religion') ?></th><td><?= ucp_escape(ucp_religion_name($player['religion'] ?? 0)) ?></td></tr>
        <tr><th><?= t('Language') ?></th><td><?= strtolower($player['language'] ?? 'en') === 'ro' ? t('Romana') : t('English') ?></td></tr>
        <tr><th><?= t('Admin level') ?></th><td><?= (int)$player['admin_level'] ?></td></tr>
        <tr><th><?= t('Ban') ?></th><td>
          <?php if ($activeBan): ?>
            <span class="pill pill-bad"><?= t('Yes') ?></span>
            <?= (int)$activeBan['expire'] !== 0 ? ', ' . t('expires on') . ' ' . date('d.m.Y H:i', (int)$activeBan['expire']) : ' (' . t('permanent') . ')' ?>
          <?php else: ?>
            <span class="pill pill-ok"><?= t('No') ?></span>
          <?php endif; ?>
        </td></tr>
        <tr><th><?= t('Warns') ?></th><td><?= (int)$player['warns'] ?>/3</td></tr>
      </table>
    </div>

    <div class="card" id="card-licenses">
      <h2>🪪 <?= t('Licenses') ?></h2>
      <table>
        <?php
        $licenses = [
            'A (motorcycles)' => $player['driving_lic_a_exp'],
            'B (cars)' => $player['driving_lic_b_exp'],
            'C (trucks)' => $player['driving_lic_c_exp'],
            'D (buses)' => $player['driving_lic_d_exp'],
            'P (plane)' => $player['airplane_lic_a_exp'],
            'H (helicopter)' => $player['airplane_lic_h_exp'],
            'W (weapons)' => $player['weapon_lic_w_exp'],
        ];
        foreach ($licenses as $cat => $exp):
            $st = ucp_license_status($exp);
            $hasDate = !empty($exp) && $exp !== '0000-00-00';
        ?>
          <tr>
            <th><?= t('Category') ?> <?= t($cat) ?></th>
            <td>
              <span class="pill <?= $st['ok'] ? 'pill-ok' : 'pill-bad' ?>">
                <?php if ($hasDate): ?>
                  <?= date('d.m.Y', strtotime($exp)) ?> (<?= $st['ok'] ? t($st['label']) : t('expired') ?>)
                <?php else: ?>
                  <?= ucp_escape(t($st['label'])) ?>
                <?php endif; ?>
              </span>
            </td>
          </tr>
        <?php endforeach; ?>
      </table>
    </div>

    <div class="card skin-card" id="card-skin">
      <h2>🧍 <?= t('Your skin') ?></h2>
      <div class="skin-box">
        <img src="assets/img/skins/skin_<?= (int)$skinId ?>.png" alt="Skin <?= (int)$skinId ?>"
             onerror="this.parentElement.innerHTML='<?= t('Skin') ?> #<?= (int)$skinId ?><br>(<?= t('no image') ?>)';">
      </div>
      <p style="color:var(--muted); margin:10px 0 0"><?= t('Model') ?> #<?= (int)$skinId ?>. <?= t('Change it in-game with') ?> <code>/skins</code>
      (<?= t('buy new outfits') ?>) <?= t('or') ?> <code>/wardrobe</code> (<?= t('switch for free between owned ones') ?>).</p>
    </div>
  </div>

  <div class="card" id="card-collections">
    <h2>👕 <?= t('Skin collections') ?> (<?= count($ownedSkins) ?>)</h2>
    <?php if (!$ownedSkins): ?>
      <p style="color:var(--muted)"><?= t("You don't own any outfits yet. Buy some in-game with") ?> <code>/skins</code>.</p>
    <?php else: ?>
      <?php foreach ($ownedSkinChunks as $chunk): ?>
      <table class="skin-collection">
        <tr>
          <?php foreach ($chunk as $sid): ?>
          <th>#<?= (int)$sid ?></th>
          <?php endforeach; ?>
        </tr>
        <tr>
          <?php foreach ($chunk as $sid): ?>
          <td>
            <div class="skin-thumb-box">
              <img src="assets/img/skins/skin_<?= (int)$sid ?>.png" alt="Skin <?= (int)$sid ?>"
                   onerror="this.parentElement.textContent='#<?= (int)$sid ?>';">
            </div>
          </td>
          <?php endforeach; ?>
        </tr>
      </table>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>

  <div class="card" id="card-cars">
    <h2>🚗 <?= t('Your cars') ?> (<?= count($vehicles) ?>)</h2>
    <?php if (!$vehicles): ?>
      <p style="color:var(--muted)"><?= t("You don't own any personal vehicles.") ?></p>
    <?php else: ?>
      <table>
        <tr><th><?= t('ID') ?></th><th><?= t('Picture') ?></th><th><?= t('Model') ?></th><th><?= t('Plate') ?></th><th><?= t('First registration') ?></th><th><?= t('Dirty') ?></th><th><?= t('Insurance') ?></th><th><?= t('Medkit') ?></th><th><?= t('Extinguisher') ?></th><th><?= t('Inspection') ?></th></tr>
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
          <td><span class="pill pill-<?= ucp_doc_tier($ins) ?>"><?= ucp_escape(t($ins['label'])) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($med) ?>"><?= ucp_escape(t($med['label'])) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($ext) ?>"><?= ucp_escape(t($ext['label'])) ?></span></td>
          <td><span class="pill pill-<?= ucp_doc_tier($itp) ?>"><?= ucp_escape(t($itp['label'])) ?></span></td>
        </tr>
        <?php endforeach; ?>
      </table>
    <?php endif; ?>
  </div>

    <div class="card" id="card-house">
      <h2>🏠 <?= t('Your house') ?> (<?= $myHouse ? 1 : 0 ?>)</h2>
      <?php if (!$myHouse): ?>
      <p style="color:var(--muted)"><?= t("You don't have any house. Buy one in-game with") ?> <code>/buyhouse</code>.</p>
      <?php else: ?>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($myHouse['name']) ?> (ID #<?= (int)$myHouse['id'] ?>)</td></tr>
        <tr><th><?= t('Type') ?></th><td><?= ucp_escape(t($houseTypeName[(int)$myHouse['type']] ?? 'Unknown')) ?></td></tr>
        <tr><th><?= t('Price') ?></th><td>$<?= ucp_money($myHouse['price']) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($myHouse['bank']) ?></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $myHouse['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myHouse['is_for_sale'] ? t('Yes') : t('No') ?></span></td></tr>
        <tr><th><?= t('Rentable') ?></th><td><?= $myHouse['is_rentable'] ? (t('Yes') . ' — $' . ucp_money($myHouse['rent_price']) . '/' . t('PayDay')) : t('No') ?></td></tr>
        <?php if ((int)$myHouse['type'] === 3 && (int)$myHouse['issue'] > 0): ?>
        <tr><th><?= t('Active issue') ?></th><td><span class="pill pill-bad"><?= t('Yes') ?> (<?= t('code') ?> <?= (int)$myHouse['issue'] ?>) — <?= t('requires Electrician') ?></span></td></tr>
        <?php endif; ?>
      </table>

      <h3 style="margin:16px 0 6px">🧊 <?= t('Fridge') ?></h3>
      <?php if (!$myHouse['has_fridge']): ?>
        <p style="color:var(--muted); margin:4px 0"><?= t('No fridge. Buy one with') ?> <code>/house upgrade frigde</code> ($10,000).</p>
      <?php else: ?>
        <?php $fridgeBroken = (int)$myHouse['fridge_expire'] > 0 && time() >= (int)$myHouse['fridge_expire']; ?>
        <p style="margin:4px 0">
          <?= t('Status:') ?>
          <?php if ($fridgeBroken): ?>
            <span class="pill pill-bad"><?= t('Broken') ?></span> — <?= t('contents were lost, needs replacement') ?> (<code>/house upgrade frigde</code>, $10,000)
          <?php else: ?>
            <span class="pill pill-ok"><?= t('Working') ?></span>
            <?php if ((int)$myHouse['fridge_expire'] > 0): ?>
              — <?= t('breaks on') ?> <strong><?= date('d.m.Y H:i', (int)$myHouse['fridge_expire']) ?></strong>
              (<?= max(0, (int)floor(((int)$myHouse['fridge_expire'] - time()) / 86400)) ?> <?= t('days left') ?>)
            <?php endif; ?>
          <?php endif; ?>
        </p>
        <table>
          <tr><th><?= t('Food') ?></th><th><?= t('Quantity') ?></th><th><?= t('Capacity') ?></th></tr>
          <?php foreach ($fridgeItems as $col => [$label, $unit, $max]): ?>
          <tr>
            <td><?= ucp_escape(t($label)) ?></td>
            <td><?= $fridgeBroken ? 0 : (int)$myHouse[$col] ?> <?= $unit ?></td>
            <td><?= $max ?> <?= $unit ?></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🛏️ <?= t('Bed') ?></h3>
      <?php if (!$myHouse['has_bed']): ?>
        <p style="color:var(--muted); margin:4px 0"><?= t('No bed. Buy one with') ?> <code>/house upgrade bed</code> ($7,500).</p>
      <?php else: ?>
        <?php $bedExpire = ($myHouse['bed_Exp'] && $myHouse['bed_Exp'] !== '0000-00-00') ? strtotime($myHouse['bed_Exp']) : 0; ?>
        <?php $bedBroken = $bedExpire > 0 && time() >= $bedExpire; ?>
        <p style="margin:4px 0">
          <?= t('Status:') ?>
          <?php if ($bedBroken): ?>
            <span class="pill pill-bad"><?= t('Broken') ?></span> — <?= t('needs replacement') ?> (<code>/house upgrade bed</code>, $7,500)
          <?php else: ?>
            <span class="pill pill-ok"><?= t('Working') ?></span>
            <?php if ($bedExpire > 0): ?>
              — <?= t('breaks on') ?> <strong><?= date('d.m.Y', $bedExpire) ?></strong>
              (<?= max(0, (int)floor(($bedExpire - time()) / 86400)) ?> <?= t('days left') ?>)
            <?php endif; ?>
          <?php endif; ?>
        </p>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🌳 <?= t('Tree') ?></h3>
      <?php if (!$houseTree): ?>
        <p style="color:var(--muted); margin:4px 0"><?= t('No tree planted. Buy one with') ?> <code>/house upgrade tree</code> ($20,000, City/Countryside House only).</p>
      <?php else: ?>
        <table>
          <tr><th><?= t('Name') ?></th><td><?= ucp_escape($houseTree['treeName']) ?> (ID #<?= (int)$houseTree['treeId'] ?>)</td></tr>
          <tr><th><?= t('Planted on') ?></th><td><?= (int)$houseTree['treePlantedDate'] > 0 ? date('d.m.Y H:i', (int)$houseTree['treePlantedDate']) : t('Unknown') ?></td></tr>
          <tr>
            <th><?= t('Fruit growth') ?></th>
            <td>
              <?= (int)$houseTree['treeFruitStatus'] ?>/30
              <?php if ((int)$houseTree['treeFruitStatus'] >= 30): ?>
                <span class="pill pill-ok"><?= t('Ready to harvest') ?></span>
              <?php else: ?>
                <span style="color:var(--muted)">(+1 <?= t('every PayDay') ?>, ~<?= 30 - (int)$houseTree['treeFruitStatus'] ?> <?= t('PayDays until max') ?>)</span>
              <?php endif; ?>
            </td>
          </tr>
        </table>
      <?php endif; ?>

      <h3 style="margin:16px 0 6px">🐄 <?= t('Animals') ?></h3>
      <?php if (!$houseAnimals): ?>
        <p style="color:var(--muted); margin:4px 0"><?= t('No animals. Buy one with') ?> <code>/house upgrade animal [name]</code> ($5,000).</p>
      <?php else: ?>
        <table>
          <tr><th>#</th><th><?= t('Type') ?></th><th><?= t('Name') ?></th></tr>
          <?php foreach ($houseAnimals as $animal): ?>
          <tr>
            <td>#<?= (int)$animal['aID'] ?></td>
            <td><?= ucp_escape($animal['aDefaultName']) ?></td>
            <td><?= ucp_escape($animal['aName']) ?> <span style="color:var(--muted)">(<?= t('rename in-game:') ?> <code>/renameanimal <?= (int)$animal['aID'] ?> [name]</code>)</span></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>
      <?php endif; ?>
    </div>

    <div class="card" id="card-business">
      <h2>🏢 <?= t('Your business') ?> (<?= $myBusiness ? 1 : 0 ?>)</h2>
      <?php if (!$myBusiness): ?>
      <p style="color:var(--muted)"><?= t("You don't have any business. Buy one in-game with") ?> <code>/buybiz</code>.</p>
      <?php else: ?>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($myBusiness['name']) ?> (ID #<?= (int)$myBusiness['id'] ?>)</td></tr>
        <tr><th><?= t('Price') ?></th><td>$<?= ucp_money($myBusiness['price']) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($myBusiness['bank']) ?></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $myBusiness['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myBusiness['is_for_sale'] ? t('Yes') : t('No') ?></span></td></tr>
        <tr><th>ANAF</th><td><span class="pill <?= $myBusiness['anaf'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myBusiness['anaf'] ? t('Blocked') : t('OK') ?></span></td></tr>
        <tr><th><?= t('Has coffee') ?></th><td><?= $myBusiness['coffee_maker'] ? '☕ ' . t('Yes') : '—' ?></td></tr>
      </table>
      <?php endif; ?>
    </div>

    <div class="card" id="card-farm">
      <h2>🌾 <?= t('Your farm') ?> (<?= $farm ? 1 : 0 ?>)</h2>
      <?php if (!$farm): ?>
      <p style="color:var(--muted)"><?= t("You don't have any farm. Buy one in-game with") ?> <code>/buyfarm</code>.</p>
      <?php else: ?>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($farm['name']) ?> (ID #<?= (int)$farm['id'] ?>)</td></tr>
        <tr><th><?= t('Price') ?></th><td>$<?= ucp_money($farm['price']) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($farm['farmBank']) ?></td></tr>
        <tr><th><?= t('Harvest in storage') ?></th><td><?= ucp_money($farm['farmRecolta']) ?> <span style="color:var(--muted)">(<?= t('sell with') ?> <code>/farm deliver</code>)</span></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $farm['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $farm['is_for_sale'] ? t('Yes') : t('No') ?></span></td></tr>
        <tr><th><?= t('Current stage') ?></th><td><?= $farm['isReadyToHarvest'] ? t('Ready to harvest') : ucp_escape($farm['nextStep']) ?></td></tr>
      </table>

      <h3 style="margin:16px 0 6px">🚜 <?= t('Equipment') ?></h3>
      <?php if ($farmEquipment === null): ?>
        <table>
          <tr><th><?= t('Type') ?></th><th><?= t('Quantity') ?></th></tr>
          <tr><td><?= t('Tractor') ?></td><td><?= (int)$farm['tractors'] ?></td></tr>
          <tr><td><?= t('Combine') ?></td><td><?= (int)$farm['combines'] ?></td></tr>
          <tr><td><?= t('Bulldozer') ?></td><td><?= (int)$farm['dozers'] ?></td></tr>
          <tr><td><?= t('Truck') ?></td><td><?= (int)$farm['trucks'] ?></td></tr>
          <tr><td><?= t('Trailer') ?></td><td><?= (int)$farm['trailers'] ?></td></tr>
        </table>
      <?php elseif (!$farmEquipment): ?>
        <p style="color:var(--muted); margin:4px 0"><?= t('No equipment. Buy with') ?> <code>/farm buy [tractor/dozer/combina/truck/trailer]</code>.</p>
      <?php else: ?>
        <table>
          <tr><th><?= t('Type') ?></th><th><?= t('Health') ?></th><th><?= t('Status') ?></th></tr>
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
            <td><?= ucp_escape(t($eqLabel)) ?> (#<?= (int)$eq['id'] ?>)</td>
            <td>
              <span class="meter"><span class="meter-fill <?= $eqTier ?>" style="width:<?= $eqHealth ?>%"></span></span>
              <span class="meter-label"><?= $eqHealth ?>%</span>
            </td>
            <td><span class="pill pill-<?= $eqTier ?>"><?= t($eqWord) ?></span></td>
          </tr>
          <?php endforeach; ?>
        </table>
      <?php endif; ?>
      <?php endif; ?>
    </div>

    <div class="card" id="card-forest">
      <h2>🌲 <?= t('Your forest') ?> (<?= $forest ? 1 : 0 ?>)</h2>
      <?php if (!$forest): ?>
      <p style="color:var(--muted)"><?= t("You don't have any forest. Buy one in-game with") ?> <code>/buyforest</code>.</p>
      <?php else: ?>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($forest['owner'] ?? 'N/A') ?> (ID #<?= (int)$forest['id'] ?>)</td></tr>
        <tr><th><?= t('Price') ?></th><td>$<?= ucp_money($forest['price']) ?></td></tr>
        <tr><th><?= t('Size') ?></th><td><?= number_format((float)$forest['size'], 2) ?> <?= t('units') ?></td></tr>
        <tr><th><?= t('Max Trees') ?></th><td><?= (int)$forest['maxTree'] ?></td></tr>
        <tr><th><?= t('Current Trees') ?></th><td><?= (int)$forest['currentTree'] ?></td></tr>
        <tr><th><?= t('Saplings in storage') ?></th><td><?= (int)$forest['saplings'] ?></td></tr>
        <tr><th><?= t('Saplings planted') ?></th><td><?= (int)$forest['plantedSaplings'] ?></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $forest['isForSale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $forest['isForSale'] ? t('Yes') : t('No') ?></span></td></tr>
      </table>
      <?php endif; ?>
    </div>

    <div class="card" id="card-hotel">
      <h2>🏨 <?= t('Your hotel') ?> (<?= $myHotel ? 1 : 0 ?>)</h2>
      <?php if (!$myHotel): ?>
      <p style="color:var(--muted)"><?= t("You don't have any hotel. Buy one in-game with") ?> <code>/buyhotel</code>.</p>
      <?php else: ?>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($myHotel['name']) ?> (ID #<?= (int)$myHotel['id'] ?>)</td></tr>
        <tr><th><?= t('Price') ?></th><td>$<?= ucp_money($myHotel['price']) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($myHotel['bank']) ?></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $myHotel['is_for_sale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myHotel['is_for_sale'] ? t('Yes') : t('No') ?></span></td></tr>
        <tr><th><?= t('Rentable') ?></th><td><?= $myHotel['is_rentable'] ? (t('Yes') . ' — $' . ucp_money($myHotel['rent_price']) . '/' . t('PayDay')) : t('No') ?></td></tr>
        <?php if ($myHotel['is_rentable']): ?>
        <tr><th><?= t('Rooms taken') ?></th><td><?= $myHotelRenterCount ?>/<?= (int)($myHotel['capacity'] ?? 5) ?></td></tr>
        <?php endif; ?>
      </table>
      <?php endif; ?>
    </div>

    <div class="card" id="card-billboard">
      <h2>📢 <?= t('Your billboard') ?> (<?= $myBillboard ? 1 : 0 ?>)</h2>
      <?php if (!$myBillboard): ?>
      <p style="color:var(--muted)"><?= t("You don't have any billboard. Buy one in-game with") ?> <code>/buybillboard</code>.</p>
      <?php else: ?>
      <?php
      // bbClean: -1 while rented, 0 dirty, 1 cleaning in progress, 2 clean
      [$myBBCleanLabel, $myBBCleanTier] = ucp_bb_clean_label($myBillboard['bbClean']);
      ?>
      <table>
        <tr><th><?= t('ID') ?></th><td>#<?= (int)$myBillboard['bbID'] ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($myBillboard['bbBank']) ?></td></tr>
        <tr><th><?= t('Rented') ?></th><td><span class="pill <?= $myBillboard['bbRented'] ? 'pill-ok' : 'pill-bad' ?>"><?= $myBillboard['bbRented'] ? (((int)$myBillboard['bbRentLeft'] * 24) . 'h ' . t('left')) : t('No') ?></span></td></tr>
        <?php if ($myBillboard['bbRented']): ?>
        <tr><th><?= t('Text') ?></th><td><?= ucp_escape($myBillboard['bbText']) ?></td></tr>
        <?php else: ?>
        <tr><th><?= t('Status') ?></th><td><span class="pill pill-<?= $myBBCleanTier ?>"><?= t($myBBCleanLabel) ?></span></td></tr>
        <?php endif; ?>
        <tr><th><?= t('24h rent price') ?></th><td>$<?= ucp_money($myBillboard['bbRentPrice24H']) ?> <span style="color:var(--muted)">(<?= t('change with') ?> <code>/setrentprice [amount]</code>)</span></td></tr>
        <tr><th><?= t('For sale') ?></th><td><span class="pill <?= $myBillboard['bbIsForSale'] ? 'pill-bad' : 'pill-ok' ?>"><?= $myBillboard['bbIsForSale'] ? (t('Yes') . ' — $' . ucp_money($myBillboard['bbPrice'])) : t('No') ?></span></td></tr>
      </table>
      <?php endif; ?>
    </div>

    <?php
    $caravanImg = [
        1 => 'https://files.prineside.com/gtasa_samp_model_id/white/3174_w.jpg',
        2 => 'https://files.prineside.com/gtasa_samp_model_id/white/3171_w.jpg',
        3 => 'https://files.prineside.com/gtasa_samp_model_id/white/3172_w.jpg',
    ];
    ?>
    <div class="card" id="card-caravan">
      <h2>🚐 <?= t('Your caravan') ?> (<?= $caravan ? 1 : 0 ?>)</h2>
      <?php if (!$caravan): ?>
      <p style="color:var(--muted)"><?= t("You don't have any caravan.") ?> <?= t('These are currently handed out by server staff.') ?></p>
      <?php else: ?>
      <table>
        <tr>
          <td rowspan="4" class="caravan-box">
            <img src="<?= ucp_escape($caravanImg[(int)$player['caravan_key']] ?? '') ?>" alt="<?= t('Caravan type') ?> <?= (int)$player['caravan_key'] ?>"
                 onerror="this.parentElement.innerHTML='(<?= t('no image') ?>)';">
          </td>
          <th><?= t('Type') ?></th><td><?= ucp_escape($caravan['rName']) ?> (#<?= (int)$player['caravan_key'] ?>)</td>
        </tr>
        <tr><th><?= t('Size') ?></th><td><?= number_format((float)$caravan['rSize'], 2) ?>m</td></tr>
        <tr><th><?= t('Weight') ?></th><td><?= (int)$caravan['rWeight'] ?>kg</td></tr>
        <tr><th><?= t('Status') ?></th><td><?= $caravan['rCamping'] ? t('Camping') : t('Parked') ?></td></tr>
      </table>
      <?php endif; ?>
    </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
