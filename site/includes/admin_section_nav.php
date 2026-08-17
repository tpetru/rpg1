<?php
// Floating right-side icon strip linking every admin editor page (2 columns).
// The including page may set $adminActive (same keys as includes/admin_nav.php) to highlight the current page.
$adminSectionPages = [
    'houses'      => ['🏠', 'Houses', 'houses.php'],
    'businesses'  => ['🏢', 'Businesses', 'businesses.php'],
    'vehicles'    => ['🚗', 'Vehicles', 'vehicles.php'],
    'farms'       => ['🌾', 'Farms', 'farms.php'],
    'forests'     => ['🌲', 'Forests', 'forests.php'],
    'hotels'      => ['🏨', 'Hotels', 'hotels.php'],
    'billboards'  => ['📢', 'Billboards', 'billboards.php'],
    'shops'       => ['🛒', 'Shops', 'shops.php'],
    'fastfood'    => ['🍔', 'Fast-food', 'fastfood.php'],
    'bars'        => ['🍺', 'Bars', 'bars.php'],
    'clothstores' => ['👕', 'Clothing Stores', 'clothstores.php'],
    'ammunation'  => ['🔫', 'AmmuNation', 'ammunation.php'],
    'prices'      => ['💲', 'Prices', 'prices.php'],
    'player'      => ['🧍', 'Player', 'player.php'],
];
?>
<nav class="section-nav admin-section-nav" aria-label="Jump to admin page">
  <?php foreach ($adminSectionPages as $key => [$icon, $label, $href]): ?>
  <a href="<?= $href ?>" title="<?= htmlspecialchars($label) ?>" class="<?= $key === ($adminActive ?? '') ? 'active' : '' ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>
