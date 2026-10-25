<?php
// Parola pentru /admin - singurul loc din care se poate schimba harta orasului.
const CITY_ADMIN_PASSWORD = 'city2026';
const CITY_ADMIN_COOKIE = 'city_admin';
const CITY_ADMIN_DAYS = 30;

if (session_status() === PHP_SESSION_NONE) session_start();

function city_admin_token(): string
{
    return hash_hmac('sha256', 'city-admin-v1', CITY_ADMIN_PASSWORD);
}

function city_admin_logged_in(): bool
{
    if (!empty($_SESSION['city_admin'])) return true;
    $c = $_COOKIE[CITY_ADMIN_COOKIE] ?? '';
    if (is_string($c) && $c !== '' && hash_equals(city_admin_token(), $c)) {
        $_SESSION['city_admin'] = true;
        return true;
    }
    return false;
}

function city_admin_set_cookie(string $value, int $expires): void
{
    setcookie(CITY_ADMIN_COOKIE, $value, ['expires' => $expires, 'path' => '/admin', 'httponly' => true, 'secure' => !empty($_SERVER['HTTPS']), 'samesite' => 'Lax']);
}

function city_require_admin_api(): void
{
    if (city_admin_logged_in()) return;
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'not_authenticated']);
    exit;
}

function city_require_admin_page(): void
{
    if (isset($_GET['logout'])) {
        unset($_SESSION['city_admin']);
        city_admin_set_cookie('', time() - 3600);
        header('Location: /admin/');
        exit;
    }
    $error = '';
    if (isset($_POST['password'])) {
        if (hash_equals(CITY_ADMIN_PASSWORD, (string)$_POST['password'])) {
            $_SESSION['city_admin'] = true;
            city_admin_set_cookie(city_admin_token(), time() + CITY_ADMIN_DAYS * 86400);
            header('Location: /admin/');
            exit;
        }
        $error = 'Parolă greșită.';
    }
    if (city_admin_logged_in()) return;
    ?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Admin · No-Santos City</title>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800&display=swap" rel="stylesheet">
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 16px; box-sizing: border-box;
    background: #6f9a5d; font-family: 'Nunito', system-ui, sans-serif; color: #4a3f32; }
  form { width: min(340px, 100%); background: #fffaf0; border-radius: 20px; padding: 26px; box-shadow: 0 20px 60px rgba(40,30,15,.35); text-align: center; }
  .logo { font-size: 2.2rem; }
  h1 { margin: 6px 0 16px; font-size: 1.3rem; }
  input { width: 100%; box-sizing: border-box; padding: 11px 14px; border: 1px solid rgba(120,100,70,.25); border-radius: 12px; font: inherit; text-align: center; }
  input:focus { outline: none; border-color: #e0894a; }
  button { width: 100%; margin-top: 12px; padding: 12px; border: none; border-radius: 12px; background: #e0894a; color: #fff; font: inherit; font-weight: 800; cursor: pointer; }
  .err { margin-bottom: 12px; color: #c0533f; font-weight: 700; }
  a { display: block; margin-top: 14px; color: #857766; font-size: .85rem; }
</style>
</head>
<body>
  <form method="post">
    <div class="logo">🏗️</div>
    <h1>Administrare oraș</h1>
    <?php if ($error): ?><div class="err"><?= htmlspecialchars($error) ?></div><?php endif; ?>
    <input type="password" name="password" placeholder="Parola" autofocus autocomplete="current-password">
    <button type="submit">Intră</button>
    <a href="/">← Înapoi la oraș</a>
  </form>
</body>
</html>
    <?php
    exit;
}
