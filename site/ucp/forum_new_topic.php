<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/forum_functions.php';
ucp_require_login();

$slug = trim($_GET['subcategory'] ?? $_POST['subcategory'] ?? '');
$subcategory = ucp_forum_subcategory_by_slug($slug);
if (!$subcategory) {
    header('Location: forum.php');
    exit;
}
if ($subcategory['admin_only_post'] && !ucp_forum_can_moderate()) {
    header('Location: forum_subcategory.php?slug=' . urlencode($subcategory['slug']));
    exit;
}

$error = '';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    if (!ucp_csrf_verify()) {
        $error = 'Security check failed (invalid or expired form). Please try again.';
    } else {
        $title = trim($_POST['title'] ?? '');
        $body = trim($_POST['body'] ?? '');

        if (mb_strlen($title) < 5 || mb_strlen($title) > 150) {
            $error = 'The title must be between 5 and 150 characters.';
        } elseif (mb_strlen($body) < 10) {
            $error = 'The message must be at least 10 characters.';
        } else {
            $topicId = ucp_forum_create_topic($subcategory['id'], ucp_current_player_id(), $title, $body);
            if ($topicId) {
                header('Location: forum_topic.php?id=' . $topicId);
                exit;
            }
            $error = 'Something went wrong, please try again.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — New Topic</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  .apply-form label { display: block; font-size: 0.85rem; color: var(--muted); margin: 14px 0 4px; }
  .apply-form input, .apply-form textarea {
    width: 100%; padding: 9px 12px; box-sizing: border-box;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 0.95rem; font-family: inherit;
  }
  .apply-form textarea { resize: vertical; min-height: 140px; }
  .apply-form button {
    margin-top: 18px; padding: 10px 20px;
    background: var(--accent); border: none; border-radius: 8px;
    color: #0f1115; font-weight: 700; font-size: 0.95rem; cursor: pointer;
  }
  .apply-form button:hover { opacity: 0.9; }
</style>
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<main style="max-width:600px">
  <p><a href="forum_subcategory.php?slug=<?= urlencode($subcategory['slug']) ?>">&larr; <?= ucp_escape($subcategory['name']) ?></a></p>
  <h1>New topic in <?= ucp_escape($subcategory['name']) ?></h1>

  <div class="card">
    <?php if ($error): ?>
      <div class="error-box"><?= ucp_escape($error) ?></div>
    <?php endif; ?>

    <form method="post" class="apply-form">
      <?= ucp_csrf_field() ?>
      <input type="hidden" name="subcategory" value="<?= ucp_escape($subcategory['slug']) ?>">

      <label for="title">Title</label>
      <input type="text" id="title" name="title" required minlength="5" maxlength="150" value="<?= ucp_escape($_POST['title'] ?? '') ?>">

      <label for="body">Message</label>
      <textarea id="body" name="body" required minlength="10"><?= ucp_escape($_POST['body'] ?? '') ?></textarea>

      <button type="submit">Post</button>
    </form>
  </div>
</main>

<footer>Nostalgia: Los Santos UCP</footer>

</body>
</html>
