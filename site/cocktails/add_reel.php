<?php
// Adauga un reel de cocktail-uri. Full page POST + redirect inapoi la /cocktails.php.
require_once __DIR__ . '/_defs.php';
require_once __DIR__ . '/../includes/db.php';

function cocktail_reel_fail(string $reason): void
{
    header('Location: /cocktails.php?add_error=' . rawurlencode($reason));
    exit;
}

$description = trim($_POST['description'] ?? '');
if (mb_strlen($description) > COCKTAIL_DESC_MAX) {
    $description = mb_substr($description, 0, COCKTAIL_DESC_MAX);
}

$cleanUrl = cocktail_clean_instagram_url(trim($_POST['url'] ?? ''));
if (!$cleanUrl) {
    cocktail_reel_fail('bad_url');
}

cocktail_ensure_tables($mysqli);

$validIds = [];
$res = $mysqli->query('SELECT id FROM cocktail_filters');
if ($res) while ($row = $res->fetch_assoc()) $validIds[] = (int)$row['id'];

$maxOrder = -1;
$orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM cocktail_reels');
if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
$nextOrder = $maxOrder + 1;

$descOrNull = $description === '' ? null : $description;
$stmt = $mysqli->prepare('INSERT INTO cocktail_reels (url, description, sort_order) VALUES (?, ?, ?)');
$stmt->bind_param('ssi', $cleanUrl, $descOrNull, $nextOrder);
$stmt->execute();
$reelId = (int)$mysqli->insert_id;

$filterIds = array_map('intval', $_POST['filters'] ?? []);
cocktail_set_reel_filters($mysqli, $reelId, $filterIds, $validIds);

header('Location: /cocktails.php');
exit;
