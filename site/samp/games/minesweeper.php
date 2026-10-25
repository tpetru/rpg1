<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Minesweeper</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .ms-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .ms-stats span span { color: var(--accent); }
  .ms-grid { display: grid; grid-template-columns: repeat(9, 30px); grid-template-rows: repeat(9, 30px); gap: 2px; margin: 0 auto; width: max-content; background: var(--border); padding: 2px; border-radius: 6px; }
  .ms-cell {
    width: 30px; height: 30px;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border-radius: 3px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 0.95rem;
    cursor: pointer; user-select: none;
  }
  .ms-cell.revealed { background: #171c22; cursor: default; }
  .ms-cell.mine { background: var(--red); }
  .ms-cell[data-n="1"] { color: #4d8cff; }
  .ms-cell[data-n="2"] { color: #3ecf8e; }
  .ms-cell[data-n="3"] { color: #ff5d5d; }
  .ms-cell[data-n="4"] { color: #c874ff; }
  .ms-cell[data-n="5"] { color: #ffcf4d; }
  .ms-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>💣 Minesweeper</h1>

  <div class="card" style="text-align: center">
    <div class="ms-stats">
      <span>Mines left: <span id="msMines">10</span></span>
      <span>Time: <span id="msTime">0</span>s</span>
      <span>Best: <span id="msBest">—</span></span>
    </div>
    <div class="game-zone"><div class="ms-grid" id="msGrid"></div></div>
    <p class="ms-msg" id="msMsg">Left-click to reveal, right-click (or long-press) to flag. 9×9, 10 mines.</p>
    <button id="msRestart" class="btn">New game</button>
  </div>
</main>

<script>
(function() {
  var SIZE = 9, MINES = 10;
  var gridEl = document.getElementById('msGrid');
  var minesEl = document.getElementById('msMines');
  var timeEl = document.getElementById('msTime');
  var bestEl = document.getElementById('msBest');
  var msgEl = document.getElementById('msMsg');
  var restartBtn = document.getElementById('msRestart');

  var best = parseInt(localStorage.getItem('minesweeperBest') || '0', 10);
  bestEl.textContent = best > 0 ? best + 's' : '—';

  var board, revealedCount, flagCount, over, started, timerId, seconds, longPressTimer;

  function inBounds(r, c) { return r >= 0 && r < SIZE && c >= 0 && c < SIZE; }

  function neighbors(r, c) {
    var out = [];
    for (var dr = -1; dr <= 1; dr++) for (var dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      if (inBounds(r + dr, c + dc)) out.push([r + dr, c + dc]);
    }
    return out;
  }

  function placeMines(safeR, safeC) {
    var placed = 0;
    while (placed < MINES) {
      var r = Math.floor(Math.random() * SIZE), c = Math.floor(Math.random() * SIZE);
      if (board[r][c].mine) continue;
      if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1) continue;
      board[r][c].mine = true;
      placed++;
    }
    for (var r2 = 0; r2 < SIZE; r2++) {
      for (var c2 = 0; c2 < SIZE; c2++) {
        if (board[r2][c2].mine) continue;
        board[r2][c2].count = neighbors(r2, c2).filter(function(p) { return board[p[0]][p[1]].mine; }).length;
      }
    }
  }

  function buildBoard() {
    board = [];
    for (var r = 0; r < SIZE; r++) {
      var row = [];
      for (var c = 0; c < SIZE; c++) row.push({ mine: false, count: 0, revealed: false, flagged: false });
      board.push(row);
    }
  }

  function reset() {
    buildBoard();
    revealedCount = 0; flagCount = 0; over = false; started = false; seconds = 0;
    clearInterval(timerId);
    minesEl.textContent = MINES;
    timeEl.textContent = 0;
    msgEl.textContent = 'Left-click to reveal, right-click (or long-press) to flag. 9×9, 10 mines.';
    render();
  }

  function render() {
    gridEl.innerHTML = '';
    for (var r = 0; r < SIZE; r++) {
      for (var c = 0; c < SIZE; c++) {
        var cell = board[r][c];
        var el = document.createElement('div');
        el.className = 'ms-cell' + (cell.revealed ? ' revealed' : '');
        if (cell.revealed && cell.mine) el.classList.add('mine');
        if (cell.revealed && cell.count > 0) el.setAttribute('data-n', cell.count);
        if (cell.revealed) {
          el.textContent = cell.mine ? '💣' : (cell.count > 0 ? cell.count : '');
        } else if (cell.flagged) {
          el.textContent = '🚩';
        }
        el.addEventListener('click', (function(rr, cc) { return function() { reveal(rr, cc); }; })(r, c));
        el.addEventListener('contextmenu', (function(rr, cc) { return function(e) { e.preventDefault(); toggleFlag(rr, cc); }; })(r, c));
        el.addEventListener('touchstart', (function(rr, cc) {
          return function() {
            longPressTimer = setTimeout(function() { toggleFlag(rr, cc); }, 450);
          };
        })(r, c));
        el.addEventListener('touchend', function() { clearTimeout(longPressTimer); });
        gridEl.appendChild(el);
      }
    }
  }

  function toggleFlag(r, c) {
    if (over) return;
    var cell = board[r][c];
    if (cell.revealed) return;
    cell.flagged = !cell.flagged;
    flagCount += cell.flagged ? 1 : -1;
    minesEl.textContent = MINES - flagCount;
    render();
  }

  function floodReveal(r, c) {
    var cell = board[r][c];
    if (cell.revealed || cell.flagged) return;
    cell.revealed = true;
    revealedCount++;
    if (cell.count === 0 && !cell.mine) {
      neighbors(r, c).forEach(function(p) { floodReveal(p[0], p[1]); });
    }
  }

  function reveal(r, c) {
    if (over) return;
    var cell = board[r][c];
    if (cell.flagged || cell.revealed) return;

    if (!started) {
      started = true;
      placeMines(r, c);
      seconds = 0;
      timerId = setInterval(function() { seconds++; timeEl.textContent = seconds; }, 1000);
    }

    if (cell.mine) {
      cell.revealed = true;
      loseGame();
      return;
    }
    floodReveal(r, c);
    render();

    if (revealedCount === SIZE * SIZE - MINES) winGame();
  }

  function revealAllMines() {
    for (var r = 0; r < SIZE; r++) for (var c = 0; c < SIZE; c++) if (board[r][c].mine) board[r][c].revealed = true;
  }

  function loseGame() {
    over = true;
    clearInterval(timerId);
    revealAllMines();
    render();
    msgEl.textContent = '💥 Boom - you hit a mine. Try again!';
  }

  function winGame() {
    over = true;
    clearInterval(timerId);
    if (best === 0 || seconds < best) {
      best = seconds;
      localStorage.setItem('minesweeperBest', best);
      bestEl.textContent = best + 's';
    }
    msgEl.textContent = '🎉 Cleared in ' + seconds + 's!';
  }

  restartBtn.addEventListener('click', reset);
  gridEl.addEventListener('contextmenu', function(e) { e.preventDefault(); });

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
