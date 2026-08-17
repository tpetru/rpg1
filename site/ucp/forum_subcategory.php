<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/forum_functions.php';
ucp_require_login();

$slug = trim($_GET['slug'] ?? '');
$subcategory = ucp_forum_subcategory_by_slug($slug);
if (!$subcategory) {
    header('Location: forum.php');
    exit;
}

$topics = ucp_forum_topics($subcategory['id']);
$canModerate = ucp_forum_can_moderate();
$canPost = $canModerate || !$subcategory['admin_only_post'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — <?= ucp_escape($subcategory['name']) ?></title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <p><a href="forum.php">Forum</a> &rsaquo; <a href="forum_category.php?slug=<?= urlencode($subcategory['category_slug']) ?>"><?= ucp_escape($subcategory['category_name']) ?></a></p>
  <h1><?= ucp_escape($subcategory['name']) ?></h1>
  <p style="color:var(--muted)"><?= ucp_escape($subcategory['description']) ?></p>

  <?php if ($canPost): ?>
    <p><a href="forum_new_topic.php?subcategory=<?= urlencode($subcategory['slug']) ?>" class="btn">+ New topic</a></p>
  <?php else: ?>
    <p style="color:var(--muted)">Only administrators can post in this subforum.</p>
  <?php endif; ?>

  <div class="card">
    <?php if (!$topics): ?>
      <p style="color:var(--muted);text-align:center;padding:20px 0">No topics yet — be the first to post.</p>
    <?php endif; ?>
    <?php foreach ($topics as $t): [$statusLabel, $statusTier] = ucp_forum_status_label($t['status']); ?>
    <div class="forum-topic-row">
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

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
