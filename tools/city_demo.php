<?php
// Locuitori demo pentru No-Santos City. Se ruleaza din linia de comanda, cu PHP-ul din XAMPP:
//   php tools/city_demo.php stats         cati sunt si cat loc mai e
//   php tools/city_demo.php add 500       adauga 500 de locuitori demo
//   php tools/city_demo.php delete        ii sterge pe toti (ce detineau revine Primăriei)
//   php tools/city_demo.php friends       prietenii intamplatoare intre locuitorii demo (max 10 fiecare)
//   php tools/city_demo.php cars [N]      N masini second-hand (implicit 20) in stocul parcului auto (owner_id 0)
//   php tools/city_demo.php uncars        sterge masinile din stocul parcului auto
//   php tools/city_demo.php unfriends     sterge prieteniile si cererile dintre locuitorii demo
// Atentie: site-ul local foloseste baza de date de PRODUCTIE, deci scriptul lucreaza pe orasul live.
// Alta copie de _common.php (ex. una de test): variabila de mediu CITY_COMMON.
//
// Locuitorii demo au created_ip = 'demo' (asa sunt gasiti la stergere) si o parola invalida - nimeni
// nu poate intra in contul lor. Fiecare primeste: bani aleatoriu, un job aleatoriu dintre locurile
// libere si o locuinta aleatorie - cumparata (~35%) sau in chirie. Unii proprietari mai cumpara o
// locuinta pe care o dau cu chirie sau o pun la vanzare, ca jucatorii reali sa aiba si oferte "de la
// alti jucatori".
if (PHP_SAPI !== 'cli') exit("Doar din linia de comanda.\n");
require getenv('CITY_COMMON') ?: 'C:/xampp/htdocs/city/_common.php';
city_ensure_schema($mysqli);
city_sync_if_needed($mysqli);
$db = $mysqli;
$cmd = $argv[1] ?? 'stats';
const DEMO_IP = 'demo';

function rows(mysqli $db, string $sql): array { return $db->query($sql)->fetch_all(MYSQLI_ASSOC); }
function stats(mysqli $db): void
{
    $r = rows($db, "SELECT COUNT(*) total, SUM(created_ip = 'demo') demo, SUM(home_id IS NULL) homeless, SUM(job_id IS NULL) unemployed FROM city_residents")[0];
    $free = rows($db, 'SELECT COUNT(*) n FROM city_properties p LEFT JOIN city_residents r ON r.home_id = p.id WHERE r.id IS NULL')[0]['n'];
    $slots = rows($db, 'SELECT SUM(slots) s FROM city_workplaces')[0]['s'];
    $jobs = rows($db, 'SELECT COUNT(*) n FROM city_residents WHERE job_id IS NOT NULL')[0]['n'];
    echo "Locuitori: {$r['total']} (demo: " . (int)$r['demo'] . "), fara casa: " . (int)$r['homeless'] . ", someri: " . (int)$r['unemployed'] . "\n";
    echo "Locuinte libere: $free · locuri de munca libere: " . ((int)$slots - (int)$jobs) . "\n";
}

if ($cmd === 'stats') { stats($db); exit; }

if ($cmd === 'unfriends') {
    $db->query("DELETE f FROM city_friends f JOIN city_residents x ON x.id = f.a JOIN city_residents y ON y.id = f.b WHERE x.created_ip = 'demo' AND y.created_ip = 'demo'");
    echo 'Sterse ' . $db->affected_rows . " legaturi de prietenie intre locuitorii demo.
";
    exit;
}

if ($cmd === 'friends') {
    // doar intre locuitorii demo: conturile reale nu primesc prieteni nechemati
    $ids = array_map('intval', array_column(rows($db, "SELECT id FROM city_residents WHERE created_ip = 'demo'"), 'id'));
    if (count($ids) < 2) exit("Nu sunt destui locuitori demo (add N mai intai).
");
    $deg = []; $linked = [];
    foreach (rows($db, "SELECT a, b, status FROM city_friends") as $f) {
        $linked[min($f['a'], $f['b']) . ':' . max($f['a'], $f['b'])] = true;
        if ($f['status'] === 'friends') { $deg[$f['a']] = ($deg[$f['a']] ?? 0) + 1; $deg[$f['b']] = ($deg[$f['b']] ?? 0) + 1; }
    }
    $ins = $db->prepare("INSERT INTO city_friends (a, b, status, created_at) VALUES (?, ?, 'friends', NOW() - INTERVAL ? HOUR)");
    $made = 0;
    $db->begin_transaction();
    shuffle($ids);
    foreach ($ids as $a) {
        $want = mt_rand(0, 8) - ($deg[$a] ?? 0);   // ~0-8 prieteni in total, cativa fara
        for ($t = 0; $want > 0 && $t < 40 && ($deg[$a] ?? 0) < CITY_MAX_FRIENDS; $t++) {
            $b = $ids[array_rand($ids)];
            $key = min($a, $b) . ':' . max($a, $b);
            if ($b === $a || isset($linked[$key]) || ($deg[$b] ?? 0) >= CITY_MAX_FRIENDS) continue;
            $h = mt_rand(1, 24 * 30);
            $ins->bind_param('iii', $a, $b, $h);
            $ins->execute();
            $linked[$key] = true; $deg[$a] = ($deg[$a] ?? 0) + 1; $deg[$b] = ($deg[$b] ?? 0) + 1;
            $want--; $made++;
        }
    }
    $db->commit();
    $vals = array_map(function ($i) use ($deg) { return $deg[$i] ?? 0; }, $ids);
    echo "Adaugat $made prietenii intre " . count($ids) . ' locuitori demo (medie ' . round(array_sum($vals) / count($vals), 1) . ', max ' . max($vals) . ").
";
    exit;
}

if ($cmd === 'delete') {
    $ids = array_column(rows($db, "SELECT id FROM city_residents WHERE created_ip = 'demo'"), 'id');
    $db->begin_transaction();
    foreach ($ids as $id) city_delete_resident($db, (int)$id);
    $db->commit();
    city_hire_unemployed($db);   // joburile eliberate pot fi luate de somerii reali
    echo 'Sters ' . count($ids) . " locuitori demo.\n";
    stats($db);
    exit;
}

if ($cmd === 'uncars') {
    $db->query('DELETE FROM city_vehicles WHERE owner_id = 0');
    echo 'Sterse ' . $db->affected_rows . " masini din stocul parcului auto.
";
    exit;
}

if ($cmd === 'cars') {
    $n = max(0, min(200, (int)($argv[2] ?? 20)));
    // masinile demo fara marca (adaugate inainte de marci) primesc si ele una
    $noBrand = rows($db, "SELECT id, model FROM city_vehicles WHERE owner_id = 0 AND brand = ''");
    foreach ($noBrand as $nb) {
        $ok = array_keys(array_filter(CITY_BRANDS, function ($b) use ($nb) { return in_array($nb['model'], $b[3], true); }));
        if ($ok) $db->query("UPDATE city_vehicles SET brand = '" . $ok[array_rand($ok)] . "' WHERE id = " . (int)$nb['id']);
    }
    $brandKeys = array_keys(CITY_BRANDS);
    $ins = $db->prepare('INSERT INTO city_vehicles (owner_id, brand, model, color, paid, built_at, km, owners, listed_price) VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?)');
    $made = [];
    for ($i = 0; $i < $n; $i++) {
        // ~15% motociclete; la masini mai multe marci accesibile decat scumpe
        do { $brand = $brandKeys[array_rand($brandKeys)]; } while ((CITY_BRANDS[$brand][1] === 'moto') !== (mt_rand(1, 100) <= 15));
        $bodies = CITY_BRANDS[$brand][3];
        $model = $bodies[array_rand($bodies)];
        $color = CITY_CAR_COLORS[array_rand(CITY_CAR_COLORS)];
        $days = mt_rand(200, 2400);
        $km = (int)(round($days * mt_rand(CITY_BRANDS[$brand][1] === 'moto' ? 8 : 25, CITY_BRANDS[$brand][1] === 'moto' ? 30 : 85) / 10) * 10);
        $owners = max(1, min(6, 1 + (int)floor($days / 600) + mt_rand(0, 2)));
        $built = date('Y-m-d', strtotime("-$days days"));
        $value = city_car_value(['brand' => $brand, 'model' => $model, 'built_at' => $built, 'created_at' => $built, 'km' => $km, 'owners' => $owners]);
        $ask = max(500, (int)(round($value * (0.9 + mt_rand(0, 25) / 100) / 50) * 50));
        $ins->bind_param('sssisiii', $brand, $model, $color, $value, $built, $km, $owners, $ask);
        $ins->execute();
        $made[] = city_car_name($brand, $model) . " $owners prop., " . round($days / 365, 1) . ' ani, ' . number_format($km, 0, ',', '.') . ' km -> ' . number_format($ask, 0, ',', '.') . ' LEI';
    }
    echo "Adaugat $n vehicule second-hand" . ($noBrand ? ' (+ marci pentru ' . count($noBrand) . ' existente)' : '') . ":\n  " . implode("\n  ", $made) . "\n";
    exit;
}

if ($cmd !== 'add') exit("Comenzi: stats | add N | delete\n");
$count = max(1, min(2000, (int)($argv[2] ?? 500)));

$first = ['Andrei', 'Alexandru', 'Mihai', 'Ion', 'Ionuț', 'Gheorghe', 'Vasile', 'Ștefan', 'Radu', 'Cristian', 'Florin', 'Bogdan', 'Daniel', 'Marius', 'Adrian', 'Cătălin', 'Sorin', 'Vlad', 'Tudor', 'Matei', 'Dragoș', 'Lucian', 'Răzvan', 'Ovidiu', 'Paul', 'Costel', 'Nicolae', 'Petru', 'Emil', 'Horia',
    'Maria', 'Elena', 'Ioana', 'Ana', 'Andreea', 'Alexandra', 'Cristina', 'Mihaela', 'Gabriela', 'Daniela', 'Alina', 'Roxana', 'Raluca', 'Irina', 'Oana', 'Simona', 'Laura', 'Diana', 'Bianca', 'Corina', 'Ileana', 'Florentina', 'Veronica', 'Camelia', 'Larisa', 'Teodora', 'Sânziana', 'Carmen', 'Lavinia', 'Anca'];
$last = ['Popescu', 'Ionescu', 'Popa', 'Pop', 'Radu', 'Dumitru', 'Stan', 'Stoica', 'Gheorghe', 'Matei', 'Ciobanu', 'Constantin', 'Rusu', 'Mihai', 'Munteanu', 'Lungu', 'Ene', 'Marin', 'Tudor', 'Moldovan', 'Dobre', 'Barbu', 'Nistor', 'Florea', 'Sandu', 'Cristea', 'Toma', 'Ursu', 'Neagu', 'Dinu',
    'Mureșan', 'Lazăr', 'Cozma', 'Oprea', 'Voicu', 'Diaconu', 'Pavel', 'Crăciun', 'Bălan', 'Manole', 'Vasilescu', 'Georgescu', 'Ardeleanu', 'Preda', 'Iordache', 'Zamfir', 'Neacșu', 'Bucur', 'Coman', 'Surdu'];
$emojis = array_values(array_filter(CITY_EMOJIS));
$taken = array_flip(array_map('mb_strtolower', array_column(rows($db, 'SELECT username FROM city_residents'), 'username')));
$today = date('Y-m-d');

// locuintele libere si locurile de munca libere, amestecate
$free = rows($db, 'SELECT p.id, p.kind FROM city_properties p LEFT JOIN city_residents r ON r.home_id = p.id WHERE r.id IS NULL AND p.owner_id IS NULL');
shuffle($free);
$slots = [];
foreach (rows($db, 'SELECT w.id, w.slots - (SELECT COUNT(*) FROM city_residents r WHERE r.job_id = w.id) free FROM city_workplaces w') as $w) {
    for ($k = 0; $k < (int)$w['free']; $k++) $slots[] = (int)$w['id'];
}
shuffle($slots);
echo "Pornesc: " . count($free) . " locuinte ale Primăriei libere, " . count($slots) . " locuri de munca libere.\n";

$ins = $db->prepare("INSERT INTO city_residents (username, password_hash, emoji, balance, home_id, rent_amount, job_id, last_daily, created_ip, joined_at, last_seen)
    VALUES (?, '!demo', ?, ?, ?, ?, ?, ?, 'demo', NOW() - INTERVAL ? MINUTE, NOW() - INTERVAL ? MINUTE)");
$own = $db->prepare('UPDATE city_properties SET owner_id = ?, paid_price = ?, sale_price = ?, rent_price = ? WHERE id = ? AND owner_id IS NULL');
$leased = [];   // [id, rent] locuinte de-ale proprietarilor demo, date cu chirie si inca goale
$made = ['owners' => 0, 'renters_player' => 0, 'renters_primarie' => 0, 'homeless' => 0, 'jobs' => 0, 'extra_lease' => 0, 'extra_sale' => 0];

$db->begin_transaction();
for ($n = 0; $n < $count; $n++) {
    do {
        $name = $first[array_rand($first)] . ' ' . $last[array_rand($last)];
        if (isset($taken[mb_strtolower($name)])) $name .= ' ' . mt_rand(2, 99);
    } while (isset($taken[mb_strtolower($name)]) || !city_valid_name($name));
    $taken[mb_strtolower($name)] = true;

    // bani: cei mai multi au putin, cativa sunt bogati
    $balance = (int)(round(300 * pow(250000 / 300, pow(mt_rand() / mt_getrandmax(), 1.6)) / 10) * 10);
    $emoji = mt_rand(0, 3) ? $emojis[array_rand($emojis)] : '';
    $job = $slots ? array_pop($slots) : null;
    $joinedMin = mt_rand(60, 45 * 1440);
    $seenMin = mt_rand(20, min($joinedMin, 6 * 1440));
    $home = null; $rent = 0; $owner = false;

    $roll = mt_rand(1, 100);
    if ($roll <= 35 && $free) {                 // isi cumpara locuinta
        $p = array_pop($free);
        $home = (int)$p['id']; $owner = true;
    } elseif ($roll <= 55 && $leased) {         // chirie la un proprietar demo
        [$home, $rent] = array_splice($leased, mt_rand(0, count($leased) - 1), 1)[0];
        $made['renters_player']++;
    } elseif ($free) {                          // chirie la Primărie
        $p = array_pop($free);
        $home = (int)$p['id']; $rent = CITY_RENTS[$p['kind']];
        $made['renters_primarie']++;
    } else {
        $made['homeless']++;
    }

    $ins->bind_param('ssiiiisii', $name, $emoji, $balance, $home, $rent, $job, $today, $joinedMin, $seenMin);
    $ins->execute();
    $id = (int)$db->insert_id;
    if ($job !== null) $made['jobs']++;

    if ($owner) {
        $made['owners']++;
        $price = CITY_PRICES[$p['kind']];
        $null = null;
        $own->bind_param('iiiii', $id, $price, $null, $null, $home);
        $own->execute();
        // un sfert dintre proprietari mai au o locuinta: cu chirie (mai des) sau de vanzare
        if (mt_rand(1, 4) === 1 && $free) {
            $q = array_pop($free);
            $qid = (int)$q['id'];
            $qprice = CITY_PRICES[$q['kind']];
            if (mt_rand(1, 10) <= 7) {
                $r = (int)(round(CITY_RENTS[$q['kind']] * (0.8 + mt_rand(0, 80) / 100) / 10) * 10);
                $own->bind_param('iiiii', $id, $qprice, $null, $r, $qid);
                $leased[] = [$qid, $r];
                $made['extra_lease']++;
            } else {
                $sale = (int)(round($qprice * (1 + mt_rand(0, 50) / 100) / 500) * 500);
                $own->bind_param('iiiii', $id, $qprice, $sale, $null, $qid);
                $made['extra_sale']++;
            }
            $own->execute();
        }
    }
}
$db->commit();
echo "Adaugat $count locuitori demo: " . json_encode($made) . "\n";
stats($db);
