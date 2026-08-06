<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();

// Weapon ID 0-46 reference (see https://sampwiki.blast.hk/wiki/Weapons and https://open.mp/docs/scripting/resources/weaponids).
// Status mirrors Weapon_IsIllegal() in bare.pwn: those weapons get your Weapon W license confiscated on /inspectplayer.
// Anything not a real carryable weapon (unused slot, or ID 44/45 which have no WEAPON_ constant) is "Unknown".
$illegalWeaponIds = [16, 17, 18, 26, 27, 28, 32, 34, 35, 36, 37, 38, 39, 40]; // WEAPON_GRENADE, TEARGAS, MOLTOV, SAWEDOFF, SHOTGSPA, UZI, TEC9, SNIPER, ROCKETLAUNCHER, HEATSEEKER, FLAMETHROWER, MINIGUN, SATCHEL, BOMB

$weapons = [
    ['id' => 0,  'def' => '-',                        'name' => 'Fist',               'icon' => 'fist.png'],
    ['id' => 1,  'def' => 'WEAPON_BRASSKNUCKLE',       'name' => 'Brass Knuckles',     'icon' => 'brassKnuckles.png'],
    ['id' => 2,  'def' => 'WEAPON_GOLFCLUB',           'name' => 'Golf Club',          'icon' => 'golfClub.png'],
    ['id' => 3,  'def' => 'WEAPON_NITESTICK',          'name' => 'Nightstick',         'icon' => 'nightStick.png'],
    ['id' => 4,  'def' => 'WEAPON_KNIFE',              'name' => 'Knife',              'icon' => 'knife.png'],
    ['id' => 5,  'def' => 'WEAPON_BAT',                'name' => 'Baseball Bat',       'icon' => 'baseballBat.png'],
    ['id' => 6,  'def' => 'WEAPON_SHOVEL',             'name' => 'Shovel',             'icon' => 'shovel.png'],
    ['id' => 7,  'def' => 'WEAPON_POOLSTICK',          'name' => 'Pool Cue',           'icon' => 'poolCue.png'],
    ['id' => 8,  'def' => 'WEAPON_KATANA',             'name' => 'Katana',             'icon' => 'katana.png'],
    ['id' => 9,  'def' => 'WEAPON_CHAINSAW',           'name' => 'Chainsaw',           'icon' => 'chainsaw.png'],
    ['id' => 10, 'def' => 'WEAPON_DILDO',              'name' => 'Purple Dildo',       'icon' => 'purpleDildo.png'],
    ['id' => 11, 'def' => 'WEAPON_DILDO2',             'name' => 'Dildo',              'icon' => 'dildo.png'],
    ['id' => 12, 'def' => 'WEAPON_VIBRATOR',           'name' => 'Vibrator',           'icon' => 'vibrator.png'],
    ['id' => 13, 'def' => 'WEAPON_VIBRATOR2',          'name' => 'Silver Vibrator',    'icon' => 'silverVibrator.png'],
    ['id' => 14, 'def' => 'WEAPON_FLOWER',             'name' => 'Flowers',            'icon' => 'flowers.png'],
    ['id' => 15, 'def' => 'WEAPON_CANE',               'name' => 'Cane',               'icon' => 'cane.png'],
    ['id' => 16, 'def' => 'WEAPON_GRENADE',            'name' => 'Grenade',            'icon' => 'grenade.png'],
    ['id' => 17, 'def' => 'WEAPON_TEARGAS',            'name' => 'Tear Gas',           'icon' => 'tearGas.png'],
    ['id' => 18, 'def' => 'WEAPON_MOLTOV',             'name' => 'Molotov Cocktail',   'icon' => 'molotovCocktail.png'],
    ['id' => 19, 'def' => '-',                         'name' => 'Unused',             'icon' => null],
    ['id' => 20, 'def' => '-',                         'name' => 'Unused',             'icon' => null],
    ['id' => 21, 'def' => '-',                         'name' => 'Unused',             'icon' => null],
    ['id' => 22, 'def' => 'WEAPON_COLT45',             'name' => '9mm',                'icon' => '9mm.png'],
    ['id' => 23, 'def' => 'WEAPON_SILENCED',           'name' => 'Silenced 9mm',       'icon' => 'silenced9mm.png'],
    ['id' => 24, 'def' => 'WEAPON_DEAGLE',             'name' => 'Desert Eagle',       'icon' => 'desertEagle.png'],
    ['id' => 25, 'def' => 'WEAPON_SHOTGUN',            'name' => 'Shotgun',            'icon' => 'shotgun.png'],
    ['id' => 26, 'def' => 'WEAPON_SAWEDOFF',           'name' => 'Sawnoff Shotgun',    'icon' => 'sawnoffShotgun.png'],
    ['id' => 27, 'def' => 'WEAPON_SHOTGSPA',           'name' => 'Combat Shotgun',     'icon' => 'combatShotgun.png'],
    ['id' => 28, 'def' => 'WEAPON_UZI',                'name' => 'Micro SMG / Uzi',    'icon' => 'microSMG-Uzi.png'],
    ['id' => 29, 'def' => 'WEAPON_MP5',                'name' => 'MP5',                'icon' => 'mp5.png'],
    ['id' => 30, 'def' => 'WEAPON_AK47',               'name' => 'AK-47',              'icon' => 'ak47.png'],
    ['id' => 31, 'def' => 'WEAPON_M4',                 'name' => 'M4',                 'icon' => 'm4.png'],
    ['id' => 32, 'def' => 'WEAPON_TEC9',               'name' => 'Tec-9',              'icon' => 'tec9.png'],
    ['id' => 33, 'def' => 'WEAPON_RIFLE',              'name' => 'Country Rifle',      'icon' => 'countryRifle.png'],
    ['id' => 34, 'def' => 'WEAPON_SNIPER',             'name' => 'Sniper Rifle',       'icon' => 'sniperRifle.png'],
    ['id' => 35, 'def' => 'WEAPON_ROCKETLAUNCHER',     'name' => 'RPG',                'icon' => 'rpg.png'],
    ['id' => 36, 'def' => 'WEAPON_HEATSEEKER',         'name' => 'HS Rocket',          'icon' => 'hsRocket.png'],
    ['id' => 37, 'def' => 'WEAPON_FLAMETHROWER',       'name' => 'Flamethrower',       'icon' => 'flame-Thrower.png'],
    ['id' => 38, 'def' => 'WEAPON_MINIGUN',            'name' => 'Minigun',            'icon' => 'minigun.png'],
    ['id' => 39, 'def' => 'WEAPON_SATCHEL',            'name' => 'Satchel Charge',     'icon' => 'satchelCharge.png'],
    ['id' => 40, 'def' => 'WEAPON_BOMB',               'name' => 'Detonator',          'icon' => 'detonator.png'],
    ['id' => 41, 'def' => 'WEAPON_SPRAYCAN',           'name' => 'Spraycan',           'icon' => 'spraycan.png'],
    ['id' => 42, 'def' => 'WEAPON_FIREEXTINGUISHER',   'name' => 'Fire Extinguisher',  'icon' => 'fireExtinguisher.png'],
    ['id' => 43, 'def' => 'WEAPON_CAMERA',             'name' => 'Camera',             'icon' => 'camera.png'],
    ['id' => 44, 'def' => '-',                         'name' => 'Night Vision Goggles','icon' => 'nightVisGoggles.png'],
    ['id' => 45, 'def' => '-',                         'name' => 'Thermal Goggles',    'icon' => 'thermalGoggles.png'],
    ['id' => 46, 'def' => 'WEAPON_PARACHUTE',          'name' => 'Parachute',          'icon' => 'parachute.png'],
];

foreach ($weapons as &$w) {
    if (in_array($w['id'], $illegalWeaponIds, true)) {
        $w['status'] = 'Illegal';
    } elseif ($w['icon'] === null) {
        $w['status'] = 'Unknown';
    } else {
        $w['status'] = 'Legal';
    }
}
unset($w);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — Weapons</title>
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .wicon-box { width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; }
  .wicon-box img { max-width: 100%; max-height: 100%; }
</style>
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <h1>🔫 Weapons</h1>
  <p style="color:var(--muted)">Status reflects the in-game rules: carrying an "Illegal" weapon gets your Weapon W license confiscated if a police officer searches you with <code>/inspectplayer</code>.</p>

  <div class="card">
    <div style="overflow-x:auto">
    <table>
      <tr><th>ID</th><th>Hud Icon</th><th>Definition</th><th>Name</th><th>Status</th></tr>
      <?php foreach ($weapons as $w): ?>
      <tr>
        <td>#<?= (int)$w['id'] ?></td>
        <td>
          <?php if ($w['icon']): ?>
            <div class="wicon-box"><img src="https://assets.open.mp/assets/images/weaponIcons/<?= $w['icon'] ?>" alt="<?= ucp_escape($w['name']) ?>"></div>
          <?php else: ?>
            <span style="color:var(--muted)">—</span>
          <?php endif; ?>
        </td>
        <td><code><?= ucp_escape($w['def']) ?></code></td>
        <td><?= ucp_escape($w['name']) ?></td>
        <td>
          <?php if ($w['status'] === 'Illegal'): ?>
            <span class="pill pill-bad">Illegal</span>
          <?php elseif ($w['status'] === 'Legal'): ?>
            <span class="pill pill-ok">Legal</span>
          <?php else: ?>
            <span class="pill pill-lvl">Unknown</span>
          <?php endif; ?>
        </td>
      </tr>
      <?php endforeach; ?>
    </table>
    </div>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
