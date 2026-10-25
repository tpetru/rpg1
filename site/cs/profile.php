<?php
// Player profile lookup backed by the Leetify public API (https://api-public.cs-prod.leetify.com).
// Per Leetify's API guidelines: data is fetched live on every request (never stored locally),
// metric names/values are shown as returned (not renamed or rescaled), and the page credits
// Leetify with an attribution + "View on Leetify" link back to the player's profile.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';

site_theme_init($mysqli);

const CS_LEETIFY_DEFAULT_STEAM_ID = '76561198245213068';
const CS_LEETIFY_API_URL = 'https://api-public.cs-prod.leetify.com/v3/profile';

function cs_leetify_fetch_profile(string $steamId): array
{
    $url = CS_LEETIFY_API_URL . '?' . http_build_query(['steam64_id' => $steamId]);

    if (extension_loaded('curl')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
        ]);
        $body = curl_exec($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlErr = curl_error($ch);
        curl_close($ch);
        if ($body === false) {
            return ['ok' => false, 'error' => 'network', 'detail' => $curlErr];
        }
    } else {
        $context = stream_context_create(['http' => [
            'method' => 'GET',
            'header' => "Accept: application/json\r\n",
            'timeout' => 10,
            'ignore_errors' => true,
        ]]);
        $body = @file_get_contents($url, false, $context);
        $status = 0;
        if (isset($http_response_header)) {
            foreach ($http_response_header as $header) {
                if (preg_match('#^HTTP/\S+\s+(\d+)#', $header, $m)) $status = (int)$m[1];
            }
        }
        if ($body === false) {
            return ['ok' => false, 'error' => 'network', 'detail' => 'file_get_contents failed'];
        }
    }

    if ($status === 404) {
        return ['ok' => false, 'error' => 'not_found'];
    }
    if ($status !== 200) {
        return ['ok' => false, 'error' => 'http_' . $status];
    }

    $data = json_decode($body, true);
    if (!is_array($data)) {
        return ['ok' => false, 'error' => 'bad_json'];
    }

    return ['ok' => true, 'data' => $data];
}

$csLeetifyErrorMessages = [
    'not_found'   => 'Nu am găsit un profil Leetify pentru acest Steam ID (jucătorul trebuie să fie utilizator Leetify).',
    'network'     => 'Nu am putut contacta API-ul Leetify (eroare de rețea pe server).',
    'bad_json'    => 'Răspunsul primit de la Leetify nu a putut fi interpretat.',
    'bad_steamid' => 'Steam ID invalid. Trebuie să conțină exact 17 cifre.',
];

$steamId = trim($_GET['steam64_id'] ?? CS_LEETIFY_DEFAULT_STEAM_ID);
$profile = null;
$fetchError = null;

if (!ctype_digit($steamId) || strlen($steamId) !== 17) {
    $fetchError = 'bad_steamid';
} else {
    $result = cs_leetify_fetch_profile($steamId);
    if ($result['ok']) {
        $profile = $result['data'];
    } else {
        $fetchError = $result['error'];
    }
}

function cs_ro_date(?string $iso): string
{
    if (!$iso) return '—';
    $ts = strtotime($iso);
    if (!$ts) return '—';
    $months = [1=>'ianuarie','februarie','martie','aprilie','mai','iunie','iulie',
        'august','septembrie','octombrie','noiembrie','decembrie'];
    return date('d', $ts) . ' ' . $months[(int)date('n', $ts)] . ' ' . date('Y', $ts);
}

function cs_fmt(?float $n, int $decimals = 1): string
{
    if ($n === null) return '—';
    return number_format($n, $decimals, ',', '.');
}

function cs_humanize_key(string $key): string
{
    return ucfirst(str_replace('_', ' ', $key));
}

$ratingLabels = [
    'aim' => 'Aim', 'positioning' => 'Positioning', 'utility' => 'Utility',
    'clutch' => 'Clutch', 'opening' => 'Opening', 'ct_leetify' => 'CT Leetify', 't_leetify' => 'T Leetify',
];
$rankLabels = [
    'leetify' => 'Leetify Rating', 'premier' => 'Premier', 'faceit' => 'FACEIT',
    'faceit_elo' => 'FACEIT ELO', 'wingman' => 'Wingman', 'renown' => 'Renown',
];
$outcomeLabels = ['win' => 'Victorie', 'loss' => 'Înfrângere', 'tie' => 'Egal'];
$outcomeColors = ['win' => 'var(--good)', 'loss' => 'var(--bad)', 'tie' => 'var(--accent)'];
?>
<!DOCTYPE html>
<html lang="ro" data-theme="<?= htmlspecialchars(site_theme()) ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CS Lineups — Profil jucător</title>
<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/theme.css?v=<?= @filemtime(__DIR__ . '/../assets/theme.css') ?>">
<?php site_render_theme_head(); ?>
<style>
  main { max-width: 1000px; margin: 0 auto; padding: 32px 24px 80px; }
  main h1 { margin: 0 0 26px; font-size: 2rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); }

  .search-row {
    display: flex; gap: 8px; flex-wrap: wrap;
    margin-bottom: 28px;
  }
  .search-row input {
    width: 260px; max-width: 100%;
    padding: 10px 12px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 6px;
    color: var(--ink); font-family: var(--mono); font-size: 0.9rem;
  }
  .search-row input:focus { outline: none; border-color: var(--accent); }
  .search-row button {
    padding: 10px 18px;
    border: none; border-radius: 6px;
    background: var(--accent); color: var(--on-accent);
    font-family: var(--disp); font-weight: 600; font-size: 0.85rem;
    cursor: pointer;
    transition: background 0.2s ease;
  }
  .search-row button:hover { background: #c6923a; }

  .error-box {
    text-align: center; color: var(--ink); font-family: var(--mono); font-size: 0.9rem;
    padding: 30px 20px; border: 1px dashed var(--line); border-radius: 8px;
  }

  .panel {
    background: var(--panel); border: 1px solid rgba(240,236,228,.09); border-radius: 8px;
    padding: 20px 22px; margin-bottom: 20px;
  }
  .panel h2 {
    margin: 0 0 16px; font-family: var(--disp); font-size: 0.88rem; font-weight: 600;
    color: var(--ink); border-bottom: 1px solid var(--line); padding-bottom: 9px;
  }

  .player-head { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: 10px; }
  .player-head .name { font-size: 1.4rem; font-weight: 600; }
  .player-head .steamid { font-family: var(--mono); color: var(--ink-3); font-size: 0.82rem; }
  .player-meta {
    display: flex; flex-wrap: wrap; gap: 18px; margin-top: 14px;
    font-family: var(--mono); font-size: 0.85rem; color: var(--ink-3);
  }
  .player-meta strong { color: var(--ink); font-weight: 500; }
  .bans-list { margin-top: 10px; color: var(--bad); font-size: 0.85rem; }

  .stat-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 12px;
  }
  .stat-card {
    background: var(--bg); border: 1px solid var(--line-soft); border-radius: 6px;
    padding: 12px 14px; text-align: center;
  }
  .stat-card .label {
    font-family: var(--mono); font-size: 0.66rem; text-transform: uppercase; letter-spacing: 0.09em; color: var(--ink-3);
    margin-bottom: 7px;
  }
  .stat-card .value { font-family: var(--mono); font-size: 1.15rem; font-weight: 500; color: var(--ink); }
  .stat-card .value.pos { color: var(--good); }
  .stat-card .value.neg { color: var(--bad); }

  table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
  th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid var(--line-soft); }
  th { color: var(--ink-3); font-family: var(--mono); text-transform: uppercase; font-size: 0.66rem; letter-spacing: 0.08em; font-weight: 500; }
  td.mono, th.mono { font-family: var(--mono); }
  .table-scroll { overflow-x: auto; }

  .attribution {
    text-align: center; margin-top: 30px;
    font-family: var(--mono); font-size: 0.75rem; color: var(--ink-3);
  }
  .attribution a { margin-left: 8px; }
</style>
</head>
<body>

<header class="hero">
  <div class="brand">
    <div class="wordmark"><strong>CS</strong><span>lineups</span></div>
    <nav id="heroNav">
      <a href="/cs/reels/">Reels</a>
      <a href="/cs/profile.php" class="is-current">Profil</a>
    </nav>
  </div>
  <button type="button" class="nav-toggle" id="navToggle" aria-label="Meniu" aria-expanded="false">
    <span></span><span></span><span></span>
  </button>
</header>

<main>
  <h1>Profil jucător</h1>

  <form class="search-row" method="get">
    <input type="text" name="steam64_id" value="<?= htmlspecialchars($steamId) ?>" placeholder="Steam64 ID" pattern="\d{17}" maxlength="17" required>
    <button type="submit">Caută</button>
  </form>

  <?php if ($fetchError): ?>
    <div class="error-box"><?= htmlspecialchars($csLeetifyErrorMessages[$fetchError] ?? ('Eroare: ' . $fetchError)) ?></div>
  <?php else: ?>
    <?php
      $r = $profile['rating'] ?? [];
      $ranks = $profile['ranks'] ?? [];
      $stats = $profile['stats'] ?? [];
      $matches = $profile['recent_matches'] ?? [];
      $teammates = $profile['recent_teammates'] ?? [];
      $bans = $profile['bans'] ?? [];
      $competitive = $ranks['competitive'] ?? [];
    ?>

    <div class="panel">
      <div class="player-head">
        <div class="name"><?= htmlspecialchars($profile['name'] ?? '—') ?></div>
        <div class="steamid"><?= htmlspecialchars($profile['steam64_id'] ?? $steamId) ?></div>
      </div>
      <div class="player-meta">
        <span>Meciuri totale: <strong><?= (int)($profile['total_matches'] ?? 0) ?></strong></span>
        <span>Winrate: <strong><?= cs_fmt(isset($profile['winrate']) ? $profile['winrate'] * 100 : null, 1) ?>%</strong></span>
        <span>Prima partidă: <strong><?= cs_ro_date($profile['first_match_date'] ?? null) ?></strong></span>
        <span>Vizibilitate: <strong><?= htmlspecialchars($profile['privacy_mode'] ?? '—') ?></strong></span>
        <a href="https://steamcommunity.com/profiles/<?= urlencode($profile['steam64_id'] ?? $steamId) ?>" target="_blank" rel="noopener">Profil Steam →</a>
      </div>
      <?php if ($bans): ?>
        <div class="bans-list">
          <?php foreach ($bans as $ban): ?>
            ⚠ Ban <?= htmlspecialchars($ban['platform'] ?? '?') ?> (<?= htmlspecialchars($ban['platform_nickname'] ?? '?') ?>) din <?= cs_ro_date($ban['banned_since'] ?? null) ?><br>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    </div>

    <div class="panel">
      <h2>Rating</h2>
      <div class="stat-grid">
        <?php foreach ($ratingLabels as $key => $label): ?>
          <?php $val = $r[$key] ?? null; ?>
          <div class="stat-card">
            <div class="label"><?= htmlspecialchars($label) ?></div>
            <div class="value <?= $val !== null ? ($val >= 0 ? 'pos' : 'neg') : '' ?>"><?= cs_fmt($val, 2) ?></div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>

    <div class="panel">
      <h2>Ranguri</h2>
      <div class="stat-grid">
        <?php foreach ($rankLabels as $key => $label): ?>
          <div class="stat-card">
            <div class="label"><?= htmlspecialchars($label) ?></div>
            <div class="value"><?= $ranks[$key] ?? null ? cs_fmt($ranks[$key], 2) : '—' ?></div>
          </div>
        <?php endforeach; ?>
      </div>
      <?php if ($competitive): ?>
        <div class="table-scroll" style="margin-top:16px;">
          <table>
            <tr><th>Hartă</th><th>Rank</th></tr>
            <?php foreach ($competitive as $c): ?>
              <tr><td><?= htmlspecialchars($c['map_name'] ?? '—') ?></td><td class="mono"><?= htmlspecialchars((string)($c['rank'] ?? '—')) ?></td></tr>
            <?php endforeach; ?>
          </table>
        </div>
      <?php endif; ?>
    </div>

    <div class="panel">
      <h2>Statistici</h2>
      <div class="stat-grid">
        <?php foreach ($stats as $key => $val): ?>
          <div class="stat-card">
            <div class="label"><?= htmlspecialchars(cs_humanize_key($key)) ?></div>
            <div class="value"><?= cs_fmt($val, 2) ?></div>
          </div>
        <?php endforeach; ?>
      </div>
    </div>

    <?php if ($matches): ?>
    <div class="panel">
      <h2>Meciuri recente</h2>
      <div class="table-scroll">
        <table>
          <tr><th>Dată</th><th>Hartă</th><th>Rezultat</th><th>Scor</th><th>Sursă</th><th>Rating</th></tr>
          <?php foreach ($matches as $m): ?>
            <?php $outcome = $m['outcome'] ?? ''; ?>
            <tr>
              <td class="mono"><?= cs_ro_date($m['finished_at'] ?? null) ?></td>
              <td><?= htmlspecialchars($m['map_name'] ?? '—') ?></td>
              <td style="color: <?= htmlspecialchars($outcomeColors[$outcome] ?? 'var(--ink)') ?>"><?= htmlspecialchars($outcomeLabels[$outcome] ?? $outcome) ?></td>
              <td class="mono"><?= isset($m['score']) ? htmlspecialchars(implode('–', $m['score'])) : '—' ?></td>
              <td><?= htmlspecialchars($m['data_source'] ?? '—') ?></td>
              <td class="mono"><?= cs_fmt($m['leetify_rating'] ?? null, 2) ?></td>
            </tr>
          <?php endforeach; ?>
        </table>
      </div>
    </div>
    <?php endif; ?>

    <?php if ($teammates): ?>
    <div class="panel">
      <h2>Coechipieri frecvenți</h2>
      <div class="table-scroll">
        <table>
          <tr><th>Steam64 ID</th><th>Meciuri împreună</th><th></th></tr>
          <?php foreach ($teammates as $t): ?>
            <tr>
              <td class="mono"><?= htmlspecialchars($t['steam64_id'] ?? '—') ?></td>
              <td class="mono"><?= (int)($t['recent_matches_count'] ?? 0) ?></td>
              <td><a href="?steam64_id=<?= urlencode($t['steam64_id'] ?? '') ?>">Vezi profil →</a></td>
            </tr>
          <?php endforeach; ?>
        </table>
      </div>
    </div>
    <?php endif; ?>

    <div class="attribution">
      Data Provided by Leetify
      <a href="https://leetify.com/app/profile/<?= urlencode($profile['steam64_id'] ?? $steamId) ?>" target="_blank" rel="noopener">View on Leetify →</a>
    </div>
  <?php endif; ?>
</main>

<?php site_render_footer(); ?>

<script>
(function() {
  var navToggle = document.getElementById('navToggle');
  var heroNav = document.getElementById('heroNav');
  if (navToggle && heroNav) {
    navToggle.addEventListener('click', function() {
      var open = heroNav.classList.toggle('is-open');
      navToggle.classList.toggle('is-open', open);
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
})();
</script>

</body>
</html>
