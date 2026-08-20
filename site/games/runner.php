<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — CJ Runner</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .runner-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 14px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .runner-stats span span { color: var(--accent); }
  #runnerCanvas {
    background: linear-gradient(180deg, #1a1410 0%, #0b0d10 75%);
    border: 1px solid var(--border); border-radius: 10px;
    max-width: 100%; display: block; margin: 0 auto;
    touch-action: none; cursor: pointer;
  }
  .runner-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🏃 CJ Runner</h1>

  <div class="card" style="text-align: center">
    <div class="runner-stats">
      <span>Score: <span id="runnerScore">0</span></span>
      <span>Best: <span id="runnerBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="runnerCanvas" width="520" height="220"></canvas></div>
    <p class="runner-msg" id="runnerMsg">Tap, click, or press Space / ↑ to jump.</p>
    <button id="runnerRestart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('runnerCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;
  var groundY = H - 28;

  var scoreEl = document.getElementById('runnerScore');
  var bestEl = document.getElementById('runnerBest');
  var msgEl = document.getElementById('runnerMsg');
  var restartBtn = document.getElementById('runnerRestart');

  var best = parseInt(localStorage.getItem('runnerBest') || '0', 10);
  bestEl.textContent = best;

  var GRAVITY = 0.62;
  var JUMP_V = -11.8;
  var BASE_SPEED = 3.1;

  var cj, obstacles, buildings, distance, score, speed, running, over, started, frame, nextGap, rafId;

  function makeBuildings() {
    var arr = [];
    var x = 0;
    while (x < W + 60) {
      var w = 30 + Math.random() * 40;
      var h = 30 + Math.random() * 70;
      arr.push({ x: x, w: w, h: h });
      x += w + 14;
    }
    return arr;
  }

  function reset() {
    cj = { x: 64, y: groundY, vy: 0, jumping: false, legPhase: 0 };
    obstacles = [];
    buildings = makeBuildings();
    distance = 0;
    score = 0;
    speed = BASE_SPEED;
    frame = 0;
    nextGap = 220;
    running = false;
    over = false;
    started = false;
    scoreEl.textContent = 0;
    msgEl.textContent = 'Tap, click, or press Space / ↑ to jump.';
    restartBtn.style.display = 'none';
    draw();
  }

  function spawnObstacle() {
    var tall = Math.random() < 0.5;
    var w = tall ? 14 : 20;
    var h = tall ? 34 : 24;
    obstacles.push({ x: W + 10, w: w, h: h, tall: tall });
  }

  function jump() {
    if (over) return;
    if (!started) {
      started = true;
      running = true;
      msgEl.textContent = '';
      loop();
    }
    if (!cj.jumping) {
      cj.vy = JUMP_V;
      cj.jumping = true;
    }
  }

  function update() {
    frame++;
    distance += speed;
    speed = Math.min(7.5, BASE_SPEED + distance * 0.001);

    var newScore = Math.floor(distance / 6);
    if (newScore !== score) {
      score = newScore;
      scoreEl.textContent = score;
    }

    cj.vy += GRAVITY;
    cj.y += cj.vy;
    if (cj.y >= groundY) {
      cj.y = groundY;
      cj.vy = 0;
      cj.jumping = false;
    }
    if (!cj.jumping) cj.legPhase += 0.32 + speed * 0.02;

    for (var b = 0; b < buildings.length; b++) buildings[b].x -= speed * 0.3;
    while (buildings.length && buildings[0].x + buildings[0].w < 0) buildings.shift();
    var lastB = buildings[buildings.length - 1];
    if (!lastB || lastB.x + lastB.w < W) {
      var w = 30 + Math.random() * 40, h = 30 + Math.random() * 70;
      buildings.push({ x: (lastB ? lastB.x + lastB.w : 0) + 14, w: w, h: h });
    }

    if (frame === 1 || obstacles.length === 0 || obstacles[obstacles.length - 1].x < W - nextGap) {
      spawnObstacle();
      nextGap = Math.max(130, 260 - speed * 12 + Math.random() * 80);
    }

    var cjBox = { left: cj.x - 9, right: cj.x + 9, top: cj.y - 34, bottom: cj.y };
    for (var i = obstacles.length - 1; i >= 0; i--) {
      var o = obstacles[i];
      o.x -= speed;
      if (o.x + o.w < 0) { obstacles.splice(i, 1); continue; }
      var oBox = { left: o.x, right: o.x + o.w, top: groundY - o.h, bottom: groundY };
      var overlap = cjBox.right > oBox.left && cjBox.left < oBox.right && cjBox.bottom > oBox.top;
      if (overlap) { gameOver(); return; }
    }
  }

  function drawLimb(px, py, w, h, angle) {
    ctx.save();
    ctx.translate(px, py);
    ctx.rotate(angle);
    ctx.fillRect(-w / 2, 0, w, h);
    ctx.restore();
  }

  function drawCJ() {
    var swing = cj.jumping ? 0.5 : Math.sin(cj.legPhase) * 0.6;
    ctx.save();
    ctx.translate(cj.x, cj.y);
    ctx.fillStyle = '#3a5a96';
    drawLimb(-3, -14, 5, 14, swing);
    drawLimb(3, -14, 5, 14, -swing);
    ctx.fillStyle = '#f0f0ec';
    ctx.fillRect(-7, -30, 14, 18);
    ctx.fillStyle = '#a5673f';
    drawLimb(-8, -28, 4, 12, -swing * 0.8);
    drawLimb(8, -28, 4, 12, swing * 0.8);
    ctx.beginPath(); ctx.arc(0, -36, 7, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#191512';
    ctx.beginPath(); ctx.ellipse(0, -40, 8, 4, 0, Math.PI, Math.PI * 2); ctx.fill();
    ctx.restore();
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a1410');
    grad.addColorStop(0.75, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = 'rgba(255,106,0,0.08)';
    for (var b = 0; b < buildings.length; b++) {
      var bd = buildings[b];
      ctx.fillRect(bd.x, groundY - bd.h, bd.w, bd.h);
    }

    ctx.fillStyle = '#252b32';
    ctx.fillRect(0, groundY, W, H - groundY);
    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.beginPath();
    ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.stroke();

    for (var i = 0; i < obstacles.length; i++) {
      var o = obstacles[i];
      var g = ctx.createLinearGradient(o.x, 0, o.x + o.w, 0);
      g.addColorStop(0, o.tall ? '#ff8533' : '#ff6a00');
      g.addColorStop(1, '#ff5500');
      ctx.fillStyle = g;
      ctx.fillRect(o.x, groundY - o.h, o.w, o.h);
    }

    drawCJ();
  }

  function loop() {
    if (!running) return;
    update();
    if (running) {
      draw();
      rafId = requestAnimationFrame(loop);
    }
  }

  function gameOver() {
    running = false;
    over = true;
    cancelAnimationFrame(rafId);
    if (score > best) {
      best = score;
      localStorage.setItem('runnerBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best score: ' + score + '! 🎉';
    } else {
      msgEl.textContent = 'Game over - score: ' + score;
    }
    restartBtn.style.display = 'inline-block';
    draw();
  }

  canvas.addEventListener('mousedown', jump);
  canvas.addEventListener('touchstart', function(e) { e.preventDefault(); jump(); });
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ' || e.key === 'ArrowUp') {
      e.preventDefault();
      jump();
    }
  });
  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
