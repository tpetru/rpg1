<?php
require_once __DIR__ . '/../includes/admin_common.php';
ucp_admin_require_level5();

$shops = $mysqli->query("SELECT * FROM `shops` ORDER BY `shopID` ASC")->fetch_all(MYSQLI_ASSOC);
$adminActive = 'shops';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Shops</title>
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>🛒 Shops</h1>
  <p style="color:var(--muted)">Shops only store a location (no name/price/owner in the database) — read-only.</p>

  <?php include __DIR__ . '/../includes/admin_nav.php'; ?>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>X</th><th>Y</th><th>Z</th></tr>
      <?php foreach ($shops as $s): ?>
      <tr>
        <td>#<?= (int)$s['shopID'] ?></td>
        <td><?= number_format((float)$s['shopLocX'], 2) ?></td>
        <td><?= number_format((float)$s['shopLocY'], 2) ?></td>
        <td><?= number_format((float)$s['shopLocZ'], 2) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
