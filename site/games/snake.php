<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Snake</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .snake-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 14px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .snake-stats span span { color: var(--accent); }
  #snakeCanvas { background: #0b0d10; border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; touch-action: none; }
  .snake-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .snake-controls { margin-top: 16px; display: none; grid-template-columns: repeat(3, 52px); grid-template-rows: repeat(2, 52px); gap: 6px; justify-content: center; }
  .snake-controls button {
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 1.2rem; cursor: pointer;
  }
  .snake-controls button:active { background: var(--accent); color: #0f1115; }
  .snake-up { grid-column: 2; grid-row: 1; }
  .snake-left { grid-column: 1; grid-row: 2; }
  .snake-down { grid-column: 2; grid-row: 2; }
  .snake-right { grid-column: 3; grid-row: 2; }
  @media (max-width: 480px) { .snake-controls { display: grid; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🐍 Snake</h1>

  <div class="card" style="text-align: center">
    <div class="snake-stats">
      <span>Score: <span id="snakeScore">0</span></span>
      <span>Best: <span id="snakeBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="snakeCanvas" width="400" height="400"></canvas></div>
    <p class="snake-msg" id="snakeMsg">Use arrow keys or WASD to move. Press Space to start.</p>
    <button id="snakeRestart" class="btn" style="display:none">Play again</button>
    <div class="snake-controls" aria-hidden="true">
      <button type="button" class="snake-up" data-dir="up">▲</button>
      <button type="button" class="snake-left" data-dir="left">◀</button>
      <button type="button" class="snake-down" data-dir="down">▼</button>
      <button type="button" class="snake-right" data-dir="right">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('snakeCanvas');
  var ctx = canvas.getContext('2d');
  var cell = 20;
  var cols = canvas.width / cell;
  var rows = canvas.height / cell;

  var scoreEl = document.getElementById('snakeScore');
  var bestEl = document.getElementById('snakeBest');
  var msgEl = document.getElementById('snakeMsg');
  var restartBtn = document.getElementById('snakeRestart');

  var snake, dir, dirQueue, food, score, best, running, loopId;

  best = parseInt(localStorage.getItem('snakeBest') || '0', 10);
  bestEl.textContent = best;

  function placeFood() {
    var ok = false;
    while (!ok) {
      food = { x: Math.floor(Math.random() * cols), y: Math.floor(Math.random() * rows) };
      ok = !snake.some(function(s) { return s.x === food.x && s.y === food.y; });
    }
  }

  function reset() {
    snake = [{ x: Math.floor(cols / 2), y: Math.floor(rows / 2) }];
    dir = { x: 0, y: 0 };
    dirQueue = [];
    score = 0;
    scoreEl.textContent = score;
    placeFood();
    running = false;
    clearInterval(loopId);
    msgEl.textContent = 'Use arrow keys or WASD to move. Press Space to start.';
    restartBtn.style.display = 'none';
    draw();
  }

  function draw() {
    ctx.fillStyle = '#0b0d10';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = 'rgba(255,255,255,0.03)';
    for (var i = 0; i <= cols; i++) {
      ctx.beginPath(); ctx.moveTo(i * cell, 0); ctx.lineTo(i * cell, canvas.height); ctx.stroke();
    }
    for (var j = 0; j <= rows; j++) {
      ctx.beginPath(); ctx.moveTo(0, j * cell); ctx.lineTo(canvas.width, j * cell); ctx.stroke();
    }

    ctx.fillStyle = '#ff5da2';
    ctx.beginPath();
    ctx.arc(food.x * cell + cell / 2, food.y * cell + cell / 2, cell / 2 - 2, 0, Math.PI * 2);
    ctx.fill();

    for (var k = 0; k < snake.length; k++) {
      ctx.fillStyle = k === 0 ? '#ff8533' : '#ff6a00';
      ctx.fillRect(snake[k].x * cell + 1, snake[k].y * cell + 1, cell - 2, cell - 2);
    }
  }

  function tick() {
    // Consume queued direction changes (not just the latest one) so quick successive key
    // presses between ticks aren't lost - each still only applies if it's not a U-turn.
    while (dirQueue.length) {
      var next = dirQueue.shift();
      if (next.x !== -dir.x || next.y !== -dir.y) { dir = next; break; }
    }
    if (dir.x === 0 && dir.y === 0) return;

    var head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y };
    var hitWall = head.x < 0 || head.x >= cols || head.y < 0 || head.y >= rows;
    var hitSelf = snake.some(function(s) { return s.x === head.x && s.y === head.y; });
    if (hitWall || hitSelf) {
      gameOver();
      return;
    }

    snake.unshift(head);
    if (head.x === food.x && head.y === food.y) {
      score++;
      scoreEl.textContent = score;
      placeFood();
    } else {
      snake.pop();
    }
    draw();
  }

  function gameOver() {
    running = false;
    clearInterval(loopId);
    if (score > best) {
      best = score;
      localStorage.setItem('snakeBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best score: ' + score + '! 🎉';
    } else {
      msgEl.textContent = 'Game over - score: ' + score;
    }
    restartBtn.style.display = 'inline-block';
  }

  function start() {
    if (running) return;
    running = true;
    msgEl.textContent = 'Go!';
    loopId = setInterval(tick, 160);
  }

  function setDir(next) {
    var last = dirQueue.length ? dirQueue[dirQueue.length - 1] : dir;
    if (next.x === last.x && next.y === last.y) return;
    if (dirQueue.length < 2) dirQueue.push(next);
    start();
  }

  var keyMap = {
    ArrowUp: { x: 0, y: -1 }, w: { x: 0, y: -1 }, W: { x: 0, y: -1 },
    ArrowDown: { x: 0, y: 1 }, s: { x: 0, y: 1 }, S: { x: 0, y: 1 },
    ArrowLeft: { x: -1, y: 0 }, a: { x: -1, y: 0 }, A: { x: -1, y: 0 },
    ArrowRight: { x: 1, y: 0 }, d: { x: 1, y: 0 }, D: { x: 1, y: 0 }
  };

  document.addEventListener('keydown', function(e) {
    if (keyMap[e.key]) {
      e.preventDefault();
      setDir(keyMap[e.key]);
    } else if (e.key === ' ') {
      e.preventDefault();
      start();
    }
  });

  var touchMap = { up: { x: 0, y: -1 }, down: { x: 0, y: 1 }, left: { x: -1, y: 0 }, right: { x: 1, y: 0 } };
  document.querySelectorAll('.snake-controls button').forEach(function(btn) {
    btn.addEventListener('click', function() {
      setDir(touchMap[btn.getAttribute('data-dir')]);
    });
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
