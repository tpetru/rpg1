<?php
require_once __DIR__ . '/../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $id = (int)($_POST['id'] ?? 0);
    if ($id > 0) {
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
}

$businesses = $mysqli->query("SELECT * FROM `businesses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'businesses';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Businesses</title>
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>🏢 Businesses</h1>
  <p style="color:var(--muted)">Edit businesses directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr><th>ID</th><th>Name</th><th>Price</th><th>Bank</th><th class="chk">For sale</th><th class="chk">ANAF locked</th><th>Owner (player ID / none)</th><th></th></tr>
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
            <form id="<?= $fid ?>" method="post"></form>
            <input form="<?= $fid ?>" type="hidden" name="id" value="<?= (int)$b['id'] ?>">
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
