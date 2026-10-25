<?php
require_once __DIR__ . '/../_auth.php';
require_once __DIR__ . '/../_db.php';
require_once __DIR__ . '/../_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
// Muta o camera cu o pozitie mai sus/mai jos. Ordinea se tine in casa_design_rooms.sort_order, pe
// langa numele afisat - camerele raman foldere pe disc, aici salvam doar cum le insiruim.
header('Content-Type: application/json');

$slug = $_POST['slug'] ?? '';
$direction = $_POST['direction'] ?? '';
$baseDir = casa_house_dir($currentHouse['slug']) . '/design';

$validRoom = preg_match('/^[a-z0-9_-]+$/i', $slug) && is_dir($baseDir . '/' . $slug);
if (!$validRoom || !in_array($direction, ['up', 'down'], true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

casa_design_rooms_ensure_table($mysqli);

// Ordinea curenta, exact cum o vede pagina (aceeasi functie o foloseste si design/index.php).
$rooms = casa_design_room_order($mysqli, (int)$currentHouse['id'], $baseDir);

$pos = array_search($slug, $rooms, true);
if ($pos === false) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

$swapPos = $direction === 'up' ? $pos - 1 : $pos + 1;
if ($swapPos < 0 || $swapPos >= count($rooms)) {
    echo json_encode(['ok' => true, 'moved' => false]);
    exit;
}

[$rooms[$pos], $rooms[$swapPos]] = [$rooms[$swapPos], $rooms[$pos]];

// Scriem pozitia pentru toate camerele, nu doar pentru cele doua mutate: dupa prima reordonare
// ordinea din baza de date devine singura sursa de adevar, fara sa mai depinda de lista implicita.
$stmt = $mysqli->prepare(
    'INSERT INTO casa_design_rooms (house_id, room_slug, name, sort_order) VALUES (?, ?, \'\', ?)
     ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order)'
);
foreach ($rooms as $i => $roomSlug) {
    $order = $i + 1;
    $stmt->bind_param('isi', $currentHouse['id'], $roomSlug, $order);
    $stmt->execute();
}

echo json_encode(['ok' => true, 'moved' => true, 'order' => $rooms]);
