<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
ucp_require_login();

$vehicles = $mysqli->query("SELECT `id`,`model_id`,`owner_id`,`price`,`is_for_sale` FROM `vehicles_personal` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

// Resolve owner usernames in bulk (avoids one query per row)
$ownerIds = array_unique(array_filter(array_map(fn($v) => (int)$v['owner_id'], $vehicles)));
$ownerNames = [];
if ($ownerIds) {
    $rows = $mysqli->query("SELECT `id`,`username` FROM `players` WHERE `id` IN (" . implode(',', $ownerIds) . ")")->fetch_all(MYSQLI_ASSOC);
    foreach ($rows as $r) { $ownerNames[(int)$r['id']] = $r['username']; }
}

$listingsActive = 'vehicles';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Vehicles</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🚗 Vehicles</h1>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Name</th><th>Owner</th><th>Price</th><th>For sale</th></tr>
      <?php foreach ($vehicles as $v): $ownerId = (int)$v['owner_id']; ?>
      <tr>
        <td>#<?= (int)$v['id'] ?></td>
        <td><?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?></td>
        <td><?= $ownerId > 0 ? ucp_escape($ownerNames[$ownerId] ?? '#' . $ownerId) : '—' ?></td>
        <td>$<?= ucp_money($v['price']) ?></td>
        <td><?= $v['is_for_sale'] ? '<span class="pill pill-ok">Yes</span>' : '<span class="pill pill-bad">No</span>' ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
