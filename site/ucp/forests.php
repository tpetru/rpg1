<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
ucp_require_login();

$forests = $mysqli->query("SELECT `id`,`owner`,`ownerId`,`price`,`size`,`isForSale`,`maxTree`,`currentTree`,`saplings`,`plantedSaplings`,`bank` FROM `forests` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

$listingsActive = 'forests';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Forests</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🌲 Forests</h1>
  <p style="color:var(--muted)">Buyable properties — lumberjacks harvest their trees, owners profit from the traffic. Also marked live on the <a href="maps.php">map</a>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Owner</th><th>Price</th><th>Size</th><th>For sale</th><th>Trees</th><th>Saplings (storage)</th><th>Saplings (planted)</th><th>Bank</th></tr>
      <?php foreach ($forests as $f): ?>
      <tr>
        <td>#<?= (int)$f['id'] ?></td>
        <td><?= (int)$f['ownerId'] > 0 ? ucp_escape($f['owner']) : '—' ?></td>
        <td>$<?= ucp_money($f['price']) ?></td>
        <td><?= number_format((float)$f['size'], 2) ?> units</td>
        <td><?= $f['isForSale'] ? '<span class="pill pill-ok">Yes</span>' : '<span class="pill pill-bad">No</span>' ?></td>
        <td><?= (int)$f['currentTree'] ?> / <?= (int)$f['maxTree'] ?></td>
        <td><?= (int)$f['saplings'] ?></td>
        <td><?= (int)$f['plantedSaplings'] ?></td>
        <td>$<?= ucp_money($f['bank']) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
