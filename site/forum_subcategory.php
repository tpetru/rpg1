<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/forum_functions.php';

$slug = trim($_GET['slug'] ?? '');
$subcategory = ucp_forum_subcategory_by_slug($slug);
if (!$subcategory) {
    header('Location: forum.php');
    exit;
}
if ($subcategory['require_login']) {
    ucp_require_login();
}

$canModerate = ucp_forum_can_moderate();               // admin_forum 2+: move pinned topics
$canManageStructure = ucp_forum_can_manage_structure(); // admin_forum 1+: post in admin-only subforums

if ($canModerate && ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && isset($_POST['move_topic']) && ucp_csrf_verify()) {
    ucp_forum_move_topic((int)$_POST['move_topic'], $_POST['direction'] === 'up' ? 'up' : 'down');
    header('Location: forum_subcategory.php?slug=' . urlencode($subcategory['slug']));
    exit;
}

$topics = ucp_forum_topics($subcategory['id']);
$pinnedIds = array_values(array_map(fn($t) => (int)$t['id'], array_filter($topics, fn($t) => $t['is_pinned'])));
$isLoggedIn = ucp_current_player_id() > 0;
$canPost = $isLoggedIn && ($canManageStructure || !$subcategory['admin_only_post']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — <?= ucp_escape($subcategory['name']) ?></title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/ucp/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <nav class="forum-breadcrumb">
    <a href="forum.php">💬 Forum</a>
    <span class="crumb-sep">›</span>
    <a href="forum_category.php?slug=<?= urlencode($subcategory['category_slug']) ?>"><?= ucp_escape($subcategory['category_name']) ?></a>
    <span class="crumb-sep">›</span>
    <span class="crumb-current"><?= ucp_escape($subcategory['name']) ?></span>
  </nav>
  <h1><?= ucp_escape($subcategory['name']) ?></h1>
  <p style="color:var(--muted)"><?= ucp_escape($subcategory['description']) ?></p>

  <?php if ($canPost): ?>
    <p><a href="forum_new_topic.php?subcategory=<?= urlencode($subcategory['slug']) ?>" class="btn">+ New topic</a></p>
  <?php elseif (!$isLoggedIn): ?>
    <p style="color:var(--muted)"><a href="ucp/index.php">Log in</a> to post a new topic.</p>
  <?php else: ?>
    <p style="color:var(--muted)">Only administrators can post in this subforum.</p>
  <?php endif; ?>

  <div class="card">
    <?php if (!$topics): ?>
      <p style="color:var(--muted);text-align:center;padding:20px 0">No topics yet — be the first to post.</p>
    <?php endif; ?>
    <?php foreach ($topics as $t): [$statusLabel, $statusTier] = ucp_forum_status_label($t['status']); ?>
    <div class="forum-topic-row">
      <?php if ($canModerate && $t['is_pinned']):
        $pinIdx = array_search((int)$t['id'], $pinnedIds, true);
      ?>
      <div class="forum-reorder">
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_topic" value="<?= (int)$t['id'] ?>"><input type="hidden" name="direction" value="up"><button type="submit" class="btn-sm" title="Move up" <?= $pinIdx === 0 ? 'disabled' : '' ?>>▲</button></form>
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_topic" value="<?= (int)$t['id'] ?>"><input type="hidden" name="direction" value="down"><button type="submit" class="btn-sm" title="Move down" <?= $pinIdx === count($pinnedIds) - 1 ? 'disabled' : '' ?>>▼</button></form>
      </div>
      <?php endif; ?>
      <div class="forum-topic-icon">
        <?php if ($t['is_pinned']): ?>📌<?php elseif ($t['is_locked']): ?>🔒<?php else: ?>💬<?php endif; ?>
      </div>
      <div class="forum-topic-main">
        <a href="forum_topic.php?id=<?= (int)$t['id'] ?>" class="forum-topic-title"><?= ucp_escape($t['title']) ?></a>
        <div class="forum-topic-meta">by <?= ucp_escape($t['username']) ?> &middot; <?= ucp_escape(date('d.m.Y H:i', strtotime($t['created_at']))) ?></div>
      </div>
      <div class="forum-topic-status"><span class="pill pill-<?= $statusTier ?>"><?= $statusLabel ?></span></div>
      <div class="forum-topic-replies"><?= max(0, (int)$t['post_count'] - 1) ?> replies</div>
      <div class="forum-topic-last">
        <strong><?= ucp_escape($t['last_username']) ?></strong>
        <?= ucp_escape(date('d.m.Y H:i', strtotime($t['last_post_at']))) ?>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

</body>
</html>
