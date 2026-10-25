<?php
// Temele vizuale ale site-ului (/aris, /docs.php, /cocktails.php, /cs). Tema activa e tinuta
// intr-un cookie si pusa de PHP pe <html data-theme="...">, ca sa nu apara licarire la incarcare;
// comutarea in pagina o face /assets/theme-switch.js, fara reload.
//
// Lista de teme traieste in tabelul site_themes: de acolo se activeaza/dezactiveaza fiecare tema
// (is_enabled) si li se schimba ordinea sau eticheta, fara sa umbli in cod. Randurile se creeaza
// singure la prima rulare, din ARIS_THEME_DEFAULTS de mai jos.
//
// Culorile fiecarei teme stau in /assets/themes.css, iar desenul de fundal in /assets/patterns/.

const SITE_THEME_COOKIE = 'site_theme';
const SITE_THEME_FALLBACK = 'classic'; // tema care ramane valabila chiar daca toate sunt dezactivate

// Cheie => [eticheta, emoji, ordine]. Folosite la popularea initiala a tabelului si ca plasa de
// siguranta cand pagina n-are conexiune la baza de date.
const SITE_THEME_DEFAULTS = [
    'kids'      => ['Alimente', '🥕', 10],
    'masini'    => ['Mașinuțe', '🚗', 20],
    'camioane'  => ['Camioane', '🚜', 30],
    'ursuleti'  => ['Ursuleți', '🧸', 40],
    'natura'    => ['Natură', '🌿', 50],
    'primavara' => ['Primăvară', '🌷', 60],
    'vara'      => ['Vară', '☀️', 70],
    'toamna'    => ['Toamnă', '🍂', 80],
    'iarna'     => ['Iarnă', '❄️', 90],
    'classic'   => ['Clasic', '🌙', 100],
];

function site_themes_ensure_table(mysqli $mysqli): void
{
    $mysqli->query(
        'CREATE TABLE IF NOT EXISTS site_themes (
            theme_key VARCHAR(32) NOT NULL,
            label VARCHAR(60) NOT NULL,
            emoji VARCHAR(16) NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            is_enabled TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (theme_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );

    // Temele noi aparute in cod se adauga automat; INSERT IGNORE nu atinge randurile existente,
    // deci ce ai dezactivat sau redenumit in baza de date ramane asa.
    $stmt = $mysqli->prepare('INSERT IGNORE INTO site_themes (theme_key, label, emoji, sort_order) VALUES (?, ?, ?, ?)');
    foreach (SITE_THEME_DEFAULTS as $key => [$label, $emoji, $order]) {
        $stmt->bind_param('sssi', $key, $label, $emoji, $order);
        $stmt->execute();
    }
}

// Cache-ul pe cerere al temelor active: apelat cu un array il seteaza, fara argument il citeste.
// Paginile cu baza de date apeleaza site_theme_init($mysqli) o data, sus; cele fara ea raman pe
// valorile implicite.
function site_themes_cache(?array $themes = null): ?array
{
    static $cache = null;
    if ($themes !== null) $cache = $themes;
    return $cache;
}

function site_theme_init(mysqli $mysqli): void
{
    site_themes_ensure_table($mysqli);

    $themes = [];
    $res = $mysqli->query('SELECT theme_key, label, emoji FROM site_themes WHERE is_enabled = 1 ORDER BY sort_order ASC, theme_key ASC');
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $themes[$row['theme_key']] = ['label' => $row['label'], 'emoji' => $row['emoji']];
        }
    }

    site_themes_cache($themes);
}

// Temele care se ofera userului. Daca nu s-a citit nimic din baza de date (pagina fara $mysqli)
// sau daca au fost dezactivate toate, ramane macar tema clasica - altfel selectorul ar fi gol.
function site_themes(): array
{
    $cache = site_themes_cache();
    if ($cache === null) {
        $themes = [];
        foreach (SITE_THEME_DEFAULTS as $key => [$label, $emoji, $order]) {
            $themes[$key] = ['label' => $label, 'emoji' => $emoji];
        }
        return $themes;
    }
    if (empty($cache)) {
        [$label, $emoji] = SITE_THEME_DEFAULTS[SITE_THEME_FALLBACK];
        return [SITE_THEME_FALLBACK => ['label' => $label, 'emoji' => $emoji]];
    }
    return $cache;
}

// Tema ceruta prin cookie, daca mai e activa; altfel prima din lista (respectiv cea clasica).
function site_theme(): string
{
    $themes = site_themes();
    $wanted = $_COOKIE[SITE_THEME_COOKIE] ?? '';
    if (isset($themes[$wanted])) return $wanted;
    if (isset($themes[SITE_THEME_FALLBACK])) return SITE_THEME_FALLBACK;
    return (string)array_key_first($themes);
}

// De pus in <head>, dupa link-ul catre /assets/theme.css (tema de baza, peste care se scrie).
function site_render_theme_head(): void
{
    $cssPath = __DIR__ . '/../assets/themes.css';
    $jsPath = __DIR__ . '/../assets/theme-switch.js';
    echo '<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&family=Nunito:wght@400;600;700;800&display=swap" rel="stylesheet">' . "\n";
    echo '<link rel="stylesheet" href="/assets/themes.css?v=' . @filemtime($cssPath) . '">' . "\n";
    echo '<script src="/assets/theme-switch.js?v=' . @filemtime($jsPath) . '" defer></script>' . "\n";
}

function site_render_theme_picker(string $extraClass = ''): void
{
    $themes = site_themes();
    if (count($themes) < 2) return; // o singura tema activa - n-are rost un selector

    $current = site_theme();
    $cls = 'theme-picker' . ($extraClass !== '' ? ' ' . $extraClass : '');
    echo '<div class="' . htmlspecialchars($cls) . '">' . "\n";
    echo '  <select class="theme-select" aria-label="Temă">' . "\n";
    foreach ($themes as $key => $theme) {
        echo '    <option value="' . htmlspecialchars($key) . '"' . ($key === $current ? ' selected' : '') . '>'
            . $theme['emoji'] . ' ' . htmlspecialchars($theme['label'])
            . "</option>\n";
    }
    echo "  </select>\n";
    echo "</div>\n";
}

// Footer comun: deocamdata doar selectorul de teme, centrat sub continut.
function site_render_footer(): void
{
    if (count(site_themes()) < 2) return;
    echo "<footer class=\"site-footer\">\n";
    echo "  <span class=\"site-footer-label\">Temă</span>\n";
    site_render_theme_picker();
    echo "</footer>\n";
}
