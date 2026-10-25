<?php
// Password gate for everything under /aris. Included at the very top of each page and endpoint,
// before any output. Pages get a login form; AJAX endpoints get a 401 JSON response instead, so a
// logged-out request can't silently look like a success.
//
// Single shared password, no user accounts - same pattern as /casa/_auth.php but without roles.

const ARIS_PASSWORD = '1103';
const ARIS_REMEMBER_COOKIE = 'aris_remember';
const ARIS_REMEMBER_DAYS = 3650; // ~10 years: the password is meant to be typed once per device

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

function aris_remember_token(): string
{
    return hash_hmac('sha256', 'aris-remember-v1', ARIS_PASSWORD);
}

function aris_is_logged_in(): bool
{
    if (!empty($_SESSION['aris_auth'])) return true;

    if (!empty($_COOKIE[ARIS_REMEMBER_COOKIE]) && hash_equals(aris_remember_token(), $_COOKIE[ARIS_REMEMBER_COOKIE])) {
        $_SESSION['aris_auth'] = true; // promote the cookie to a session for the rest of the visit
        return true;
    }
    return false;
}

function aris_login(): void
{
    $_SESSION['aris_auth'] = true;
    setcookie(ARIS_REMEMBER_COOKIE, aris_remember_token(), [
        'expires'  => time() + ARIS_REMEMBER_DAYS * 86400,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

function aris_logout(): void
{
    unset($_SESSION['aris_auth']);
    setcookie(ARIS_REMEMBER_COOKIE, '', [
        'expires'  => time() - 3600,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

// For AJAX endpoints: refuse with JSON instead of rendering a login page into the response.
function aris_require_api_auth(): void
{
    if (aris_is_logged_in()) return;
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'not_authenticated']);
    exit;
}

// For full pages: render the login form and stop, unless already authenticated.
function aris_require_page_auth(): void
{
    if (isset($_GET['logout'])) {
        aris_logout();
        header('Location: /');
        exit;
    }

    $error = '';
    if (isset($_POST['aris_password'])) {
        if (hash_equals(ARIS_PASSWORD, (string)$_POST['aris_password'])) {
            aris_login();
            // Redirect so a refresh doesn't re-post the password.
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }
        $error = 'Parolă greșită.';
    }

    if (aris_is_logged_in()) return;

    aris_render_login_page($error);
    exit;
}

function aris_render_login_page(string $error): void
{
    ?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Aris</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  html, body { height: 100%; margin: 0; }
  body {
    display: flex; align-items: center; justify-content: center;
    padding: 24px;
  }
  .login-card { width: 100%; max-width: 352px; display: flex; flex-direction: column; }
  .wordmark { display: flex; align-items: baseline; gap: 8px; }
  .wordmark strong { font-family: var(--disp); font-weight: 700; font-size: 16px; letter-spacing: .16em; color: var(--ink); }
  .login-card .divider { height: 1px; background: var(--line); margin: 16px 0 0; }
  .login-card h1 { margin: 22px 0 0; font-size: 26px; font-weight: 600; letter-spacing: -0.025em; color: var(--ink); }
  .login-error {
    margin-top: 18px;
    display: flex; align-items: flex-start; gap: 10px;
    border-left: 2px solid var(--bad);
    background: rgba(210,105,79,.08);
    border-radius: 0 6px 6px 0;
    padding: 11px 13px;
    font-size: 13px; line-height: 1.45; color: var(--ink);
  }
  .login-card input[type=password] {
    margin-top: 22px;
    height: 44px;
    padding: 0 14px;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 7px;
    color: var(--ink);
    font-family: var(--disp);
    font-size: 14px;
  }
  .login-card input[type=password]:focus { outline: none; border-color: var(--accent); }
  .login-card button {
    margin-top: 14px;
    border: none; cursor: pointer;
    height: 44px;
    border-radius: 7px;
    background: var(--accent);
    color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 14px;
    transition: background 0.2s ease;
  }
  .login-card button:hover { background: #c6923a; }
</style>
</head>
<body>
  <form class="login-card" method="post">
    <div class="wordmark"><strong>ARIS</strong></div>
    <div class="divider"></div>
    <h1>Introdu parola pentru acces</h1>
    <?php if ($error !== ''): ?>
      <div class="login-error"><span><?= htmlspecialchars($error) ?> Mai încearcă.</span></div>
    <?php endif; ?>
    <input type="password" name="aris_password" placeholder="Parola" autofocus autocomplete="current-password">
    <button type="submit">Intră</button>
    <?php site_render_theme_picker('login-theme-picker'); ?>
  </form>
</body>
</html>
    <?php
}
