<?php
// Shared helpers for the /ucp/admin/*.php property-editor pages.
require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/functions.php';

// Editing houses/businesses/vehicles/farms/hotels/fastfood requires admin level 5 in-game
// (same as /hc /bc /vc /farmc /htlc /ffc), same rule enforced here.
function ucp_admin_require_level5() {
    ucp_require_admin();
    if (ucp_current_admin_level() < 5) {
        header('Location: ' . UCP_BASE . '/dashboard.php');
        exit;
    }
}

// Looks up a player by id, returns the username or null if not found
function ucp_username_by_id($mysqli, $id) {
    $id = (int)$id;
    if ($id <= 0) return null;
    $stmt = $mysqli->prepare("SELECT `username` FROM `players` WHERE `id` = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ? $row['username'] : null;
}
