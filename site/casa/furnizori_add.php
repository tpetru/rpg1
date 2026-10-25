<?php
require_once __DIR__ . '/_auth.php';
casa_require_admin_api_auth();
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_suppliers.php';
casa_suppliers_ensure_table($mysqli);
// Adauga un furnizor. AJAX + raspuns JSON.
header('Content-Type: application/json');

$name = trim((string)($_POST['name'] ?? ''));
$category = trim((string)($_POST['category'] ?? ''));
$subcategory = trim((string)($_POST['subcategory'] ?? ''));
$tags = casa_supplier_clean_tags((string)($_POST['tags'] ?? ''));
$url = trim((string)($_POST['url'] ?? ''));

if ($name === '' || mb_strlen($name) > CASA_SUPPLIER_NAME_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Numele furnizorului lipsește sau e prea lung.']);
    exit;
}
if (mb_strlen($category) > CASA_SUPPLIER_CATEGORY_MAX || mb_strlen($subcategory) > CASA_SUPPLIER_CATEGORY_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Categoria sau subcategoria e prea lungă.']);
    exit;
}
if (mb_strlen($tags) > CASA_SUPPLIER_TAGS_MAX || mb_strlen($url) > CASA_SUPPLIER_URL_MAX) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Tag-urile sau link-ul sunt prea lungi.']);
    exit;
}
// Un link fara schema ("emag.ro") ar fi interpretat ca o cale relativa in browser - il completam.
if ($url !== '' && !preg_match('#^https?://#i', $url)) {
    $url = 'https://' . $url;
}

$maxRes = $mysqli->query('SELECT COALESCE(MAX(sort_order), 0) AS m FROM casa_suppliers');
$next = (int)$maxRes->fetch_assoc()['m'] + 1;

$stmt = $mysqli->prepare(
    'INSERT INTO casa_suppliers (name, category, subcategory, tags, url, sort_order) VALUES (?, ?, ?, ?, ?, ?)'
);
$stmt->bind_param('sssssi', $name, $category, $subcategory, $tags, $url, $next);
$stmt->execute();

echo json_encode(['ok' => true, 'id' => $mysqli->insert_id]);
