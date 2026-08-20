<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — CJ Gym</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .gym-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .gym-stats span span { color: var(--accent); }
  .gym-muscle-wrap { width: 100%; max-width: 320px; height: 14px; margin: 0 auto 18px; background: var(--panel-2); border: 1px solid var(--border); border-radius: 7px; overflow: hidden; }
  .gym-muscle-fill { height: 100%; width: 0%; background: linear-gradient(90deg, var(--accent), var(--accent-2)); transition: width 0.15s ease; }
  .gym-track {
    position: relative;
    width: 100%; max-width: 320px; height: 40px;
    margin: 0 auto;
    background: #0b0d10;
    border: 1px solid var(--border);
    border-radius: 8px;
    overflow: hidden;
  }
  .gym-zone { position: absolute; top: 0; bottom: 0; background: rgba(62,207,142,0.28); border-left: 2px solid var(--green); border-right: 2px solid var(--green); }
  .gym-indicator { position: absolute; top: 4px; bottom: 4px; width: 6px; background: #ffd633; border-radius: 3px; box-shadow: 0 0 8px rgba(255,214,51,0.7); }
  .gym-msg {
    color: var(--muted); margin-top: 14px;
    height: 80px;
    display: flex; align-items: center; justify-content: center;
    line-height: 1.35;
  }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🏋️ CJ Gym</h1>

  <div class="card" style="text-align: center">
    <div class="gym-stats">
      <span>Reps: <span id="gymReps">0</span></span>
      <span>Misses: <span id="gymMisses">0</span>/3</span>
      <span>Best: <span id="gymBest">0</span></span>
    </div>
    <div class="gym-muscle-wrap"><div class="gym-muscle-fill" id="gymMuscle"></div></div>
    <div class="game-zone">
      <div class="gym-track" id="gymTrack">
        <div class="gym-zone" id="gymZone"></div>
        <div class="gym-indicator" id="gymIndicator"></div>
      </div>
    </div>
    <p class="gym-msg" id="gymMsg">Press Lift (or Space) when the bar is in the green zone. 3 misses and CJ calls it a day.</p>
    <button id="gymLift" class="btn">Lift! 🏋️</button>
  </div>
</main>

<script>
(function() {
  var track = document.getElementById('gymTrack');
  var zoneEl = document.getElementById('gymZone');
  var indicatorEl = document.getElementById('gymIndicator');
  var repsEl = document.getElementById('gymReps');
  var missesEl = document.getElementById('gymMisses');
  var bestEl = document.getElementById('gymBest');
  var muscleEl = document.getElementById('gymMuscle');
  var msgEl = document.getElementById('gymMsg');
  var liftBtn = document.getElementById('gymLift');

  var best = parseInt(localStorage.getItem('gymBest') || '0', 10);
  bestEl.textContent = best;

  var TRACK_W = 320;
  var reps, misses, muscle, over, t, speed, zoneLeft, zoneW, rafId;

  function newRound() {
    speed = 0.05 + reps * 0.005;
    zoneW = Math.max(34, 80 - reps * 4);
    zoneLeft = Math.random() * (TRACK_W - zoneW);
    zoneEl.style.left = zoneLeft + 'px';
    zoneEl.style.width = zoneW + 'px';
  }

  function reset() {
    reps = 0; misses = 0; muscle = 0; over = false; t = 0;
    repsEl.textContent = 0;
    missesEl.textContent = 0;
    muscleEl.style.width = '0%';
    msgEl.textContent = 'Press Lift (or Space) when the bar is in the green zone. 3 misses and CJ calls it a day.';
    liftBtn.textContent = 'Lift! 🏋️';
    newRound();
    cancelAnimationFrame(rafId);
    tick();
  }

  function currentX() {
    return (Math.sin(t) + 1) / 2 * (TRACK_W - 6);
  }

  function tick() {
    t += speed;
    var x = currentX();
    indicatorEl.style.left = x + 'px';
    if (!over) rafId = requestAnimationFrame(tick);
  }

  function lift() {
    if (over) { reset(); return; }
    var x = currentX() + 3;
    if (x >= zoneLeft && x <= zoneLeft + zoneW) {
      reps++;
      repsEl.textContent = reps;
      muscle = Math.min(100, muscle + 6);
      muscleEl.style.width = muscle + '%';
      msgEl.textContent = 'Nice rep! 💪';
      newRound();
    } else {
      misses++;
      missesEl.textContent = misses;
      msgEl.textContent = 'Bad form - missed the zone.';
      if (misses >= 3) { endGame(); return; }
      newRound();
    }
  }

  function endGame() {
    over = true;
    cancelAnimationFrame(rafId);
    if (reps > best) {
      best = reps;
      localStorage.setItem('gymBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best - ' + reps + ' reps! 🎉';
    } else {
      msgEl.textContent = "That's it for today - " + reps + ' reps.';
    }
    liftBtn.textContent = 'Try again';
  }

  liftBtn.addEventListener('click', lift);
  document.addEventListener('keydown', function(e) {
    if (e.key === ' ') { e.preventDefault(); lift(); }
  });

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
