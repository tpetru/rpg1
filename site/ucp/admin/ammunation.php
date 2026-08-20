<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !ucp_csrf_verify()) {
    $flash = "Security check failed (invalid or expired form). Please try again.";
    $flashErr = true;
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['amoID'] ?? 0);
    if ($id > 0) {
        $name    = trim($_POST['amoName'] ?? '');
        $intId   = max(0, (int)($_POST['amoInteriorId'] ?? 0));
        $vwId    = max(0, (int)($_POST['amoVwId'] ?? 0));
        $intX    = (float)($_POST['amoInteriorX'] ?? 0);
        $intY    = (float)($_POST['amoInteriorY'] ?? 0);
        $intZ    = (float)($_POST['amoInteriorZ'] ?? 0);

        $stmt = $mysqli->prepare("UPDATE `ammunations` SET `amoName`=?, `amoInteriorId`=?, `amoVwId`=?, `amoInteriorX`=?, `amoInteriorY`=?, `amoInteriorZ`=? WHERE `amoID`=?");
        $stmt->bind_param('siidddi', $name, $intId, $vwId, $intX, $intY, $intZ, $id);
        $stmt->execute();
        $stmt->close();
        $flash = "AmmuNation #$id updated.";
    }
}

try {
    $shops = $mysqli->query("SELECT * FROM `ammunations` ORDER BY `amoID` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $shops = null; // table doesn't exist yet - the gamemode creates it on startup
}

$adminActive = 'ammunation';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — AmmuNation</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>
<?php include __DIR__ . '/../../includes/admin_section_nav.php'; ?>

<main>
  <h1>🔫 AmmuNation</h1>
  <p style="color:var(--muted)">Edit AmmuNation shops directly. Changes are saved immediately to the database. Creating/repositioning shops is still done in-game with <code>/ammoc</code> (admin level 5+). Interior ID here is the raw SA-MP interior number (not a catalog ID). Leaving the interior fields all at 0 means the shop has no interior (buy weapons from the exterior pickup only). Changes only take effect in-game after a server restart.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <?php if ($shops === null): ?>
  <div class="card">
    <p style="color:var(--muted)">The <code>ammunations</code> table doesn't exist yet. It's created automatically by the gamemode on startup - run the server once, then reload this page.</p>
  </div>
  <?php else: ?>
  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr>
        <th>ID</th><th>Name</th><th>Interior ID (raw)</th><th>VW</th>
        <th>Int X</th><th>Int Y</th><th>Int Z</th><th></th>
      </tr>
      <?php foreach ($shops as $a): $fid = 'amo-' . (int)$a['amoID']; ?>
      <tr>
          <td>#<?= (int)$a['amoID'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="amoName" maxlength="32" value="<?= ucp_escape($a['amoName']) ?>" style="width:140px"></td>
          <td><input form="<?= $fid ?>" type="number" name="amoInteriorId" min="0" value="<?= (int)$a['amoInteriorId'] ?>" style="width:80px"></td>
          <td><input form="<?= $fid ?>" type="number" name="amoVwId" min="0" value="<?= (int)$a['amoVwId'] ?>" style="width:70px"></td>
          <td><input form="<?= $fid ?>" type="number" step="0.0001" name="amoInteriorX" value="<?= (float)$a['amoInteriorX'] ?>" style="width:90px"></td>
          <td><input form="<?= $fid ?>" type="number" step="0.0001" name="amoInteriorY" value="<?= (float)$a['amoInteriorY'] ?>" style="width:90px"></td>
          <td><input form="<?= $fid ?>" type="number" step="0.0001" name="amoInteriorZ" value="<?= (float)$a['amoInteriorZ'] ?>" style="width:90px"></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <?= ucp_csrf_field() ?>
              <input type="hidden" name="amoID" value="<?= (int)$a['amoID'] ?>">
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
