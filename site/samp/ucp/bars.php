<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

$barTypeNames = [1 => t('Pub'), 2 => t('Dance'), 3 => t('Cafe')];

try {
    $bars = $mysqli->query("SELECT `id`,`name`,`type`,`stock_max`,`stock_curr`,`terrace` FROM `bars` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
} catch (mysqli_sql_exception $e) {
    $bars = [];
}
$listingsActive = 'bars';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Bars</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🍺 <?= t('Bars') ?></h1>
  <p style="color:var(--muted)"><?= t('Fixed drink-serving spots around the city, stocked and refilled from their own inventory.') ?></p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th><?= t('ID') ?></th><th><?= t('Name') ?></th><th><?= t('Type') ?></th><th><?= t('Terrace') ?></th><th><?= t('Stock') ?></th></tr>
      <?php foreach ($bars as $bar):
          $stockPct = $bar['stock_max'] > 0 ? (int)round(100 * $bar['stock_curr'] / $bar['stock_max']) : 0;
          $stockTier = $stockPct <= 20 ? 'bad' : ($stockPct <= 50 ? 'warn' : 'ok');
      ?>
      <tr>
        <td>#<?= (int)$bar['id'] ?></td>
        <td><?= ucp_escape($bar['name']) ?></td>
        <td><?= ucp_escape($barTypeNames[(int)$bar['type']] ?? t('Pub')) ?></td>
        <td><?= !empty($bar['terrace']) ? '✅' : '—' ?></td>
        <td><span class="pill pill-<?= $stockTier ?>"><?= (int)$bar['stock_curr'] ?> / <?= (int)$bar['stock_max'] ?></span></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
