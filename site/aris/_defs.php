<?php
require_once __DIR__ . '/../includes/themes.php';
// Shared helpers for /aris/ - Aris' feeding plan. Tracks what he's been given to eat (or is
// planned to be given) each day, with a quantity and a free note per entry. A meal's source is
// exactly one of: a food from the managed list, a saved recipe (itself a list of foods + grams),
// or free-typed custom text - never more than one at a time. Foods/recipes are their own managed
// lists (add/rename/delete, or full edit for recipes) - deleting one just unlinks anything that
// referenced it instead of deleting that history.

const ARIS_BIRTH_DATE = '2026-03-11';
const ARIS_QUANTITY_MAX = 60;
const ARIS_NOTES_MAX = 300;
const ARIS_FOOD_NAME_MAX = 80;
const ARIS_RECIPE_NAME_MAX = 100;
const ARIS_CUSTOM_TEXT_MAX = 150;
const ARIS_REACTION_MAX = 300;

function aris_ensure_tables(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_foods (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(80) NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Marcaj manual "e alergic confirmat la asta" - separat de urmarirea reactiilor din
    // aris_allergens (aia e per-incercare; asta e un DA/NU stabil, setat de parinte).
    $hasAllergicCol = $mysqli->query("SHOW COLUMNS FROM aris_foods LIKE 'is_allergic'");
    if ($hasAllergicCol && $hasAllergicCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE aris_foods ADD COLUMN is_allergic TINYINT(1) NOT NULL DEFAULT 0 AFTER name');
    }
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_recipes (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(100) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_recipe_items (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            recipe_id INT UNSIGNED NOT NULL,
            food_id INT UNSIGNED NULL,
            grams INT UNSIGNED NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_meals (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            meal_date DATE NOT NULL,
            food_id INT UNSIGNED NULL,
            quantity VARCHAR(60) NULL,
            notes VARCHAR(300) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Migration: o masa poate proveni acum dintr-o reteta sau poate fi text liber, nu doar un
    // aliment din lista.
    $hasRecipeCol = $mysqli->query("SHOW COLUMNS FROM aris_meals LIKE 'recipe_id'");
    if ($hasRecipeCol && $hasRecipeCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE aris_meals ADD COLUMN recipe_id INT UNSIGNED NULL AFTER food_id');
    }
    $hasCustomCol = $mysqli->query("SHOW COLUMNS FROM aris_meals LIKE 'custom_text'");
    if ($hasCustomCol && $hasCustomCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE aris_meals ADD COLUMN custom_text VARCHAR(150) NULL AFTER recipe_id');
    }
    // Checklist de alergeni: fiecare rand e un aliment-alergen relevant, cu o bifa "i-a fost dat
    // deja copilului" - data si reactia sunt completate doar cand bifa e pusa.
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_allergens (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            food_id INT UNSIGNED NULL,
            is_given TINYINT(1) NOT NULL DEFAULT 0,
            used_on DATE NULL,
            reaction VARCHAR(300) NULL,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Bifa AVEM/NU AVEM per aliment, tinuta pe saptamana (week_start = Lunea acelei saptamani) -
    // lista in sine (ce alimente apar) e derivata din retetele saptamanii, nu stocata separat.
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_shopping_status (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            food_id INT UNSIGNED NOT NULL,
            week_start DATE NOT NULL,
            have_it TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY food_week (food_id, week_start)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Articole adaugate manual pe lista de cumparaturi a unei saptamani (nu vin dintr-o reteta) -
    // ex. lucruri care nu sunt "aliment" in sensul retetelor, sau ceva uitat din lista automata.
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_shopping_extra (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            week_start DATE NOT NULL,
            name VARCHAR(80) NOT NULL,
            have_it TINYINT(1) NOT NULL DEFAULT 0,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Alimente derivate automat din retete pe care parintele le-a scos manual din lista unei
    // saptamani (ex. "il am deja, nu mai apare in lista"), fara sa afecteze alte saptamani.
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS aris_shopping_removed (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            food_id INT UNSIGNED NOT NULL,
            week_start DATE NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY food_week (food_id, week_start)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

// Suma gramelor dintr-o zi, citita din campul liber "quantity" al fiecarei mese. Accepta "50g",
// "50 g", "80gr" si un numar simplu ("50" - gramele fiind unitatea implicita in acest camp), dar
// ignora orice are o alta unitate explicita (ml, linguriță, bucată etc.), ca sa nu numere lichide
// sau masuri fara gramaj ca grame. Intoarce null daca nicio masa din ziua asta nu are un gramaj
// recunoscut.
function aris_day_total_grams(array $dayMeals): ?int
{
    $total = 0;
    $found = false;
    foreach ($dayMeals as $meal) {
        $q = trim((string)($meal['quantity'] ?? ''));
        if ($q === '') continue;
        if (preg_match('/\b(ml|l|lingur|bucat|felii?|cati|cană|cana|pahar|buc)\b/iu', $q)) continue;
        if (preg_match('/^(\d+(?:[.,]\d+)?)\s*g(?:r)?\b/i', $q, $m) || preg_match('/^(\d+(?:[.,]\d+)?)$/', $q, $m)) {
            $total += (int)round((float)str_replace(',', '.', $m[1]));
            $found = true;
        }
    }
    return $found ? $total : null;
}

// Detaliile complete ale meselor date (grupate pe zi, ca in $mealsByDate), indexate dupa id -
// baza pentru popup-ul de detalii folosit atat pe /aris/ cat si pe /aris/calendar.php. Fiecare
// masa din $mealsByDate trebuie sa aiba deja: id, recipe_id, quantity, notes, label (din
// aris_meal_label). Ingredientele retetelor sunt aduse intr-un singur request, nu unul per masa.
function aris_build_meal_details(mysqli $mysqli, array $mealsByDate): array
{
    $recipeIds = [];
    foreach ($mealsByDate as $dayMeals) {
        foreach ($dayMeals as $meal) {
            if ($meal['recipe_id'] !== null) $recipeIds[(int)$meal['recipe_id']] = true;
        }
    }

    $recipeIngredients = [];
    if (!empty($recipeIds)) {
        $ids = implode(',', array_map('intval', array_keys($recipeIds)));
        $res = $mysqli->query(
            "SELECT ri.recipe_id, ri.grams, f.name AS food_name
             FROM aris_recipe_items ri LEFT JOIN aris_foods f ON f.id = ri.food_id
             WHERE ri.recipe_id IN ($ids)
             ORDER BY ri.recipe_id ASC, ri.sort_order ASC, ri.id ASC"
        );
        if ($res) {
            while ($row = $res->fetch_assoc()) {
                $recipeIngredients[(int)$row['recipe_id']][] = [
                    'name' => $row['food_name'] ?? 'Aliment șters',
                    'grams' => $row['grams'] !== null ? (int)$row['grams'] : null,
                ];
            }
        }
    }

    $details = [];
    foreach ($mealsByDate as $date => $dayMeals) {
        foreach ($dayMeals as $meal) {
            $ingredients = null;
            if ($meal['recipe_id'] !== null) {
                $ingredients = $recipeIngredients[(int)$meal['recipe_id']] ?? [];
            }
            $source = $meal['recipe_id'] !== null ? 'recipe' : ($meal['custom_text'] !== null ? 'custom' : 'food');
            $details[$meal['id']] = [
                'date' => aris_ro_date($date),
                'age' => aris_age_at($date),
                'label' => $meal['label']['label'],
                'type' => $meal['label']['type'],
                'quantity' => $meal['quantity'],
                'notes' => $meal['notes'],
                'ingredients' => $ingredients,
                // Folosite de popup-ul cu editare de pe /aris/ (calendarul il foloseste doar
                // pentru vizualizare, deci ignora aceste campuri).
                'mealDate' => $meal['meal_date'],
                'source' => $source,
                'foodId' => $meal['food_id'],
                'recipeId' => $meal['recipe_id'],
                'customText' => $meal['custom_text'],
            ];
        }
    }
    return $details;
}

// Luni al saptamanii carei apartine o data (acelasi Luni-Duminica folosit peste tot in /aris/).
function aris_week_start(string $date): string
{
    return (new DateTime($date))->modify('monday this week')->format('Y-m-d');
}

// Alimentele existente mentionate intr-un text liber (o masa "personalizata"), gasite prin
// aceeasi potrivire aproximativa (normalizare + similar_text, prag 85%) folosita la creare de
// alimente noi - dar aplicata pe bucati din text, nu pe un nume intreg, ca sa prinda alimentul
// chiar daca apare in mijlocul propozitiei ("piure de dovleac cu morcov" -> dovleac + morcov).
// Compara fiecare aliment doar cu fraze din text avand acelasi numar de cuvinte ca numele lui, ca
// sa evite potriviri intamplatoare intre cuvinte scurte fara legatura. Numele scurte (sub 5
// caractere, ex. "ou", "apă") cer potrivire exacta a cuvantului - similaritatea de 85% nu e de
// incredere pe siruri asa de scurte. Intoarce [food_id => nume].
function aris_extract_mentioned_food_ids(mysqli $mysqli, string $text): array
{
    $clean = preg_replace('/[^\p{L}\p{N}\s]/u', ' ', aris_normalize_food_name($text));
    $words = array_values(array_filter(preg_split('/\s+/', trim((string)$clean))));
    $wordCountInText = count($words);
    if ($wordCountInText === 0) return [];

    $matched = [];
    $res = $mysqli->query('SELECT id, name FROM aris_foods');
    if ($res) {
        while ($food = $res->fetch_assoc()) {
            $normalizedFood = aris_normalize_food_name($food['name']);
            if ($normalizedFood === '') continue;
            $foodWordCount = count(explode(' ', $normalizedFood));
            $requireExact = mb_strlen($normalizedFood) < 5;
            for ($i = 0; $i + $foodWordCount <= $wordCountInText; $i++) {
                $phrase = implode(' ', array_slice($words, $i, $foodWordCount));
                if ($requireExact) {
                    if ($phrase === $normalizedFood) {
                        $matched[(int)$food['id']] = $food['name'];
                        break;
                    }
                    continue;
                }
                similar_text($phrase, $normalizedFood, $pct);
                if ($pct >= 85.0) {
                    $matched[(int)$food['id']] = $food['name'];
                    break;
                }
            }
        }
    }
    return $matched;
}

// Alimentele din retetele folosite in mesele saptamanii date (identificata prin Lunea ei) plus
// cele recunoscute in textul meselor personalizate ale saptamanii, cu starea AVEM/NU AVEM
// curenta, plus articolele adaugate manual si minus cele scoase manual - lista completa,
// editabila, pentru popup-ul de cumparaturi de pe /aris/. Fiecare element are 'type' ('food' -
// derivat din retete/text, sau 'extra' - adaugat manual), 'id', 'name', 'have_it'; cheia
// array-ului e un string unic "food_5"/"extra_3" convenabil de folosit direct in HTML.
function aris_shopping_list(mysqli $mysqli, string $weekStart): array
{
    $weekEnd = (new DateTime($weekStart))->modify('+6 days')->format('Y-m-d');

    $recipeIds = [];
    $stmt = $mysqli->prepare('SELECT DISTINCT recipe_id FROM aris_meals WHERE recipe_id IS NOT NULL AND meal_date BETWEEN ? AND ?');
    $stmt->bind_param('ss', $weekStart, $weekEnd);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) $recipeIds[] = (int)$row['recipe_id'];

    $foods = [];
    if (!empty($recipeIds)) {
        $ids = implode(',', $recipeIds);
        $res = $mysqli->query(
            "SELECT DISTINCT ri.food_id, f.name
             FROM aris_recipe_items ri JOIN aris_foods f ON f.id = ri.food_id
             WHERE ri.recipe_id IN ($ids)
             ORDER BY f.name ASC"
        );
        if ($res) {
            while ($row = $res->fetch_assoc()) {
                $foods[(int)$row['food_id']] = ['name' => $row['name'], 'have_it' => false];
            }
        }
    }

    $stmt = $mysqli->prepare('SELECT custom_text FROM aris_meals WHERE custom_text IS NOT NULL AND meal_date BETWEEN ? AND ?');
    $stmt->bind_param('ss', $weekStart, $weekEnd);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        foreach (aris_extract_mentioned_food_ids($mysqli, $row['custom_text']) as $fid => $fname) {
            if (!isset($foods[$fid])) {
                $foods[$fid] = ['name' => $fname, 'have_it' => false];
            }
        }
    }

    if (!empty($foods)) {
        $stmt = $mysqli->prepare('SELECT food_id FROM aris_shopping_removed WHERE week_start = ?');
        $stmt->bind_param('s', $weekStart);
        $stmt->execute();
        $res = $stmt->get_result();
        while ($row = $res->fetch_assoc()) {
            unset($foods[(int)$row['food_id']]);
        }
    }

    if (!empty($foods)) {
        $stmt = $mysqli->prepare('SELECT food_id, have_it FROM aris_shopping_status WHERE week_start = ?');
        $stmt->bind_param('s', $weekStart);
        $stmt->execute();
        $res = $stmt->get_result();
        while ($row = $res->fetch_assoc()) {
            $fid = (int)$row['food_id'];
            if (isset($foods[$fid])) $foods[$fid]['have_it'] = (int)$row['have_it'] === 1;
        }
    }

    uasort($foods, function ($a, $b) { return strcasecmp($a['name'], $b['name']); });

    $items = [];
    foreach ($foods as $fid => $food) {
        $items["food_$fid"] = ['type' => 'food', 'id' => $fid, 'name' => $food['name'], 'have_it' => $food['have_it']];
    }

    $stmt = $mysqli->prepare('SELECT id, name, have_it FROM aris_shopping_extra WHERE week_start = ? ORDER BY sort_order ASC, id ASC');
    $stmt->bind_param('s', $weekStart);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $eid = (int)$row['id'];
        $items["extra_$eid"] = ['type' => 'extra', 'id' => $eid, 'name' => $row['name'], 'have_it' => (int)$row['have_it'] === 1];
    }

    return $items;
}

// Cauta un aliment dupa nume; daca nu exista, il creaza. Folosit la ingredientele unei retete,
// unde userul scrie liber numele in loc sa aleaga dintr-un dropdown - "Ou"/"ou"/"OU" si
// "Cartof dulce"/"cartofi dulci"/"Cartofi dulce" trebuie sa gaseasca acelasi aliment, nu sa
// creeze unul nou de fiecare data cand forma de plural sau majusculele difera putin.
function aris_find_or_create_food(mysqli $mysqli, string $name): ?int
{
    $name = trim($name);
    if ($name === '' || mb_strlen($name) > ARIS_FOOD_NAME_MAX) return null;

    // Potrivire exacta, case-insensitive (colatia impicita a coloanei se ocupa de majuscule).
    $stmt = $mysqli->prepare('SELECT id FROM aris_foods WHERE name = ?');
    $stmt->bind_param('s', $name);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    if ($row) return (int)$row['id'];

    // Fara potrivire exacta - incearca o potrivire aproximativa (plural/singular, mici diferente
    // de tastare), ca sa nu apara un aliment nou pentru fiecare variatie a aceluiasi cuvant.
    $similar = aris_find_similar_food($mysqli, $name);
    if ($similar !== null) return $similar;

    $maxOrder = -1;
    $orderRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM aris_foods');
    if ($orderRes) $maxOrder = (int)$orderRes->fetch_assoc()['max_order'];
    $nextOrder = $maxOrder + 1;

    $ins = $mysqli->prepare('INSERT INTO aris_foods (name, sort_order) VALUES (?, ?)');
    $ins->bind_param('si', $name, $nextOrder);
    if (!$ins->execute()) {
        // Race cu o alta cerere care a creat exact acelasi nume intre timp - recitim.
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        return $row ? (int)$row['id'] : null;
    }
    return $mysqli->insert_id;
}

// Minuscule, fara diacritice, spatii multiple reduse - nu e o lematizare reala, doar reduce
// zgomotul inainte de compararea de similaritate de mai jos.
function aris_normalize_food_name(string $name): string
{
    $name = mb_strtolower(trim($name));
    $name = strtr($name, ['ă' => 'a', 'â' => 'a', 'î' => 'i', 'ș' => 's', 'ş' => 's', 'ț' => 't', 'ţ' => 't']);
    return preg_replace('/\s+/', ' ', $name);
}

// Cel mai apropiat aliment existent, dupa % de similaritate intre formele normalizate - prag
// destul de ridicat si o lungime minima, ca doua alimente scurte si diferite sa nu fie unite din
// greseala (ex. "Ou" nu trebuie sa "gaseasca" ceva doar pentru ca e scurt).
function aris_find_similar_food(mysqli $mysqli, string $name): ?int
{
    $normalizedInput = aris_normalize_food_name($name);
    if (mb_strlen($normalizedInput) < 5) return null;

    $res = $mysqli->query('SELECT id, name FROM aris_foods');
    if (!$res) return null;

    $bestId = null;
    $bestPct = 0.0;
    while ($row = $res->fetch_assoc()) {
        $normalizedExisting = aris_normalize_food_name($row['name']);
        similar_text($normalizedInput, $normalizedExisting, $pct);
        if ($pct > $bestPct) {
            $bestPct = $pct;
            $bestId = (int)$row['id'];
        }
    }
    return $bestPct >= 85.0 ? $bestId : null;
}

// n=1 -> singular, altfel -> plural. Suficient de corect pentru intervalele mici de aici
// (zile intr-o luna, luni intr-un an) - nu trateaza formele compuse cu "de" de la 20 in sus.
function aris_pluralize(int $n, string $singular, string $plural): string
{
    return $n . ' ' . ($n === 1 ? $singular : $plural);
}

// Varsta lui Aris la o anumita data (nu neaparat azi - poate fi data unei mese trecute sau
// planificate), ca text gata de afisat: "6 luni și 4 zile", "1 an și 2 luni", "12 zile".
function aris_age_at(string $targetDate): ?string
{
    $birth = new DateTime(ARIS_BIRTH_DATE);
    $target = new DateTime($targetDate);
    if ($target < $birth) return null;

    $diff = $birth->diff($target);
    if ($diff->y > 0) {
        $parts = [aris_pluralize($diff->y, 'an', 'ani')];
        if ($diff->m > 0) $parts[] = aris_pluralize($diff->m, 'lună', 'luni');
        return implode(' și ', $parts);
    }
    if ($diff->m > 0) {
        $parts = [aris_pluralize($diff->m, 'lună', 'luni')];
        if ($diff->d > 0) $parts[] = aris_pluralize($diff->d, 'zi', 'zile');
        return implode(' și ', $parts);
    }
    return aris_pluralize($diff->d, 'zi', 'zile');
}

// 'planned' (data e in viitor) sau 'given' (azi sau trecut).
function aris_meal_status(string $mealDate): string
{
    return strtotime($mealDate) > strtotime('today') ? 'planned' : 'given';
}

// Eticheta de afisat pentru o masa, indiferent din ce provine - exact una dintre food_name /
// recipe_name / custom_text e completata. 'type' e folosit pentru micul tag din UI.
function aris_meal_label(?string $foodName, ?string $recipeName, ?string $customText): array
{
    if ($recipeName !== null) return ['label' => $recipeName, 'type' => 'recipe'];
    if ($customText !== null && $customText !== '') return ['label' => $customText, 'type' => 'custom'];
    if ($foodName !== null) return ['label' => $foodName, 'type' => 'food'];
    return ['label' => 'Aliment șters', 'type' => 'deleted'];
}

const ARIS_MONTHS_RO = [
    1 => 'ianuarie', 2 => 'februarie', 3 => 'martie', 4 => 'aprilie', 5 => 'mai', 6 => 'iunie',
    7 => 'iulie', 8 => 'august', 9 => 'septembrie', 10 => 'octombrie', 11 => 'noiembrie', 12 => 'decembrie',
];
const ARIS_WEEKDAYS_RO_SHORT = ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'];
const ARIS_WEEKDAYS_RO_FULL = [1 => 'Luni', 2 => 'Marți', 3 => 'Miercuri', 4 => 'Joi', 5 => 'Vineri', 6 => 'Sâmbătă', 7 => 'Duminică'];

function aris_ro_date(string $ymd): string
{
    $ts = strtotime($ymd);
    return date('d', $ts) . ' ' . ARIS_MONTHS_RO[(int)date('n', $ts)];
}

// "Marți, 15.09" - ziua saptamanii (Luni=1..Duminica=7, ISO) plus data numerica zi.luna.
function aris_ro_date_with_weekday(string $ymd): string
{
    $ts = strtotime($ymd);
    return ARIS_WEEKDAYS_RO_FULL[(int)date('N', $ts)] . ', ' . date('d.m', $ts);
}

function aris_ro_month_year(int $month, int $year): string
{
    return ARIS_MONTHS_RO[$month] . ' ' . $year;
}

const ARIS_FLAVEUR_URL = 'https://flaveur.ro/plan-de-diversificare-pentru-primele-30-de-zile-varianta-noua/';

// Header nav comun tuturor paginilor /aris/*. Flaveur e un link extern (planul de diversificare
// dupa care ne ghidam), nu o pagina interna - se deschide intr-un tab nou.
function aris_render_nav(string $current): void
{
    $links = [
        'plan' => ['/', 'Plan'],
        'calendar' => ['/calendar.php', 'Calendar'],
        'alimente' => ['/alimente.php', 'Alimente'],
        'retete' => ['/retete.php', 'Rețete'],
        'alergeni' => ['/alergeni.php', 'Alergeni'],
        'notite' => ['/notite.php', 'Notițe'],
    ];
    foreach ($links as $key => [$href, $label]) {
        $cls = $key === $current ? ' class="is-current"' : '';
        echo '<a href="' . htmlspecialchars($href) . '"' . $cls . '>' . htmlspecialchars($label) . "</a>\n";
    }
    echo '<a href="' . htmlspecialchars(ARIS_FLAVEUR_URL) . '" target="_blank" rel="noopener">Flaveur ↗</a>' . "\n";
}

// Temele vizuale sunt comune intregului site - vezi /includes/themes.php (lista lor se
// activeaza/dezactiveaza din tabelul site_themes) si /assets/themes.css.
