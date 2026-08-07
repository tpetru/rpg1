<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$sectionNav = [
  ['farms', '🌾', 'Farms'],
  ['forests', '🌲', 'Forests'],
  ['prices', '💲', 'Prices'],
  ['player', '🧍', 'Player'],
];

$flash = null;
$flashErr = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
  $fstID = (int)($_POST['fstID'] ?? 0);
  $fstOwnerId = (int)($_POST['fstOwnerId'] ?? 0);
  $fstOwnerName = trim($_POST['fstOwnerName'] ?? '');
  $fstForSale = isset($_POST['fstForSale']) ? 1 : 0;
  $fstDefaultPrice = (int)($_POST['fstDefaultPrice'] ?? 0);
  $fstPrice = (int)($_POST['fstPrice'] ?? 0);
  $fstSize = (float)($_POST['fstSize'] ?? 0);
  $fstMaxTree = (int)($_POST['fstMaxTree'] ?? 0);
  $fstCurrentTree = (int)($_POST['fstCurrentTree'] ?? 0);
  $fstSaplings = (int)($_POST['fstSaplings'] ?? 0);
  $fstPlantedSaplings = (int)($_POST['fstPlantedSaplings'] ?? 0);

  if ($fstID > 0 && $fstSize > 0) {
    $stmt = $mysqli->prepare("UPDATE `forests` SET
      `owner` = ?, `ownerId` = ?, `isForSale` = ?,
      `defaultPrice` = ?, `price` = ?, `size` = ?,
      `maxTree` = ?, `currentTree` = ?, `saplings` = ?, `plantedSaplings` = ?
      WHERE `id` = ?");
    $stmt->bind_param('iiiiidiiiii', $fstOwnerId, $fstOwnerId, $fstForSale, $fstDefaultPrice, $fstPrice, $fstSize, $fstMaxTree, $fstCurrentTree, $fstSaplings, $fstPlantedSaplings, $fstID);
    if ($stmt->execute()) {
      $flash = "Forest #$fstID updated successfully";
    } else {
      $flash = "Error updating forest: " . $stmt->error;
      $flashErr = true;
    }
  } else {
    $flash = "Invalid input (ID and Size required)";
    $flashErr = true;
  }
}

$forests = $mysqli->query("SELECT * FROM `forests` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'forests';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Forests</title>
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
  <h1>🌲 Forests</h1>
  <p style="color:var(--muted)">Edit forest properties, ownership, and resources.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>">
      <?= htmlspecialchars($flash) ?>
    </div>
  <?php endif; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table class="edittable">
      <tr>
        <th>ID</th>
        <th>Owner ID</th>
        <th>Owner Name</th>
        <th>For Sale</th>
        <th>Default Price</th>
        <th>Current Price</th>
        <th>Size</th>
        <th>Max Trees</th>
        <th>Current Trees</th>
        <th>Saplings</th>
        <th>Planted Saplings</th>
        <th></th>
      </tr>
      <?php foreach ($forests as $f): ?>
      <form method="POST" style="display:contents;">
      <tr>
        <td>#<?= (int)$f['id'] ?></td>
        <td><input type="number" name="fstOwnerId" value="<?= (int)$f['ownerId'] ?>" min="0"></td>
        <td><input type="text" name="fstOwnerName" value="<?= htmlspecialchars($f['owner'] ?? '') ?>" maxlength="24"></td>
        <td><input type="checkbox" name="fstForSale" <?= (int)$f['isForSale'] ? 'checked' : '' ?> class="chk"></td>
        <td><input type="number" name="fstDefaultPrice" value="<?= (int)$f['defaultPrice'] ?>" min="0"></td>
        <td><input type="number" name="fstPrice" value="<?= (int)$f['price'] ?>" min="0"></td>
        <td><input type="number" name="fstSize" value="<?= number_format((float)$f['size'], 2) ?>" step="0.01" min="0.01" required></td>
        <td><input type="number" name="fstMaxTree" value="<?= (int)$f['maxTree'] ?>" min="0"></td>
        <td><input type="number" name="fstCurrentTree" value="<?= (int)$f['currentTree'] ?>" min="0"></td>
        <td><input type="number" name="fstSaplings" value="<?= (int)$f['saplings'] ?>" min="0"></td>
        <td><input type="number" name="fstPlantedSaplings" value="<?= (int)$f['plantedSaplings'] ?>" min="0"></td>
        <td>
          <input type="hidden" name="fstID" value="<?= (int)$f['id'] ?>">
          <button type="submit" class="save-btn">💾</button>
        </td>
      </tr>
      </form>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
