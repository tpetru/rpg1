<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — GTA Wordle</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  @keyframes wordle-shake {
    10%, 90% { transform: translateX(-1px); }
    20%, 80% { transform: translateX(2px); }
    30%, 50%, 70% { transform: translateX(-4px); }
    40%, 60% { transform: translateX(4px); }
  }
  @keyframes wordle-pop {
    0% { transform: scale(1); }
    50% { transform: scale(1.08); }
    100% { transform: scale(1); }
  }
  .wordle-grid { display: flex; flex-direction: column; gap: 6px; margin: 0 auto 18px; width: max-content; }
  .wordle-row { display: flex; gap: 6px; }
  .wordle-row.shake { animation: wordle-shake 0.4s; }
  .wordle-cell {
    width: 50px; height: 50px;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border: 2px solid var(--border); border-radius: 6px;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif; font-weight: 700; font-size: 1.5rem;
    color: var(--text);
    text-transform: uppercase;
  }
  .wordle-cell.filled { border-color: #4a4f57; }
  .wordle-cell.pop { animation: wordle-pop 0.15s ease; }
  .wordle-cell.correct { background: var(--green); border-color: var(--green); color: #0f1115; }
  .wordle-cell.present { background: #ffcf4d; border-color: #ffcf4d; color: #0f1115; }
  .wordle-cell.absent { background: #2a2f37; border-color: #2a2f37; color: var(--muted); }

  .wordle-kb { display: flex; flex-direction: column; gap: 6px; align-items: center; }
  .wordle-kb-row { display: flex; gap: 5px; }
  .wordle-key {
    min-width: 30px; height: 44px; padding: 0 6px;
    display: flex; align-items: center; justify-content: center;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 6px;
    color: var(--text); font-weight: 700; font-size: 0.82rem; cursor: pointer;
    font-family: 'Rajdhani', 'Segoe UI', sans-serif;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .wordle-key.wide { min-width: 52px; font-size: 0.72rem; }
  .wordle-key:active { transform: translateY(1px); }
  .wordle-key.correct { background: var(--green); border-color: var(--green); color: #0f1115; }
  .wordle-key.present { background: #ffcf4d; border-color: #ffcf4d; color: #0f1115; }
  .wordle-key.absent { background: #2a2f37; border-color: #2a2f37; color: var(--muted); }
  .wordle-msg { color: var(--muted); margin: 4px 0 16px; height: 80px; display: flex; align-items: center; justify-content: center; line-height: 1.35; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main style="max-width: 480px">
  <p><a href="index.php" class="game-back"><span>&larr;</span> Games</a></p>
  <h1>🔤 GTA Wordle</h1>

  <div class="card" style="text-align: center">
    <p class="wordle-msg" id="wordleMsg">Guess the 5-letter GTA San Andreas word in 6 tries.</p>
    <div class="game-zone"><div class="wordle-grid" id="wordleGrid"></div></div>
    <div class="wordle-kb" id="wordleKb"></div>
    <button id="wordleRestart" class="btn" style="display:none; margin-top:16px">New word</button>
  </div>
</main>

<script>
(function() {
  var WORDS = [
    'GRAND','THEFT','STEAL','AUTOS','GROVE','SWEET','RYDER','VAGOS','CESAR','KENDL',
    'SMOKE','TRUTH','MAFIA','BADGE','ARMOR','MEDIC','TURFS','FARMS','RADIO','MONEY',
    'TAXIS','PILOT','BOATS','ROADS','HOUSE','PRESS','STORE','SHOPS','BANKS','GUARD',
    'TIRED','PHONE','WATCH','DOZER','TRUCK','TRAIN','PLANE','FIRES','CRASH','CHASE'
  ];
  var WORD_LEN = 5, MAX_TRIES = 6;

  var gridEl = document.getElementById('wordleGrid');
  var kbEl = document.getElementById('wordleKb');
  var msgEl = document.getElementById('wordleMsg');
  var restartBtn = document.getElementById('wordleRestart');

  var secret, current, row, over, keyStatus;

  function buildGrid() {
    gridEl.innerHTML = '';
    for (var r = 0; r < MAX_TRIES; r++) {
      var rowEl = document.createElement('div');
      rowEl.className = 'wordle-row';
      rowEl.id = 'wrow-' + r;
      for (var c = 0; c < WORD_LEN; c++) {
        var cell = document.createElement('div');
        cell.className = 'wordle-cell';
        cell.id = 'wcell-' + r + '-' + c;
        rowEl.appendChild(cell);
      }
      gridEl.appendChild(rowEl);
    }
  }

  var KB_ROWS = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  function buildKeyboard() {
    kbEl.innerHTML = '';
    KB_ROWS.forEach(function(rowStr, idx) {
      var rowEl = document.createElement('div');
      rowEl.className = 'wordle-kb-row';
      if (idx === 2) rowEl.appendChild(makeKey('ENTER', 'wide'));
      rowStr.split('').forEach(function(ch) { rowEl.appendChild(makeKey(ch, '')); });
      if (idx === 2) rowEl.appendChild(makeKey('BACK', 'wide'));
      kbEl.appendChild(rowEl);
    });
  }

  function makeKey(key, extraClass) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'wordle-key' + (extraClass ? ' ' + extraClass : '');
    btn.id = 'wkey-' + key;
    btn.textContent = key === 'ENTER' ? 'ENTER' : (key === 'BACK' ? '⌫' : key);
    btn.addEventListener('click', function() { handleKey(key); });
    return btn;
  }

  function renderCurrentRow() {
    for (var c = 0; c < WORD_LEN; c++) {
      var cell = document.getElementById('wcell-' + row + '-' + c);
      var ch = current[c] || '';
      cell.textContent = ch;
      cell.classList.toggle('filled', !!ch);
    }
  }

  function shakeRow() {
    var rowEl = document.getElementById('wrow-' + row);
    rowEl.classList.remove('shake');
    void rowEl.offsetWidth;
    rowEl.classList.add('shake');
  }

  function evaluate(guess) {
    var secretArr = secret.split('');
    var guessArr = guess.split('');
    var statuses = new Array(WORD_LEN).fill('absent');
    var used = new Array(WORD_LEN).fill(false);
    for (var i = 0; i < WORD_LEN; i++) {
      if (guessArr[i] === secretArr[i]) { statuses[i] = 'correct'; used[i] = true; }
    }
    for (var i = 0; i < WORD_LEN; i++) {
      if (statuses[i] === 'correct') continue;
      for (var j = 0; j < WORD_LEN; j++) {
        if (!used[j] && secretArr[j] === guessArr[i]) { statuses[i] = 'present'; used[j] = true; break; }
      }
    }
    return statuses;
  }

  var rank = { absent: 0, present: 1, correct: 2 };

  function colorRow(statuses) {
    for (var c = 0; c < WORD_LEN; c++) {
      var cell = document.getElementById('wcell-' + row + '-' + c);
      cell.classList.add(statuses[c]);
      (function(cellEl, delay) {
        setTimeout(function() {
          cellEl.classList.add('pop');
          setTimeout(function() { cellEl.classList.remove('pop'); }, 150);
        }, delay);
      })(cell, c * 60);

      var ch = current[c];
      var key = document.getElementById('wkey-' + ch);
      if (key && rank[statuses[c]] > (rank[keyStatus[ch]] || -1)) {
        keyStatus[ch] = statuses[c];
        key.classList.remove('correct', 'present', 'absent');
        key.classList.add(statuses[c]);
      }
    }
  }

  function handleKey(key) {
    if (over) return;
    if (key === 'ENTER') {
      if (current.length !== WORD_LEN) { shakeRow(); return; }
      submitGuess();
    } else if (key === 'BACK') {
      current = current.slice(0, -1);
      renderCurrentRow();
    } else if (/^[A-Z]$/.test(key) && current.length < WORD_LEN) {
      current += key;
      renderCurrentRow();
    }
  }

  function submitGuess() {
    var statuses = evaluate(current);
    colorRow(statuses);
    if (current === secret) {
      over = true;
      msgEl.textContent = 'You got it! 🎉 (' + (row + 1) + '/' + MAX_TRIES + ')';
      restartBtn.style.display = 'inline-block';
    } else if (row + 1 >= MAX_TRIES) {
      over = true;
      msgEl.textContent = 'Out of tries - the word was ' + secret + '.';
      restartBtn.style.display = 'inline-block';
    } else {
      row++;
      current = '';
      msgEl.textContent = 'Guess the 5-letter GTA San Andreas word in 6 tries.';
    }
  }

  function reset() {
    secret = WORDS[Math.floor(Math.random() * WORDS.length)];
    current = '';
    row = 0;
    over = false;
    keyStatus = {};
    buildGrid();
    buildKeyboard();
    msgEl.textContent = 'Guess the 5-letter GTA San Andreas word in 6 tries.';
    restartBtn.style.display = 'none';
  }

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { handleKey('ENTER'); return; }
    if (e.key === 'Backspace') { handleKey('BACK'); return; }
    var k = e.key.toUpperCase();
    if (/^[A-Z]$/.test(k)) handleKey(k);
  });

  restartBtn.addEventListener('click', reset);

  reset();
})();
</script>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
