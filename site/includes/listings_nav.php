<?php
// Floating right-side quick nav between the property listing pages (houses/hotels/businesses/farms/vehicles).
// The including page must set $listingsActive to one of: houses, hotels, businesses, farms, vehicles
$listingsPages = [
    'houses'     => ['🏠', 'Houses', 'houses.php'],
    'hotels'     => ['🏨', 'Hotels', 'hotels.php'],
    'businesses' => ['🏢', 'Businesses', 'businesses.php'],
    'farms'      => ['🌾', 'Farms', 'farms.php'],
    'vehicles'   => ['🚗', 'Vehicles', 'vehicles.php'],
];
?>
<nav class="section-nav" aria-label="Jump to listing">
  <?php foreach ($listingsPages as $key => [$icon, $label, $href]): ?>
  <a href="<?= $href ?>" title="<?= ucp_escape($label) ?>" class="<?= $key === $listingsActive ? 'active' : '' ?>"><span><?= $icon ?></span></a>
  <?php endforeach; ?>
</nav>
