<?php
// Salveaza harta orasului (doar adminul). Corpul cererii e JSON-ul de salvare al jocului.
require_once __DIR__ . '/_auth.php';
city_require_admin_api();
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);

$raw = file_get_contents('php://input');
if ($raw === false || strlen($raw) > CITY_STATE_MAX_BYTES) city_json(['ok' => false, 'error' => 'too large'], 413);
$data = json_decode($raw, true);
if (!is_array($data) || ($data['v'] ?? 0) !== 1) city_json(['ok' => false, 'error' => 'invalid data'], 400);

$size = city_map_size($data);
if (!$size) city_json(['ok' => false, 'error' => 'invalid size'], 400);
$data['w'] = $size[0];
$data['h'] = $size[1];
$data['ox'] = max(0, (int)($data['ox'] ?? 0));
$data['oy'] = max(0, (int)($data['oy'] ?? 0));
$n = $size[0] * $size[1];
foreach (['ground', 'road', 'zone', 'crop', 'level', 'deco', 'growth'] as $layer) {
    $bytes = is_string($data[$layer] ?? null) ? base64_decode($data[$layer], true) : false;
    if ($bytes === false || strlen($bytes) !== $n) city_json(['ok' => false, 'error' => 'invalid layer ' . $layer], 400);
}
if (!is_array($data['specials'] ?? null)) city_json(['ok' => false, 'error' => 'invalid specials'], 400);
unset($data['cam']);
$data['name'] = mb_substr(trim((string)($data['name'] ?? '')), 0, 32) ?: 'Orașul meu';

$json = json_encode($data, JSON_UNESCAPED_UNICODE);
// Harta se poate doar mari. Daca s-a adaugat pamant la vest/nord de la ultima salvare, proprietatile si
// locurile de munca se muta in aceeasi tranzactie. O fereastra veche de admin (cu harta dinainte de
// marire) e refuzata, ca sa nu suprascrie harta mare.
$mysqli->begin_transaction();
$res = $mysqli->query('SELECT data FROM city_state WHERE id = 1 FOR UPDATE');
$row = $res ? $res->fetch_assoc() : null;
$old = $row ? json_decode($row['data'], true) : null;
if (is_array($old)) {
    $oldSize = city_map_size($old) ?? [CITY_DEFAULT_W, CITY_DEFAULT_H];
    $dx = $data['ox'] - (int)($old['ox'] ?? 0);
    $dy = $data['oy'] - (int)($old['oy'] ?? 0);
    if ($dx < 0 || $dy < 0 || $data['w'] < $oldSize[0] || $data['h'] < $oldSize[1]) {
        $mysqli->rollback();
        city_json(['ok' => false, 'error' => 'map_resized'], 409);
    }
    city_shift_map($mysqli, $dx, $dy);
}
$stmt = $mysqli->prepare('INSERT INTO city_state (id, version, data) VALUES (1, 1, ?) ON DUPLICATE KEY UPDATE version = version + 1, data = VALUES(data)');
$stmt->bind_param('s', $json);
$stmt->execute();
$mysqli->commit();

$state = city_load_state($mysqli);
$version = $state ? $state['version'] : 1;
city_sync_map($mysqli, $data, $version);
city_json(['ok' => true, 'version' => $version]);
