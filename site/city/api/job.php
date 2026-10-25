<?php
// Schimba jobul: POST id = locul de munca dorit. Merge doar daca mai e loc acolo; jobul vechi se
// elibereaza pentru altcineva.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') city_json(['ok' => false, 'error' => 'POST only'], 405);
$me = city_current_resident($mysqli);
if (!$me) city_json(['ok' => false, 'error' => 'Intră în cont mai întâi.'], 401);
$meId = (int)$me['id'];
city_daily($mysqli, $meId);

$id = (int)($_POST['id'] ?? 0);
$stmt = $mysqli->prepare('SELECT * FROM city_workplaces WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$w = $stmt->get_result()->fetch_assoc();
if (!$w) city_json(['ok' => false, 'error' => 'Locul de muncă nu mai există.'], 404);
if ((int)$me['job_id'] === $id) city_json(['ok' => false, 'error' => 'Deja lucrezi aici.'], 400);
if (!city_take_job($mysqli, $meId, $id)) city_json(['ok' => false, 'error' => 'Nu mai e niciun loc liber acolo.'], 409);

// locul eliberat de mine poate fi luat de un somer
city_hire_unemployed($mysqli);
$job = CITY_JOBS[$w['kind']];
city_json([
    'ok' => true,
    'message' => 'Te-ai angajat ca ' . mb_strtolower($job['title']) . ' la ' . city_lower_first($w['name']) . ' (' . $w['x'] . ',' . $w['y'] . ') · ' . city_lei($job['salary']) . ' pe zi.',
    'meInfo' => city_me_info($mysqli, $meId),
]);
