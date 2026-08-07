<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
ucp_require_login();

$farms = $mysqli->query("SELECT `id`,`name`,`owner`,`isOwned`,`price`,`is_for_sale`,`tractors`,`combines`,`dozers`,`trucks`,`trailers` FROM `farms` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);

// Individual equipment (see farm_equipment in bare.pwn); falls back to the legacy tractors/combines/... counts on `farms` if the table doesn't exist yet
$farmEquipModels = [531 => 'tractors', 486 => 'dozers', 532 => 'combines', 403 => 'trucks', 450 => 'trailers'];
$farmEquipCounts = null;
try {
    $rows = $mysqli->query("SELECT `farm_id`,`model`,COUNT(*) AS `cnt` FROM `farm_equipment` GROUP BY `farm_id`,`model`")->fetch_all(MYSQLI_ASSOC);
    $farmEquipCounts = [];
    foreach ($rows as $r) {
        $col = $farmEquipModels[(int)$r['model']] ?? null;
        if ($col) { $farmEquipCounts[(int)$r['farm_id']][$col] = (int)$r['cnt']; }
    }
} catch (mysqli_sql_exception $e) {
    $farmEquipCounts = null; // table doesn't exist yet
}

$listingsActive = 'farms';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Farms</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🌾 Farms</h1>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Name</th><th>Owner</th><th>Price</th><th>For sale</th><th>Tractors</th><th>Combines</th><th>Dozers</th><th>Trucks</th><th>Trailers</th></tr>
      <?php foreach ($farms as $f):
          $eq = $farmEquipCounts[(int)$f['id']] ?? null;
          $tractors = $eq['tractors'] ?? (int)$f['tractors'];
          $combines = $eq['combines'] ?? (int)$f['combines'];
          $dozers   = $eq['dozers']   ?? (int)$f['dozers'];
          $trucks   = $eq['trucks']   ?? (int)$f['trucks'];
          $trailers = $eq['trailers'] ?? (int)$f['trailers'];
      ?>
      <tr>
        <td>#<?= (int)$f['id'] ?></td>
        <td><?= ucp_escape($f['name']) ?></td>
        <td><?= $f['isOwned'] ? ucp_escape($f['owner']) : '—' ?></td>
        <td>$<?= ucp_money($f['price']) ?></td>
        <td><?= $f['is_for_sale'] ? '<span class="pill pill-ok">Yes</span>' : '<span class="pill pill-bad">No</span>' ?></td>
        <td><?= (int)$tractors ?></td>
        <td><?= (int)$combines ?></td>
        <td><?= (int)$dozers ?></td>
        <td><?= (int)$trucks ?></td>
        <td><?= (int)$trailers ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
