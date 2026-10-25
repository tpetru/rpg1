<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

// `billboards` is created by the gamemode on startup (CREATE TABLE IF NOT EXISTS) - may not exist yet if it hasn't run since this feature was added
try {
    $billboards = $mysqli->query("SELECT `bbID`,`bbOwner`,`bbOwnerId`,`bbIsForSale`,`bbPrice`,`bbBank`,`bbRented`,`bbRentLeft`,`bbRentPrice24H`,`bbClean`,`bbText` FROM `billboards` ORDER BY `bbID` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $billboards = [];
}
$listingsActive = 'billboards';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Billboards</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>📢 <?= t('Billboards') ?></h1>
  <p style="color:var(--muted)"><?= t('Rentable ad space around the city, showing custom text to passersby. Also marked live on the') ?> <a href="maps.php"><?= t('map') ?></a>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th><?= t('ID') ?></th><th><?= t('Owner') ?></th><th><?= t('For sale') ?></th><th><?= t('Rented') ?></th><th><?= t('Status') ?></th><th><?= t('24h rent price') ?></th><th><?= t('Bank') ?></th><th><?= t('Text') ?></th></tr>
      <?php foreach ($billboards as $bb):
          [$cleanLabel, $cleanTier] = ucp_bb_clean_label($bb['bbClean']);
      ?>
      <tr>
        <td>#<?= (int)$bb['bbID'] ?></td>
        <td><?= (int)$bb['bbOwnerId'] > 0 ? ucp_escape($bb['bbOwner']) : '—' ?></td>
        <td><?= $bb['bbIsForSale'] ? ('<span class="pill pill-ok">' . t('Yes') . ' — $' . ucp_money($bb['bbPrice']) . '</span>') : ('<span class="pill pill-bad">' . t('No') . '</span>') ?></td>
        <td><?= $bb['bbRented'] ? ('<span class="pill pill-ok">' . t('Yes') . ' — ' . ((int)$bb['bbRentLeft'] * 24) . 'h ' . t('left') . '</span>') : ('<span class="pill pill-bad">' . t('No') . '</span>') ?></td>
        <td><span class="pill pill-<?= $cleanTier ?>"><?= t($cleanLabel) ?></span></td>
        <td>$<?= ucp_money($bb['bbRentPrice24H']) ?></td>
        <td>$<?= ucp_money($bb['bbBank']) ?></td>
        <td><?= $bb['bbRented'] ? ucp_escape($bb['bbText']) : '<span style="color:var(--muted)">—</span>' ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
