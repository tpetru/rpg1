<?php
// Floating right-side quick nav between the property listing pages.
// The including page must set $listingsActive to one of: houses, hotels, businesses, farms, forests, vehicles, billboards, bars, gasstations
$listingsPages = [
    'houses'      => ['🏠', 'Houses', 'houses.php'],
    'hotels'      => ['🏨', 'Hotels', 'hotels.php'],
    'businesses'  => ['🏢', 'Businesses', 'businesses.php'],
    'farms'       => ['🌾', 'Farms', 'farms.php'],
    'forests'     => ['🌲', 'Forests', 'forests.php'],
    'vehicles'    => ['🚗', 'Vehicles', 'vehicles.php'],
    'billboards'  => ['📢', 'Billboards', 'billboards.php'],
    'bars'        => ['🍺', 'Bars', 'bars.php'],
    'gasstations' => ['⛽', 'Gas Stations', 'gasstations.php'],
];
?>
<nav class="section-nav" aria-label="Jump to location">
  <?php foreach ($listingsPages as $key => [$icon, $label, $href]): ?>
  <a href="<?= $href ?>" title="<?= ucp_escape($label) ?>" class="<?= $key === $listingsActive ? 'active' : '' ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>
