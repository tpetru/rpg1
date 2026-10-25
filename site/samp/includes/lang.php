<?php
// ============================================================
//  LANG (site) - EN/RO in functie de players.language
// ------------------------------------------------------------
//  Aceeasi idee ca in gamemode (pawno/include/lang.inc): textul ENGLEZ
//  din sursa e cheia de traducere. t('English text') cauta traducerea in
//  includes/lang/ro.php si o returneaza; daca nu exista, ramane engleza -
//  deci site-ul functioneaza corect si cu dictionarul gol.
//
//  Limba jucatorului:
//    - logat in UCP  -> `players`.`language` (coloana DB, aceeasi pe care
//                        o seteaza /en si /ro din joc) - sursa unica de adevar
//    - vizitator     -> cookie-ul `site_lang`, setat de switcher-ul EN/RO
//                        din header (set_language.php)
//
//  De facut o singura data, la inceputul oricarei pagini (inainte de orice
//  output): require_once __DIR__ . '/includes/lang.php'; (ajusteaza calea
//  relativa dupa adancimea fisierului). Se poate include de oricate ori -
//  e require_once si idempotent.
// ============================================================

if (!function_exists('t')) {

    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    require_once __DIR__ . '/../../includes/db.php';

    function site_lang_detect() {
        global $mysqli;

        // Utilizator logat: players.language e sursa unica de adevar (sincron cu /en, /ro din joc)
        if (isset($_SESSION['ucp_player_id']) && isset($mysqli)) {
            $pid = (int)$_SESSION['ucp_player_id'];
            $stmt = $mysqli->prepare("SELECT `language` FROM `players` WHERE `id` = ? LIMIT 1");
            $stmt->bind_param('i', $pid);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if ($row) {
                return strtolower((string)$row['language']) === 'ro' ? 'ro' : 'en';
            }
        }

        // Vizitator neautentificat: cookie-ul setat de switcher-ul din header
        if (isset($_COOKIE['site_lang']) && $_COOKIE['site_lang'] === 'ro') {
            return 'ro';
        }
        return 'en';
    }

    $GLOBALS['__site_lang'] = site_lang_detect();
    $GLOBALS['__site_dict'] = ($GLOBALS['__site_lang'] === 'ro') ? require __DIR__ . '/lang/ro.php' : [];

    // Traduce un text (cheia = textul englez din sursa). Text lipsa din dictionar -> ramane englez.
    function t($text) {
        return $GLOBALS['__site_dict'][$text] ?? $text;
    }

    // La fel ca t(), dar tipareste direct, cu escaping HTML (comod pt output inline)
    function te($text) {
        echo htmlspecialchars(t($text), ENT_QUOTES, 'UTF-8');
    }

    // 'en' sau 'ro' - limba curenta a vizitatorului/jucatorului
    function site_lang_current() {
        return $GLOBALS['__site_lang'];
    }
}
