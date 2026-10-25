<?php
require_once __DIR__ . '/../includes/themes.php';
// Shared helpers for /cocktails.php and its action endpoints in this folder.
// Filters are fully user-managed (add/rename/delete) - not a fixed enum like the /cs/ categories.

const COCKTAIL_DESC_MAX = 256;
const COCKTAIL_FILTER_NAME_MAX = 32;

function cocktail_ensure_tables(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS cocktail_filters (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(32) NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY name (name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS cocktail_reels (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            url VARCHAR(255) NOT NULL,
            description VARCHAR(256) NULL,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
    // Many-to-many: a reel can carry more than one filter tag (e.g. "rum" + "tiki").
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS cocktail_reel_filters (
            reel_id INT UNSIGNED NOT NULL,
            filter_id INT UNSIGNED NOT NULL,
            PRIMARY KEY (reel_id, filter_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );
}

// Accepta doar link-uri instagram.com/reel|reels|p/<cod>/ si le normalizeaza inainte de a le baga
// in data-instgrm-permalink pentru embed.js.
function cocktail_clean_instagram_url(string $url): ?string
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

// Filter ids assigned to a reel, keyed by reel id.
function cocktail_filters_by_reel(mysqli $mysqli): array
{
    $byReel = [];
    $res = $mysqli->query('SELECT reel_id, filter_id FROM cocktail_reel_filters');
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $byReel[(int)$row['reel_id']][] = (int)$row['filter_id'];
        }
    }
    return $byReel;
}

// Replaces a reel's filter assignments with exactly $filterIds (validated against $validIds first).
function cocktail_set_reel_filters(mysqli $mysqli, int $reelId, array $filterIds, array $validIds): void
{
    $filterIds = array_values(array_unique(array_intersect(array_map('intval', $filterIds), $validIds)));

    $del = $mysqli->prepare('DELETE FROM cocktail_reel_filters WHERE reel_id = ?');
    $del->bind_param('i', $reelId);
    $del->execute();

    if (!$filterIds) return;
    $ins = $mysqli->prepare('INSERT INTO cocktail_reel_filters (reel_id, filter_id) VALUES (?, ?)');
    foreach ($filterIds as $fid) {
        $ins->bind_param('ii', $reelId, $fid);
        $ins->execute();
    }
}
