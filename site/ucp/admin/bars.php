<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$barTypeName = [1 => 'Pub', 2 => 'Dance', 3 => 'Cafe'];

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !ucp_csrf_verify()) {
    $flash = "Security check failed (invalid or expired form). Please try again.";
    $flashErr = true;
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
        $name       = trim($_POST['name'] ?? '');
        $type       = (int)($_POST['type'] ?? 1);
        $gtaIntId   = max(0, (int)($_POST['gta_interior_id'] ?? 0));
        $vwId       = max(0, (int)($_POST['vw_id'] ?? 0));
        $stockMax   = max(0, (int)($_POST['stock_max'] ?? 0));
        $stockCurr  = max(0, (int)($_POST['stock_curr'] ?? 0));
        $terrace    = isset($_POST['terrace']) ? 1 : 0;

        if (!isset($barTypeName[$type])) $type = 1;
        if ($stockCurr > $stockMax) $stockCurr = $stockMax;

        if ($name === '') {
            $flash = "Name cannot be empty.";
            $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `bars` SET `name`=?, `type`=?, `gta_interior_id`=?, `vw_id`=?, `stock_max`=?, `stock_curr`=?, `terrace`=? WHERE `id`=?");
            $stmt->bind_param('siiiiiii', $name, $type, $gtaIntId, $vwId, $stockMax, $stockCurr, $terrace, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Bar #$id updated.";
        }
    }
}

try {
    $bars = $mysqli->query("SELECT * FROM `bars` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $bars = null; // table doesn't exist yet - the gamemode creates it on startup
}

$adminActive = 'bars';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Bars</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>
<?php include __DIR__ . '/../../includes/admin_section_nav.php'; ?>

<main>
  <h1>🍺 Bars</h1>
  <p style="color:var(--muted)">Edit bars directly. Changes are saved immediately to the database. Creating/repositioning bars is still done in-game with <code>/barcreate</code> (admin level 6+) and <code>/barc</code> (admin level 5+). Interior/VW changes here only take effect in-game after a server restart.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <?php if ($bars === null): ?>
  <div class="card">
    <p style="color:var(--muted)">The <code>bars</code> table doesn't exist yet. It's created automatically by the gamemode on startup - run the server once, then reload this page.</p>
  </div>
  <?php else: ?>
  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr>
        <th>ID</th><th>Name</th><th>Type</th><th>GTA Interior ID</th><th>VW</th>
        <th>Stock max</th><th>Stock curr</th><th class="chk">Terrace</th><th>X</th><th>Y</th><th>Z</th><th></th>
      </tr>
      <?php foreach ($bars as $b): $fid = 'bar-' . (int)$b['id']; ?>
      <tr>
          <td>#<?= (int)$b['id'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="name" maxlength="32" value="<?= ucp_escape($b['name']) ?>" style="width:140px"></td>
          <td>
            <select form="<?= $fid ?>" name="type">
              <?php foreach ($barTypeName as $val => $label): ?>
                <option value="<?= $val ?>" <?= (int)$b['type'] === $val ? 'selected' : '' ?>><?= $label ?></option>
              <?php endforeach; ?>
            </select>
          </td>
          <td><input form="<?= $fid ?>" type="number" name="gta_interior_id" min="0" value="<?= (int)$b['gta_interior_id'] ?>" style="width:80px"></td>
          <td><input form="<?= $fid ?>" type="number" name="vw_id" min="0" value="<?= (int)$b['vw_id'] ?>" style="width:70px"></td>
          <td><input form="<?= $fid ?>" type="number" name="stock_max" min="0" value="<?= (int)$b['stock_max'] ?>" style="width:80px"></td>
          <td><input form="<?= $fid ?>" type="number" name="stock_curr" min="0" value="<?= (int)$b['stock_curr'] ?>" style="width:80px"></td>
          <td class="chk"><input form="<?= $fid ?>" type="checkbox" name="terrace" <?= !empty($b['terrace']) ? 'checked' : '' ?>></td>
          <td><?= number_format((float)$b['loc_x'], 2) ?></td>
          <td><?= number_format((float)$b['loc_y'], 2) ?></td>
          <td><?= number_format((float)$b['loc_z'], 2) ?></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <?= ucp_csrf_field() ?>
              <input type="hidden" name="id" value="<?= (int)$b['id'] ?>">
              <button type="submit" class="save-btn">Save</button>
            </form>
          </td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
  <?php endif; ?>
</main>

<?php include __DIR__ . '/../../includes/footer.php'; ?>

</body>
</html>
