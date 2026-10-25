<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Cannon</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .cannon-stats { display: flex; justify-content: space-between; margin-bottom: 14px; font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.05rem; }
  .cannon-stats span span { color: var(--accent); }
  #cannonCanvas { background: linear-gradient(180deg, #1a2230 0%, #0b0d10 85%); border: 1px solid var(--border); border-radius: 10px; max-width: 100%; display: block; margin: 0 auto; }
  .cannon-power { width: 100%; max-width: 320px; height: 10px; margin: 12px auto 0; background: var(--panel-2); border: 1px solid var(--border); border-radius: 5px; overflow: hidden; }
  .cannon-power-fill { height: 100%; width: 0%; background: linear-gradient(90deg, var(--accent), var(--accent-2)); transition: width 0.05s linear; }
  .cannon-msg { color: var(--muted); margin-top: 14px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
  .cannon-controls { margin-top: 14px; display: none; justify-content: center; gap: 10px; }
  .cannon-controls button { width: 70px; height: 44px; background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1.1rem; cursor: pointer; }
  .cannon-controls button:active { background: var(--accent); color: #0f1115; }
  @media (max-width: 480px) { .cannon-controls { display: flex; } }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>💥 Cannon</h1>

  <div class="card" style="text-align: center">
    <div class="cannon-stats">
      <span>Shot: <span id="cannonShot">1</span>/10</span>
      <span>Hits: <span id="cannonHits">0</span></span>
      <span>Best: <span id="cannonBest">0</span></span>
    </div>
    <div class="game-zone"><canvas id="cannonCanvas" width="320" height="240"></canvas></div>
    <div class="cannon-power"><div class="cannon-power-fill" id="cannonPowerFill"></div></div>
    <p class="cannon-msg" id="cannonMsg">← → or A/D to aim, hold Space (or the Fire button) to charge power, release to fire.</p>
    <button id="cannonRestart" class="btn" style="display:none">Play again</button>
    <div class="cannon-controls" aria-hidden="true">
      <button type="button" id="cannonLeftBtn">◀</button>
      <button type="button" id="cannonFireBtn">🔥</button>
      <button type="button" id="cannonRightBtn">▶</button>
    </div>
  </div>
</main>

<script>
(function() {
  var canvas = document.getElementById('cannonCanvas');
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;
  var groundY = H - 20;

  var shotEl = document.getElementById('cannonShot');
  var hitsEl = document.getElementById('cannonHits');
  var bestEl = document.getElementById('cannonBest');
  var msgEl = document.getElementById('cannonMsg');
  var restartBtn = document.getElementById('cannonRestart');
  var powerFill = document.getElementById('cannonPowerFill');

  var best = parseInt(localStorage.getItem('cannonBest') || '0', 10);
  bestEl.textContent = best;

  var GRAVITY = 0.22;
  var MAX_POWER = 100, CHARGE_RATE = 2.4, LAUNCH_K = 0.15;
  var CANNON_X = 32, CANNON_Y = groundY - 10;
  var MAX_SHOTS = 10;

  var angleDeg, power, charging, projectile, target, shot, hits, over, rafId, keys;

  function newTarget() {
    target = { x: 150 + Math.random() * (W - 190), y: groundY - 22, w: 28, h: 22 };
  }

  function reset() {
    angleDeg = 45; power = 0; charging = false; projectile = null; keys = {};
    shot = 1; hits = 0; over = false;
    shotEl.textContent = shot;
    hitsEl.textContent = 0;
    powerFill.style.width = '0%';
    msgEl.textContent = '← → or A/D to aim, hold Space (or the Fire button) to charge power, release to fire.';
    restartBtn.style.display = 'none';
    newTarget();
    cancelAnimationFrame(rafId);
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function fire() {
    if (projectile || over) return;
    var rad = angleDeg * Math.PI / 180;
    projectile = {
      x: CANNON_X + Math.cos(rad) * 20,
      y: CANNON_Y - Math.sin(rad) * 20,
      vx: Math.cos(rad) * power * LAUNCH_K,
      vy: -Math.sin(rad) * power * LAUNCH_K
    };
    power = 0;
    powerFill.style.width = '0%';
  }

  function resolveShot(hit) {
    if (hit) { hits++; hitsEl.textContent = hits; msgEl.textContent = 'Direct hit! 💥'; }
    else { msgEl.textContent = 'Missed.'; }
    projectile = null;
    if (shot >= MAX_SHOTS) {
      endGame();
      return;
    }
    shot++;
    shotEl.textContent = shot;
    newTarget();
  }

  function update() {
    if (keys.left) angleDeg = Math.min(80, angleDeg + 1.1);
    if (keys.right) angleDeg = Math.max(10, angleDeg - 1.1);

    if (charging && !projectile) {
      power = Math.min(MAX_POWER, power + CHARGE_RATE);
      powerFill.style.width = power + '%';
    }
    if (projectile) {
      projectile.vy += GRAVITY;
      projectile.x += projectile.vx;
      projectile.y += projectile.vy;

      var hit = projectile.x > target.x && projectile.x < target.x + target.w &&
                projectile.y > target.y && projectile.y < target.y + target.h;
      if (hit) { resolveShot(true); return; }
      if (projectile.y >= groundY || projectile.x > W) { resolveShot(false); return; }
    }
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a2230');
    grad.addColorStop(0.85, '#0b0d10');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    ctx.fillStyle = '#252b32';
    ctx.fillRect(0, groundY, W, H - groundY);

    ctx.save();
    ctx.translate(CANNON_X, CANNON_Y);
    ctx.rotate(-angleDeg * Math.PI / 180);
    ctx.fillStyle = '#ff6a00';
    ctx.fillRect(0, -5, 26, 10);
    ctx.restore();
    ctx.fillStyle = '#4a4f57';
    ctx.beginPath();
    ctx.arc(CANNON_X, CANNON_Y, 10, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#ff5d5d';
    ctx.fillRect(target.x, target.y, target.w, target.h);
    ctx.fillStyle = 'rgba(255,255,255,0.5)';
    ctx.fillRect(target.x, target.y + target.h / 2 - 1, target.w, 2);

    if (projectile) {
      ctx.fillStyle = '#ffd633';
      ctx.beginPath();
      ctx.arc(projectile.x, projectile.y, 5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function loop() {
    if (over) return;
    update();
    draw();
    rafId = requestAnimationFrame(loop);
  }

  function endGame() {
    over = true;
    cancelAnimationFrame(rafId);
    if (hits > best) {
      best = hits;
      localStorage.setItem('cannonBest', best);
      bestEl.textContent = best;
      msgEl.textContent = 'New best - ' + hits + '/10 hits! 🎉';
    } else {
      msgEl.textContent = 'Final score: ' + hits + '/10 hits.';
    }
    restartBtn.style.display = 'inline-block';
  }

  var aimKeyMap = {
    ArrowLeft: 'left', a: 'left', A: 'left',
    ArrowRight: 'right', d: 'right', D: 'right'
  };
  document.addEventListener('keydown', function(e) {
    if (aimKeyMap[e.key]) { e.preventDefault(); keys[aimKeyMap[e.key]] = true; }
    else if (e.key === ' ') { e.preventDefault(); if (!projectile && !over) charging = true; }
  });
  document.addEventListener('keyup', function(e) {
    if (aimKeyMap[e.key]) { e.preventDefault(); keys[aimKeyMap[e.key]] = false; }
    else if (e.key === ' ') { e.preventDefault(); if (charging) { charging = false; fire(); } }
  });

  function bindHold(btn, key) {
    btn.addEventListener('mousedown', function() { keys[key] = true; });
    btn.addEventListener('mouseup', function() { keys[key] = false; });
    btn.addEventListener('mouseleave', function() { keys[key] = false; });
    btn.addEventListener('touchstart', function(e) { e.preventDefault(); keys[key] = true; });
    btn.addEventListener('touchend', function(e) { e.preventDefault(); keys[key] = false; });
  }
  bindHold(document.getElementById('cannonLeftBtn'), 'left');
  bindHold(document.getElementById('cannonRightBtn'), 'right');
  var fireBtn = document.getElementById('cannonFireBtn');
  fireBtn.addEventListener('touchstart', function(e) { e.preventDefault(); if (!projectile && !over) charging = true; });
  fireBtn.addEventListener('touchend', function(e) { e.preventDefault(); if (charging) { charging = false; fire(); } });
  fireBtn.addEventListener('mousedown', function() { if (!projectile && !over) charging = true; });
  fireBtn.addEventListener('mouseup', function() { if (charging) { charging = false; fire(); } });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
