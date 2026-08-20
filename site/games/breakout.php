<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Breakout</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .breakout-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .breakout-stats span span { color: var(--accent); }
  #breakoutCanvas { background: #0b0d10; border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; cursor: pointer; }
  .breakout-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🧨 Breakout</h1>

  <div class="card" style="text-align: center">
    <div class="breakout-stats">
      <span>Score: <span id="brkScore">0</span></span>
      <span>Lives: <span id="brkLives">3</span></span>
      <span>Best: <span id="brkBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="breakoutCanvas" width="320" height="420"></canvas></div>
    <p class="breakout-msg" id="brkMsg">Move the mouse, drag, or use ← → / A D to steer the paddle. Click/tap or Space to launch.</p>
    <button id="brkRestart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('breakoutCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('brkScore');
  var livesEl = document.getElementById('brkLives');
  var bestEl = document.getElementById('brkBest');
  var msgEl = document.getElementById('brkMsg');
  var restartBtn = document.getElementById('brkRestart');

  var best = parseInt(localStorage.getItem('breakoutBest') || '0', 10);
  bestEl.textContent = best;

  var PADDLE_W = 64, PADDLE_H = 10, BALL_R = 6;
  var ROWS = 5, COLS = 8, BRICK_H = 18, BRICK_PAD = 4, BRICK_TOP = 40;
  var BRICK_W = (W - BRICK_PAD * (COLS + 1)) / COLS;
  var ROW_COLORS = ['#ff5d5d', '#ff8533', '#ffcf4d', '#3ecf8e', '#4d8cff'];

  var paddle, ball, bricks, score, lives, over, launched, rafId;

  function buildBricks() {
    var arr = [];
    for (var r = 0; r < ROWS; r++) {
      for (var c = 0; c < COLS; c++) {
        arr.push({
          x: BRICK_PAD + c * (BRICK_W + BRICK_PAD),
          y: BRICK_TOP + r * (BRICK_H + BRICK_PAD),
          w: BRICK_W, h: BRICK_H, alive: true, color: ROW_COLORS[r % ROW_COLORS.length]
        });
      }
    }
    return arr;
  }

  function resetBall() {
    ball = { x: paddle.x + paddle.w / 2, y: paddle.y - BALL_R - 1, vx: 0, vy: 0 };
    launched = false;
  }

  function reset() {
    paddle = { x: (W - PADDLE_W) / 2, y: H - 28, w: PADDLE_W, h: PADDLE_H };
    bricks = buildBricks();
    score = 0; lives = 3; over = false;
    scoreEl.textContent = 0; livesEl.textContent = 3;
    msgEl.textContent = 'Move the mouse, drag, or use ← → / A D to steer the paddle. Click/tap or Space to launch.';
    restartBtn.style.display = 'none';
    resetBall();
    cancelAnimationFrame(rafId);
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function launch() {
    if (over || launched) return;
    launched = true;
    var angle = -Math.PI / 2 + (Math.random() * 0.6 - 0.3);
    var speed = 4.4;
    ball.vx = Math.cos(angle) * speed;
    ball.vy = Math.sin(angle) * speed;
  }

  function movePaddleTo(px) {
    paddle.x = Math.max(0, Math.min(W - paddle.w, px - paddle.w / 2));
    if (!launched) ball.x = paddle.x + paddle.w / 2;
  }

  function update() {
    if (!launched) return;

    ball.x += ball.vx;
    ball.y += ball.vy;

    if (ball.x - BALL_R < 0) { ball.x = BALL_R; ball.vx *= -1; }
    if (ball.x + BALL_R > W) { ball.x = W - BALL_R; ball.vx *= -1; }
    if (ball.y - BALL_R < 0) { ball.y = BALL_R; ball.vy *= -1; }

    if (ball.y + BALL_R >= paddle.y && ball.y + BALL_R <= paddle.y + paddle.h + 6 &&
        ball.x >= paddle.x - BALL_R && ball.x <= paddle.x + paddle.w + BALL_R && ball.vy > 0) {
      var hit = (ball.x - (paddle.x + paddle.w / 2)) / (paddle.w / 2);
      var speed = Math.min(7.5, Math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy) + 0.06);
      var angle = hit * 1.1 - Math.PI / 2;
      ball.vx = Math.cos(angle) * speed;
      ball.vy = Math.sin(angle) * speed;
      ball.y = paddle.y - BALL_R - 1;
    }

    for (var i = 0; i < bricks.length; i++) {
      var b = bricks[i];
      if (!b.alive) continue;
      if (ball.x + BALL_R > b.x && ball.x - BALL_R < b.x + b.w && ball.y + BALL_R > b.y && ball.y - BALL_R < b.y + b.h) {
        b.alive = false;
        score += 10;
        scoreEl.textContent = score;
        var overlapX = Math.min(ball.x + BALL_R - b.x, b.x + b.w - (ball.x - BALL_R));
        var overlapY = Math.min(ball.y + BALL_R - b.y, b.y + b.h - (ball.y - BALL_R));
        if (overlapX < overlapY) ball.vx *= -1; else ball.vy *= -1;
        break;
      }
    }

    if (bricks.every(function(b) { return !b.alive; })) {
      win();
      return;
    }

    if (ball.y - BALL_R > H) {
      lives--;
      livesEl.textContent = lives;
      if (lives <= 0) { lose(); return; }
      resetBall();
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0b0d10';
    ctx.fillRect(0, 0, W, H);

    bricks.forEach(function(b) {
      if (!b.alive) return;
      ctx.fillStyle = b.color;
      ctx.fillRect(b.x, b.y, b.w, b.h);
    });

    ctx.fillStyle = '#ff6a00';
    ctx.beginPath();
    ctx.roundRect ? ctx.roundRect(paddle.x, paddle.y, paddle.w, paddle.h, 4) : ctx.rect(paddle.x, paddle.y, paddle.w, paddle.h);
    ctx.fill();

    ctx.fillStyle = '#ffd633';
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, BALL_R, 0, Math.PI * 2);
    ctx.fill();
  }

  function loop() {
    if (over) return;
    update();
    if (!over) {
      draw();
      rafId = requestAnimationFrame(loop);
    }
  }

  function win() {
    over = true;
    cancelAnimationFrame(rafId);
    if (score > best) { best = score; localStorage.setItem('breakoutBest', best); bestEl.textContent = best; }
    msgEl.textContent = 'All bricks cleared! 🎉 Score: ' + score;
    restartBtn.style.display = 'inline-block';
  }

  function lose() {
    over = true;
    cancelAnimationFrame(rafId);
    if (score > best) { best = score; localStorage.setItem('breakoutBest', best); bestEl.textContent = best; }
    msgEl.textContent = 'Out of lives - score: ' + score;
    restartBtn.style.display = 'inline-block';
    draw();
  }

  canvas.addEventListener('mousemove', function(e) {
    var rect = canvas.getBoundingClientRect();
    movePaddleTo((e.clientX - rect.left) * (W / rect.width));
  });
  canvas.addEventListener('mousedown', launch);
  canvas.addEventListener('touchmove', function(e) {
    e.preventDefault();
    var rect = canvas.getBoundingClientRect();
    movePaddleTo((e.touches[0].clientX - rect.left) * (W / rect.width));
  });
  canvas.addEventListener('touchstart', function(e) {
    e.preventDefault();
    var rect = canvas.getBoundingClientRect();
    movePaddleTo((e.touches[0].clientX - rect.left) * (W / rect.width));
    launch();
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ') { e.preventDefault(); launch(); }
    else if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') movePaddleTo(paddle.x + paddle.w / 2 - 22);
    else if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') movePaddleTo(paddle.x + paddle.w / 2 + 22);
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
