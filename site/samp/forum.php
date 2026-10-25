<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/forum_functions.php';
require_once __DIR__ . '/includes/lang.php';

$categoryIcons = [
    'suggestions' => '💡',
    'complaints'  => '⚠️',
    'bugs'        => '🐛',
    'rules'       => '📜',
];

$canManageStructure = ucp_forum_can_manage_structure();

if ($canManageStructure && ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && isset($_POST['move_category']) && ucp_csrf_verify()) {
    ucp_forum_move_category((int)$_POST['move_category'], $_POST['direction'] === 'up' ? 'up' : 'down');
    header('Location: forum.php');
    exit;
}

$categories = ucp_forum_categories();
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Forum</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/ucp/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <h1>💬 <?= t('Forum') ?></h1>
  <p style="color:var(--muted)"><?= t("Suggestions, complaints, bugs and the server's rules.") ?></p>

  <div class="card">
    <?php foreach ($categories as $i => $cat): ?>
    <div class="forum-cat-row">
      <?php if ($canManageStructure): ?>
      <div class="forum-reorder">
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_category" value="<?= (int)$cat['id'] ?>"><input type="hidden" name="direction" value="up"><button type="submit" class="btn-sm" title="<?= t('Move up') ?>" <?= $i === 0 ? 'disabled' : '' ?>>▲</button></form>
        <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="move_category" value="<?= (int)$cat['id'] ?>"><input type="hidden" name="direction" value="down"><button type="submit" class="btn-sm" title="<?= t('Move down') ?>" <?= $i === count($categories) - 1 ? 'disabled' : '' ?>>▼</button></form>
      </div>
      <?php endif; ?>
      <div class="forum-cat-icon"><?= $categoryIcons[$cat['slug']] ?? '💬' ?></div>
      <div class="forum-cat-main">
        <a href="forum_category.php?slug=<?= urlencode($cat['slug']) ?>" class="forum-cat-title"><?= ucp_escape($cat['name']) ?></a>
        <div class="forum-cat-desc"><?= ucp_escape($cat['description']) ?></div>
      </div>
      <div class="forum-cat-stats">
        <strong><?= (int)$cat['subcategory_count'] ?></strong> <?= t('subforums') ?>
      </div>
      <div class="forum-cat-stats">
        <strong><?= (int)$cat['topic_count'] ?></strong> <?= t('topics') ?>
        <br><?= (int)$cat['post_count'] ?> <?= t('posts') ?>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

</body>
</html>
