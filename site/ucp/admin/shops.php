<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$sectionNav = [
  ['shops', '🛒', 'Shops'],
  ['fastfood', '🍔', 'Fast-food'],
  ['prices', '💲', 'Prices'],
  ['player', '🧍', 'Player'],
];

$shopTypeName = [
  1 => '24/7 Shop',
  2 => 'Electronics Shop',
  3 => 'Tools Shop'
];

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
  $shopID = (int)($_POST['shopID'] ?? 0);
  $shopName = trim($_POST['shopName'] ?? '');
  $shopType = (int)($_POST['shopType'] ?? 0);

  if ($shopID > 0 && $shopName && isset($shopTypeName[$shopType])) {
    $stmt = $mysqli->prepare("UPDATE `shops` SET `shopName` = ?, `shopType` = ? WHERE `shopID` = ?");
    $stmt->bind_param('sii', $shopName, $shopType, $shopID);
    if ($stmt->execute()) {
      $flash = "Shop #$shopID updated successfully";
    } else {
      $flash = "Error updating shop";
      $flashErr = true;
    }
  } else {
    $flash = "Invalid input";
    $flashErr = true;
  }
}

$shops = $mysqli->query("SELECT * FROM `shops` ORDER BY `shopID` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'shops';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Shops</title>
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
  <h1>🛒 Shops</h1>
  <p style="color:var(--muted)">Edit shop names and types.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>">
      <?= htmlspecialchars($flash) ?>
    </div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr><th>ID</th><th>Name</th><th>Type</th><th>X</th><th>Y</th><th>Z</th><th></th></tr>
      <?php foreach ($shops as $s): $sid = 'shop-' . (int)$s['shopID']; ?>
      <tr>
        <td>#<?= (int)$s['shopID'] ?></td>
        <td><input form="<?= $sid ?>" type="text" name="shopName" value="<?= htmlspecialchars($s['shopName'] ?? '') ?>" required></td>
        <td>
          <select form="<?= $sid ?>" name="shopType" required>
            <?php foreach ($shopTypeName as $tid => $tname): ?>
              <option value="<?= $tid ?>" <?= ((int)$s['shopType'] === $tid) ? 'selected' : '' ?>><?= htmlspecialchars($tname) ?></option>
            <?php endforeach; ?>
          </select>
        </td>
        <td><?= number_format((float)$s['shopLocX'], 2) ?></td>
        <td><?= number_format((float)$s['shopLocY'], 2) ?></td>
        <td><?= number_format((float)$s['shopLocZ'], 2) ?></td>
        <td>
          <form id="<?= $sid ?>" method="POST">
            <input type="hidden" name="shopID" value="<?= (int)$s['shopID'] ?>">
            <button type="submit" class="save-btn">Save</button>
          </form>
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
