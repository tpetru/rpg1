<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Basketball</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .bball-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .bball-stats span span { color: var(--accent); }
  #bballCanvas { background: linear-gradient(180deg, #1a2230 0%, #0b0d10 85%); border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; cursor: pointer; }
  .bball-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🏀 Basketball</h1>

  <div class="card" style="text-align: center">
    <div class="bball-stats">
      <span>Score: <span id="bballScore">0</span></span>
      <span>Time: <span id="bballTime">45</span>s</span>
      <span>Best: <span id="bballBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="bballCanvas" width="320" height="420"></canvas></div>
    <p class="bball-msg" id="bballMsg">Drag back from the ball and release to shoot. Sink as many as you can in 45s.</p>
    <button id="bballRestart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('bballCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('bballScore');
  var timeEl = document.getElementById('bballTime');
  var bestEl = document.getElementById('bballBest');
  var msgEl = document.getElementById('bballMsg');
  var restartBtn = document.getElementById('bballRestart');

  var best = parseInt(localStorage.getItem('basketballBest') || '0', 10);
  bestEl.textContent = best;

  var GRAVITY = 0.32;
  var BALL_R = 11;
  var LAUNCH_X = 70, LAUNCH_Y = H - 50;
  var HOOP_Y = 110, RIM_L = 220, RIM_R = 268, RIM_CX = (RIM_L + RIM_R) / 2;

  var ball, score, timeLeft, over, dragging, dragStart, dragNow, rafId, tickTimer;

  function resetBall() {
    ball = { x: LAUNCH_X, y: LAUNCH_Y, vx: 0, vy: 0, moving: false };
  }

  function reset() {
    resetBall();
    score = 0; timeLeft = 45; over = false; dragging = false;
    scoreEl.textContent = 0;
    timeEl.textContent = 45;
    msgEl.textContent = 'Drag back from the ball and release to shoot. Sink as many as you can in 45s.';
    restartBtn.style.display = 'none';
    clearInterval(tickTimer);
    tickTimer = setInterval(function() {
      if (over) return;
      timeLeft--;
      timeEl.textContent = timeLeft;
      if (timeLeft <= 0) endGame();
    }, 1000);
    cancelAnimationFrame(rafId);
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function shoot(dx, dy) {
    var K = 0.16;
    ball.vx = dx * K;
    ball.vy = dy * K;
    ball.moving = true;
  }

  function update() {
    if (!ball.moving) return;
    var prevY = ball.y;
    ball.vy += GRAVITY;
    ball.x += ball.vx;
    ball.y += ball.vy;

    if (ball.vy > 0 && prevY < HOOP_Y && ball.y >= HOOP_Y && ball.x > RIM_L + 6 && ball.x < RIM_R - 6) {
      score++;
      scoreEl.textContent = score;
      ball.moving = false;
      msgEl.textContent = 'Swish! 🏀';
      setTimeout(function() { if (!over) { resetBall(); msgEl.textContent = ''; } }, 500);
      return;
    }

    if (ball.x - BALL_R > W || ball.x + BALL_R < 0 || ball.y - BALL_R > H) {
      ball.moving = false;
      setTimeout(function() { if (!over) { resetBall(); msgEl.textContent = ''; } }, 250);
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a2230');
    grad.addColorStop(0.85, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#252b32';
    ctx.fillRect(RIM_R + 4, HOOP_Y - 50, 8, 70);
    ctx.strokeStyle = '#ff6a00';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(RIM_L, HOOP_Y);
    ctx.lineTo(RIM_R, HOOP_Y);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    for (var n = 0; n < 4; n++) {
      var nx = RIM_L + 8 + n * ((RIM_R - RIM_L - 16) / 3);
      ctx.beginPath();
      ctx.moveTo(nx, HOOP_Y);
      ctx.lineTo(RIM_CX + (nx - RIM_CX) * 0.4, HOOP_Y + 26);
      ctx.stroke();
    }

    ctx.fillStyle = '#252b32';
    ctx.fillRect(0, H - 22, W, 22);

    if (dragging) {
      ctx.strokeStyle = 'rgba(255,106,0,0.6)';
      ctx.lineWidth = 2;
      ctx.setLineDash([6, 5]);
      ctx.beginPath();
      ctx.moveTo(ball.x, ball.y);
      ctx.lineTo(dragNow.x, dragNow.y);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    ctx.fillStyle = '#ff8533';
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, BALL_R, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#0f1115';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(ball.x - BALL_R, ball.y); ctx.lineTo(ball.x + BALL_R, ball.y); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(ball.x, ball.y - BALL_R); ctx.lineTo(ball.x, ball.y + BALL_R); ctx.stroke();
  }

  function loop() {
    if (over) return;
    update();
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function endGame() {
    over = true;
    clearInterval(tickTimer);
    cancelAnimationFrame(rafId);
    if (score > best) {
      best = score;
      localStorage.setItem('basketballBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best score: ' + score + '! 🎉';
    } else {
      msgEl.textContent = "Time's up - score: " + score;
    }
    restartBtn.style.display = 'inline-block';
  }

  function pointerPos(e) {
    var rect = canvas.getBoundingClientRect();
    var cx = (e.touches ? e.touches[0].clientX : e.clientX);
    var cy = (e.touches ? e.touches[0].clientY : e.clientY);
    return { x: (cx - rect.left) * (W / rect.width), y: (cy - rect.top) * (H / rect.height) };
  }

  function onDown(e) {
    if (over || ball.moving) return;
    e.preventDefault();
    dragging = true;
    dragStart = pointerPos(e);
    dragNow = dragStart;
  }
  function onMove(e) {
    if (!dragging) return;
    e.preventDefault();
    dragNow = pointerPos(e);
  }
  function onUp(e) {
    if (!dragging) return;
    dragging = false;
    var p = pointerPos(e);
    var dx = ball.x - p.x;
    var dy = ball.y - p.y;
    var dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > 8) shoot(dx, dy);
  }

  canvas.addEventListener('mousedown', onDown);
  canvas.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  canvas.addEventListener('touchstart', onDown);
  canvas.addEventListener('touchmove', onMove);
  canvas.addEventListener('touchend', onUp);

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
