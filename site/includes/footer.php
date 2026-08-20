<?php
// Relies on the including page having already called session_start() (directly, or via auth.php) -
// this file is included near the end of <body>, too late to safely start a session of its own
// (headers are already sent by then, so session_start() here would just throw a warning).
$footerIsLoggedIn = isset($_SESSION['ucp_player_id']);
?>
<style>
  .site-footer {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 56px;
    padding: 36px 24px 32px;
    border-top: 1px solid #252b32;
    font-size: 0.86rem;
  }
  .site-footer .footer-col {
    display: flex;
    flex-direction: column;
    gap: 11px;
    min-width: 130px;
  }
  .site-footer .footer-col a {
    position: relative;
    align-self: flex-start;
    color: #8e969f;
    text-decoration: none;
    transition: color 0.2s ease;
  }
  .site-footer .footer-col a::after {
    content: "";
    position: absolute;
    left: 0; bottom: -3px;
    width: 100%; height: 1px;
    background: linear-gradient(90deg, #ff6a00, #ff8533);
    transform: scaleX(0);
    transform-origin: left;
    transition: transform 0.25s ease;
  }
  .site-footer .footer-col a:hover {
    color: #fff;
    text-decoration: none;
  }
  .site-footer .footer-col a:hover::after {
    transform: scaleX(1);
  }
</style>
<footer class="site-footer">
  <div class="footer-col">
    <a href="/index.php">Homepage</a>
    <a href="/tc.html">Terms &amp; Conditions</a>
    <a href="/ucp/vip.php">VIP</a>
  </div>
  <div class="footer-col">
    <a href="/index.php">Homepage</a>
    <a href="/presentation.php">Presentation</a>
    <?php if ($footerIsLoggedIn): ?>
    <a href="/ucp/maps.php">Maps</a>
    <a href="/ucp/howto.php">How To</a>
    <?php endif; ?>
  </div>
  <div class="footer-col">
    <a href="/index.php">Homepage</a>
    <?php if ($footerIsLoggedIn): ?>
      <a href="/ucp/dashboard.php">Dashboard</a>
    <?php else: ?>
      <a href="#" class="auth-login-trigger">Login</a>
    <?php endif; ?>
    <a href="/forum.php">Forum</a>
    <?php if ($footerIsLoggedIn): ?>
      <a href="/ucp/dashboard.php">UCP</a>
    <?php else: ?>
      <a href="#" class="auth-login-trigger">UCP</a>
    <?php endif; ?>
  </div>
</footer>
