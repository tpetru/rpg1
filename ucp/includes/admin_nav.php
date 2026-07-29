<?php
// Sub-navigation between the admin editor pages. The including page must set
// $adminActive to one of: houses, businesses, vehicles, farms, hotels, shops, fastfood
$adminPages = [
    'houses'     => ['🏠 Houses', 'houses.php'],
    'businesses' => ['🏢 Businesses', 'businesses.php'],
    'vehicles'   => ['🚗 Vehicles', 'vehicles.php'],
    'farms'      => ['🌾 Farms', 'farms.php'],
    'hotels'     => ['🏨 Hotels', 'hotels.php'],
    'shops'      => ['🛒 Shops', 'shops.php'],
    'fastfood'   => ['🍔 Fast-food', 'fastfood.php'],
    'prices'     => ['💲 Prices', 'prices.php'],
    'player'     => ['🧍 Player', 'player.php'],
];
?>
<nav class="subtabs">
  <?php foreach ($adminPages as $key => [$label, $href]): ?>
    <a href="<?= $href ?>" class="<?= $key === $adminActive ? 'active' : '' ?>"><?= $label ?></a>
  <?php endforeach; ?>
</nav>
