<?php
require_once __DIR__ . '/../../includes/admin_common.php';
ucp_require_admin();
if (ucp_current_admin_level() < 2) {
    header('Location: ' . UCP_BASE . '/dashboard.php');
    exit;
}

$flash = null;
$flashErr = false;

// Fetches the current temperature in Romania (Bucharest) from Open-Meteo - free, no API key required.
function ucp_fetch_romania_temperature() {
    $url = 'https://api.open-meteo.com/v1/forecast?latitude=44.4268&longitude=26.1025&current_weather=true';
    $json = false;
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 8,
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $json = curl_exec($ch);
        curl_close($ch);
    } else {
        $ctx  = stream_context_create(['http' => ['timeout' => 8]]);
        $json = @file_get_contents($url, false, $ctx);
    }
    if (!$json) return null;

    $data = json_decode($json, true);
    if (!isset($data['current_weather']['temperature'])) return null;
    return (float)$data['current_weather']['temperature'];
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    if (!ucp_csrf_verify()) {
        $flash = "Security check failed (invalid or expired form). Please try again.";
        $flashErr = true;
    } else {
        $temp = ucp_fetch_romania_temperature();
        if ($temp === null) {
            $flash = "Could not reach the weather service. Try again later.";
            $flashErr = true;
        } else {
            $val = (string)(int)round($temp);
            $stmt = $mysqli->prepare("INSERT INTO `server_setup` (`ssSetare`,`ssValue`) VALUES ('temperature', ?) ON DUPLICATE KEY UPDATE `ssValue`=?");
            $stmt->bind_param('ss', $val, $val);
            $stmt->execute();
            $stmt->close();
            $flash = "Temperature updated to {$val}\xC2\xB0C (live reading for Bucharest, Romania). The game server picks this up at the next PayDay.";
        }
    }
}

$row = $mysqli->query("SELECT `ssValue` FROM `server_setup` WHERE `ssSetare`='temperature' LIMIT 1")->fetch_assoc();
$currentTemp = $row ? (int)$row['ssValue'] : null;
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Temperature</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="<?= UCP_BASE ?>/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../../includes/header.php'; ?>

<main>
  <h1>🌡️ City Temperature</h1>
  <p style="color:var(--muted)">The city's current temperature, shown to players in-game. Pulled live from Open-Meteo (Bucharest, Romania) and stored in <code>server_setup</code>.</p>

  <?php if ($flash): ?>
    <div class="flash <?= $flashErr ? 'err' : 'ok' ?>"><?= ucp_escape($flash) ?></div>
  <?php endif; ?>

  <div class="card">
    <p style="font-size:2rem; margin:0 0 16px">
      <?= $currentTemp !== null ? ucp_escape((string)$currentTemp) . '°C' : 'Not set' ?>
    </p>
    <form method="post">
      <?= ucp_csrf_field() ?>
      <button type="submit" class="save-btn">Update Temperature</button>
    </form>
  </div>
</main>

<?php include __DIR__ . '/../../includes/footer.php'; ?>

</body>
</html>
