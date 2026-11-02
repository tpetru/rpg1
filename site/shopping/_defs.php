<?php
require_once __DIR__ . '/../includes/themes.php';
// Helperi comuni pentru /shopping.php (lista de cumparaturi de pe no-santos.com) si endpoint-urile
// din acest folder. E varianta "generala" a casa/shopping.php: in loc de camerele casei, produsele
// sunt grupate pe categorii definite de user (adauga/redenumeste/sterge), iar tabelele stau in baza
// de date principala a site-ului (shop_*), separat de cele ale casei (casa_price_*).
//
// Extragerea pretului din pagina de produs NU e duplicata: se refolosesc functiile din
// casa/_price_check.php (fetch + JSON-LD/OpenGraph/microdata/...), ca un magazin reparat acolo sa
// mearga automat si aici. De aici se foloseste doar partea "pura" (casa_fetch_page,
// casa_extract_price, casa_detect_unit_price) - scrierea in istoric e mai jos, pe tabelele shop_*.
require_once __DIR__ . '/../casa/_price_check.php';

const SHOP_NAME_MAX = 150;
const SHOP_URL_MAX = 500;
const SHOP_TAGS_MAX = 255;
const SHOP_COMMENT_MAX = 256;
const SHOP_CATEGORY_NAME_MAX = 40;
const SHOP_CATEGORY_ICON_MAX = 8;

function shop_ensure_tables(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS shop_categories (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(40) NOT NULL,
            icon VARCHAR(8) NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS shop_products (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(150) NOT NULL,
            url VARCHAR(500) NOT NULL,
            category_id INT UNSIGNED NULL,
            tags VARCHAR(255) NULL,
            comment VARCHAR(256) NULL,
            priority TINYINT(1) NOT NULL DEFAULT 0,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY category (category_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS shop_price_history (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            product_id INT UNSIGNED NOT NULL,
            price DECIMAL(10,2) NULL,
            unit_price DECIMAL(10,2) NULL,
            currency VARCHAR(8) NULL,
            ok TINYINT(1) NOT NULL DEFAULT 0,
            error VARCHAR(255) NULL,
            checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY product_checked (product_id, checked_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

// id => ['id', 'name', 'icon'], in ordinea de afisare.
function shop_categories(mysqli $mysqli): array
{
    $out = [];
    $res = $mysqli->query('SELECT id, name, icon FROM shop_categories ORDER BY sort_order ASC, id ASC');
    if ($res) while ($row = $res->fetch_assoc()) $out[(int)$row['id']] = $row;
    return $out;
}

// Categoria trimisa din formular: un id existent, altfel null ("Fără categorie").
function shop_category_from_post(mysqli $mysqli, $raw): ?int
{
    $id = (int)$raw;
    if ($id <= 0) return null;
    $stmt = $mysqli->prepare('SELECT id FROM shop_categories WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ? $id : null;
}

function shop_host(string $url): string
{
    $host = parse_url($url, PHP_URL_HOST);
    return $host ? preg_replace('/^www\./', '', $host) : $url;
}

// "laptop, cadou" -> ["laptop", "cadou"], fara spatii si fara intrari goale.
function shop_tags(?string $raw): array
{
    if ($raw === null || trim($raw) === '') return [];
    return array_values(array_filter(array_map('trim', explode(',', $raw))));
}

function shop_json_error(int $code, string $error): void
{
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $error]);
    exit;
}

// Campurile comune ale formularului de adaugare/editare produs, validate. Iese cu 400 la input gresit.
function shop_product_input(mysqli $mysqli): array
{
    $name = trim($_POST['name'] ?? '');
    $url = trim($_POST['url'] ?? '');
    $tags = trim($_POST['tags'] ?? '');
    $comment = trim($_POST['comment'] ?? '');

    if ($url === '' || mb_strlen($url) > SHOP_URL_MAX || mb_strlen($name) > SHOP_NAME_MAX
        || mb_strlen($tags) > SHOP_TAGS_MAX || mb_strlen($comment) > SHOP_COMMENT_MAX) {
        shop_json_error(400, 'invalid input');
    }
    if (!filter_var($url, FILTER_VALIDATE_URL) || !preg_match('#^https?://#i', $url)) {
        shop_json_error(400, 'invalid url');
    }
    if ($name === '') $name = shop_host($url) ?: 'Produs';

    return [
        'name' => $name,
        'url' => $url,
        'category_id' => shop_category_from_post($mysqli, $_POST['category'] ?? 0),
        'tags' => $tags === '' ? null : $tags,
        'comment' => $comment === '' ? null : $comment,
    ];
}

// Acelasi pas ca casa_check_product_price(), dar pe shop_price_history: citeste pagina, extrage
// pretul si tine cel mult o intrare pe zi per produs. O verificare esuata nu lasa nimic in istoric.
function shop_check_product_price(mysqli $mysqli, int $productId, string $url): array
{
    $fetched = casa_fetch_page($url);

    $price = null;
    $unitPrice = null;
    $currency = null;
    $ok = 0;
    $error = null;

    if (!$fetched['ok']) {
        $error = mb_substr($fetched['error'], 0, 255);
    } else {
        $extracted = casa_extract_price($fetched['html']);
        if ($extracted === null) {
            $error = 'Prețul nu a putut fi găsit în pagină';
        } else {
            $price = $extracted['price'];
            $unitPrice = $extracted['unit_price'] ?? null;
            if ($unitPrice === null) $unitPrice = casa_detect_unit_price($fetched['html'], (float)$price);
            if ($unitPrice !== null && $price > 0) {
                // Produse vandute la cutie/bax: se urmareste pretul pe mp (vezi casa/_price_check.php).
                $factor = $unitPrice / $price;
                $rescale = $mysqli->prepare('UPDATE shop_price_history SET price = ROUND(price * ?, 2), unit_price = ROUND(price * ?, 2) WHERE product_id = ? AND unit_price IS NULL');
                $rescale->bind_param('ddi', $factor, $factor, $productId);
                $rescale->execute();
                $price = $unitPrice;
            }
            $currency = $extracted['currency'] ?: 'RON';
            $ok = 1;
        }
    }

    if ($ok === 1) {
        $todayStmt = $mysqli->prepare('SELECT id FROM shop_price_history WHERE product_id = ? AND DATE(checked_at) = CURDATE() LIMIT 1');
        $todayStmt->bind_param('i', $productId);
        $todayStmt->execute();
        $todayRow = $todayStmt->get_result()->fetch_assoc();

        if ($todayRow) {
            $update = $mysqli->prepare('UPDATE shop_price_history SET price = ?, unit_price = ?, currency = ?, checked_at = NOW() WHERE id = ?');
            $update->bind_param('ddsi', $price, $unitPrice, $currency, $todayRow['id']);
            $update->execute();
        } else {
            $insert = $mysqli->prepare('INSERT INTO shop_price_history (product_id, price, unit_price, currency, ok, error) VALUES (?, ?, ?, ?, 1, NULL)');
            $insert->bind_param('idds', $productId, $price, $unitPrice, $currency);
            $insert->execute();
        }
    }

    return ['id' => $productId, 'ok' => (bool)$ok, 'price' => $price, 'unit_price' => $unitPrice, 'currency' => $currency, 'error' => $error];
}
