<?php
require_once __DIR__ . '/../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
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
}

$vehicles = $mysqli->query("SELECT * FROM `vehicles_personal` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'vehicles';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Vehicles</title>
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>🚗 Personal vehicles</h1>
  <p style="color:var(--muted)">Edit personal vehicles directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr><th>ID</th><th>Model</th><th>Plate</th><th>Price</th><th class="chk">For sale</th><th class="chk">Locked</th><th class="chk">Confiscated</th><th>Owner (player ID / none)</th><th></th></tr>
      <?php foreach ($vehicles as $v): $fid = 'vehicle-' . (int)$v['id']; ?>
      <tr>
          <td>#<?= (int)$v['id'] ?></td>
          <td><?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?></td>
          <td><?= ucp_escape($v['plate'] ?? '—') ?></td>
          <td><input form="<?= $fid ?>" type="number" name="price" value="<?= (int)$v['price'] ?>"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_for_sale" <?= $v['is_for_sale'] ? 'checked' : '' ?>></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="locked" <?= $v['locked'] ? 'checked' : '' ?>></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="is_confiscated" <?= $v['is_confiscated'] ? 'checked' : '' ?>></td>
          <td><input form="<?= $fid ?>" type="text" name="owner_id" value="<?= (int)$v['owner_id'] > 0 ? (int)$v['owner_id'] : 'none' ?>" placeholder="none"></td>
          <td>
            <form id="<?= $fid ?>" method="post"></form>
            <input form="<?= $fid ?>" type="hidden" name="id" value="<?= (int)$v['id'] ?>">
            <button form="<?= $fid ?>" type="submit" class="save-btn">Save</button>
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
