<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Frogger</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .frg-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 0.98rem; }
  .frg-stats span span { color: var(--accent); }
  #frgCanvas { background: #0b0d10; border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; }
  .frg-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .frg-controls { margin-top: 16px; display: none; grid-template-columns: repeat(3, 56px); grid-template-rows: repeat(2, 46px); gap: 6px; justify-content: center; }
  .frg-controls button { background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1.1rem; cursor: pointer; }
  .frg-controls button:active { background: var(--accent); color: #0f1115; }
  .frg-up { grid-column: 2; grid-row: 1; }
  .frg-left { grid-column: 1; grid-row: 2; }
  .frg-down { grid-column: 2; grid-row: 2; }
  .frg-right { grid-column: 3; grid-row: 2; }
  @media (max-width: 480px) { .frg-controls { display: grid; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>

<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🚦 Frogger</h1>

  <div class="card" style="text-align: center">
    <div class="frg-stats">
      <span>Time: <span id="frgTime">25</span>s</span>
      <span>Lives: <span id="frgLives">3</span></span>
      <span>Score: <span id="frgScore">0</span></span>
      <span>Best: <span id="frgBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="frgCanvas" width="320" height="480"></canvas></div>
    <p class="frg-msg" id="frgMsg">Arrows or WASD to hop. Cross the road, ride the logs across the river, reach all 4 landing pads.</p>
    <button id="frgRestart" class="btn" style="display:none">Play again</button>
    <div class="frg-controls" aria-hidden="true">
      <button type="button" class="frg-up" data-dir="up">▲</button>
      <button type="button" class="frg-left" data-dir="left">◀</button>
      <button type="button" class="frg-down" data-dir="down">▼</button>
      <button type="button" class="frg-right" data-dir="right">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('frgCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;
  var cell = 40, cols = 8, rows = 12;
  var PW = 26;

  var timeEl = document.getElementById('frgTime');
  var livesEl = document.getElementById('frgLives');
  var scoreEl = document.getElementById('frgScore');
  var bestEl = document.getElementById('frgBest');
  var msgEl = document.getElementById('frgMsg');
  var restartBtn = document.getElementById('frgRestart');

  var best = parseInt(localStorage.getItem('froggerBest') || '0', 10);
  bestEl.textContent = best;

  var GOAL_ROW = 0, RIVER_ROWS = [1, 2, 3, 4], MEDIAN_ROW = 5, ROAD_ROWS = [6, 7, 8], START_ROW = 11;
  var GOAL_COLS = [0, 2, 5, 7];
  var START_X = 3 * cell;

  var player, roads, rivers, goalsFilled, levelMul;
  var score, lives, timeLeft, over, started, frame, rafId;

  function buildLanes(mul) {
    roads = ROAD_ROWS.map(function(row, i) {
      var dir = i % 2 === 0 ? 1 : -1;
      var speed = (0.6 + i * 0.5) * mul;
      var w = 40, spacing = 110;
      var cars = [];
      for (var n = 0; n < 3; n++) cars.push({ x: n * spacing + (dir > 0 ? -spacing : W), w: w });
      return { row: row, dir: dir, speed: speed, cars: cars };
    });
    rivers = RIVER_ROWS.map(function(row, i) {
      var dir = i % 2 === 0 ? -1 : 1;
      var speed = (0.7 + i * 0.3) * mul;
      var w = 74, spacing = 140;
      var logs = [];
      for (var n = 0; n < 3; n++) logs.push({ x: n * spacing + (dir > 0 ? -spacing : W), w: w });
      return { row: row, dir: dir, speed: speed, logs: logs };
    });
  }

  function respawnPlayer() {
    player.x = START_X;
    player.y = START_ROW * cell;
    timeLeft = 25;
  }

  function reset() {
    player = { x: START_X, y: START_ROW * cell };
    levelMul = 1;
    buildLanes(levelMul);
    goalsFilled = [false, false, false, false];
    score = 0; lives = 3; timeLeft = 25; over = false; started = false; frame = 0;
    scoreEl.textContent = 0;
    livesEl.textContent = 3;
    timeEl.textContent = 25;
    msgEl.textContent = 'Arrows or WASD to hop. Cross the road, ride the logs across the river, reach all 4 landing pads.';
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

  function move(dx, dy) {
    if (over) return;
    if (!started) { start(); return; }
    var nx = player.x + dx * cell, ny = player.y + dy * cell;
    if (nx < 0 || nx + PW > W) return;
    if (ny < 0 || ny > START_ROW * cell) return;
    player.x = nx;
    player.y = ny;
  }

  function rowAt(y) { return Math.round(y / cell); }

  function nearestGoalSlot(x) {
    var center = x + PW / 2;
    for (var i = 0; i < GOAL_COLS.length; i++) {
      var slotCenter = GOAL_COLS[i] * cell + cell / 2;
      if (Math.abs(center - slotCenter) < cell / 2) return i;
    }
    return -1;
  }

  function loseLife(reason) {
    lives--;
    livesEl.textContent = lives;
    if (lives <= 0) { gameOver(reason); return; }
    msgEl.textContent = reason;
    respawnPlayer();
  }

  function update() {
    frame++;
    timeLeft -= 1 / 60;
    timeEl.textContent = Math.max(0, Math.ceil(timeLeft));
    if (timeLeft <= 0) { loseLife("Time's up!"); return; }

    roads.forEach(function(lane) {
      lane.cars.forEach(function(c) {
        c.x += lane.dir * lane.speed;
        if (lane.dir > 0 && c.x > W) c.x = -c.w;
        if (lane.dir < 0 && c.x + c.w < 0) c.x = W;
      });
    });
    rivers.forEach(function(lane) {
      lane.logs.forEach(function(l) {
        l.x += lane.dir * lane.speed;
        if (lane.dir > 0 && l.x > W) l.x = -l.w;
        if (lane.dir < 0 && l.x + l.w < 0) l.x = W;
      });
    });

    var pr = rowAt(player.y);

    if (ROAD_ROWS.indexOf(pr) !== -1) {
      var rlane = roads.filter(function(l) { return l.row === pr; })[0];
      var hit = rlane.cars.some(function(c) { return player.x + PW > c.x && player.x < c.x + c.w; });
      if (hit) { loseLife('Splat! A car got you.'); return; }
    }

    if (RIVER_ROWS.indexOf(pr) !== -1) {
      var wlane = rivers.filter(function(l) { return l.row === pr; })[0];
      var onLog = wlane.logs.filter(function(l) { return player.x + PW > l.x && player.x < l.x + l.w; })[0];
      if (!onLog) { loseLife('Splash! You fell in the river.'); return; }
      player.x += wlane.dir * wlane.speed;
      if (player.x < 0 || player.x + PW > W) { loseLife('Swept off the edge!'); return; }
    }

    if (pr === GOAL_ROW) {
      var slot = nearestGoalSlot(player.x);
      if (slot === -1 || goalsFilled[slot]) { loseLife('No safe landing there!'); return; }
      goalsFilled[slot] = true;
      score += 50;
      scoreEl.textContent = score;
      if (score > best) { best = score; localStorage.setItem('froggerBest', best); bestEl.textContent = best; }
      msgEl.textContent = 'Nice hop! 🎉';
      respawnPlayer();
      if (goalsFilled.every(Boolean)) {
        goalsFilled = [false, false, false, false];
        levelMul += 0.15;
        buildLanes(levelMul);
        msgEl.textContent = 'Round clear! Next round is faster.';
      }
    }
  }

  function rowColor(row) {
    if (row === GOAL_ROW) return '#12362e';
    if (RIVER_ROWS.indexOf(row) !== -1) return '#123a52';
    if (row === MEDIAN_ROW) return '#1c3a1f';
    if (ROAD_ROWS.indexOf(row) !== -1) return '#202226';
    return '#1c3a1f';
  }

  function drawPlayer() {
    ctx.save();
    ctx.translate(player.x + PW / 2, player.y + cell / 2);
    ctx.fillStyle = '#f0f0ec';
    ctx.fillRect(-8, -2, 16, 15);
    ctx.fillStyle = '#3a5a96';
    ctx.fillRect(-8, 10, 16, 5);
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

  function draw() {
    ctx.clearRect(0, 0, W, H);
    for (var r = 0; r < rows; r++) {
      ctx.fillStyle = rowColor(r);
      ctx.fillRect(0, r * cell, W, cell);
    }

    for (var g = 0; g < GOAL_COLS.length; g++) {
      var gx = GOAL_COLS[g] * cell;
      ctx.fillStyle = goalsFilled[g] ? '#ff8533' : 'rgba(62,207,142,0.35)';
      ctx.fillRect(gx + 4, 6, cell - 8, cell - 12);
    }

    ctx.fillStyle = '#8a6a3a';
    roads.forEach(function(lane) {
      lane.cars.forEach(function(c) {
        ctx.fillStyle = '#ff8533';
        ctx.fillRect(c.x, lane.row * cell + 6, c.w, cell - 12);
        ctx.fillStyle = 'rgba(255,255,255,0.3)';
        ctx.fillRect(c.x + 4, lane.row * cell + 9, c.w - 8, 6);
      });
    });
    rivers.forEach(function(lane) {
      lane.logs.forEach(function(l) {
        ctx.fillStyle = '#8a5a2e';
        ctx.fillRect(l.x, lane.row * cell + 8, l.w, cell - 16);
      });
    });

    drawPlayer();
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
    if (score > best) { best = score; localStorage.setItem('froggerBest', best); bestEl.textContent = best; }
    msgEl.textContent = (reason || 'Game over') + ' Final score: ' + score;
    restartBtn.style.display = 'inline-block';
    draw();
  }

  var keyMap = {
    ArrowUp: [0, -1], w: [0, -1], W: [0, -1],
    ArrowDown: [0, 1], s: [0, 1], S: [0, 1],
    ArrowLeft: [-1, 0], a: [-1, 0], A: [-1, 0],
    ArrowRight: [1, 0], d: [1, 0], D: [1, 0]
  };
  document.addEventListener('keydown', function(e) {
    if (keyMap[e.key]) { e.preventDefault(); if (over) { reset(); } else { move(keyMap[e.key][0], keyMap[e.key][1]); } }
  });

  var touchMap = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
  document.querySelectorAll('.frg-controls button').forEach(function(btn) {
    btn.addEventListener('click', function() {
      if (over) { reset(); return; }
      var d = touchMap[btn.getAttribute('data-dir')];
      move(d[0], d[1]);
    });
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
