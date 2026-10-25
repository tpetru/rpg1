<?php
// Sub-navigation between the admin editor pages. The including page must set
// $adminActive to one of: houses, businesses, vehicles, farms, hotels, billboards, shops, fastfood, forests, bars, clothstores, ammunation
$adminPages = [
    'houses'      => ['🏠 Houses', 'houses.php'],
    'businesses'  => ['🏢 Businesses', 'businesses.php'],
    'vehicles'    => ['🚗 Vehicles', 'vehicles.php'],
    'farms'       => ['🌾 Farms', 'farms.php'],
    'hotels'      => ['🏨 Hotels', 'hotels.php'],
    'billboards'  => ['📢 Billboards', 'billboards.php'],
    'shops'       => ['🛒 Shops', 'shops.php'],
    'fastfood'    => ['🍔 Fast-food', 'fastfood.php'],
    'forests'     => ['🌲 Forests', 'forests.php'],
    'bars'        => ['🍺 Bars', 'bars.php'],
    'clothstores' => ['👕 Clothing Stores', 'clothstores.php'],
    'ammunation'  => ['🔫 AmmuNation', 'ammunation.php'],
    'prices'      => ['💲 Prices', 'prices.php'],
    'player'      => ['🧍 Player', 'player.php'],
];
?>
<nav class="subtabs">
  <?php foreach ($adminPages as $key => [$label, $href]): ?>
    <a href="<?= $href ?>" class="<?= $key === $adminActive ? 'active' : '' ?>"><?= $label ?></a>
  <?php endforeach; ?>
</nav>
