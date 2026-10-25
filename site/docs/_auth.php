<?php
// Password gate for /docs.php and everything under /docs. Included at the very top of the page
// and endpoints, before any output. Pages get a login form; AJAX endpoints get a 401 JSON response
// instead, so a logged-out request can't silently look like a success.
//
// One master password (below) gives full access - every document, every filter, and the "manage
// companies" section. Each company ("firma") can also have its own password (docs_companies.password,
// editable from that same section) - logging in with it locks the session to that one company's
// documents, with the filters and company management hidden entirely (see docs.php, which filters
// the list and skips that markup). Every endpoint that touches a document or a company also
// re-checks the lock server-side (docs_require_doc_access() / docs_require_full_access()) - the
// hidden UI alone isn't enough, since a locked-in browser can still call the endpoints directly.

const DOCS_MASTER_PASSWORD = '1103';
const DOCS_REMEMBER_COOKIE = 'docs_remember';
const DOCS_REMEMBER_DAYS = 3650; // ~10 years: the password is meant to be typed once per device

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// $companyId is 0 for the master role - baked into the token so a master cookie can't be replayed
// as a company cookie (or vice versa) even if the hashes were ever to collide.
function docs_remember_token(string $role, int $companyId, string $password): string
{
    return hash_hmac('sha256', 'docs-remember-v3:' . $role . ':' . $companyId, $password);
}

// Returns ['role' => 'all'|'company', 'company_id' => int|null, 'company_name' => string|null],
// or null if the password matches neither the master password nor any company's password.
function docs_match_password(mysqli $mysqli, string $password): ?array
{
    if ($password === '') return null;

    if (hash_equals(DOCS_MASTER_PASSWORD, $password)) {
        return ['role' => 'all', 'company_id' => null, 'company_name' => null];
    }

    $stmt = $mysqli->prepare("SELECT id, name FROM docs_companies WHERE password IS NOT NULL AND password != '' AND password = ? LIMIT 1");
    $stmt->bind_param('s', $password);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    if ($row) {
        return ['role' => 'company', 'company_id' => (int)$row['id'], 'company_name' => $row['name']];
    }
    return null;
}

function docs_is_logged_in(mysqli $mysqli): bool
{
    if (!empty($_SESSION['docs_auth']) && in_array($_SESSION['docs_role'] ?? '', ['all', 'company'], true)) {
        return true;
    }

    if (!empty($_COOKIE[DOCS_REMEMBER_COOKIE])) {
        $parts = explode(':', $_COOKIE[DOCS_REMEMBER_COOKIE], 3);
        if (count($parts) === 3) {
            [$role, $companyIdStr, $token] = $parts;
            $companyId = (int)$companyIdStr;

            if ($role === 'all' && hash_equals(docs_remember_token('all', 0, DOCS_MASTER_PASSWORD), $token)) {
                $_SESSION['docs_auth'] = true;
                $_SESSION['docs_role'] = 'all';
                $_SESSION['docs_company_id'] = null;
                return true;
            }

            if ($role === 'company' && $companyId > 0) {
                $stmt = $mysqli->prepare('SELECT password FROM docs_companies WHERE id = ?');
                $stmt->bind_param('i', $companyId);
                $stmt->execute();
                $row = $stmt->get_result()->fetch_assoc();
                $companyPassword = $row['password'] ?? '';
                // If the password was since cleared/changed, this token no longer verifies -
                // the remembered device is naturally logged out instead of silently let back in.
                if ($companyPassword !== '' && hash_equals(docs_remember_token('company', $companyId, $companyPassword), $token)) {
                    $_SESSION['docs_auth'] = true;
                    $_SESSION['docs_role'] = 'company';
                    $_SESSION['docs_company_id'] = $companyId;
                    return true;
                }
            }
        }
    }
    return false;
}

function docs_login(string $role, ?int $companyId, string $password): void
{
    $_SESSION['docs_auth'] = true;
    $_SESSION['docs_role'] = $role;
    $_SESSION['docs_company_id'] = $companyId;

    $cookieValue = $role . ':' . ($companyId ?? 0) . ':' . docs_remember_token($role, $companyId ?? 0, $password);
    setcookie(DOCS_REMEMBER_COOKIE, $cookieValue, [
        'expires'  => time() + DOCS_REMEMBER_DAYS * 86400,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

function docs_logout(): void
{
    unset($_SESSION['docs_auth'], $_SESSION['docs_role'], $_SESSION['docs_company_id']);
    setcookie(DOCS_REMEMBER_COOKIE, '', ['expires' => time() - 3600, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax']);
}

// Company id this session is locked to, or null when it has full access (role 'all').
function docs_locked_company_id(): ?int
{
    if (($_SESSION['docs_role'] ?? '') !== 'company') return null;
    return $_SESSION['docs_company_id'] ?? null;
}

// For endpoints that act on one document: refuse with 403 JSON if it's outside the locked
// company. No-op for full access.
function docs_require_doc_access(mysqli $mysqli, int $docId): void
{
    $lockedCompanyId = docs_locked_company_id();
    if ($lockedCompanyId === null) return;

    $stmt = $mysqli->prepare('SELECT company_id FROM docs_items WHERE id = ?');
    $stmt->bind_param('i', $docId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    if (!$row || $row['company_id'] === null || (int)$row['company_id'] !== $lockedCompanyId) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'forbidden']);
        exit;
    }
}

// For endpoints that manage companies themselves (add/rename/delete/password): locked roles
// can't touch the company list at all, only their own documents.
function docs_require_full_access(): void
{
    if (docs_locked_company_id() === null) return;
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'forbidden']);
    exit;
}

// For AJAX endpoints: refuse with JSON instead of rendering a login page into the response.
function docs_require_api_auth(mysqli $mysqli): void
{
    if (docs_is_logged_in($mysqli)) return;
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'not_authenticated']);
    exit;
}

// For full pages: render the login form and stop, unless already authenticated.
function docs_require_page_auth(mysqli $mysqli): void
{
    if (isset($_GET['logout'])) {
        docs_logout();
        header('Location: /');
        exit;
    }

    $error = '';
    if (isset($_POST['docs_password'])) {
        $match = docs_match_password($mysqli, (string)$_POST['docs_password']);
        if ($match !== null) {
            docs_login($match['role'], $match['company_id'], (string)$_POST['docs_password']);
            // Redirect so a refresh doesn't re-post the password.
            header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?'));
            exit;
        }
        $error = 'Parolă greșită.';
    }

    if (docs_is_logged_in($mysqli)) return;

    docs_render_login_page($error);
    exit;
}

function docs_render_login_page(string $error): void
{
    ?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Documente</title>
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
    <div class="wordmark"><strong>DOCS</strong></div>
    <div class="divider"></div>
    <h1>Introdu parola pentru acces</h1>
    <?php if ($error !== ''): ?>
      <div class="login-error"><span><?= htmlspecialchars($error) ?> Mai încearcă.</span></div>
    <?php endif; ?>
    <input type="password" name="docs_password" placeholder="Parola" autofocus autocomplete="current-password">
    <button type="submit">Intră</button>
    <?php site_render_theme_picker('login-theme-picker'); ?>
  </form>
</body>
</html>
    <?php
}
