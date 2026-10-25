<?php
require_once __DIR__ . '/_auth.php';
// Single entry point for /casa - one password field routes you either into a house (if it matches
// that house's password) or into the admin page (if it matches the fixed admin password). No house
// names are shown here - the password itself is what identifies where you're going.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);

if (isset($_GET['logout'])) {
    casa_house_logout();
    // "?logout=all" (butonul "Ieși" din meniu) te scoate de tot - si din casa, si din admin - ca sa
    // ajungi la ecranul de parola. Simplul "?logout" (numele casei din header) doar schimba casa.
    if ($_GET['logout'] === 'all') {
        casa_admin_logout();
    }
}

// Already authenticated on this device - skip straight past the password screen.
$house = casa_current_authed_house($mysqli);
if ($house !== null) {
    header('Location: /design/');
    exit;
}
if (casa_is_admin()) {
    header('Location: /admin.php');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['casa_password'])) {
    $submitted = (string)$_POST['casa_password'];

    if (hash_equals(CASA_ADMIN_PASSWORD, $submitted)) {
        casa_admin_login();
        header('Location: /admin.php');
        exit;
    }

    $matchedId = null;
    $res = $mysqli->query('SELECT id, password FROM casa_houses');
    while ($row = $res->fetch_assoc()) {
        if ($row['password'] !== '' && hash_equals($row['password'], $submitted)) {
            $matchedId = (int)$row['id'];
            break;
        }
    }

    if ($matchedId !== null) {
        casa_house_login($matchedId, $submitted);
        header('Location: /design/');
        exit;
    }

    $error = 'Parolă greșită.';
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style><?= casa_login_page_css() ?></style>
</head>
<body>
  <form class="login-card" method="post">
    <div class="wordmark"><strong>CASA</strong><span>noastră</span></div>
    <div class="divider"></div>
    <h1>Introdu parola pentru acces</h1>
    <?php if ($error !== ''): ?>
      <div class="login-error"><span><?= htmlspecialchars($error) ?> Mai încearcă.</span></div>
    <?php endif; ?>
    <div class="login-fields">
      <input type="password" name="casa_password" placeholder="Parola" autofocus autocomplete="current-password">
    </div>
    <button type="submit">Intră</button>
    <?php casa_render_theme_picker('login-theme-picker'); ?>
  </form>

</body>
</html>
