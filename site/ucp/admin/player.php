<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$playerId = (int)($_GET['playerid'] ?? $_POST['playerid'] ?? 0);
$flash = null;
$flashErr = false;

// Field metadata: column => [label, input type]. type: int, float, text, date, bool
$playerFields = [
    'username'            => ['Username', 'text'],
    'password'            => ['Password (plaintext)', 'text'],
    'email'               => ['Email', 'text'],
    'level'               => ['Level', 'int'],
    'rp'                  => ['RP', 'int'],
    'money'               => ['Cash', 'int'],
    'bank'                => ['Bank', 'int'],
    'admin_level'         => ['Admin level', 'int'],
    'faction'             => ['Faction ID (0 = none)', 'int'],
    'faction_rank'        => ['Faction rank', 'int'],
    'faction_join'        => ['Faction join date', 'date'],
    'job'                 => ['Job', 'int'],
    'house'               => ['House ID', 'int'],
    'business'            => ['Business ID', 'int'],
    'hotel'               => ['Hotel ID', 'int'],
    'rent_house'          => ['Renting house ID', 'int'],
    'rent_hotel'          => ['Renting hotel ID', 'int'],
    'caravan_key'         => ['Caravan key', 'int'],
    'spawn_type'          => ['Spawn type', 'int'],
    'skin'                => ['Skin', 'int'],
    'key1'                => ['Key 1', 'int'],
    'key2'                => ['Key 2', 'int'],
    'key3'                => ['Key 3', 'int'],
    'driving_lic_a_exp'   => ['License A expiry', 'date'],
    'driving_lic_b_exp'   => ['License B expiry', 'date'],
    'driving_lic_c_exp'   => ['License C expiry', 'date'],
    'driving_lic_d_exp'   => ['License D expiry', 'date'],
    'airplane_lic_a_exp'  => ['License P (plane) expiry', 'date'],
    'airplane_lic_h_exp'  => ['License H (helicopter) expiry', 'date'],
    'weapon_lic_w_exp'    => ['License W (weapons) expiry', 'date'],
    'medkits'             => ['Medkits', 'int'],
    'extinguishers'       => ['Extinguishers', 'int'],
    'gas_can'             => ['Gas can (-1 = none)', 'int'],
    'phone_model'         => ['Phone model (-1 = none)', 'int'],
    'phone_number'        => ['Phone number', 'int'],
    'phone_expire'        => ['Phone expire (unix)', 'int'],
    'watch_model'         => ['Watch model (-1 = none)', 'int'],
    'watch_expire'        => ['Watch expire', 'date'],
    'diseased'            => ['Diseased', 'bool'],
    'disease_paydays'     => ['Disease paydays left', 'int'],
    'tired'               => ['Tiredness', 'int'],
    'wanted_level'        => ['Wanted level', 'int'],
    'jail_seconds'        => ['Jail seconds left', 'int'],
    'warns'               => ['Warns (0-3)', 'int'],
    'mute_expire'         => ['Mute expire (unix)', 'int'],
    'rob_points'          => ['Rob points', 'int'],
    'is_president'        => ['Is president', 'bool'],
    'was_president'       => ['Was president', 'bool'],
    'voted'               => ['Voted', 'bool'],
];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && $playerId > 0) {
    $set = [];
    $types = '';
    $vals = [];
    foreach ($playerFields as $col => [$label, $type]) {
        switch ($type) {
            case 'int':
                $v = (int)($_POST[$col] ?? 0);
                $types .= 'i';
                break;
            case 'bool':
                $v = isset($_POST[$col]) ? 1 : 0;
                $types .= 'i';
                break;
            case 'date':
                $v = trim($_POST[$col] ?? '');
                if ($v === '') { $v = null; }
                $types .= 's';
                break;
            default:
                $v = trim($_POST[$col] ?? '');
                $types .= 's';
        }
        $set[] = "`$col`=?";
        $vals[] = $v;
    }
    $sql = "UPDATE `players` SET " . implode(', ', $set) . " WHERE `id`=?";
    $types .= 'i';
    $vals[] = $playerId;
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param($types, ...$vals);
    $stmt->execute();
    $stmt->close();
    $flash = "Player #$playerId updated.";
}

// Search by username -> redirect to ?playerid=X once found
$usernameSearch = trim($_GET['username'] ?? '');
if ($playerId === 0 && $usernameSearch !== '') {
    $stmt = $mysqli->prepare("SELECT `id` FROM `players` WHERE `username`=? LIMIT 1");
    $stmt->bind_param('s', $usernameSearch);
    $stmt->execute();
    $found = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($found) {
        header('Location: player.php?playerid=' . (int)$found['id']);
        exit;
    }
    $flash = "No player found with username \"$usernameSearch\".";
    $flashErr = true;
}

$player = null;
if ($playerId > 0) {
    $stmt = $mysqli->prepare("SELECT * FROM `players` WHERE `id`=? LIMIT 1");
    $stmt->bind_param('i', $playerId);
    $stmt->execute();
    $player = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$player) {
        $flash = "Player #$playerId not found.";
        $flashErr = true;
    }
}

$adminActive = 'player';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Player editor</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>

<main>
  <h1>🧍 Player editor</h1>
  <p style="color:var(--muted)">Look up a player by ID and edit every column directly. Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <div class="card">
    <form method="get" style="display:flex; gap:10px; align-items:center; flex-wrap:wrap">
      <label style="color:var(--muted); font-size:0.85rem">Player ID</label>
      <input type="number" name="playerid" min="1" value="<?= $playerId > 0 ? $playerId : '' ?>" style="width:120px; background:var(--panel-2); border:1px solid var(--border); border-radius:6px; padding:6px 10px; color:var(--text)">
      <button type="submit" class="save-btn">Load</button>
    </form>
    <form method="get" style="display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-top:10px">
      <label style="color:var(--muted); font-size:0.85rem">Username</label>
      <input type="text" name="username" value="<?= ucp_escape($usernameSearch) ?>" placeholder="Search by username" style="width:220px; background:var(--panel-2); border:1px solid var(--border); border-radius:6px; padding:6px 10px; color:var(--text)">
      <button type="submit" class="save-btn">Search</button>
    </form>
  </div>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <?php if ($player): ?>
  <div class="card">
    <h2>#<?= (int)$player['id'] ?> — <?= ucp_escape($player['username']) ?></h2>
    <form method="post">
      <input type="hidden" name="playerid" value="<?= (int)$player['id'] ?>">
      <table class="edittable">
        <tr><th>Field</th><th>Value</th></tr>
        <?php foreach ($playerFields as $col => [$label, $type]): $v = $player[$col]; ?>
        <tr>
          <td><?= ucp_escape($label) ?></td>
          <td style="max-width:220px">
            <?php if ($type === 'bool'): ?>
              <input type="checkbox" name="<?= $col ?>" <?= $v ? 'checked' : '' ?>>
            <?php elseif ($type === 'date'): ?>
              <input type="date" name="<?= $col ?>" value="<?= ($v && $v !== '0000-00-00') ? ucp_escape($v) : '' ?>">
            <?php elseif ($type === 'int'): ?>
              <input type="number" name="<?= $col ?>" value="<?= (int)$v ?>">
            <?php else: ?>
              <input type="text" name="<?= $col ?>" value="<?= ucp_escape($v) ?>">
            <?php endif; ?>
          </td>
        </tr>
        <?php endforeach; ?>
      </table>
      <button type="submit" class="save-btn" style="margin-top:12px">Save</button>
    </form>
  </div>
  <?php endif; ?>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
