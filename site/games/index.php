<?php
session_start();

// Add future games here - each entry renders as one tile below. Nothing else needs to change.
$games = [
    ['slug' => 'snake', 'icon' => '🐍', 'name' => 'Snake', 'desc' => "The classic - eat, grow, don't hit the walls or yourself."],
    ['slug' => '2048', 'icon' => '🔢', 'name' => '2048', 'desc' => 'Slide and combine matching tiles to reach the 2048 tile.'],
    ['slug' => 'tetris', 'icon' => '🧱', 'name' => 'Tetris', 'desc' => 'Stack falling blocks, clear lines, don\'t top out.'],
    ['slug' => 'flappy', 'icon' => '🧑🏾', 'name' => 'Flappy', 'desc' => 'Tap to flap and squeeze through the pipes.'],
    ['slug' => 'runner', 'icon' => '🏃', 'name' => 'CJ Runner', 'desc' => 'Jump CJ over obstacles through the streets of Los Santos.'],
    ['slug' => 'wordle', 'icon' => '🔤', 'name' => 'GTA Wordle', 'desc' => 'Guess the 5-letter GTA San Andreas word in 6 tries.'],
    ['slug' => 'traffic', 'icon' => '🚗', 'name' => 'Traffic', 'desc' => 'Switch lanes and dodge oncoming traffic for as long as you can.'],
    ['slug' => 'breakout', 'icon' => '🧨', 'name' => 'Breakout', 'desc' => 'Bounce the ball, break every brick, keep your 3 lives.'],
    ['slug' => 'minesweeper', 'icon' => '💣', 'name' => 'Minesweeper', 'desc' => 'Clear the 9×9 grid without detonating any of the 10 mines.'],
    ['slug' => 'whackamole', 'icon' => '🔨', 'name' => 'Whack-a-Mole', 'desc' => 'Whack as many moles as you can before the 30-second timer runs out.'],
    ['slug' => 'tictactoe', 'icon' => '❌', 'name' => 'Tic-Tac-Toe', 'desc' => 'Classic X vs O against the computer.'],
    ['slug' => 'memory', 'icon' => '🃏', 'name' => 'Memory', 'desc' => 'Flip cards, find all 8 matching pairs in as few moves as possible.'],
    ['slug' => 'basketball', 'icon' => '🏀', 'name' => 'Basketball', 'desc' => 'Drag to aim and shoot hoops before the 45-second clock runs out.'],
    ['slug' => 'fishing', 'icon' => '🎣', 'name' => 'Fishing', 'desc' => 'Time your reel to the bobber - 3 misses and the fish get away.'],
    ['slug' => 'parking', 'icon' => '🅿️', 'name' => 'Parking', 'desc' => 'Steer around obstacles and park in the marked spot before time runs out.'],
    ['slug' => 'cannon', 'icon' => '💥', 'name' => 'Cannon', 'desc' => 'Aim and charge your shot to hit the target - 10 shots, most hits wins.'],
    ['slug' => 'doodlejump', 'icon' => '⬆️', 'name' => 'CJ Jump', 'desc' => 'Bounce CJ from platform to platform - how high can you climb?'],
    ['slug' => 'cluckinbell', 'icon' => '🍗', 'name' => "Cluckin' Bell Challenge", 'desc' => "Mash to stuff CJ full at Cluckin' Bell - don't let him burst."],
    ['slug' => 'gym', 'icon' => '🏋️', 'name' => 'CJ Gym', 'desc' => 'Time your lifts to the zone and build CJ up rep by rep.'],
    ['slug' => 'spaceinvaders', 'icon' => '👾', 'name' => 'Space Invaders', 'desc' => 'Shoot down the descending alien waves before they reach you.'],
    ['slug' => 'frogger', 'icon' => '🚦', 'name' => 'Frogger', 'desc' => 'Hop across traffic and ride the logs to reach all 4 landing pads.'],
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos | RPG — Games</title>
<link rel="icon" type="image/png" href="/ucp/assets/img/favicon.ico">
<link rel="stylesheet" href="/ucp/assets/css/style.css?v=<?= filemtime(__DIR__ . '/../ucp/assets/css/style.css') ?>">
<style>
  .games-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 18px;
  }
  .game-tile {
    display: flex; flex-direction: column; align-items: center; text-align: center;
    gap: 8px;
    background: var(--panel);
    border: 1px solid var(--border);
    border-radius: 14px;
    padding: 28px 20px;
    color: var(--text);
    text-decoration: none;
    transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1), border-color 0.25s ease, box-shadow 0.25s ease;
  }
  .game-tile:hover {
    text-decoration: none;
    transform: translateY(-4px);
    border-color: var(--accent);
    box-shadow: 0 14px 30px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,106,0,0.1);
  }
  .game-tile .game-icon { font-size: 2.6rem; }
  .game-tile h2 { margin: 4px 0 0; font-size: 1.1rem; color: #fff; font-family: 'Rajdhani', 'Segoe UI', sans-serif; }
  .game-tile p { margin: 0; color: var(--muted); font-size: 0.85rem; line-height: 1.5; }
</style>
</head>
<body>

<?php $publicHeaderNav = false; include __DIR__ . '/../includes/header-public.php'; ?>


<main>
  <h1>🎮 Games</h1>
  <p style="color:var(--muted)">A few web-based mini-games to take a break with - just for fun, no accounts or rewards involved. More coming soon.</p>

  <div class="games-grid">
    <?php foreach ($games as $game): ?>
    <a class="game-tile" href="<?= htmlspecialchars($game['slug'], ENT_QUOTES, 'UTF-8') ?>.php">
      <div class="game-icon"><?= $game['icon'] ?></div>
      <h2><?= htmlspecialchars($game['name'], ENT_QUOTES, 'UTF-8') ?></h2>
      <p><?= htmlspecialchars($game['desc'], ENT_QUOTES, 'UTF-8') ?></p>
    </a>
    <?php endforeach; ?>
  </div>
</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
