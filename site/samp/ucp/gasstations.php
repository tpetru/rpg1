<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

$gasStations = $mysqli->query("SELECT `id`,`name`,`locX`,`locY`,`locZ` FROM `fuelstations` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

$listingsActive = 'gasstations';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Gas Stations</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>⛽ <?= t('Fuel Stations') ?></h1>
  <p style="color:var(--muted)"><?= t('Fixed refuel points around the map — not ownable, just drive up and fill your tank. Also marked live on the') ?> <a href="maps.php"><?= t('map') ?></a>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th><?= t('ID') ?></th><th><?= t('Name') ?></th><th><?= t('Location (X, Y, Z)') ?></th></tr>
      <?php foreach ($gasStations as $g): ?>
      <tr>
        <td>#<?= (int)$g['id'] ?></td>
        <td><?= ucp_escape($g['name']) ?></td>
        <td><?= number_format((float)$g['locX'], 1) ?>, <?= number_format((float)$g['locY'], 1) ?>, <?= number_format((float)$g['locZ'], 1) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
