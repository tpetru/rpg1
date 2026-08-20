<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Flappy</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .flappy-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 14px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .flappy-stats span span { color: var(--accent); }
  #flappyCanvas {
    background: linear-gradient(180deg, #1a2230 0%, #0b0d10 85%);
    border: 1px solid var(--border); border-radius: 10px;
    max-width: 100%; display: block; margin: 0 auto;
    touch-action: none; cursor: pointer;
  }
  .flappy-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🧑🏾 Flappy</h1>

  <div class="card" style="text-align: center">
    <div class="flappy-stats">
      <span>Score: <span id="flappyScore">0</span></span>
      <span>Best: <span id="flappyBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="flappyCanvas" width="320" height="480"></canvas></div>
    <p class="flappy-msg" id="flappyMsg">Tap, click, or press Space / ↑ to flap.</p>
    <button id="flappyRestart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('flappyCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('flappyScore');
  var bestEl = document.getElementById('flappyBest');
  var msgEl = document.getElementById('flappyMsg');
  var restartBtn = document.getElementById('flappyRestart');

  var best = parseInt(localStorage.getItem('flappyBest') || '0', 10);
  bestEl.textContent = best;

  var GRAVITY = 0.45;
  var FLAP_VELOCITY = -7.6;
  var PIPE_GAP = 132;
  var PIPE_WIDTH = 52;
  var PIPE_SPEED = 2.6;
  var PIPE_SPACING = 200;
  var GROUND_H = 4;

  var bird, pipes, score, running, over, started, frame, rafId;

  function reset() {
    bird = { x: W / 3, y: H / 2, vy: 0 };
    pipes = [];
    score = 0;
    frame = 0;
    running = false;
    over = false;
    started = false;
    scoreEl.textContent = 0;
    msgEl.textContent = 'Tap, click, or press Space / ↑ to flap.';
    restartBtn.style.display = 'none';
    draw();
  }

  function spawnPipe() {
    var margin = 40;
    var top = margin + Math.random() * (H - GROUND_H - PIPE_GAP - margin * 2);
    pipes.push({ x: W, top: top, passed: false });
  }

  function flap() {
    if (over) return;
    if (!started) {
      started = true;
      running = true;
      msgEl.textContent = '';
      loop();
    }
    bird.vy = FLAP_VELOCITY;
  }

  function update() {
    frame++;
    bird.vy += GRAVITY;
    bird.y += bird.vy;

    if (frame === 1 || pipes.length === 0 || pipes[pipes.length - 1].x < W - PIPE_SPACING) {
      spawnPipe();
    }

    for (var i = pipes.length - 1; i >= 0; i--) {
      var p = pipes[i];
      p.x -= PIPE_SPEED;
      if (!p.passed && p.x + PIPE_WIDTH < bird.x) {
        p.passed = true;
        score++;
        scoreEl.textContent = score;
      }
      if (p.x < -PIPE_WIDTH) pipes.splice(i, 1);
    }

    var birdR = 12;
    if (bird.y + birdR >= H - GROUND_H || bird.y - birdR <= 0) {
      gameOver();
      return;
    }
    for (var j = 0; j < pipes.length; j++) {
      var pp = pipes[j];
      var inX = bird.x + birdR > pp.x && bird.x - birdR < pp.x + PIPE_WIDTH;
      if (inX) {
        var inGap = bird.y - birdR > pp.top && bird.y + birdR < pp.top + PIPE_GAP;
        if (!inGap) { gameOver(); return; }
      }
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a2230');
    grad.addColorStop(0.85, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#ff6a00';
    for (var i = 0; i < pipes.length; i++) {
      var p = pipes[i];
      var g = ctx.createLinearGradient(p.x, 0, p.x + PIPE_WIDTH, 0);
      g.addColorStop(0, '#ff8533');
      g.addColorStop(1, '#ff6a00');
      ctx.fillStyle = g;
      ctx.fillRect(p.x, 0, PIPE_WIDTH, p.top);
      ctx.fillRect(p.x, p.top + PIPE_GAP, PIPE_WIDTH, H - (p.top + PIPE_GAP));
    }

    ctx.fillStyle = '#252b32';
    ctx.fillRect(0, H - GROUND_H, W, GROUND_H);

    ctx.save();
    ctx.translate(bird.x, bird.y);
    var angle = Math.max(-0.5, Math.min(0.9, bird.vy / 10));
    ctx.rotate(angle);
    ctx.fillStyle = '#f0f0ec';
    ctx.fillRect(-7, -2, 14, 13);
    ctx.fillStyle = '#3a5a96';
    ctx.fillRect(-7, 9, 14, 4);
    ctx.fillStyle = '#a5673f';
    ctx.beginPath();
    ctx.arc(0, -9, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#191512';
    ctx.beginPath();
    ctx.ellipse(0, -13, 8.4, 4.4, 0, Math.PI, Math.PI * 2);
    ctx.fill();
    ctx.restore();
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
      localStorage.setItem('flappyBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best score: ' + score + '! 🎉';
    } else {
      msgEl.textContent = 'Game over - score: ' + score;
    }
    restartBtn.style.display = 'inline-block';
    draw();
  }

  canvas.addEventListener('mousedown', flap);
  canvas.addEventListener('touchstart', function(e) { e.preventDefault(); flap(); });
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ' || e.key === 'ArrowUp') {
      e.preventDefault();
      flap();
    }
  });
  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
