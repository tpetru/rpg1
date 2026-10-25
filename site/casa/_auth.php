<?php
require_once __DIR__ . '/_theme.php';
// Session bootstrap, the "who are you" name-gate, and the admin gate for /casa. Actual access to a
// house's data is a separate concern handled by _house.php's casa_require_house_auth() - each house
// has its own password now, so there's no single shared password to check here anymore.
//
// The admin password (below) only unlocks /admin.php (create houses, set/change their
// passwords) - it does NOT grant access into any house's own pages; that always needs that house's
// own password, entered once per browser like before.

const CASA_ADMIN_PASSWORD = '2026';
const CASA_ADMIN_REMEMBER_COOKIE = 'casa_admin_remember';
const CASA_REMEMBER_DAYS = 3650; // ~10 years: a password is meant to be typed once per device
const CASA_NAME_COOKIE = 'casa_name';

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Best-effort display name for the current device/browser - falls back to "Anonim" when nobody
// has set one yet. Used to attribute notes and photo uploads without requiring real accounts.
function casa_current_name(): string
{
    $name = trim((string)($_COOKIE[CASA_NAME_COOKIE] ?? ''));
    return $name !== '' ? $name : 'Anonim';
}

// If a device already has a name cookie, this is a no-op. Otherwise blocks with a lightweight
// name-only prompt so notes/uploads are never silently attributed to "Anonim".
function casa_require_name(): void
{
    if (isset($_POST['casa_name_only'])) {
        $name = trim((string)($_POST['casa_name'] ?? ''));
        if ($name !== '') {
            setcookie(CASA_NAME_COOKIE, $name, [
                'expires'  => time() + CASA_REMEMBER_DAYS * 86400,
                'path'     => '/',
                'httponly' => true,
                'samesite' => 'Lax',
            ]);
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }
    }

    if (trim((string)($_COOKIE[CASA_NAME_COOKIE] ?? '')) !== '') return;

    casa_render_name_page();
    exit;
}

function casa_admin_remember_token(): string
{
    return hash_hmac('sha256', 'casa-admin-remember-v1', CASA_ADMIN_PASSWORD);
}

function casa_is_admin(): bool
{
    if (!empty($_SESSION['casa_admin_auth'])) return true;

    if (!empty($_COOKIE[CASA_ADMIN_REMEMBER_COOKIE]) && hash_equals(casa_admin_remember_token(), (string)$_COOKIE[CASA_ADMIN_REMEMBER_COOKIE])) {
        $_SESSION['casa_admin_auth'] = true;
        return true;
    }
    return false;
}

function casa_admin_login(): void
{
    $_SESSION['casa_admin_auth'] = true;
    setcookie(CASA_ADMIN_REMEMBER_COOKIE, casa_admin_remember_token(), [
        'expires'  => time() + CASA_REMEMBER_DAYS * 86400,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

function casa_admin_logout(): void
{
    unset($_SESSION['casa_admin_auth']);
    setcookie(CASA_ADMIN_REMEMBER_COOKIE, '', ['expires' => time() - 3600, 'path' => '/']);
    // Ca la casa_house_logout(): $_COOKIE pastreaza valoarea veche pe tot restul cererii curente,
    // deci casa_is_admin() ar raspunde inca "da" daca n-am sterge-o si de acolo.
    unset($_COOKIE[CASA_ADMIN_REMEMBER_COOKIE]);
}

// Pentru endpoint-urile AJAX din zona de admin: raspuns JSON, nu formularul de login randat in
// mijlocul unui raspuns care ar trebui sa fie JSON.
function casa_require_admin_api_auth(): void
{
    if (casa_is_admin()) return;
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'not_authenticated']);
    exit;
}

// Gate for /admin.php only.
function casa_require_admin_auth(): void
{
    if (isset($_GET['logout'])) {
        casa_admin_logout();
        header('Location: /admin.php');
        exit;
    }

    $error = '';
    if (isset($_POST['casa_admin_password'])) {
        if (hash_equals(CASA_ADMIN_PASSWORD, (string)$_POST['casa_admin_password'])) {
            casa_admin_login();
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }
        $error = 'Parolă greșită.';
    }

    if (casa_is_admin()) return;

    casa_render_admin_login_page($error);
    exit;
}

function casa_render_admin_login_page(string $error): void
{
    ?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<title>Casa noastră — Admin</title>
<style><?= casa_login_page_css() ?></style>
</head>
<body>
  <form class="login-card" method="post">
    <div class="wordmark"><strong>CASA</strong><span>admin</span></div>
    <div class="divider"></div>
    <h1>Parola de administrare</h1>
    <?php if ($error !== ''): ?>
      <div class="login-error"><span><?= htmlspecialchars($error) ?> Mai încearcă.</span></div>
    <?php endif; ?>
    <div class="login-fields">
      <input type="password" name="casa_admin_password" placeholder="Parola" autofocus autocomplete="current-password">
    </div>
    <button type="submit">Intră</button>
    <?php casa_render_theme_picker('login-theme-picker'); ?>
  </form>
</body>
</html>
    <?php
}

// Same look as the login page, but name-only - shown once per device that doesn't have a name yet.
function casa_render_name_page(): void
{
    ?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<title>Casa noastră</title>
<style><?= casa_login_page_css() ?></style>
</head>
<body>
  <form class="login-card" method="post">
    <div class="wordmark"><strong>CASA</strong><span>noastră</span></div>
    <div class="divider"></div>
    <h1>Cine ești?</h1>
    <p class="sub">Pune-ți numele, ca să apară la notițele și pozele tale</p>
    <input type="text" name="casa_name" placeholder="Numele tău" maxlength="40" autocomplete="name" autofocus required>
    <input type="hidden" name="casa_name_only" value="1">
    <button type="submit">Salvează</button>
  </form>
</body>
</html>
    <?php
}

// Shared inline CSS for the small standalone auth pages of this module (admin login, name gate,
// and _house.php's per-house password prompt) - kept as one function so their look never drifts.
function casa_login_page_css(): string
{
    return <<<'CSS'
  html, body { height: 100%; margin: 0; }
  body {
    display: flex; align-items: center; justify-content: center;
    padding: 24px;
  }
  .login-card { width: 100%; max-width: 352px; display: flex; flex-direction: column; }
  .wordmark { display: flex; align-items: baseline; gap: 8px; }
  .wordmark strong { font-family: var(--disp); font-weight: 700; font-size: 16px; letter-spacing: .16em; color: var(--ink); }
  .wordmark span { font-size: 13px; color: var(--ink-3); }
  .login-card .divider { height: 1px; background: var(--line); margin: 16px 0 0; }
  .login-card h1 { margin: 22px 0 0; font-size: 26px; font-weight: 600; letter-spacing: -0.025em; color: var(--ink); }
  .login-card p.sub { margin: 9px 0 0; font-size: 13.5px; line-height: 1.55; color: var(--ink-2); }
  .login-error {
    margin-top: 18px;
    display: flex; align-items: flex-start; gap: 10px;
    border-left: 2px solid var(--bad);
    background: rgba(210,105,79,.08);
    border-radius: 0 6px 6px 0;
    padding: 11px 13px;
    font-size: 13px; line-height: 1.45; color: var(--ink);
  }
  .login-fields { margin-top: 22px; display: flex; flex-direction: column; gap: 10px; }
  .login-card input[type=password],
  .login-card input[type=text] {
    height: 44px;
    padding: 0 14px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 7px;
    color: var(--ink);
    font-family: var(--disp);
    font-size: 14px;
    margin-top: 20px;
  }
  .login-fields input { margin-top: 0; }
  .login-card input[type=password]:focus,
  .login-card input[type=text]:focus { outline: none; border-color: var(--accent); }
  .login-card button {
    margin-top: 20px;
    border: none; cursor: pointer;
    height: 44px;
    border-radius: 7px;
    background: var(--accent);
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 14px;
    transition: background 0.2s ease;
  }
  .login-card button:hover { background: #c6923a; }
CSS;
}
