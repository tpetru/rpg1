<?php
require_once __DIR__ . '/_auth.php';
casa_require_admin_api_auth();
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_suppliers.php';
casa_suppliers_ensure_table($mysqli);
// Muta un furnizor cu o pozitie mai sus/mai jos. AJAX + raspuns JSON.
header('Content-Type: application/json');

$id = (int)($_POST['id'] ?? 0);
$direction = $_POST['direction'] ?? '';
if ($id <= 0 || !in_array($direction, ['up', 'down'], true)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid input']);
    exit;
}

// Renumerotam intai tot (0,1,2,...) in ordinea afisata, ca sort_order sa fie sigur unic inainte de
// interschimbare - altfel randurile adaugate inainte de reordonare pot imparti aceeasi valoare.
$res = $mysqli->query('SELECT id FROM casa_suppliers ORDER BY sort_order, id');
$ids = [];
while ($row = $res->fetch_assoc()) $ids[] = (int)$row['id'];

$renumber = $mysqli->prepare('UPDATE casa_suppliers SET sort_order = ? WHERE id = ?');
foreach ($ids as $i => $rowId) {
    $renumber->bind_param('ii', $i, $rowId);
    $renumber->execute();
}

$pos = array_search($id, $ids, true);
if ($pos === false) {
    http_response_code(404);
    echo json_encode(['ok' => false, 'error' => 'not found']);
    exit;
}

$swapPos = $direction === 'up' ? $pos - 1 : $pos + 1;
if ($swapPos < 0 || $swapPos >= count($ids)) {
    echo json_encode(['ok' => true, 'moved' => false]);
    exit;
}

$swapId = $ids[$swapPos];
$renumber->bind_param('ii', $swapPos, $id);
$renumber->execute();
$renumber->bind_param('ii', $pos, $swapId);
$renumber->execute();

echo json_encode(['ok' => true, 'moved' => true]);
