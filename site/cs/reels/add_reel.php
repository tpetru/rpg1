<?php
// Adauga un reel Instagram. Full page POST + redirect inapoi la /cs/reels/, la fel ca uploadul de poze.
require_once __DIR__ . '/../_defs.php';
require_once __DIR__ . '/../../includes/db.php';

function cs_reel_fail(string $reason): void
{
    header('Location: /cs/reels/?add_error=' . rawurlencode($reason));
    exit;
}

$map = $_POST['map'] ?? '';
if (!isset($csReelMaps[$map])) {
    cs_reel_fail('bad_map');
}

$team = strtolower(trim($_POST['team'] ?? ''));
if (!isset($csReelTeams[$team])) {
    cs_reel_fail('bad_team');
}

$description = trim($_POST['description'] ?? '');
if (mb_strlen($description) > 128) {
    $description = mb_substr($description, 0, 128);
}

$cleanUrl = cs_clean_instagram_url(trim($_POST['url'] ?? ''));
if (!$cleanUrl) {
    cs_reel_fail('bad_url');
}

cs_ensure_reels_table($mysqli);

$maxOrder = -1;
$orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM cs_reels');
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$descOrNull = $description === '' ? null : $description;
$stmt = $mysqli->prepare('INSERT INTO cs_reels (url, map_slug, team, description, sort_order) VALUES (?, ?, ?, ?, ?)');
$stmt->bind_param('ssssi', $cleanUrl, $map, $team, $descOrNull, $nextOrder);
$stmt->execute();

header('Location: /cs/reels/');
exit;
