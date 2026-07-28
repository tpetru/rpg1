<?php
// Include comun pentru paginile faction1.php..faction8.php
// Fiecare fisier wrapper seteaza $factionId inainte de a include acest fisier.

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';
ucp_require_faction_access($factionId);

$isAdmin  = ucp_current_admin_level() > 0;
$isLeader = ucp_is_faction_leader($factionId);

$flash = null;
$flashErr = false;

// Recalculeaza numarul de membri, la fel ca "UPDATE factions f SET f.members = (SELECT COUNT(*) ...)" din bare.pwn
function faction_sync_members($mysqli, $factionId) {
    $stmt = $mysqli->prepare("UPDATE `factions` SET `members` = (SELECT COUNT(*) FROM `players` WHERE `faction` = ?) WHERE `id` = ?");
    $stmt->bind_param('ii', $factionId, $factionId);
    $stmt->execute();
    $stmt->close();
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $action = $_POST['action'] ?? '';

    // ---- Uninvite/kick a member (leader or admin) - mirrors /fkick and /adminuninvite in bare.pwn ----
    if ($action === 'kick') {
        $targetId = (int)($_POST['player_id'] ?? 0);
        $stmt = $mysqli->prepare("SELECT `id`,`username`,`faction_rank` FROM `players` WHERE `id` = ? AND `faction` = ? LIMIT 1");
        $stmt->bind_param('ii', $targetId, $factionId);
        $stmt->execute();
        $target = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$target) {
            $flash = "Player not found in this faction."; $flashErr = true;
        } elseif ((int)$target['faction_rank'] >= 5) {
            $flash = "Use \"Remove leader\" to remove the faction leader."; $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction`=0, `faction_rank`=1, `faction_join`=NULL WHERE `id`=?");
            $stmt->bind_param('i', $targetId);
            $stmt->execute();
            $stmt->close();
            faction_sync_members($mysqli, $factionId);
            $flash = ucp_escape($target['username']) . " was removed from the faction.";
        }
    }

    // ---- Change a member's rank (leader or admin) - mirrors /fsetrank in bare.pwn ----
    if ($action === 'setrank') {
        $targetId = (int)($_POST['player_id'] ?? 0);
        $newRank  = max(1, min(4, (int)($_POST['new_rank'] ?? 1))); // rank 5 (leader) is handled separately

        $stmt = $mysqli->prepare("SELECT `id`,`username`,`faction_rank` FROM `players` WHERE `id` = ? AND `faction` = ? LIMIT 1");
        $stmt->bind_param('ii', $targetId, $factionId);
        $stmt->execute();
        $target = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$target) {
            $flash = "Player not found in this faction."; $flashErr = true;
        } elseif ((int)$target['faction_rank'] >= 5) {
            $flash = "You can't change the leader's rank this way."; $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction_rank`=? WHERE `id`=?");
            $stmt->bind_param('ii', $newRank, $targetId);
            $stmt->execute();
            $stmt->close();
            $flash = ucp_escape($target['username']) . "'s rank was set to $newRank.";
        }
    }

    // ---- Refill all faction vehicles (leader or admin) - mirrors /refillfactionveh in bare.pwn ----
    if ($action === 'refill') {
        $stmt = $mysqli->prepare("UPDATE `vehicles_faction` SET `fuel`=100 WHERE `faction_id`=?");
        $stmt->bind_param('i', $factionId);
        $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        $flash = "Refilled $affected faction vehicle(s) to full fuel.";
    }

    // ---- Admin only: remove the faction leader (player becomes a civilian) - mirrors /fc [id] removelead ----
    if ($action === 'remove_lead' && $isAdmin) {
        $stmt = $mysqli->prepare("SELECT `id`,`username` FROM `players` WHERE `faction` = ? AND `faction_rank` >= 5 LIMIT 1");
        $stmt->bind_param('i', $factionId);
        $stmt->execute();
        $leader = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$leader) {
            $flash = "This faction has no leader."; $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction`=0, `faction_rank`=1, `faction_join`=NULL WHERE `id`=?");
            $stmt->bind_param('i', $leader['id']);
            $stmt->execute();
            $stmt->close();

            $stmt = $mysqli->prepare("UPDATE `factions` SET `lead`='' WHERE `id`=?");
            $stmt->bind_param('i', $factionId);
            $stmt->execute();
            $stmt->close();

            faction_sync_members($mysqli, $factionId);
            $flash = ucp_escape($leader['username']) . " is no longer the faction leader and is now a civilian.";
        }
    }

    // ---- Admin only: directly set the faction bank amount ----
    if ($action === 'set_bank' && $isAdmin) {
        $amount = max(0, (int)($_POST['amount'] ?? 0));
        $stmt = $mysqli->prepare("UPDATE `factions` SET `bank`=? WHERE `id`=?");
        $stmt->bind_param('ii', $amount, $factionId);
        $stmt->execute();
        $stmt->close();
        $flash = "Faction bank set to $" . ucp_money($amount) . ".";
    }
}

$stmt = $mysqli->prepare("SELECT * FROM `factions` WHERE `id` = ? LIMIT 1");
$stmt->bind_param('i', $factionId);
$stmt->execute();
$faction = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$faction) {
    header('Location: dashboard.php');
    exit;
}

$stmt = $mysqli->prepare("SELECT `id`,`username`,`level`,`faction_rank` FROM `players` WHERE `faction` = ? ORDER BY `faction_rank` DESC, `username` ASC");
$stmt->bind_param('i', $factionId);
$stmt->execute();
$members = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

$vehicles = [];
try {
    $stmt = $mysqli->prepare("SELECT `id`,`model_id`,`fuel` FROM `vehicles_faction` WHERE `faction_id` = ? ORDER BY `id` ASC");
    $stmt->bind_param('i', $factionId);
    $stmt->execute();
    $vehicles = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
} catch (mysqli_sql_exception $e) {
    $vehicles = []; // table doesn't exist yet - gamemode hasn't started since it was added
}

$isMafia = $factionId >= 4 && $factionId <= 7;
$factionName = ucp_faction_name($factionId);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — <?= ucp_escape($factionName) ?></title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
<style>
  .flash { padding: 10px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 0.92rem; }
  .flash.ok { background: rgba(62,207,142,0.1); border: 1px solid var(--green); color: var(--green); }
  .flash.err { background: rgba(255,93,93,0.1); border: 1px solid var(--red); color: var(--red); }
  .row-actions { display: flex; gap: 6px; align-items: center; }
  .row-actions select { background: var(--panel-2); border: 1px solid var(--border); color: var(--text); border-radius: 6px; padding: 4px 6px; }
  .row-actions button, .btn { background: var(--accent); border: none; border-radius: 6px; color: #0f1115; font-weight: 600; font-size: 0.82rem; padding: 5px 12px; cursor: pointer; }
  .row-actions button.danger, .btn.danger { background: var(--red); color: #fff; }
  .row-actions button:hover, .btn:hover { opacity: 0.9; }
  .bank-form { display: flex; gap: 8px; align-items: center; margin-top: 10px; }
  .bank-form input[type=number] { width: 160px; background: var(--panel-2); border: 1px solid var(--border); color: var(--text); border-radius: 6px; padding: 6px 8px; }
</style>
</head>
<body>

<?php
include __DIR__ . '/header.php';
?>

<main>
  <h1><?= ucp_escape($factionName) ?></h1>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= $flash ?></div>
  <?php endif; ?>

  <div class="grid-2">
    <div class="card">
      <h2>🏛️ Faction info</h2>
      <table>
        <tr><th>Name</th><td><?= ucp_escape($faction['name'] ?: $factionName) ?></td></tr>
        <tr><th>Leader</th><td><?= $faction['lead'] ? ucp_escape($faction['lead']) : '—' ?></td></tr>
        <tr><th>Members</th><td><?= count($members) ?></td></tr>
        <tr><th>Bank</th><td>$<?= ucp_money($faction['bank']) ?></td></tr>
      </table>

      <?php if ($isAdmin): ?>
        <?php if ($faction['lead']): ?>
        <form method="post" style="margin-top:14px" onsubmit="return confirm('Remove the faction leader? They will become a civilian.');">
          <input type="hidden" name="action" value="remove_lead">
          <button type="submit" class="btn danger">Remove leader</button>
        </form>
        <?php endif; ?>

        <form method="post" class="bank-form">
          <input type="hidden" name="action" value="set_bank">
          <label for="bank-amount" style="color:var(--muted); font-size:0.85rem">Set bank:</label>
          <input id="bank-amount" type="number" name="amount" min="0" value="<?= (int)$faction['bank'] ?>">
          <button type="submit" class="btn">Save</button>
        </form>
      <?php endif; ?>
    </div>

    <?php if ($isMafia): ?>
    <div class="card">
      <h2>🔒 Stash</h2>
      <table>
        <tr>
          <th>Herbs</th>
          <td>
            <?= (int)$faction['seif_herbs'] ?>g / 10000g
            <span class="meter"><span class="meter-fill good" style="width:<?= min(100, (int)$faction['seif_herbs'] / 100) ?>%"></span></span>
          </td>
        </tr>
        <tr>
          <th>Drugs</th>
          <td>
            <?= (int)$faction['seif_drugs'] ?>g / 1000g
            <span class="meter"><span class="meter-fill bad" style="width:<?= min(100, (int)$faction['seif_drugs'] / 10) ?>%"></span></span>
          </td>
        </tr>
      </table>
    </div>
    <?php endif; ?>
  </div>

  <div class="card">
    <h2>👥 Members (<?= count($members) ?>)</h2>
    <?php if (!$members): ?>
      <p style="color:var(--muted)">No members in this faction.</p>
    <?php else: ?>
      <div style="overflow-x:auto">
      <table>
        <tr><th>ID</th><th>Username</th><th>Level</th><th>Rank</th><th></th></tr>
        <?php foreach ($members as $m): $mrank = (int)$m['faction_rank']; ?>
        <tr>
          <td>#<?= (int)$m['id'] ?></td>
          <td><?= ucp_escape($m['username']) ?></td>
          <td><?= (int)$m['level'] ?></td>
          <td>
            <?php if ($mrank >= 5): ?>
              <span class="pill pill-lvl">Leader</span>
            <?php else: ?>
              Rank <?= $mrank ?>
            <?php endif; ?>
          </td>
          <td>
            <?php if ($mrank < 5): ?>
            <div class="row-actions">
              <form method="post" style="display:flex; gap:6px; align-items:center">
                <input type="hidden" name="action" value="setrank">
                <input type="hidden" name="player_id" value="<?= (int)$m['id'] ?>">
                <select name="new_rank">
                  <?php for ($r = 1; $r <= 4; $r++): ?>
                    <option value="<?= $r ?>" <?= $mrank === $r ? 'selected' : '' ?>>Rank <?= $r ?></option>
                  <?php endfor; ?>
                </select>
                <button type="submit">Set</button>
              </form>
              <form method="post" onsubmit="return confirm('Remove <?= ucp_escape(addslashes($m['username'])) ?> from the faction?');">
                <input type="hidden" name="action" value="kick">
                <input type="hidden" name="player_id" value="<?= (int)$m['id'] ?>">
                <button type="submit" class="danger">Kick</button>
              </form>
            </div>
            <?php else: ?>
              <span style="color:var(--muted); font-size:0.85rem">—</span>
            <?php endif; ?>
          </td>
        </tr>
        <?php endforeach; ?>
      </table>
      </div>
    <?php endif; ?>
  </div>

  <div class="card">
    <h2>🚗 Faction vehicles (<?= count($vehicles) ?>)</h2>

    <form method="post" style="margin-bottom:14px" onsubmit="return confirm('Refill all faction vehicles to full fuel?');">
      <input type="hidden" name="action" value="refill">
      <button type="submit" class="btn">⛽ Refill all vehicles</button>
    </form>

    <?php if (!$vehicles): ?>
      <p style="color:var(--muted)">No vehicles registered to this faction.</p>
    <?php else: ?>
      <table>
        <tr><th>ID</th><th>Model ID</th><th>Model name</th><th>Fuel</th></tr>
        <?php foreach ($vehicles as $v):
            $fuelPct = max(0, min(100, (float)$v['fuel']));
            $fuelTier = $fuelPct >= 60 ? 'ok' : ($fuelPct >= 30 ? 'warn' : 'bad');
        ?>
        <tr>
          <td>#<?= (int)$v['id'] ?></td>
          <td><?= (int)$v['model_id'] ?></td>
          <td><?= ucp_escape(ucp_vehicle_name($v['model_id'])) ?></td>
          <td>
            <span class="meter"><span class="meter-fill <?= $fuelTier ?>" style="width:<?= $fuelPct ?>%"></span></span>
            <span class="meter-label"><?= (int)round($fuelPct) ?>%</span>
          </td>
        </tr>
        <?php endforeach; ?>
      </table>
    <?php endif; ?>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
