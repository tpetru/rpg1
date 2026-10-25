<?php
// Include comun pentru paginile faction1.php..faction8.php
// Fiecare fisier wrapper seteaza $factionId inainte de a include acest fisier.

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';
global $mysqli;
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

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !ucp_csrf_verify()) {
    $flash = t("Security check failed (invalid or expired form). Please try again.");
    $flashErr = true;
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
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
            $flash = t("Player not found in this faction."); $flashErr = true;
        } elseif ((int)$target['faction_rank'] >= 5) {
            $flash = t('Use "Remove leader" to remove the faction leader.'); $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction`=0, `faction_rank`=0, `faction_join`=NULL WHERE `id`=?");
            $stmt->bind_param('i', $targetId);
            $stmt->execute();
            $stmt->close();
            faction_sync_members($mysqli, $factionId);
            $flash = ucp_escape($target['username']) . " " . t("was removed from the faction.");
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
            $flash = t("Player not found in this faction."); $flashErr = true;
        } elseif ((int)$target['faction_rank'] >= 5) {
            $flash = t("You can't change the leader's rank this way."); $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction_rank`=? WHERE `id`=?");
            $stmt->bind_param('ii', $newRank, $targetId);
            $stmt->execute();
            $stmt->close();
            $flash = sprintf(t("%s's rank was set to %d."), ucp_escape($target['username']), $newRank);
        }
    }

    // ---- Refill all faction vehicles (leader or admin) - mirrors /refillfactionveh in bare.pwn ----
    if ($action === 'refill') {
        $stmt = $mysqli->prepare("UPDATE `vehicles_faction` SET `fuel`=100 WHERE `faction_id`=?");
        $stmt->bind_param('i', $factionId);
        $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        $flash = t("Refilled") . " $affected " . t("faction vehicle(s) to full fuel.");
    }

    // ---- Admin only: remove the faction leader (player becomes a civilian) - mirrors /fc [id] removelead ----
    if ($action === 'remove_lead' && $isAdmin) {
        $stmt = $mysqli->prepare("SELECT `id`,`username` FROM `players` WHERE `faction` = ? AND `faction_rank` >= 5 LIMIT 1");
        $stmt->bind_param('i', $factionId);
        $stmt->execute();
        $leader = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$leader) {
            $flash = t("This faction has no leader."); $flashErr = true;
        } else {
            $stmt = $mysqli->prepare("UPDATE `players` SET `faction`=0, `faction_rank`=0, `faction_join`=NULL WHERE `id`=?");
            $stmt->bind_param('i', $leader['id']);
            $stmt->execute();
            $stmt->close();

            $stmt = $mysqli->prepare("UPDATE `factions` SET `lead`='' WHERE `id`=?");
            $stmt->bind_param('i', $factionId);
            $stmt->execute();
            $stmt->close();

            faction_sync_members($mysqli, $factionId);
            $flash = ucp_escape($leader['username']) . " " . t("is no longer the faction leader and is now a civilian.");
        }
    }

    // ---- Admin only: directly set the faction bank amount ----
    if ($action === 'set_bank' && $isAdmin) {
        $amount = max(0, (int)($_POST['amount'] ?? 0));
        $stmt = $mysqli->prepare("UPDATE `factions` SET `bank`=? WHERE `id`=?");
        $stmt->bind_param('ii', $amount, $factionId);
        $stmt->execute();
        $stmt->close();
        $flash = t("Faction bank set to") . " $" . ucp_money($amount) . ".";
    }

    // ---- Leader/admin: update a faction application's status ----
    if ($action === 'app_status') {
        $appId = (int)($_POST['app_id'] ?? 0);
        $newStatus = $_POST['new_status'] ?? '';
        $rejectReason = trim($_POST['reject_reason'] ?? '');

        $stmt = $mysqli->prepare("SELECT * FROM `ucp_factapplications` WHERE `id` = ? AND `factionsId` = ? LIMIT 1");
        $stmt->bind_param('ii', $appId, $factionId);
        $stmt->execute();
        $app = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$app) {
            $flash = t("Application not found."); $flashErr = true;
        } elseif (!in_array($newStatus, ['Review', 'Accepted', 'Rejected'], true)) {
            $flash = t("Invalid status."); $flashErr = true;
        } elseif ($newStatus === 'Rejected' && $rejectReason === '') {
            $flash = t("Please provide a reason for rejecting this application."); $flashErr = true;
        } elseif ($newStatus === 'Accepted') {
            $stmt = $mysqli->prepare("SELECT `username`, `faction` FROM `players` WHERE `id` = ? LIMIT 1");
            $stmt->bind_param('i', $app['playerId']);
            $stmt->execute();
            $applicant = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            $currentMembers = (int)$mysqli->query("SELECT COUNT(*) c FROM `players` WHERE `faction` = " . (int)$factionId)->fetch_assoc()['c'];
            $maxMembers = (int)$mysqli->query("SELECT `max_members` m FROM `factions` WHERE `id` = " . (int)$factionId)->fetch_assoc()['m'];

            if (!$applicant) {
                $flash = t("Applicant no longer exists."); $flashErr = true;
            } elseif ($currentMembers >= $maxMembers) {
                $flash = t("This faction is full") . " (" . $currentMembers . "/" . $maxMembers . " " . t("members") . ")."; $flashErr = true;
            } else {
                $stmt = $mysqli->prepare("UPDATE `players` SET `faction`=?, `faction_rank`=1 WHERE `id`=?");
                $stmt->bind_param('ii', $factionId, $app['playerId']);
                $stmt->execute();
                $stmt->close();

                faction_sync_members($mysqli, $factionId);

                $stmt = $mysqli->prepare("UPDATE `ucp_factapplications` SET `status`='Accepted' WHERE `id`=?");
                $stmt->bind_param('i', $appId);
                $stmt->execute();
                $stmt->close();

                $flash = sprintf(t("%s's application was accepted and they joined the faction."), ucp_escape($applicant['username']));
            }
        } else {
            $stmt = $mysqli->prepare("UPDATE `ucp_factapplications` SET `status`=?, `reject_reason`=? WHERE `id`=?");
            $rr = $newStatus === 'Rejected' ? $rejectReason : null;
            $stmt->bind_param('ssi', $newStatus, $rr, $appId);
            $stmt->execute();
            $stmt->close();
            $flash = t("Application status updated to") . " $newStatus.";
        }
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

// Applications to this faction, with the applicant's current username (leader/admin only see these)
$applications = [];
if ($isLeader || $isAdmin) {
    $stmt = $mysqli->prepare(
        "SELECT a.*, p.username FROM `ucp_factapplications` a
         LEFT JOIN `players` p ON p.id = a.playerId
         WHERE a.factionsId = ? ORDER BY FIELD(a.status,'Open','Review','Accepted','Rejected'), a.data_aplicarii DESC"
    );
    $stmt->bind_param('i', $factionId);
    $stmt->execute();
    $applications = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
}

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
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — <?= ucp_escape($factionName) ?></title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
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
      <h2>🏛️ <?= t('Faction info') ?></h2>
      <table>
        <tr><th><?= t('Name') ?></th><td><?= ucp_escape($faction['name'] ?: $factionName) ?></td></tr>
        <tr><th><?= t('Leader') ?></th><td><?= $faction['lead'] ? ucp_escape($faction['lead']) : '—' ?></td></tr>
        <tr><th><?= t('Members') ?></th><td><?= count($members) ?></td></tr>
        <tr><th><?= t('Bank') ?></th><td>$<?= ucp_money($faction['bank']) ?></td></tr>
      </table>

      <?php if ($isAdmin): ?>
        <?php if ($faction['lead']): ?>
        <form method="post" style="margin-top:14px" onsubmit="return confirm('<?= t('Remove the faction leader? They will become a civilian.') ?>');">
          <?= ucp_csrf_field() ?>
          <input type="hidden" name="action" value="remove_lead">
          <button type="submit" class="btn danger"><?= t('Remove leader') ?></button>
        </form>
        <?php endif; ?>

        <form method="post" class="bank-form">
          <?= ucp_csrf_field() ?>
          <input type="hidden" name="action" value="set_bank">
          <label for="bank-amount" style="color:var(--muted); font-size:0.85rem"><?= t('Set bank:') ?></label>
          <input id="bank-amount" type="number" name="amount" min="0" value="<?= (int)$faction['bank'] ?>">
          <button type="submit" class="btn"><?= t('Save') ?></button>
        </form>
      <?php endif; ?>
    </div>

    <?php if ($isMafia): ?>
    <div class="card">
      <h2>🔒 <?= t('Stash') ?></h2>
      <table>
        <tr>
          <th><?= t('Herbs') ?></th>
          <td>
            <?= (int)$faction['seif_herbs'] ?>g / 10000g
            <span class="meter"><span class="meter-fill good" style="width:<?= min(100, (int)$faction['seif_herbs'] / 100) ?>%"></span></span>
          </td>
        </tr>
        <tr>
          <th><?= t('Drugs') ?></th>
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
    <h2>👥 <?= t('Members') ?> (<?= count($members) ?> / <?= (int)$faction['max_members'] ?>)</h2>
    <?php if (!$members): ?>
      <p style="color:var(--muted)"><?= t('No members in this faction.') ?></p>
    <?php else: ?>
      <div style="overflow-x:auto">
      <table>
        <tr><th><?= t('ID') ?></th><th><?= t('Username') ?></th><th><?= t('Level') ?></th><th><?= t('Rank') ?></th><th></th></tr>
        <?php foreach ($members as $m): $mrank = (int)$m['faction_rank']; ?>
        <tr>
          <td>#<?= (int)$m['id'] ?></td>
          <td><?= ucp_escape($m['username']) ?></td>
          <td><?= (int)$m['level'] ?></td>
          <td>
            <?php if ($mrank >= 5): ?>
              <span class="pill pill-lvl"><?= t('Leader') ?></span>
            <?php else: ?>
              <?= t('Rank') ?> <?= $mrank ?>
            <?php endif; ?>
          </td>
          <td>
            <?php if ($mrank < 5): ?>
            <div class="row-actions">
              <form method="post" style="display:flex; gap:6px; align-items:center">
                <?= ucp_csrf_field() ?>
                <input type="hidden" name="action" value="setrank">
                <input type="hidden" name="player_id" value="<?= (int)$m['id'] ?>">
                <select name="new_rank">
                  <?php for ($r = 1; $r <= 4; $r++): ?>
                    <option value="<?= $r ?>" <?= $mrank === $r ? 'selected' : '' ?>>Rank <?= $r ?></option>
                  <?php endfor; ?>
                </select>
                <button type="submit"><?= t('Set') ?></button>
              </form>
              <form method="post" onsubmit="return confirm('<?= t('Remove') ?> <?= ucp_escape(addslashes($m['username'])) ?> <?= t('from the faction?') ?>');">
                <?= ucp_csrf_field() ?>
                <input type="hidden" name="action" value="kick">
                <input type="hidden" name="player_id" value="<?= (int)$m['id'] ?>">
                <button type="submit" class="danger"><?= t('Kick') ?></button>
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

  <?php if ($isLeader || $isAdmin): ?>
  <div class="card">
    <h2>📝 <?= t('Applications') ?> (<?= count($applications) ?>)</h2>
    <?php if (!$applications): ?>
      <p style="color:var(--muted)"><?= t('No applications for this faction.') ?></p>
    <?php else: ?>
      <div style="overflow-x:auto">
      <table>
        <tr><th><?= t('Applicant') ?></th><th><?= t('Applied on') ?></th><th><?= t('Current faction') ?></th><th><?= t('Reason') ?></th><th><?= t('Status') ?></th><th></th></tr>
        <?php foreach ($applications as $a): ?>
        <tr>
          <td><?= $a['username'] ? ucp_escape($a['username']) : '#' . (int)$a['playerId'] ?></td>
          <td><?= ucp_escape(date('Y-m-d H:i', strtotime($a['data_aplicarii']))) ?></td>
          <td><?= $a['lastFaction'] ? ucp_escape(ucp_faction_name($a['lastFaction'])) : t('Civil') ?></td>
          <td style="max-width:260px; white-space:pre-wrap"><?= ucp_escape($a['motiv']) ?><?php if ($a['status'] === 'Rejected' && $a['reject_reason']): ?>
              <br><span style="color:var(--red); font-size:0.82rem"><?= t('Rejected:') ?> <?= ucp_escape($a['reject_reason']) ?></span>
            <?php endif; ?></td>
          <td>
            <span class="pill <?= $a['status'] === 'Accepted' ? 'pill-ok' : ($a['status'] === 'Rejected' ? 'pill-bad' : 'pill-lvl') ?>"><?= ucp_escape(t($a['status'])) ?></span>
          </td>
          <td>
            <?php if ($a['status'] === 'Open' || $a['status'] === 'Review'): ?>
            <div class="row-actions">
              <?php if ($a['status'] === 'Open'): ?>
              <form method="post">
                <?= ucp_csrf_field() ?>
                <input type="hidden" name="action" value="app_status">
                <input type="hidden" name="app_id" value="<?= (int)$a['id'] ?>">
                <input type="hidden" name="new_status" value="Review">
                <button type="submit"><?= t('Mark reviewing') ?></button>
              </form>
              <?php endif; ?>
              <form method="post" onsubmit="return confirm('<?= t('Accept this application and add') ?> <?= ucp_escape(addslashes($a['username'] ?? ('#' . $a['playerId']))) ?> <?= t('to the faction?') ?>');">
                <?= ucp_csrf_field() ?>
                <input type="hidden" name="action" value="app_status">
                <input type="hidden" name="app_id" value="<?= (int)$a['id'] ?>">
                <input type="hidden" name="new_status" value="Accepted">
                <button type="submit"><?= t('Accept') ?></button>
              </form>
              <form method="post" onsubmit="var r=prompt('<?= t('Reason for rejecting this application:') ?>'); if(!r){return false;} this.reject_reason.value=r; return true;">
                <?= ucp_csrf_field() ?>
                <input type="hidden" name="action" value="app_status">
                <input type="hidden" name="app_id" value="<?= (int)$a['id'] ?>">
                <input type="hidden" name="new_status" value="Rejected">
                <input type="hidden" name="reject_reason" value="">
                <button type="submit" class="danger"><?= t('Reject') ?></button>
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
  <?php endif; ?>

  <div class="card">
    <h2>🚗 <?= t('Faction vehicles') ?> (<?= count($vehicles) ?>)</h2>

    <form method="post" style="margin-bottom:14px" onsubmit="return confirm('<?= t('Refill all faction vehicles to full fuel?') ?>');">
      <?= ucp_csrf_field() ?>
      <input type="hidden" name="action" value="refill">
      <button type="submit" class="btn">⛽ <?= t('Refill all vehicles') ?></button>
    </form>

    <?php if (!$vehicles): ?>
      <p style="color:var(--muted)"><?= t('No vehicles registered to this faction.') ?></p>
    <?php else: ?>
      <table>
        <tr><th><?= t('ID') ?></th><th><?= t('Model ID') ?></th><th><?= t('Model name') ?></th><th><?= t('Fuel') ?></th></tr>
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

<?php include __DIR__ . '/footer.php'; ?>

</body>
</html>
