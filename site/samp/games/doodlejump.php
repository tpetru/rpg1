<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — CJ Jump</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .jump-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .jump-stats span span { color: var(--accent); }
  #jumpCanvas { background: linear-gradient(180deg, #1a2230 0%, #0b0d10 85%); border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; }
  .jump-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>⬆️ CJ Jump</h1>

  <div class="card" style="text-align: center">
    <div class="jump-stats">
      <span>Height: <span id="jumpScore">0</span></span>
      <span>Best: <span id="jumpBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="jumpCanvas" width="320" height="480"></canvas></div>
    <p class="jump-msg" id="jumpMsg">← → or A/D to move (or hold left/right half of the screen). CJ bounces automatically - don't fall off the bottom.</p>
    <button id="jumpRestart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('jumpCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('jumpScore');
  var bestEl = document.getElementById('jumpBest');
  var msgEl = document.getElementById('jumpMsg');
  var restartBtn = document.getElementById('jumpRestart');

  var best = parseInt(localStorage.getItem('doodleBest') || '0', 10);
  bestEl.textContent = best;

  var GRAVITY = 0.35, JUMP_V = -9.6, MOVE_SPEED = 3.8;
  var PLAT_W = 52, PLAT_H = 12;

  var cj, platforms, score, over, started, keys, frame, rafId;

  function reset() {
    cj = { x: W / 2, y: H - 60, vy: JUMP_V, vx: 0 };
    platforms = [{ x: W / 2 - PLAT_W / 2, y: H - 30, w: PLAT_W }];
    var y = H - 100;
    while (y > 0) {
      platforms.push({ x: Math.random() * (W - PLAT_W), y: y, w: PLAT_W });
      y -= 62 + Math.random() * 34;
    }
    score = 0; over = false; started = true; frame = 0;
    keys = { left: false, right: false };
    scoreEl.textContent = 0;
    msgEl.textContent = '';
    restartBtn.style.display = 'none';
    cancelAnimationFrame(rafId);
    draw();
    rafId = requestAnimationFrame(loop);
  }

  var PLAT_COLORS = ['#ff6a00', '#3ecf8e', '#4d8cff'];

  function spawnAbove() {
    var topY = H;
    for (var i = 0; i < platforms.length; i++) if (platforms[i].y < topY) topY = platforms[i].y;
    platforms.push({ x: Math.random() * (W - PLAT_W), y: topY - (62 + Math.random() * 34), w: PLAT_W });
  }

  function update() {
    frame++;
    cj.vx = keys.left ? -MOVE_SPEED : (keys.right ? MOVE_SPEED : cj.vx * 0.85);
    cj.x += cj.vx;
    if (cj.x < -18) cj.x = W + 18;
    if (cj.x > W + 18) cj.x = -18;

    var prevY = cj.y;
    cj.vy += GRAVITY;
    cj.y += cj.vy;

    if (cj.vy > 0) {
      var feetPrev = prevY + 18, feetNow = cj.y + 18;
      for (var i = 0; i < platforms.length; i++) {
        var p = platforms[i];
        if (cj.x + 10 > p.x && cj.x - 10 < p.x + p.w && feetPrev <= p.y && feetNow >= p.y) {
          cj.vy = JUMP_V;
          cj.y = p.y - 18;
          break;
        }
      }
    }

    if (cj.y < H * 0.45) {
      var dy = H * 0.45 - cj.y;
      cj.y += dy;
      platforms.forEach(function(p) { p.y += dy; });
      score += dy;
      var shown = Math.floor(score / 8);
      scoreEl.textContent = shown;
    }

    platforms = platforms.filter(function(p) { return p.y < H + 20; });
    var minY = H;
    platforms.forEach(function(p) { if (p.y < minY) minY = p.y; });
    if (minY > -20) spawnAbove();

    if (cj.y > H + 30) { gameOver(); }
  }

  function drawLimb(px, py, w, h, angle) {
    ctx.save();
    ctx.translate(px, py);
    ctx.rotate(angle);
    ctx.fillRect(-w / 2, 0, w, h);
    ctx.restore();
  }

  function drawCJ() {
    var wobble = Math.sin(frame * 0.15) * 0.25;
    ctx.save();
    ctx.translate(cj.x, cj.y);
    ctx.fillStyle = '#3a5a96';
    drawLimb(-3, -14, 5, 14, wobble);
    drawLimb(3, -14, 5, 14, -wobble);
    ctx.fillStyle = '#f0f0ec';
    ctx.fillRect(-7, -30, 14, 18);
    ctx.fillStyle = '#a5673f';
    drawLimb(-8, -28, 4, 12, -wobble * 1.4);
    drawLimb(8, -28, 4, 12, wobble * 1.4);
    ctx.beginPath(); ctx.arc(0, -36, 7, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#191512';
    ctx.beginPath(); ctx.ellipse(0, -40, 8, 4, 0, Math.PI, Math.PI * 2); ctx.fill();
    ctx.restore();
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a2230');
    grad.addColorStop(0.85, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    platforms.forEach(function(p, i) {
      ctx.fillStyle = PLAT_COLORS[i % PLAT_COLORS.length];
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(p.x, p.y, p.w, PLAT_H, 5); else ctx.rect(p.x, p.y, p.w, PLAT_H);
      ctx.fill();
    });

    drawCJ();
  }

  function loop() {
    if (over) return;
    update();
    if (!over) {
      draw();
      rafId = requestAnimationFrame(loop);
    }
  }

  function gameOver() {
    over = true;
    cancelAnimationFrame(rafId);
    var finalScore = Math.floor(score / 8);
    if (finalScore > best) {
      best = finalScore;
      localStorage.setItem('doodleBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best height: ' + finalScore + '! 🎉';
    } else {
      msgEl.textContent = 'CJ fell - height: ' + finalScore;
    }
    restartBtn.style.display = 'inline-block';
    draw();
  }

  var keyMap = {
    ArrowLeft: 'left', a: 'left', A: 'left',
    ArrowRight: 'right', d: 'right', D: 'right'
  };
  document.addEventListener('keydown', function(e) {
    if (keyMap[e.key]) { e.preventDefault(); keys[keyMap[e.key]] = true; }
  });
  document.addEventListener('keyup', function(e) {
    if (keyMap[e.key]) keys[keyMap[e.key]] = false;
  });

  function setTouch(e, val) {
    e.preventDefault();
    var rect = canvas.getBoundingClientRect();
    var x = (e.touches[0].clientX - rect.left) * (W / rect.width);
    keys.left = val && x < W / 2;
    keys.right = val && x >= W / 2;
  }
  canvas.addEventListener('touchstart', function(e) { setTouch(e, true); });
  canvas.addEventListener('touchmove', function(e) { setTouch(e, true); });
  canvas.addEventListener('touchend', function() { keys.left = false; keys.right = false; });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
