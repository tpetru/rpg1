<?php
// Furnizorii de materiale - lista tinuta in zona de admin a /casa (vezi furnizori.php).
//
// Spre deosebire de restul datelor din /casa, furnizorii NU sunt legati de o casa anume: sunt
// aceiasi indiferent pe ce santier lucrezi, asa ca stau intr-un tabel global, vizibil doar cu
// parola de admin.

const CASA_SUPPLIER_NAME_MAX = 120;
const CASA_SUPPLIER_CATEGORY_MAX = 60;
const CASA_SUPPLIER_TAGS_MAX = 255;
const CASA_SUPPLIER_URL_MAX = 500;

function casa_suppliers_ensure_table(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS casa_suppliers (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(120) NOT NULL,
            category VARCHAR(60) NOT NULL DEFAULT \'\',
            subcategory VARCHAR(60) NOT NULL DEFAULT \'\',
            tags VARCHAR(255) NOT NULL DEFAULT \'\',
            url VARCHAR(500) NOT NULL DEFAULT \'\',
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY sort_order (sort_order)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

// Tag-urile se tin ca text separat prin virgula. Functia curata spatiile si intrarile goale, ca
// "vopsea , , interior" sa devina "vopsea, interior".
function casa_supplier_clean_tags(string $raw): string
{
    $tags = array_filter(array_map('trim', explode(',', $raw)), fn($t) => $t !== '');
    return implode(', ', $tags);
}

function casa_supplier_tag_list(string $tags): array
{
    return array_values(array_filter(array_map('trim', explode(',', $tags)), fn($t) => $t !== ''));
}

function casa_suppliers_all(mysqli $mysqli): array
{
    casa_suppliers_ensure_table($mysqli);
    $rows = [];
    $res = $mysqli->query('SELECT id, name, category, subcategory, tags, url FROM casa_suppliers ORDER BY sort_order ASC, id ASC');
    while ($row = $res->fetch_assoc()) {
        $row['id'] = (int)$row['id'];
        $rows[] = $row;
    }
    return $rows;
}
