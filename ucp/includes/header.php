<?php
// Shared top navigation bar, included by every logged-in UCP page.
// Uses UCP_BASE (defined in auth.php) for all links/assets so it renders correctly
// regardless of how deep the including page lives (e.g. /ucp/admin/houses.php).
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';

$headerAdminLevel = ucp_current_admin_level();
$headerIsAdmin    = $headerAdminLevel > 0;
$headerCanEdit    = $headerAdminLevel >= 5; // editing houses/businesses/etc. requires level 5, same as /hc /bc /farmc in-game
$headerFaction    = ucp_current_faction();
$headerIsLeader   = $headerFaction > 0 && ucp_is_faction_leader($headerFaction);
$b = UCP_BASE;
?>
<header class="topbar">
  <a href="<?= $b ?>/index.php" class="brand"><img src="<?= $b ?>/assets/img/logo.jpg" alt="" class="brand-logo"> Nostalgia: Los Santos UCP</a>
  <nav>
    <a href="<?= $b ?>/dashboard.php">Dashboard</a>
    <a href="<?= $b ?>/maps.php">Map</a>
    <a href="<?= $b ?>/howto.php">How To</a>

    <?php if ($headerIsAdmin): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">Factions ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">All factions</a>
          <?php for ($fi = 1; $fi <= 8; $fi++): ?>
            <a href="<?= $b ?>/faction<?= $fi ?>.php"><?= ucp_escape(ucp_faction_name($fi)) ?></a>
          <?php endfor; ?>
        </div>
      </div>
    <?php elseif ($headerIsLeader): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">Factions ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">All factions</a>
          <a href="<?= $b ?>/faction<?= $headerFaction ?>.php"><?= ucp_escape(ucp_faction_name($headerFaction)) ?></a>
        </div>
      </div>
    <?php else: ?>
      <a href="<?= $b ?>/factions.php">Factions</a>
    <?php endif; ?>

    <?php if ($headerCanEdit): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/admin/houses.php" class="dd-toggle">Admin ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/admin/houses.php">Houses</a>
          <a href="<?= $b ?>/admin/businesses.php">Businesses</a>
          <a href="<?= $b ?>/admin/vehicles.php">Vehicles</a>
          <a href="<?= $b ?>/admin/farms.php">Farms</a>
          <a href="<?= $b ?>/admin/hotels.php">Hotels</a>
          <a href="<?= $b ?>/admin/shops.php">Shops</a>
          <a href="<?= $b ?>/admin/fastfood.php">Fast-food</a>
          <a href="<?= $b ?>/admincmds.php">Admin Cmds</a>
        </div>
      </div>
    <?php elseif ($headerIsAdmin): ?>
      <a href="<?= $b ?>/admincmds.php">Admin Cmds</a>
    <?php endif; ?>
    <a href="<?= $b ?>/logout.php">Logout</a>
  </nav>
  <div class="userbox">
    <?= ucp_escape($_SESSION['ucp_username']) ?><?= $headerIsAdmin ? ' · admin lvl ' . $headerAdminLevel : '' ?>
  </div>
</header>
