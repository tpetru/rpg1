<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
require_once __DIR__ . '/includes/forum_functions.php';

$topicId = (int)($_GET['id'] ?? 0);
$topic = ucp_forum_topic($topicId);
if (!$topic) {
    header('Location: forum.php');
    exit;
}
if ($topic['require_login']) {
    ucp_require_login();
}

$canModerate = ucp_forum_can_moderate(); // admin_forum 2+: pin/lock/status
$canDelete = ucp_forum_can_delete();     // admin_forum 3+: delete topics/posts
$isLoggedIn = ucp_current_player_id() > 0;
$error = '';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    if (!ucp_csrf_verify()) {
        $error = 'Security check failed (invalid or expired form). Please try again.';
    } elseif (isset($_POST['reply'])) {
        if (!$isLoggedIn) {
            header('Location: ucp/index.php');
            exit;
        }
        $body = trim($_POST['body'] ?? '');
        if ($topic['is_locked'] && !$canModerate) {
            $error = 'This topic is locked.';
        } elseif (mb_strlen($body) < 2) {
            $error = 'Your message is too short.';
        } else {
            ucp_forum_create_post($topicId, ucp_current_player_id(), $body);
            header('Location: forum_topic.php?id=' . $topicId . '#bottom');
            exit;
        }
    } elseif (isset($_POST['mod_action'])) {
        $action = $_POST['mod_action'];
        $allowed = in_array($action, ['pin', 'lock', 'status'], true) ? $canModerate
                 : (in_array($action, ['delete_topic', 'delete_post'], true) ? $canDelete : false);
        if ($allowed) {
            switch ($action) {
                case 'pin':    ucp_forum_toggle_pin($topicId); break;
                case 'lock':   ucp_forum_toggle_lock($topicId); break;
                case 'status': ucp_forum_set_status($topicId, $_POST['status'] ?? ''); break;
                case 'delete_topic':
                    ucp_forum_delete_topic($topicId);
                    header('Location: forum_subcategory.php?slug=' . urlencode($topic['subcategory_slug']));
                    exit;
                case 'delete_post':
                    ucp_forum_delete_post((int)($_POST['post_id'] ?? 0));
                    break;
            }
            header('Location: forum_topic.php?id=' . $topicId);
            exit;
        }
    }
    $topic = ucp_forum_topic($topicId);
}

$posts = ucp_forum_posts($topicId);
[$statusLabel, $statusTier] = ucp_forum_status_label($topic['status']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — <?= ucp_escape($topic['title']) ?></title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/ucp/assets/css/style.css') ?>">
<style>
  .forum-mod-bar { display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0; }
  .forum-mod-bar form { display: inline; }
  .btn-sm { display: inline-block; background: var(--panel-2); border: 1px solid var(--border); border-radius: 6px; color: var(--text); font-size: 0.8rem; padding: 5px 10px; cursor: pointer; }
  .btn-sm:hover { opacity: 0.85; }
  .apply-form textarea {
    width: 100%; box-sizing: border-box; padding: 9px 12px; min-height: 100px; resize: vertical;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 0.95rem; font-family: inherit;
  }
  .apply-form button {
    margin-top: 10px; padding: 9px 18px;
    background: var(--accent); border: none; border-radius: 8px;
    color: #0f1115; font-weight: 700; font-size: 0.9rem; cursor: pointer;
  }
</style>
</head>
<body>

<?php include __DIR__ . '/includes/header.php'; ?>

<main>
  <nav class="forum-breadcrumb">
    <a href="forum.php">💬 Forum</a>
    <span class="crumb-sep">›</span>
    <a href="forum_category.php?slug=<?= urlencode($topic['category_slug']) ?>"><?= ucp_escape($topic['category_name']) ?></a>
    <span class="crumb-sep">›</span>
    <a href="forum_subcategory.php?slug=<?= urlencode($topic['subcategory_slug']) ?>"><?= ucp_escape($topic['subcategory_name']) ?></a>
    <span class="crumb-sep">›</span>
    <span class="crumb-current"><?= ucp_escape($topic['title']) ?></span>
  </nav>
  <h1>
    <?php if ($topic['is_pinned']): ?>📌<?php endif; ?>
    <?php if ($topic['is_locked']): ?>🔒<?php endif; ?>
    <?= ucp_escape($topic['title']) ?>
  </h1>
  <p><span class="pill pill-<?= $statusTier ?>"><?= $statusLabel ?></span> <span style="color:var(--muted)">started by <?= ucp_escape($topic['username']) ?>, <?= ucp_escape(date('d.m.Y H:i', strtotime($topic['created_at']))) ?></span></p>

  <?php if ($canModerate || $canDelete): ?>
  <div class="forum-mod-bar">
    <?php if ($canModerate): ?>
    <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="mod_action" value="pin"><button class="btn-sm" type="submit"><?= $topic['is_pinned'] ? 'Unpin' : 'Pin' ?></button></form>
    <form method="post"><?= ucp_csrf_field() ?><input type="hidden" name="mod_action" value="lock"><button class="btn-sm" type="submit"><?= $topic['is_locked'] ? 'Unlock' : 'Lock' ?></button></form>
    <form method="post">
      <?= ucp_csrf_field() ?>
      <input type="hidden" name="mod_action" value="status">
      <select name="status" onchange="this.form.submit()" class="btn-sm">
        <?php foreach ($GLOBALS['forumStatusLabels'] as $key => [$label, $tier]): ?>
          <option value="<?= $key ?>" <?= $topic['status'] === $key ? 'selected' : '' ?>><?= $label ?></option>
        <?php endforeach; ?>
      </select>
    </form>
    <?php endif; ?>
    <?php if ($canDelete): ?>
    <form method="post" onsubmit="return confirm('Delete this entire topic?');"><?= ucp_csrf_field() ?><input type="hidden" name="mod_action" value="delete_topic"><button class="btn-sm" type="submit" style="color:var(--red)">Delete topic</button></form>
    <?php endif; ?>
  </div>
  <?php endif; ?>

  <?php if ($error): ?>
    <div class="error-box"><?= ucp_escape($error) ?></div>
  <?php endif; ?>

  <div class="card" style="padding:0">
    <?php foreach ($posts as $i => $p): ?>
    <div class="forum-post">
      <div class="forum-post-user">
        <?= ucp_forum_avatar($p['username'], 52) ?>
        <div class="forum-post-username"><?= ucp_escape($p['username']) ?></div>
        <?php if ($p['admin_level'] > 0): ?><span class="pill pill-lvl">admin samp</span><?php endif; ?>
        <?php if ($p['admin_forum'] > 0): ?><span class="pill pill-lvl">admin forum</span><?php endif; ?>
        <?php if ($p['vip'] > 0): ?><span class="pill pill-vip">VIP</span><?php endif; ?>
      </div>
      <div class="forum-post-content">
        <div class="forum-post-meta">
          <span>#<?= $i + 1 ?></span>
          <span>&middot;</span>
          <span><?= ucp_escape(date('d.m.Y H:i', strtotime($p['created_at']))) ?></span>
          <?php if ($p['edited_at']): ?><span>&middot; edited</span><?php endif; ?>
          <?php if ($canDelete): ?>
            <form method="post" style="display:inline" onsubmit="return confirm('Delete this post?');">
              <?= ucp_csrf_field() ?>
              <input type="hidden" name="mod_action" value="delete_post">
              <input type="hidden" name="post_id" value="<?= (int)$p['id'] ?>">
              <button type="submit" class="btn-sm" style="padding:2px 8px;color:var(--red)">Delete</button>
            </form>
          <?php endif; ?>
        </div>
        <div class="forum-post-body"><?= nl2br(ucp_escape($p['body'])) ?></div>
      </div>
    </div>
    <?php endforeach; ?>
  </div>

  <a id="bottom"></a>
  <?php if (!$isLoggedIn): ?>
    <p style="color:var(--muted)"><a href="ucp/index.php">Log in</a> to reply to this topic.</p>
  <?php elseif (!$topic['is_locked'] || $canModerate): ?>
  <div class="card apply-form">
    <form method="post">
      <?= ucp_csrf_field() ?>
      <input type="hidden" name="reply" value="1">
      <textarea name="body" required minlength="2" placeholder="Write a reply..."></textarea>
      <button type="submit">Post reply</button>
    </form>
  </div>
  <?php else: ?>
    <p style="color:var(--muted)">This topic is locked, no new replies can be added.</p>
  <?php endif; ?>
</main>

<?php include __DIR__ . '/includes/footer.php'; ?>

</body>
</html>
