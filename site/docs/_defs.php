<?php
require_once __DIR__ . '/../includes/themes.php';
// Shared helpers for /docs.php and its action endpoints in this folder.
// A document is a tracked name + expiration date, optionally linked to a company ("firma").
// Companies are their own managed table (add/rename/delete), same pattern as cocktail_filters -
// the user picks from a dropdown instead of retyping free text, and deleting a company just
// unlinks its documents (they fall back to "Fara firma") rather than deleting them.

const DOCS_NAME_MAX = 150;
const DOCS_COMPANY_NAME_MAX = 120;
const DOCS_COMPANY_PASSWORD_MAX = 60;
const DOCS_EXPIRING_SOON_DAYS = 7;
const DOCS_TASK_TEXT_MAX = 255;

function docs_ensure_tables(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS docs_companies (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(120) NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Parola opțională a firmei - logarea cu ea îți restrânge sesiunea doar la documentele ei
    // (vezi /docs/_auth.php). NULL/gol înseamnă că firma n-are propria parolă de acces.
    $hasPasswordCol = $mysqli->query("SHOW COLUMNS FROM docs_companies LIKE 'password'");
    if ($hasPasswordCol && $hasPasswordCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE docs_companies ADD COLUMN password VARCHAR(' . DOCS_COMPANY_PASSWORD_MAX . ') NULL AFTER name');
        // Migrare unica din vechea parola hardcodata pentru "Dr. Vacaru" (1234), inainte ca
        // parolele per-firma sa fie stocate in baza de date.
        $mysqli->query("UPDATE docs_companies SET password = '1234' WHERE name = 'Dr. Vacaru'");
    }
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS docs_items (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(150) NOT NULL,
            company_id INT UNSIGNED NULL,
            expires_at DATE NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS docs_tasks (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            doc_id INT UNSIGNED NOT NULL,
            text VARCHAR(255) NOT NULL,
            completed_at DATE NULL,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY doc_id (doc_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );

    // Migration from the first version of this page, which stored the company as free text
    // directly on docs_items instead of a separate managed table.
    $hasOldCompanyCol = $mysqli->query("SHOW COLUMNS FROM docs_items LIKE 'company'");
    if ($hasOldCompanyCol && $hasOldCompanyCol->num_rows > 0) {
        $hasCompanyIdCol = $mysqli->query("SHOW COLUMNS FROM docs_items LIKE 'company_id'");
        if ($hasCompanyIdCol && $hasCompanyIdCol->num_rows === 0) {
            $mysqli->query('ALTER TABLE docs_items ADD COLUMN company_id INT UNSIGNED NULL AFTER company');
        }
        $res = $mysqli->query("SELECT DISTINCT company FROM docs_items WHERE company IS NOT NULL AND company != ''");
        if ($res) {
            while ($row = $res->fetch_assoc()) {
                $name = $row['company'];
                $mysqli->query('INSERT IGNORE INTO docs_companies (name) VALUES (\'' . $mysqli->real_escape_string($name) . '\')');
                $mysqli->query(
                    'UPDATE docs_items di JOIN docs_companies dc ON dc.name = \'' . $mysqli->real_escape_string($name) . '\'
                     SET di.company_id = dc.id WHERE di.company = \'' . $mysqli->real_escape_string($name) . '\''
                );
            }
        }
        $mysqli->query('ALTER TABLE docs_items DROP COLUMN company');
    }
}

// 'expired' (red) | 'soon' (within DOCS_EXPIRING_SOON_DAYS, amber) | 'valid' (green).
function docs_status(string $expiresAt): string
{
    $today = strtotime('today');
    $expires = strtotime($expiresAt);
    if ($expires < $today) return 'expired';
    if ($expires <= strtotime('+' . DOCS_EXPIRING_SOON_DAYS . ' days', $today)) return 'soon';
    return 'valid';
}
