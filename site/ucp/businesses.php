<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

$businesses = $mysqli->query("SELECT `id`,`name`,`owner`,`owned`,`price`,`is_for_sale` FROM `businesses` ORDER BY `id` ASC")->fetch_all(MYSQLI_ASSOC);
$listingsActive = 'businesses';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Businesses</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>
<?php include __DIR__ . '/includes/listings_nav.php'; ?>

<main>
  <h1>🏢 Businesses</h1>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Name</th><th>Owner</th><th>Price</th><th>For sale</th></tr>
      <?php foreach ($businesses as $b): ?>
      <tr>
        <td>#<?= (int)$b['id'] ?></td>
        <td><?= ucp_escape($b['name']) ?></td>
        <td><?= $b['owned'] ? ucp_escape($b['owner']) : '—' ?></td>
        <td>$<?= ucp_money($b['price']) ?></td>
        <td><?= $b['is_for_sale'] ? '<span class="pill pill-ok">Yes</span>' : '<span class="pill pill-bad">No</span>' ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
