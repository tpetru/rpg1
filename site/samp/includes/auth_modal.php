<?php
// Shared login/register modal - included from both includes/header.php (UCP pages) and
// includes/header-public.php (site-root pages: index.php, newspaper.php, presentation.php).
// Deliberately self-contained (own CSRF/session handling, hardcoded /ucp/auth_ajax.php path)
// instead of requiring auth.php, so it doesn't pull a DB connection into lightweight public
// pages like index.php that otherwise never touch the database.
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
require_once __DIR__ . '/lang.php';
if (empty($_SESSION['ucp_csrf_token'])) {
    $_SESSION['ucp_csrf_token'] = bin2hex(random_bytes(32));
}
$authModalCsrf = $_SESSION['ucp_csrf_token'];

if (!isset($_SESSION['ucp_player_id'])):
?>
<div id="authModal" class="auth-modal-overlay">
  <div class="auth-modal-backdrop" data-auth-close></div>
  <div class="auth-modal-card">
    <button type="button" class="auth-modal-close" data-auth-close aria-label="<?= t('Close') ?>">&times;</button>

    <div class="auth-modal-body">
      <div class="auth-modal-form-col">
        <h2 class="auth-modal-title">Nostalgia: Los Santos</h2>

        <div class="auth-tabs">
          <span class="auth-tabs-indicator" id="authTabIndicator"></span>
          <button type="button" class="auth-tab active" data-auth-tab="login"><?= t('Login') ?></button>
          <button type="button" class="auth-tab" data-auth-tab="register"><?= t('Register') ?></button>
        </div>

        <div class="auth-modal-error" id="authModalError" hidden></div>

        <form id="authLoginForm" class="auth-form" data-auth-action="login">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($authModalCsrf, ENT_QUOTES, 'UTF-8') ?>">
          <div class="auth-field">
            <span class="auth-field-icon">👤</span>
            <input type="text" name="username" placeholder="<?= t('Username') ?>" autocomplete="username" required>
          </div>
          <div class="auth-field">
            <span class="auth-field-icon">🔒</span>
            <input type="password" name="password" placeholder="<?= t('Password') ?>" autocomplete="current-password" required>
          </div>
          <button type="submit" class="auth-submit"><span class="auth-submit-label"><?= t('Login') ?></span></button>
        </form>

        <div id="authRegisterInfo" class="auth-register-info" hidden>
          <p><?= t('Registration is done directly on our SA-MP server:') ?> <strong>84.234.99.136:7777</strong>.</p>
          <p><?= t('Click') ?> <a href="samp://84.234.99.136:7777">HERE</a> <?= t('to connect to the server and create your account.') ?></p>
          <a href="samp://84.234.99.136:7777" class="auth-submit auth-connect-btn"><?= t('Connect to the server') ?></a>
        </div>
      </div>

      <div class="auth-modal-image-col">
        <img src="/ucp/assets/img/logo.jpg" alt="" class="auth-modal-logo">
      </div>
    </div>
  </div>
</div>
<script>
(function() {
  var modal = document.getElementById('authModal');
  if (!modal) return;
  var errorBox = document.getElementById('authModalError');
  var indicator = document.getElementById('authTabIndicator');
  var card = modal.querySelector('.auth-modal-card');

  function moveIndicator(tab) {
    indicator.style.width = tab.offsetWidth + 'px';
    indicator.style.transform = 'translateX(' + tab.offsetLeft + 'px)';
  }

  function openModal(e) {
    if (e) e.preventDefault();
    modal.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    moveIndicator(modal.querySelector('.auth-tab.active'));
  }
  function closeModal() {
    modal.classList.remove('is-open');
    document.body.style.overflow = '';
    errorBox.hidden = true;
  }

  // Event delegation (not direct listeners) - .auth-login-trigger elements can appear anywhere on the
  // page, including further down the DOM than this script (e.g. footer.php's Login/UCP links), so they
  // may not exist yet when this script runs.
  document.addEventListener('click', function(e) {
    var trigger = e.target.closest('.auth-login-trigger');
    if (trigger) openModal(e);
  });
  modal.querySelectorAll('[data-auth-close]').forEach(function(el) {
    el.addEventListener('click', closeModal);
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && modal.classList.contains('is-open')) closeModal();
  });

  modal.querySelectorAll('.auth-tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
      modal.querySelectorAll('.auth-tab').forEach(function(t) { t.classList.remove('active'); });
      tab.classList.add('active');
      moveIndicator(tab);
      var which = tab.getAttribute('data-auth-tab');
      document.getElementById('authLoginForm').hidden = which !== 'login';
      document.getElementById('authRegisterInfo').hidden = which !== 'register';
      errorBox.hidden = true;
    });
  });

  function showError(msg) {
    errorBox.textContent = msg;
    errorBox.hidden = false;
    card.classList.remove('shake');
    void card.offsetWidth;
    card.classList.add('shake');
  }

  modal.querySelectorAll('.auth-form').forEach(function(form) {
    form.addEventListener('submit', function(e) {
      e.preventDefault();
      var btn = form.querySelector('.auth-submit');
      var label = btn.querySelector('.auth-submit-label');
      var originalLabel = label.textContent;
      var fd = new FormData(form);
      fd.append('action', form.getAttribute('data-auth-action'));
      errorBox.hidden = true;
      btn.disabled = true;
      label.textContent = <?= json_encode(t('Please wait…')) ?>;
      fetch('/ucp/auth_ajax.php', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(data) {
          if (data.success) {
            window.location.href = '/ucp/dashboard.php';
          } else {
            btn.disabled = false;
            label.textContent = originalLabel;
            showError(data.error || <?= json_encode(t('Something went wrong.')) ?>);
          }
        })
        .catch(function() {
          btn.disabled = false;
          label.textContent = originalLabel;
          showError(<?= json_encode(t('Network error, please try again.')) ?>);
        });
    });
  });
})();
</script>
<?php endif; ?>
