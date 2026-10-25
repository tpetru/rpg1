<?php
require_once __DIR__ . '/../includes/themes.php';
// Shared definitions for the /cs utility-lineup pages. Each map lives in its own folder
// (/cs/<map>/) with an index.php shim, and its photos sit in /cs/<map>/photos/.
// Photo metadata (short description + category) is kept in the `cs_photos` table, keyed by
// map slug + filename, so the folder stays the source of truth for which photos exist.

$csMaps = [
    'dust'    => 'Dust',
    'mirage'  => 'Mirage',
    'inferno' => 'Inferno',
    'nuke'    => 'Nuke',
];

// Short codes for the floating map nav, so each button reads at a glance.
$csMapLetters = [
    'dust'    => 'D',
    'mirage'  => 'M',
    'inferno' => 'I',
    'nuke'    => 'N',
];

$csCategories = [
    'smoke'    => 'Smoke',
    'molotov'  => 'Molotov',
    'grenade'  => 'Grenade',
    'flash'    => 'Flash',
];

$csImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

// /cs/reels/ tine link-uri Instagram cu execute-uri, separat de hartile cu poze de mai sus
// (Cache nu are pagina de poze, dar apare aici ca optiune de harta pentru reels).
$csReelMaps = [
    'dust'    => 'Dust',
    'mirage'  => 'Mirage',
    'inferno' => 'Inferno',
    'nuke'    => 'Nuke',
    'cache'   => 'Cache',
    'ancient' => 'Ancient',
];

$csReelTeams = [
    't'  => 'T',
    'ct' => 'CT',
];

function cs_photos_dir(string $map): string
{
    return __DIR__ . '/' . $map . '/photos';
}

function cs_photo_files(string $map, array $csImageExtensions): array
{
    $dir = cs_photos_dir($map);
    $files = [];
    if (is_dir($dir)) {
        foreach (scandir($dir) as $file) {
            $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
            if (in_array($ext, $csImageExtensions, true)) {
                $files[] = $file;
            }
        }
        sort($files, SORT_NATURAL | SORT_FLAG_CASE);
    }
    return $files;
}

// Creates /cs/<map>/photos/ for every map if missing, so uploads always have a target folder.
function cs_ensure_photo_dirs(array $csMaps): void
{
    foreach (array_keys($csMaps) as $map) {
        $dir = cs_photos_dir($map);
        if (!is_dir($dir)) @mkdir($dir, 0777, true);
    }
}

function cs_ensure_tables(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS cs_photos (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            map_slug VARCHAR(32) NOT NULL,
            filename VARCHAR(255) NOT NULL,
            description VARCHAR(128) NULL,
            category VARCHAR(16) NOT NULL DEFAULT "smoke",
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY map_file (map_slug, filename)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Added after the table already existed on some installs.
    $hasSortCol = $mysqli->query("SHOW COLUMNS FROM cs_photos LIKE 'sort_order'");
    if ($hasSortCol && $hasSortCol->num_rows === 0) {
        $mysqli->query('ALTER TABLE cs_photos ADD COLUMN sort_order INT NOT NULL DEFAULT 0 AFTER category');
    }
}

function cs_ensure_reels_table(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS cs_reels (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            url VARCHAR(255) NOT NULL,
            map_slug VARCHAR(32) NOT NULL,
            team VARCHAR(4) NOT NULL DEFAULT "t",
            description VARCHAR(128) NULL,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

// Accepta doar link-uri instagram.com/reel|reels|p/<cod>/ si le normalizeaza (fara query string,
// fara mobile params) inainte de a le baga in data-instgrm-permalink pentru embed.js.
function cs_clean_instagram_url(string $url): ?string
{
    $parts = parse_url($url);
    if (!$parts || empty($parts['host']) || stripos($parts['host'], 'instagram.com') === false) {
        return null;
    }
    if (empty($parts['path']) || !preg_match('#^/(reel|reels|p)/([A-Za-z0-9_-]+)/?#', $parts['path'], $m)) {
        return null;
    }
    return 'https://www.instagram.com/' . $m[1] . '/' . $m[2] . '/';
}

// Renumbers a map's photos sequentially (0,1,2...) in their current display order, so sort_order is
// always unique and gap-free before a swap. Returns the ordered filename list.
function cs_normalize_order(mysqli $mysqli, string $map, array $orderedFiles): array
{
    $stmt = $mysqli->prepare(
        'INSERT INTO cs_photos (map_slug, filename, sort_order) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order)'
    );
    foreach ($orderedFiles as $i => $file) {
        $stmt->bind_param('ssi', $map, $file, $i);
        $stmt->execute();
    }
    return $orderedFiles;
}
