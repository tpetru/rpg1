<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Space Invaders</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .inv-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .inv-stats span span { color: var(--accent); }
  #invCanvas { background: linear-gradient(180deg, #05070a 0%, #0b0d10 85%); border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; cursor: pointer; }
  .inv-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .inv-controls { margin-top: 16px; display: none; justify-content: center; gap: 10px; }
  .inv-controls button { width: 70px; height: 44px; background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1.1rem; cursor: pointer; }
  .inv-controls button:active { background: var(--accent); color: #0f1115; }
  @media (max-width: 480px) { .inv-controls { display: flex; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>

<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>👾 Space Invaders</h1>

  <div class="card" style="text-align: center">
    <div class="inv-stats">
      <span>Score: <span id="invScore">0</span></span>
      <span>Lives: <span id="invLives">3</span></span>
      <span>Best: <span id="invBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="invCanvas" width="320" height="420"></canvas></div>
    <p class="inv-msg" id="invMsg">← → or A/D to move, Space (or Fire) to shoot. Clear the wave before it reaches you.</p>
    <button id="invRestart" class="btn" style="display:none">Play again</button>
    <div class="inv-controls" aria-hidden="true">
      <button type="button" id="invLeftBtn">◀</button>
      <button type="button" id="invFireBtn">🔥</button>
      <button type="button" id="invRightBtn">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('invCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('invScore');
  var livesEl = document.getElementById('invLives');
  var bestEl = document.getElementById('invBest');
  var msgEl = document.getElementById('invMsg');
  var restartBtn = document.getElementById('invRestart');

  var best = parseInt(localStorage.getItem('invadersBest') || '0', 10);
  bestEl.textContent = best;

  var PLAYER_SPEED = 4;
  var ROW_COLORS = ['#ff5d5d', '#ff8533', '#ffcf4d', '#3ecf8e', '#4d8cff'];

  var player, playerBullet, enemyBullets, enemies, enemyDir, enemySpeed, wave;
  var score, lives, over, started, keys, frame, rafId;

  function buildEnemies(speedMul) {
    enemies = [];
    var cols = 8, rows = 5, ew = 24, eh = 14, gapX = 10, gapY = 14;
    var totalW = cols * ew + (cols - 1) * gapX;
    var startX = (W - totalW) / 2;
    var startY = 34;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        enemies.push({ x: startX + c * (ew + gapX), y: startY + r * (eh + gapY), w: ew, h: eh, alive: true, row: r });
      }
    }
    enemyDir = 1;
    enemySpeed = 0.6 * speedMul;
  }

  function reset() {
    player = { x: W / 2 - 14, y: H - 26, w: 28, h: 12 };
    playerBullet = null;
    enemyBullets = [];
    wave = 1;
    buildEnemies(1);
    score = 0; lives = 3; over = false; started = false; frame = 0;
    keys = {};
    scoreEl.textContent = 0;
    livesEl.textContent = 3;
    msgEl.textContent = '← → or A/D to move, Space (or Fire) to shoot. Clear the wave before it reaches you.';
    restartBtn.style.display = 'none';
    cancelAnimationFrame(rafId);
    draw();
  }

  function start() {
    if (started || over) return;
    started = true;
    msgEl.textContent = '';
    rafId = requestAnimationFrame(loop);
  }

  function shoot() {
    if (over) return;
    if (!started) { start(); return; }
    if (playerBullet) return;
    playerBullet = { x: player.x + player.w / 2 - 2, y: player.y - 8, w: 4, h: 10 };
  }

  function rectsOverlap(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
  }

  function update() {
    frame++;
    if (keys.left) player.x = Math.max(0, player.x - PLAYER_SPEED);
    if (keys.right) player.x = Math.min(W - player.w, player.x + PLAYER_SPEED);

    var alive = enemies.filter(function(e) { return e.alive; });
    var hitEdge = false;
    alive.forEach(function(e) {
      e.x += enemySpeed * enemyDir;
      if (e.x <= 4 || e.x + e.w >= W - 4) hitEdge = true;
    });
    if (hitEdge) {
      enemyDir *= -1;
      alive.forEach(function(e) { e.y += 16; });
      enemySpeed = Math.min(3.4, enemySpeed * 1.04);
    }

    if (alive.some(function(e) { return e.y + e.h >= player.y; })) { gameOver('The invasion reached you!'); return; }

    if (playerBullet) {
      playerBullet.y -= 6;
      if (playerBullet.y < -10) {
        playerBullet = null;
      } else {
        for (var i = 0; i < enemies.length; i++) {
          var e = enemies[i];
          if (e.alive && rectsOverlap(playerBullet, e)) {
            e.alive = false;
            playerBullet = null;
            score += 10;
            scoreEl.textContent = score;
            if (score > best) { best = score; localStorage.setItem('invadersBest', best); bestEl.textContent = best; }
            break;
          }
        }
      }
    }

    if (frame % 40 === 0 && alive.length && Math.random() < 0.6) {
      var s = alive[Math.floor(Math.random() * alive.length)];
      enemyBullets.push({ x: s.x + s.w / 2 - 2, y: s.y + s.h, w: 4, h: 10 });
    }
    for (var j = enemyBullets.length - 1; j >= 0; j--) {
      var b = enemyBullets[j];
      b.y += 3;
      if (b.y > H) { enemyBullets.splice(j, 1); continue; }
      if (rectsOverlap(b, player)) {
        enemyBullets.splice(j, 1);
        lives--;
        livesEl.textContent = lives;
        if (lives <= 0) { gameOver('Ship destroyed!'); return; }
      }
    }

    if (enemies.every(function(e) { return !e.alive; })) {
      wave++;
      buildEnemies(1 + (wave - 1) * 0.18);
      msgEl.textContent = 'Wave ' + wave + ' incoming!';
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#05070a');
    grad.addColorStop(0.85, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    enemies.forEach(function(e) {
      if (!e.alive) return;
      ctx.fillStyle = ROW_COLORS[e.row % ROW_COLORS.length];
      ctx.fillRect(e.x, e.y, e.w, e.h);
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.fillRect(e.x + 3, e.y + e.h - 4, e.w - 6, 3);
    });

    ctx.fillStyle = '#ffd633';
    enemyBullets.forEach(function(b) { ctx.fillRect(b.x, b.y, b.w, b.h); });

    if (playerBullet) {
      ctx.fillStyle = '#4dd9ff';
      ctx.fillRect(playerBullet.x, playerBullet.y, playerBullet.w, playerBullet.h);
    }

    ctx.fillStyle = '#3ecf8e';
    ctx.fillRect(player.x, player.y + 5, player.w, player.h - 5);
    ctx.fillRect(player.x + player.w / 2 - 3, player.y, 6, 7);
  }

  function loop() {
    if (over) return;
    update();
    if (!over) {
      draw();
      rafId = requestAnimationFrame(loop);
    }
  }

  function gameOver(reason) {
    over = true;
    started = false;
    cancelAnimationFrame(rafId);
    if (score > best) { best = score; localStorage.setItem('invadersBest', best); bestEl.textContent = best; }
    msgEl.textContent = (reason || 'Game over') + ' Score: ' + score;
    restartBtn.style.display = 'inline-block';
    draw();
  }

  var moveKeyMap = {
    ArrowLeft: 'left', a: 'left', A: 'left',
    ArrowRight: 'right', d: 'right', D: 'right'
  };
  document.addEventListener('keydown', function(e) {
    if (moveKeyMap[e.key]) { e.preventDefault(); keys[moveKeyMap[e.key]] = true; if (!started) start(); }
    else if (e.key === ' ') { e.preventDefault(); if (over) { reset(); } else { shoot(); } }
  });
  document.addEventListener('keyup', function(e) {
    if (moveKeyMap[e.key]) keys[moveKeyMap[e.key]] = false;
  });

  function bindHold(btn, key) {
    btn.addEventListener('mousedown', function() { keys[key] = true; if (!started) start(); });
    btn.addEventListener('mouseup', function() { keys[key] = false; });
    btn.addEventListener('mouseleave', function() { keys[key] = false; });
    btn.addEventListener('touchstart', function(e) { e.preventDefault(); keys[key] = true; if (!started) start(); });
    btn.addEventListener('touchend', function(e) { e.preventDefault(); keys[key] = false; });
  }
  bindHold(document.getElementById('invLeftBtn'), 'left');
  bindHold(document.getElementById('invRightBtn'), 'right');
  var fireBtn = document.getElementById('invFireBtn');
  fireBtn.addEventListener('click', function() { if (over) reset(); else shoot(); });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
