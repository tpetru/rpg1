<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Whack-a-Mole</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .wam-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .wam-stats span span { color: var(--accent); }
  .wam-grid { display: grid; grid-template-columns: repeat(3, 90px); grid-template-rows: repeat(3, 90px); gap: 10px; margin: 0 auto; width: max-content; }
  .wam-hole {
    width: 90px; height: 90px; border-radius: 50%;
    background: radial-gradient(circle at 50% 40%, #2a1f18 0%, #171310 70%);
    border: 3px solid #3a2a1e;
    display: flex; align-items: flex-end; justify-content: center; overflow: hidden;
    cursor: pointer;
  }
  .wam-mole { font-size: 2.4rem; transform: translateY(100%); transition: transform 0.12s ease-out; }
  .wam-hole.up .wam-mole { transform: translateY(10%); }
  .wam-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🔨 Whack-a-Mole</h1>

  <div class="card" style="text-align: center">
    <div class="wam-stats">
      <span>Score: <span id="wamScore">0</span></span>
      <span>Time: <span id="wamTime">30</span>s</span>
      <span>Best: <span id="wamBest">0</span></span>
    </div>
    <div class="game-zone"><div class="wam-grid" id="wamGrid"></div></div>
    <p class="wam-msg" id="wamMsg">Click Start, then whack the moles before they hide!</p>
    <button id="wamStart" class="btn">Start</button>
  </div>
</main>

<script>
(function() {
  var gridEl = document.getElementById('wamGrid');
  var scoreEl = document.getElementById('wamScore');
  var timeEl = document.getElementById('wamTime');
  var bestEl = document.getElementById('wamBest');
  var msgEl = document.getElementById('wamMsg');
  var startBtn = document.getElementById('wamStart');

  var best = parseInt(localStorage.getItem('whackBest') || '0', 10);
  bestEl.textContent = best;

  var HOLES = 9, DURATION = 30;
  var holes = [];
  var score, timeLeft, running, moleTimer, tickTimer, activeHole;

  for (var i = 0; i < HOLES; i++) {
    var hole = document.createElement('div');
    hole.className = 'wam-hole';
    var mole = document.createElement('div');
    mole.className = 'wam-mole';
    mole.textContent = '🧑🏾';
    hole.appendChild(mole);
    (function(idx, holeEl) {
      holeEl.addEventListener('click', function() { whack(idx); });
    })(i, hole);
    gridEl.appendChild(hole);
    holes.push(hole);
  }

  function popRandom() {
    if (activeHole !== null && activeHole !== undefined) holes[activeHole].classList.remove('up');
    activeHole = Math.floor(Math.random() * HOLES);
    holes[activeHole].classList.add('up');
    var upTime = Math.max(420, 950 - score * 10);
    moleTimer = setTimeout(function() {
      if (holes[activeHole]) holes[activeHole].classList.remove('up');
      activeHole = null;
      if (running) moleTimer = setTimeout(popRandom, 250 + Math.random() * 300);
    }, upTime);
  }

  function whack(idx) {
    if (!running) return;
    if (idx === activeHole) {
      holes[idx].classList.remove('up');
      activeHole = null;
      score++;
      scoreEl.textContent = score;
      clearTimeout(moleTimer);
      moleTimer = setTimeout(popRandom, 200 + Math.random() * 250);
    }
  }

  function start() {
    holes.forEach(function(h) { h.classList.remove('up'); });
    score = 0; timeLeft = DURATION; running = true; activeHole = null;
    scoreEl.textContent = 0;
    timeEl.textContent = DURATION;
    msgEl.textContent = 'Go!';
    startBtn.style.display = 'none';
    popRandom();
    tickTimer = setInterval(function() {
      timeLeft--;
      timeEl.textContent = timeLeft;
      if (timeLeft <= 0) end();
    }, 1000);
  }

  function end() {
    running = false;
    clearInterval(tickTimer);
    clearTimeout(moleTimer);
    holes.forEach(function(h) { h.classList.remove('up'); });
    if (score > best) {
      best = score;
      localStorage.setItem('whackBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best: ' + score + '! 🎉';
    } else {
      msgEl.textContent = "Time's up - score: " + score;
    }
    startBtn.textContent = 'Play again';
    startBtn.style.display = 'inline-block';
  }

  startBtn.addEventListener('click', start);
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
