<?php
// Floating right-side quick nav between the property listing pages.
// The including page must set $listingsActive to one of: houses, hotels, businesses, farms, forests, vehicles, market, billboards, bars, gasstations
require_once __DIR__ . '/lang.php';
$listingsPages = [
    'houses'      => ['🏠', 'Houses', 'houses.php'],
    'hotels'      => ['🏨', 'Hotels', 'hotels.php'],
    'businesses'  => ['🏢', 'Businesses', 'businesses.php'],
    'farms'       => ['🌾', 'Farms', 'farms.php'],
    'forests'     => ['🌲', 'Forests', 'forests.php'],
    'vehicles'    => ['🚗', 'Vehicles', 'vehicles.php'],
    'market'      => ['🛒', 'Vehicle Market', 'market.php'],
    'billboards'  => ['📢', 'Billboards', 'billboards.php'],
    'bars'        => ['🍺', 'Bars', 'bars.php'],
    'gasstations' => ['⛽', 'Gas Stations', 'gasstations.php'],
];
?>
<nav class="section-nav" aria-label="<?= t('Jump to location') ?>">
  <?php foreach ($listingsPages as $key => [$icon, $label, $href]): ?>
  <a href="<?= $href ?>" title="<?= ucp_escape(t($label)) ?>" class="<?= $key === $listingsActive ? 'active' : '' ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>
