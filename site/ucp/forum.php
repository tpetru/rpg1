<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/forum_functions.php';
ucp_require_login();

$categoryIcons = [
    'suggestions' => '💡',
    'complaints'  => '⚠️',
    'bugs'        => '🐛',
    'rules'       => '📜',
];

$categories = ucp_forum_categories();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — Forum</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main>
  <h1>💬 Forum</h1>
  <p style="color:var(--muted)">Suggestions, complaints, bugs and the server's rules.</p>

  <div class="card">
    <?php foreach ($categories as $cat): ?>
    <div class="forum-cat-row">
      <div class="forum-cat-icon"><?= $categoryIcons[$cat['slug']] ?? '💬' ?></div>
      <div class="forum-cat-main">
        <a href="forum_category.php?slug=<?= urlencode($cat['slug']) ?>" class="forum-cat-title"><?= ucp_escape($cat['name']) ?></a>
        <div class="forum-cat-desc"><?= ucp_escape($cat['description']) ?></div>
      </div>
      <div class="forum-cat-stats">
        <strong><?= (int)$cat['subcategory_count'] ?></strong> subforums
      </div>
      <div class="forum-cat-stats">
        <strong><?= (int)$cat['topic_count'] ?></strong> topics
        <br><?= (int)$cat['post_count'] ?> posts
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
