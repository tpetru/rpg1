<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_admin_require_level5();

$flash = null;
$flashErr = false;

// Every price/economy setting is one row in `server_setup` (ssSetare/ssValue) - see Server_Setup_Seed / OnPayDayLoaded in the gamemode
$priceFields = [
    'min_salary'         => ['Minimum salary', '$'],
    'tax'                => ['Tax', '%'],
    'cass'               => ['CASS', '%'],
    'bank_interest'      => ['Bank interest', '%', true],
    'insurance_price'    => ['Insurance price', '$'],
    'medkit_price'       => ['Medkit price', '$'],
    'extinguisher_price' => ['Extinguisher price', '$'],
    'itp_price'          => ['ITP (inspection) price', '$'],
    'plate_price'        => ['License plate price', '$'],
    'rent_bike_price'    => ['Bike rental price', '$'],
    'exam_a_price'       => ['Exam A (motorcycle) price', '$'],
    'exam_b_price'       => ['Exam B (car) price', '$'],
    'exam_c_price'       => ['Exam C (truck) price', '$'],
    'exam_d_price'       => ['Exam D (bus) price', '$'],
    'exam_p_price'       => ['Exam P (plane) price', '$'],
    'exam_h_price'       => ['Exam H (helicopter) price', '$'],
    'pizza_price'        => ['Pizza price', '$'],
    'burger_price'       => ['Burger price', '$'],
    'meal_price'         => ['Meal price', '$'],
    'desert_price'       => ['Desert price', '$'],
    'gascan_price'       => ['Gas can price', '$'],
    'farm_tractor_price' => ['Farm tractor price', '$'],
    'farm_dozer_price'   => ['Farm bulldozer price', '$'],
    'farm_combine_price' => ['Farm combine price', '$'],
    'farm_truck_price'   => ['Farm truck price', '$'],
    'farm_trailer_price' => ['Farm trailer price', '$'],
    'shovel_price'       => ['Shovel price', '$'],
    'phone_sim_price'    => ['SIM card price', '$'],
    'phone_price_1'      => ['Phone price - Samsung A70', '$'],
    'phone_price_2'      => ['Phone price - Samsung S27', '$'],
    'phone_price_3'      => ['Phone price - iPhone 16', '$'],
    'phone_price_4'      => ['Phone price - iPhone 17', '$'],
    'phone_price_5'      => ['Phone price - Motorola 67', '$'],
    'watch_price_1'      => ['Watch price - Xiaomi Watch', '$'],
    'watch_price_2'      => ['Watch price - Galaxy Watch', '$'],
    'watch_price_3'      => ['Watch price - Apple Watch', '$'],
    'watch_price_4'      => ['Watch price - Rolex Watch', '$'],
];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    $stmt = $mysqli->prepare("UPDATE `server_setup` SET `ssValue`=? WHERE `ssSetare`=?");
    foreach ($priceFields as $key => $info) {
        $isFloat = $info[2] ?? false;
        $raw = $_POST[$key] ?? 0;
        $val = (string)($isFloat ? max(0, (float)$raw) : max(0, (int)$raw));
        $stmt->bind_param('ss', $val, $key);
        $stmt->execute();
    }
    $stmt->close();
    $flash = "Prices updated.";
}

$prices = [];
$rows = $mysqli->query("SELECT `ssSetare`, `ssValue` FROM `server_setup`")->fetch_all(MYSQLI_ASSOC);
foreach ($rows as $r) { $prices[$r['ssSetare']] = $r['ssValue']; }
$adminActive = 'prices';
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Prices</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>

<main>
  <h1>💲 Prices</h1>
  <p style="color:var(--muted)">Server-wide economy settings (server_setup). Changes are saved immediately to the database.</p>

  <?php include __DIR__ . '/../../includes/admin_nav.php'; ?>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <form method="post">
      <table class="edittable">
        <tr><th>Setting</th><th>Value</th></tr>
        <?php foreach ($priceFields as $col => $info): [$label, $unit] = $info; $isFloat = $info[2] ?? false; ?>
        <tr>
          <td><?= ucp_escape($label) ?> (<?= $unit ?>)</td>
          <td style="max-width:160px">
            <input type="number" name="<?= $col ?>" min="0" <?= $isFloat ? 'step="0.01"' : '' ?> value="<?= $isFloat ? (float)$prices[$col] : (int)$prices[$col] ?>">
          </td>
        </tr>
        <?php endforeach; ?>
      </table>
      <button type="submit" class="save-btn" style="margin-top:12px">Save all</button>
    </form>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
