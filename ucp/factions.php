<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

// Live member counts (see `factions`.`members`, synced from `players` whenever someone joins/leaves)
$memberCounts = [];
$maxMembers = [];
$applicationsOn = [];
$rows = $mysqli->query("SELECT `id`, `members`, `max_members`, `application_on` FROM `factions`")->fetch_all(MYSQLI_ASSOC);
foreach ($rows as $r) {
    $memberCounts[(int)$r['id']]   = (int)$r['members'];
    $maxMembers[(int)$r['id']]     = (int)$r['max_members'];
    $applicationsOn[(int)$r['id']] = (int)$r['application_on'] === 1;
}

$myFaction = ucp_current_faction();

// Short descriptions distilled from the actual /howto faction text in bare.pwn
$factionDescriptions = [
    1 => 'Law enforcement. On-duty officers set wanted levels, arrest suspects, check licenses and insurance, install speed radars, and confiscate expired documents.',
    2 => 'Vehicle registry & inspections. Renew ITP, plates and insurance for drivers, issue fines, and impound vehicles whose ITP has expired (towed until the owner pays to redeem it).',
    3 => 'Emergency medical & fire service. Heal players in the ambulance, cure the sick at the hospital, and put out fires anywhere on the map with the Firetruck.',
    4 => 'Organized crime family. Runs drugs (transport & craft weed), smuggles contraband by boat, fights other mafias over territory, and stocks weapons at the HQ.',
    5 => 'Organized crime family. Runs drugs (transport & craft weed), smuggles contraband by boat, fights other mafias over territory, and stocks weapons at the HQ.',
    6 => 'Organized crime family. Runs drugs (transport & craft weed), smuggles contraband by boat, fights other mafias over territory, and stocks weapons at the HQ.',
    7 => 'Organized crime family. Runs drugs (transport & craft weed), smuggles contraband by boat, fights other mafias over territory, and stocks weapons at the HQ.',
    8 => 'The press. Broadcasts live news headlines, hosts live Q&A interviews, and publishes a newspaper with player-written stories.',
];
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Factions</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .faction-card h2 { margin: 0 0 6px; font-size: 1.2rem; }
  .faction-card .fmembers { color: var(--muted); font-size: 0.82rem; margin: 0 0 10px; }
  .faction-card p.fdesc { margin: 0 0 12px; color: var(--text); font-size: 0.92rem; line-height: 1.55; }
  .faction-card .btn-apply {
    display: inline-block; background: var(--accent); color: #0f1115; font-weight: 600;
    font-size: 0.82rem; padding: 6px 14px; border-radius: 6px;
  }
  .faction-card .btn-apply:hover { opacity: 0.9; text-decoration: none; }
</style>
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <h1>🏛️ Factions</h1>
  <p style="color:var(--muted); margin:-10px 0 20px">What each faction on the server does.</p>

  <div class="grid-3">
    <?php for ($fid = 1; $fid <= 8; $fid++): ?>
    <div class="card faction-card">
      <h2 style="color:<?= ucp_faction_color($fid) ?>"><?= ucp_escape(ucp_faction_name($fid)) ?></h2>
      <p class="fmembers"><?= $memberCounts[$fid] ?? 0 ?> / <?= $maxMembers[$fid] ?? 6 ?> member<?= ($memberCounts[$fid] ?? 0) === 1 ? '' : 's' ?></p>
      <p class="fdesc"><?= ucp_escape($factionDescriptions[$fid]) ?></p>
      <?php if (!empty($applicationsOn[$fid]) && $myFaction !== $fid): ?>
        <a class="btn-apply" href="apply_faction.php?faction=<?= $fid ?>">Apply to join</a>
      <?php endif; ?>
    </div>
    <?php endfor; ?>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
