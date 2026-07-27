<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_admin();

$myLevel = ucp_current_admin_level();
if ($myLevel < 5) {
    // Editarea proprietăților (case/business/vehicule/ferme) necesită nivel 5 în joc (/hc /bc /vc /farmc)
    header('Location: dashboard.php');
    exit;
}

$houseTypeName = [1 => 'Villa', 2 => 'City House', 3 => 'Apartment', 4 => 'Countryside House'];
$ffTypeName    = [1 => 'Pizza', 2 => 'Burger', 3 => 'Cluckin Bell'];

// Cauta un player dupa id, intoarce username-ul sau null daca nu exista
function ucp_username_by_id($mysqli, $id) {
    $id = (int)$id;
    if ($id <= 0) return null;
    $stmt = $mysqli->prepare("SELECT `username` FROM `players` WHERE `id` = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ? $row['username'] : null;
}

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $entity = $_POST['entity'] ?? '';
    $id = (int)($_POST['id'] ?? 0);

    if ($entity === 'house' && $id > 0) {
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
            $flash = "House #$id updated.";
        }
    }

    if ($entity === 'business' && $id > 0) {
        $name  = trim($_POST['name'] ?? '');
        $price = max(0, (int)($_POST['price'] ?? 0));
        $bank  = (int)($_POST['bank'] ?? 0);
        $forSale = isset($_POST['is_for_sale']) ? 1 : 0;
        $anaf = isset($_POST['anaf']) ? 1 : 0;
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
            $stmt = $mysqli->prepare("UPDATE `businesses` SET `name`=?, `price`=?, `bank`=?, `is_for_sale`=?, `anaf`=?, `owner_id`=?, `owner`=?, `owned`=? WHERE `id`=?");
            $stmt->bind_param('siiiiisii', $name, $price, $bank, $forSale, $anaf, $ownerId, $ownerName, $owned, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Business #$id updated.";
        }
    }

    if ($entity === 'vehicle' && $id > 0) {
        $price = max(0, (int)($_POST['price'] ?? 0));
        $forSale = isset($_POST['is_for_sale']) ? 1 : 0;
        $locked = isset($_POST['locked']) ? 1 : 0;
        $confiscated = isset($_POST['is_confiscated']) ? 1 : 0;
        $ownerRaw = trim($_POST['owner_id'] ?? '');
        $ownerId = (strcasecmp($ownerRaw, 'none') === 0 || $ownerRaw === '') ? 0 : (int)$ownerRaw;

        if ($ownerId > 0 && ucp_username_by_id($mysqli, $ownerId) === null) {
            $flash = "Player ID $ownerRaw not found."; $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `vehicles_personal` SET `price`=?, `is_for_sale`=?, `locked`=?, `is_confiscated`=?, `owner_id`=? WHERE `id`=?");
            $stmt->bind_param('iiiiii', $price, $forSale, $locked, $confiscated, $ownerId, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Vehicle #$id updated.";
        }
    }

    if ($entity === 'farm' && $id > 0) {
        $name  = trim($_POST['name'] ?? '');
        $price = max(0, (int)($_POST['price'] ?? 0));
        $bank  = (int)($_POST['bank'] ?? 0);
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
            $stmt = $mysqli->prepare("UPDATE `farms` SET `name`=?, `price`=?, `farmBank`=?, `is_for_sale`=?, `owner_id`=?, `owner`=?, `isOwned`=? WHERE `id`=?");
            $stmt->bind_param('siiiisii', $name, $price, $bank, $forSale, $ownerId, $ownerName, $isOwned, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Farm #$id updated.";
        }
    }

    if ($entity === 'fastfood' && $id > 0) {
        $name = trim($_POST['name'] ?? '');
        $type = max(1, min(3, (int)($_POST['type'] ?? 1)));
        $stmt = $mysqli->prepare("UPDATE `fastfood` SET `ffName`=?, `ffType`=? WHERE `ffID`=?");
        $stmt->bind_param('sii', $name, $type, $id);
        $stmt->execute();
        $stmt->close();
        $flash = "Fast-food #$id updated.";
    }
}

$houses      = $mysqli->query("SELECT * FROM `houses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$businesses  = $mysqli->query("SELECT * FROM `businesses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$vehicles    = $mysqli->query("SELECT * FROM `vehicles_personal` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$farms       = $mysqli->query("SELECT * FROM `farms` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$shops       = $mysqli->query("SELECT * FROM `shops` ORDER BY `shopID` ASC")->fetch_all(MYSQLI_ASSOC);
$fastfood    = $mysqli->query("SELECT * FROM `fastfood` ORDER BY `ffID` ASC")->fetch_all(MYSQLI_ASSOC);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NostalgiaRP UCP — Admin Panel</title>
<link rel="stylesheet" href="assets/css/style.css">
<style>
  nav.subtabs { position: sticky; top: 0; z-index: 10; display: flex; gap: 6px; flex-wrap: wrap; padding: 10px 0; background: var(--bg); border-bottom: 1px solid var(--border); margin-bottom: 16px; }
  nav.subtabs a { background: var(--panel); border: 1px solid var(--border); border-radius: 999px; padding: 5px 14px; font-size: 0.85rem; color: var(--text); }
  nav.subtabs a:hover { color: var(--accent); border-color: var(--accent); text-decoration: none; }
  table.edittable input[type=text], table.edittable input[type=number] {
    width: 100%; min-width: 70px; background: var(--panel-2); border: 1px solid var(--border);
    border-radius: 6px; padding: 5px 7px; color: var(--text); font-size: 0.86rem;
  }
  table.edittable select { background: var(--panel-2); border: 1px solid var(--border); border-radius: 6px; padding: 5px 7px; color: var(--text); font-size: 0.86rem; }
  table.edittable td { vertical-align: middle; }
  table.edittable .chk { display: flex; align-items: center; justify-content: center; }
  .save-btn { background: var(--accent); border: none; border-radius: 6px; padding: 6px 14px; color: #0f1115; font-weight: 700; font-size: 0.82rem; cursor: pointer; }
  .save-btn:hover { opacity: 0.9; }
  .flash { padding: 10px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 0.92rem; }
  .flash.ok { background: rgba(62,207,142,0.1); border: 1px solid var(--green); color: var(--green); }
  .flash.err { background: rgba(255,93,93,0.1); border: 1px solid var(--red); color: var(--red); }
  section { scroll-margin-top: 60px; margin-bottom: 40px; }
</style>
</head>
<body>

<header class="topbar">
  <div class="brand">🏙️ NostalgiaRP UCP</div>
  <nav>
    <a href="dashboard.php">Dashboard</a>
    <a href="maps.php">Map</a>
    <a href="howto.php">How To</a>
    <a href="admin.php">Admin</a>
    <a href="admincmds.php">Admin Cmds</a>
    <a href="logout.php">Logout</a>
  </nav>
  <div class="userbox"><?= ucp_escape($_SESSION['ucp_username']) ?> · admin lvl <?= $myLevel ?></div>
</header>

<main style="max-width:1300px">
  <h1>🛠️ Admin Panel</h1>
  <p style="color:var(--muted)">Edit houses, businesses, vehicles, farms, shops and fast-food directly. Changes are saved immediately to the database.</p>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <nav class="subtabs">
    <a href="#houses">Houses (<?= count($houses) ?>)</a>
    <a href="#businesses">Businesses (<?= count($businesses) ?>)</a>
    <a href="#vehicles">Vehicles (<?= count($vehicles) ?>)</a>
    <a href="#farms">Farms (<?= count($farms) ?>)</a>
    <a href="#shops">Shops (<?= count($shops) ?>)</a>
    <a href="#fastfood">Fast-food (<?= count($fastfood) ?>)</a>
  </nav>

  <section id="houses">
    <div class="card">
      <h2>🏠 Houses</h2>
      <div style="overflow-x:auto">
      <table class="edittable">
        <tr><th>ID</th><th>Name</th><th>Type</th><th>Price</th><th>Bank</th><th>For sale</th><th>Rentable</th><th>Rent price</th><th>Owner (player ID / none)</th><th></th></tr>
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
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $h['is_for_sale'] ? 'checked' : '' ?>></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_rentable" <?= $h['is_rentable'] ? 'checked' : '' ?>></td>
            <td><input form="<?= $fid ?>" type="number" name="rent_price" value="<?= (int)$h['rent_price'] ?>"></td>
            <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= $h['owned'] ? (int)$h['owner_id'] : 'none' ?>" placeholder="none"></td>
            <td>
              <form id="<?= $fid ?>" method="post" action="admin.php#houses">
                <input type="hidden" name="entity" value="house">
                <input type="hidden" name="id" value="<?= (int)$h['id'] ?>">
              </form>
              <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
            </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

  <section id="businesses">
    <div class="card">
      <h2>🏢 Businesses</h2>
      <div style="overflow-x:auto">
      <table class="edittable">
        <tr><th>ID</th><th>Name</th><th>Price</th><th>Bank</th><th>For sale</th><th>ANAF locked</th><th>Owner (player ID / none)</th><th></th></tr>
        <?php foreach ($businesses as $b): $fid = 'business-' . (int)$b['id']; ?>
        <tr>
            <td>#<?= (int)$b['id'] ?></td>
            <td><input form="<?= $fid ?>" type="text" name="name" value="<?= ucp_escape($b['name']) ?>"></td>
            <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$b['price'] ?>"></td>
            <td><input form="<?= $fid ?>" type="number" name="bank" value="<?= (int)$b['bank'] ?>"></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $b['is_for_sale'] ? 'checked' : '' ?>></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="anaf" <?= $b['anaf'] ? 'checked' : '' ?>></td>
            <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= $b['owned'] ? (int)$b['owner_id'] : 'none' ?>" placeholder="none"></td>
            <td>
              <form id="<?= $fid ?>" method="post" action="admin.php#businesses">
                <input type="hidden" name="entity" value="business">
                <input type="hidden" name="id" value="<?= (int)$b['id'] ?>">
              </form>
              <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
            </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

  <section id="vehicles">
    <div class="card">
      <h2>🚗 Personal vehicles</h2>
      <div style="overflow-x:auto">
      <table class="edittable">
        <tr><th>ID</th><th>Model</th><th>Plate</th><th>Price</th><th>For sale</th><th>Locked</th><th>Confiscated</th><th>Owner (player ID / none)</th><th></th></tr>
        <?php foreach ($vehicles as $v): $fid = 'vehicle-' . (int)$v['id']; ?>
        <tr>
            <td>#<?= (int)$v['id'] ?></td>
            <td>Model #<?= (int)$v['model_id'] ?></td>
            <td><?= ucp_escape($v['plate'] ?? '—') ?></td>
            <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$v['price'] ?>"></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $v['is_for_sale'] ? 'checked' : '' ?>></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="locked" <?= $v['locked'] ? 'checked' : '' ?>></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_confiscated" <?= $v['is_confiscated'] ? 'checked' : '' ?>></td>
            <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= (int)$v['owner_id'] > 0 ? (int)$v['owner_id'] : 'none' ?>" placeholder="none"></td>
            <td>
              <form id="<?= $fid ?>" method="post" action="admin.php#vehicles">
                <input type="hidden" name="entity" value="vehicle">
                <input type="hidden" name="id" value="<?= (int)$v['id'] ?>">
              </form>
              <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
            </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

  <section id="farms">
    <div class="card">
      <h2>🌾 Farms</h2>
      <div style="overflow-x:auto">
      <table class="edittable">
        <tr><th>ID</th><th>Name</th><th>Price</th><th>Bank</th><th>For sale</th><th>Owner (player ID / none)</th><th></th></tr>
        <?php foreach ($farms as $f): $fid = 'farm-' . (int)$f['id']; ?>
        <tr>
            <td>#<?= (int)$f['id'] ?></td>
            <td><input form="<?= $fid ?>" type="text" name="name" value="<?= ucp_escape($f['name']) ?>"></td>
            <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$f['price'] ?>"></td>
            <td><input form="<?= $fid ?>" type="number" name="bank" value="<?= (int)$f['farmBank'] ?>"></td>
            <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $f['is_for_sale'] ? 'checked' : '' ?>></td>
            <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= $f['isOwned'] ? (int)$f['owner_id'] : 'none' ?>" placeholder="none"></td>
            <td>
              <form id="<?= $fid ?>" method="post" action="admin.php#farms">
                <input type="hidden" name="entity" value="farm">
                <input type="hidden" name="id" value="<?= (int)$f['id'] ?>">
              </form>
              <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
            </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

  <section id="shops">
    <div class="card">
      <h2>🛒 Shops</h2>
      <p style="color:var(--muted)">Shops only store a location (no name/price/owner in the database) — read-only.</p>
      <div style="overflow-x:auto">
      <table>
        <tr><th>ID</th><th>X</th><th>Y</th><th>Z</th></tr>
        <?php foreach ($shops as $s): ?>
        <tr>
          <td>#<?= (int)$s['shopID'] ?></td>
          <td><?= number_format((float)$s['shopLocX'], 2) ?></td>
          <td><?= number_format((float)$s['shopLocY'], 2) ?></td>
          <td><?= number_format((float)$s['shopLocZ'], 2) ?></td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

  <section id="fastfood">
    <div class="card">
      <h2>🍔 Fast-food</h2>
      <div style="overflow-x:auto">
      <table class="edittable">
        <tr><th>ID</th><th>Name</th><th>Type</th><th></th></tr>
        <?php foreach ($fastfood as $f): $fid = 'fastfood-' . (int)$f['ffID']; ?>
        <tr>
            <td>#<?= (int)$f['ffID'] ?></td>
            <td><input form="<?= $fid ?>" type="text" name="name" value="<?= ucp_escape($f['ffName']) ?>"></td>
            <td>
              <select form="<?= $fid ?>" name="type">
                <?php foreach ($ffTypeName as $tid => $tname): ?>
                  <option value="<?= $tid ?>" <?= ((int)$f['ffType'] === $tid) ? 'selected' : '' ?>><?= ucp_escape($tname) ?></option>
                <?php endforeach; ?>
              </select>
            </td>
            <td>
              <form id="<?= $fid ?>" method="post" action="admin.php#fastfood">
                <input type="hidden" name="entity" value="fastfood">
                <input type="hidden" name="id" value="<?= (int)$f['ffID'] ?>">
              </form>
              <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
            </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    </div>
  </section>

</main>

<footer>NostalgiaRP UCP</footer>

</body>
</html>
