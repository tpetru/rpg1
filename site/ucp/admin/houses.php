<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$houseTypeName = [1 => 'Villa', 2 => 'City House', 3 => 'Apartment', 4 => 'Countryside House'];
$sectionNav = [
  ['list', '🏠', 'Houses'],
  ['prices', '💲', 'Prices'],
  ['player', '🧍', 'Player'],
];

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    $rowAction = $_POST['row_action'] ?? '';

    // Quick add/remove buttons for fridge/bed/tree - defaults mirror /house upgrade in bare.pwn
    if ($id > 0 && $rowAction !== '') {
        if ($rowAction === 'create_fridge') {
            $expire = time() + 32 * 86400; // FRIDGE_LIFESPAN_DAYS
            $stmt = $mysqli->prepare("UPDATE `houses` SET `has_fridge`=1, `fridge_expire`=?, `fridge_milk`=0, `fridge_banana`=0, `fridge_water`=0, `fridge_juice`=0, `fridge_beer`=0 WHERE `id`=?");
            $stmt->bind_param('ii', $expire, $id);
            $stmt->execute(); $stmt->close();
            $flash = "Fridge added to house #$id.";
        } elseif ($rowAction === 'delete_fridge') {
            $stmt = $mysqli->prepare("UPDATE `houses` SET `has_fridge`=0, `fridge_expire`=0 WHERE `id`=?");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
            $flash = "Fridge removed from house #$id.";
        } elseif ($rowAction === 'create_bed') {
            $expire = time() + 29 * 86400; // BED_LIFESPAN_DAYS
            $stmt = $mysqli->prepare("UPDATE `houses` SET `has_bed`=1, `bed_expire`=? WHERE `id`=?");
            $stmt->bind_param('ii', $expire, $id);
            $stmt->execute(); $stmt->close();
            $flash = "Bed added to house #$id.";
        } elseif ($rowAction === 'delete_bed') {
            $stmt = $mysqli->prepare("UPDATE `houses` SET `has_bed`=0, `bed_expire`=0 WHERE `id`=?");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
            $flash = "Bed removed from house #$id.";
        } elseif ($rowAction === 'create_tree') {
            $now = time();
            $stmt = $mysqli->prepare("INSERT INTO `houses_tree` (`treeHouseId`, `treePlantedDate`) VALUES (?, ?)");
            $stmt->bind_param('ii', $id, $now);
            $stmt->execute();
            $newTreeId = $stmt->insert_id;
            $stmt->close();
            $stmt = $mysqli->prepare("UPDATE `houses` SET `tree_id`=? WHERE `id`=?");
            $stmt->bind_param('ii', $newTreeId, $id);
            $stmt->execute(); $stmt->close();
            $flash = "Tree planted at house #$id.";
        } elseif ($rowAction === 'delete_tree') {
            $treeId = (int)($_POST['tree_id'] ?? 0);
            if ($treeId > 0) {
                $stmt = $mysqli->prepare("DELETE FROM `houses_tree` WHERE `treeId`=?");
                $stmt->bind_param('i', $treeId);
                $stmt->execute(); $stmt->close();
            }
            $stmt = $mysqli->prepare("UPDATE `houses` SET `tree_id`=0 WHERE `id`=?");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
            $flash = "Tree removed from house #$id.";
        }
    } elseif ($id > 0) {
        $name  = trim($_POST['name'] ?? '');
        $type  = max(1, min(4, (int)($_POST['type'] ?? 1)));
        $price = max(0, (int)($_POST['price'] ?? 0));
        $bank  = (int)($_POST['bank'] ?? 0);
        $forSale = isset($_POST['is_for_sale']) ? 1 : 0;
        $rentable = isset($_POST['is_rentable']) ? 1 : 0;
        $rentPrice = max(0, (int)($_POST['rent_price'] ?? 0));
        $ownerRaw = trim($_POST['owner_id'] ?? '');

        if (strcasecmp($ownerRaw, 'none') === 0 || $ownerRaw === '') {
            $ownerId = 0; $ownerName = ''; $owned = 0;
        } else {
            $ownerId = (int)$ownerRaw;
            $ownerName = ucp_username_by_id($mysqli, $ownerId);
            if ($ownerName === null) {
                $flash = "Player ID $ownerRaw not found."; $flashErr = true;
            }
            $owned = 1;
        }

        if (!$flashErr) {
            $stmt = $mysqli->prepare("UPDATE `houses` SET `name`=?, `type`=?, `price`=?, `bank`=?, `is_for_sale`=?, `is_rentable`=?, `rent_price`=?, `owner_id`=?, `owner`=?, `owned`=? WHERE `id`=?");
            $stmt->bind_param('siiiiiiisii', $name, $type, $price, $bank, $forSale, $rentable, $rentPrice, $ownerId, $ownerName, $owned, $id);
            $stmt->execute();
            $stmt->close();

            // Fridge contents (only present in the form if the house currently has a fridge)
            if (isset($_POST['fridge_milk'])) {
                $fridgeMax = ['fridge_milk' => 20, 'fridge_banana' => 30, 'fridge_water' => 25, 'fridge_juice' => 20, 'fridge_beer' => 50];
                $fv = [];
                foreach ($fridgeMax as $col => $max) {
                    $fv[$col] = max(0, min($max, (int)($_POST[$col] ?? 0)));
                }
                $stmt = $mysqli->prepare("UPDATE `houses` SET `fridge_milk`=?, `fridge_banana`=?, `fridge_water`=?, `fridge_juice`=?, `fridge_beer`=? WHERE `id`=?");
                $stmt->bind_param('iiiiii', $fv['fridge_milk'], $fv['fridge_banana'], $fv['fridge_water'], $fv['fridge_juice'], $fv['fridge_beer'], $id);
                $stmt->execute();
                $stmt->close();
            }

            // Tree fruit growth (only present in the form if this house has a tree planted)
            if (isset($_POST['tree_fruit_status']) && (int)($_POST['tree_id'] ?? 0) > 0) {
                $treeId = (int)$_POST['tree_id'];
                $fruitStatus = max(0, min(30, (int)$_POST['tree_fruit_status']));
                $stmt = $mysqli->prepare("UPDATE `houses_tree` SET `treeFruitStatus`=? WHERE `treeId`=?");
                $stmt->bind_param('ii', $fruitStatus, $treeId);
                $stmt->execute();
                $stmt->close();
            }

            $flash = "House #$id updated.";
        }
    }
}

$houses = $mysqli->query("SELECT * FROM `houses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

// Trees, keyed by treeId (see tree_id on houses)
$treesById = [];
$treeRows = $mysqli->query("SELECT * FROM `houses_tree`")->fetch_all(MYSQLI_ASSOC);
foreach ($treeRows as $t) { $treesById[(int)$t['treeId']] = $t; }

$fridgeItems = [
    'fridge_milk'   => ['Milk', 'cartons', 20],
    'fridge_banana' => ['Bananas', 'pcs', 30],
    'fridge_water'  => ['Water', 'L', 25],
    'fridge_juice'  => ['Juice', 'bottles', 20],
    'fridge_beer'   => ['Beer', 'cans', 50],
];

$adminActive = 'houses';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Houses</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>

<nav class="section-nav" aria-label="Jump to section">
  <?php foreach ($sectionNav as [$anchorId, $icon, $label]): ?>
  <a href="/ucp/admin/<?= $anchorId ?>.php" title="<?= htmlspecialchars($label) ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>

<main>
  <h1>🏠 Houses</h1>
  <p style="color:var(--muted)">Edit houses directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr><th>ID</th><th>Name</th><th>Type</th><th>Price</th><th>Bank</th><th>Rent price</th><th>Owner (player ID / none)</th><th class="chk">For sale</th><th class="chk">Rentable</th><th></th></tr>
      <?php foreach ($houses as $h): $fid = 'house-' . (int)$h['id']; ?>
      <tr>
          <td>#<?= (int)$h['id'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="name" value="<?= ucp_escape($h['name']) ?>"></td>
          <td>
            <select form="<?= $fid ?>" name="type">
              <?php foreach ($houseTypeName as $tid => $tname): ?>
                <option value="<?= $tid ?>" <?= ((int)$h['type'] === $tid) ? 'selected' : '' ?>><?= ucp_escape($tname) ?></option>
              <?php endforeach; ?>
            </select>
          </td>
          <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$h['price'] ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="bank" value="<?= (int)$h['bank'] ?>"></td>
          <td><input form="<?= $fid ?>" type="number" name="rent_price" value="<?= (int)$h['rent_price'] ?>"></td>
          <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= $h['owned'] ? (int)$h['owner_id'] : 'none' ?>" placeholder="none"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $h['is_for_sale'] ? 'checked' : '' ?>></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_rentable" <?= $h['is_rentable'] ? 'checked' : '' ?>></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <input type="hidden" name="id" value="<?= (int)$h['id'] ?>">
              <button type="submit" class="save-btn">Save</button>
            </form>
          </td>
      </tr>
      <tr>
        <td colspan="10" style="background:var(--panel-2)">
          <div style="display:flex; gap:24px; flex-wrap:wrap; font-size:0.86rem">
            <div style="flex:1 1 320px; min-width:320px">
              <strong>🧊 Fridge</strong>
              <?php if (!$h['has_fridge']): ?>
                <p style="color:var(--muted); margin:4px 0">None.</p>
                <button form="<?= $fid ?>" type="submit" name="row_action" value="create_fridge" class="save-btn">Create fridge</button>
              <?php else:
                $fridgeBroken = (int)$h['fridge_expire'] > 0 && time() >= (int)$h['fridge_expire'];
              ?>
                <p style="margin:4px 0">
                  <span class="pill <?= $fridgeBroken ? 'pill-bad' : 'pill-ok' ?>"><?= $fridgeBroken ? 'Broken' : 'Working' ?></span>
                  <?php if ((int)$h['fridge_expire'] > 0): ?>
                    <span style="color:var(--muted)">(breaks <?= date('d.m.Y', (int)$h['fridge_expire']) ?>)</span>
                  <?php endif; ?>
                </p>
                <table class="edittable" style="width:100%">
                  <tr><th>Food</th><th>Quantity</th><th>Capacity</th></tr>
                  <?php foreach ($fridgeItems as $col => [$label, $unit, $max]): ?>
                  <tr>
                    <td><?= ucp_escape($label) ?></td>
                    <td style="max-width:110px">
                      <input form="<?= $fid ?>" type="number" name="<?= $col ?>" min="0" max="<?= $max ?>" value="<?= (int)$h[$col] ?>"> <?= $unit ?>
                    </td>
                    <td><?= $max ?> <?= $unit ?></td>
                  </tr>
                  <?php endforeach; ?>
                </table>
                <button form="<?= $fid ?>" type="submit" name="row_action" value="delete_fridge" class="save-btn" style="background:var(--red); margin-top:6px">Delete fridge</button>
              <?php endif; ?>
            </div>
            <div style="flex:1 1 240px; min-width:240px">
              <strong>🛏️ Bed</strong>
              <?php if (!$h['has_bed']): ?>
                <p style="color:var(--muted); margin:4px 0">None.</p>
                <button form="<?= $fid ?>" type="submit" name="row_action" value="create_bed" class="save-btn">Create bed</button>
              <?php else:
                $bedBroken = (int)$h['bed_expire'] > 0 && time() >= (int)$h['bed_expire'];
              ?>
                <table style="width:100%">
                  <tr><th>Status</th><th>Breaks on</th></tr>
                  <tr>
                    <td><span class="pill <?= $bedBroken ? 'pill-bad' : 'pill-ok' ?>"><?= $bedBroken ? 'Broken' : 'Working' ?></span></td>
                    <td><?= (int)$h['bed_expire'] > 0 ? date('d.m.Y', (int)$h['bed_expire']) : '—' ?></td>
                  </tr>
                </table>
                <button form="<?= $fid ?>" type="submit" name="row_action" value="delete_bed" class="save-btn" style="background:var(--red); margin-top:6px">Delete bed</button>
              <?php endif; ?>
            </div>
            <div style="flex:1 1 320px; min-width:320px">
              <strong>🌳 Tree</strong>
              <?php $tree = $treesById[(int)$h['tree_id']] ?? null; ?>
              <?php if (!$tree): ?>
                <p style="color:var(--muted); margin:4px 0">None.</p>
                <?php if (in_array((int)$h['type'], [2, 4], true)): ?>
                  <button form="<?= $fid ?>" type="submit" name="row_action" value="create_tree" class="save-btn">Plant tree</button>
                <?php else: ?>
                  <p style="color:var(--muted); font-size:0.8rem; margin:4px 0">Only City/Countryside houses can have a tree.</p>
                <?php endif; ?>
              <?php else: ?>
                <table class="edittable" style="width:100%">
                  <tr><th>Name</th><th>Fruit growth</th><th>Status</th></tr>
                  <tr>
                    <td><?= ucp_escape($tree['treeName']) ?> (#<?= (int)$tree['treeId'] ?>)</td>
                    <td style="max-width:110px">
                      <input form="<?= $fid ?>" type="number" name="tree_fruit_status" min="0" max="30" value="<?= (int)$tree['treeFruitStatus'] ?>">
                      <input form="<?= $fid ?>" type="hidden" name="tree_id" value="<?= (int)$tree['treeId'] ?>">
                      /30
                    </td>
                    <td>
                      <?php if ((int)$tree['treeFruitStatus'] >= 30): ?>
                        <span class="pill pill-ok">Ready to harvest</span>
                      <?php else: ?>
                        <span style="color:var(--muted)">Growing</span>
                      <?php endif; ?>
                    </td>
                  </tr>
                </table>
                <button form="<?= $fid ?>" type="submit" name="row_action" value="delete_tree" class="save-btn" style="background:var(--red); margin-top:6px">Remove tree</button>
              <?php endif; ?>
            </div>
          </div>
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
