<?php
// Prietenii: POST action = request | accept | decline | cancel | remove, id = celalalt locuitor.
// Cererea trebuie aprobata de celalalt; fiecare poate avea cel mult CITY_MAX_FRIENDS prieteni.
// Daca amandoi isi cer prietenia unul altuia, devin prieteni direct.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
$me = city_current_resident($mysqli);
if (!$me) city_json(['ok' => false, 'error' => 'Intră în cont mai întâi.'], 401);
$meId = (int)$me['id'];
$action = (string)($_POST['action'] ?? '');
$otherId = (int)($_POST['id'] ?? 0);

$stmt = $mysqli->prepare('SELECT id, username FROM city_residents WHERE id = ?');
$stmt->bind_param('i', $otherId);
$stmt->execute();
$other = $stmt->get_result()->fetch_assoc();
if (!$other) city_json(['ok' => false, 'error' => 'Locuitorul nu mai există.'], 404);
if ($otherId === $meId) city_json(['ok' => false, 'error' => 'Nu poți fi prieten cu tine.'], 400);
$name = $other['username'];

function fr_done(mysqli $db, int $meId, string $message): void
{
    city_json(['ok' => true, 'message' => $message, 'social' => city_social($db, $meId)]);
}
function fr_fail(mysqli $db, string $error): void
{
    $db->rollback();
    city_json(['ok' => false, 'error' => $error], 409);
}
// legatura dintre noi doi, oricare ar fi trimis cererea
function fr_link(mysqli $db, int $x, int $y): ?array
{
    $stmt = $db->prepare('SELECT * FROM city_friends WHERE (a = ? AND b = ?) OR (a = ? AND b = ?) FOR UPDATE');
    $stmt->bind_param('iiii', $x, $y, $y, $x);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

// blocam ambii locuitori (in aceeasi ordine), ca limita de prieteni sa nu fie depasita de doua cereri simultane
$mysqli->begin_transaction();
$lo = min($meId, $otherId);
$hi = max($meId, $otherId);
$stmt = $mysqli->prepare('SELECT id FROM city_residents WHERE id IN (?, ?) ORDER BY id FOR UPDATE');
$stmt->bind_param('ii', $lo, $hi);
$stmt->execute();
$stmt->get_result()->fetch_all();
$link = fr_link($mysqli, $meId, $otherId);

if ($action === 'request') {
    if ($link && $link['status'] === 'friends') fr_fail($mysqli, 'Ești deja prieten cu ' . $name . '.');
    if ($link && (int)$link['a'] === $meId) fr_fail($mysqli, 'I-ai trimis deja o cerere lui ' . $name . '.');
    if (city_friend_count($mysqli, $meId) >= CITY_MAX_FRIENDS) fr_fail($mysqli, 'Ai deja ' . CITY_MAX_FRIENDS . ' prieteni - cât se poate. Elimină pe cineva ca să faci loc.');
    if ($link) {
        // ne-a cerut-o si el: devenim prieteni direct
        if (city_friend_count($mysqli, $otherId) >= CITY_MAX_FRIENDS) fr_fail($mysqli, $name . ' are deja ' . CITY_MAX_FRIENDS . ' prieteni.');
        $stmt = $mysqli->prepare("UPDATE city_friends SET status = 'friends' WHERE a = ? AND b = ?");
        $stmt->bind_param('ii', $otherId, $meId);
        $stmt->execute();
        $mysqli->commit();
        fr_done($mysqli, $meId, 'Acum ești prieten cu ' . $name . '! 🤝');
    }
    $stmt = $mysqli->prepare("SELECT COUNT(*) n FROM city_friends WHERE a = ? AND status = 'pending'");
    $stmt->bind_param('i', $meId);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_assoc()['n'] >= CITY_MAX_PENDING_OUT) fr_fail($mysqli, 'Ai prea multe cereri nerăspunse. Așteaptă să-ți răspundă cineva.');
    $stmt = $mysqli->prepare("INSERT INTO city_friends (a, b, status) VALUES (?, ?, 'pending')");
    $stmt->bind_param('ii', $meId, $otherId);
    $stmt->execute();
    $mysqli->commit();
    fr_done($mysqli, $meId, 'I-ai trimis lui ' . $name . ' o cerere de prietenie.');
}

if ($action === 'accept') {
    if (!$link || $link['status'] !== 'pending' || (int)$link['a'] !== $otherId) fr_fail($mysqli, 'Cererea nu mai există.');
    if (city_friend_count($mysqli, $meId) >= CITY_MAX_FRIENDS) fr_fail($mysqli, 'Ai deja ' . CITY_MAX_FRIENDS . ' prieteni - cât se poate. Elimină pe cineva ca să faci loc.');
    if (city_friend_count($mysqli, $otherId) >= CITY_MAX_FRIENDS) fr_fail($mysqli, $name . ' are deja ' . CITY_MAX_FRIENDS . ' prieteni.');
    $stmt = $mysqli->prepare("UPDATE city_friends SET status = 'friends' WHERE a = ? AND b = ?");
    $stmt->bind_param('ii', $otherId, $meId);
    $stmt->execute();
    $mysqli->commit();
    fr_done($mysqli, $meId, 'Acum ești prieten cu ' . $name . '! 🤝');
}

if ($action === 'decline' || $action === 'cancel' || $action === 'remove') {
    $ok = $link && ($action === 'remove' ? $link['status'] === 'friends'
        : $link['status'] === 'pending' && (int)$link['a'] === ($action === 'decline' ? $otherId : $meId));
    if (!$ok) fr_fail($mysqli, $action === 'remove' ? 'Nu ești prieten cu ' . $name . '.' : 'Cererea nu mai există.');
    $a = (int)$link['a'];
    $b = (int)$link['b'];
    $stmt = $mysqli->prepare('DELETE FROM city_friends WHERE a = ? AND b = ?');
    $stmt->bind_param('ii', $a, $b);
    $stmt->execute();
    $mysqli->commit();
    fr_done($mysqli, $meId, $action === 'remove' ? $name . ' nu mai e în lista ta de prieteni.' : ($action === 'decline' ? 'Ai refuzat cererea lui ' . $name . '.' : 'Ai anulat cererea către ' . $name . '.'));
}

$mysqli->rollback();
city_json(['ok' => false, 'error' => 'Acțiune necunoscută.'], 400);
