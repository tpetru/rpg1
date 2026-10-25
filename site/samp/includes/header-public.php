<?php
// Public header for site root pages (not logged-in UCP)
// Links to presentation, howto, UCP, etc.
// Uses absolute (root-relative) hrefs throughout - this include is used both from site-root pages
// (presentation.php) and from one-level-deeper pages (games/index.php, games/snake.php), so relative
// paths like "index.php" would resolve incorrectly from the deeper ones.
require_once __DIR__ . '/lang.php';
$publicLoggedIn = isset($_SESSION['ucp_player_id']);
$publicHeaderNav = $publicHeaderNav ?? true;
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
    <a href="/index.php" class="brand"><img src="/ucp/assets/img/logo.jpg" alt="" class="brand-logo"> No-Santos <span style="font-size:0.75em;color:#ff5da2;vertical-align:0.12em">♥</span> RPG</a>
    <?php if ($publicHeaderNav): ?>
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
      <?php if ($publicLoggedIn): ?>
        <a href="/ucp/dashboard.php" class="brand-dd-box">🧭 UCP</a>
      <?php else: ?>
        <a href="#" class="brand-dd-box auth-login-trigger">🧭 UCP</a>
      <?php endif; ?>
    </div>
    <?php endif; ?>
  </div>
  <?php if ($publicHeaderNav): ?>
  <button type="button" class="topbar-toggle" id="topbarToggle" aria-label="Toggle menu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
  <nav>
    <a href="/index.php">🏠 <?= t('Homepage') ?></a>
    <a href="/presentation.php">🏙️ <?= t('Presentation') ?></a>
    <a href="/forum.php">💬 <?= t('Forum') ?></a>
    <a href="/games/index.php">🎮 <?= t('Games') ?></a>
    <a href="/newspaper.php">📰 <?= t('Newspaper') ?></a>
    <a href="/updates.php">🛠️ <?= t('Updates') ?></a>
    <?php if ($publicLoggedIn): ?>
      <a href="/ucp/dashboard.php">🧭 UCP</a>
    <?php else: ?>
      <a href="#" class="auth-login-trigger">🧭 UCP</a>
    <?php endif; ?>
    <div class="lang-switch">
      <a href="/set_language.php?lang=en&redirect=<?= urlencode($_SERVER['REQUEST_URI'] ?? '/') ?>" class="<?= site_lang_current() === 'en' ? 'active' : '' ?>">EN</a>
      <a href="/set_language.php?lang=ro&redirect=<?= urlencode($_SERVER['REQUEST_URI'] ?? '/') ?>" class="<?= site_lang_current() === 'ro' ? 'active' : '' ?>">RO</a>
    </div>
  </nav>
  <?php endif; ?>
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
})();
</script>

<?php require __DIR__ . '/auth_modal.php'; ?>
