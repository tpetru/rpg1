<?php
// Temele vizuale ale /casa. Separate de cele ale restului site-ului (/includes/themes.php):
// acolo sunt teme de copii cu desene pe fundal, aici e proiectul casei - doua teme sobre.
//
// Tema activa sta intr-un cookie citit la randare si pusa pe <html data-casa-theme="...">, ca sa
// nu apara licarire; comutarea in pagina o face assets/theme-switch.js - propria copie a casei
// (identic cu /assets/theme-switch.js de la restul site-ului, dar dus local dupa ce /casa a primit
// propriul DocumentRoot pe subdomeniu si nu mai vede folderul assets/ comun), configurat prin data-*
// pe selector.
//
// Culorile: "dark" e chiar tema din assets/casa-theme.css (charcoal + alama), deci n-are nevoie de
// nimic in plus; "cream" isi suprascrie token-urile in assets/casa-themes.css.

const CASA_THEME_COOKIE = 'casa_theme';
const CASA_THEME_DEFAULT = 'dark';
const CASA_THEMES = [
    'dark'    => ['label' => 'Noapte', 'emoji' => '🌙'],
    'cream'   => ['label' => 'Cremă', 'emoji' => '🫖'],
    'santier' => ['label' => 'Șantier', 'emoji' => '🧱'],
    'plante'  => ['label' => 'Plante', 'emoji' => '🌿'],
];

function casa_theme(): string
{
    $theme = $_COOKIE[CASA_THEME_COOKIE] ?? '';
    return isset(CASA_THEMES[$theme]) ? $theme : CASA_THEME_DEFAULT;
}

// De pus in <head>, dupa link-ul catre casa-theme.css - fisierul de teme doar scrie peste ea.
function casa_render_theme_head(): void
{
    $cssPath = __DIR__ . '/assets/casa-themes.css';
    $jsPath = __DIR__ . '/assets/theme-switch.js';
    echo '<link rel="stylesheet" href="/assets/casa-themes.css?v=' . @filemtime($cssPath) . '">' . "\n";
    echo '<script src="/assets/theme-switch.js?v=' . @filemtime($jsPath) . '" defer></script>' . "\n";
}

function casa_render_theme_picker(string $extraClass = ''): void
{
    $current = casa_theme();
    $cls = 'theme-picker' . ($extraClass !== '' ? ' ' . $extraClass : '');
    echo '<div class="' . htmlspecialchars($cls) . '">' . "\n";
    echo '  <select class="theme-select" aria-label="Temă" data-cookie="' . CASA_THEME_COOKIE . '"'
        . ' data-attr="data-casa-theme" data-path="/">' . "\n";
    foreach (CASA_THEMES as $key => $theme) {
        echo '    <option value="' . htmlspecialchars($key) . '"' . ($key === $current ? ' selected' : '') . '>'
            . $theme['emoji'] . ' ' . htmlspecialchars($theme['label'])
            . "</option>\n";
    }
    echo "  </select>\n";
    echo "</div>\n";
}

function casa_render_footer(): void
{
    echo "<footer class=\"site-footer\">\n";
    echo "  <span class=\"site-footer-label\">Temă</span>\n";
    casa_render_theme_picker();
    echo "</footer>\n";
}
