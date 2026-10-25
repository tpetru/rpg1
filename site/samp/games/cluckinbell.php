<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Cluckin' Bell Challenge</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .cb-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .cb-stats span span { color: var(--accent); }
  .cb-face { font-size: 4rem; margin: 6px 0 14px; transition: transform 0.08s ease; }
  .cb-bar-wrap { width: 100%; max-width: 320px; height: 22px; margin: 0 auto 14px; background: var(--panel-2); border: 1px solid var(--border); border-radius: 11px; overflow: hidden; }
  .cb-bar-fill { height: 100%; width: 0%; background: linear-gradient(90deg, var(--green), #ffcf4d 70%, var(--red)); transition: width 0.08s linear; }
  .cb-msg { color: var(--muted); margin-top: 10px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  #cbEat { font-size: 1.1rem; padding: 14px 34px; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🍗 Cluckin' Bell Challenge</h1>

  <div class="card" style="text-align: center">
    <div class="cb-stats">
      <span>Time: <span id="cbTime">15</span>s</span>
      <span>Eaten: <span id="cbCount">0</span></span>
      <span>Best: <span id="cbBest">0</span></span>
    </div>
    <div class="game-zone">
      <div style="width: 100%">
        <div class="cb-face" id="cbFace">😋</div>
        <div class="cb-bar-wrap"><div class="cb-bar-fill" id="cbFill"></div></div>
      </div>
    </div>
    <p class="cb-msg" id="cbMsg">Mash EAT (or Space) to stuff CJ full - but don't overdo it, or he bursts!</p>
    <button id="cbEat" class="btn">EAT! 🍗</button>
  </div>
</main>

<script>
(function() {
  var timeEl = document.getElementById('cbTime');
  var countEl = document.getElementById('cbCount');
  var bestEl = document.getElementById('cbBest');
  var faceEl = document.getElementById('cbFace');
  var fillEl = document.getElementById('cbFill');
  var msgEl = document.getElementById('cbMsg');
  var eatBtn = document.getElementById('cbEat');

  var best = parseInt(localStorage.getItem('cluckinBest') || '0', 10);
  bestEl.textContent = best;

  var TIME = 15, DECAY_PER_SEC = 5.5;
  var fullness, count, timeLeft, running, over, decayTimer, tickTimer;

  function updateFace() {
    var scale = 1 + fullness / 220;
    faceEl.style.transform = 'scale(' + scale.toFixed(2) + ')';
    faceEl.textContent = fullness > 90 ? '🤢' : (fullness > 60 ? '🥵' : (fullness > 25 ? '😋' : '🙂'));
    fillEl.style.width = Math.min(100, fullness) + '%';
  }

  function reset() {
    fullness = 0; count = 0; timeLeft = TIME; running = false; over = false;
    timeEl.textContent = TIME;
    countEl.textContent = 0;
    msgEl.textContent = "Mash EAT (or Space) to stuff CJ full - but don't overdo it, or he bursts!";
    eatBtn.textContent = 'EAT! 🍗';
    updateFace();
  }

  function start() {
    if (running || over) return;
    running = true;
    decayTimer = setInterval(function() {
      fullness = Math.max(0, fullness - DECAY_PER_SEC / 10);
      updateFace();
    }, 100);
    tickTimer = setInterval(function() {
      timeLeft--;
      timeEl.textContent = timeLeft;
      if (timeLeft <= 0) endGame(false);
    }, 1000);
  }

  function eat() {
    if (over) { reset(); return; }
    if (!running) start();
    fullness += 4 + Math.random() * 3.5;
    count++;
    countEl.textContent = count;
    updateFace();
    if (fullness >= 100) endGame(true);
  }

  function endGame(burst) {
    over = true; running = false;
    clearInterval(decayTimer);
    clearInterval(tickTimer);
    if (count > best) {
      best = count;
      localStorage.setItem('cluckinBest', best);
      bestEl.textContent = best;
    }
    faceEl.textContent = burst ? '🤮' : '😵';
    msgEl.textContent = burst
      ? 'CJ overate and burst! Final count: ' + count
      : "Time's up! CJ ate " + count + ' pieces.';
    eatBtn.textContent = 'Play again';
  }

  eatBtn.addEventListener('click', eat);
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ') { e.preventDefault(); eat(); }
  });

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
