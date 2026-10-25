<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

$houseTypeName = [1 => t('Villa'), 2 => t('City House'), 3 => t('Apartment'), 4 => t('Countryside House')];

$houses = $mysqli->query("SELECT `id`,`name`,`type`,`owner`,`owned`,`price`,`is_for_sale` FROM `houses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$listingsActive = 'houses';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Houses</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🏠 <?= t('Houses') ?></h1>
  <p style="color:var(--muted)"><?= t('Buyable properties — one per player, complete with beds, fridges and yards for pets. Also marked live on the') ?> <a href="maps.php"><?= t('map') ?></a>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th><?= t('ID') ?></th><th><?= t('Name') ?></th><th><?= t('Type') ?></th><th><?= t('Owner') ?></th><th><?= t('Price') ?></th><th><?= t('For sale') ?></th></tr>
      <?php foreach ($houses as $h): ?>
      <tr>
        <td>#<?= (int)$h['id'] ?></td>
        <td><?= ucp_escape($h['name']) ?></td>
        <td><?= ucp_escape($houseTypeName[(int)$h['type']] ?? t('Unknown')) ?></td>
        <td><?= $h['owned'] ? ucp_escape($h['owner']) : '—' ?></td>
        <td>$<?= ucp_money($h['price']) ?></td>
        <td><?= $h['is_for_sale'] ? ('<span class="pill pill-ok">' . t('Yes') . '</span>') : ('<span class="pill pill-bad">' . t('No') . '</span>') ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
