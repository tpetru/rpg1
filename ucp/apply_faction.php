<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

$factionId = (int)($_GET['faction'] ?? $_POST['faction'] ?? 0);

$stmt = $mysqli->prepare("SELECT `id`, `name`, `application_on` FROM `factions` WHERE `id` = ? LIMIT 1");
$stmt->bind_param('i', $factionId);
$stmt->execute();
$faction = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$faction || (int)$faction['application_on'] !== 1) {
    header('Location: factions.php');
    exit;
}

$playerId = ucp_current_player_id();
$error = '';
$success = false;

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $motiv = trim($_POST['motiv'] ?? '');
    $lastFaction = (int)($_POST['last_faction'] ?? 0);

    if ($factionId === ucp_current_faction()) {
        $error = "You're already a member of this faction.";
    } elseif ($motiv === '' || mb_strlen($motiv) < 10) {
        $error = 'Please write a longer reason for your application (at least 10 characters).';
    } else {
        $stmt = $mysqli->prepare("SELECT `id` FROM `ucp_FactApplications` WHERE `playerId` = ? AND `factionsId` = ? AND `status` IN ('Open','Review') LIMIT 1");
        $stmt->bind_param('ii', $playerId, $factionId);
        $stmt->execute();
        $existing = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($existing) {
            $error = 'You already have a pending application for this faction.';
        } else {
            $stmt = $mysqli->prepare("INSERT INTO `ucp_FactApplications` (`playerId`, `factionsId`, `data_aplicarii`, `status`, `motiv`, `lastFaction`) VALUES (?, ?, NOW(), 'Open', ?, ?)");
            $stmt->bind_param('iisi', $playerId, $factionId, $motiv, $lastFaction);
            $stmt->execute();
            $stmt->close();
            $success = true;
        }
    }
}

$factionName = ucp_faction_name($factionId);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Apply to <?= ucp_escape($factionName) ?></title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .apply-form label { display: block; font-size: 0.85rem; color: var(--muted); margin: 14px 0 4px; }
  .apply-form input, .apply-form select, .apply-form textarea {
    width: 100%; padding: 9px 12px;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 0.95rem; font-family: inherit;
  }
  .apply-form textarea { resize: vertical; min-height: 110px; }
  .apply-form button {
    margin-top: 18px; padding: 10px 20px;
    background: var(--accent); border: none; border-radius: 8px;
    color: #0f1115; font-weight: 700; font-size: 0.95rem; cursor: pointer;
  }
  .apply-form button:hover { opacity: 0.9; }
  .error-box, .success-box {
    padding: 10px 14px; border-radius: 8px; font-size: 0.88rem; margin-bottom: 14px;
  }
  .error-box { background: rgba(255,93,93,0.1); border: 1px solid var(--red); color: var(--red); }
  .success-box { background: rgba(62,207,142,0.1); border: 1px solid var(--green); color: var(--green); }
  .btn { display: inline-block; background: var(--accent); border: none; border-radius: 6px; color: #0f1115; font-weight: 600; font-size: 0.85rem; padding: 7px 14px; }
  .btn:hover { opacity: 0.9; text-decoration: none; }
</style>
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main style="max-width:600px">
  <h1>Apply to join <span style="color:<?= ucp_faction_color($factionId) ?>"><?= ucp_escape($factionName) ?></span></h1>

  <div class="card">
    <?php if ($success): ?>
      <div class="success-box">Your application has been submitted. The faction leader will review it soon.</div>
      <a href="factions.php" class="btn">&larr; Back to Factions</a>
    <?php else: ?>
      <?php if ($error): ?>
        <div class="error-box"><?= ucp_escape($error) ?></div>
      <?php endif; ?>

      <form method="post" class="apply-form">
        <input type="hidden" name="faction" value="<?= $factionId ?>">

        <label for="last_faction">Current faction</label>
        <select id="last_faction" name="last_faction">
          <option value="0">Civil</option>
          <?php for ($fi = 1; $fi <= 8; $fi++): ?>
            <option value="<?= $fi ?>"><?= ucp_escape(ucp_faction_name($fi)) ?></option>
          <?php endfor; ?>
        </select>

        <label for="motiv">Why do you want to join <?= ucp_escape($factionName) ?>?</label>
        <textarea id="motiv" name="motiv" required minlength="10" placeholder="Tell us about your experience and why you'd be a good fit..."><?= ucp_escape($_POST['motiv'] ?? '') ?></textarea>

        <button type="submit">Submit application</button>
      </form>
    <?php endif; ?>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
