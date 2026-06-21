<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

$pid = ucp_current_player_id();

$stmt = $mysqli->prepare("SELECT * FROM `players` WHERE `id` = ? LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$player = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$player) {
    ucp_logout();
    header('Location: index.php');
    exit;
}

// Vehicule personale detinute
$stmt = $mysqli->prepare("SELECT * FROM `vehicles_personal` WHERE `owner_id` = ? ORDER BY `id` ASC");
$stmt->bind_param('i', $pid);
$stmt->execute();
$vehicles = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

// Rulota personala (daca detine)
$caravan = null;
if ((int)$player['caravan_key'] > 0) {
    $stmt = $mysqli->prepare("SELECT * FROM `rulote_personale` WHERE `rOwner` = ? AND `rOwned` = 1 LIMIT 1");
    $stmt->bind_param('i', $pid);
    $stmt->execute();
    $caravan = $stmt->get_result()->fetch_assoc();
    $stmt->close();
}

// Info generale despre server (derivate din DB, nu necesita conexiune la procesul SA-MP)
$serverStats = [];
$serverStats['players']   = (int)$mysqli->query("SELECT COUNT(*) c FROM `players`")->fetch_assoc()['c'];
$serverStats['houses']    = (int)$mysqli->query("SELECT COUNT(*) c FROM `houses` WHERE `owned` = 1")->fetch_assoc()['c'];
$serverStats['businesses']= (int)$mysqli->query("SELECT COUNT(*) c FROM `businesses` WHERE `owned` = 1")->fetch_assoc()['c'];
$serverStats['vehicles']  = (int)$mysqli->query("SELECT COUNT(*) c FROM `vehicles_personal` WHERE `owner_id` != 0")->fetch_assoc()['c'];

// Skin-ul jucatorului: gamemode-ul are momentan o singura clasa inregistrata (model 7, AddPlayerClass in bare.pwn),
// deci toti playerii au acelasi skin - nu exista inca o coloana `skin` per player in DB.
// Daca se adauga selectie de skin in gamemode, adauga o coloana `players`.`skin` si inlocuieste valoarea de mai jos.
$skinId = 7;
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NostalgiaRP UCP — Dashboard</title>
<link rel="stylesheet" href="assets/css/style.css">
</head>
<body>

<header class="topbar">
  <div class="brand">🏙️ NostalgiaRP UCP</div>
  <nav>
    <a href="dashboard.php">Dashboard</a>
    <?php if (ucp_current_admin_level() > 0): ?>
      <a href="admin.php">Admin</a>
    <?php endif; ?>
    <a href="logout.php">Logout</a>
  </nav>
  <div class="userbox"><?= ucp_escape($_SESSION['ucp_username']) ?></div>
</header>

<main>
  <h1>Bine ai venit, <?= ucp_escape($player['username']) ?></h1>

  <div class="grid-2">
    <div class="card">
      <h2>👤 Contul tău</h2>
      <table>
        <tr><th>Nivel</th><td><?= (int)$player['level'] ?></td></tr>
        <tr><th>RP</th><td><?= (int)$player['rp'] ?></td></tr>
        <tr><th>Cash</th><td>$<?= ucp_money($player['money']) ?></td></tr>
        <tr><th>Bancă</th><td>$<?= ucp_money($player['bank']) ?></td></tr>
        <tr><th>Facțiune</th><td><?= ucp_escape(ucp_faction_name($player['faction'])) ?><?= $player['faction'] > 0 ? ' (rang ' . (int)$player['faction_rank'] . ')' : '' ?></td></tr>
        <tr><th>Admin level</th><td><?= (int)$player['admin_level'] ?></td></tr>
        <tr><th>Casă</th><td><?= ((int)$player['house'] !== 999) ? ('ID #' . (int)$player['house']) : 'Nu deține' ?></td></tr>
      </table>
    </div>

    <div class="card">
      <h2>🪪 Permise auto</h2>
      <table>
        <?php
        $licenses = [
            'A' => $player['driving_lic_a_exp'],
            'B' => $player['driving_lic_b_exp'],
            'C' => $player['driving_lic_c_exp'],
            'D' => $player['driving_lic_d_exp'],
        ];
        foreach ($licenses as $cat => $exp):
            $st = ucp_license_status($exp);
        ?>
          <tr>
            <th>Categoria <?= $cat ?></th>
            <td><span class="pill <?= $st['ok'] ? 'pill-ok' : 'pill-bad' ?>"><?= ucp_escape($st['label']) ?></span></td>
          </tr>
        <?php endforeach; ?>
      </table>
    </div>
  </div>

  <div class="grid-2">
    <div class="card" style="display:flex; gap:18px; align-items:center;">
      <div class="skin-box">
        <img src="assets/img/skins/skin_<?= (int)$skinId ?>.png" alt="Skin <?= (int)$skinId ?>"
             onerror="this.parentElement.innerHTML='Skin #<?= (int)$skinId ?><br>(fără imagine)';">
      </div>
      <div>
        <h2 style="margin-bottom:4px">🧍 Skin-ul tău</h2>
        <p style="color:var(--muted); margin:0">Model #<?= (int)$skinId ?>. Toți jucătorii folosesc același skin momentan
        (serverul nu are încă selecție de skin per jucător).</p>
      </div>
    </div>

    <div class="card">
      <h2>🌍 Despre server</h2>
      <table>
        <tr><th>Conturi înregistrate</th><td><?= $serverStats['players'] ?></td></tr>
        <tr><th>Case vândute</th><td><?= $serverStats['houses'] ?></td></tr>
        <tr><th>Afaceri vândute</th><td><?= $serverStats['businesses'] ?></td></tr>
        <tr><th>Vehicule personale deținute</th><td><?= $serverStats['vehicles'] ?></td></tr>
      </table>
    </div>
  </div>

  <?php if ($caravan): ?>
  <div class="card">
    <h2>🚐 Rulota ta</h2>
    <p style="color:var(--muted)">Tip <?= (int)$player['caravan_key'] ?> ·
    <?= $caravan['rCamping'] ? 'În camping' : 'Parcată' ?></p>
  </div>
  <?php endif; ?>

  <div class="card">
    <h2>🚗 Mașinile tale (<?= count($vehicles) ?>)</h2>
    <?php if (!$vehicles): ?>
      <p style="color:var(--muted)">Nu deții niciun vehicul personal.</p>
    <?php else: ?>
      <table>
        <tr><th>ID</th><th>Model</th><th>Plăcuță</th><th>Asigurare</th><th>Kit medical</th><th>Extinctor</th><th>ITP</th></tr>
        <?php foreach ($vehicles as $v):
            $ins = ucp_doc_status($v['insurance_exp']);
            $med = ucp_doc_status($v['medkit_exp']);
            $ext = ucp_doc_status($v['extinguisher_exp']);
            $itp = ucp_doc_status($v['itp_exp']);
        ?>
        <tr>
          <td>#<?= (int)$v['id'] ?></td>
          <td>Model #<?= (int)$v['model_id'] ?></td>
          <td><?= ucp_escape($v['plate'] ?? '—') ?></td>
          <td><span class="pill <?= $ins['ok'] ? 'pill-ok' : 'pill-bad' ?>"><?= ucp_escape($ins['label']) ?></span></td>
          <td><span class="pill <?= $med['ok'] ? 'pill-ok' : 'pill-bad' ?>"><?= ucp_escape($med['label']) ?></span></td>
          <td><span class="pill <?= $ext['ok'] ? 'pill-ok' : 'pill-bad' ?>"><?= ucp_escape($ext['label']) ?></span></td>
          <td><span class="pill <?= $itp['ok'] ? 'pill-ok' : 'pill-bad' ?>"><?= ucp_escape($itp['label']) ?></span></td>
        </tr>
        <?php endforeach; ?>
      </table>
    <?php endif; ?>
  </div>
</main>

<footer>NostalgiaRP UCP</footer>

</body>
</html>
