<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

$businesses = $mysqli->query("SELECT `id`,`name`,`owner`,`owned`,`price`,`is_for_sale`,`coffee_maker` FROM `businesses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$listingsActive = 'businesses';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Businesses</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🏢 <?= t('Businesses') ?></h1>
  <p style="color:var(--muted)"><?= t('Buyable properties that earn passive income from nearby player activity. Also marked live on the') ?> <a href="maps.php"><?= t('map') ?></a>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th><?= t('ID') ?></th><th><?= t('Name') ?></th><th><?= t('Owner') ?></th><th><?= t('Price') ?></th><th><?= t('For sale') ?></th><th><?= t('Has coffee') ?></th></tr>
      <?php foreach ($businesses as $b): ?>
      <tr>
        <td>#<?= (int)$b['id'] ?></td>
        <td><?= ucp_escape($b['name']) ?></td>
        <td><?= $b['owned'] ? ucp_escape($b['owner']) : '—' ?></td>
        <td>$<?= ucp_money($b['price']) ?></td>
        <td><?= $b['is_for_sale'] ? ('<span class="pill pill-ok">' . t('Yes') . '</span>') : ('<span class="pill pill-bad">' . t('No') . '</span>') ?></td>
        <td><?= $b['coffee_maker'] ? '☕' : '—' ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
