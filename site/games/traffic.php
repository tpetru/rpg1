<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Traffic</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .traffic-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 14px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .traffic-stats span span { color: var(--accent); }
  #trafficCanvas {
    background: #12161b;
    border: 1px solid var(--border); border-radius: 10px;
    max-width: 100%; display: block; margin: 0 auto;
    touch-action: none; cursor: pointer;
  }
  .traffic-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .traffic-controls { margin-top: 16px; display: none; justify-content: center; gap: 10px; }
  .traffic-controls button {
    width: 70px; height: 46px;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 1.2rem; cursor: pointer;
  }
  .traffic-controls button:active { background: var(--accent); color: #0f1115; }
  @media (max-width: 480px) { .traffic-controls { display: flex; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🚗 Traffic</h1>

  <div class="card" style="text-align: center">
    <div class="traffic-stats">
      <span>Score: <span id="trafficScore">0</span></span>
      <span>Best: <span id="trafficBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="trafficCanvas" width="320" height="480"></canvas></div>
    <p class="traffic-msg" id="trafficMsg">Tap left/right, or use ← → / A D, to change lanes. Don't crash.</p>
    <button id="trafficRestart" class="btn" style="display:none">Play again</button>
    <div class="traffic-controls" aria-hidden="true">
      <button type="button" data-dir="-1">◀</button>
      <button type="button" data-dir="1">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('trafficCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var scoreEl = document.getElementById('trafficScore');
  var bestEl = document.getElementById('trafficBest');
  var msgEl = document.getElementById('trafficMsg');
  var restartBtn = document.getElementById('trafficRestart');

  var best = parseInt(localStorage.getItem('trafficBest') || '0', 10);
  bestEl.textContent = best;

  var LANES = 3;
  var LANE_W = 70;
  var ROAD_X = (W - LANE_W * LANES) / 2;
  var BASE_SPEED = 3.2;
  var SPEED_CAP = 8.2;

  function laneCenterX(lane) { return ROAD_X + LANE_W * lane + LANE_W / 2; }

  var player, cars, distance, score, speed, stripeOffset, lastSpawnFrame, running, over, started, frame, rafId;

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function drawCar(cx, cy, w, h, color) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.fillStyle = color;
    roundRect(-w / 2, -h / 2, w, h, 6);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    roundRect(-w / 2 + 5, -h / 2 + 8, w - 10, h * 0.3, 3);
    ctx.fill();
    ctx.restore();
  }

  function reset() {
    player = { lane: 1, x: laneCenterX(1), targetX: laneCenterX(1), w: 34, h: 56, y: H - 90 };
    cars = [];
    distance = 0; score = 0; speed = BASE_SPEED;
    stripeOffset = 0; frame = 0; lastSpawnFrame = -999;
    running = false; over = false; started = false;
    scoreEl.textContent = 0;
    msgEl.textContent = "Tap left/right, or use ← → / A D, to change lanes. Don't crash.";
    restartBtn.style.display = 'none';
    draw();
  }

  function changeLane(dir) {
    if (over) return;
    var newLane = player.lane + dir;
    if (newLane < 0 || newLane >= LANES) return;
    player.lane = newLane;
    player.targetX = laneCenterX(newLane);
    if (!started) {
      started = true;
      running = true;
      msgEl.textContent = '';
      loop();
    }
  }

  var CAR_COLORS = ['#4d8cff', '#3ecf8e', '#c874ff', '#ffcf4d', '#ff5d5d'];

  function spawnCar() {
    var lane = Math.floor(Math.random() * LANES);
    for (var i = 0; i < cars.length; i++) {
      if (cars[i].lane === lane && cars[i].y < 100) return;
    }
    cars.push({
      lane: lane, x: laneCenterX(lane), y: -70, w: 34, h: 56,
      color: CAR_COLORS[Math.floor(Math.random() * CAR_COLORS.length)]
    });
  }

  function overlap(ax, ay, aw, ah, bx, by, bw, bh) {
    return Math.abs(ax - bx) < (aw + bw) / 2 - 6 && Math.abs(ay - by) < (ah + bh) / 2 - 6;
  }

  function update() {
    frame++;
    distance += speed;
    speed = Math.min(SPEED_CAP, BASE_SPEED + distance * 0.0011);

    var newScore = Math.floor(distance / 6);
    if (newScore !== score) { score = newScore; scoreEl.textContent = score; }

    player.x += (player.targetX - player.x) * 0.25;
    stripeOffset = (stripeOffset + speed) % 34;

    var spawnInterval = Math.max(34, 68 - speed * 3);
    if (frame - lastSpawnFrame >= spawnInterval) {
      spawnCar();
      lastSpawnFrame = frame;
    }

    for (var i = cars.length - 1; i >= 0; i--) {
      var c = cars[i];
      c.y += speed;
      if (c.y > H + 60) { cars.splice(i, 1); continue; }
      if (overlap(player.x, player.y, player.w, player.h, c.x, c.y, c.w, c.h)) {
        gameOver();
        return;
      }
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#12161b';
    ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#1c2128';
    ctx.fillRect(ROAD_X, 0, LANE_W * LANES, H);

    ctx.strokeStyle = 'rgba(255,255,255,0.25)';
    ctx.lineWidth = 3;
    ctx.setLineDash([18, 16]);
    for (var l = 1; l < LANES; l++) {
      var x = ROAD_X + LANE_W * l;
      ctx.beginPath();
      ctx.moveTo(x, -34 + stripeOffset);
      ctx.lineTo(x, H);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    ctx.fillStyle = '#ff8533';
    ctx.fillRect(ROAD_X - 4, 0, 4, H);
    ctx.fillRect(ROAD_X + LANE_W * LANES, 0, 4, H);

    cars.forEach(function(c) { drawCar(c.x, c.y, c.w, c.h, c.color); });
    drawCar(player.x, player.y, player.w, player.h, '#ff6a00');
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
      localStorage.setItem('trafficBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best score: ' + score + '! 🎉';
    } else {
      msgEl.textContent = 'Crashed - score: ' + score;
    }
    restartBtn.style.display = 'inline-block';
    draw();
  }

  canvas.addEventListener('mousedown', function(e) {
    var rect = canvas.getBoundingClientRect();
    var x = (e.clientX - rect.left) * (W / rect.width);
    changeLane(x < W / 2 ? -1 : 1);
  });
  canvas.addEventListener('touchstart', function(e) {
    e.preventDefault();
    var rect = canvas.getBoundingClientRect();
    var x = (e.touches[0].clientX - rect.left) * (W / rect.width);
    changeLane(x < W / 2 ? -1 : 1);
  });
  document.addEventListener('keydown', function(e) {
    var map = { ArrowLeft: -1, a: -1, A: -1, ArrowRight: 1, d: 1, D: 1 };
    if (map[e.key] !== undefined) {
      e.preventDefault();
      changeLane(map[e.key]);
    }
  });
  document.querySelectorAll('.traffic-controls button').forEach(function(btn) {
    btn.addEventListener('click', function() { changeLane(parseInt(btn.getAttribute('data-dir'), 10)); });
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
