<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !ucp_csrf_verify()) {
    $flash = "Security check failed (invalid or expired form). Please try again.";
    $flashErr = true;
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
        $name   = trim($_POST['name'] ?? '');
        $intId  = max(0, (int)($_POST['intId'] ?? 0));
        $vwId   = max(0, (int)($_POST['vwId'] ?? 0));

        if ($name === '') {
            $flash = "Name cannot be empty.";
            $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `clothstores` SET `name`=?, `intId`=?, `vwId`=? WHERE `id`=?");
            $stmt->bind_param('siii', $name, $intId, $vwId, $id);
            $stmt->execute();
            $stmt->close();
            $flash = "Clothing store #$id updated.";
        }
    }
}

try {
    $stores = $mysqli->query("SELECT * FROM `clothstores` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $stores = null; // table doesn't exist yet - the gamemode creates it on startup
}

$adminActive = 'clothstores';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Clothing Stores</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>
<?php include __DIR__ . '/../../includes/admin_section_nav.php'; ?>

<main>
  <h1>👕 Clothing Stores</h1>
  <p style="color:var(--muted)">Edit clothing stores directly. Changes are saved immediately to the database. Creating/repositioning stores is still done in-game with <code>/clsc</code> (admin level 5+). <code>intId</code> is a <code>gta_interiors</code> catalog ID, not a raw interior number - changes here only take effect in-game after a server restart.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <?php if ($stores === null): ?>
  <div class="card">
    <p style="color:var(--muted)">The <code>clothstores</code> table doesn't exist yet. It's created automatically by the gamemode on startup - run the server once, then reload this page.</p>
  </div>
  <?php else: ?>
  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr>
        <th>ID</th><th>Name</th><th>Interior ID (gta_interiors)</th><th>VW</th><th>X</th><th>Y</th><th>Z</th><th></th>
      </tr>
      <?php foreach ($stores as $s): $fid = 'clst-' . (int)$s['id']; ?>
      <tr>
          <td>#<?= (int)$s['id'] ?></td>
          <td><input form="<?= $fid ?>" type="text" name="name" maxlength="32" value="<?= ucp_escape($s['name']) ?>" style="width:140px"></td>
          <td><input form="<?= $fid ?>" type="number" name="intId" min="0" value="<?= (int)$s['intId'] ?>" style="width:80px"></td>
          <td><input form="<?= $fid ?>" type="number" name="vwId" min="0" value="<?= (int)$s['vwId'] ?>" style="width:70px"></td>
          <td><?= number_format((float)$s['locX'], 2) ?></td>
          <td><?= number_format((float)$s['locY'], 2) ?></td>
          <td><?= number_format((float)$s['locZ'], 2) ?></td>
          <td>
            <form id="<?= $fid ?>" method="post">
              <?= ucp_csrf_field() ?>
              <input type="hidden" name="id" value="<?= (int)$s['id'] ?>">
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
