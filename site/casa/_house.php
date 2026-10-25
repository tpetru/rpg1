<?php
// Multi-house support for /casa - one shared database and codebase, every casa_* table scoped by
// a house_id column, so more than one household's data can live side by side without colliding
// (two houses will both have a "bucatarie", for instance). Required right after _db.php on every
// page/endpoint, same convention as _auth.php.

const CASA_HOUSE_NAME_MAX = 60;

// Toate preturile sunt acum in LEI nativ (vezi migrarea casa_migrate_prices_eur_to_lei - valorile
// vechi, introduse cand totul era in EUR, au fost inmultite o singura data cu rata de mai jos ca sa
// insemne in continuare acelasi cost real). Sumele/totalurile primesc un tooltip cu echivalentul in
// EUR (impartit la aceeasi rata) la hover, doar ca reper - nu se mai stocheaza nimic in EUR.
const CASA_EUR_TO_LEI = 5.25;

function casa_format_lei(float $amountLei): string
{
    return number_format($amountLei, 2, ',', '.') . ' LEI';
}

function casa_eur_title(float $amountLei): string
{
    return number_format($amountLei / CASA_EUR_TO_LEI, 2, ',', '.') . ' EUR';
}

// Every casa_* table that needs a house_id column - kept as one list here instead of scattering the
// same ALTER-TABLE migration across each table's own page.
const CASA_HOUSE_SCOPED_TABLES = [
    'casa_construction_items',
    'casa_design_colors',
    'casa_design_notes',
    'casa_design_photo_meta',
    'casa_design_photo_ratings',
    'casa_design_photo_winners',
    'casa_design_prices',
    'casa_design_status',
    'casa_journal',
    'casa_links',
    'casa_price_history',
    'casa_price_products',
];

// The starter set of empty room folders a brand new house gets, matching what Chicerea already has
// on disk - so the design page immediately has its standard rooms ready for photos.
const CASA_STARTER_ROOMS = ['living', 'bucatarie', 'dormitor', 'baie', 'hol'];

// Creates casa_houses, adds house_id to every table in CASA_HOUSE_SCOPED_TABLES if missing, and -
// only the first time this ever runs, when casa_houses is empty - seeds a "Chicerea" house from the
// pre-multi-house data and backfills every existing row to it. Safe to call on every request.
function casa_ensure_house_schema(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_houses (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            slug VARCHAR(60) NOT NULL,
            name VARCHAR(100) NOT NULL,
            password VARCHAR(100) NOT NULL DEFAULT \'\',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY slug (slug)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Migration: casa_houses existed before each house had its own password (the whole module
    // shared one login) - add the column and default any pre-existing house to a placeholder
    // password, so nothing that already worked suddenly locks anyone out. Can't reuse the old
    // shared owner password (2026) here - that's now reserved for the admin page, and a house
    // password equal to it would make that house unreachable (2026 always routes to admin first).
    $hasPasswordCol = $mysqli->query("SHOW COLUMNS FROM casa_houses LIKE 'password'");
    if ($hasPasswordCol && $hasPasswordCol->num_rows === 0) {
        $mysqli->query("ALTER TABLE casa_houses ADD COLUMN password VARCHAR(100) NOT NULL DEFAULT '' AFTER name");
        $mysqli->query("UPDATE casa_houses SET password = '2027' WHERE password = ''");
    }
    // Same reasoning, ongoing: if any house's password ever ends up equal to the admin password
    // (this migration included), it would be permanently unreachable - reset it to the same
    // placeholder so it's at least reachable, then change it for real from /admin.php.
    $mysqli->query('UPDATE casa_houses SET password = \'2027\' WHERE password = \'' . CASA_ADMIN_PASSWORD . '\'');

    $countRes = $mysqli->query('SELECT COUNT(*) AS c FROM casa_houses');
    $isFirstRun = $countRes && (int)$countRes->fetch_assoc()['c'] === 0;

    $chicereaId = null;
    if ($isFirstRun) {
        $slug = 'Chicerea';
        $name = 'Chicerea';
        $password = '2027';
        $stmt = $mysqli->prepare('INSERT INTO casa_houses (slug, name, password) VALUES (?, ?, ?)');
        $stmt->bind_param('sss', $slug, $name, $password);
        $stmt->execute();
        $chicereaId = $mysqli->insert_id;
    }

    foreach (CASA_HOUSE_SCOPED_TABLES as $table) {
        $hasCol = $mysqli->query("SHOW COLUMNS FROM $table LIKE 'house_id'");
        if ($hasCol && $hasCol->num_rows === 0) {
            $mysqli->query("ALTER TABLE $table ADD COLUMN house_id INT UNSIGNED NULL FIRST");
        }
        if ($chicereaId !== null) {
            $mysqli->query("UPDATE $table SET house_id = $chicereaId WHERE house_id IS NULL");
        }
    }

    // These tables key rows by room_slug (+category/filename/etc) alone, which collides across
    // houses (two houses will both have a "bucatarie") - fold house_id into the front of each
    // table's existing unique/primary key so rows stay disambiguated per house.
    casa_migrate_house_key($mysqli, 'casa_design_colors', 'PRIMARY', 'PRIMARY', ['house_id', 'room_slug']);
    casa_migrate_house_key($mysqli, 'casa_design_status', 'UNIQUE', 'room_category_step', ['house_id', 'room_slug', 'category', 'step']);
    casa_migrate_house_key($mysqli, 'casa_design_prices', 'UNIQUE', 'room_category', ['house_id', 'room_slug', 'category']);
    casa_migrate_house_key($mysqli, 'casa_design_photo_ratings', 'UNIQUE', 'room_filename_ip', ['house_id', 'room_slug', 'filename', 'ip']);
    casa_migrate_house_key($mysqli, 'casa_design_photo_meta', 'UNIQUE', 'room_filename', ['house_id', 'room_slug', 'filename']);
    casa_migrate_house_key($mysqli, 'casa_design_photo_winners', 'PRIMARY', 'PRIMARY', ['house_id', 'room_slug', 'filename']);

    // Trebuie sa ruleze inainte de conversia EUR->LEI de mai jos - populeaza casa_design_checklist_items
    // din vechile casa_design_status/casa_design_prices (inca in EUR), ca acele valori sa apuce sa fie
    // convertite si ele, indiferent de pagina cu care userul a "lovit" prima data update-ul.
    // require (nu require_once): checklist_defs.php seteaza doar o variabila (fara functii/clase),
    // iar paginile care il folosesc si ele (design/index.php etc.) fac propriul require_once separat -
    // daca am folosi require_once aici, PHP ar considera fisierul deja inclus si le-ar lasa fara
    // variabila $casaChecklistDefs in scope-ul lor global.
    require __DIR__ . '/design/checklist_defs.php';
    casa_design_checklist_ensure_schema($mysqli, $casaChecklistDefs);

    casa_migrate_prices_eur_to_lei($mysqli);
}

// Toate preturile erau introduse pana acum in EUR; de acum inainte totul (afisaj + input-uri) e in
// LEI nativ - o singura data, la prima incarcare de pagina de dupa update, inmultim cu rata fixata
// (CASA_EUR_TO_LEI) tot ce era deja in baza de date, ca sumele deja introduse sa insemne in
// continuare acelasi cost real, doar exprimat in LEI. Dupa asta, orice suma noua se scrie direct
// in LEI, fara nicio conversie. Marcata in casa_migrations ca sa ruleze o singura data vreodata.
function casa_migrate_prices_eur_to_lei(mysqli $mysqli): void
{
    $mysqli->query(
        "CREATE TABLE IF NOT EXISTS casa_migrations (
            name VARCHAR(64) NOT NULL,
            applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );
    $migrationName = 'prices_eur_to_lei_v1';
    $check = $mysqli->query("SELECT 1 FROM casa_migrations WHERE name = '$migrationName'");
    if ($check && $check->num_rows > 0) return;

    $rate = CASA_EUR_TO_LEI;
    $moneyColumns = [
        'casa_construction_items' => ['price_estimate', 'price_actual'],
        'casa_design_checklist_items' => ['price_estimate', 'price_actual'],
        'casa_journal' => ['price'],
    ];
    foreach ($moneyColumns as $table => $columns) {
        $tableExists = $mysqli->query("SHOW TABLES LIKE '$table'");
        if (!$tableExists || $tableExists->num_rows === 0) continue;
        foreach ($columns as $col) {
            $mysqli->query("UPDATE `$table` SET `$col` = `$col` * $rate");
        }
    }

    $mysqli->query("INSERT IGNORE INTO casa_migrations (name) VALUES ('$migrationName')");
}

// Rebuilds a table's primary/unique key to lead with house_id, if it doesn't already - idempotent,
// cheap to call on every request (a single SHOW KEYS check once migrated).
function casa_migrate_house_key(mysqli $mysqli, string $table, string $keyType, string $keyName, array $columns): void
{
    $lookupName = $keyType === 'PRIMARY' ? 'PRIMARY' : $keyName;
    $check = $mysqli->query("SHOW KEYS FROM $table WHERE Key_name = '$lookupName' AND Seq_in_index = 1 AND Column_name = 'house_id'");
    if ($check && $check->num_rows > 0) return;

    $cols = implode(', ', $columns);
    if ($keyType === 'PRIMARY') {
        $mysqli->query("ALTER TABLE $table DROP PRIMARY KEY, ADD PRIMARY KEY ($cols)");
    } else {
        $mysqli->query("ALTER TABLE $table DROP INDEX $keyName, ADD UNIQUE KEY $keyName ($cols)");
    }
}

const CASA_HOUSE_REMEMBER_COOKIE = 'casa_house_remember';

function casa_house_remember_token(int $houseId, string $password): string
{
    return hash_hmac('sha256', 'casa-house-remember-v1:' . $houseId, $password);
}

// One password screen at /index.php identifies AND authenticates the house in a single step
// (matched against every house's password there) - so "selected" and "authenticated" are the same
// state now, tracked by one session flag / one remember cookie "<houseId>:<token>", instead of a
// separate house-picker step before a per-house password prompt.
function casa_current_authed_house(mysqli $mysqli): ?array
{
    static $cached = null;
    static $resolved = false;
    if ($resolved) return $cached;
    $resolved = true;

    $houseId = !empty($_SESSION['casa_house_authed']) ? ($_SESSION['casa_house_id'] ?? null) : null;

    if ($houseId === null && !empty($_COOKIE[CASA_HOUSE_REMEMBER_COOKIE])) {
        $parts = explode(':', (string)$_COOKIE[CASA_HOUSE_REMEMBER_COOKIE], 2);
        if (count($parts) === 2) {
            $cid = (int)$parts[0];
            $stmt = $mysqli->prepare('SELECT password FROM casa_houses WHERE id = ?');
            $stmt->bind_param('i', $cid);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            if ($row && hash_equals(casa_house_remember_token($cid, $row['password']), $parts[1])) {
                $houseId = $cid;
            }
        }
    }
    if ($houseId === null) return null;

    $stmt = $mysqli->prepare('SELECT id, slug, name FROM casa_houses WHERE id = ?');
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    if (!$row) return null;

    $_SESSION['casa_house_id'] = (int)$row['id'];
    $_SESSION['casa_house_authed'] = true;
    $cached = ['id' => (int)$row['id'], 'slug' => $row['slug'], 'name' => $row['name']];
    return $cached;
}

function casa_house_login(int $houseId, string $password): void
{
    $_SESSION['casa_house_id'] = $houseId;
    $_SESSION['casa_house_authed'] = true;
    setcookie(CASA_HOUSE_REMEMBER_COOKIE, $houseId . ':' . casa_house_remember_token($houseId, $password), [
        'expires'  => time() + CASA_REMEMBER_DAYS * 86400,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
}

function casa_house_logout(): void
{
    unset($_SESSION['casa_house_id'], $_SESSION['casa_house_authed']);
    setcookie(CASA_HOUSE_REMEMBER_COOKIE, '', ['expires' => time() - 3600, 'path' => '/']);
    // setcookie() trimite doar antetul catre browser; $_COOKIE ramane cu valoarea veche pana la
    // cererea urmatoare. Fara asta, casa_current_authed_house() te re-autentifica imediat din
    // cookie-ul "sters" si delogarea n-are niciun efect.
    unset($_COOKIE[CASA_HOUSE_REMEMBER_COOKIE]);
}

// For full pages: redirects to the password screen if this device isn't authenticated for any house.
function casa_require_house_auth(mysqli $mysqli): array
{
    if (isset($_GET['logout'])) {
        casa_house_logout();
        header('Location: /index.php');
        exit;
    }

    $house = casa_current_authed_house($mysqli);
    if ($house === null) {
        header('Location: /index.php');
        exit;
    }
    casa_require_name();
    return $house;
}

// For AJAX endpoints: JSON error instead of a redirect, mirrors the old casa_require_api_auth().
function casa_require_api_house_auth(mysqli $mysqli): array
{
    $house = casa_current_authed_house($mysqli);
    if ($house === null) {
        http_response_code(401);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'error' => 'not_authenticated']);
        exit;
    }
    return $house;
}

// Filesystem root for a house's own uploads (design photos, stage photos) - site/<slug>/.
function casa_house_dir(string $slug): string
{
    return __DIR__ . '/' . $slug;
}

// Drepturile cu care se creeaza folderele si fisierele caselor. Grupul trebuie sa poata scrie,
// pentru ca in aceleasi foldere lucreaza doi utilizatori diferiti: serverul web (uploadul din site)
// si utilizatorul de FTP/SSH (pozele puse manual). Fara bitul de scriere pe grup, cine creeaza
// folderul primul il inchide pentru celalalt.
const CASA_DIR_MODE = 0775;
const CASA_FILE_MODE = 0664;

// Creeaza un folder pentru fisierele unei case.
//
// mkdir() primeste modul dorit, dar umask-ul procesului il taie (de obicei 0775 -> 0755), deci
// grupul ramane fara drept de scriere. De aceea dam chmod explicit dupa creare - si doar pe
// nivelurile pe care chiar le-am creat acum, ca sa nu umblam la drepturile folderelor existente.
function casa_make_dir(string $dir): bool
{
    if (is_dir($dir)) return true;

    $missing = [];
    $path = $dir;
    while (!is_dir($path)) {
        $missing[] = $path;
        $parent = dirname($path);
        if ($parent === $path) break;
        $path = $parent;
    }

    if (!@mkdir($dir, CASA_DIR_MODE, true)) return false;
    foreach ($missing as $created) @chmod($created, CASA_DIR_MODE);
    return true;
}

// Sterge o casa: toate randurile ei din tabelele scoped, apoi randul din casa_houses.
//
// Folderul cu fisierele urcate (poze de design si de progres) NU se sterge - pozele n-ar mai putea
// fi recuperate din aplicatie. E redenumit alaturi, in "<slug>__sters_<data>", ceea ce elibereaza si
// slug-ul daca vrei sa recreezi o casa cu acelasi nume. Daca vrei pozele duse de tot, sterge
// folderul de pe disc manual.
//
// Intoarce ['name' => numele casei sterse, 'archived' => noul nume de folder sau null daca n-avea].
function casa_delete_house(mysqli $mysqli, int $houseId): ?array
{
    $stmt = $mysqli->prepare('SELECT slug, name FROM casa_houses WHERE id = ?');
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $house = $stmt->get_result()->fetch_assoc();
    if (!$house) return null;

    foreach (CASA_HOUSE_SCOPED_TABLES as $table) {
        $del = $mysqli->prepare("DELETE FROM $table WHERE house_id = ?");
        $del->bind_param('i', $houseId);
        $del->execute();
    }

    $del = $mysqli->prepare('DELETE FROM casa_houses WHERE id = ?');
    $del->bind_param('i', $houseId);
    $del->execute();

    $archived = null;
    $dir = casa_house_dir($house['slug']);
    if (is_dir($dir)) {
        $target = $house['slug'] . '__sters_' . date('Ymd_His');
        if (@rename($dir, casa_house_dir($target))) {
            $archived = $target;
        }
    }

    return ['name' => $house['name'], 'archived' => $archived];
}

// Diacritic-stripped, case-preserved, separator-free folder name for a new house ("Casa Bunicii"
// -> "CasaBunicii"), de-duplicated against existing slugs by appending 2, 3, ... on collision.
function casa_house_folder_slug(mysqli $mysqli, string $name): string
{
    $map = [
        'ă' => 'a', 'â' => 'a', 'î' => 'i', 'ș' => 's', 'ş' => 's', 'ț' => 't', 'ţ' => 't',
        'Ă' => 'A', 'Â' => 'A', 'Î' => 'I', 'Ș' => 'S', 'Ş' => 'S', 'Ț' => 'T', 'Ţ' => 'T',
    ];
    $base = preg_replace('/[^A-Za-z0-9]+/', '', strtr($name, $map));
    if ($base === '') $base = 'Casa';

    $slug = $base;
    $suffix = 2;
    while (true) {
        $stmt = $mysqli->prepare('SELECT id FROM casa_houses WHERE slug = ?');
        $stmt->bind_param('s', $slug);
        $stmt->execute();
        if ($stmt->get_result()->num_rows === 0 && !is_dir(casa_house_dir($slug))) break;
        $slug = $base . $suffix;
        $suffix++;
    }
    return $slug;
}

// ============================ Camerele din /design ============================
// Camerele sunt foldere pe disc; in casa_design_rooms tinem doar ce nu incape intr-un nume de
// folder: numele afisat (butonul de redenumire) si ordinea (sagetile de mutare).

// Ordinea implicita, folosita pana cand muti prima data o camera. Ce nu e in lista vine la urma.
const CASA_DESIGN_DEFAULT_ROOM_ORDER = [
    'living' => 1, 'bucatarie' => 2, 'dormitor' => 3, 'dormitor_matrimonial' => 3, 'dormitor2' => 4,
    'dormitor3' => 5, 'hol' => 6, 'baie' => 7, 'baie_dus' => 7, 'baie_cada' => 8, 'terasa' => 9, 'exterior' => 10,
];

// Nume mai citete decat folderul, pentru cateva camere standard.
const CASA_DESIGN_ROOM_NAME_OVERRIDES = [
    'dormitor_matrimonial' => 'Dormitor 1',
    'dormitor2' => 'Dormitor 2',
    'dormitor3' => 'Dormitor 3',
];

function casa_design_rooms_ensure_table(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_design_rooms (
            house_id INT UNSIGNED NOT NULL,
            room_slug VARCHAR(64) NOT NULL,
            name VARCHAR(100) NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (house_id, room_slug)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $hasSortCol = $mysqli->query("SHOW COLUMNS FROM casa_design_rooms LIKE 'sort_order'");
    if ($hasSortCol && $hasSortCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE casa_design_rooms ADD COLUMN sort_order INT NOT NULL DEFAULT 0');
    }
}

// slug => ['name' => string, 'sort_order' => int]. Numele gol inseamna "fara nume propriu" - asa
// arata randurile scrise doar ca sa retina ordinea.
function casa_design_room_meta(mysqli $mysqli, int $houseId): array
{
    casa_design_rooms_ensure_table($mysqli);
    $meta = [];
    $stmt = $mysqli->prepare('SELECT room_slug, name, sort_order FROM casa_design_rooms WHERE house_id = ?');
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $meta[$row['room_slug']] = ['name' => (string)$row['name'], 'sort_order' => (int)$row['sort_order']];
    }
    return $meta;
}

// Numele afisat: cel pus de user > lista de mai sus > numele folderului, cu spatii si majuscule.
function casa_design_room_name(string $slug, array $meta): string
{
    $custom = $meta[$slug]['name'] ?? '';
    if ($custom !== '') return $custom;
    if (isset(CASA_DESIGN_ROOM_NAME_OVERRIDES[$slug])) return CASA_DESIGN_ROOM_NAME_OVERRIDES[$slug];
    return mb_convert_case(str_replace(['_', '-'], ' ', $slug), MB_CASE_TITLE, 'UTF-8');
}

// Sorteaza camerele pentru afisare. Daca s-a reordonat vreodata manual, ordinea din baza de date e
// singura care conteaza; altfel ramane ordinea implicita. Ex-aequo se departajeaza dupa nume.
function casa_design_sort_rooms(array $rooms, array $meta): array
{
    $hasManualOrder = false;
    foreach ($meta as $m) {
        if ($m['sort_order'] > 0) { $hasManualOrder = true; break; }
    }

    usort($rooms, function ($a, $b) use ($meta, $hasManualOrder) {
        if ($hasManualOrder) {
            $orderA = $meta[$a['slug']]['sort_order'] ?? 0;
            $orderB = $meta[$b['slug']]['sort_order'] ?? 0;
            // Camerele fara pozitie salvata (adaugate dupa reordonare) merg la coada.
            if ($orderA === 0) $orderA = 9999;
            if ($orderB === 0) $orderB = 9999;
        } else {
            $orderA = CASA_DESIGN_DEFAULT_ROOM_ORDER[$a['slug']] ?? 999;
            $orderB = CASA_DESIGN_DEFAULT_ROOM_ORDER[$b['slug']] ?? 999;
        }
        if ($orderA === $orderB) return strcasecmp($a['name'], $b['name']);
        return $orderA <=> $orderB;
    });
    return $rooms;
}

// Lista de sluguri in ordinea de afisare - ce vede si utilizatorul pe pagina.
function casa_design_room_order(mysqli $mysqli, int $houseId, string $baseDir): array
{
    $meta = casa_design_room_meta($mysqli, $houseId);

    $rooms = [];
    foreach (scandir($baseDir) ?: [] as $entry) {
        if ($entry === '.' || $entry === '..') continue;
        if (!is_dir($baseDir . '/' . $entry)) continue;
        $rooms[] = ['slug' => $entry, 'name' => casa_design_room_name($entry, $meta)];
    }

    return array_column(casa_design_sort_rooms($rooms, $meta), 'slug');
}

// Diacritic-stripped, lowercase, underscore-separated slug for a room folder ("Baie oaspeți" ->
// "baie_oaspeti"), matching the naming convention of the existing room folders (baie_cada, etc).
function casa_room_slugify(string $name): string
{
    $map = [
        'ă' => 'a', 'â' => 'a', 'î' => 'i', 'ș' => 's', 'ş' => 's', 'ț' => 't', 'ţ' => 't',
        'Ă' => 'a', 'Â' => 'a', 'Î' => 'i', 'Ș' => 's', 'Ş' => 's', 'Ț' => 't', 'Ţ' => 't',
    ];
    $text = mb_strtolower(strtr($name, $map));
    $text = preg_replace('/[^a-z0-9]+/', '_', $text);
    return trim($text, '_');
}

// ============================ Checklist-uri de camera (mai multe items per categorie) ============================
// Fiecare card (categorie - Var & Tapet, Mobilă etc.) poate avea orice numar de items; fiecare item
// are propriile bife Cumpărat/Montat si propriile costuri estimativ/real. Inainte, o categorie avea
// un singur set fix de bife si un singur pret - vezi migrarea de mai jos.
function casa_design_checklist_ensure_schema(mysqli $mysqli, array $checklistDefs): void
{
    $existsRes = $mysqli->query("SHOW TABLES LIKE 'casa_design_checklist_items'");
    $alreadyExists = $existsRes && $existsRes->num_rows > 0;

    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_design_checklist_items (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            house_id INT UNSIGNED NOT NULL,
            room_slug VARCHAR(64) NOT NULL,
            category VARCHAR(32) NOT NULL,
            name VARCHAR(150) NOT NULL,
            cumparat TINYINT(1) NOT NULL DEFAULT 0,
            montat TINYINT(1) NOT NULL DEFAULT 0,
            price_estimate DECIMAL(10,2) NOT NULL DEFAULT 0,
            price_actual DECIMAL(10,2) NOT NULL DEFAULT 0,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY house_room_category (house_id, room_slug, category)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );

    if ($alreadyExists) return;

    // Prima rulare dupa update: fiecare (casa, camera, categorie) care avea deja o bifa sau un pret
    // in vechiul sistem (un singur item fix per categorie) devine primul item din card, cu acelasi
    // nume ca eticheta categoriei - nimic din ce s-a completat pana acum nu se pierde.
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_design_status (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            house_id INT UNSIGNED NOT NULL,
            room_slug VARCHAR(64) NOT NULL,
            category VARCHAR(32) NOT NULL,
            step VARCHAR(32) NOT NULL,
            done TINYINT(1) NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY house_room_category_step (house_id, room_slug, category, step)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_design_prices (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            house_id INT UNSIGNED NOT NULL,
            room_slug VARCHAR(64) NOT NULL,
            category VARCHAR(32) NOT NULL,
            price_estimate DECIMAL(10,2) NOT NULL DEFAULT 0,
            price_actual DECIMAL(10,2) NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY house_room_category (house_id, room_slug, category)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );

    // Ordinea istorica a celor doua bife per categorie, din vechiul checklist_defs.php - prima
    // bifa insemna mereu "achizitionat" (cumparat/comandat), a doua "montat" (montat/varuit).
    $historicalStepOrder = [
        'var'      => ['cumparat', 'varuit'],
        'parchet'  => ['cumparat', 'montat'],
        'mobila'   => ['comandat', 'montat'],
        'iluminat' => ['comandat', 'montat'],
        'tapet'    => ['cumparat', 'montat'],
        'decor'    => ['cumparat', 'montat'],
    ];

    $rows = [];
    $res = $mysqli->query('SELECT house_id, room_slug, category, step, done FROM casa_design_status');
    while ($res && $row = $res->fetch_assoc()) {
        $key = $row['house_id'] . '|' . $row['room_slug'] . '|' . $row['category'];
        $rows[$key]['house_id'] = (int)$row['house_id'];
        $rows[$key]['room_slug'] = $row['room_slug'];
        $rows[$key]['category'] = $row['category'];
        $rows[$key]['steps'][$row['step']] = (bool)$row['done'];
    }
    $priceRes = $mysqli->query('SELECT house_id, room_slug, category, price_estimate, price_actual FROM casa_design_prices');
    while ($priceRes && $row = $priceRes->fetch_assoc()) {
        $key = $row['house_id'] . '|' . $row['room_slug'] . '|' . $row['category'];
        $rows[$key]['house_id'] = (int)$row['house_id'];
        $rows[$key]['room_slug'] = $row['room_slug'];
        $rows[$key]['category'] = $row['category'];
        $rows[$key]['price_estimate'] = (float)$row['price_estimate'];
        $rows[$key]['price_actual'] = (float)$row['price_actual'];
    }

    if (!$rows) return;

    $insert = $mysqli->prepare(
        'INSERT INTO casa_design_checklist_items
            (house_id, room_slug, category, name, cumparat, montat, price_estimate, price_actual)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    foreach ($rows as $r) {
        $steps = $r['steps'] ?? [];
        $order = $historicalStepOrder[$r['category']] ?? ['cumparat', 'montat'];
        $cumparat = (int)($steps[$order[0]] ?? false);
        $montat = (int)($steps[$order[1]] ?? false);
        $name = $checklistDefs[$r['category']]['label'] ?? ucfirst($r['category']);
        $estimate = $r['price_estimate'] ?? 0.0;
        $actual = $r['price_actual'] ?? 0.0;
        $insert->bind_param('isssiidd', $r['house_id'], $r['room_slug'], $r['category'], $name, $cumparat, $montat, $estimate, $actual);
        $insert->execute();
    }
}

// Toate items-urile unei case, grupate [room_slug][category] => listă ordonată.
function casa_design_checklist_items(mysqli $mysqli, int $houseId): array
{
    $lookup = [];
    $stmt = $mysqli->prepare(
        'SELECT id, room_slug, category, name, cumparat, montat, price_estimate, price_actual
         FROM casa_design_checklist_items WHERE house_id = ? ORDER BY sort_order, id'
    );
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $lookup[$row['room_slug']][$row['category']][] = [
            'id' => (int)$row['id'],
            'name' => $row['name'],
            'cumparat' => (bool)$row['cumparat'],
            'montat' => (bool)$row['montat'],
            'price_estimate' => (float)$row['price_estimate'],
            'price_actual' => (float)$row['price_actual'],
        ];
    }
    return $lookup;
}

// Camerele de pe paginile Preturi / Link-uri / produs: aceleasi ca in Design (foldere + nume
// redenumite + ordinea aleasa), ca o camera noua sa apara peste tot fara sa fie adaugata si de mana.
// Intoarce slug => ['name' => ..., 'icon' => ...]. "others" ramane mereu, ca loc implicit al produselor
// care nu au camera.
function casa_rooms_for_pages(mysqli $mysqli, int $houseId, string $houseSlug): array
{
    $icons = [
        'living' => '🛋️', 'bucatarie' => '🍳', 'dormitor_matrimonial' => '🛏️', 'dormitor2' => '🛏️',
        'dormitor3' => '🛏️', 'baie_dus' => '🚿', 'baie_cada' => '🛁', 'hol' => '🚪',
        'terasa' => '🌿', 'exterior' => '🏡', 'others' => '✨',
    ];
    $baseDir = casa_house_dir($houseSlug) . '/design';
    $meta = casa_design_room_meta($mysqli, $houseId);

    $found = [];
    if (is_dir($baseDir)) {
        foreach (scandir($baseDir) ?: [] as $entry) {
            if ($entry === '.' || $entry === '..' || !is_dir($baseDir . '/' . $entry)) continue;
            $found[] = ['slug' => $entry, 'name' => casa_design_room_name($entry, $meta)];
        }
    }

    $rooms = [];
    foreach (casa_design_sort_rooms($found, $meta) as $r) {
        $rooms[$r['slug']] = ['name' => $r['name'], 'icon' => $icons[$r['slug']] ?? '🏠'];
    }
    if (!isset($rooms['others'])) $rooms['others'] = ['name' => 'Others', 'icon' => '✨'];
    return $rooms;
}
