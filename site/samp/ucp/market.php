<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();

// `km` was added to vehicles_personal via a later migration (gamemode's OnGameModeInit); guard
// against it not existing yet on a DB that hasn't been through that migration.
$hasKm = $mysqli->query("SHOW COLUMNS FROM `vehicles_personal` LIKE 'km'")->num_rows > 0;
$kmSelect = $hasKm ? '`km`' : 'NULL AS `km`';
$vehicles = $mysqli->query("SELECT `id`,`model_id`,`owner_id`,`price`,$kmSelect FROM `vehicles_personal` WHERE `is_for_sale`=1 ORDER BY `price` ASC")->fetch_all(MYSQLI_ASSOC);

// Resolve owner usernames in bulk (avoids one query per row)
$ownerIds = array_unique(array_filter(array_map(fn($v) => (int)$v['owner_id'], $vehicles)));
$ownerNames = [];
if ($ownerIds) {
    $rows = $mysqli->query("SELECT `id`,`username` FROM `players` WHERE `id` IN (" . implode(',', $ownerIds) . ")")->fetch_all(MYSQLI_ASSOC);
    foreach ($rows as $r) { $ownerNames[(int)$r['id']] = $r['username']; }
}

$listingsActive = 'market';
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Vehicle Market</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🛒 <?= t('Vehicle Market') ?></h1>
  <p style="color:var(--muted)"><?= t('Personal vehicles currently listed for sale by their owners. Enter one and use') ?> <code>/vbuy</code> <?= t('to purchase it.') ?></p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th></th><th><?= t('ID') ?></th><th><?= t('Name') ?></th><th><?= t('Price') ?></th><th><?= t('Owner') ?></th><th><?= t('Odometer') ?></th></tr>
      <?php if (!$vehicles): ?>
      <tr><td colspan="6" style="text-align:center;color:var(--muted)"><?= t('No vehicles are currently for sale.') ?></td></tr>
      <?php endif; ?>
      <?php foreach ($vehicles as $v): $ownerId = (int)$v['owner_id']; ?>
      <tr>
        <td><div class="vehicle-thumb"><img src="<?= ucp_escape(ucp_vehicle_image($v['model_id'])) ?>" alt="" loading="lazy"></div></td>
        <td>#<?= (int)$v['id'] ?></td>
        <td><?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?></td>
        <td>$<?= ucp_money($v['price']) ?></td>
        <td><?= $ownerId > 0 ? ucp_escape($ownerNames[$ownerId] ?? '#' . $ownerId) : '—' ?></td>
        <td><?= $v['km'] !== null ? number_format((float)$v['km'], 1, '.', '.') . ' km' : '—' ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
