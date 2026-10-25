<?php
// Orasul comun: harta (un singur rand in city_state, editat doar din /admin) si locuitorii, fiecare
// cu contul lui (city_residents: nume + parola). Un login = un rand in city_sessions, ca acelasi cont
// sa poata fi deschis pe mai multe dispozitive. city_ips tine cate conturi s-au facut de pe fiecare
// IP (maxim CITY_MAX_ACCOUNTS_PER_IP) si incercarile gresite de login. Tabelele stau in baza lor,
// `city` - aceeasi conexiune si acelasi cont MySQL ca restul site-ului (la fel ca /casa).
//
// Proprietati (city_properties): fiecare Căsuță/Casă de pe harta e o casa, fiecare Bloc mic are
// CITY_APTS_PER_BLOCK apartamente. Ce n-a cumparat nimeni e al Primăriei (owner_id NULL), care il
// vinde la pret fix si il inchiriaza cat timp e gol. Un jucator isi poate vinde proprietatea sau
// o poate inchiria altora (case si apartamente deopotriva). Unde locuieste fiecare: city_residents.home_id (unic - o proprietate
// are cel mult un locatar); daca nu e proprietarul ei, e chirias si plateste rent_amount pe zi.
// Banii (LEI, intregi) se misca doar prin city_money(), care scrie si in istoricul city_transactions.
require_once __DIR__ . '/../includes/db.php';

const CITY_DB_NAME = 'city';
if (!$mysqli->select_db(CITY_DB_NAME)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Baza de date `' . CITY_DB_NAME . '` nu există sau contul MySQL n-are acces la ea.']);
    exit;
}
date_default_timezone_set('Europe/Bucharest');

// Harta poate fi marita din admin: marimea ei e in JSON-ul salvat (w, h). Hartile vechi n-o au -> 80 x 60.
const CITY_DEFAULT_W = 80;
const CITY_DEFAULT_H = 60;
const CITY_MAX_SIDE = 200;       // la fel ca MAX_SIDE / MAX_TILES din city.js
const CITY_MAX_TILES = 20000;
const CITY_TOKEN_COOKIE = 'city_token';
const CITY_EMOJIS = ['', '😀', '😎', '🤠', '👩', '👨', '🧔', '👵', '🐱', '🐶', '🦊', '🐻', '🐸', '🌻', '⚽', '🎸'];
const CITY_STATE_MAX_BYTES = 1500000;
const CITY_MAX_ACCOUNTS_PER_IP = 5;
const CITY_MAX_FRIENDS = 10;
// Masini personale: se cumpara de la un Dealership pus de admin pe harta. Cel mult CITY_MAX_CARS pe jucator.
const CITY_MAX_CARS = 3;
const CITY_CAR_RESALE = 60;          // % din valoarea de acum, cand vinzi la dealer
const CITY_KM_PER_TILE = 0.5;         // un patratel de pe harta = 0,5 km (pentru kilometrajul masinilor)
// Caroseriile (model) si pretul lor de baza; la motociclete pretul vine de la marca.
const CITY_CARS = [
    'mini'   => ['name' => 'Mini', 'price' => 8000, 'icon' => '🚗'],
    'hatch'  => ['name' => 'Hatchback', 'price' => 15000, 'icon' => '🚙'],
    'break'  => ['name' => 'Break', 'price' => 20000, 'icon' => '🚐'],
    'sedan'  => ['name' => 'Sedan', 'price' => 25000, 'icon' => '🚘'],
    'suv'    => ['name' => 'SUV', 'price' => 40000, 'icon' => '🚙'],
    'sport'  => ['name' => 'Sport', 'price' => 90000, 'icon' => '🏎️'],
    'moto'   => ['name' => 'Motocicletă', 'price' => 9000, 'icon' => '🏍️'],
];
// Marci: nume, tip (car | moto), multiplicatorul pretului caroseriei (sau pretul fix al motocicletei) si
// caroseriile pe care le face.
const CITY_BRANDS = [
    'volkswagen' => ['Volkswagen', 'car', 1.05, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'skoda'      => ['Škoda', 'car', 0.95, ['hatch', 'sedan', 'break', 'suv']],
    'toyota'     => ['Toyota', 'car', 1.05, ['mini', 'hatch', 'sedan', 'break', 'suv', 'sport']],
    'bmw'        => ['BMW', 'car', 1.5, ['hatch', 'sedan', 'break', 'suv', 'sport']],
    'audi'       => ['Audi', 'car', 1.4, ['hatch', 'sedan', 'break', 'suv', 'sport']],
    'mercedes'   => ['Mercedes-Benz', 'car', 1.6, ['hatch', 'sedan', 'break', 'suv', 'sport']],
    'renault'    => ['Renault', 'car', 0.9, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'peugeot'    => ['Peugeot', 'car', 0.95, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'dacia'      => ['Dacia', 'car', 0.8, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'hyundai'    => ['Hyundai', 'car', 0.95, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'kia'        => ['Kia', 'car', 0.95, ['mini', 'hatch', 'sedan', 'break', 'suv', 'sport']],
    'citroen'    => ['Citroën', 'car', 0.9, ['mini', 'hatch', 'break', 'suv']],
    'opel'       => ['Opel', 'car', 0.9, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'ford'       => ['Ford', 'car', 1.0, ['mini', 'hatch', 'sedan', 'break', 'suv', 'sport']],
    'fiat'       => ['Fiat', 'car', 0.85, ['mini', 'hatch', 'break', 'suv']],
    'tesla'      => ['Tesla', 'car', 1.6, ['sedan', 'suv', 'sport']],
    'seat'       => ['SEAT', 'car', 0.95, ['mini', 'hatch', 'break', 'suv']],
    'cupra'      => ['CUPRA', 'car', 1.15, ['hatch', 'break', 'suv', 'sport']],
    'volvo'      => ['Volvo', 'car', 1.3, ['sedan', 'break', 'suv']],
    'nissan'     => ['Nissan', 'car', 1.0, ['mini', 'hatch', 'suv', 'sport']],
    'mg'         => ['MG', 'car', 0.85, ['mini', 'hatch', 'suv']],
    'byd'        => ['BYD', 'car', 0.95, ['hatch', 'sedan', 'suv']],
    'suzuki'     => ['Suzuki', 'car', 0.85, ['mini', 'hatch', 'suv']],
    'mini'       => ['MINI', 'car', 1.2, ['mini', 'hatch', 'suv']],
    'mazda'      => ['Mazda', 'car', 1.05, ['hatch', 'sedan', 'break', 'suv', 'sport']],
    'jeep'       => ['Jeep', 'car', 1.3, ['suv']],
    'porsche'    => ['Porsche', 'car', 2.5, ['sedan', 'suv', 'sport']],
    'lexus'      => ['Lexus', 'car', 1.5, ['sedan', 'suv', 'sport']],
    'honda'      => ['Honda', 'car', 1.05, ['mini', 'hatch', 'sedan', 'break', 'suv']],
    'mitsubishi' => ['Mitsubishi', 'car', 1.0, ['hatch', 'suv']],
    'yamaha'     => ['Yamaha', 'moto', 6000, ['moto']],
    'kawasaki'   => ['Kawasaki', 'moto', 7000, ['moto']],
    'ducati'     => ['Ducati', 'moto', 14000, ['moto']],
    'ktm'        => ['KTM', 'moto', 8000, ['moto']],
    'harley'     => ['Harley-Davidson', 'moto', 16000, ['moto']],
];
// Culori: gri (implicit, fara supliment), alb/negru +1.000 LEI, restul +2.500 LEI.
const CITY_CAR_COLOR_INFO = [
    '#8e9196' => ['Gri', 0],
    '#f7f4ee' => ['Alb', 1000],
    '#2b2e33' => ['Negru', 1000],
    '#d9534f' => ['Roșu', 2500],
    '#4a8fc9' => ['Albastru', 2500],
    '#f1c84b' => ['Galben', 2500],
    '#5aa469' => ['Verde', 2500],
    '#e8873c' => ['Portocaliu', 2500],
    '#9b6cc4' => ['Mov', 2500],
];
const CITY_CAR_COLORS = ['#8e9196', '#f7f4ee', '#2b2e33', '#d9534f', '#4a8fc9', '#f1c84b', '#5aa469', '#e8873c', '#9b6cc4'];
function city_car_base(string $brand, string $model): int
{
    $b = CITY_BRANDS[$brand] ?? null;
    if (!$b || !in_array($model, $b[3], true)) return CITY_CARS[$model]['price'] ?? 0;   // masini fara marca (cumparate inainte)
    return $b[1] === 'moto' ? (int)$b[2] : (int)(round(CITY_CARS[$model]['price'] * $b[2] / 100) * 100);
}
function city_car_price(string $brand, string $model, string $color): int
{
    return city_car_base($brand, $model) + (CITY_CAR_COLOR_INFO[$color][1] ?? 2500);
}
function city_car_name(string $brand, string $model): string
{
    return (isset(CITY_BRANDS[$brand]) ? CITY_BRANDS[$brand][0] . ' ' : '') . (CITY_CARS[$model]['name'] ?? 'mașină');
}
const CITY_MAX_PENDING_OUT = 20;      // cereri de prietenie trimise si inca neraspunse
const CITY_LOGIN_MAX_FAILS = 10;       // incercari gresite permise per IP...
const CITY_LOGIN_FAIL_WINDOW = 15;     // ...intr-un interval de atatea minute
const CITY_PASSWORD_MIN = 6;

const CITY_APTS_PER_BLOCK = 4;
const CITY_PRICES = ['house1' => 25000, 'house2' => 40000, 'apt' => 15000, 'hfloor' => 65000, 'hpool' => 80000, 'villa' => 150000, 'mansion' => 350000];   // preturile Primăriei
const CITY_KIND_NAMES = ['house1' => 'Căsuța', 'house2' => 'Casa', 'apt' => 'Apartamentul', 'hfloor' => 'Casa cu etaj', 'hpool' => 'Casa cu piscină', 'villa' => 'Vila', 'mansion' => 'Conacul'];
const CITY_RENTS = ['house1' => 250, 'house2' => 350, 'apt' => 200, 'hfloor' => 400, 'hpool' => 450, 'villa' => 700, 'mansion' => 1200];   // chiria pe zi la Primărie
// Locuintele puse de admin ca cladiri (cheia cladirii din harta => tipul proprietatii); ca si Blocul, au
// apartamentele / casa pe patratelul din stanga-sus.
const CITY_HOME_SPECIALS = ['house_floor' => 'hfloor', 'house_pool' => 'hpool', 'villa' => 'villa', 'mansion' => 'mansion'];
const CITY_START_BALANCE = 5000;

// Locurile de munca vin din cladirile de pe harta (city_workplaces, refacute la fiecare salvare a
// adminului). Fiecare tip de loc de munca = o meserie cu salariul ei pe zi; cine n-are loc e somer.
const CITY_JOBS = [
    'shop'     => ['title' => 'Vânzător', 'salary' => 900, 'icon' => '🛒'],
    'school'   => ['title' => 'Profesor', 'salary' => 1200, 'icon' => '📚'],
    'clinic'   => ['title' => 'Medic', 'salary' => 1500, 'icon' => '🩺'],
    'market'   => ['title' => 'Comerciant', 'salary' => 1000, 'icon' => '🧺'],
    'fire'     => ['title' => 'Pompier', 'salary' => 1100, 'icon' => '🚒'],
    'church'   => ['title' => 'Preot', 'salary' => 900, 'icon' => '⛪'],
    'park'     => ['title' => 'Grădinar', 'salary' => 800, 'icon' => '🌳'],
    'windmill' => ['title' => 'Morar', 'salary' => 950, 'icon' => '🌬️'],
    'barn'     => ['title' => 'Îngrijitor de animale', 'salary' => 950, 'icon' => '🐄'],
    'field'    => ['title' => 'Fermier', 'salary' => 1000, 'icon' => '🌾'],
    'hospital'   => ['title' => 'Medic de spital', 'salary' => 1700, 'icon' => '🏥'],
    'medcenter'  => ['title' => 'Medic specialist', 'salary' => 1600, 'icon' => '🩺'],
    'kinder'     => ['title' => 'Educatoare', 'salary' => 1000, 'icon' => '🧸'],
    'highschool' => ['title' => 'Profesor de liceu', 'salary' => 1300, 'icon' => '🎓'],
    'dorm'       => ['title' => 'Administrator de cămin', 'salary' => 900, 'icon' => '🛏️'],
    'lidl'       => ['title' => 'Casier', 'salary' => 1000, 'icon' => '🛒'],
    'kaufland'   => ['title' => 'Casier', 'salary' => 1050, 'icon' => '🛒'],
    'penny'      => ['title' => 'Casier', 'salary' => 950, 'icon' => '🛒'],
    'carrefour'  => ['title' => 'Casier', 'salary' => 1050, 'icon' => '🛒'],
    'mall'       => ['title' => 'Vânzător în mall', 'salary' => 1100, 'icon' => '🛍️'],
    'rompetrol'  => ['title' => 'Pompagiu', 'salary' => 950, 'icon' => '⛽'],
    'omv'        => ['title' => 'Pompagiu', 'salary' => 950, 'icon' => '⛽'],
    'socar'      => ['title' => 'Pompagiu', 'salary' => 950, 'icon' => '⛽'],
    'factory_s'  => ['title' => 'Muncitor', 'salary' => 1100, 'icon' => '🏭'],
    'factory_m'  => ['title' => 'Muncitor', 'salary' => 1150, 'icon' => '🏭'],
    'factory_l'  => ['title' => 'Muncitor calificat', 'salary' => 1250, 'icon' => '🏭'],
    'factory_xl' => ['title' => 'Operator de producție', 'salary' => 1350, 'icon' => '🏭'],
    'solar'      => ['title' => 'Tehnician', 'salary' => 1300, 'icon' => '☀️'],
    'parking_s'  => ['title' => 'Paznic de parcare', 'salary' => 800, 'icon' => '🅿️'],
    'parking_l'  => ['title' => 'Paznic de parcare', 'salary' => 850, 'icon' => '🅿️'],
    'busdepot'   => ['title' => 'Șofer de autobuz', 'salary' => 1150, 'icon' => '🚌'],
    'tramdepot'  => ['title' => 'Vatman', 'salary' => 1150, 'icon' => '🚋'],
    'stadium_s'  => ['title' => 'Fotbalist', 'salary' => 1300, 'icon' => '⚽'],
    'stadium_m'  => ['title' => 'Fotbalist', 'salary' => 1600, 'icon' => '⚽'],
    'stadium_l'  => ['title' => 'Fotbalist', 'salary' => 2000, 'icon' => '⚽'],
    'pool'       => ['title' => 'Salvamar', 'salary' => 900, 'icon' => '🏊'],
    'amusement'  => ['title' => 'Animator', 'salary' => 950, 'icon' => '🎡'],
    'bar'        => ['title' => 'Barman', 'salary' => 950, 'icon' => '🍺'],
    'restaurant' => ['title' => 'Ospătar', 'salary' => 1000, 'icon' => '🍽️'],
    'airport'    => ['title' => 'Personal de aeroport', 'salary' => 1500, 'icon' => '✈️'],
    'aumovio'    => ['title' => 'Programator', 'salary' => 2200, 'icon' => '💻'],
    'dealership' => ['title' => 'Vânzător auto', 'salary' => 1300, 'icon' => '🚗'],
    'usedlot'    => ['title' => 'Vânzător mașini second-hand', 'salary' => 1100, 'icon' => '🅿️'],
];
const CITY_UNEMPLOYED_PAY = 500;  // ajutorul de somaj nu se impoziteaza
// Taxele pe salariu, ca in Romania (procente): CAS si CASS din brut, impozitul din ce ramane dupa ele.
const CITY_TAX_CAS = 25;
const CITY_TAX_CASS = 10;
const CITY_TAX_INCOME = 10;
const CITY_SHOP_SLOTS = [0, 3, 6, 12];                       // dupa nivelul magazinului
// locurile de munca trebuie sa fie la fel ca jobs din SPECIALS (city.js)
const CITY_SPECIAL_SLOTS = [
    'park' => 1, 'school' => 8, 'clinic' => 6, 'church' => 1, 'fire' => 5, 'market' => 12, 'windmill' => 2, 'barn' => 3,
    'hospital' => 20, 'medcenter' => 8, 'kinder' => 4, 'highschool' => 12, 'dorm' => 2,
    'lidl' => 10, 'kaufland' => 16, 'penny' => 6, 'carrefour' => 16, 'mall' => 30,
    'rompetrol' => 3, 'omv' => 3, 'socar' => 3,
    'factory_s' => 6, 'factory_m' => 12, 'factory_l' => 20, 'factory_xl' => 40, 'solar' => 2,
    'parking_s' => 1, 'parking_l' => 2, 'busdepot' => 10, 'tramdepot' => 8,
    'stadium_s' => 6, 'stadium_m' => 12, 'stadium_l' => 22, 'pool' => 3, 'amusement' => 10,
    'bar' => 4, 'restaurant' => 8, 'airport' => 40, 'dealership' => 5, 'usedlot' => 3, 'aumovio' => 5,
];
const CITY_SPECIAL_NAMES = [
    'park' => 'Parcul', 'school' => 'Școala', 'clinic' => 'Dispensarul', 'church' => 'Biserica', 'fire' => 'Remiza de pompieri', 'market' => 'Piața', 'windmill' => 'Moara', 'barn' => 'Hambarul',
    'hospital' => 'Spitalul', 'medcenter' => 'Clinica medicală', 'kinder' => 'Grădinița', 'highschool' => 'Liceul', 'dorm' => 'Căminul',
    'lidl' => 'Lidl', 'kaufland' => 'Kaufland', 'penny' => 'Penny', 'carrefour' => 'Carrefour', 'mall' => 'Mall-ul',
    'rompetrol' => 'Benzinăria Rompetrol', 'omv' => 'Benzinăria OMV', 'socar' => 'Benzinăria SOCAR',
    'factory_s' => 'Fabrica mică', 'factory_m' => 'Fabrica medie', 'factory_l' => 'Fabrica mare', 'factory_xl' => 'Fabrica gigantică', 'solar' => 'Parcul fotovoltaic',
    'parking_s' => 'Parcarea mică', 'parking_l' => 'Parcarea mare', 'busdepot' => 'Autobaza', 'tramdepot' => 'Depoul de tramvaie',
    'stadium_s' => 'Stadionul mic', 'stadium_m' => 'Stadionul mediu', 'stadium_l' => 'Stadionul mare', 'pool' => 'Piscina', 'amusement' => 'Parcul de distracții',
    'bar' => 'Barul', 'restaurant' => 'Restaurantul', 'airport' => 'Aeroportul', 'dealership' => 'Dealerul auto', 'aumovio' => 'AuNau-movio', 'usedlot' => 'Parcul auto',
];
// nume proprii: raman cu majuscula in mijlocul propozitiei ("la Lidl", nu "la lidl")
const CITY_PROPER_NAMES = ['Lidl', 'Kaufland', 'Penny', 'Carrefour', 'AuNau-movio'];
const CITY_SHOP_NAMES = [1 => 'Prăvălia', 2 => 'Magazinul', 3 => 'Magazinul mare'];
const CITY_FIELD_CHUNK = 4;      // campurile se impart in patrate de 4x4: fiecare are cate un fermier la 4 parcele
const CITY_FIELD_TILES_PER_JOB = 4;
const CITY_MAX_PRICE = 100000000;
const CITY_MAX_RENT = 1000000;

function city_ip(): string
{
    return substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 45);
}

function city_has_column(mysqli $db, string $table, string $column): bool
{
    $res = $db->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $res && $res->num_rows > 0;
}

function city_ensure_schema(mysqli $db): void
{
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_state (
            id TINYINT UNSIGNED NOT NULL,
            version INT UNSIGNED NOT NULL DEFAULT 0,
            data MEDIUMTEXT NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_residents (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            username VARCHAR(30) NOT NULL,
            password_hash VARCHAR(255) NOT NULL DEFAULT \'\',
            emoji VARCHAR(16) NOT NULL DEFAULT \'\',
            balance INT NOT NULL DEFAULT 0,
            home_id INT UNSIGNED NULL,
            rent_amount INT UNSIGNED NOT NULL DEFAULT 0,
            job_id INT UNSIGNED NULL,
            last_daily DATE NULL,
            created_ip VARCHAR(45) NOT NULL DEFAULT \'\',
            joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP NULL,
            PRIMARY KEY (id),
            UNIQUE KEY username (username),
            UNIQUE KEY home_id (home_id),
            KEY job_id (job_id),
            KEY created_ip (created_ip)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Prima varianta a tabelului (fara conturi): token in cookie, pe un singur dispozitiv.
    if (city_has_column($db, 'city_residents', 'token_hash')) {
        $db->query("ALTER TABLE city_residents DROP INDEX token_hash, DROP COLUMN token_hash, DROP COLUMN ip_hash,
            ADD COLUMN password_hash VARCHAR(255) NOT NULL DEFAULT '' AFTER username,
            ADD COLUMN created_ip VARCHAR(45) NOT NULL DEFAULT '', ADD KEY created_ip (created_ip)");
    }
    // A doua varianta: locuitorul avea doar coordonatele unei case (house_x/house_y), fara bani si
    // fara proprietati. Toti primesc soldul de start si sunt mutati din nou, de data asta in chirie.
    if (!city_has_column($db, 'city_residents', 'balance')) {
        $db->query('ALTER TABLE city_residents ADD COLUMN balance INT NOT NULL DEFAULT 0 AFTER emoji,
            ADD COLUMN home_id INT UNSIGNED NULL AFTER balance,
            ADD COLUMN rent_amount INT UNSIGNED NOT NULL DEFAULT 0 AFTER home_id,
            ADD COLUMN last_daily DATE NULL AFTER rent_amount,
            ADD UNIQUE KEY home_id (home_id)');
        $db->query('UPDATE city_residents SET balance = ' . CITY_START_BALANCE . ', last_daily = CURDATE()');
    }
    if (city_has_column($db, 'city_residents', 'house_x')) {
        $db->query('ALTER TABLE city_residents DROP COLUMN house_x, DROP COLUMN house_y');
    }
    if (!city_has_column($db, 'city_residents', 'job_id')) {
        $db->query('ALTER TABLE city_residents ADD COLUMN job_id INT UNSIGNED NULL AFTER rent_amount, ADD KEY job_id (job_id)');
    }
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_workplaces (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            wkey VARCHAR(40) NOT NULL,
            kind VARCHAR(16) NOT NULL,
            name VARCHAR(60) NOT NULL,
            x SMALLINT NOT NULL,
            y SMALLINT NOT NULL,
            slots SMALLINT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY wkey (wkey)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_sessions (
            token_hash CHAR(64) NOT NULL,
            resident_id INT UNSIGNED NOT NULL,
            ip VARCHAR(45) NOT NULL DEFAULT \'\',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP NULL,
            PRIMARY KEY (token_hash),
            KEY resident_id (resident_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_ips (
            ip VARCHAR(45) NOT NULL,
            accounts INT UNSIGNED NOT NULL DEFAULT 0,
            login_fails INT UNSIGNED NOT NULL DEFAULT 0,
            fails_since TIMESTAMP NULL,
            first_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (ip)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_properties (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            x SMALLINT NOT NULL,
            y SMALLINT NOT NULL,
            unit TINYINT UNSIGNED NOT NULL DEFAULT 0,
            kind VARCHAR(8) NOT NULL,
            owner_id INT UNSIGNED NULL,
            sale_price INT UNSIGNED NULL,
            rent_price INT UNSIGNED NULL,
            paid_price INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY pos (x, y, unit),
            KEY owner_id (owner_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Prietenii: a i-a trimis cererea lui b. status: 'pending' (asteapta raspunsul lui b) sau 'friends'.
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_friends (
            a INT UNSIGNED NOT NULL,
            b INT UNSIGNED NOT NULL,
            status VARCHAR(8) NOT NULL DEFAULT \'pending\',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (a, b),
            KEY b (b)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_vehicles (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            owner_id INT UNSIGNED NOT NULL,
            model VARCHAR(12) NOT NULL,
            color CHAR(7) NOT NULL,
            paid INT UNSIGNED NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY owner_id (owner_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    foreach (['built_at DATE NULL', "brand VARCHAR(20) NOT NULL DEFAULT ''", 'km INT UNSIGNED NOT NULL DEFAULT 0', 'owners SMALLINT UNSIGNED NOT NULL DEFAULT 1', 'listed_price INT UNSIGNED NULL'] as $col) {
        $name = explode(' ', $col)[0];
        if (!city_has_column($db, 'city_vehicles', $name)) {
            $db->query("ALTER TABLE city_vehicles ADD COLUMN $col");
            if ($name === 'built_at') $db->query('UPDATE city_vehicles SET built_at = DATE(created_at) WHERE built_at IS NULL');
        }
    }
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_meta (
            k VARCHAR(32) NOT NULL,
            v VARCHAR(255) NOT NULL,
            PRIMARY KEY (k)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $db->query(
        'CREATE TABLE IF NOT EXISTS city_transactions (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            resident_id INT UNSIGNED NOT NULL,
            amount INT NOT NULL,
            kind VARCHAR(16) NOT NULL,
            note VARCHAR(120) NOT NULL DEFAULT \'\',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY resident_id (resident_id, id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

function city_json(array $data, int $code = 200): void
{
    http_response_code($code);
    header('Content-Type: application/json');
    header('Cache-Control: no-store');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// ================= CONTURI =================
function city_start_session(mysqli $db, int $residentId): void
{
    $token = bin2hex(random_bytes(32));
    $hash = hash('sha256', $token);
    $ip = city_ip();
    $stmt = $db->prepare('INSERT INTO city_sessions (token_hash, resident_id, ip, last_seen) VALUES (?, ?, ?, NOW())');
    $stmt->bind_param('sis', $hash, $residentId, $ip);
    $stmt->execute();
    setcookie(CITY_TOKEN_COOKIE, $token, [
        'expires' => time() + 365 * 86400,
        'path' => '/',
        'httponly' => true,
        'secure' => !empty($_SERVER['HTTPS']),
        'samesite' => 'Lax',
    ]);
}

function city_end_session(mysqli $db): void
{
    $token = $_COOKIE[CITY_TOKEN_COOKIE] ?? '';
    if (is_string($token) && strlen($token) === 64) {
        $hash = hash('sha256', $token);
        $stmt = $db->prepare('DELETE FROM city_sessions WHERE token_hash = ?');
        $stmt->bind_param('s', $hash);
        $stmt->execute();
    }
    setcookie(CITY_TOKEN_COOKIE, '', ['expires' => time() - 3600, 'path' => '/', 'httponly' => true, 'samesite' => 'Lax']);
}

function city_current_resident(mysqli $db): ?array
{
    $token = $_COOKIE[CITY_TOKEN_COOKIE] ?? '';
    if (!is_string($token) || strlen($token) !== 64) return null;
    $hash = hash('sha256', $token);
    $stmt = $db->prepare('SELECT r.* FROM city_sessions s JOIN city_residents r ON r.id = s.resident_id WHERE s.token_hash = ?');
    $stmt->bind_param('s', $hash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc() ?: null;
    if ($row) {
        $stmt = $db->prepare('UPDATE city_sessions SET last_seen = NOW() WHERE token_hash = ?');
        $stmt->bind_param('s', $hash);
        $stmt->execute();
    }
    return $row;
}

// Sterge un cont: sesiunile lui, ce detinea revine Primăriei (chiriasii raman, dar platesc de acum
// chiria Primăriei), si se elibereaza un loc in limita IP-ului de pe care a fost facut.
function city_delete_resident(mysqli $db, int $id): void
{
    $stmt = $db->prepare('SELECT created_ip FROM city_residents WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    if (!$row) return;
    // chiriasii raman, dar platesc de acum chiria Primăriei pentru tipul de locuinta
    foreach (CITY_RENTS as $kind => $rent) {
        $stmt = $db->prepare('UPDATE city_residents r JOIN city_properties p ON p.id = r.home_id SET r.rent_amount = ? WHERE p.owner_id = ? AND r.id != ? AND p.kind = ?');
        $stmt->bind_param('iiis', $rent, $id, $id, $kind);
        $stmt->execute();
    }
    $stmt = $db->prepare('UPDATE city_properties SET owner_id = NULL, sale_price = NULL, rent_price = NULL, paid_price = 0 WHERE owner_id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $stmt = $db->prepare('DELETE FROM city_vehicles WHERE owner_id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $stmt = $db->prepare('DELETE FROM city_friends WHERE a = ? OR b = ?');
    $stmt->bind_param('ii', $id, $id);
    $stmt->execute();
    foreach (['DELETE FROM city_residents WHERE id = ?', 'DELETE FROM city_sessions WHERE resident_id = ?', 'DELETE FROM city_transactions WHERE resident_id = ?'] as $sql) {
        $stmt = $db->prepare($sql);
        $stmt->bind_param('i', $id);
        $stmt->execute();
    }
    $stmt = $db->prepare('UPDATE city_ips SET accounts = GREATEST(accounts, 1) - 1 WHERE ip = ?');
    $stmt->bind_param('s', $row['created_ip']);
    $stmt->execute();
}

function city_valid_name(string $name): bool
{
    return (bool)preg_match('/^[\p{L}\p{N}][\p{L}\p{N} ._\'-]{1,23}$/u', $name);
}
function city_clean_name(string $name): string
{
    return preg_replace('/\s+/u', ' ', trim($name));
}

// Toti locuitorii, cu locul in care stau (coordonatele vin din proprietatea lor).
const CITY_RESIDENT_SELECT = 'SELECT r.*, p.x AS px, p.y AS py, p.unit AS pu, p.kind AS pk, p.owner_id AS powner, w.kind AS jkind,
    (r.last_seen IS NOT NULL AND r.last_seen > NOW() - INTERVAL 2 MINUTE) AS online
    FROM city_residents r LEFT JOIN city_properties p ON p.id = r.home_id LEFT JOIN city_workplaces w ON w.id = r.job_id';

function city_public_resident(array $r): array
{
    $hasHome = $r['px'] !== null;
    return [
        'id' => (int)$r['id'],
        'u' => $r['username'],
        'e' => $r['emoji'],
        'x' => $hasHome ? (int)$r['px'] : null,
        'y' => $hasHome ? (int)$r['py'] : null,
        'h' => $hasHome ? (int)$r['home_id'] : null,
        'st' => $hasHome ? ((int)$r['powner'] === (int)$r['id'] ? 'own' : 'rent') : null,
        'j' => date('Y-m-d', strtotime($r['joined_at'])),
        'on' => (bool)($r['online'] ?? false),
        'w' => $r['job_id'] === null || $r['jkind'] === null ? null : (int)$r['job_id'],
        'jk' => $r['jkind'] ?? null,
    ];
}

function city_fetch_resident(mysqli $db, int $id): ?array
{
    $stmt = $db->prepare(CITY_RESIDENT_SELECT . ' WHERE r.id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

// ================= HARTA =================
function city_load_state(mysqli $db): ?array
{
    $res = $db->query('SELECT version, data FROM city_state WHERE id = 1');
    $row = $res ? $res->fetch_assoc() : null;
    if (!$row) return null;
    $data = json_decode($row['data'], true);
    if (!is_array($data)) return null;
    return ['version' => (int)$row['version'], 'data' => $data];
}

const CITY_BLOC_APTS = 12;      // apartamentele unui Bloc pus de admin (apts din city.js)

// [latime, inaltime] ale hartii salvate, sau null daca sunt in afara limitelor.
function city_map_size(array $data): ?array
{
    $w = (int)($data['w'] ?? CITY_DEFAULT_W);
    $h = (int)($data['h'] ?? CITY_DEFAULT_H);
    if ($w < 10 || $h < 10 || $w > CITY_MAX_SIDE || $h > CITY_MAX_SIDE || $w * $h > CITY_MAX_TILES) return null;
    return [$w, $h];
}

// Harta a fost marita spre vest/nord: tot ce e pe ea s-a mutat cu ($dx, $dy) patratele, deci si
// proprietatile si locurile de munca se muta - altfel city_sync_* le-ar vedea ca demolate.
// $dx, $dy >= 0; randurile sunt mutate de la capat spre inceput ca sa nu se loveasca de cheile unice.
function city_shift_map(mysqli $db, int $dx, int $dy): void
{
    if ($dx === 0 && $dy === 0) return;
    $stmt = $db->prepare('UPDATE city_properties SET x = x + ?, y = y + ? ORDER BY x DESC, y DESC, unit DESC');
    $stmt->bind_param('ii', $dx, $dy);
    $stmt->execute();
    $res = $db->query('SELECT id, wkey, kind, x, y FROM city_workplaces ORDER BY x DESC, y DESC');
    $upd = $db->prepare('UPDATE city_workplaces SET wkey = ?, x = ?, y = ? WHERE id = ?');
    while ($w = $res->fetch_assoc()) {
        $x = (int)$w['x'] + $dx;
        $y = (int)$w['y'] + $dy;
        $key = $w['wkey'];
        // cheile cu coordonate (magazine, cladiri) se refac; campurile ("field:cx,cy") se regrupeaza la sync
        if (strpos($key, 'shop:') === 0) $key = "shop:$x,$y";
        elseif (strpos($key, 'sp:') === 0) $key = 'sp:' . $w['kind'] . ":$x,$y";
        $id = (int)$w['id'];
        $upd->bind_param('siii', $key, $x, $y, $id);
        $upd->execute();
    }
}

// Ce proprietati exista pe harta: ["x,y,unit" => kind].
function city_map_properties(array $data): array
{
    $zone = base64_decode($data['zone'] ?? '', true);
    $level = base64_decode($data['level'] ?? '', true);
    $size = city_map_size($data);
    if (!$size) return [];
    [$mw] = $size;
    $n = $size[0] * $size[1];
    if ($zone === false || $level === false || strlen($zone) !== $n || strlen($level) !== $n) return [];
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $lv = ord($level[$i]);
        if (ord($zone[$i]) !== 1 || $lv < 1) continue;
        $x = $i % $mw;
        $y = intdiv($i, $mw);
        if ($lv >= 3) {
            for ($u = 0; $u < CITY_APTS_PER_BLOCK; $u++) $out["$x,$y,$u"] = 'apt';
        } else {
            $out["$x,$y,0"] = $lv === 1 ? 'house1' : 'house2';
        }
    }
    // blocurile puse ca cladiri: apartamentele stau pe patratelul din stanga-sus
    foreach ($data['specials'] ?? [] as $s) {
        if (is_array($s) && isset(CITY_HOME_SPECIALS[$s['t'] ?? ''])) $out[(int)$s['x'] . ',' . (int)$s['y'] . ',0'] = CITY_HOME_SPECIALS[$s['t']];
    }
    foreach ($data['specials'] ?? [] as $s) {
        if (!is_array($s) || ($s['t'] ?? '') !== 'bloc') continue;
        $x = (int)$s['x'];
        $y = (int)$s['y'];
        for ($u = 0; $u < CITY_BLOC_APTS; $u++) $out["$x,$y,$u"] = 'apt';
    }
    return $out;
}

// "Casa (11,10)" - sau "casa (11,10)" in mijlocul unei propozitii ($lower).
function city_property_label(array $p, bool $lower = false): string
{
    $name = CITY_KIND_NAMES[$p['kind']] ?? 'Proprietatea';
    if ($p['kind'] === 'apt') $name .= ' ' . ((int)$p['unit'] + 1);
    if ($lower) $name = mb_strtolower(mb_substr($name, 0, 1)) . mb_substr($name, 1);
    return $name . ' (' . $p['x'] . ',' . $p['y'] . ')';
}
function city_demolished_text(array $p): string
{
    return city_property_label($p) . ' a fost ' . ($p['kind'] === 'apt' ? 'demolat' : 'demolată') . ' - banii înapoi';
}

// Dupa ce adminul schimba harta: proprietatile noi apar ale Primăriei, cele care au disparut (casa
// daramata, sau o casa care a devenit bloc ori invers) se sterg - proprietarul isi primeste inapoi
// banii platiti, iar cine locuia acolo e mutat in chirie intr-un apartament liber.
// Căsuță -> Casă (si invers) e aceeasi casa, doar mai mare: proprietarul o pastreaza.
function city_sync_properties(mysqli $db, array $data): void
{
    $desired = city_map_properties($data);
    $db->begin_transaction();
    $res = $db->query('SELECT * FROM city_properties FOR UPDATE');
    while ($p = $res->fetch_assoc()) {
        $key = $p['x'] . ',' . $p['y'] . ',' . $p['unit'];
        $want = $desired[$key] ?? null;
        // Căsuță <-> Casă e aceeasi casa (se mareste); orice alt schimb de tip inseamna alta locuinta
        $sameFamily = $want !== null && ($want === $p['kind'] || (in_array($want, ['house1', 'house2'], true) && in_array($p['kind'], ['house1', 'house2'], true)));
        if ($sameFamily) {
            if ($want !== $p['kind']) {
                $stmt = $db->prepare('UPDATE city_properties SET kind = ? WHERE id = ?');
                $stmt->bind_param('si', $want, $p['id']);
                $stmt->execute();
            }
            unset($desired[$key]);
            continue;
        }
        $id = (int)$p['id'];
        if ($p['owner_id'] !== null && (int)$p['paid_price'] > 0) {
            city_money($db, (int)$p['owner_id'], (int)$p['paid_price'], 'refund', city_demolished_text($p));
        }
        $stmt = $db->prepare('UPDATE city_residents SET home_id = NULL, rent_amount = 0 WHERE home_id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $stmt = $db->prepare('DELETE FROM city_properties WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
    }
    $stmt = $db->prepare('INSERT INTO city_properties (x, y, unit, kind) VALUES (?, ?, ?, ?)');
    foreach ($desired as $key => $kind) {
        [$x, $y, $u] = array_map('intval', explode(',', $key));
        $stmt->bind_param('iiis', $x, $y, $u, $kind);
        $stmt->execute();
    }
    $db->commit();
    city_rehouse_homeless($db);
}

// ================= LOCURI DE MUNCA =================
// Ce locuri de munca exista pe harta: [wkey => [kind, name, x, y, slots]]. Cheile sunt stabile cat
// timp cladirea ramane pe loc, ca angajatii sa nu fie dati afara la fiecare salvare a hartii.
function city_map_workplaces(array $data): array
{
    $size = city_map_size($data) ?? [0, 0];
    $mw = $size[0];
    $n = $size[0] * $size[1];
    $zone = base64_decode($data['zone'] ?? '', true);
    $level = base64_decode($data['level'] ?? '', true);
    $crop = base64_decode($data['crop'] ?? '', true);
    $out = [];
    if ($zone !== false && $level !== false && strlen($zone) === $n && strlen($level) === $n) {
        $fields = [];
        for ($i = 0; $i < $n; $i++) {
            $x = $i % $mw;
            $y = intdiv($i, $mw);
            $z = ord($zone[$i]);
            $lv = min(3, ord($level[$i]));
            if ($z === 2 && $lv > 0) {
                $out["shop:$x,$y"] = ['shop', CITY_SHOP_NAMES[$lv], $x, $y, CITY_SHOP_SLOTS[$lv]];
            } elseif ($z === 3) {
                $key = intdiv($x, CITY_FIELD_CHUNK) . ',' . intdiv($y, CITY_FIELD_CHUNK);
                if (!isset($fields[$key])) $fields[$key] = ['x' => $x, 'y' => $y, 'n' => 0];
                $fields[$key]['n']++;
            }
        }
        foreach ($fields as $key => $f) {
            $slots = (int)ceil($f['n'] / CITY_FIELD_TILES_PER_JOB);
            $out["field:$key"] = ['field', 'Câmpul', $f['x'], $f['y'], $slots];
        }
    }
    foreach ($data['specials'] ?? [] as $s) {
        if (!is_array($s) || !isset(CITY_SPECIAL_SLOTS[$s['t'] ?? ''])) continue;
        $x = (int)$s['x'];
        $y = (int)$s['y'];
        $out['sp:' . $s['t'] . ":$x,$y"] = [$s['t'], CITY_SPECIAL_NAMES[$s['t']], $x, $y, CITY_SPECIAL_SLOTS[$s['t']]];
    }
    return $out;
}

// Ca la proprietati: locurile noi apar, cele disparute se sterg (angajatii lor devin someri), iar
// daca o cladire are acum mai putine locuri, pleaca ultimii angajati. Apoi somerii sunt angajati.
function city_sync_workplaces(mysqli $db, array $data): void
{
    $desired = city_map_workplaces($data);
    $res = $db->query('SELECT * FROM city_workplaces');
    $existing = [];
    while ($w = $res->fetch_assoc()) $existing[$w['wkey']] = $w;
    foreach ($existing as $key => $w) {
        $id = (int)$w['id'];
        if (!isset($desired[$key])) {
            $db->query('UPDATE city_residents SET job_id = NULL WHERE job_id = ' . $id);
            $db->query('DELETE FROM city_workplaces WHERE id = ' . $id);
            continue;
        }
        [$kind, $name, $x, $y, $slots] = $desired[$key];
        $stmt = $db->prepare('UPDATE city_workplaces SET name = ?, x = ?, y = ?, slots = ? WHERE id = ?');
        $stmt->bind_param('siiii', $name, $x, $y, $slots, $id);
        $stmt->execute();
        $workers = (int)$db->query('SELECT COUNT(*) FROM city_residents WHERE job_id = ' . $id)->fetch_row()[0];
        if ($workers > $slots) {
            $db->query('UPDATE city_residents SET job_id = NULL WHERE job_id = ' . $id . ' ORDER BY joined_at DESC, id DESC LIMIT ' . ($workers - $slots));
        }
        unset($desired[$key]);
    }
    $stmt = $db->prepare('INSERT INTO city_workplaces (wkey, kind, name, x, y, slots) VALUES (?, ?, ?, ?, ?, ?)');
    foreach ($desired as $key => [$kind, $name, $x, $y, $slots]) {
        if ($slots < 1) continue;
        $stmt->bind_param('sssiii', $key, $kind, $name, $x, $y, $slots);
        $stmt->execute();
    }
    city_hire_unemployed($db);
}

// Angajeaza un somer intr-un loc de munca liber, ales la intamplare. false = nu e niciun loc liber.
function city_hire(mysqli $db, int $residentId): bool
{
    $res = $db->query('SELECT w.id FROM city_workplaces w
        WHERE (SELECT COUNT(*) FROM city_residents r WHERE r.job_id = w.id) < w.slots ORDER BY RAND() LIMIT 5');
    $candidates = [];
    while ($row = $res->fetch_assoc()) $candidates[] = (int)$row['id'];
    foreach ($candidates as $wid) {
        if (city_take_job($db, $residentId, $wid)) return true;
    }
    return false;
}

// Muta un locuitor pe un loc de munca anume, daca mai e loc acolo (verificat sub lacat, ca doi
// jucatori sa nu ia ultimul loc deodata).
function city_take_job(mysqli $db, int $residentId, int $workplaceId): bool
{
    $db->begin_transaction();
    $stmt = $db->prepare('SELECT slots FROM city_workplaces WHERE id = ? FOR UPDATE');
    $stmt->bind_param('i', $workplaceId);
    $stmt->execute();
    $w = $stmt->get_result()->fetch_assoc();
    if (!$w) { $db->rollback(); return false; }
    $stmt = $db->prepare('SELECT COUNT(*) FROM city_residents WHERE job_id = ? AND id != ?');
    $stmt->bind_param('ii', $workplaceId, $residentId);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_row()[0] >= (int)$w['slots']) { $db->rollback(); return false; }
    $stmt = $db->prepare('UPDATE city_residents SET job_id = ? WHERE id = ?');
    $stmt->bind_param('ii', $workplaceId, $residentId);
    $stmt->execute();
    $db->commit();
    return true;
}

function city_hire_unemployed(mysqli $db): void
{
    $res = $db->query('SELECT id FROM city_residents WHERE job_id IS NULL ORDER BY joined_at, id');
    $ids = [];
    while ($row = $res->fetch_assoc()) $ids[] = (int)$row['id'];
    foreach ($ids as $id) if (!city_hire($db, $id)) break;
}

// Locurile de munca, pentru harta: cine lucreaza unde si cate locuri mai sunt.
function city_public_workplaces(mysqli $db): array
{
    $res = $db->query('SELECT w.*, (SELECT COUNT(*) FROM city_residents r WHERE r.job_id = w.id) AS workers FROM city_workplaces w ORDER BY w.y, w.x');
    $out = [];
    while ($w = $res->fetch_assoc()) {
        $out[] = ['id' => (int)$w['id'], 'k' => $w['kind'], 'n' => $w['name'], 'x' => (int)$w['x'], 'y' => (int)$w['y'], 'sl' => (int)$w['slots'], 'wk' => (int)$w['workers']];
    }
    return $out;
}

// Proprietatile si locurile de munca se refac din harta de fiecare data cand adminul salveaza; daca
// harta are o versiune pe care n-am vazut-o inca (de ex. imediat dupa un update), o facem acum.
function city_sync_if_needed(mysqli $db): void
{
    $state = city_load_state($db);
    if (!$state) return;
    $res = $db->query("SELECT v FROM city_meta WHERE k = 'synced_version'");
    $row = $res ? $res->fetch_assoc() : null;
    if ($row && (int)$row['v'] === $state['version']) return;
    city_sync_map($db, $state['data'], $state['version']);
}
function city_sync_map(mysqli $db, array $data, int $version): void
{
    city_sync_properties($db, $data);
    city_sync_workplaces($db, $data);
    city_mark_synced($db, $version);
}
function city_mark_synced(mysqli $db, int $version): void
{
    $stmt = $db->prepare("INSERT INTO city_meta (k, v) VALUES ('synced_version', ?) ON DUPLICATE KEY UPDATE v = VALUES(v)");
    $v = (string)$version;
    $stmt->bind_param('s', $v);
    $stmt->execute();
}

// Chiria pe zi pentru cine se muta acum intr-o proprietate goala, sau null daca nu se poate inchiria:
// a Primăriei -> chiria ei; a unui jucator -> chiria ceruta de el, iar daca n-a cerut una dar a pus-o
// la vanzare, chiria Primăriei pentru acelasi tip de locuinta (cat timp asteapta un cumparator).
function city_effective_rent(array $p): ?int
{
    if ($p['owner_id'] === null) return CITY_RENTS[$p['kind']];
    if ($p['rent_price'] !== null) return (int)$p['rent_price'];
    if ($p['sale_price'] !== null) return CITY_RENTS[$p['kind']];
    return null;
}

// Muta un locuitor fara casa in chirie, in ordinea asta:
//   1. intr-o casa sau un apartament gol al unui jucator, care il ofera spre inchiriere;
//   2. intr-o casa sau un apartament gol de vanzare (al Primăriei sau al unui jucator);
//   3. altfel nicaieri - asteapta pana se elibereaza sau apare ceva. Atunci intoarce false.
function city_auto_rent(mysqli $db, int $residentId): bool
{
    $free = 'FROM city_properties p LEFT JOIN city_residents r ON r.home_id = p.id WHERE r.id IS NULL';
    $tiers = [
        "SELECT p.* $free AND p.owner_id IS NOT NULL AND p.owner_id != $residentId AND p.rent_price IS NOT NULL ORDER BY RAND() LIMIT 1",
        "SELECT p.* $free AND (p.owner_id IS NULL OR (p.sale_price IS NOT NULL AND p.owner_id != $residentId)) ORDER BY RAND() LIMIT 1",
    ];
    foreach ($tiers as $sql) {
        for ($try = 0; $try < 3; $try++) {
            $res = $db->query($sql);
            $p = $res ? $res->fetch_assoc() : null;
            if (!$p) break;
            try {
                $stmt = $db->prepare('UPDATE city_residents SET home_id = ?, rent_amount = ? WHERE id = ? AND home_id IS NULL');
                $rent = city_effective_rent($p);
                $stmt->bind_param('iii', $p['id'], $rent, $residentId);
                if ($stmt->execute()) return true;
            } catch (mysqli_sql_exception $e) {
                // altcineva a luat locuinta in aceeasi clipa (home_id e unic) - incercam alta
            }
        }
    }
    return false;
}

function city_rehouse_homeless(mysqli $db): void
{
    $res = $db->query('SELECT id FROM city_residents WHERE home_id IS NULL ORDER BY joined_at, id');
    $ids = [];
    while ($row = $res->fetch_assoc()) $ids[] = (int)$row['id'];
    foreach ($ids as $id) if (!city_auto_rent($db, $id)) break;
}

// ================= BANI =================
function city_money(mysqli $db, int $residentId, int $amount, string $kind, string $note): void
{
    $stmt = $db->prepare('UPDATE city_residents SET balance = balance + ? WHERE id = ?');
    $stmt->bind_param('ii', $amount, $residentId);
    $stmt->execute();
    $stmt = $db->prepare('INSERT INTO city_transactions (resident_id, amount, kind, note) VALUES (?, ?, ?, ?)');
    $note = mb_substr($note, 0, 120);
    $stmt->bind_param('iiss', $residentId, $amount, $kind, $note);
    $stmt->execute();
}

function city_lei(int $n): string
{
    return number_format($n, 0, ',', '.') . ' LEI';
}

// "Fabrica mică" -> "fabrica mică", dar "Lidl" ramane "Lidl"
function city_lower_first(string $name): string
{
    foreach (CITY_PROPER_NAMES as $p) if (strpos($name, $p) === 0) return $name;
    return mb_strtolower(mb_substr($name, 0, 1)) . mb_substr($name, 1);
}

// Cheltuielile zilei: iesirile (cumparaturi, bar, restaurant, mall, distractii...) din ziua respectiva, la
// locurile care exista pe harta ($kinds = tipurile de locuri de munca de pe harta). Aceeasi zi + acelasi
// locuitor = aceleasi cheltuieli. Intoarce [[eticheta, suma], ...]. $dow: 0 duminica ... 6 sambata.
const CITY_SPEND = [
    // grup => [tipuri de locuri, eticheta, suma min, suma max]
    'shop'    => [['shop', 'market', 'lidl', 'kaufland', 'penny', 'carrefour'], 'Cumpărături', 40, 150],
    'mall'    => [['mall'], 'Mall', 100, 400],
    'bar'     => [['bar'], 'Bar', 30, 100],
    'food'    => [['restaurant'], 'Restaurant', 60, 180],
    'fun'     => [['amusement'], 'Parc de distracții', 50, 150],
    'pool'    => [['pool'], 'Piscină', 20, 50],
    'stadium' => [['stadium_s', 'stadium_m', 'stadium_l'], 'Stadion', 40, 120],
];
function city_day_spending(int $residentId, string $date, int $dow, array $kinds): array
{
    $groups = [];
    foreach (CITY_SPEND as $g => $d) if (array_intersect($d[0], $kinds)) $groups[] = $g;
    if (!$groups) return [];
    $h = function (string $k) use ($residentId, $date): float { return (crc32("$residentId|$date|$k") % 100000) / 100000; };
    $weekend = $dow === 0 || $dow === 6;
    $outings = $weekend ? 1 + (int)floor($h('n') * 3) : ((int)($h('lunch') < 0.45) + (int)($h('after') < 0.5) + (int)($h('eve') < 0.25));
    $out = [];
    for ($k = 0; $k < $outings; $k++) {
        $d = CITY_SPEND[$groups[(int)floor($h("g$k") * count($groups))]];
        $out[] = [$d[1], (int)(round(($d[2] + $h("a$k") * ($d[3] - $d[2])) / 5) * 5)];
    }
    return $out;
}

// Kilometrii parcursi in ziua asta cu masina personala (prima a jucatorului): naveta casa-serviciu in zilele
// lucratoare + cate o tura dus-intors la fiecare iesire. Distantele sunt cele de pe harta (patratele x
// CITY_KM_PER_TILE). Se adauga la kilometrajul masinii; intoarce kilometrii adaugati.
function city_drive_day(mysqli $db, int $residentId, string $date, int $dow, int $outings): int
{
    $stmt = $db->prepare('SELECT id FROM city_vehicles WHERE owner_id = ? ORDER BY id LIMIT 1');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $car = $stmt->get_result()->fetch_assoc();
    if (!$car) return 0;
    $stmt = $db->prepare('SELECT p.x AS hx, p.y AS hy, w.x AS wx, w.y AS wy FROM city_residents r
        LEFT JOIN city_properties p ON p.id = r.home_id LEFT JOIN city_workplaces w ON w.id = r.job_id WHERE r.id = ?');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $g = $stmt->get_result()->fetch_assoc();
    $tiles = 0.0;
    if ($g['hx'] !== null && $g['wx'] !== null && $dow >= 1 && $dow <= 5) $tiles += 2 * (abs($g['hx'] - $g['wx']) + abs($g['hy'] - $g['wy']));
    for ($k = 0; $k < $outings; $k++) $tiles += 2 * (6 + 20 * (crc32("$residentId|$date|km$k") % 1000) / 1000);
    $km = (int)round($tiles * CITY_KM_PER_TILE);
    if ($km > 0) {
        $stmt = $db->prepare('UPDATE city_vehicles SET km = km + ? WHERE id = ?');
        $stmt->bind_param('ii', $km, $car['id']);
        $stmt->execute();
    }
    return $km;
}

// Din salariul brut: CAS, CASS, impozit si ce ramane net.
function city_salary_taxes(int $gross): array
{
    $cas = (int)round($gross * CITY_TAX_CAS / 100);
    $cass = (int)round($gross * CITY_TAX_CASS / 100);
    $income = (int)round(($gross - $cas - $cass) * CITY_TAX_INCOME / 100);
    return ['cas' => $cas, 'cass' => $cass, 'income' => $income, 'total' => $cas + $cass + $income, 'net' => $gross - $cas - $cass - $income];
}

// Salariul si chiria, o data pe zi, in prima zi in care intri in oras. Zilele in care nu intri nu
// aduc nici salariu, nici chirie. Intoarce ce s-a intamplat azi, sau null daca era deja facut.
function city_daily(mysqli $db, int $residentId): ?array
{
    $today = date('Y-m-d');
    $db->begin_transaction();
    $stmt = $db->prepare('SELECT r.username, r.last_daily, r.home_id, r.rent_amount, w.kind AS jkind FROM city_residents r LEFT JOIN city_workplaces w ON w.id = r.job_id WHERE r.id = ? FOR UPDATE');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $me = $stmt->get_result()->fetch_assoc();
    if (!$me || $me['last_daily'] === $today) { $db->commit(); return null; }

    $job = $me['jkind'] !== null ? CITY_JOBS[$me['jkind']] : null;
    $salary = $job ? $job['salary'] : CITY_UNEMPLOYED_PAY;
    city_money($db, $residentId, $salary, 'salary', ($job ? 'Salariul brut de ' . mb_strtolower($job['title']) : 'Ajutorul de șomaj') . ' pe ' . date('d.m'));
    $taxes = 0;
    if ($job) {
        $t = city_salary_taxes($salary);
        $taxes = $t['total'];
        city_money($db, $residentId, -$taxes, 'tax', 'Taxe pe salariu: CAS ' . city_lei($t['cas']) . ', CASS ' . city_lei($t['cass']) . ', impozit ' . city_lei($t['income']));
    }
    $rent = 0;
    if ($me['home_id'] !== null) {
        $stmt = $db->prepare('SELECT * FROM city_properties WHERE id = ?');
        $stmt->bind_param('i', $me['home_id']);
        $stmt->execute();
        $home = $stmt->get_result()->fetch_assoc();
        if ($home && (int)$home['owner_id'] !== $residentId) {
            $rent = (int)$me['rent_amount'];
            if ($rent > 0) {
                city_money($db, $residentId, -$rent, 'rent', 'Chiria pe ' . date('d.m') . ' - ' . city_property_label($home));
                if ($home['owner_id'] !== null) {
                    city_money($db, (int)$home['owner_id'], $rent, 'rent_in', 'Chirie de la ' . $me['username'] . ' - ' . city_property_label($home));
                }
            }
        }
    }
    // cheltuielile zilei, din ce a ramas dupa salariu si chirie (nu se intra pe minus din cheltuieli)
    $spent = 0;
    $res = $db->query('SELECT DISTINCT kind FROM city_workplaces');
    $kinds = $res ? array_column($res->fetch_all(MYSQLI_ASSOC), 'kind') : [];
    $stmt = $db->prepare('SELECT balance FROM city_residents WHERE id = ?');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $left = (int)$stmt->get_result()->fetch_assoc()['balance'];
    $outs = city_day_spending($residentId, $today, (int)date('w'), $kinds);
    foreach ($outs as $o) {
        $amt = min($o[1], $left);
        if ($amt <= 0) break;
        city_money($db, $residentId, -$amt, 'spend', $o[0] . ' pe ' . date('d.m'));
        $left -= $amt;
        $spent += $amt;
    }
    $km = city_drive_day($db, $residentId, $today, (int)date('w'), count($outs));
    $stmt = $db->prepare('UPDATE city_residents SET last_daily = ? WHERE id = ?');
    $stmt->bind_param('si', $today, $residentId);
    $stmt->execute();
    $db->commit();
    return ['salary' => $salary, 'taxes' => $taxes, 'rent' => $rent, 'spent' => $spent, 'km' => $km, 'job' => $job ? $job['title'] : null];
}

// Toate proprietatile, pentru harta: ce e de vanzare (s = pret), ce se poate inchiria (r = chirie pe
// zi), al cui e (o) si cine locuieste acolo (oc). Ale Primăriei sunt mereu de vanzare, iar
// apartamentele ei mereu de inchiriat cand sunt libere.
function city_public_properties(mysqli $db): array
{
    $res = $db->query('SELECT p.*, r.id AS occ FROM city_properties p LEFT JOIN city_residents r ON r.home_id = p.id ORDER BY p.y, p.x, p.unit');
    $out = [];
    while ($p = $res->fetch_assoc()) {
        $cityOwned = $p['owner_id'] === null;
        $out[] = [
            'id' => (int)$p['id'], 'x' => (int)$p['x'], 'y' => (int)$p['y'], 'u' => (int)$p['unit'], 'k' => $p['kind'],
            'o' => $cityOwned ? null : (int)$p['owner_id'],
            's' => $cityOwned ? CITY_PRICES[$p['kind']] : ($p['sale_price'] === null ? null : (int)$p['sale_price']),
            'r' => city_effective_rent($p),
            'ro' => $p['rent_price'] !== null,   // proprietarul a ales singur sa o inchirieze
            'oc' => $p['occ'] === null ? null : (int)$p['occ'],
        ];
    }
    return $out;
}

function city_me_info(mysqli $db, int $residentId, ?array $daily = null): array
{
    $stmt = $db->prepare('SELECT r.balance, r.home_id, r.rent_amount, r.last_daily, hp.owner_id AS home_owner,
            w.id AS wid, w.kind AS jkind, w.name AS wname, w.x AS wx, w.y AS wy
        FROM city_residents r LEFT JOIN city_workplaces w ON w.id = r.job_id LEFT JOIN city_properties hp ON hp.id = r.home_id WHERE r.id = ?');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $me = $stmt->get_result()->fetch_assoc();
    $stmt = $db->prepare('SELECT amount, kind, note, created_at FROM city_transactions WHERE resident_id = ? ORDER BY id DESC LIMIT 10');
    $stmt->bind_param('i', $residentId);
    $stmt->execute();
    $res = $stmt->get_result();
    $history = [];
    while ($t = $res->fetch_assoc()) {
        $history[] = ['a' => (int)$t['amount'], 'k' => $t['kind'], 'n' => $t['note'], 't' => date('d.m H:i', strtotime($t['created_at']))];
    }
    return [
        'balance' => (int)$me['balance'],
        'home' => $me['home_id'] === null ? null : (int)$me['home_id'],
        'rent' => (int)$me['rent_amount'],
        'job' => $me['jkind'] === null ? null : [
            'id' => (int)$me['wid'], 'k' => $me['jkind'], 'title' => CITY_JOBS[$me['jkind']]['title'],
            'salary' => CITY_JOBS[$me['jkind']]['salary'], 'place' => $me['wname'], 'x' => (int)$me['wx'], 'y' => (int)$me['wy'],
        ],
        'daily' => $daily,
        'history' => $history,
        'payslip' => city_payslip($db, $residentId, $me),
        'vehicles' => city_my_vehicles($db, $residentId),
    ];
}

// Fluturasul de salariu: ce primesti si ce platesti intr-o zi, cu jobul si casa de acum.
// Chiriile de la chiriasii tai vin doar in zilele in care trec ei pe aici, deci sunt "pana la".
function city_payslip(mysqli $db, int $residentId, array $me): array
{
    $job = $me['jkind'] !== null ? CITY_JOBS[$me['jkind']] : null;
    $gross = $job ? $job['salary'] : CITY_UNEMPLOYED_PAY;
    $t = $job ? city_salary_taxes($gross) : ['cas' => 0, 'cass' => 0, 'income' => 0, 'total' => 0, 'net' => $gross];
    $rent = ($me['home_id'] !== null && (int)$me['home_owner'] !== $residentId) ? (int)$me['rent_amount'] : 0;
    $stmt = $db->prepare('SELECT COALESCE(SUM(r.rent_amount), 0) s, COUNT(*) n FROM city_residents r JOIN city_properties p ON p.id = r.home_id WHERE p.owner_id = ? AND r.id <> ?');
    $stmt->bind_param('ii', $residentId, $residentId);
    $stmt->execute();
    $in = $stmt->get_result()->fetch_assoc();
    // cheltuielile ultimei zile platite
    $spend = [];
    if ($me['last_daily'] !== null) {
        $stmt = $db->prepare("SELECT note, -amount a FROM city_transactions WHERE resident_id = ? AND kind = 'spend' AND DATE(created_at) = ? ORDER BY id");
        $stmt->bind_param('is', $residentId, $me['last_daily']);
        $stmt->execute();
        foreach ($stmt->get_result()->fetch_all(MYSQLI_ASSOC) as $sp) $spend[] = ['n' => preg_replace('/ pe \d\d\.\d\d$/', '', $sp['note']), 'a' => (int)$sp['a']];
    }
    $spent = array_sum(array_column($spend, 'a'));
    return [
        'spend' => $spent, 'spend_items' => $spend,
        'job' => $job ? $job['title'] : null,
        'gross' => $gross, 'cas' => $t['cas'], 'cass' => $t['cass'], 'income' => $t['income'], 'taxes' => $t['total'],
        'rent' => $rent, 'rent_in' => (int)$in['s'], 'tenants' => (int)$in['n'],
        'total' => $t['net'] - $rent + (int)$in['s'] - $spent,
        'balance' => (int)$me['balance'],
        'paid_today' => $me['last_daily'] === date('Y-m-d'),
        'rates' => [CITY_TAX_CAS, CITY_TAX_CASS, CITY_TAX_INCOME],
    ];
}

// ================= PRIETENI =================
// Prietenii mei si cererile: friends = id-urile prietenilor, incoming = cine mi-a cerut prietenia
// (cel mai nou primul), outgoing = cui i-am cerut eu si inca n-a raspuns.
function city_social(mysqli $db, int $id): array
{
    $stmt = $db->prepare('SELECT a, b, status FROM city_friends WHERE a = ? OR b = ? ORDER BY created_at DESC');
    $stmt->bind_param('ii', $id, $id);
    $stmt->execute();
    $res = $stmt->get_result();
    $out = ['friends' => [], 'incoming' => [], 'outgoing' => [], 'max' => CITY_MAX_FRIENDS];
    while ($f = $res->fetch_assoc()) {
        $other = (int)$f['a'] === $id ? (int)$f['b'] : (int)$f['a'];
        if ($f['status'] === 'friends') $out['friends'][] = $other;
        elseif ((int)$f['b'] === $id) $out['incoming'][] = $other;
        else $out['outgoing'][] = $other;
    }
    return $out;
}
function city_friend_count(mysqli $db, int $id): int
{
    $stmt = $db->prepare("SELECT COUNT(*) n FROM city_friends WHERE (a = ? OR b = ?) AND status = 'friends'");
    $stmt->bind_param('ii', $id, $id);
    $stmt->execute();
    return (int)$stmt->get_result()->fetch_assoc()['n'];
}

// Masinile mele: [{id, m (model), c (culoare), p (cat s-a platit)}].
// Valoarea de acum a unei masini: pretul de catalog, scazut dupa vechime, kilometri si cati proprietari a avut.
function city_car_value(array $v): int
{
    $price = city_car_base((string)($v['brand'] ?? ''), $v['model']);
    $days = max(0, (int)floor((time() - strtotime($v['built_at'] ?: $v['created_at'])) / 86400));
    $f = pow(0.88, $days / 365) * max(0.35, 1 - (int)$v['km'] / 350000) * pow(0.96, max(0, (int)$v['owners'] - 1));
    return (int)(round($price * max(0.12, $f) / 50) * 50);
}
function city_car_row(array $v): array
{
    return [
        'id' => (int)$v['id'], 'b' => (string)($v['brand'] ?? ''), 'm' => $v['model'], 'n' => city_car_name((string)($v['brand'] ?? ''), $v['model']), 'c' => $v['color'], 'p' => (int)$v['paid'],
        'km' => (int)$v['km'], 'ow' => (int)$v['owners'], 'age' => max(0, (int)floor((time() - strtotime($v['built_at'] ?: $v['created_at'])) / 86400)),
        'v' => city_car_value($v), 'l' => $v['listed_price'] === null ? null : (int)$v['listed_price'],
    ];
}
function city_my_vehicles(mysqli $db, int $id): array
{
    $stmt = $db->prepare('SELECT * FROM city_vehicles WHERE owner_id = ? ORDER BY id');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $out = [];
    foreach ($stmt->get_result()->fetch_all(MYSQLI_ASSOC) as $v) $out[] = city_car_row($v);
    return $out;
}
// Masinile scoase la vanzare (ale jucatorilor si stocul de demo al parcului auto): cu vanzatorul (s = nume, 0 = parcul).
function city_used_cars(mysqli $db): array
{
    $res = $db->query('SELECT v.*, r.username FROM city_vehicles v LEFT JOIN city_residents r ON r.id = v.owner_id WHERE v.listed_price IS NOT NULL ORDER BY v.listed_price, v.id');
    $out = [];
    while ($v = $res->fetch_assoc()) { $row = city_car_row($v); $row['o'] = (int)$v['owner_id']; $row['s'] = $v['username']; $out[] = $row; }
    return $out;
}
function city_has_workplace_kind(mysqli $db, string $kind): bool
{
    $stmt = $db->prepare('SELECT 1 FROM city_workplaces WHERE kind = ? LIMIT 1');
    $stmt->bind_param('s', $kind);
    $stmt->execute();
    return (bool)$stmt->get_result()->fetch_row();
}
// Masina cu care circula fiecare locuitor (prima cumparata): [id locuitor => [model, culoare]].
function city_public_cars(mysqli $db): array
{
    $res = $db->query('SELECT owner_id, model, color FROM city_vehicles WHERE owner_id > 0 ORDER BY id DESC');
    $out = [];
    while ($v = $res->fetch_assoc()) $out[(int)$v['owner_id']] = [$v['model'], $v['color']];   // DESC: ramane cea mai veche
    return $out;
}

// Marcile pentru client: cheie => {n, t, b: {caroserie: pret de baza}}.
function city_brands_public(): array
{
    $out = [];
    foreach (CITY_BRANDS as $k => $b) {
        $bodies = [];
        foreach ($b[3] as $body) $bodies[$body] = city_car_base($k, $body);
        $out[$k] = ['n' => $b[0], 't' => $b[1], 'b' => $bodies];
    }
    return $out;
}
function city_colors_public(): array
{
    $out = [];
    foreach (CITY_CAR_COLOR_INFO as $hex => $c) $out[] = ['c' => $hex, 'n' => $c[0], 'x' => $c[1]];
    return $out;
}

function city_prices_public(): array
{
    return ['house1' => CITY_PRICES['house1'], 'house2' => CITY_PRICES['house2'], 'apt' => CITY_PRICES['apt'], 'rents' => CITY_RENTS, 'jobs' => CITY_JOBS, 'unemployed' => CITY_UNEMPLOYED_PAY, 'start' => CITY_START_BALANCE, 'cars' => CITY_CARS, 'brands' => city_brands_public(), 'colors' => city_colors_public(), 'maxCars' => CITY_MAX_CARS, 'carResale' => CITY_CAR_RESALE];
}
