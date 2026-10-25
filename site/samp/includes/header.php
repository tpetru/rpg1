<?php
// Shared top navigation bar, included by every UCP page. Most pages require login (ucp_require_login()
// before this include), but some forum pages allow guests, so this must render safely logged-out too.
// Uses UCP_BASE (defined in auth.php) for all links/assets so it renders correctly
// regardless of how deep the including page lives (e.g. /ucp/admin/houses.php).
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';
require_once __DIR__ . '/lang.php';

$headerLoggedIn   = isset($_SESSION['ucp_player_id']);
$headerAdminLevel = ucp_current_admin_level();
$headerIsAdmin    = $headerAdminLevel > 0;
$headerCanEdit    = $headerAdminLevel >= 5; // editing houses/businesses/etc. requires level 5, same as /hc /bc /farmc in-game
$headerFaction    = ucp_current_faction();
$headerIsLeader   = $headerFaction > 0 && ucp_is_faction_leader($headerFaction);
$b = UCP_BASE;
?>
<style>
  .lang-switch { display: inline-flex; gap: 2px; margin-left: 10px; font-size: 0.78rem; }
  .lang-switch a {
    color: #8e969f; text-decoration: none; padding: 3px 7px; border-radius: 5px;
    border: 1px solid #252b32;
  }
  .lang-switch a:hover { color: #fff; text-decoration: none; }
  .lang-switch a.active { color: #fff; background: #171c22; border-color: #ff8533; }
</style>
<header class="topbar">
  <div class="brand-dd">
    <a href="/index.php" class="brand"><img src="<?= $b ?>/assets/img/logo.jpg" alt="" class="brand-logo"> No-Santos <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</a>
    <span class="brand-dd-caret">▾</span>
    <div class="brand-dd-menu">
      <a href="/forum.php" class="brand-dd-box">💬 <?= t('Forum') ?></a>
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
    <a href="<?= $b ?>/dashboard.php">🏠 <?= t('Dashboard') ?></a>
    <a href="<?= $b ?>/maps.php">🗺️ <?= t('Maps') ?></a>
    <a href="<?= $b ?>/map_holiday.php">🎁 <?= t('Holiday Map') ?></a>
    <a href="<?= $b ?>/vip.php" style="color:#FFD700">⭐ VIP</a>
    <a href="/forum.php">💬 <?= t('Forum') ?></a>
    <a href="/updates.php">🛠️ <?= t('Updates') ?></a>

    <div class="nav-dd">
      <a href="<?= $b ?>/houses.php" class="dd-toggle">🗺️ <?= t('World Data') ?> ▾</a>
      <div class="nav-dd-menu">
        <a href="<?= $b ?>/houses.php">🏠 <?= t('Houses') ?></a>
        <a href="<?= $b ?>/hotels.php">🏨 <?= t('Hotels') ?></a>
        <a href="<?= $b ?>/businesses.php">🏢 <?= t('Businesses') ?></a>
        <a href="<?= $b ?>/farms.php">🌾 <?= t('Farms') ?></a>
        <a href="<?= $b ?>/forests.php">🌲 <?= t('Forests') ?></a>
        <a href="<?= $b ?>/vehicles.php">🚗 <?= t('Vehicles') ?></a>
        <a href="<?= $b ?>/market.php">🛒 <?= t('Vehicle Market') ?></a>
        <a href="<?= $b ?>/billboards.php">📢 <?= t('Billboards') ?></a>
        <a href="<?= $b ?>/bars.php">🍺 <?= t('Bars') ?></a>
        <a href="<?= $b ?>/gasstations.php">⛽ <?= t('Gas Stations') ?></a>
      </div>
    </div>

    <?php if ($headerIsAdmin): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">🏴 <?= t('Factions') ?> ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">🏴 <?= t('All factions') ?></a>
          <?php for ($fi = 1; $fi <= 9; $fi++): ?>
            <a href="<?= $b ?>/faction<?= $fi ?>.php"><?= ucp_escape(ucp_faction_name($fi)) ?></a>
          <?php endfor; ?>
        </div>
      </div>
    <?php elseif ($headerIsLeader): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/factions.php" class="dd-toggle">🏴 <?= t('Factions') ?> ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/factions.php">🏴 <?= t('All factions') ?></a>
          <a href="<?= $b ?>/faction<?= $headerFaction ?>.php"><?= ucp_escape(ucp_faction_name($headerFaction)) ?></a>
        </div>
      </div>
    <?php else: ?>
      <a href="<?= $b ?>/factions.php">🏴 <?= t('Factions') ?></a>
    <?php endif; ?>

    <?php if ($headerCanEdit || $headerIsAdmin): ?>
      <span class="nav-sep" aria-hidden="true"></span>
    <?php endif; ?>
    <?php if ($headerCanEdit): ?>
      <div class="nav-dd">
        <a href="<?= $b ?>/admin/houses.php" class="dd-toggle">🛠️ <?= t('Admin') ?> ▾</a>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/admincmds.php">🛡️ <?= t('Admin Cmds') ?></a>
          <a href="<?= $b ?>/admin/ammunation.php">🔫 AmmuNation</a>
          <a href="<?= $b ?>/admin/bars.php">🍺 <?= t('Bars') ?></a>
          <a href="<?= $b ?>/admin/billboards.php">📢 <?= t('Billboards') ?></a>
          <a href="<?= $b ?>/admin/businesses.php">🏢 <?= t('Businesses') ?></a>
          <a href="<?= $b ?>/admin/clothstores.php">👕 <?= t('Clothing Stores') ?></a>
          <a href="<?= $b ?>/admin/farms.php">🌾 <?= t('Farms') ?></a>
          <a href="<?= $b ?>/admin/fastfood.php">🍔 <?= t('Fast-food') ?></a>
          <a href="<?= $b ?>/admin/forests.php">🌲 <?= t('Forests') ?></a>
          <a href="<?= $b ?>/admin/hotels.php">🏨 <?= t('Hotels') ?></a>
          <a href="<?= $b ?>/admin/houses.php">🏠 <?= t('Houses') ?></a>
          <a href="<?= $b ?>/admin/player.php">🧍 <?= t('Player') ?></a>
          <a href="<?= $b ?>/admin/prices.php">💲 <?= t('Prices') ?></a>
          <a href="<?= $b ?>/admin/shops.php">🛒 <?= t('Shops') ?></a>
          <a href="<?= $b ?>/admin/temperature.php">🌡️ <?= t('Temperature') ?></a>
          <a href="<?= $b ?>/admin/vehicles.php">🚗 <?= t('Vehicles') ?></a>
        </div>
      </div>
    <?php elseif ($headerIsAdmin): ?>
      <a href="<?= $b ?>/admincmds.php">🛡️ <?= t('Admin Cmds') ?></a>
      <?php if ($headerAdminLevel >= 2): ?>
        <a href="<?= $b ?>/admin/temperature.php">🌡️ <?= t('Temperature') ?></a>
      <?php endif; ?>
    <?php endif; ?>
    <?php if (!$headerLoggedIn): ?>
      <a href="#" class="auth-login-trigger">🔑 <?= t('Login') ?></a>
    <?php endif; ?>
  </nav>
  <div class="userbox">
    <?php if ($headerLoggedIn): ?>
      <div class="nav-dd user-dd">
        <span class="dd-toggle"><?= ucp_escape($_SESSION['ucp_username']) ?><?= $headerIsAdmin ? ' · ' . t('admin lvl') . ' ' . $headerAdminLevel : '' ?> ▾</span>
        <div class="nav-dd-menu">
          <a href="<?= $b ?>/dashboard.php">🏠 <?= t('Dashboard') ?></a>
          <a href="<?= $b ?>/logout.php">🚪 <?= t('Logout') ?></a>
        </div>
      </div>
    <?php else: ?>
      <?= t('Guest') ?>
    <?php endif; ?>
    <div class="lang-switch">
      <a href="/set_language.php?lang=en&redirect=<?= urlencode($_SERVER['REQUEST_URI'] ?? '/') ?>" class="<?= site_lang_current() === 'en' ? 'active' : '' ?>">EN</a>
      <a href="/set_language.php?lang=ro&redirect=<?= urlencode($_SERVER['REQUEST_URI'] ?? '/') ?>" class="<?= site_lang_current() === 'ro' ? 'active' : '' ?>">RO</a>
    </div>
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
