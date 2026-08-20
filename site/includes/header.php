<?php
// Shared top navigation bar, included by every UCP page. Most pages require login (ucp_require_login()
// before this include), but some forum pages allow guests, so this must render safely logged-out too.
// Uses UCP_BASE (defined in auth.php) for all links/assets so it renders correctly
// regardless of how deep the including page lives (e.g. /ucp/admin/houses.php).
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';

$headerLoggedIn   = isset($_SESSION['ucp_player_id']);
$headerAdminLevel = ucp_current_admin_level();
$headerIsAdmin    = $headerAdminLevel > 0;
$headerCanEdit    = $headerAdminLevel >= 5; // editing houses/businesses/etc. requires level 5, same as /hc /bc /farmc in-game
$headerFaction    = ucp_current_faction();
$headerIsLeader   = $headerFaction > 0 && ucp_is_faction_leader($headerFaction);
$b = UCP_BASE;
?>
<header class="topbar">
  <div class="brand-dd">
    <a href="/index.php" class="brand"><img src="<?= $b ?>/assets/img/logo.jpg" alt="" class="brand-logo"> No-Santos <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</a>
    <span class="brand-dd-caret">▾</span>
    <div class="brand-dd-menu">
      <a href="/forum.php" class="brand-dd-box">💬 Forum</a>
      <div class="brand-cj-idle" aria-hidden="true">
        <span class="bcj-head"></span>
        <span class="bcj-torso"></span>
        <span class="bcj-arm bcj-arm-l"></span>
        <span class="bcj-arm bcj-arm-r"></span>
        <span class="bcj-leg bcj-leg-l"></span>
        <span class="bcj-leg bcj-leg-r"></span>
      </div>
      <?php if ($headerLoggedIn): ?>
        <a href="<?= $b ?>/dashboard.php" class="brand-dd-box">🧭 UCP</a>
      <?php else: ?>
        <a href="#" class="brand-dd-box auth-login-trigger">🧭 UCP</a>
      <?php endif; ?>
    </div>
  </div>
  <button type="button" class="topbar-toggle" id="topbarToggle" aria-label="Toggle menu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <nav>
    <a href="<?= $b ?>/dashboard.php">🏠 Dashboard</a>
    <a href="<?= $b ?>/maps.php">🗺️ Maps</a>
    <a href="<?= $b ?>/vip.php" style="color:#FFD700">⭐ VIP</a>
    <a href="/forum.php">💬 Forum</a>

    <div class="nav-dd">
      <a href="<?= $b ?>/houses.php" class="dd-toggle">🗺️ World Data ▾</a>
      <div class="nav-dd-menu">
        <a href="<?= $b ?>/houses.php">🏠 Houses</a>
        <a href="<?= $b ?>/hotels.php">🏨 Hotels</a>
        <a href="<?= $b ?>/businesses.php">🏢 Businesses</a>
        <a href="<?= $b ?>/farms.php">🌾 Farms</a>
        <a href="<?= $b ?>/forests.php">🌲 Forests</a>
        <a href="<?= $b ?>/vehicles.php">🚗 Vehicles</a>
        <a href="<?= $b ?>/billboards.php">📢 Billboards</a>
        <a href="<?= $b ?>/bars.php">🍺 Bars</a>
        <a href="<?= $b ?>/gasstations.php">⛽ Gas Stations</a>
      </div>
    </div>

    <?php if ($headerIsAdmin): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">🏴 Factions ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">🏴 All factions</a>
          <?php for ($fi = 1; $fi <= 8; $fi++): ?>
            <a href="<?= $b ?>/faction<?= $fi ?>.php"><?= ucp_escape(ucp_faction_name($fi)) ?></a>
          <?php endfor; ?>
        </div>
      </div>
    <?php elseif ($headerIsLeader): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">🏴 Factions ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">🏴 All factions</a>
          <a href="<?= $b ?>/faction<?= $headerFaction ?>.php"><?= ucp_escape(ucp_faction_name($headerFaction)) ?></a>
        </div>
      </div>
    <?php else: ?>
      <a href="<?= $b ?>/factions.php">🏴 Factions</a>
    <?php endif; ?>

    <?php if ($headerCanEdit || $headerIsAdmin): ?>
      <span class="nav-sep" aria-hidden="true"></span>
    <?php endif; ?>
    <?php if ($headerCanEdit): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/admin/houses.php" class="dd-toggle">🛠️ Admin ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/admincmds.php">🛡️ Admin Cmds</a>
          <a href="<?= $b ?>/admin/ammunation.php">🔫 AmmuNation</a>
          <a href="<?= $b ?>/admin/bars.php">🍺 Bars</a>
          <a href="<?= $b ?>/admin/billboards.php">📢 Billboards</a>
          <a href="<?= $b ?>/admin/businesses.php">🏢 Businesses</a>
          <a href="<?= $b ?>/admin/clothstores.php">👕 Clothing Stores</a>
          <a href="<?= $b ?>/admin/farms.php">🌾 Farms</a>
          <a href="<?= $b ?>/admin/fastfood.php">🍔 Fast-food</a>
          <a href="<?= $b ?>/admin/forests.php">🌲 Forests</a>
          <a href="<?= $b ?>/admin/hotels.php">🏨 Hotels</a>
          <a href="<?= $b ?>/admin/houses.php">🏠 Houses</a>
          <a href="<?= $b ?>/admin/player.php">🧍 Player</a>
          <a href="<?= $b ?>/admin/prices.php">💲 Prices</a>
          <a href="<?= $b ?>/admin/shops.php">🛒 Shops</a>
          <a href="<?= $b ?>/admin/vehicles.php">🚗 Vehicles</a>
        </div>
      </div>
    <?php elseif ($headerIsAdmin): ?>
      <a href="<?= $b ?>/admincmds.php">🛡️ Admin Cmds</a>
    <?php endif; ?>
    <?php if (!$headerLoggedIn): ?>
      <a href="#" class="auth-login-trigger">🔑 Login</a>
    <?php endif; ?>
  </nav>
  <div class="userbox">
    <?php if ($headerLoggedIn): ?>
      <div class="nav-dd user-dd">
        <span class="dd-toggle"><?= ucp_escape($_SESSION['ucp_username']) ?><?= $headerIsAdmin ? ' · admin lvl ' . $headerAdminLevel : '' ?> ▾</span>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/dashboard.php">🏠 Dashboard</a>
          <a href="<?= $b ?>/logout.php">🚪 Logout</a>
        </div>
      </div>
    <?php else: ?>
      Guest
    <?php endif; ?>
  </div>
</header>

<script>
(function() {
  var topbar = document.querySelector('header.topbar');
  var toggle = document.getElementById('topbarToggle');
  if (!toggle) return;
  toggle.addEventListener('click', function() {
    var open = topbar.classList.toggle('nav-open');
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
  var mq = window.matchMedia('(max-width: 860px)');
  document.querySelectorAll('header.topbar .nav-dd > .dd-toggle').forEach(function(link) {
    link.addEventListener('click', function(e) {
      if (mq.matches) {
        e.preventDefault();
        link.closest('.nav-dd').classList.toggle('dd-mobile-open');
      }
    });
  });
})();
</script>

<?php require __DIR__ . '/auth_modal.php'; ?>
