<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Parking</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .park-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .park-stats span span { color: var(--accent); }
  #parkCanvas { background: #12161b; border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; }
  .park-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .park-controls { margin-top: 16px; display: none; grid-template-columns: repeat(3, 56px); grid-template-rows: repeat(2, 46px); gap: 6px; justify-content: center; }
  .park-controls button { background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1.1rem; cursor: pointer; }
  .park-controls button:active { background: var(--accent); color: #0f1115; }
  .park-fwd { grid-column: 2; grid-row: 1; }
  .park-left { grid-column: 1; grid-row: 2; }
  .park-back { grid-column: 2; grid-row: 2; }
  .park-right { grid-column: 3; grid-row: 2; }
  @media (max-width: 480px) { .park-controls { display: grid; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🅿️ Parking</h1>

  <div class="card" style="text-align: center">
    <div class="park-stats">
      <span>Time: <span id="parkTime">40</span>s</span>
      <span>Best: <span id="parkBest">—</span></span>
    </div>
    <div class="game-zone"><canvas id="parkCanvas" width="300" height="440"></canvas></div>
    <p class="park-msg" id="parkMsg">↑↓ or W/S to drive, ←→ or A/D to steer. Park inside the marked spot without hitting anything.</p>
    <button id="parkRestart" class="btn">Restart</button>
    <div class="park-controls" aria-hidden="true">
      <button type="button" data-k="up">▲</button>
      <button type="button" data-k="left">◀</button>
      <button type="button" data-k="down">▼</button>
      <button type="button" data-k="right">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('parkCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  var timeEl = document.getElementById('parkTime');
  var bestEl = document.getElementById('parkBest');
  var msgEl = document.getElementById('parkMsg');
  var restartBtn = document.getElementById('parkRestart');

  var best = parseInt(localStorage.getItem('parkingBest') || '0', 10);
  bestEl.textContent = best > 0 ? best + 's' : '—';

  var ACCEL = 0.16, MAX_FWD = 3.0, MAX_REV = -1.5, FRICTION = 0.965, TURN_RATE = 0.05;
  var CAR_W = 16, CAR_H = 28, CAR_R = 15;

  var ZONE = { x: 108, y: 26, w: 84, h: 60 };
  var OBSTACLES = [
    { x: 20, y: 150, w: 90, h: 26 },
    { x: 190, y: 150, w: 90, h: 26 },
    { x: 60, y: 260, w: 60, h: 22 },
    { x: 180, y: 300, w: 60, h: 22 }
  ];

  var car, timeLeft, over, won, keys, parkTimer, tickTimer, rafId;

  function reset() {
    car = { x: W / 2, y: H - 50, angle: -Math.PI / 2, speed: 0 };
    timeLeft = 40;
    over = false; won = false; parkTimer = 0;
    keys = {};
    timeEl.textContent = 40;
    msgEl.textContent = '↑↓ or W/S to drive, ←→ or A/D to steer. Park inside the marked spot without hitting anything.';
    clearInterval(tickTimer);
    tickTimer = setInterval(function() {
      if (over) return;
      timeLeft--;
      timeEl.textContent = timeLeft;
      if (timeLeft <= 0) endGame(false);
    }, 1000);
    cancelAnimationFrame(rafId);
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function circleRectCollide(cx, cy, r, rx, ry, rw, rh) {
    var nx = Math.max(rx, Math.min(cx, rx + rw));
    var ny = Math.max(ry, Math.min(cy, ry + rh));
    var dx = cx - nx, dy = cy - ny;
    return (dx * dx + dy * dy) < r * r;
  }

  function update() {
    var fwd = keys.up ? 1 : (keys.down ? -1 : 0);
    var steer = keys.left ? -1 : (keys.right ? 1 : 0);

    car.speed += fwd * ACCEL;
    car.speed *= FRICTION;
    if (car.speed > MAX_FWD) car.speed = MAX_FWD;
    if (car.speed < MAX_REV) car.speed = MAX_REV;

    if (Math.abs(car.speed) > 0.05) {
      car.angle += steer * TURN_RATE * (car.speed / MAX_FWD);
    }

    car.x += Math.cos(car.angle) * car.speed;
    car.y += Math.sin(car.angle) * car.speed;

    if (car.x < CAR_R || car.x > W - CAR_R || car.y < CAR_R || car.y > H - CAR_R) {
      endGame(false, 'You drove off the road!');
      return;
    }
    for (var i = 0; i < OBSTACLES.length; i++) {
      var o = OBSTACLES[i];
      if (circleRectCollide(car.x, car.y, CAR_R, o.x, o.y, o.w, o.h)) {
        endGame(false, 'Crashed!');
        return;
      }
    }

    var margin = 10;
    var inZone = car.x > ZONE.x + margin && car.x < ZONE.x + ZONE.w - margin &&
                 car.y > ZONE.y + margin && car.y < ZONE.y + ZONE.h - margin;
    if (inZone && Math.abs(car.speed) < 0.18) {
      parkTimer++;
      if (parkTimer > 40) { endGame(true); return; }
    } else {
      parkTimer = 0;
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#12161b';
    ctx.fillRect(0, 0, W, H);

    ctx.strokeStyle = '#ff8533';
    ctx.setLineDash([8, 6]);
    ctx.lineWidth = 2;
    ctx.strokeRect(ZONE.x, ZONE.y, ZONE.w, ZONE.h);
    ctx.setLineDash([]);
    ctx.fillStyle = 'rgba(255,133,51,0.35)';
    ctx.font = 'bold 20px Arial';
    ctx.textAlign = 'center';
    ctx.fillText('P', ZONE.x + ZONE.w / 2, ZONE.y + ZONE.h / 2 + 7);

    ctx.fillStyle = '#2a2f37';
    OBSTACLES.forEach(function(o) { ctx.fillRect(o.x, o.y, o.w, o.h); });

    ctx.save();
    ctx.translate(car.x, car.y);
    ctx.rotate(car.angle + Math.PI / 2);
    ctx.fillStyle = '#ff6a00';
    ctx.fillRect(-CAR_W / 2, -CAR_H / 2, CAR_W, CAR_H);
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fillRect(-CAR_W / 2 + 2, -CAR_H / 2 + 5, CAR_W - 4, 8);
    ctx.restore();
  }

  function loop() {
    if (over) return;
    update();
    if (!over) {
      draw();
      rafId = requestAnimationFrame(loop);
    }
  }

  function endGame(success, customMsg) {
    over = true;
    won = success;
    clearInterval(tickTimer);
    cancelAnimationFrame(rafId);
    draw();
    if (success) {
      if (best === 0 || timeLeft > best) {
        best = timeLeft;
        localStorage.setItem('parkingBest', best);
        bestEl.textContent = best + 's';
      }
      msgEl.textContent = 'Parked! 🎉 (' + timeLeft + 's left)';
    } else {
      msgEl.textContent = customMsg || "Time's up!";
    }
  }

  var keyMap = {
    ArrowUp: 'up', w: 'up', W: 'up',
    ArrowDown: 'down', s: 'down', S: 'down',
    ArrowLeft: 'left', a: 'left', A: 'left',
    ArrowRight: 'right', d: 'right', D: 'right'
  };
  document.addEventListener('keydown', function(e) {
    if (keyMap[e.key]) { e.preventDefault(); keys[keyMap[e.key]] = true; }
  });
  document.addEventListener('keyup', function(e) {
    if (keyMap[e.key]) keys[keyMap[e.key]] = false;
  });
  document.querySelectorAll('.park-controls button').forEach(function(btn) {
    var k = btn.getAttribute('data-k');
    btn.addEventListener('touchstart', function(e) { e.preventDefault(); keys[k] = true; });
    btn.addEventListener('touchend', function(e) { e.preventDefault(); keys[k] = false; });
    btn.addEventListener('mousedown', function() { keys[k] = true; });
    btn.addEventListener('mouseup', function() { keys[k] = false; });
    btn.addEventListener('mouseleave', function() { keys[k] = false; });
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
