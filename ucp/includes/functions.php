<?php
// Formateaza o suma cu separator de mii (".") - echivalentul MoneyStr() din gamemode
function ucp_money($amount) {
    return number_format((float)$amount, 0, '.', '.');
}

// Starea unui document de vehicul (asigurare/kit medical/extinctor/ITP), coloana DATE.
// Oglindeste VehicleDoc_IsValid()/VehicleDoc_Status() din bare.pwn: valid pana la finalul zilei calendaristice.
function ucp_doc_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Expired', 'ok' => false];

    $expDay   = strtotime(date('Y-m-d', strtotime($dateStr)));
    $todayDay = strtotime(date('Y-m-d'));

    if ($expDay < $todayDay) return ['label' => 'Expired', 'ok' => false];

    $days = (int)round(($expDay - $todayDay) / 86400) + 1;
    return ['label' => $days . ' days', 'ok' => true];
}

// Status of a driving license (driving_lic_a/b/c/d_exp) - same mechanism as vehicle documents
function ucp_license_status($dateStr) {
    if (empty($dateStr) || $dateStr === '0000-00-00') return ['label' => 'Not held', 'ok' => false];
    return ucp_doc_status($dateStr);
}

function ucp_escape($str) {
    return htmlspecialchars((string)$str, ENT_QUOTES, 'UTF-8');
}

// Faction name by ID (1-7), mirroring FactionData from bare.pwn
function ucp_faction_name($id) {
    $names = [
        1 => 'Romanian Police',
        2 => 'Romanian Vehicle Registry',
        3 => 'SMURD',
        4 => 'European Mafia',
        5 => 'American Mafia',
        6 => 'African Mafia',
        7 => 'Asian Mafia',
    ];
    return $names[(int)$id] ?? 'No faction';
}
