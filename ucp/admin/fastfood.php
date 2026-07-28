<?php
require_once __DIR__ . '/../includes/admin_common.php';
ucp_admin_require_level5();

$ffTypeName = [1 => 'Pizza', 2 => 'Burger', 3 => 'Cluckin Bell', 4 => 'Desert'];

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
        $name = trim($_POST['name'] ?? '');
        $type = max(1, min(4, (int)($_POST['type'] ?? 1))); // 1=Pizza 2=Burger 3=Cluckin Bell 4=Desert
        $stmt = $mysqli->prepare("UPDATE `fastfood` SET `ffName`=?, `ffType`=? WHERE `ffID`=?");
        $stmt->bind_param('sii', $name, $type, $id);
        $stmt->execute();
        $stmt->close();
        $flash = "Fast-food #$id updated.";
    }
}

$fastfood = $mysqli->query("SELECT * FROM `fastfood` ORDER BY `ffID` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'fastfood';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Fast-food</title>
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>🍔 Fast-food</h1>
  <p style="color:var(--muted)">Edit fast-food locations directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
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
            <form id="<?= $fid ?>" method="post"></form>
            <input form="<?= $fid ?>" type="hidden" name="id" value="<?= (int)$f['ffID'] ?>">
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
