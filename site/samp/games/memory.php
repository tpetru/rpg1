<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Memory</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .mem-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .mem-stats span span { color: var(--accent); }
  .mem-grid { display: grid; grid-template-columns: repeat(4, 70px); grid-template-rows: repeat(4, 70px); gap: 8px; margin: 0 auto; width: max-content; }
  .mem-card {
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    font-size: 1.8rem; cursor: pointer;
  }
  .mem-card.flipped, .mem-card.matched { background: linear-gradient(160deg, var(--panel) 0%, var(--panel-2) 100%); border-color: var(--accent); }
  .mem-card.matched { opacity: 0.55; cursor: default; }
  .mem-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🃏 Memory</h1>

  <div class="card" style="text-align: center">
    <div class="mem-stats">
      <span>Moves: <span id="memMoves">0</span></span>
      <span>Best: <span id="memBest">—</span></span>
    </div>
    <div class="game-zone"><div class="mem-grid" id="memGrid"></div></div>
    <p class="mem-msg" id="memMsg">Find all 8 matching pairs.</p>
    <button id="memRestart" class="btn">New game</button>
  </div>
</main>

<script>
(function() {
  var ICONS = ['🚗', '🔫', '💰', '🏠', '🌴', '🚁', '🛥️', '🏍️'];
  var gridEl = document.getElementById('memGrid');
  var movesEl = document.getElementById('memMoves');
  var bestEl = document.getElementById('memBest');
  var msgEl = document.getElementById('memMsg');
  var restartBtn = document.getElementById('memRestart');

  var best = parseInt(localStorage.getItem('memoryBest') || '0', 10);
  bestEl.textContent = best > 0 ? best : '—';

  var cards, flipped, matchedCount, moves, busy;

  function shuffle(arr) {
    for (var i = arr.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
    }
    return arr;
  }

  function reset() {
    var deck = shuffle(ICONS.concat(ICONS));
    cards = deck.map(function(icon) { return { icon: icon, flipped: false, matched: false }; });
    flipped = [];
    matchedCount = 0;
    moves = 0;
    busy = false;
    movesEl.textContent = 0;
    msgEl.textContent = 'Find all 8 matching pairs.';
    render();
  }

  function render() {
    gridEl.innerHTML = '';
    cards.forEach(function(c, idx) {
      var el = document.createElement('div');
      el.className = 'mem-card' + (c.matched ? ' matched' : (c.flipped ? ' flipped' : ''));
      el.textContent = (c.flipped || c.matched) ? c.icon : '❔';
      el.addEventListener('click', function() { flipCard(idx); });
      gridEl.appendChild(el);
    });
  }

  function flipCard(idx) {
    if (busy) return;
    var c = cards[idx];
    if (c.flipped || c.matched) return;
    c.flipped = true;
    flipped.push(idx);
    render();

    if (flipped.length === 2) {
      moves++;
      movesEl.textContent = moves;
      busy = true;
      var a = cards[flipped[0]], b = cards[flipped[1]];
      if (a.icon === b.icon) {
        a.matched = true; b.matched = true;
        matchedCount++;
        flipped = [];
        busy = false;
        if (matchedCount === ICONS.length) win();
        render();
      } else {
        setTimeout(function() {
          a.flipped = false; b.flipped = false;
          flipped = [];
          busy = false;
          render();
        }, 700);
      }
    }
  }

  function win() {
    if (best === 0 || moves < best) {
      best = moves;
      localStorage.setItem('memoryBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best - solved in ' + moves + ' moves! 🎉';
    } else {
      msgEl.textContent = 'Solved in ' + moves + ' moves! 🎉';
    }
  }

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
