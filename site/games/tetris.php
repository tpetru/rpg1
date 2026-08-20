<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Tetris</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .tetris-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 6px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .tetris-stats span span { color: var(--accent); }
  .tetris-sub { color: var(--muted); font-size: 0.82rem; margin-bottom: 12px; }
  .tetris-layout { display: flex; gap: 14px; justify-content: center; align-items: flex-start; flex-wrap: wrap; }
  #tetrisCanvas { background: #0b0d10; border: 1px solid var(--border); border-radius: 10px; touch-action: none; }
  .tetris-side { display: flex; flex-direction: column; align-items: center; gap: 6px; }
  .tetris-side .lbl { color: var(--muted); font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.5px; }
  #tetrisNext { background: #0b0d10; border: 1px solid var(--border); border-radius: 10px; }
  .tetris-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .tetris-controls { margin-top: 16px; display: none; grid-template-columns: repeat(3, 52px); grid-template-rows: repeat(2, 52px); gap: 6px; justify-content: center; }
  .tetris-controls button {
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    color: var(--text); font-size: 1.2rem; cursor: pointer;
  }
  .tetris-controls button:active { background: var(--accent); color: #0f1115; }
  .tetris-rotate { grid-column: 2; grid-row: 1; }
  .tetris-left { grid-column: 1; grid-row: 2; }
  .tetris-down { grid-column: 2; grid-row: 2; }
  .tetris-right { grid-column: 3; grid-row: 2; }
  @media (max-width: 480px) { .tetris-controls { display: grid; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🧱 Tetris</h1>

  <div class="card" style="text-align: center">
    <div class="tetris-stats">
      <span>Score: <span id="tetrisScore">0</span></span>
      <span>Best: <span id="tetrisBest">0</span></span>
    </div>
    <div class="tetris-sub">Level <span id="tetrisLevel">1</span> &middot; Lines <span id="tetrisLines">0</span></div>

    <div class="game-zone">
      <div class="tetris-layout">
        <canvas id="tetrisCanvas" width="240" height="480"></canvas>
        <div class="tetris-side">
          <div class="lbl">Next</div>
          <canvas id="tetrisNext" width="88" height="88"></canvas>
        </div>
      </div>
    </div>

    <p class="tetris-msg" id="tetrisMsg">Arrows/WASD to move &amp; rotate, Space to hard drop.</p>
    <button id="tetrisRestart" class="btn" style="display:none">Play again</button>
    <div class="tetris-controls" aria-hidden="true">
      <button type="button" class="tetris-rotate" data-act="rotate">⟳</button>
      <button type="button" class="tetris-left" data-act="left">◀</button>
      <button type="button" class="tetris-down" data-act="down">▼</button>
      <button type="button" class="tetris-right" data-act="right">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var cols = 10, rows = 20, cell = 24;
  var canvas = document.getElementById('tetrisCanvas');
  var ctx = canvas.getContext('2d');
  var nextCanvas = document.getElementById('tetrisNext');
  var nctx = nextCanvas.getContext('2d');

  var scoreEl = document.getElementById('tetrisScore');
  var bestEl = document.getElementById('tetrisBest');
  var levelEl = document.getElementById('tetrisLevel');
  var linesEl = document.getElementById('tetrisLines');
  var msgEl = document.getElementById('tetrisMsg');
  var restartBtn = document.getElementById('tetrisRestart');

  var best = parseInt(localStorage.getItem('tetrisBest') || '0', 10);
  bestEl.textContent = best;

  var PIECES = {
    I: { color: '#4dd9ff', shape: [[0,0,0,0],[1,1,1,1],[0,0,0,0],[0,0,0,0]] },
    O: { color: '#ffe000', shape: [[1,1],[1,1]] },
    T: { color: '#c874ff', shape: [[0,1,0],[1,1,1],[0,0,0]] },
    S: { color: '#3ecf8e', shape: [[0,1,1],[1,1,0],[0,0,0]] },
    Z: { color: '#ff5d5d', shape: [[1,1,0],[0,1,1],[0,0,0]] },
    J: { color: '#4d8cff', shape: [[1,0,0],[1,1,1],[0,0,0]] },
    L: { color: '#ff8533', shape: [[0,0,1],[1,1,1],[0,0,0]] }
  };
  var PIECE_KEYS = Object.keys(PIECES);

  var board, current, nextPiece, score, lines, level, running, over, loopId;

  function emptyBoard() {
    var b = [];
    for (var r = 0; r < rows; r++) b.push(new Array(cols).fill(0));
    return b;
  }

  function randomKey() { return PIECE_KEYS[Math.floor(Math.random() * PIECE_KEYS.length)]; }

  function newPiece(key) {
    var def = PIECES[key];
    var shape = def.shape.map(function(row) { return row.slice(); });
    return { shape: shape, color: def.color, x: Math.floor((cols - shape[0].length) / 2), y: 0 };
  }

  function rotateMatrix(m) {
    var n = m.length, res = [];
    for (var i = 0; i < n; i++) res.push(new Array(n).fill(0));
    for (var r = 0; r < n; r++) for (var c = 0; c < n; c++) res[c][n - 1 - r] = m[r][c];
    return res;
  }

  function collides(shape, px, py) {
    for (var r = 0; r < shape.length; r++) {
      for (var c = 0; c < shape[r].length; c++) {
        if (!shape[r][c]) continue;
        var x = px + c, y = py + r;
        if (x < 0 || x >= cols || y >= rows) return true;
        if (y >= 0 && board[y][x]) return true;
      }
    }
    return false;
  }

  function mergePiece() {
    for (var r = 0; r < current.shape.length; r++) {
      for (var c = 0; c < current.shape[r].length; c++) {
        if (current.shape[r][c]) {
          var y = current.y + r;
          if (y >= 0) board[y][current.x + c] = current.color;
        }
      }
    }
  }

  function clearLines() {
    var cleared = 0;
    for (var r = rows - 1; r >= 0; r--) {
      if (board[r].every(function(v) { return v; })) {
        board.splice(r, 1);
        board.unshift(new Array(cols).fill(0));
        cleared++;
        r++;
      }
    }
    return cleared;
  }

  function updateSpeed() {
    if (!running) return;
    clearInterval(loopId);
    var interval = Math.max(120, 700 - (level - 1) * 50);
    loopId = setInterval(tick, interval);
  }

  function spawn() {
    current = nextPiece || newPiece(randomKey());
    nextPiece = newPiece(randomKey());
    drawNext();
    if (collides(current.shape, current.x, current.y)) {
      gameOver();
    }
  }

  function lockPiece() {
    mergePiece();
    var cleared = clearLines();
    if (cleared) {
      lines += cleared;
      linesEl.textContent = lines;
      var table = [0, 100, 300, 500, 800];
      score += table[cleared] * level;
      scoreEl.textContent = score;
      if (score > best) {
        best = score;
        localStorage.setItem('tetrisBest', best);
        bestEl.textContent = best;
      }
      var newLevel = Math.floor(lines / 10) + 1;
      if (newLevel !== level) {
        level = newLevel;
        levelEl.textContent = level;
        updateSpeed();
      }
    }
    spawn();
    draw();
  }

  function move(dx, dy) {
    if (collides(current.shape, current.x + dx, current.y + dy)) return false;
    current.x += dx;
    current.y += dy;
    draw();
    return true;
  }

  function rotate() {
    var rotated = rotateMatrix(current.shape);
    var kicks = [0, -1, 1, -2, 2];
    for (var i = 0; i < kicks.length; i++) {
      if (!collides(rotated, current.x + kicks[i], current.y)) {
        current.shape = rotated;
        current.x += kicks[i];
        draw();
        return;
      }
    }
  }

  function hardDrop() {
    while (move(0, 1)) {}
    lockPiece();
  }

  function tick() {
    if (!move(0, 1)) lockPiece();
  }

  function gameOver() {
    running = false;
    over = true;
    clearInterval(loopId);
    msgEl.textContent = 'Game over - final score: ' + score;
    restartBtn.style.display = 'inline-block';
  }

  function start() {
    if (running || over) return;
    running = true;
    msgEl.textContent = 'Go!';
    updateSpeed();
  }

  function reset() {
    board = emptyBoard();
    current = null;
    nextPiece = null;
    score = 0; lines = 0; level = 1;
    running = false; over = false;
    clearInterval(loopId);
    scoreEl.textContent = 0;
    linesEl.textContent = 0;
    levelEl.textContent = 1;
    msgEl.textContent = 'Arrows/WASD to move & rotate, Space to hard drop.';
    restartBtn.style.display = 'none';
    spawn();
    draw();
  }

  function draw() {
    ctx.fillStyle = '#0b0d10';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = 'rgba(255,255,255,0.03)';
    for (var i = 0; i <= cols; i++) { ctx.beginPath(); ctx.moveTo(i * cell, 0); ctx.lineTo(i * cell, canvas.height); ctx.stroke(); }
    for (var j = 0; j <= rows; j++) { ctx.beginPath(); ctx.moveTo(0, j * cell); ctx.lineTo(canvas.width, j * cell); ctx.stroke(); }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (board[r][c]) drawCell(ctx, c, r, board[r][c]);
      }
    }
    if (current) {
      for (var pr = 0; pr < current.shape.length; pr++) {
        for (var pc = 0; pc < current.shape[pr].length; pc++) {
          if (current.shape[pr][pc]) drawCell(ctx, current.x + pc, current.y + pr, current.color);
        }
      }
    }
  }

  function drawCell(context, x, y, color) {
    if (y < 0) return;
    context.fillStyle = color;
    context.fillRect(x * cell + 1, y * cell + 1, cell - 2, cell - 2);
  }

  function drawNext() {
    nctx.fillStyle = '#0b0d10';
    nctx.fillRect(0, 0, nextCanvas.width, nextCanvas.height);
    if (!nextPiece) return;
    var s = nextPiece.shape;
    var n = s.length;
    var c = 18;
    var offsetX = (nextCanvas.width - n * c) / 2;
    var offsetY = (nextCanvas.height - n * c) / 2;
    for (var r = 0; r < n; r++) {
      for (var cc = 0; cc < n; cc++) {
        if (s[r][cc]) {
          nctx.fillStyle = nextPiece.color;
          nctx.fillRect(offsetX + cc * c + 1, offsetY + r * c + 1, c - 2, c - 2);
        }
      }
    }
  }

  var keyActions = {
    ArrowLeft: function() { move(-1, 0); }, a: function() { move(-1, 0); }, A: function() { move(-1, 0); },
    ArrowRight: function() { move(1, 0); }, d: function() { move(1, 0); }, D: function() { move(1, 0); },
    ArrowDown: function() { move(0, 1); }, s: function() { move(0, 1); }, S: function() { move(0, 1); },
    ArrowUp: rotate, w: rotate, W: rotate
  };

  document.addEventListener('keydown', function(e) {
    if (e.key === ' ') {
      e.preventDefault();
      if (!running && !over) { start(); return; }
      hardDrop();
      return;
    }
    if (keyActions[e.key]) {
      e.preventDefault();
      if (!running && !over) start();
      keyActions[e.key]();
    }
  });

  var touchActions = {
    left: function() { move(-1, 0); },
    right: function() { move(1, 0); },
    down: function() { move(0, 1); },
    rotate: rotate
  };
  document.querySelectorAll('.tetris-controls button').forEach(function(btn) {
    btn.addEventListener('click', function() {
      if (!running && !over) start();
      touchActions[btn.getAttribute('data-act')]();
    });
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
