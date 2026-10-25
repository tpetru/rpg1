<?php
// Helpers pentru forumul simplu.
// Ierarhie: z_forum_categories -> z_forum_subcategories -> z_forum_topics -> z_forum_posts.
// Moderarea (pin/lock/status/stergere) foloseste acelasi prag ca admincmds: admin_level >= 1.

$GLOBALS['forumStatusLabels'] = [
    'open'        => ['Open', 'warn'],
    'in_progress' => ['In Progress', 'good'],
    'resolved'    => ['Resolved', 'ok'],
    'rejected'    => ['Rejected', 'bad'],
];

// Forum permissions use their own tier (`players.admin_forum`), separate from the site's admin_level:
// 1+ = manage structure (move categories/subcategories, post in admin-only subforums)
// 2+ = moderate topics (pin/lock/status, and move pinned topics)
// 3+ = delete (topics/posts)
function ucp_forum_can_manage_structure() {
    return ucp_current_admin_forum() >= 1;
}

function ucp_forum_can_moderate() {
    return ucp_current_admin_forum() >= 2;
}

function ucp_forum_can_delete() {
    return ucp_current_admin_forum() >= 3;
}

function ucp_forum_status_label($status) {
    return $GLOBALS['forumStatusLabels'][$status] ?? ['Open', 'warn'];
}

// Deterministic pseudo-avatar (colored circle + initial) so posts feel like a forum
// without needing profile pictures - color/initial derived from the username.
function ucp_forum_avatar_color($username) {
    $palette = ['#ff6a00','#ff8533','#3ecf8e','#4488ff','#aa44aa','#44aa44','#ffcc00','#36d1c2','#ff5d5d','#85648c'];
    return $palette[crc32($username) % count($palette)];
}

function ucp_forum_avatar($username, $size = 40) {
    $color = ucp_forum_avatar_color($username);
    $initial = ucp_escape(mb_strtoupper(mb_substr($username, 0, 1)));
    $fontSize = round($size * 0.42);
    return '<div class="forum-avatar" style="width:' . (int)$size . 'px;height:' . (int)$size . 'px;background:' . $color . ';font-size:' . $fontSize . 'px">' . $initial . '</div>';
}

// ============================================================
//  CATEGORIES (top level)
// ============================================================
function ucp_forum_categories() {
    global $mysqli;
    $sql = "SELECT c.`id`, c.`name`, c.`slug`, c.`description`,
                   (SELECT COUNT(*) FROM `z_forum_subcategories` s WHERE s.`category_id` = c.`id`) AS subcategory_count,
                   (SELECT COUNT(*) FROM `z_forum_topics` t
                      INNER JOIN `z_forum_subcategories` s ON s.`id` = t.`subcategory_id`
                      WHERE s.`category_id` = c.`id`) AS topic_count,
                   (SELECT COUNT(*) FROM `z_forum_posts` p
                      INNER JOIN `z_forum_topics` t ON t.`id` = p.`topic_id`
                      INNER JOIN `z_forum_subcategories` s ON s.`id` = t.`subcategory_id`
                      WHERE s.`category_id` = c.`id`) AS post_count
            FROM `z_forum_categories` c
            ORDER BY c.`sort_order` ASC";
    return $mysqli->query($sql)->fetch_all(MYSQLI_ASSOC);
}

function ucp_forum_category_by_slug($slug) {
    global $mysqli;
    $stmt = $mysqli->prepare("SELECT `id`,`name`,`slug`,`description` FROM `z_forum_categories` WHERE `slug` = ? LIMIT 1");
    $stmt->bind_param('s', $slug);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

// ============================================================
//  SUBCATEGORIES
// ============================================================
function ucp_forum_subcategories($categoryId) {
    global $mysqli;
    $sql = "SELECT s.`id`, s.`name`, s.`slug`, s.`description`, s.`admin_only_post`, s.`require_login`,
                   (SELECT COUNT(*) FROM `z_forum_topics` t WHERE t.`subcategory_id` = s.`id`) AS topic_count,
                   (SELECT COUNT(*) FROM `z_forum_posts` p
                      INNER JOIN `z_forum_topics` t ON t.`id` = p.`topic_id`
                      WHERE t.`subcategory_id` = s.`id`) AS post_count
            FROM `z_forum_subcategories` s
            WHERE s.`category_id` = ?
            ORDER BY s.`sort_order` ASC";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('i', $categoryId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function ucp_forum_subcategory_by_slug($slug) {
    global $mysqli;
    $sql = "SELECT s.`id`, s.`name`, s.`slug`, s.`description`, s.`admin_only_post`, s.`require_login`,
                   c.`id` AS category_id, c.`name` AS category_name, c.`slug` AS category_slug
            FROM `z_forum_subcategories` s
            INNER JOIN `z_forum_categories` c ON c.`id` = s.`category_id`
            WHERE s.`slug` = ? LIMIT 1";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('s', $slug);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

// Most recently active topic in a subcategory (for the "last activity" column on the subcategory list).
function ucp_forum_last_activity($subcategoryId) {
    global $mysqli;
    $sql = "SELECT t.`id`, t.`title`, t.`last_post_at`, pl.`username`
            FROM `z_forum_topics` t
            INNER JOIN `z_forum_posts` p ON p.`id` = (
                SELECT p2.`id` FROM `z_forum_posts` p2 WHERE p2.`topic_id` = t.`id` ORDER BY p2.`id` DESC LIMIT 1
            )
            INNER JOIN `players` pl ON pl.`id` = p.`player_id`
            WHERE t.`subcategory_id` = ?
            ORDER BY t.`last_post_at` DESC LIMIT 1";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('i', $subcategoryId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

// ============================================================
//  TOPICS
// ============================================================
function ucp_forum_topics($subcategoryId) {
    global $mysqli;
    $sql = "SELECT t.`id`, t.`title`, t.`status`, t.`is_pinned`, t.`is_locked`, t.`created_at`, t.`last_post_at`,
                   pl.`username`,
                   (SELECT COUNT(*) FROM `z_forum_posts` p WHERE p.`topic_id` = t.`id`) AS post_count,
                   (SELECT pl2.`username` FROM `z_forum_posts` p2
                      INNER JOIN `players` pl2 ON pl2.`id` = p2.`player_id`
                      WHERE p2.`topic_id` = t.`id` ORDER BY p2.`id` DESC LIMIT 1) AS last_username
            FROM `z_forum_topics` t
            INNER JOIN `players` pl ON pl.`id` = t.`player_id`
            WHERE t.`subcategory_id` = ?
            ORDER BY t.`is_pinned` DESC, t.`sort_order` ASC, t.`last_post_at` DESC";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('i', $subcategoryId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function ucp_forum_topic($topicId) {
    global $mysqli;
    $sql = "SELECT t.*, pl.`username`,
                   s.`slug` AS subcategory_slug, s.`name` AS subcategory_name, s.`require_login`,
                   c.`slug` AS category_slug, c.`name` AS category_name
            FROM `z_forum_topics` t
            INNER JOIN `z_forum_subcategories` s ON s.`id` = t.`subcategory_id`
            INNER JOIN `z_forum_categories` c ON c.`id` = s.`category_id`
            INNER JOIN `players` pl ON pl.`id` = t.`player_id`
            WHERE t.`id` = ? LIMIT 1";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('i', $topicId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

// Creeaza un topic nou + primul mesaj. Returneaza noul topic id.
function ucp_forum_create_topic($subcategoryId, $playerId, $title, $body) {
    global $mysqli;
    $mysqli->begin_transaction();
    try {
        $stmt = $mysqli->prepare("INSERT INTO `z_forum_topics` (`subcategory_id`,`player_id`,`title`) VALUES (?,?,?)");
        $stmt->bind_param('iis', $subcategoryId, $playerId, $title);
        $stmt->execute();
        $topicId = $stmt->insert_id;
        $stmt->close();

        $stmt = $mysqli->prepare("INSERT INTO `z_forum_posts` (`topic_id`,`player_id`,`body`) VALUES (?,?,?)");
        $stmt->bind_param('iis', $topicId, $playerId, $body);
        $stmt->execute();
        $stmt->close();

        $mysqli->commit();
        return $topicId;
    } catch (mysqli_sql_exception $e) {
        $mysqli->rollback();
        return false;
    }
}

// ============================================================
//  POSTS
// ============================================================
function ucp_forum_posts($topicId) {
    global $mysqli;
    $sql = "SELECT p.`id`, p.`body`, p.`created_at`, p.`edited_at`, p.`player_id`, pl.`username`, pl.`admin_level`, pl.`admin_forum`, pl.`vip`
            FROM `z_forum_posts` p
            INNER JOIN `players` pl ON pl.`id` = p.`player_id`
            WHERE p.`topic_id` = ?
            ORDER BY p.`id` ASC";
    $stmt = $mysqli->prepare($sql);
    $stmt->bind_param('i', $topicId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

// Adauga un reply intr-un topic existent si actualizeaza last_post_at (pt sortarea listei de topicuri).
function ucp_forum_create_post($topicId, $playerId, $body) {
    global $mysqli;
    $mysqli->begin_transaction();
    try {
        $stmt = $mysqli->prepare("INSERT INTO `z_forum_posts` (`topic_id`,`player_id`,`body`) VALUES (?,?,?)");
        $stmt->bind_param('iis', $topicId, $playerId, $body);
        $stmt->execute();
        $stmt->close();

        $stmt = $mysqli->prepare("UPDATE `z_forum_topics` SET `last_post_at` = NOW() WHERE `id` = ?");
        $stmt->bind_param('i', $topicId);
        $stmt->execute();
        $stmt->close();

        $mysqli->commit();
        return true;
    } catch (mysqli_sql_exception $e) {
        $mysqli->rollback();
        return false;
    }
}

// ============================================================
//  MODERATION
// ============================================================
function ucp_forum_set_status($topicId, $status) {
    global $mysqli;
    if (!array_key_exists($status, $GLOBALS['forumStatusLabels'])) return false;
    $stmt = $mysqli->prepare("UPDATE `z_forum_topics` SET `status` = ? WHERE `id` = ?");
    $stmt->bind_param('si', $status, $topicId);
    $stmt->execute();
    $stmt->close();
    return true;
}

function ucp_forum_toggle_pin($topicId) {
    global $mysqli;
    $mysqli->query("UPDATE `z_forum_topics` SET `is_pinned` = 1 - `is_pinned` WHERE `id` = " . (int)$topicId);
}

function ucp_forum_toggle_lock($topicId) {
    global $mysqli;
    $mysqli->query("UPDATE `z_forum_topics` SET `is_locked` = 1 - `is_locked` WHERE `id` = " . (int)$topicId);
}

function ucp_forum_delete_topic($topicId) {
    global $mysqli;
    $stmt = $mysqli->prepare("DELETE FROM `z_forum_topics` WHERE `id` = ?");
    $stmt->bind_param('i', $topicId);
    $stmt->execute();
    $stmt->close();
}

function ucp_forum_delete_post($postId) {
    global $mysqli;
    $stmt = $mysqli->prepare("DELETE FROM `z_forum_posts` WHERE `id` = ?");
    $stmt->bind_param('i', $postId);
    $stmt->execute();
    $stmt->close();
}

// ============================================================
//  MANUAL REORDERING (admin only) - swaps sort_order with the row immediately
//  above/below it within its group, based on position rather than raw value
//  so it works even when several rows share the same sort_order (e.g. 0).
// ============================================================
function ucp_forum_swap_order($rows, $id, $direction, $table) {
    global $mysqli;
    $ids = array_map('intval', array_column($rows, 'id'));
    $idx = array_search((int)$id, $ids, true);
    if ($idx === false) return;
    $swapIdx = $direction === 'up' ? $idx - 1 : $idx + 1;
    if ($swapIdx < 0 || $swapIdx >= count($rows)) return;

    $a = $rows[$idx];
    $b = $rows[$swapIdx];
    $stmt = $mysqli->prepare("UPDATE `$table` SET `sort_order` = ? WHERE `id` = ?");
    $newA = (int)$b['sort_order'];
    $stmt->bind_param('ii', $newA, $a['id']);
    $stmt->execute();
    $newB = (int)$a['sort_order'];
    $stmt->bind_param('ii', $newB, $b['id']);
    $stmt->execute();
    $stmt->close();
}

function ucp_forum_move_category($id, $direction) {
    global $mysqli;
    $rows = $mysqli->query("SELECT `id`, `sort_order` FROM `z_forum_categories` ORDER BY `sort_order` ASC, `id` ASC")->fetch_all(MYSQLI_ASSOC);
    ucp_forum_swap_order($rows, $id, $direction, 'z_forum_categories');
}

function ucp_forum_move_subcategory($id, $direction) {
    global $mysqli;
    $stmt = $mysqli->prepare("SELECT `category_id` FROM `z_forum_subcategories` WHERE `id` = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) return;

    $stmt = $mysqli->prepare("SELECT `id`, `sort_order` FROM `z_forum_subcategories` WHERE `category_id` = ? ORDER BY `sort_order` ASC, `id` ASC");
    $stmt->bind_param('i', $row['category_id']);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    ucp_forum_swap_order($rows, $id, $direction, 'z_forum_subcategories');
}

// Only pinned topics can be manually reordered - regular topics stay sorted by last activity.
function ucp_forum_move_topic($id, $direction) {
    global $mysqli;
    $stmt = $mysqli->prepare("SELECT `subcategory_id`, `is_pinned` FROM `z_forum_topics` WHERE `id` = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row || !$row['is_pinned']) return;

    $stmt = $mysqli->prepare("SELECT `id`, `sort_order` FROM `z_forum_topics` WHERE `subcategory_id` = ? AND `is_pinned` = 1 ORDER BY `sort_order` ASC, `id` ASC");
    $stmt->bind_param('i', $row['subcategory_id']);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    ucp_forum_swap_order($rows, $id, $direction, 'z_forum_topics');
}
