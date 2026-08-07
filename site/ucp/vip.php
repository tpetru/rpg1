<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
ucp_require_login();

$pid = ucp_current_player_id();
$stmt = $mysqli->prepare("SELECT `vip` FROM `players` WHERE `id` = ? LIMIT 1");
$stmt->bind_param('i', $pid);
$stmt->execute();
$isVip = (bool)($stmt->get_result()->fetch_assoc()['vip'] ?? 0);
$stmt->close();

$benefits = [
    ['💰', '+10% salary at PayDay',       'Every PayDay, VIP members earn a 10% bonus on top of their regular salary.'],
    ['🏦', '+0.01% bank interest',        'VIP bank balances earn extra interest on top of the server\'s normal rate at every PayDay.'],
    ['🎯', '+10% heist earnings',         'Cash rewards from store heists (/rob) are boosted by 10% for VIP members.'],
    ['⭐', 'Double RP or rob points',      'At every PayDay you get double RP on even hours, or double rob points on odd hours.'],
    ['⛽', 'Bigger gas can (50L)',         'The gas can holds 50 liters for VIP members, instead of the standard 20 liters.'],
    ['🏧', 'Bank from anywhere',          '/mybank works from anywhere for VIP members - no need to be near a bank or ATM.'],
    ['💬', 'VIP chat & gold tag',         'Use /vipc to talk to every VIP member online regardless of distance, and stand out with a gold [VIP] tag in local chat.'],
    ['🚘', 'Special plate color',          'VIP-owned vehicles are shown with a distinct red license plate.'],
    ['📄', '+3 days on licenses',          'Any license or permit earned at an exam (A, B, C, D, A, H, W) is valid 3 extra days for VIP members.'],
    ['🎩', 'Exclusive VIP hats',          'Use /viphat [black/red/green/farmer/witch/off] to wear an exclusive hat only VIP members can put on.'],
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — VIP</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .vip-hero { text-align: center; padding: 36px 20px; }
  .vip-hero h1 { font-size: 2rem; margin: 0 0 8px; color: #FFD700; text-shadow: 0 0 18px rgba(255,215,0,0.35); }
  .vip-hero p { color: var(--muted); font-size: 1rem; margin: 0; }
  .vip-status { display: inline-block; margin-top: 16px; padding: 8px 18px; border-radius: 999px; font-weight: 700; font-size: 0.88rem; }
  .vip-status.on  { background: rgba(255,215,0,0.15); color: #FFD700; border: 1px solid #FFD700; }
  .vip-status.off { background: var(--panel-2); color: var(--muted); border: 1px solid var(--border); }
  .vip-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-top: 10px; }
  .vip-card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }
  .vip-card .vicon { font-size: 1.8rem; margin-bottom: 10px; }
  .vip-card h2 { font-size: 1.02rem; margin: 0 0 8px; color: #FFD700; }
  .vip-card p { margin: 0; color: var(--text); font-size: 0.9rem; line-height: 1.5; }
  .vip-howto { text-align: center; margin-top: 26px; color: var(--muted); font-size: 0.9rem; }
</style>
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <div class="vip-hero">
    <h1>⭐ VIP Membership</h1>
    <p>Support the server and unlock exclusive perks across the whole RPG experience.</p>
    <?php if ($isVip): ?>
      <div class="vip-status on">✅ You are a VIP member</div>
    <?php else: ?>
      <div class="vip-status off">You are not a VIP member yet</div>
    <?php endif; ?>
  </div>

  <div class="vip-grid">
    <?php foreach ($benefits as [$icon, $title, $desc]): ?>
    <div class="vip-card">
      <div class="vicon"><?= $icon ?></div>
      <h2><?= ucp_escape($title) ?></h2>
      <p><?= ucp_escape($desc) ?></p>
    </div>
    <?php endforeach; ?>
  </div>

  <p class="vip-howto">VIP status is granted by the server administration. Contact an admin in-game if you'd like to become a VIP member.</p>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
