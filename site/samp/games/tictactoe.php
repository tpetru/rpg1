<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Tic-Tac-Toe</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .ttt-stats { display: flex; justify-content: center; gap: 22px; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 0.95rem; }
  .ttt-stats span span { color: var(--accent); }
  .ttt-grid { display: grid; grid-template-columns: repeat(3, 84px); grid-template-rows: repeat(3, 84px); gap: 6px; margin: 0 auto; width: max-content; }
  .ttt-cell {
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    font-size: 2.4rem; font-weight: 700; cursor: pointer;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif;
  }
  .ttt-cell.x { color: var(--accent); }
  .ttt-cell.o { color: #4d8cff; }
  .ttt-cell.win { background: rgba(62,207,142,0.15); border-color: var(--green); }
  .ttt-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>❌⭕ Tic-Tac-Toe</h1>

  <div class="card" style="text-align: center">
    <div class="ttt-stats">
      <span>Wins: <span id="tttWins">0</span></span>
      <span>Losses: <span id="tttLosses">0</span></span>
      <span>Draws: <span id="tttDraws">0</span></span>
    </div>
    <div class="game-zone"><div class="ttt-grid" id="tttGrid"></div></div>
    <p class="ttt-msg" id="tttMsg">You're X. Beat the computer!</p>
    <button id="tttRestart" class="btn">New game</button>
  </div>
</main>

<script>
(function() {
  var gridEl = document.getElementById('tttGrid');
  var msgEl = document.getElementById('tttMsg');
  var restartBtn = document.getElementById('tttRestart');
  var winsEl = document.getElementById('tttWins');
  var lossesEl = document.getElementById('tttLosses');
  var drawsEl = document.getElementById('tttDraws');

  var stats = JSON.parse(localStorage.getItem('tttStats') || '{"wins":0,"losses":0,"draws":0}');
  winsEl.textContent = stats.wins;
  lossesEl.textContent = stats.losses;
  drawsEl.textContent = stats.draws;

  var LINES = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6]
  ];

  var board, over, cells;

  function reset() {
    board = ['', '', '', '', '', '', '', '', ''];
    over = false;
    msgEl.textContent = "You're X. Beat the computer!";
    render();
  }

  function render() {
    gridEl.innerHTML = '';
    cells = [];
    for (var i = 0; i < 9; i++) {
      var cell = document.createElement('div');
      cell.className = 'ttt-cell';
      if (board[i]) { cell.textContent = board[i]; cell.classList.add(board[i].toLowerCase()); }
      (function(idx) { cell.addEventListener('click', function() { playerMove(idx); }); })(i);
      gridEl.appendChild(cell);
      cells.push(cell);
    }
  }

  function checkWinner(b) {
    for (var i = 0; i < LINES.length; i++) {
      var l = LINES[i];
      if (b[l[0]] && b[l[0]] === b[l[1]] && b[l[1]] === b[l[2]]) return { winner: b[l[0]], line: l };
    }
    if (b.every(function(v) { return v; })) return { winner: 'draw' };
    return null;
  }

  function playerMove(idx) {
    if (over || board[idx]) return;
    board[idx] = 'X';
    render();
    var result = checkWinner(board);
    if (result) { endGame(result); return; }
    msgEl.textContent = "Computer's turn...";
    setTimeout(computerMove, 350);
  }

  function computerMove() {
    if (over) return;
    var move = findBestMove();
    board[move] = 'O';
    render();
    var result = checkWinner(board);
    if (result) { endGame(result); return; }
    msgEl.textContent = 'Your turn.';
  }

  function findBestMove() {
    var i;
    for (i = 0; i < 9; i++) {
      if (!board[i]) { board[i] = 'O'; if (checkWinner(board) && checkWinner(board).winner === 'O') { board[i] = ''; return i; } board[i] = ''; }
    }
    for (i = 0; i < 9; i++) {
      if (!board[i]) { board[i] = 'X'; if (checkWinner(board) && checkWinner(board).winner === 'X') { board[i] = ''; return i; } board[i] = ''; }
    }
    if (!board[4]) return 4;
    var corners = [0, 2, 6, 8].filter(function(i) { return !board[i]; });
    if (corners.length) return corners[Math.floor(Math.random() * corners.length)];
    var empties = board.map(function(v, i) { return v ? -1 : i; }).filter(function(i) { return i !== -1; });
    return empties[Math.floor(Math.random() * empties.length)];
  }

  function saveStats() { localStorage.setItem('tttStats', JSON.stringify(stats)); }

  function endGame(result) {
    over = true;
    if (result.line) result.line.forEach(function(i) { cells[i].classList.add('win'); });
    if (result.winner === 'draw') {
      stats.draws++;
      msgEl.textContent = "It's a draw!";
    } else if (result.winner === 'X') {
      stats.wins++;
      msgEl.textContent = 'You win! 🎉';
    } else {
      stats.losses++;
      msgEl.textContent = 'Computer wins.';
    }
    winsEl.textContent = stats.wins;
    lossesEl.textContent = stats.losses;
    drawsEl.textContent = stats.draws;
    saveStats();
  }

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
