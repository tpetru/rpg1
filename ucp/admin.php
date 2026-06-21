<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_admin();

$myLevel = ucp_current_admin_level();

// Lista de comenzi admin, oglindita exact dupa /ahelp din gamemodes/bare.pwn.
// Tine sincronizat manual cu blocul "---- /ahelp ----" daca se adauga/schimba comenzi acolo.
$ADMIN_COMMANDS = [
    1 => [
        'General' => ['/ahelp', '/respawn', '/aheal', '/businesslist', '/showradars', '/removeradar'],
    ],
    2 => [
        'General' => ['/createFire', '/healall', '/gotoLoc', '/gotoBiz', '/gotoHouse', '/gotoFaction', '/goto', '/openGolfTournament', '/startGolf'],
    ],
    3 => [
        'General'     => ['/veh', '/rac', '/createDisease'],
        'DrivingLic'  => ['/setDrivingLicAexp', '/setDrivingLicBexp', '/setDrivingLicCexp', '/setDrivingLicDexp'],
    ],
    5 => [
        'General'   => ['/payday'],
        'PVehicles' => ['/vchangeINSURANCEexp', '/vchangeMEDKITexp', '/vchangeEXTINCTORexp', '/vchangeITPexp'],
    ],
    6 => [
        'Factions'  => ['/changeFactionHQ', '/changeFactionhqIcon', '/changeFactionPickup', '/changeFactionLead', '/createFactionVeh', '/removeFactionLead'],
        'Houses'    => ['/createHouse', '/changeHousePrice', '/changeHouseOwner'],
        'PVehicles' => ['/vCreate', '/vSetPrice'],
        'Caravans'  => ['/createCaravan'],
        'Business'  => ['/createBiz', '/changeBizName', '/changeBizPrice', '/changeBizLoc'],
    ],
];
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NostalgiaRP UCP — Admin</title>
<link rel="stylesheet" href="assets/css/style.css">
</head>
<body>

<header class="topbar">
  <div class="brand">🏙️ NostalgiaRP UCP</div>
  <nav>
    <a href="dashboard.php">Dashboard</a>
    <a href="admin.php">Admin</a>
    <a href="logout.php">Logout</a>
  </nav>
  <div class="userbox"><?= ucp_escape($_SESSION['ucp_username']) ?> · admin lvl <?= $myLevel ?></div>
</header>

<main>
  <h1>Comenzi admin (nivelul tău: <?= $myLevel ?>)</h1>

  <?php foreach ($ADMIN_COMMANDS as $level => $groups): ?>
    <?php if ($level > $myLevel) continue; ?>
    <div class="card">
      <h2><span class="pill pill-lvl">Nivel <?= $level ?></span></h2>
      <table>
        <tr><th>Categorie</th><th>Comenzi</th></tr>
        <?php foreach ($groups as $groupName => $cmds): ?>
          <tr>
            <td style="white-space:nowrap; color:var(--muted)"><?= ucp_escape($groupName) ?></td>
            <td>
              <?php foreach ($cmds as $cmd): ?>
                <code><?= ucp_escape($cmd) ?></code>
              <?php endforeach; ?>
            </td>
          </tr>
        <?php endforeach; ?>
      </table>
    </div>
  <?php endforeach; ?>
</main>

<footer>NostalgiaRP UCP</footer>

</body>
</html>
