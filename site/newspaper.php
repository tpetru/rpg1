<?php
// Read newspaper images
$newspaperDir = __DIR__ . '/newspaper';
$images = [];
if (is_dir($newspaperDir)) {
    $files = glob($newspaperDir . '/*.png');
    usort($files, function($a, $b) {
        return filemtime($a) <=> filemtime($b);
    });
    foreach ($files as $file) {
        $images[] = [
            'path' => 'newspaper/' . basename($file),
            'name' => basename($file)
        ];
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Newspaper</title>
<link rel="icon" type="image/png" href="ucp/assets/img/favicon.ico">
<style>
  :root {
    --bg: #0b0d10;
    --panel: #12161b;
    --panel-2: #171c22;
    --border: #252b32;
    --text: #f2f2f2;
    --muted: #8e969f;
    --accent: #ff6a00;
    --accent-2: #ff8533;
    --accent-soft: #e8a268;
    --green: #3ecf8e;
    --red: #ff5d5d;
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.6;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }

  .topbar {
    position: relative;
    display: flex; align-items: center; justify-content: space-between;
    flex-wrap: wrap; row-gap: 8px; padding: 14px 24px;
    background: rgba(18, 22, 27, 0.72);
    backdrop-filter: blur(14px) saturate(140%);
    -webkit-backdrop-filter: blur(14px) saturate(140%);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0; z-index: 100; min-height: 64px;
  }
  .topbar::after {
    content: "";
    position: absolute; left: 0; right: 0; bottom: -1px; height: 1px;
    background: linear-gradient(90deg, transparent, rgba(255,106,0,0.6) 20%, rgba(255,133,51,0.4) 50%, rgba(255,106,0,0.6) 80%, transparent);
    opacity: 0.7;
  }
  .topbar .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 1.1rem; letter-spacing: 0.3px; color: #fff; text-decoration: none; transition: color 0.25s ease; }
  .topbar .brand:hover { text-decoration: none; color: var(--accent); }
  .topbar .brand img {
    height: 34px; width: 34px; border-radius: 8px;
    border: 1px solid var(--border);
    transition: border-color 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease;
  }
  .topbar .brand:hover img {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(255,106,0,0.12), 0 4px 14px rgba(255,106,0,0.2);
    transform: rotate(-4deg) scale(1.05);
  }
  .topbar nav { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 20px; }
  .topbar nav a {
    position: relative; display: inline-flex; align-items: center; justify-content: center;
    min-width: 108px; padding: 6px 12px;
    border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 0.92rem; text-decoration: none; text-align: center;
    transition: color 0.25s ease, border-color 0.25s ease, background 0.25s ease;
  }
  .topbar nav a::after {
    content: "";
    position: absolute; left: 50%; bottom: 4px; width: 0; height: 2px;
    border-radius: 2px;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    transition: width 0.28s ease, left 0.28s ease;
  }
  .topbar nav a:hover { color: #fff; text-decoration: none; border-color: var(--accent-soft); background: var(--panel-2); }
  .topbar nav a:hover::after { width: calc(100% - 24px); left: 12px; }
  .nav-dd { position: relative; }
  .nav-dd-toggle { cursor: pointer; }
  .nav-dd-menu {
    display: none;
    position: absolute; top: 100%; left: 50%; transform: translateX(-50%); margin-top: 0;
    background: rgba(23, 28, 34, 0.92);
    backdrop-filter: blur(10px);
    border: 1px solid var(--border); border-radius: 10px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 14px 32px rgba(0,0,0,0.5);
  }
  .topbar .nav-dd-menu a { display: block; position: static; padding: 8px 10px; border: none; border-radius: 7px; font-size: 0.88rem; white-space: nowrap; text-decoration: none; transition: background 0.2s ease, color 0.2s ease; }
  .topbar .nav-dd-menu a::after { display: none; }
  .topbar .nav-dd-menu a:hover { background: rgba(255,106,0,0.1); border: none; color: var(--accent); text-decoration: none; }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }

main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 50px 24px 80px;
  }

  .newspaper-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 40px;
    margin-bottom: 60px;
  }
  @media (max-width: 900px) {
    .newspaper-grid { grid-template-columns: 1fr; gap: 30px; }
  }

  .page-spread {
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 10px 40px rgba(0,0,0,0.4);
    transition: transform 0.2s, box-shadow 0.2s;
    cursor: pointer;
  }
  .page-spread:hover {
    transform: translateY(-4px);
    box-shadow: 0 15px 50px rgba(0,0,0,0.6);
  }

  .page-image {
    width: 100%;
    height: auto;
    display: block;
    background: #000;
  }

  .page-info {
    padding: 18px 20px;
    background: var(--panel-2);
    border-top: 1px solid var(--border);
  }
  .page-info h3 {
    margin: 0 0 6px;
    font-size: 1.1rem;
    color: var(--accent-2);
    word-wrap: break-word;
    overflow-wrap: break-word;
    word-break: break-word;
    max-width: 100%;
    display: block;
    min-height: 1.4rem;
  }
  .page-info p {
    margin: 0;
    font-size: 0.9rem;
    color: var(--muted);
  }

  .modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.95);
    z-index: 1000;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .modal.active {
    display: flex;
  }

  .modal-content {
    position: relative;
    max-width: 90%;
    max-height: 90vh;
    overflow: auto;
  }
  .modal-image {
    width: 100%;
    height: auto;
    display: block;
  }

  .modal-close {
    position: absolute;
    top: 20px;
    right: 20px;
    background: rgba(255,255,255,0.2);
    border: none;
    color: #fff;
    font-size: 2rem;
    cursor: pointer;
    width: 50px;
    height: 50px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }
  .modal-close:hover {
    background: rgba(255,255,255,0.3);
  }

  .modal-nav {
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(255,255,255,0.2);
    border: none;
    color: #fff;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 15px 20px;
    border-radius: 6px;
    transition: background 0.2s;
  }
  .modal-nav:hover {
    background: rgba(255,255,255,0.3);
  }
  .modal-prev { left: 20px; }
  .modal-next { right: 20px; }

  footer { text-align: center; padding: 30px 24px; color: var(--muted); font-size: 0.85rem; border-top: 1px solid var(--border); }
</style>
</head>
<body>

<header class="topbar">
  <a href="index.php" class="brand"><img src="ucp/assets/img/logo.jpg" alt="" class="brand-logo"> Nostalgia: Los Santos | RPG</a>
  <nav>
    <a href="index.php">🏠 Homepage</a>
    <a href="presentation.php">🏙️ Presentation</a>
    <a href="newspaper.php">📰 Newspaper</a>
    <a href="ucp/index.php">🧭 UCP</a>
  </nav>
</header>

<main>
  <div class="newspaper-grid">
    <?php foreach ($images as $index => $image): ?>
    <div class="page-spread" onclick="openModal(<?= $index ?>)">
      <img src="<?= htmlspecialchars($image['path']) ?>" alt="Page" class="page-image">
      <div class="page-info">
        <p>📄 Click to view full page</p>
      </div>
    </div>
    <?php endforeach; ?>
  </div>

  <?php if (empty($images)): ?>
  <div class="page-spread" style="padding: 40px; text-align: center;">
    <p style="color: var(--muted);">No newspaper pages found. Add images to the newspaper/ folder.</p>
  </div>
  <?php endif; ?>
</main>

<div class="modal" id="modal">
  <div class="modal-content">
    <button class="modal-close" onclick="closeModal()">✕</button>
    <button class="modal-nav modal-prev" onclick="prevPage()">❮</button>
    <img src="" alt="Full page" class="modal-image" id="modalImage">
    <button class="modal-nav modal-next" onclick="nextPage()">❯</button>
  </div>
</div>

<footer>Nostalgia: Los Santos | RPG — 2026 Newspaper Archive · <a href="tc.html">Terms &amp; Conditions</a></footer>

<script>
  let currentPage = 0;
  const pages = <?= json_encode(array_map(fn($img) => $img['path'], $images)) ?>;

  function openModal(index) {
    currentPage = index;
    const modal = document.getElementById('modal');
    const img = document.getElementById('modalImage');
    img.src = pages[currentPage];
    modal.classList.add('active');
  }

  function closeModal() {
    document.getElementById('modal').classList.remove('active');
  }

  function nextPage() {
    currentPage = (currentPage + 1) % pages.length;
    document.getElementById('modalImage').src = pages[currentPage];
  }

  function prevPage() {
    currentPage = (currentPage - 1 + pages.length) % pages.length;
    document.getElementById('modalImage').src = pages[currentPage];
  }

  document.addEventListener('keydown', (e) => {
    if (!document.getElementById('modal').classList.contains('active')) return;
    if (e.key === 'ArrowRight') nextPage();
    if (e.key === 'ArrowLeft') prevPage();
    if (e.key === 'Escape') closeModal();
  });
</script>

</body>
</html>
