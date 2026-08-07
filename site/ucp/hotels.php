<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
ucp_require_login();

$hotels = $mysqli->query("SELECT `id`,`name`,`owner`,`owned`,`price`,`is_for_sale`,`capacity` FROM `hotels` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$listingsActive = 'hotels';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Hotels</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/listings_nav.php'; ?>

<main>
  <h1>🏨 Hotels</h1>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Name</th><th>Owner</th><th>Price</th><th>For sale</th><th>Capacity</th></tr>
      <?php foreach ($hotels as $h): ?>
      <tr>
        <td>#<?= (int)$h['id'] ?></td>
        <td><?= ucp_escape($h['name']) ?></td>
        <td><?= $h['owned'] ? ucp_escape($h['owner']) : '—' ?></td>
        <td>$<?= ucp_money($h['price']) ?></td>
        <td><?= $h['is_for_sale'] ? '<span class="pill pill-ok">Yes</span>' : '<span class="pill pill-bad">No</span>' ?></td>
        <td><?= (int)$h['capacity'] ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
