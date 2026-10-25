<?php
require_once __DIR__ . '/_auth.php';
require_once __DIR__ . '/_db.php';
require_once __DIR__ . '/_house.php';
casa_ensure_house_schema($mysqli);
$currentHouse = casa_require_api_house_auth($mysqli);
require_once __DIR__ . '/stage_defs.php';
header('Content-Type: application/json');

$stage = (int)($_GET['stage'] ?? 0);
if ($stage < 1 || $stage > $stageCount) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'invalid stage']);
    exit;
}

$label = $stageLabels[$stage];
echo json_encode([
    'ok' => true,
    'stage' => $stage,
    'label' => $label,
    'folder' => casa_stage_folder_slug($stage, $label),
    'photos' => casa_stage_photo_files($currentHouse['slug'], $stage, $label),
]);
