<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Fishing</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .fish-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .fish-stats span span { color: var(--accent); }
  .fish-track {
    position: relative;
    width: 60px; height: 300px;
    margin: 0 auto;
    background: #0b0d10;
    border: 1px solid var(--border);
    border-radius: 8px;
    overflow: hidden;
  }
  .fish-zone { position: absolute; left: 0; right: 0; background: rgba(62,207,142,0.28); border-top: 2px solid var(--green); border-bottom: 2px solid var(--green); }
  .fish-indicator { position: absolute; left: 4px; right: 4px; height: 6px; background: #ffd633; border-radius: 3px; box-shadow: 0 0 8px rgba(255,214,51,0.7); }
  .fish-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .game-zone { height: 340px; }
  .fish-hint { color: var(--muted); font-size: 0.8rem; margin-top: 6px; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🎣 Fishing</h1>

  <div class="card" style="text-align: center">
    <div class="fish-stats">
      <span>Caught: <span id="fishScore">0</span></span>
      <span>Lives: <span id="fishLives">❤️❤️❤️</span></span>
      <span>Best: <span id="fishBest">0</span></span>
    </div>
    <div class="game-zone">
      <div class="fish-track" id="fishTrack">
        <div class="fish-zone" id="fishZone"></div>
        <div class="fish-indicator" id="fishIndicator"></div>
      </div>
    </div>
    <p class="fish-msg" id="fishMsg">Press Reel (or Space) when the bobber is in the green zone.</p>
    <button id="fishReel" class="btn">Reel! 🎣</button>
    <p class="fish-hint">3 misses and the fish get away for good.</p>
  </div>
</main>

<script>
(function() {
  var track = document.getElementById('fishTrack');
  var zoneEl = document.getElementById('fishZone');
  var indicatorEl = document.getElementById('fishIndicator');
  var scoreEl = document.getElementById('fishScore');
  var livesEl = document.getElementById('fishLives');
  var bestEl = document.getElementById('fishBest');
  var msgEl = document.getElementById('fishMsg');
  var reelBtn = document.getElementById('fishReel');

  var best = parseInt(localStorage.getItem('fishingBest') || '0', 10);
  bestEl.textContent = best;

  var TRACK_H = 300;
  var score, lives, over, t, speed, zoneTop, zoneH, rafId;

  function newRound() {
    speed = 0.045 + score * 0.006;
    zoneH = Math.max(38, 90 - score * 5);
    zoneTop = Math.random() * (TRACK_H - zoneH);
    zoneEl.style.top = zoneTop + 'px';
    zoneEl.style.height = zoneH + 'px';
  }

  function reset() {
    score = 0; lives = 3; over = false; t = 0;
    scoreEl.textContent = 0;
    livesEl.textContent = '❤️❤️❤️';
    msgEl.textContent = 'Press Reel (or Space) when the bobber is in the green zone.';
    reelBtn.textContent = 'Reel! 🎣';
    newRound();
    cancelAnimationFrame(rafId);
    tick();
  }

  function tick() {
    t += speed;
    var y = (Math.sin(t) + 1) / 2 * (TRACK_H - 6);
    indicatorEl.style.top = y + 'px';
    if (!over) rafId = requestAnimationFrame(tick);
  }

  function currentIndicatorY() {
    var y = (Math.sin(t) + 1) / 2 * (TRACK_H - 6);
    return y + 3;
  }

  function reel() {
    if (over) return;
    var y = currentIndicatorY();
    if (y >= zoneTop && y <= zoneTop + zoneH) {
      score++;
      scoreEl.textContent = score;
      msgEl.textContent = 'Caught one! 🐟';
      newRound();
    } else {
      lives--;
      livesEl.textContent = '❤️'.repeat(Math.max(0, lives)) + '🖤'.repeat(3 - Math.max(0, lives));
      msgEl.textContent = 'Missed - the fish swam off.';
      if (lives <= 0) { endGame(); return; }
      newRound();
    }
  }

  function endGame() {
    over = true;
    cancelAnimationFrame(rafId);
    if (score > best) {
      best = score;
      localStorage.setItem('fishingBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best - caught ' + score + '! 🎉';
    } else {
      msgEl.textContent = 'Out of tries - caught ' + score + '.';
    }
    reelBtn.textContent = 'Try again';
  }

  reelBtn.addEventListener('click', function() {
    if (over) { reset(); } else { reel(); }
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ') { e.preventDefault(); if (over) reset(); else reel(); }
  });

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
