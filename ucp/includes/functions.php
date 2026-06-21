<?php
// Formateaza o suma cu separator de mii (".") - echivalentul MoneyStr() din gamemode
function ucp_money($amount) {
    return number_format((float)$amount, 0, '.', '.');
}

// Starea unui document de vehicul (asigurare/kit medical/extinctor/ITP), coloana DATE.
// Oglindeste VehicleDoc_IsValid()/VehicleDoc_Status() din bare.pwn: valid pana la finalul zilei calendaristice.
function ucp_doc_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Expirat', 'ok' => false];

    $expDay   = strtotime(date('Y-m-d', strtotime($dateStr)));
    $todayDay = strtotime(date('Y-m-d'));

    if ($expDay < $todayDay) return ['label' => 'Expirat', 'ok' => false];

    $days = (int)round(($expDay - $todayDay) / 86400) + 1;
    return ['label' => $days . ' zile', 'ok' => true];
}

// Starea unui permis auto (driving_lic_a/b/c/d_exp) - acelasi mecanism ca docurile de vehicul
function ucp_license_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Nedeținut', 'ok' => false];
    return ucp_doc_status($dateStr);
}

function ucp_escape($str) {
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

// Numele facțiunii dupa ID (1-7), oglindind FactionData din bare.pwn
function ucp_faction_name($id) {
    $names = [
        1 => 'Politia Romana',
        2 => 'Registrul Auto Roman',
        3 => 'SMURD',
        4 => 'Mafia Europeana',
        5 => 'Mafia Americana',
        6 => 'Mafia Africana',
        7 => 'Mafia Asiatica',
    ];
    return $names[(int)$id] ?? 'Fără facțiune';
}
