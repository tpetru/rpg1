<?php
require_once __DIR__ . '/_auth.php';
casa_require_admin_auth();
// Admin-only page: create houses and set/change each house's own password. Getting into a house's
// actual pages still needs that house's password - being admin here doesn't skip that.
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);

$error = '';
$notice = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    if ($_POST['action'] === 'create_house') {
        $name = trim((string)($_POST['house_name'] ?? ''));
        $password = (string)($_POST['house_password'] ?? '');
        if ($name === '' || mb_strlen($name) > CASA_HOUSE_NAME_MAX) {
            $error = 'Numele casei trebuie să aibă între 1 și ' . CASA_HOUSE_NAME_MAX . ' caractere.';
        } elseif ($password === '') {
            $error = 'Alege o parolă pentru casă.';
        } elseif (hash_equals(CASA_ADMIN_PASSWORD, $password)) {
            $error = 'Parola casei nu poate fi parola de administrare.';
        } else {
            $slug = casa_house_folder_slug($mysqli, $name);
            $stmt = $mysqli->prepare('INSERT INTO casa_houses (slug, name, password) VALUES (?, ?, ?)');
            $stmt->bind_param('sss', $slug, $name, $password);
            $stmt->execute();

            foreach (CASA_STARTER_ROOMS as $room) {
                casa_make_dir(casa_house_dir($slug) . '/design/' . $room);
            }

            $notice = 'Casa „' . $name . '” a fost creată.';
        }
    } elseif ($_POST['action'] === 'set_password') {
        $houseId = (int)($_POST['house_id'] ?? 0);
        $password = (string)($_POST['house_password'] ?? '');
        if ($houseId <= 0 || $password === '') {
            $error = 'Alege o parolă nouă.';
        } elseif (hash_equals(CASA_ADMIN_PASSWORD, $password)) {
            $error = 'Parola casei nu poate fi parola de administrare.';
        } else {
            $stmt = $mysqli->prepare('UPDATE casa_houses SET password = ? WHERE id = ?');
            $stmt->bind_param('si', $password, $houseId);
            $stmt->execute();
            $notice = 'Parola a fost schimbată.';
        }
    } elseif ($_POST['action'] === 'rename_house') {
        $houseId = (int)($_POST['house_id'] ?? 0);
        $name = trim((string)($_POST['house_name'] ?? ''));
        if ($houseId <= 0 || $name === '' || mb_strlen($name) > CASA_HOUSE_NAME_MAX) {
            $error = 'Numele casei trebuie să aibă între 1 și ' . CASA_HOUSE_NAME_MAX . ' caractere.';
        } else {
            // Doar numele afisat. Slug-ul ramane cum e: el da numele folderului cu pozele urcate,
            // iar redenumirea lui ar insemna mutarea fisierelor de pe disc.
            $stmt = $mysqli->prepare('UPDATE casa_houses SET name = ? WHERE id = ?');
            $stmt->bind_param('si', $name, $houseId);
            $stmt->execute();
            $notice = 'Numele a fost schimbat în „' . $name . '”.';
        }
    } elseif ($_POST['action'] === 'open_house') {
        // Deschide casa direct din admin: parola ei e oricum afisata pe pagina asta, deci nu e o
        // scurtatura pe langa nimic - doar te scuteste sa o retastezi la /index.php.
        $houseId = (int)($_POST['house_id'] ?? 0);
        $stmt = $mysqli->prepare('SELECT password FROM casa_houses WHERE id = ?');
        $stmt->bind_param('i', $houseId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        if ($row) {
            casa_house_login($houseId, $row['password']);
            header('Location: /design/');
            exit;
        }
        $error = 'Casa nu mai există.';
    } elseif ($_POST['action'] === 'delete_house') {
        $houseId = (int)($_POST['house_id'] ?? 0);
        $deleted = $houseId > 0 ? casa_delete_house($mysqli, $houseId) : null;
        if ($deleted === null) {
            $error = 'Casa nu a putut fi ștearsă (nu mai există).';
        } else {
            $notice = 'Casa „' . $deleted['name'] . '” a fost ștearsă.';
            $notice .= $deleted['archived'] !== null
                ? ' Pozele ei nu s-au șters: folderul a fost mutat în „' . $deleted['archived'] . '”.'
                : '';
        }
    }
}

$houses = [];
$res = $mysqli->query('SELECT id, slug, name, password FROM casa_houses ORDER BY name ASC');
while ($row = $res->fetch_assoc()) {
    $houses[] = $row;
}
?>
<!DOCTYPE html>
<html lang="ro" data-casa-theme="<?= htmlspecialchars(casa_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="icon" href="/favicon.webp" type="image/webp">
<title>Casa noastră — Admin</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/casa-theme.css?v=<?= @filemtime(__DIR__ . '/assets/casa-theme.css') ?>">
<?php casa_render_theme_head(); ?>
<style>
  body { line-height: 1.6; }
  main { max-width: 640px; margin: 0 auto; padding: 60px 24px 80px; }
  h1 { margin: 0 0 8px; font-family: var(--disp); font-size: 1.9rem; font-weight: 600; color: var(--ink); }
  main > p.sub { margin: 0 0 32px; color: var(--ink-2); font-size: 0.95rem; }

  .house-list { display: flex; flex-direction: column; gap: 10px; margin-bottom: 32px; }
  .house-row {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 14px 18px;
  }
  .house-head { display: flex; align-items: center; gap: 10px; margin-bottom: 6px; }
  .house-head .open-form { flex: 1; min-width: 0; }
  /* Numele e butonul care deschide casa: arata a titlu, nu a buton. Fundalul e scos explicit si
     pe :hover, altfel ar prinde umplutura de accent din regula generala .house-row button:hover. */
  .house-row .name,
  .house-row .name:hover,
  .house-row .name:focus {
    display: inline-flex; align-items: baseline; gap: 9px;
    padding: 0; background: none; border: none; border-radius: 0; box-shadow: none;
    cursor: pointer; text-align: left;
    font-family: var(--disp); font-weight: 600; font-size: 1rem;
    transition: color 0.15s ease;
  }
  .house-row .name { color: var(--ink); }
  .house-row .name:hover { color: var(--accent); }
  .house-row .name:hover .name-text { text-decoration: underline; text-underline-offset: 3px; }
  .house-row .name .open-hint {
    font-family: var(--mono); font-size: 0.7rem; font-weight: 400; color: var(--ink-3);
    opacity: 0; transition: opacity 0.15s ease;
  }
  .house-row .name:hover .open-hint { opacity: 1; }
  .house-head .delete-form { flex-shrink: 0; }
  .house-row .delete-btn {
    padding: 5px 12px;
    background: transparent; border: 1px solid var(--line);
    color: var(--ink-3); font-size: 0.78rem; font-weight: 500;
  }
  .house-row .delete-btn:hover { background: transparent; border-color: var(--bad); color: var(--bad); }
  .house-row .current-password { font-family: var(--mono); font-size: 0.82rem; color: var(--ink-2); margin-bottom: 10px; }
  .house-row .current-password code { color: var(--accent); }
  .house-row form { display: flex; gap: 8px; flex-wrap: wrap; }
  .house-row form + form { margin-top: 8px; }
  /* Butoanele celor doua randuri au text de lungimi diferite - latime fixa pe ele, ca sa iasa
     campurile de nume si de parola exact la fel. */
  .house-row form:not(.open-form):not(.delete-form) button { min-width: 156px; }
  .house-row input[type=text] {
    flex: 1; min-width: 160px;
    padding: 8px 12px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-size: 0.88rem; font-family: var(--mono);
  }
  .house-row input:focus { outline: none; border-color: var(--accent); }
  .house-row button, .add-row button {
    padding: 8px 18px;
    background: var(--accent); border: none; border-radius: 6px;
    color: var(--on-accent); font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer; transition: background 0.2s ease;
  }
  /* Numele casei si butonul de stergere sunt tot <button>, dar nu vrem umplutura de accent pe ele -
     le excludem din regula generala, in loc sa incercam sa o batem la specificitate din alta parte
     (temele /casa au propria versiune a acestei reguli, si ea exclude aceleasi doua butoane). */
  .house-row button:not(.name):not(.delete-btn):hover, .add-row button:hover { background: #c6923a; }

  .add-card {
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 22px 24px;
  }
  .add-card h2 { margin: 0 0 14px; font-family: var(--disp); font-weight: 600; font-size: 1.05rem; color: var(--ink); }
  .add-row { display: flex; gap: 10px; flex-wrap: wrap; }
  .add-row input {
    flex: 1; min-width: 160px;
    padding: 10px 14px;
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    color: var(--ink); font-size: 0.95rem; font-family: var(--disp);
  }
  .add-row input:focus { outline: none; border-color: var(--accent); }

  .form-error {
    margin: 0 0 16px;
    border-left: 2px solid var(--bad);
    background: rgba(210,105,79,.08);
    border-radius: 0 6px 6px 0;
    padding: 11px 13px;
    font-size: 13px; color: var(--ink);
  }
  .form-notice {
    margin: 0 0 16px;
    border-left: 2px solid var(--good);
    background: rgba(157,191,122,.08);
    border-radius: 0 6px 6px 0;
    padding: 11px 13px;
    font-size: 13px; color: var(--ink);
  }
  .top-links { display: flex; justify-content: flex-end; gap: 18px; margin-bottom: 32px; font-size: 0.82rem; }
  .top-links a { color: var(--ink-3); }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CASA</strong><span>admin</span></div>
  </div>
</header>

<main>
  <div class="top-links">
    <a href="/furnizori.php">Furnizori →</a>
    <a href="?logout">Ieși din admin</a>
  </div>

  <h1>Administrare</h1>
  <p class="sub">Click pe numele unei case ca să o deschizi. Tot de aici o redenumești, îi schimbi parola sau o ștergi.</p>

  <?php if ($error !== ''): ?>
    <div class="form-error"><?= htmlspecialchars($error) ?></div>
  <?php endif; ?>
  <?php if ($notice !== ''): ?>
    <div class="form-notice"><?= htmlspecialchars($notice) ?></div>
  <?php endif; ?>

  <div class="house-list">
    <?php if (empty($houses)): ?>
      <p style="color:var(--ink-3); font-size:0.9rem;">Nicio casă încă.</p>
    <?php endif; ?>
    <?php foreach ($houses as $house): ?>
      <div class="house-row">
        <div class="house-head">
          <form method="post" class="open-form">
            <input type="hidden" name="action" value="open_house">
            <input type="hidden" name="house_id" value="<?= (int)$house['id'] ?>">
            <button type="submit" class="name" title="Deschide casa">
              <span class="name-text"><?= htmlspecialchars($house['name']) ?></span><span class="open-hint">deschide →</span>
            </button>
          </form>
          <form method="post" class="delete-form"
                data-confirm="Ștergi casa „<?= htmlspecialchars($house['name'], ENT_QUOTES) ?>”? Se șterg toate datele ei (construcție, jurnal, prețuri, design). Pozele urcate NU se șterg - folderul lor e mutat deoparte.">
            <input type="hidden" name="action" value="delete_house">
            <input type="hidden" name="house_id" value="<?= (int)$house['id'] ?>">
            <button type="submit" class="delete-btn" title="Șterge casa">Șterge</button>
          </form>
        </div>
        <div class="current-password">Parolă curentă: <code><?= htmlspecialchars($house['password']) ?></code></div>
        <form method="post">
          <input type="hidden" name="action" value="rename_house">
          <input type="hidden" name="house_id" value="<?= (int)$house['id'] ?>">
          <input type="text" name="house_name" maxlength="<?= CASA_HOUSE_NAME_MAX ?>" value="<?= htmlspecialchars($house['name']) ?>" required>
          <button type="submit">Schimbă numele</button>
        </form>
        <form method="post">
          <input type="hidden" name="action" value="set_password">
          <input type="hidden" name="house_id" value="<?= (int)$house['id'] ?>">
          <input type="text" name="house_password" placeholder="Parolă nouă" required>
          <button type="submit">Schimbă parola</button>
        </form>
      </div>
    <?php endforeach; ?>
  </div>

  <div class="add-card">
    <h2>Casă nouă</h2>
    <form class="add-row" method="post">
      <input type="hidden" name="action" value="create_house">
      <input type="text" name="house_name" maxlength="<?= CASA_HOUSE_NAME_MAX ?>" placeholder="Numele casei (ex: Chicerea)" required>
      <input type="text" name="house_password" placeholder="Parola casei" required>
      <button type="submit">Creează</button>
    </form>
  </div>
</main>

<?php casa_render_footer(); ?>

<script>
// Confirmare inainte de stergere - formularul poarta textul in data-confirm.
document.querySelectorAll('form[data-confirm]').forEach(function (form) {
  form.addEventListener('submit', function (e) {
    if (!confirm(form.getAttribute('data-confirm'))) e.preventDefault();
  });
});
</script>

</body>
</html>
