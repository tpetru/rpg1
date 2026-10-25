<?php
// Shared stage definitions - used by index.php (render) and stage_photos_fetch.php (AJAX refresh)
// so they can't drift apart. Each stage maps to a folder under stage_photos/ where real progress
// photos live (e.g. "03-fundatie/"), scanned the same way the room design galleries work.

$stageLabels = [
    1 => 'Teren',
    2 => 'Săpătură',
    3 => 'Fundație',
    4 => 'Zidărie',
    5 => 'Acoperiș',
    6 => 'Instalații',
    7 => 'Tencuială',
    8 => 'Izolație',
    9 => 'Finisaje interior',
    10 => 'Finisaje exterior',
    11 => 'Cheie',
];
$stageCount = count($stageLabels);

// The house's current stage is derived from the "Progres general" checklist, not set by hand: it's
// the first stage that still has an item not fully achizitionat+montat, skipping over stages with no
// items tagged to them; once everything itemized is done, it settles on the last stage ("Cheie").
function casa_derive_stage(array $items, int $stageCount): int
{
    if (empty($items)) return 1;
    $byStage = [];
    foreach ($items as $item) {
        $s = (int)$item['stage'];
        if (!isset($byStage[$s])) $byStage[$s] = ['total' => 0, 'done' => 0];
        $byStage[$s]['total']++;
        if ($item['achizitionat'] && $item['montat']) $byStage[$s]['done']++;
    }
    $stage = 1;
    for ($s = 1; $s <= $stageCount; $s++) {
        $bucket = $byStage[$s] ?? null;
        $complete = !$bucket || $bucket['done'] === $bucket['total'];
        if ($complete) {
            $stage = min($s + 1, $stageCount);
        } else {
            $stage = $s;
            break;
        }
    }
    return $stage;
}

function casa_slugify(string $text): string
{
    $map = [
        'ă' => 'a', 'â' => 'a', 'î' => 'i', 'ș' => 's', 'ş' => 's', 'ț' => 't', 'ţ' => 't',
        'Ă' => 'a', 'Â' => 'a', 'Î' => 'i', 'Ș' => 's', 'Ş' => 's', 'Ț' => 't', 'Ţ' => 't',
    ];
    $text = strtr($text, $map);
    $text = mb_strtolower($text);
    $text = preg_replace('/[^a-z0-9]+/', '-', $text);
    return trim($text, '-');
}

function casa_stage_folder_slug(int $num, string $label): string
{
    return sprintf('%02d-%s', $num, casa_slugify($label));
}

function casa_stage_photos_dir(string $houseSlug, int $num, string $label): string
{
    return casa_house_dir($houseSlug) . '/stage_photos/' . casa_stage_folder_slug($num, $label);
}

// Creates the stage_photos/<NN-slug>/ folder for every stage if missing, so the user always has a
// ready-made place to drop progress photos into without creating folders by hand.
function casa_ensure_stage_folders(string $houseSlug, array $stageLabels): void
{
    $base = casa_house_dir($houseSlug) . '/stage_photos';
    casa_make_dir($base);
    foreach ($stageLabels as $num => $label) {
        $dir = casa_stage_photos_dir($houseSlug, $num, $label);
        casa_make_dir($dir);
    }
}

// Header badge text ("ETAPA 7 · TENCUIALĂ") shown on every page's nav, not just progres.php.
// Reads the same construction-items table progres.php uses, so it can never drift from it.
function casa_current_stage_tag(mysqli $mysqli, int $houseId, array $stageLabels, int $stageCount): string
{
    $items = [];
    $stmt = $mysqli->prepare('SELECT stage, achizitionat, montat FROM casa_construction_items WHERE house_id = ?');
    $stmt->bind_param('i', $houseId);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($res) {
        while ($row = $res->fetch_assoc()) $items[] = $row;
    }
    $stage = casa_derive_stage($items, $stageCount);
    return 'ETAPA ' . $stage . ' · ' . mb_strtoupper($stageLabels[$stage], 'UTF-8');
}

function casa_stage_photo_files(string $houseSlug, int $num, string $label): array
{
    $dir = casa_stage_photos_dir($houseSlug, $num, $label);
    $exts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    $files = [];
    if (is_dir($dir)) {
        foreach (scandir($dir) as $f) {
            $ext = strtolower(pathinfo($f, PATHINFO_EXTENSION));
            if (in_array($ext, $exts, true)) {
                $files[] = '/' . rawurlencode($houseSlug) . '/stage_photos/' . casa_stage_folder_slug($num, $label) . '/' . rawurlencode($f);
            }
        }
        sort($files, SORT_NATURAL | SORT_FLAG_CASE);
    }
    return $files;
}
