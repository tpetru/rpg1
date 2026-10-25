<?php
// Tot ce vede un jucator, apelat periodic: locuitorii, proprietatile de pe harta si - daca e intrat
// in cont - banii lui. Tot aici se platesc o data pe zi salariul si chiria, si e tinuta evidenta
// celor online.
require_once __DIR__ . '/../_common.php';
city_ensure_schema($mysqli);
city_sync_if_needed($mysqli);

$me = city_current_resident($mysqli);
$meInfo = null;
if ($me) {
    $id = (int)$me['id'];
    $stmt = $mysqli->prepare('UPDATE city_residents SET last_seen = NOW() WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($me['job_id'] === null) city_hire($mysqli, $id);   // inainte de salariu, ca somerul angajat azi sa ia deja salariul
    $daily = city_daily($mysqli, $id);
    if ($me['home_id'] === null) city_auto_rent($mysqli, $id);
    $meInfo = city_me_info($mysqli, $id, $daily);
}

$list = [];
$res = $mysqli->query(CITY_RESIDENT_SELECT . ' ORDER BY r.joined_at, r.id');
while ($row = $res->fetch_assoc()) $list[] = city_public_resident($row);

city_json([
    'ok' => true,
    'me' => $me ? (int)$me['id'] : null,
    'meInfo' => $meInfo,
    'residents' => $list,
    'properties' => city_public_properties($mysqli),
    'workplaces' => city_public_workplaces($mysqli),
    'prices' => city_prices_public(),
    'cars' => city_public_cars($mysqli),
    'used' => city_used_cars($mysqli),
    'social' => $me ? city_social($mysqli, (int)$me['id']) : null,
]);
