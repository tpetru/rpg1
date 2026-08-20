<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — 2048</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .g2048-stats {
    display: flex; justify-content: space-between;
    margin-bottom: 14px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem;
  }
  .g2048-stats span span { color: var(--accent); }
  .g2048-board {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
    background: #0b0d10;
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 10px;
    width: 100%;
    max-width: 400px;
    margin: 0 auto;
    touch-action: none;
    user-select: none;
  }
  .g2048-cell {
    aspect-ratio: 1 / 1;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2);
    border-radius: 6px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700;
    font-size: 1.5rem;
    transition: background 0.12s ease, color 0.12s ease;
  }
  .g2048-cell[data-big="1"] { font-size: 1.15rem; }
  .g2048-cell[data-big="2"] { font-size: 0.95rem; }
  .g2048-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🔢 2048</h1>

  <div class="card" style="text-align: center">
    <div class="g2048-stats">
      <span>Score: <span id="g2048Score">0</span></span>
      <span>Best: <span id="g2048Best">0</span></span>
    </div>
    <div class="game-zone"><div class="g2048-board" id="g2048Board"></div></div>
    <p class="g2048-msg" id="g2048Msg">Use arrow keys, WASD, or swipe to combine tiles and reach 2048.</p>
    <button id="g2048Restart" class="btn" style="display:none">Play again</button>
  </div>
</main>

<script>
(function() {
  var size = 4;
  var board, score, best, won, over;

  var boardEl = document.getElementById('g2048Board');
  var scoreEl = document.getElementById('g2048Score');
  var bestEl = document.getElementById('g2048Best');
  var msgEl = document.getElementById('g2048Msg');
  var restartBtn = document.getElementById('g2048Restart');

  best = parseInt(localStorage.getItem('g2048Best') || '0', 10);
  bestEl.textContent = best;

  var tileColors = {
    2: ['#3a3f47', '#f2f2f2'], 4: ['#4a4038', '#f2f2f2'],
    8: ['#ff9c4d', '#0f1115'], 16: ['#ff8533', '#0f1115'],
    32: ['#ff6a00', '#fff'], 64: ['#ff5500', '#fff'],
    128: ['#ffcf4d', '#0f1115'], 256: ['#ffd633', '#0f1115'],
    512: ['#ffdb1a', '#0f1115'], 1024: ['#ffe000', '#0f1115'],
    2048: ['#fff200', '#0f1115']
  };

  function emptyBoard() {
    var b = [];
    for (var i = 0; i < size; i++) b.push([0, 0, 0, 0]);
    return b;
  }

  function addRandomTile() {
    var empties = [];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] === 0) empties.push([r, c]);
      }
    }
    if (!empties.length) return;
    var pick = empties[Math.floor(Math.random() * empties.length)];
    board[pick[0]][pick[1]] = Math.random() < 0.9 ? 2 : 4;
  }

  function reset() {
    board = emptyBoard();
    score = 0;
    won = false;
    over = false;
    scoreEl.textContent = 0;
    msgEl.textContent = 'Use arrow keys, WASD, or swipe to combine tiles and reach 2048.';
    restartBtn.style.display = 'none';
    addRandomTile();
    addRandomTile();
    render();
  }

  function render() {
    boardEl.innerHTML = '';
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        var v = board[r][c];
        var cell = document.createElement('div');
        cell.className = 'g2048-cell';
        if (v) {
          cell.textContent = v;
          var colors = tileColors[v] || ['#7a1fa2', '#fff'];
          cell.style.background = colors[0];
          cell.style.color = colors[1];
          if (v >= 1000) cell.setAttribute('data-big', '2');
          else if (v >= 100) cell.setAttribute('data-big', '1');
        }
        boardEl.appendChild(cell);
      }
    }
  }

  function slideRowLeft(row) {
    var vals = row.filter(function(v) { return v !== 0; });
    var gained = 0;
    for (var i = 0; i < vals.length - 1; i++) {
      if (vals[i] === vals[i + 1]) {
        vals[i] *= 2;
        gained += vals[i];
        vals.splice(i + 1, 1);
      }
    }
    while (vals.length < size) vals.push(0);
    var moved = false;
    for (var j = 0; j < size; j++) if (vals[j] !== row[j]) moved = true;
    return { row: vals, gained: gained, moved: moved };
  }

  function transpose(b) {
    var n = emptyBoard();
    for (var r = 0; r < size; r++) for (var c = 0; c < size; c++) n[c][r] = b[r][c];
    return n;
  }

  function reverseRows(b) {
    return b.map(function(row) { return row.slice().reverse(); });
  }

  function applyLeft(b) {
    var moved = false, gained = 0;
    var newB = b.map(function(row) {
      var res = slideRowLeft(row);
      if (res.moved) moved = true;
      gained += res.gained;
      return res.row;
    });
    return { board: newB, moved: moved, gained: gained };
  }

  function canMove() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] === 0) return true;
        if (c < size - 1 && board[r][c] === board[r][c + 1]) return true;
        if (r < size - 1 && board[r][c] === board[r + 1][c]) return true;
      }
    }
    return false;
  }

  function move(dir) {
    if (over) return;
    var result;
    if (dir === 'left') {
      result = applyLeft(board);
    } else if (dir === 'right') {
      result = applyLeft(reverseRows(board));
      result.board = reverseRows(result.board);
    } else if (dir === 'up') {
      result = applyLeft(transpose(board));
      result.board = transpose(result.board);
    } else {
      result = applyLeft(reverseRows(transpose(board)));
      result.board = transpose(reverseRows(result.board));
    }

    if (!result.moved) return;

    board = result.board;
    score += result.gained;
    scoreEl.textContent = score;
    if (score > best) {
      best = score;
      localStorage.setItem('g2048Best', best);
      bestEl.textContent = best;
    }
    addRandomTile();
    render();

    if (!won && board.some(function(row) { return row.indexOf(2048) !== -1; })) {
      won = true;
      msgEl.textContent = '2048 reached! 🎉 Keep going for a higher score, or restart.';
    } else if (!canMove()) {
      over = true;
      msgEl.textContent = 'Game over - final score: ' + score;
      restartBtn.style.display = 'inline-block';
    }
  }

  var keyMap = {
    ArrowUp: 'up', w: 'up', W: 'up',
    ArrowDown: 'down', s: 'down', S: 'down',
    ArrowLeft: 'left', a: 'left', A: 'left',
    ArrowRight: 'right', d: 'right', D: 'right'
  };
  document.addEventListener('keydown', function(e) {
    if (keyMap[e.key]) {
      e.preventDefault();
      move(keyMap[e.key]);
    }
  });

  var touchStartX = 0, touchStartY = 0;
  boardEl.addEventListener('touchstart', function(e) {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
  });
  boardEl.addEventListener('touchend', function(e) {
    var dx = e.changedTouches[0].clientX - touchStartX;
    var dy = e.changedTouches[0].clientY - touchStartY;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 24) return;
    if (Math.abs(dx) > Math.abs(dy)) {
      move(dx > 0 ? 'right' : 'left');
    } else {
      move(dy > 0 ? 'down' : 'up');
    }
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
