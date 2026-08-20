<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/forum_functions.php';

$slug = trim($_GET['slug'] ?? '');
$category = ucp_forum_category_by_slug($slug);
if (!$category) {
    header('Location: forum.php');
    exit;
}

$canManageStructure = ucp_forum_can_manage_structure();

if ($canManageStructure && ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && isset($_POST['move_subcategory']) && ucp_csrf_verify()) {
    ucp_forum_move_subcategory((int)$_POST['move_subcategory'], $_POST['direction'] === 'up' ? 'up' : 'down');
    header('Location: forum_category.php?slug=' . urlencode($category['slug']));
    exit;
}

$subcategories = ucp_forum_subcategories($category['id']);
foreach ($subcategories as &$sub) {
    $sub['last'] = ucp_forum_last_activity($sub['id']);
}
unset($sub);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — <?= ucp_escape($category['name']) ?></title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/ucp/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <nav class="forum-breadcrumb">
    <a href="forum.php">💬 Forum</a>
    <span class="crumb-sep">›</span>
    <span class="crumb-current"><?= ucp_escape($category['name']) ?></span>
  </nav>
  <h1><?= ucp_escape($category['name']) ?></h1>
  <p style="color:var(--muted)"><?= ucp_escape($category['description']) ?></p>

  <div class="card">
    <?php if (!$subcategories): ?>
      <p style="color:var(--muted);text-align:center;padding:20px 0">No subforums here yet.</p>
    <?php endif; ?>
    <?php foreach ($subcategories as $i => $sub): ?>
    <div class="forum-cat-row">
      <?php if ($canManageStructure): ?>
      <div class="forum-reorder">
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_subcategory" value="<?= (int)$sub['id'] ?>"><input type="hidden" name="direction" value="up"><button type="submit" class="btn-sm" title="Move up" <?= $i === 0 ? 'disabled' : '' ?>>▲</button></form>
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_subcategory" value="<?= (int)$sub['id'] ?>"><input type="hidden" name="direction" value="down"><button type="submit" class="btn-sm" title="Move down" <?= $i === count($subcategories) - 1 ? 'disabled' : '' ?>>▼</button></form>
      </div>
      <?php endif; ?>
      <div class="forum-cat-icon"><?= $sub['require_login'] ? '🔒' : '💬' ?></div>
      <div class="forum-cat-main">
        <a href="forum_subcategory.php?slug=<?= urlencode($sub['slug']) ?>" class="forum-cat-title"><?= ucp_escape($sub['name']) ?></a>
        <div class="forum-cat-desc"><?= ucp_escape($sub['description']) ?></div>
      </div>
      <div class="forum-cat-stats">
        <strong><?= (int)$sub['topic_count'] ?></strong> topics
        <br><?= (int)$sub['post_count'] ?> posts
      </div>
      <?php if ($sub['last']): ?>
      <div class="forum-cat-last">
        <?= ucp_forum_avatar($sub['last']['username'], 34) ?>
        <div>
          <a href="forum_topic.php?id=<?= (int)$sub['last']['id'] ?>"><?= ucp_escape($sub['last']['title']) ?></a>
          by <?= ucp_escape($sub['last']['username']) ?><br>
          <?= ucp_escape(date('d.m.Y H:i', strtotime($sub['last']['last_post_at']))) ?>
        </div>
      </div>
      <?php else: ?>
      <div class="forum-cat-last-empty">No topics yet</div>
      <?php endif; ?>
    </div>
    <?php endforeach; ?>
  </div>
</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

</body>
</html>
