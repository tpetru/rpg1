<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

$farmEquipModels = [
    'add_tractor' => 531, 'add_combine' => 532, 'add_dozer' => 486, 'add_truck' => 403, 'add_trailer' => 450,
];
$farmEquipTypes = [
    531 => ['Tractor', 16],
    486 => ['Bulldozer', 6],
    532 => ['Combine', 11],
    403 => ['Truck', 12],
    450 => ['Trailer', 15],
];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    $rowAction = $_POST['row_action'] ?? '';

    // Quick add/remove buttons for equipment - mirrors /farm buy (admin free-grant: no price charged)
    if ($id > 0 && $rowAction !== '' && isset($farmEquipModels[$rowAction])) {
        $model = $farmEquipModels[$rowAction];
        $stmt = $mysqli->prepare("INSERT INTO `farm_equipment` (`farm_id`, `model`, `uses`) VALUES (?, ?, 0)");
        $stmt->bind_param('ii', $id, $model);
        $stmt->execute();
        $stmt->close();
        $flash = "Equipment added to farm #$id.";
    } elseif ($id > 0 && $rowAction === 'delete_equip') {
        $equipId = (int)($_POST['equip_id'] ?? 0);
        if ($equipId > 0) {
            $stmt = $mysqli->prepare("DELETE FROM `farm_equipment` WHERE `id`=? AND `farm_id`=?");
            $stmt->bind_param('ii', $equipId, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Equipment #$equipId removed from farm #$id.";
        }
    } elseif ($id > 0 && $rowAction === 'update_equip_uses') {
        $equipId = (int)($_POST['equip_id'] ?? 0);
        $model = (int)($_POST['equip_model'] ?? 0);
        $max = $farmEquipTypes[$model][1] ?? 1;
        $uses = max(0, min($max, (int)($_POST['uses'] ?? 0)));
        if ($equipId > 0) {
            $stmt = $mysqli->prepare("UPDATE `farm_equipment` SET `uses`=? WHERE `id`=? AND `farm_id`=?");
            $stmt->bind_param('iii', $uses, $equipId, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Equipment #$equipId updated ($uses/$max uses).";
        }
    } elseif ($id > 0) {
        $name  = trim($_POST['name'] ?? '');
        $price = max(0, (int)($_POST['price'] ?? 0));
        $bank  = (int)($_POST['bank'] ?? 0);
        $recolta = max(0, (int)($_POST['recolta'] ?? 0));
        $forSale = isset($_POST['is_for_sale']) ? 1 : 0;
        $ownerRaw = trim($_POST['owner_id'] ?? '');

        if (strcasecmp($ownerRaw, 'none') === 0 || $ownerRaw === '') {
            $ownerId = 0; $ownerName = ''; $isOwned = 0;
        } else {
            $ownerId = (int)$ownerRaw;
            $ownerName = ucp_username_by_id($mysqli, $ownerId);
            if ($ownerName === null) {
                $flash = "Player ID $ownerRaw not found."; $flashErr = true;
            }
            $isOwned = 1;
        }

        if (!$flashErr) {
            $stmt = $mysqli->prepare("UPDATE `farms` SET `name`=?, `price`=?, `farmBank`=?, `farmRecolta`=?, `is_for_sale`=?, `owner_id`=?, `owner`=?, `isOwned`=? WHERE `id`=?");
            $stmt->bind_param('siiiiisii', $name, $price, $bank, $recolta, $forSale, $ownerId, $ownerName, $isOwned, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Farm #$id updated.";
        }
    }
}

$farms = $mysqli->query("SELECT * FROM `farms` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

// Individual farm equipment (each with its own wear), grouped by farm_id - see farm_equipment in bare.pwn
$farmEquipByFarm = [];
try {
    $rows = $mysqli->query("SELECT * FROM `farm_equipment` ORDER BY `farm_id` ASC, `model` ASC, `id` ASC")->fetch_all(MYSQLI_ASSOC);
    foreach ($rows as $r) { $farmEquipByFarm[(int)$r['farm_id']][] = $r; }
} catch (mysqli_sql_exception $e) {
    $farmEquipByFarm = null; // table doesn't exist yet
}

$adminActive = 'farms';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Farms</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>

<main>
  <h1>🌾 Farms</h1>
  <p style="color:var(--muted)">Edit farms directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr><th>ID</th><th>Name</th><th>Price</th><th>Bank</th><th>Recolta</th><th class="chk">For sale</th><th>Owner (player ID / none)</th><th></th></tr>
      <?php foreach ($farms as $f): $fid = 'farm-' . (int)$f['id']; ?>
      <tr>
          <td>#<?= (int)$f['id'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="name" value="<?= ucp_escape($f['name']) ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$f['price'] ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="bank" value="<?= (int)$f['farmBank'] ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="recolta" value="<?= (int)$f['farmRecolta'] ?>"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $f['is_for_sale'] ? 'checked' : '' ?>></td>
          <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= $f['isOwned'] ? (int)$f['owner_id'] : 'none' ?>" placeholder="none"></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <input type="hidden" name="id" value="<?= (int)$f['id'] ?>">
              <button type="submit" class="save-btn">Save</button>
            </form>
          </td>
      </tr>
      <tr>
        <td colspan="8" style="background:var(--panel-2)">
          <?php $equip = $farmEquipByFarm[(int)$f['id']] ?? []; ?>
          <?php if ($farmEquipByFarm === null): ?>
            <span style="color:var(--muted)">Equipment: <?= (int)$f['tractors'] ?> tractor(s), <?= (int)$f['combines'] ?> combine(s), <?= (int)$f['dozers'] ?> dozer(s), <?= (int)$f['trucks'] ?> truck(s), <?= (int)$f['trailers'] ?> trailer(s)</span>
          <?php else: ?>
            <?php if (!$equip): ?>
              <p style="color:var(--muted); margin:4px 0">No equipment.</p>
            <?php else: ?>
              <table class="edittable" style="width:100%">
                <tr><th>Equipment</th><th>Health (current/max)</th><th>Status</th><th></th></tr>
                <?php foreach ($equip as $eq):
                    $eqInfo = $farmEquipTypes[(int)$eq['model']] ?? ['Unknown', 1];
                    [$eqLabel, $eqMax] = $eqInfo;
                    $eqBroken = (int)$eq['uses'] >= $eqMax;
                    $eqHealth = (int)round(min(100, (int)$eq['uses'] / $eqMax * 100));
                    if ($eqHealth >= 100)     { $eqTier = 'bad';  $eqWord = 'Broken'; }
                    elseif ($eqHealth >= 70)  { $eqTier = 'warn'; $eqWord = 'Poor'; }
                    elseif ($eqHealth >= 40)  { $eqTier = 'good'; $eqWord = 'Good'; }
                    else                      { $eqTier = 'ok';   $eqWord = 'Excellent'; }
                    $eqFid = 'farm-' . (int)$f['id'] . '-eq-' . (int)$eq['id'];
                ?>
                <tr>
                  <td><?= ucp_escape($eqLabel) ?> (#<?= (int)$eq['id'] ?>)</td>
                  <td>
                    <span class="meter"><span class="meter-fill <?= $eqTier ?>" style="width:<?= $eqHealth ?>%"></span></span>
                    <span class="meter-label"><?= (int)$eq['uses'] ?> / <?= $eqMax ?></span>
                  </td>
                  <td><span class="pill pill-<?= $eqTier ?>"><?= $eqWord ?></span></td>
                  <td>
                    <form id="<?= $eqFid ?>" method="post" style="display:flex; gap:6px; align-items:center; flex-wrap:wrap">
                      <input type="hidden" name="id" value="<?= (int)$f['id'] ?>">
                      <input type="hidden" name="equip_id" value="<?= (int)$eq['id'] ?>">
                      <input type="hidden" name="equip_model" value="<?= (int)$eq['model'] ?>">
                      <input type="number" name="uses" min="0" value="<?= (int)$eq['uses'] ?>" style="width:60px">
                      <button type="submit" name="row_action" value="update_equip_uses" class="save-btn">Save</button>
                      <button type="submit" name="row_action" value="delete_equip" class="save-btn" style="background:var(--red)">Remove</button>
                    </form>
                  </td>
                </tr>
                <?php endforeach; ?>
              </table>
            <?php endif; ?>
            <div style="display:flex; gap:8px; flex-wrap:wrap; margin-top:8px">
              <?php foreach ($farmEquipModels as $action => $model):
                  $addFid = 'farm-' . (int)$f['id'] . '-' . $action;
                  $addLabel = $farmEquipTypes[$model][0] ?? $action;
              ?>
                <form id="<?= $addFid ?>" method="post">
                  <input type="hidden" name="id" value="<?= (int)$f['id'] ?>">
                  <button type="submit" name="row_action" value="<?= $action ?>" class="save-btn">+ <?= ucp_escape($addLabel) ?></button>
                </form>
              <?php endforeach; ?>
            </div>
          <?php endif; ?>
        </td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
