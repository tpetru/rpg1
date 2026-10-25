<?php
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/functions.php';
require_once __DIR__ . '/../includes/lang.php';
ucp_require_login();
?>
<!DOCTYPE html>
<html lang="<?= site_lang_current() ?>">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia LosSantos | RPG — How To</title>
<link rel="icon" type="image/png" href="<?= UCP_BASE ?>/assets/img/favicon.ico">
<link rel="stylesheet" href="assets/css/style.css?v=<?= filemtime(__DIR__ . '/assets/css/style.css') ?>">
<style>
  html { scroll-behavior: smooth; }
  body { line-height: 1.65; }

  header.hero {
    padding: 40px 24px 30px;
    text-align: center;
    background: radial-gradient(ellipse at top, #1a1410 0%, #0b0d10 70%);
    border-bottom: 1px solid var(--border);
  }
  header.hero h1 {
    margin: 0 0 10px;
    font-size: 2.1rem;
    background: linear-gradient(90deg, var(--accent), var(--accent-2));
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }
  header.hero p { margin: 0 auto; max-width: 640px; color: var(--muted); font-size: 1rem; }

  nav.toc {
    position: sticky; top: var(--topbar-h); z-index: 90;
    display: flex; flex-wrap: wrap; gap: 6px;
    justify-content: center;
    padding: 12px 16px;
    background: rgba(11,13,16,0.94);
    backdrop-filter: blur(6px);
    border-bottom: 1px solid var(--border);
  }
  nav.toc a {
    color: var(--text);
    padding: 5px 11px;
    border-radius: 999px;
    font-size: 0.82rem;
    background: var(--panel);
    border: 1px solid var(--border);
  }
  nav.toc a:hover { color: var(--accent); border-color: var(--accent-soft); text-decoration: none; }

  main { max-width: 1400px; margin: 0 auto; padding: 36px 24px 100px; }

  section { margin-bottom: 46px; scroll-margin-top: 60px; }
  section h2 { font-size: 1.5rem; margin: 0 0 4px; color: #fff; }
  section .subtitle { color: var(--muted); margin: 0 0 16px; font-size: 0.92rem; }

  .card {
    background: var(--panel);
    border: 1px solid rgba(232,162,104,0.35);
    border-radius: 12px;
    padding: 18px 20px;
    margin: 12px 0;
  }
  .card h3 { margin: 0 0 8px; font-size: 1.05rem; color: var(--accent-2); }
  .card h4 { margin: 14px 0 6px; font-size: 0.92rem; color: var(--accent-2); text-transform: uppercase; letter-spacing: 0.4px; }
  .card p { margin: 6px 0; }
  .card ul { margin: 6px 0; padding-left: 20px; }
  .card li { margin: 4px 0; }

  code {
    background: #11141b;
    border: 1px solid var(--border);
    border-radius: 5px;
    padding: 1px 7px;
    font-family: "Cascadia Code", Consolas, monospace;
    font-size: 0.9em;
    color: var(--green);
    white-space: nowrap;
  }
  .num { color: var(--accent-2); font-weight: 600; }
  .warn { color: var(--red); }
  .ct { color: #6495ED; }
  .t { color: #FF6347; }

  .note {
    border-left: 3px solid var(--accent-soft);
    background: rgba(255,133,51,0.06);
    padding: 10px 16px;
    border-radius: 0 10px 10px 0;
    margin: 12px 0;
    font-size: 0.92rem;
  }

  .subtopic-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  @media (max-width: 700px) { .subtopic-grid { grid-template-columns: 1fr; } }

  footer { text-align: center; padding: 30px; color: var(--muted); font-size: 0.82rem; border-top: 1px solid var(--border); }
</style>
</head>
<body>

<?php include __DIR__ . '/../includes/header.php'; ?>

<header class="hero">
  <h1>📖 <?= t('How To Guide') ?></h1>
  <p><?= t("Everything from the in-game /howto command, in one place. Each section matches a") ?> <code>/howto [subject]</code> <?= t('topic.') ?></p>
</header>

<nav class="toc">
  <a href="#jobs"><?= t('Jobs') ?></a>
  <a href="#factions"><?= t('Factions') ?></a>
  <a href="#vehicles"><?= t('Vehicles') ?></a>
  <a href="#business"><?= t('Business') ?></a>
  <a href="#house"><?= t('House') ?></a>
  <a href="#hotel"><?= t('Hotel') ?></a>
  <a href="#billboards"><?= t('Billboards') ?></a>
  <a href="#games"><?= t('Games') ?></a>
  <a href="#caravan"><?= t('Caravan') ?></a>
  <a href="#licence"><?= t('Licence') ?></a>
  <a href="#farm"><?= t('Farm') ?></a>
  <a href="#forest"><?= t('Forest') ?></a>
  <a href="#rob"><?= t('Rob') ?></a>
  <a href="#smuggle"><?= t('Smuggle') ?></a>
  <a href="#skins"><?= t('Skins') ?></a>
  <a href="#casino"><?= t('Casino') ?></a>
  <a href="#religion"><?= t('Religion') ?></a>
</nav>

<main>

<section id="jobs">
  <h2>💼 <?= t('Jobs') ?> — <code>/howto job</code></h2>
  <p class="subtitle"><?= t('Base command:') ?> <code>/howto job [1-12]</code> <?= t('for a specific job') ?></p>
  <div class="card">
    <p><?= t('Jobs let you earn money doing deliveries.') ?></p>
    <ul>
      <li><code>/jobs</code> — <?= t('list all jobs') ?></li>
      <li><code>/getjob [id or name]</code> — <?= t('take a job (at the Job Center in City Hall)') ?></li>
      <li><code>/job</code> — <?= t('start working (be in your job vehicle)') ?></li>
      <li><code>/stopwork</code> — <?= t('stop working') ?></li>
      <li><code>/joblist</code> — <?= t('see job vehicle locations (admin teleport)') ?></li>
    </ul>
    <p><?= t('Most jobs: drive to the LOAD point, make 2 deliveries (UNLOAD), then return to load. Follow the checkpoints.') ?></p>
  </div>

  <div class="subtopic-grid">
    <div class="card">
      <h3>1 — <?= t('Glovo Delivery') ?></h3>
      <p><?= t('Food courier.') ?> <?= t('Take it with') ?> <code>/getjob 1</code>. <?= t('Get in your job bike/car (see') ?> <code>/joblist</code>), <?= t('then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t('Drive to the marked restaurant to load, deliver to 2 houses, then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$100</span> + <span class="num">$2</span> <?= t('per distance unit to the house, per delivery.') ?></p>
      <p><code>/getjob 1</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>2 — <?= t('Cement Truck Driver') ?></h3>
      <p><?= t('Haul cement.') ?> <?= t('Take it with') ?> <code>/getjob 2</code>. <?= t('Get in a cement truck, then') ?> <code>/job</code>.</p>
      <p><?= t('Load at the marked plant, unload at 2 sites, then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$2.000</span> + <span class="num">$1</span> <?= t('per distance unit to the site, per delivery.') ?></p>
      <p><code>/getjob 2</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>3 — <?= t('Gun Delivery') ?></h3>
      <p><?= t('Deliver weapons.') ?> <?= t('Take it with') ?> <code>/getjob 3</code>. <?= t('Get in the job vehicle, then') ?> <code>/job</code>.</p>
      <p><?= t('Load weapons at the marked spot, deliver to 2 drop-offs (fixed points or mafia HQs), then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$500</span> + <span class="num">$1</span> <?= t('per distance unit to the drop-off, per delivery.') ?></p>
      <p><code>/getjob 3</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>4 — <?= t('Car Transportator') ?></h3>
      <p><?= t('Transport vehicles.') ?> <?= t('Take it with') ?> <code>/getjob 4</code>. <?= t('Get in the transporter, then') ?> <code>/job</code>.</p>
      <p><?= t('Load at the marked spot, unload at 2 businesses, then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$1.500</span> + <span class="num">$1</span> <?= t('per distance unit to the business, per delivery.') ?></p>
      <p><code>/getjob 4</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>5 — Uber</h3>
      <p><?= t('Drive players around for money.') ?> <?= t('Take it with') ?> <code>/getjob 5</code>. <?= t('Use') ?> <code>/fare [amount]</code> <?= t('in your PERSONAL vehicle to go on duty.') ?></p>
      <p><?= t('When a player uses') ?> <code>/service uber</code>, <?= t('use') ?> <code>/accept uber</code> <?= t('to take the ride. The passenger is charged over time until they get out.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <?= t('you set the price with') ?> <code>/fare [amount]</code> - <?= t('the passenger is charged that amount every') ?> <span class="num">20 <?= t('seconds') ?></span> <?= t('for as long as the ride lasts.') ?></p>
      <p><code>/getjob 5</code>, <code>/fare</code>, <code>/service</code>, <code>/accept</code></p>
    </div>
    <div class="card">
      <h3>6 — <?= t('Emergency Logistics Driver') ?></h3>
      <p><?= t('Deliver medical supplies.') ?> <?= t('Take it with') ?> <code>/getjob 6</code>. <?= t('Get in a depot vehicle (Bobcat / Burrito), then') ?> <code>/job</code>.</p>
      <p><?= t('Load at the marked depot, deliver to 2 shops, then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$700</span> + <span class="num">$1</span> <?= t('per distance unit to the shop, per delivery.') ?></p>
      <p><code>/getjob 6</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>7 — <?= t('Bus Driver') ?></h3>
      <p><?= t('Drive fixed routes.') ?> <?= t('Take it with') ?> <code>/getjob 7</code>. <?= t('Get in a depot bus and use') ?> <code>/bus [1-3]</code> <?= t('to start a route.') ?></p>
      <p><?= t('You earn at each checkpoint, plus $100 for every passenger that boards.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$300</span> + <span class="num">$1</span> <?= t('per distance unit since the last checkpoint, at every checkpoint;') ?> <span class="num">$1.000</span> <?= t('bonus for finishing the route;') ?> <span class="num">$100</span> <?= t('per boarding passenger.') ?></p>
      <p><code>/getjob 7</code>, <code>/bus [1-3]</code>, <code>/stopwork</code></p>
    </div>
    <div class="card">
      <h3>8 — <?= t('Electrician') ?></h3>
      <p><?= t('Repair broken appliances and devices for a fee.') ?> <?= t('Take it with') ?> <code>/getjob 8</code>. <?= t('You must be driving your Electrician job vehicle (see') ?> <code>/joblist</code>) <?= t('for every repair command below.') ?></p>
      <ul>
        <li><code>/findbrokenitems</code> — <?= t('checkpoint to a nearby house that needs a repair') ?></li>
        <li><code>/fixfridge</code> / <code>/fixbed</code> — <?= t("fix a house's fridge/bed (within 5 days of breaking), paid from the house's own bank ($2.000 / $1.000)") ?></li>
        <li><code>/fixapartament</code> — <?= t("fix an active apartment issue (flood/sewage/electrical), paid from the house's bank ($3.000)") ?></li>
        <li><code>/fixphone [playerid] [amount]</code> / <code>/fixwatch [playerid] [amount]</code> — <?= t("offer to fix a nearby player's broken phone/watch; they confirm with") ?> <code>/accept fixphone</code> <?= t('or') ?> <code>/accept fixwatch</code></li>
      </ul>
    </div>
    <div class="card">
      <h3>9 — <?= t('Crop Duster Pilot') ?></h3>
      <p><?= t('Treat farmland from the air.') ?> <?= t('Take it with') ?> <code>/getjob 9</code>. <?= t('Get in one of the 2 job planes (Beagle, see') ?> <code>/joblist</code>), <?= t('then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t('Fly to the marked load point and hold still for 3 seconds while it loads fertilizer, then fly to the randomly chosen farm within') ?> <span class="num">120 <?= t('seconds') ?></span>, <?= t('between altitude') ?> <span class="num">100</span> <?= t('and') ?> <span class="num">200</span>, <?= t('and hit its checkpoint to spray it.') ?></p>
      <p><?= t('Pays') ?> <span class="num">$2.000-$3.000</span> <?= t('per run. Too slow or too low/high over the farm and the fertilizer goes to waste - use') ?> <code>/job</code> <?= t('again to retry.') ?></p>
      <p><code>/getjob 9</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>10 — <?= t('Water Hauler') ?></h3>
      <p><?= t('Transport water.') ?> <?= t('Take it with') ?> <code>/getjob 10</code>. <?= t('Get in the water tanker, then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t('Load at the water depot, deliver to 2 locations (farms or businesses), then return to load.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$1.200</span> + <span class="num">$1</span> <?= t('per distance unit to the delivery point, per delivery.') ?></p>
      <p><code>/getjob 10</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>11 — <?= t('Fisherman') ?></h3>
      <p><?= t('Catch fish at dedicated spots, then deliver it fresh.') ?> <?= t('Take it with') ?> <code>/getjob 11</code>. <?= t("You'll need a fishing rod — buy one at a") ?> <strong><?= t('Tools Shop') ?></strong> (<code>/shop</code>).</p>
      <p><?= t('Stand at one of the fishing spots and use') ?> <code>/fish</code> <?= t('to cast. After') ?> <span class="num">5</span> <?= t('seconds you catch a fish (') ?><span class="num">300-2.500g</span>), <?= t('and a random fast-food (pizza/burger/cluckin) is marked as your delivery point — drive there to sell it.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$500</span> <?= t('base +') ?> <?= t("half the fish's weight in grams (a") ?> <span class="num">2.500g</span> <?= t('fish pays around') ?> <span class="num">$1.750</span>).</p>
      <p><code>/getjob 11</code>, <code>/fish</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>12 — <?= t('Lumberjack') ?></h3>
      <p><?= t('Log timber from forests.') ?> <?= t('Take it with') ?> <code>/getjob 12</code>. <?= t('Get in a job vehicle (Dozer, Dune, see') ?> <code>/joblist</code>), <?= t('then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t('Drive to the marked forest, load logs at the logging point, then transport them to the lumber mill for unload. Repeat up to 5 loads.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$3.000</span> <?= t('base') ?> + <span class="num">$2</span> <?= t('per distance unit to the mill per load. Bonus:') ?> <span class="num">$10.000</span> <?= t('for completing all 5 loads in one session.') ?></p>
      <p><code>/getjob 12</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>13 — <?= t('Fuel Carrier') ?></h3>
      <p><?= t('Resupply gas stations.') ?> <?= t('Take it with') ?> <code>/getjob 13</code>. <?= t('Get in one of the 3 job roadtrains and attach one of the 3 job trailers (see') ?> <code>/joblist</code>), <?= t('then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t('Drive to the fuel depot to load (3 seconds), then pick a gas station from the list (shows current/max fuel and distance) and deliver to it. If the station doesn\'t have enough room, you\'ll be asked to pick another one.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <?= t('each run delivers') ?> <span class="num">1.000L</span> <?= t('and pays') ?> <span class="num">$6.000-$7.500</span>, <?= t('then the run ends — use') ?> <code>/job</code> <?= t('again for another run.') ?></p>
      <p><code>/getjob 13</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>14 — <?= t('Truck Driver') ?></h3>
      <p><?= t('Resupply bars.') ?> <?= t('Take it with') ?> <code>/getjob 14</code>. <?= t('Get in one of the 2 job trucks and attach one of the 2 job trailers (see') ?> <code>/joblist</code>), <?= t('then') ?> <code>/job</code> <?= t('to start.') ?></p>
      <p><?= t("You're sent to a random loading point out of 3; drive there to load to 100% (3 seconds), then pick a bar from the list (shows current/max stock and distance) and deliver to it.") ?></p>
      <p><?= t('Delivery has spillage: the truck loses') ?> <span class="num">2</span> <?= t('units of cargo for every') ?> <span class="num">1</span> <?= t('unit that actually reaches the bar, so a full load can resupply at most half of what a bar is missing. If the bar is already full, you\'ll be asked to pick another one.') ?></p>
      <p><strong><?= t('Pay:') ?></strong> <span class="num">$6.000-$7.500</span> <?= t('per run, then the run ends — use') ?> <code>/job</code> <?= t('again for another run.') ?></p>
      <p><code>/getjob 14</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
  </div>
</section>

<section id="factions">
  <h2>🚓 <?= t('Factions') ?> — <code>/howto faction</code></h2>
  <p class="subtitle"><?= t('Base command:') ?> <code>/howto faction [1-9]</code> <?= t('for a specific faction') ?></p>
  <div class="card">
    <p><?= t('Factions: Police (1), R.A.R. (2), SMURD (3), Mafias (4-7), News (8), Loco Outlaw Customs (9).') ?></p>
    <p><?= t('Joining: a rank 4+ member invites you with') ?> <code>/finvite</code>; <?= t('you accept with') ?> <code>/accept finvite [id]</code> (<?= t('be within 15m') ?>). <?= t('You can also apply straight from the') ?> <a href="factions.php"><?= t('Factions') ?></a> <?= t('page here on the UCP.') ?></p>
    <ul>
      <li><code>/f [text]</code> — <?= t('faction chat') ?></li>
      <li><code>/fhelp</code> — <?= t('every command your faction and rank can use') ?></li>
      <li><code>/factionstats [members/vehicles/bank]</code> — <?= t('faction info (rank 5)') ?></li>
      <li><code>/duty</code> — <?= t('go on/off duty (factions 1-3, inside the HQ)') ?></li>
    </ul>
  </div>

  <div class="subtopic-grid">
    <div class="card">
      <h3>1 — Politia Romana</h3>
      <p><?= t('Law enforcement.') ?> <?= t('Go on/off duty with') ?> <code>/duty</code> (<?= t('inside the HQ') ?>). <?= t('Only on-duty officers have police powers.') ?></p>
      <ul>
        <li><code>/wanted [player] [0-6] [reason]</code> — <?= t("set a suspect's wanted level") ?></li>
        <li><code>/arrest [player]</code> — <?= t('jail a wanted suspect (at an arrest zone)') ?></li>
        <li><code>/m [player]</code> — <?= t('megaphone: order a driver to pull over (in a faction vehicle, within 50m)') ?></li>
        <li><code>/radar install [limit]</code> — <?= t('set up a speed radar and sanction speeders (') ?><code>/radar remove</code>)</li>
        <li><code>/garage</code>, <code>/entrace</code> — <?= t('move around the station; press H near the LSPD barrier to open it') ?></li>
      </ul>
      <h4><?= t('Vehicle checks') ?></h4>
      <p><?= t('Police can inspect papers and confiscate:') ?> <code>/checklicenses [player]</code>, <code>/suspendlic</code>, <code>/confiscate insurance [player]</code> (<?= t('rank 2+') ?>), <code>/confiscate licence [A/B/C/D/P/H/all] [player]</code> — <?= t('driving + airplane (P) & helicopter (H) licenses.') ?></p>
      <h4><?= t('Self-surrender —') ?> <code>/arrestme</code></h4>
      <p><?= t('At the') ?> <strong>[ Jail ]</strong> <?= t('marker, if') ?> <strong><?= t('no officer is on duty') ?></strong>, <?= t('a player with wanted level') ?> <span class="num">2+</span> <?= t('can turn themselves in with') ?> <code>/arrestme</code>. <?= t('Same jail time and fine as a normal') ?> <code>/arrest</code>, <?= t('but') ?> <span class="num">+20%</span> <?= t("on both — and since there's no arresting officer, the full fine goes straight into the Police faction vault instead of being split.") ?></p>
    </div>
    <div class="card">
      <h3>2 — Registrul Auto Roman (R.A.R.)</h3>
      <p><?= t('Vehicle registry & inspections.') ?> <?= t('Members run the R.A.R. HQ, where drivers renew their vehicle documents (') ?><code>/vitp</code> <?= t('inspection') ?>, <code>/vplate</code>, <code>/vInsurance</code>).</p>
      <p><code>/fine [player] [amount] [reason]</code> — <?= t('fine a driver.') ?></p>
      <h4><?= t('Checks & confiscation (rank 3+, on-duty)') ?></h4>
      <p><code>/confiscate medkit / extinctor / itp [player]</code> — <?= t('take those items/documents.') ?></p>
      <h4><?= t('Impounding') ?></h4>
      <p><?= t("If your ITP is expired, R.A.R. can tow your car with a Towtruck and impound it (") ?><code>/towpark</code>) — <?= t("the engine won't start. Go to the car and use") ?> <code>/redeemcar</code> <?= t('to pay the release fee and get it back with ITP valid until the end of the day.') ?></p>
    </div>
    <div class="card">
      <h3>3 — SMURD</h3>
      <p><?= t('Emergency medical & fire service.') ?></p>
      <h4><?= t('Medical') ?></h4>
      <p><code>/heal [player]</code> — <?= t('heal a player who is a passenger in your ambulance (paid). Sick players come to the hospital to') ?> <code>/curedisease</code>.</p>
      <h4><?= t('Firefighting') ?></h4>
      <p><?= t('Fires can break out anywhere on the map. On duty, take the Firetruck, drive within 25m of the fire, and hold the FIRE button (spray water) to put it out.') ?></p>
    </div>
    <div class="card">
      <h3>4-7 — Mafias</h3>
      <p><?= t('Organized crime family. Mafias run drugs and fight over territory.') ?></p>
      <ul>
        <li><code>/drugs transport</code> — <?= t('haul weed to the vault') ?></li>
        <li><code>/drugs craft</code> — <?= t('turn weed into drugs') ?></li>
        <li><code>/drugs get</code> / <code>use</code> — <?= t('take & use drugs during a war') ?></li>
        <li><code>/seif</code> — <?= t('the faction vault (rank 4+)') ?></li>
        <li><code>/equip</code> — <?= t('get weapons inside the HQ') ?></li>
        <li><code>/war</code> — <?= t('start a turf war') ?></li>
        <li><code>/warsurrender</code> — <?= t('surrender an ongoing war (rank 4+)') ?></li>
      </ul>
      <p><?= t('Each mafia controls its own territories. See') ?> <a href="#smuggle"><?= t('Smuggling') ?></a> <?= t('for the') ?> <code>/smuggle</code> <?= t('contraband run (mafias only).') ?></p>
    </div>
    <div class="card">
      <h3>8 — News Reporters</h3>
      <p><?= t('The press. They inform the city via live broadcasts, live interviews and the newspaper.') ?></p>
      <h4><?= t('Live news (rank 1+)') ?></h4>
      <p><code>/news [text]</code> — <?= t('broadcast a headline to everyone.') ?></p>
      <h4><?= t('Live Q&A / interviews (rank 3+)') ?></h4>
      <ul>
        <li><code>/qa [player]</code> — <?= t('start a live interview (the guest accepts with') ?> <code>/accept qa</code>)</li>
        <li><code>/qa list</code> — <?= t('see submitted questions') ?></li>
        <li><code>/qa ask [nr]</code> — <?= t('ask one live') ?></li>
        <li><code>/qa del [nr]</code> — <?= t('remove one') ?></li>
        <li><code>/qa end</code> — <?= t('stop the Q&A') ?></li>
      </ul>
      <p><?= t('Anyone can') ?> <code>/question [text]</code> <?= t('to submit; the guest replies with') ?> <code>/answer [text]</code>.</p>
      <h4><?= t('Newspaper') ?></h4>
      <ul>
        <li><code>/newspaper create</code> — <?= t('start a new edition') ?></li>
        <li><code>/newspaper edit [1-5] [text]</code> — <?= t('write up to 5 stories') ?></li>
        <li><code>/newspaper sell</code> — <?= t('put it on sale') ?></li>
        <li><code>/newspaper open</code> — <?= t('read the current newspaper') ?></li>
      </ul>
    </div>
    <div class="card">
      <h3>9 — Loco Outlaw Customs</h3>
      <p><?= t("A street tuning crew — the only faction that can modify") ?> <em><?= t("other players'") ?></em> <?= t('vehicles.') ?></p>
      <h4><?= t('Tuning —') ?> <code>/tune</code></h4>
      <p><?= t('Members work from their garage (the') ?> <strong>[ Tuning Point ]</strong> <?= t('marker). Both you and the car have to be at the point, you must be the') ?> <strong><?= t('driver') ?></strong>, <?= t('the') ?> <strong><?= t('engine off') ?></strong> <?= t('and the') ?> <strong><?= t('hood open') ?></strong> (<code>/changecar engine</code>, <code>/changecar hood</code>).</p>
      <ul>
        <li><?= t('Spoiler, Hood, Roof, Side Skirt, Front/Rear Bumper, Exhaust, Wheels, Nitro, Hydraulics') ?></li>
        <li><?= t('Paintjob (3 options) and') ?> <em><?= t('Remove All Mods') ?></em></li>
      </ul>
      <p><?= t("The menu only lists parts that actually fit the model in front of you — the server tests the vehicle live instead of guessing, so you can't buy a part that won't mount.") ?></p>
      <p><strong><?= t('Wheels expire.') ?></strong> <?= t('Rims fitted with') ?> <code>/tune</code> <?= t('are saved to the vehicle and survive respawns and restarts, but only for') ?> <span class="num">14 <?= t('days') ?></span> <?= t('on a personal vehicle and') ?> <span class="num">7 <?= t('days') ?></span> <?= t('on a faction vehicle. After that the car reverts to its stock rims on its next respawn.') ?></p>
      <p class="note"><?= t('Anyone sitting in the car as a') ?> <strong><?= t('passenger') ?></strong> <?= t('while it gets tuned picks up sin 7,') ?> <em><?= t('Witness to Illegal Vehicle Modifications') ?></em> — <?= t('see') ?> <a href="#religion"><?= t('Religion & Sins') ?></a>.</p>
    </div>
  </div>

  <div class="card">
    <h4><?= t('Leadership (any faction, rank 4/5)') ?></h4>
    <ul>
      <li><code>/finvite [player]</code>, <code>/fbank</code> (<?= t('rank 4+') ?>)</li>
      <li><code>/fsetrank [player] [1-5]</code>, <code>/fbankwithdraw</code> (<?= t('rank 5 Lead') ?>)</li>
      <li><code>/fkick</code> (<?= t('or') ?> <code>/funinvite</code>) <code>[player]</code> — <?= t('remove a member (rank 5 Lead)') ?></li>
      <li><code>/refillfactionveh</code>, <code>/respawnfactionveh</code> — <?= t('refuel/respawn all faction vehicles (Lead)') ?></li>
    </ul>
  </div>
</section>

<section id="vehicles">
  <h2>🚗 <?= t('Vehicles') ?> — <code>/howto vehicle</code></h2>
  <div class="card">
    <p><?= t('Buy vehicles from dealerships. You need a matching driving license to drive one (see') ?> <a href="#licence"><?= t('Licence') ?></a>). <?= t('You can own up to') ?> <span class="num">3</span> <?= t('personal vehicles (slots 1-3).') ?></p>

    <h4><?= t('Buying & selling') ?></h4>
    <ul>
      <li><code>/vbuy</code> — <?= t('buy the dealership vehicle you are sitting in') ?></li>
      <li><code>/sellveh [price]</code> — <?= t("list the vehicle you're driving for sale at that price") ?></li>
      <li><code>/sellveh 0</code> — <?= t('cancel the listing') ?></li>
      <li><code>/sellvehtostate</code> — <?= t('sell it back to the state instantly (') ?><span class="num">60%</span>)</li>
      <li><code>/vsellto [playerid]</code> — <?= t("offer the vehicle you're driving directly to a nearby player") ?></li>
    </ul>

    <h4><?= t('Info & navigation') ?></h4>
    <ul>
      <li><code>/vstats</code> — <?= t('all your vehicles: documents, fuel and dirt level') ?></li>
      <li><code>/findmy veh1</code> / <code>/findmy veh2</code> / <code>/findmy veh3</code> — <?= t('checkpoint to the vehicle in that slot') ?></li>
    </ul>

    <h4><?= t('Using your vehicle') ?></h4>
    <ul>
      <li><code>/engine</code> — <?= t('start/stop the engine') ?> · <code>/lock</code> — <?= t('lock/unlock the doors') ?></li>
      <li><code>/v park</code> — <?= t('save the current spot as its permanent spawn point') ?></li>
      <li><code>/v color1 [colorID]</code> / <code>/v color2 [colorID]</code> — <?= t('repaint (primary/secondary). Range is') ?> <span class="num">0-127</span> <?= t('normally,') ?> <span class="num">0-255</span> <?= t('on a') ?> <strong>VIP</strong> <?= t('vehicle.') ?></li>
      <li><code>/changecar [engine/lights/alarm/doors/hood/boot]</code> — <?= t('toggle a component of the vehicle you drive') ?></li>
    </ul>
    <p><?= t('You can also press the horn key for lights, and the analog up/down keys for hood/boot while driving.') ?></p>

    <h4><?= t('Wheels') ?></h4>
    <p><?= t("Rims are no longer bought from the vehicle menu — they're fitted by") ?> <strong>Loco Outlaw Customs</strong> <?= t('with') ?> <code>/tune</code> <?= t('at their garage (see') ?> <a href="#factions"><?= t('Factions') ?></a>). <?= t("They're saved and survive respawns and restarts, but they") ?> <strong><?= t('expire') ?></strong>: <span class="num">14 <?= t('days') ?></span> <?= t('on a personal vehicle,') ?> <span class="num">7 <?= t('days') ?></span> <?= t('on a faction vehicle. Once expired the car goes back to its stock rims the next time it respawns — go get them refitted.') ?></p>

    <h4><?= t('Fuel') ?></h4>
    <p><?= t('Every vehicle burns fuel while the engine runs.') ?></p>
    <ul>
      <li><code>/refuel</code> — <?= t('refuel at a gas station (paid)') ?></li>
      <li><code>/fillgascan</code> — <?= t('fill your gas can at a gas station (buy the can at') ?> <code>/shop</code>)</li>
      <li><code>/fill</code> — <?= t("empty a FULL gas can into the vehicle you're in - use it when you run dry far from a station") ?></li>
    </ul>

    <h4><?= t('Documents & items (all at R.A.R.)') ?></h4>
    <ul>
      <li><code>/vinsurance</code> — <?= t('insurance,') ?> <span class="num">$500</span>, <?= t('valid') ?> <span class="num">5 <?= t('days') ?></span></li>
      <li><code>/vitp</code> — <?= t('ITP inspection,') ?> <span class="num">$750</span>, <?= t('valid') ?> <span class="num">15 <?= t('days') ?></span> (<?= t('engine off, hood open, boot closed, lights on') ?>)</li>
      <li><code>/vplate</code> — <?= t('number plate,') ?> <span class="num">$250</span>, <?= t('no expiry') ?></li>
      <li><code>/v install medicalkit</code> — <?= t('fit a medical kit bought at /shop (') ?><span class="num">$500</span>), <?= t('valid') ?> <span class="num">7 <?= t('days') ?></span></li>
      <li><code>/v install extinctor</code> — <?= t('fit an extinguisher bought at /shop (') ?><span class="num">$500</span>), <?= t('valid') ?> <span class="num">10 <?= t('days') ?></span></li>
    </ul>
    <p><?= t('A document is valid for the WHOLE day it expires on - only the next day does it count as expired.') ?></p>

    <h4><?= t('Police & R.A.R.') ?></h4>
    <p><?= t('They can inspect your car and confiscate it or its documents. Use') ?> <code>/redeemcar</code> <?= t('to buy back a vehicle that was confiscated or towed.') ?></p>

    <h4><?= t('Dirty vehicles') ?></h4>
    <p><?= t('Your car gets dirtier every time it respawns (') ?><span class="num">+8-12</span> <?= t('each time). At') ?> <span class="num">75</span> <?= t("you're warned to wash it; above") ?> <span class="num">90</span> <?= t("the engine won't start at all. Use") ?> <code>/v wash</code> <?= t('at a CarWash (') ?><span class="num">$100</span>) <?= t('to clean it.') ?></p>

    <h4><?= t('Renting (no license needed)') ?></h4>
    <p><code>/rentcar</code> — <?= t('rent a car at a rental point') ?> · <code>/rentbike</code> — <?= t('rent a bicycle (') ?><span class="num">$15</span>)</p>
  </div>
</section>

<section id="business">
  <h2>🏢 <?= t('Businesses') ?> — <code>/howto business</code></h2>
  <div class="card">
    <p><?= t("A business earns") ?> <span class="num"><?= t('passive income') ?></span> <?= t("into its own bank whenever players use the activity it covers - you don't have to be online. You can own only") ?> <span class="num"><?= t('ONE') ?></span> <?= t('business at a time. Stand on the pickup to interact.') ?></p>

    <h4><?= t('Buying & selling') ?></h4>
    <ul>
      <li><code>/buybiz</code> — <?= t("buy the business you're standing in (sold by the server or another player)") ?></li>
      <li><code>/biz sell [price]</code> — <?= t('list it for sale at that price; money goes to your bank when someone buys it with') ?> <code>/buybiz</code></li>
      <li><code>/biz sell 0</code> — <?= t('cancel the listing') ?></li>
      <li><code>/biz sellto [playerid] [amount]</code> — <?= t('offer it directly to a nearby player; they buy it with cash via') ?> <code>/accept biz [yourid]</code></li>
      <li><code>/biz selltostate</code> — <?= t('sell it back to the state instantly for') ?> <span class="num">60%</span> <?= t('of its value') ?></li>
    </ul>

    <h4><?= t('Money & info') ?></h4>
    <ul>
      <li><code>/bbank</code> — <?= t('show the business bank balance (stand on it)') ?></li>
      <li><code>/biz withdraw [amount]</code> — <?= t('withdraw earnings from the business bank') ?></li>
      <li><code>/mybiz</code> — <?= t('set a checkpoint to the business you own') ?></li>
      <li><code>/mybank</code> — <?= t('list all your property accounts (near a bank/ATM)') ?></li>
      <li><code>/mybank biz deposit [amount]</code> / <code>withdraw [amount]</code> — <?= t('move money in/out of the business bank (near a bank/ATM)') ?></li>
    </ul>

    <h4><?= t('Where the income comes from') ?></h4>
    <p><?= t('Each business is tied to an activity, and takes a cut every time someone uses it - fast-food orders (') ?><code>/pizza</code>, <code>/burger</code>, <code>/meal</code>, <code>/desert</code>), <?= t('the ATM withdrawal fee, phone & SIM sales, SMS and calls, fridge shopping, appliances (fridge/bed), Glovo deliveries and exam fees. The busier the activity, the more it earns.') ?></p>

    <h4><?= t('ANAF audits') ?></h4>
    <p><?= t('Once a day at') ?> <span class="num">12:00</span>, <?= t('a random owned business gets flagged - it earns') ?> <span class="warn"><?= t('nothing') ?></span> <?= t("until cleared. You're warned on respawn if yours is hit.") ?></p>
    <ul>
      <li><?= t('Drive a') ?> <span class="num"><?= t('vehicle model 428') ?></span> <?= t('to your business and use') ?> <code>/biz getdocs</code></li>
      <li><?= t('Drive to') ?> <span class="num">ANAF</span> <?= t('and use') ?> <code>/biz givedocs</code> - <?= t('your business is cleared at the next payday') ?></li>
    </ul>
  </div>
</section>

<section id="house">
  <h2>🏠 <?= t('Houses') ?> — <code>/howto house</code></h2>
  <div class="card">
    <p><?= t('A house is your spawn point and storage. You can own only ONE. Stand on the pickup to interact; be at YOUR OWN house for the fridge/bed/tree/animal/SGR/trash commands.') ?></p>

    <h4><?= t('Buy & sell') ?></h4>
    <ul>
      <li><code>/buyhouse</code> — <?= t('buy the house you stand on (from server or a player)') ?></li>
      <li><code>/house sell [price]</code> — <?= t('list for sale (money to your bank when sold);') ?> <code>/house sell 0</code> <?= t('cancels') ?></li>
      <li><code>/house sellto [playerid] [amount]</code> — <?= t('offer it directly to a player (cash, via /accept house)') ?></li>
      <li><code>/house selltostate</code> — <?= t('sell to the state for') ?> <span class="num">60%</span></li>
    </ul>

    <h4><?= t('Renting') ?></h4>
    <p><code>/renthouse</code> / <code>/rentappartment</code> — <?= t('rent a nearby rentable one (blocked if you own/rent already).') ?> <code>/endrent</code> <?= t('to give it up.') ?></p>

    <h4><?= t('Info') ?></h4>
    <ul>
      <li><code>/hstats</code> — <?= t('name, ID, price, type, fridge contents + break dates') ?></li>
      <li><code>/findmy house</code> / <code>/findhouse [id]</code> — <?= t('checkpoint to your house / any house') ?></li>
      <li><code>/mybank house deposit|withdraw [amount]</code> — <?= t('house bank (near a bank/ATM)') ?></li>
    </ul>
    <p><?= t('If the house has an interior, press') ?> <span class="num">ENTER</span> <?= t('at the pickup to go in/out.') ?></p>

    <h4><?= t('Upgrades —') ?> <code>/house upgrade [frigde/bed/tree/animal]</code></h4>
    <ul>
      <li><code>frigde</code> — <span class="num">$10.000</span>, <?= t('breaks after') ?> <span class="num">32 <?= t('days') ?></span></li>
      <li><code>bed</code> — <span class="num">$7.500</span>, <?= t('breaks after') ?> <span class="num">29 <?= t('days') ?></span></li>
      <li><code>tree</code> — <span class="num">$20.000</span> (<?= t('city or countryside house') ?>), <?= t('unlocks') ?> <code>/tree plant</code></li>
      <li><code>animal [name]</code> — <span class="num">$5.000</span>: <?= t('Turtle/Deer (Villa only), Cow (countryside only), Parrot (any house type)') ?></li>
    </ul>
    <p><?= t('Same command replaces a broken fridge/bed (1% to Home Furnitures).') ?></p>

    <h4><?= t('Fridge —') ?> <code>/frigde</code></h4>
    <ul>
      <li><code>/frigde</code> — <?= t('view contents') ?></li>
      <li><code>/frigde buy [item] [qty]</code> — <?= t('stock milk/banana/water/juice/beer, only') ?> <span class="num">15:00-20:00</span></li>
      <li><code>/frigde use [item]</code> — <?= t('eat/drink one for HP') ?></li>
    </ul>
    <p><?= t('Price/max/HP: Milk $100/20L/+20, Banana $50/30/+10, Water $150/25L/+25, Juice $200/20L/+15, Beer $250/50L/+10.') ?></p>
    <p class="warn"><?= t('A broken fridge loses everything inside and is unusable until replaced.') ?></p>

    <h4><?= t('Tree —') ?> <code>/tree [plant/collect]</code></h4>
    <p><?= t('Unlocked by') ?> <code>/house upgrade tree</code> (<?= t('city/countryside') ?>); <code>/tree plant</code> <?= t('needs a Shovel (5s). Grows +1/payday (max 30): 12-20 = 8-11 bananas, 21-29 = 1-3, 30 = 0 + resets.') ?></p>

    <h4>SGR/<?= t('Trash') ?></h4>
    <p><?= t('Fridge drinks leave SGR bottles, fridge food leaves trash (max 100 each, warned at 80).') ?></p>
    <ul>
      <li><code>/sgrload</code>/<code>/trashload</code> — <?= t('at your house, in an SGR van/garbage truck') ?></li>
      <li><code>/sgrunload</code>/<code>/trashunload</code> — <?= t('at the unload point; house bank gets $50/$30 each') ?></li>
    </ul>

    <h4><?= t('Tiredness &') ?> <code>/sleep</code></h4>
    <p><?= t('+2/min; 80+ costs extra HP. Home bed: free, 30s, to 0. Any hotel: $150, 45s, to 10 (see') ?> <a href="#hotel"><?= t('Hotel') ?></a>).</p>

    <h4><?= t('Cow') ?></h4>
    <p><?= t('Gives a 50% chance/payday (while online) of 2-5L milk straight into your fridge.') ?></p>

    <h4><?= t('Parrot —') ?> <code>/parrot [get/down]</code></h4>
    <p><?= t('The only portable pet — available at') ?> <strong><?= t('any') ?></strong> <?= t('house type, unlike the others.') ?> <code>/parrot get</code> <?= t('puts it on your shoulder so it follows you everywhere;') ?> <code>/parrot down</code> <?= t("sets it back down and it flies home. It doesn't stay on your shoulder across a disconnect — you'll need") ?> <code>/parrot get</code> <?= t('again next time.') ?></p>

    <h4><?= t('Repairs') ?></h4>
    <p><?= t('An Electrician can fix your fridge/bed in the last 5 days before they break, paid from the house bank ($2.000/$1.000), adding 15 days.') ?></p>
  </div>
</section>

<section id="hotel">
  <h2>🏨 <?= t('Hotels') ?> — <code>/howto hotel</code></h2>
  <div class="card">
    <p><?= t('A hotel is an ownable property (like a house) where') ?> <span class="num"><?= t('any') ?></span> <?= t("player can pay to sleep - no bed and no ownership required. It's a passive income property: guests pay, the owner collects. You can own only ONE hotel at a time.") ?></p>

    <h4><?= t('What you can do AT a hotel (anyone)') ?></h4>
    <ul>
      <li><code>/sleep</code> — <?= t('rent a room for') ?> <span class="num">$150</span>. <?= t('You freeze for') ?> <span class="num">45 <?= t('seconds') ?></span>, <?= t('then your tiredness drops to') ?> <span class="num">10</span>. <?= t("It does NOT have to be your own hotel, and you don't need a bed. Just stand at the hotel pickup. Compared to sleeping at home (free, 30s, tiredness → 0), a hotel is the paid option when you're away from your house or don't own a bed.") ?></li>
      <li><code>/buyhotel</code> — <?= t("buy the hotel you're standing on, if it's for sale") ?></li>
    </ul>

    <h4><?= t('Buying & selling') ?></h4>
    <ul>
      <li><code>/buyhotel</code> — <?= t("buy the hotel whose pickup you're standing on (sold by the server or another player)") ?></li>
      <li><code>/sellhotel [price]</code> — <?= t('list your hotel for sale at that price; the money goes to your bank when someone buys it') ?></li>
      <li><code>/sellhotel 0</code> — <?= t('cancel the listing') ?></li>
      <li><code>/sellhotelstate</code> — <?= t('sell it back to the state instantly for') ?> <span class="num">60%</span> <?= t('of its value') ?></li>
    </ul>

    <h4><?= t('Renting a room long-term') ?></h4>
    <p><code>/renthotel</code> — <?= t('rent a nearby hotel an admin marked rentable (not the same as') ?> <code>/sleep</code>). <?= t("Blocked if you own a house or already rent something. Rent is taken from you every PayDay, into the hotel's bank.") ?> <code>/endrent</code> — <?= t('give up your current rent.') ?></p>

    <h4><?= t('Info & navigation') ?></h4>
    <ul>
      <li><code>/htlstats</code> — <?= t('name, ID, price, hotel bank balance and the sleep price') ?></li>
      <li><code>/findmy hotel</code> — <?= t('set a checkpoint to the hotel you own') ?></li>
      <li><code>/findhotel [id]</code> — <?= t('set a checkpoint to any hotel by its ID') ?></li>
    </ul>

    <h4><?= t('Owner income') ?></h4>
    <p><?= t('Every time a guest uses') ?> <code>/sleep</code> <?= t('at your hotel,') ?> <span class="num">$75</span> (<?= t('half the $150 they pay') ?>) <?= t("goes into the hotel's bank; the other half is lost to running costs. This happens whether you are online or not.") ?></p>
    <ul>
      <li><code>/mybank hotel withdraw [amount]</code> — <?= t('take the earnings out (near a bank/ATM)') ?></li>
      <li><code>/mybank hotel deposit [amount]</code> — <?= t('put money in') ?></li>
      <li><code>/mybank</code> — <?= t('see the balance of every property you own') ?></li>
    </ul>

    <h4><?= t('Hygiene items —') ?> <code>/htlitems</code></h4>
    <p><?= t('Your hotel stocks up to') ?> <span class="num">200</span> <?= t('hygiene items (soap, towels...). Every') ?> <code>/sleep</code> <?= t('stay and every new') ?> <code>/renthotel</code> <?= t('check-in uses up') ?> <span class="num">1</span> <?= t('item. Run out, and') ?> <strong class="warn"><?= t('your hotel stops earning money in its bank') ?></strong> <?= t("until you restock - guests can still sleep there, you just don't get paid.") ?></p>
    <ul>
      <li><code>/htlitems buy [amount]</code> — <?= t('buy items at a') ?> <span class="num">24/7 Shop</span>, <span class="num">$100</span> <?= t('each, up to') ?> <span class="num">100</span> <?= t('per trip. You must be at the wheel of the designated supply vehicle (') ?><span class="num">Boxville</span>).</li>
      <li><code>/htlitems unload</code> — <?= t("deliver the items you're carrying to your own hotel (still in the Boxville). Anything over the 200 cap is wasted, so don't overbuy.") ?></li>
    </ul>

    <div class="note"><?= t('A hotel near a busy area earns more, because tiredness builds up on everyone (+2/minute) and players away from home need somewhere to sleep - but it also burns through hygiene items faster, so keep it stocked.') ?></div>
  </div>
</section>

<section id="billboards">
  <h2>📢 <?= t('Billboards') ?> — <code>/howto billboards</code></h2>
  <div class="card">
    <p><?= t('A billboard is an ownable property (like a hotel) that other players pay to rent for 24/48/72h and display their own text on. You can own only ONE billboard at a time. Stand at the billboard\'s pickup to interact.') ?></p>

    <h4><?= t('Buying & selling') ?></h4>
    <ul>
      <li><code>/buybillboard</code> (<?= t('or') ?> <code>/buybb</code>) — <?= t("buy the billboard you're standing at, if it's for sale") ?></li>
      <li><code>/bb sell [price]</code> — <?= t('list your billboard for sale at that price; the money goes to your bank when someone buys it with') ?> <code>/buybillboard</code></li>
      <li><code>/bb sell 0</code> — <?= t('cancel the listing') ?></li>
      <li><code>/bb sellto [playerid] [amount]</code> — <?= t('offer it directly to a nearby player; they buy it with cash via') ?> <code>/accept billboard [yourid]</code></li>
      <li><code>/bb selltostate</code> — <?= t('sell it back to the state instantly for') ?> <span class="num">60%</span> <?= t('of its value') ?></li>
    </ul>

    <h4><?= t('Renting a billboard (anyone)') ?></h4>
    <p><?= t('The billboard must be') ?> <span class="num"><?= t('free') ?></span> <?= t('and') ?> <span class="num"><?= t('clean') ?></span>. <?= t('Use') ?> <code>/rentbb</code> (<?= t('or') ?> <code>/rentbillboard</code>) <?= t('at its pickup and pick 24/48/72 hours (in payday cycles) from the dialog.') ?></p>
    <ul>
      <li><code>/bbtext [text]</code> — <?= t("set the text shown on the billboard, only while you're renting it (max") ?> <span class="num">100</span> <?= t('characters, at most') ?> <span class="num">5</span> <?= t('line breaks with') ?> <code>\n</code>)</li>
    </ul>
    <p><?= t('When your rent runs out, the text resets to the default and the billboard becomes') ?> <span class="warn"><?= t('dirty') ?></span> - <?= t('it needs cleaning before it can be rented again.') ?></p>

    <h4><?= t('Cleaning — News Reporters only') ?></h4>
    <p><?= t("A dirty billboard can only be cleaned by a member of the News faction, at the billboard's pickup:") ?></p>
    <ul>
      <li><code>/cleanbb</code> — <?= t('starts the cleanup; earns the reporter') ?> <span class="num">$500</span> <?= t('and the News faction bank') ?> <span class="num">$250</span>. <?= t('It finishes automatically at the next PayDay, after which the billboard is clean and rentable again.') ?></li>
    </ul>

    <h4><?= t('Owner settings & info') ?></h4>
    <ul>
      <li><code>/setrentprice [amount]</code> — <?= t("set your billboard's 24h rent price (48h/72h scale x2/x3 automatically)") ?></li>
    </ul>
    <p><?= t("Every rental pays") ?> <span class="num">50%</span> <?= t("of the rent straight into the billboard's own bank, whether you're online or not — check it in the") ?> <a href="dashboard.php"><?= t('UCP dashboard') ?></a>.</p>

    <div class="note"><?= t('Billboard income comes from renters, not passive use - a well-placed billboard (busy road, city center) rents out faster and more often.') ?></div>
  </div>
</section>

<section id="games">
  <h2>🎮 <?= t('Mini-games & Events') ?> — <code>/howto games</code></h2>
  <div class="card">
    <h4>Golf</h4>
    <p><?= t('Stroke play at the golf course.') ?></p>
    <ul>
      <li><code>/joingolf</code> — <?= t('enter (an admin opens the tournament)') ?></li>
      <li><code>/hitball [power]</code> — <?= t('swing toward the hole; aim with your camera, power sets distance') ?></li>
      <li><code>/leavegolf</code> — <?= t('quit') ?></li>
    </ul>
    <p><?= t('Fewest strokes wins.') ?></p>

    <h4><?= t('Basketball') ?></h4>
    <p><?= t('At the') ?> <code>/basket</code> <?= t('court (follow the map icon).') ?></p>
    <ul>
      <li><code>/joinbasket</code> — <?= t('join the lobby') ?></li>
      <li><code>/throwball [power]</code> — <?= t('shoot at your hoop') ?></li>
      <li><code>/leavebasket</code> — <?= t('quit') ?></li>
    </ul>
    <p><?= t('Most points wins.') ?></p>

    <h4><?= t('Race Events (BestLap)') ?></h4>
    <p><?= t('An admin opens a race on a track (Lap1/2/3) with a set car (or random).') ?></p>
    <ul>
      <li><code>/event join</code> — <?= t('enter while sign-ups are open') ?></li>
      <li><?= t('On start you spawn at the line; a 5s countdown runs (5..4..3..2..1..GO!), then race the checkpoints') ?></li>
    </ul>
    <p><?= t('Your time is measured from GO to the last checkpoint. The top 3 are announced server-wide; beat the best time for that track & car to set a RECORD!') ?></p>

    <h4>Counter Strike</h4>
    <p><?= t('5v5 team deathmatch with a bomb. Several matches can run at once.') ?></p>
    <ul>
      <li><code>/event cs join [nr]</code> — <?= t('enter while an admin has sign-ups open') ?></li>
      <li><?= t('Sign-ups close automatically at') ?> <span class="num">10 <?= t('players') ?></span> (<?= t('or when an admin starts it), then everyone spawns') ?></li>
      <li><?= t('Teams are assigned alternately as you join: T, CT, T, CT...') ?></li>
    </ul>
    <p><strong><?= t('Rules:') ?></strong> <?= t('the match is') ?> <span class="num">10 <?= t('rounds') ?></span>; <?= t('most rounds won takes it (5-5 = draw). After round 5 the teams swap sides.') ?></p>
    <ul>
      <li><span class="t">T</span> <?= t('win by planting the bomb (') ?><code>/plant</code> <?= t('at a [ Bomb ] site, 3s freeze) and letting it explode, or by killing all CT.') ?></li>
      <li><span class="ct">CT</span> <?= t("win by killing all T (only if the bomb isn't planted), or by defusing it (") ?><code>/defuse</code>, <?= t('3s freeze).') ?></li>
      <li><?= t('Once planted, the bomb explodes in a set number of seconds - killing every T does NOT win the round anymore, CT must defuse.') ?></li>
    </ul>
    <p><?= t('Each round you get an AK-47 (T) or M4 (CT), a Desert Eagle and full armour. Die and you spectate your team until the next round.') ?></p>

    <h4><?= t('Hunt The Mayor') ?></h4>
    <p><?= t('One random player becomes the Mayor; everyone else hunts them.') ?></p>
    <ul>
      <li><code>/event htm join</code> — <?= t('enter while an admin has sign-ups open') ?></li>
      <li><?= t('On start, the Mayor spawns at a random secret location (100 HP + 100 armour, MP5); every hunter spawns together elsewhere (50 HP, M4)') ?></li>
    </ul>
    <p><?= t('You have') ?> <span class="num">15 <?= t('minutes') ?></span>.</p>
    <ul>
      <li><?= t('Land a hit on the Mayor (any damage) →') ?> <span class="num">$5.000</span>, <?= t('once per hunter') ?></li>
      <li><?= t('Land the kill → an extra') ?> <span class="num">$10.000</span></li>
      <li><?= t('If the Mayor survives the full 15 minutes → they earn') ?> <span class="num">$15.000</span></li>
    </ul>
  </div>
</section>

<section id="caravan">
  <h2>🚐 <?= t('Caravan') ?> — <code>/howto caravan</code></h2>
  <div class="card">
    <p><?= t('A caravan is a trailer you tow behind your own car and can camp at, turning any spot into a temporary spawn point. You must') ?> <span class="num"><?= t('own a caravan') ?></span> - <?= t('an admin gives you one.') ?></p>

    <h4><?= t('Commands') ?></h4>
    <ul>
      <li><code>/attach</code> — <?= t('hook the caravan to your PERSONAL vehicle. You must be driving that vehicle and be near the caravan.') ?></li>
      <li><code>/detach</code> — <?= t('unhook it and park it where you stand. The spot is saved - the caravan reappears there after a restart.') ?></li>
      <li><code>/findmycaravan</code> — <?= t('set a checkpoint to your parked caravan') ?></li>
      <li><code>/camp</code> — <?= t('start camping. You must be driving with the caravan attached.') ?></li>
    </ul>

    <h4><?= t('Towing') ?></h4>
    <p><?= t('While attached, the caravan follows your car. Park on flat ground before') ?> <code>/detach</code>, <?= t('otherwise it can end up tilted or stuck.') ?></p>

    <h4><?= t('Camping — what') ?> <code>/camp</code> <?= t('actually does') ?></h4>
    <p><?= t("Your SPAWN POINT moves to the caravan's spot for") ?> <span class="num">3 <?= t('hours') ?></span> (<?= t('= 3 paydays, since payday runs once an hour). Every time you die or reconnect you respawn at the camp instead of your normal spawn. When it expires, your spawn resets to normal automatically (house, faction or civilian, whatever you had).') ?></p>

    <div class="note"><?= t('This is handy for setting up far from the city - drag the caravan somewhere remote, /camp, and you stop losing time travelling back after every death.') ?></div>
  </div>
</section>

<section id="licence">
  <h2>🪪 <?= t('Licenses') ?> — <code>/howto licence</code></h2>
  <div class="card">
    <p><?= t('You need a license to drive/fly. Pass the exam and pay the fee at the exam spot.') ?></p>
    <p><strong><?= t("Validity depends on the exam vehicle's health:") ?></strong> <?= t('finish with high HP for the FULL duration; a damaged vehicle gives a shorter one (full / damaged):') ?></p>
    <h4><?= t('Driving licenses') ?></h4>
    <ul>
      <li>A (<code>/examA</code>) — <?= t('motorcycles') ?> — 7 / 2 <?= t('days') ?></li>
      <li>B (<code>/examB</code>) — <?= t('cars') ?> — 10 / 3 <?= t('days') ?></li>
      <li>C (<code>/examC</code>) — <?= t('trucks & trailers') ?> — 12 / 3 <?= t('days') ?></li>
      <li>D (<code>/examD</code>) — <?= t('buses') ?> — 13 / 3 <?= t('days') ?></li>
    </ul>
    <h4><?= t('Air licenses') ?></h4>
    <ul>
      <li>P (<code>/examP</code>) — <?= t('airplanes') ?> — 15 / 2 <?= t('days') ?></li>
      <li>H (<code>/examH</code>) — <?= t('helicopters') ?> — 16 / 2 <?= t('days') ?></li>
    </ul>
    <p><?= t("Check yours with") ?> <code>/licenses</code>. <?= t("Rentals and exam vehicles don't need a license.") ?></p>
  </div>
</section>

<section id="farm">
  <h2>🌾 <?= t('Farming') ?> — <code>/howto farm</code></h2>
  <div class="card">
    <p><?= t('Own a field and work the land through a cycle of 5 steps -') ?> <span class="num"><?= t('one step per real day') ?></span>.</p>

    <h4><?= t('Owning a farm') ?></h4>
    <p><?= t('Stand on a for-sale field (look for the pickup + sign) and use') ?> <code>/buyfarm</code>. <?= t('To resell, list it with') ?> <code>/sellfarm [price]</code> - <?= t('another player buys it with /buyfarm and the money goes to your bank (') ?><code>/sellfarm 0</code> <?= t('cancels). Or sell it back to the state instantly with') ?> <code>/sellfarmtostate</code> (60%). <?= t('You can own one farm.') ?></p>

    <h4><?= t('Machines (on your own farm)') ?></h4>
    <ul>
      <li><code>/farm buy [tractor/dozer/combina]</code> — <?= t('parks a machine at the farm (Tractor $10.000, Dozer $15.000, Combine $20.000)') ?></li>
      <li><code>/farm sell</code> — <?= t('sit in a farm machine to sell that one (75% back)') ?></li>
    </ul>

    <h4><?= t('Working (one step per day)') ?></h4>
    <p><?= t('Drive the correct machine for the shown time WITHOUT leaving it:') ?></p>
    <ul>
      <li><code>/farm plow</code> — Tractor, 1 <?= t('min') ?></li>
      <li><code>/farm level</code> — Dozer, 2 <?= t('min') ?></li>
      <li><code>/farm seed</code> — Tractor, 3 <?= t('min') ?></li>
      <li><code>/farm fertilize</code> — Tractor, 1 <?= t('min') ?></li>
      <li><code>/farm harvest</code> — Combine, 4 <?= t('min') ?> → <?= t('paid $15.000, cycle restarts') ?></li>
    </ul>
    <p class="warn"><?= t("If you leave the machine, die or disconnect, the job is cancelled and you lose that day's work (and can't retry until tomorrow).") ?></p>

    <h4><?= t('Info') ?></h4>
    <p><code>/farm stats</code> (<?= t('on a field') ?>) <?= t('and') ?> <code>/farmstats</code> (<?= t('your farm') ?>) <?= t('show the next step, progress and whether you can work today.') ?></p>
  </div>
</section>

<section id="forest">
  <h2>🌲 <?= t('Forests') ?> — <code>/howto forest</code></h2>
  <div class="card">
    <p><?= t('Own a forest and grow trees to fund the Lumberjack job.') ?></p>

    <h4><?= t('Owning a forest') ?></h4>
    <p><?= t('Stand on a for-sale forest (pickup + sign) and use') ?> <code>/buyforest</code>. <?= t('Resell with') ?> <code>/sellforest [price]</code> (<code>/sellforest 0</code> <?= t('cancels') ?>), <?= t('offer it directly with') ?> <code>/sellforestto [playerid] [price]</code>, <?= t('or sell to the state with') ?> <code>/sellforesttostate</code> (60%). <?= t('Check it with') ?> <code>/foreststats</code>.</p>

    <h4><?= t('Trees') ?></h4>
    <p><?= t('Each forest has') ?> <code>currentTree</code>/<code>maxTree</code>. <?= t('It grows') ?> <span class="num"><?= t('+10 per PayDay') ?></span> (<?= t('capped at max') ?>) — <?= t('this is what Lumberjacks cut down with') ?> <code>/chopwood</code>.</p>

    <h4><?= t('Saplings (growing trees faster)') ?></h4>
    <ul>
      <li><?= t('Buy saplings at a') ?> <strong><?= t('Tools Shop') ?></strong> (<span class="num">$10/<?= t('unit') ?></span>) <?= t('while sitting in a') ?> <strong>Benson</strong> — <?= t("you'll be asked how many to buy.") ?></li>
      <li><?= t('Drive the Benson to your forest and use') ?> <code>/forest saplings deposit [amount]</code> <?= t('to store them (max 2x maxTree).') ?></li>
      <li><?= t('A Lumberjack can then plant one: drive a') ?> <strong><?= t('Forklift') ?></strong> <?= t('to the forest and use') ?> <code>/forest tree plant</code>. <?= t('A marker appears inside the forest — get out, switch to a') ?> <strong><?= t('Shovel') ?></strong> <?= t('and press FIRE to plant (pays') ?> <span class="num">$600</span>).</li>
      <li><?= t('Planted saplings are added to') ?> <code>currentTree</code> <?= t('at the next PayDay.') ?></li>
    </ul>
  </div>
</section>

<section id="rob">
  <h2>🔫 <?= t('Robbery') ?> — <code>/howto rob</code></h2>
  <div class="card">
    <p><?= t('Rob a shop or fast-food with your crew - the more people in the car, the bigger the reward.') ?></p>

    <h4><?= t('Requirements') ?></h4>
    <ul>
      <li><?= t('You need') ?> <span class="num">10/10 <?= t('rob points') ?></span> (<?= t('shown in') ?> <code>/stats</code>). <?= t('You gain 1 per payday.') ?></li>
      <li><?= t('You must be the driver of a vehicle, parked next to a shop or fast-food.') ?></li>
    </ul>

    <h4><?= t('Doing it') ?></h4>
    <p><?= t('Drive up to a shop or fast-food and use') ?> <code>/rob</code>.</p>
    <ul>
      <li><?= t('Everyone in the car at that moment becomes the crew and each loses 10 rob points.') ?></li>
      <li><?= t('The whole crew gets wanted level 6 - the police will come!') ?></li>
      <li><?= t('Now deliver the money: a checkpoint appears at a random business. Reach it, then a second business appears. You must reach both.') ?></li>
    </ul>

    <h4><?= t('Payout') ?></h4>
    <p><?= t('After the 2nd business every crew member who is still alive and connected earns') ?> <span class="num"><?= t('$12.000 + $2.000 per crew member + a random bonus up to $5.000') ?></span> <?= t('each. Die or disconnect and you get nothing.') ?></p>
  </div>
</section>

<section id="smuggle">
  <h2>🚤 <?= t('Smuggling') ?> — <code>/smuggle</code></h2>
  <p class="subtitle"><?= t('Mafias only (factions 4-7) - run contraband by boat with your crew.') ?></p>
  <div class="card">
    <p class="note"><?= t('This is a mafia-exclusive mechanic - only members of factions 4-7 can use') ?> <code>/smuggle</code>. <?= t('One successful run per faction, per calendar day (shared cooldown for the whole mafia).') ?></p>

    <h4><?= t('Requirements') ?></h4>
    <ul>
      <li><?= t("You need to be the") ?> <strong><?= t('driver') ?></strong> <?= t("of one of your faction's designated boats (plate") ?> <code>SMG</code>).</li>
    </ul>

    <h4><?= t('Doing it') ?></h4>
    <p><?= t('Use') ?> <code>/smuggle</code> <?= t('while driving. Everyone else riding in the boat at that moment is auto-added as crew (up to') ?> <span class="num">6</span> <?= t('people).') ?></p>
    <ul>
      <li><strong>1. <?= t('Loading:') ?></strong> <?= t('drive the boat to the fixed loading point. Reaching it freezes the driver for') ?> <span class="num">10 <?= t('seconds') ?></span> ("<?= t('Loading cargo...') ?>"), <?= t('then every crew member gets') ?> <span class="num"><?= t('wanted level 6') ?></span> <?= t("and Police + News are alerted with your leader's name.") ?></li>
      <li><strong>2. <?= t('Collection x2:') ?></strong> <?= t('two random collection points (out of 6 possible) are chosen. Drive the boat to each one; every stop freezes the driver for') ?> <span class="num">5 <?= t('seconds') ?></span> ("<?= t('Collecting cargo...') ?>").</li>
      <li><strong>3. <?= t('Delivery:') ?></strong> <?= t('a random hotel on the server is chosen as the drop-off. Get into your faction\'s') ?> <strong>Sultan</strong> (<?= t('as driver OR passenger') ?>) <?= t('and reach the hotel to complete the run.') ?></li>
    </ul>

    <h4><?= t('Payout') ?></h4>
    <p><?= t('On delivery, the faction vault gets') ?> <span class="num">$25.000</span> + <span class="num">500g</span> <?= t("weed (capped by the vault's herb space), each crew member who is still alive, connected and was part of the run earns") ?> <span class="num">$2.000-$3.000</span>, <?= t("and everyone's wanted level drops from 6 to") ?> <span class="num">5</span>.</p>
    <p class="warn"><?= t('If the leader (boat driver) is arrested or killed before delivery, the whole run is cancelled - nobody gets paid. Police earn a') ?> <span class="num">$5.000</span> <?= t('bounty (to their faction bank) for every smuggler they catch mid-run.') ?></p>
  </div>
</section>

<section id="skins">
  <h2>🧍 <?= t('Skins & Clothes') ?> — <code>/howto skins</code></h2>
  <div class="card">
    <p><?= t('Change how your character looks by buying and wearing outfits (skins).') ?></p>

    <h4><?= t('Clothing store') ?></h4>
    <p><?= t('Go to a store marked with the clothes icon on the map.') ?></p>
    <ul>
      <li><code>/skins</code> — <?= t('browse the catalogue and buy an outfit (') ?><span class="num">$10.000</span> <?= t('each). Buying an outfit also puts it on.') ?></li>
      <li><code>/wardrobe</code> — <?= t('switch between outfits you already own, for free.') ?></li>
    </ul>
    <p><?= t('Outfits you buy are yours forever - you can swap between them anytime at a store.') ?></p>

    <h4><?= t('Faction uniform') ?></h4>
    <p><?= t('Factions have 3 uniforms by rank (rank 1/2, rank 3/4, rank 5). You wear the one for your rank automatically when you spawn on duty (faction spawn); as a civilian you wear your own outfit. Inside your faction HQ you can use') ?> <code>/changeskin</code> <?= t('to switch between your uniform and civilian clothes.') ?></p>
  </div>
</section>

<section id="casino">
  <h2>🎰 <?= t('Casino') ?> — <code>/howto casino</code></h2>
  <div class="card">
    <p><?= t('Try your luck at the Casino (casino icon on the map).') ?></p>

    <h4><?= t('Getting in') ?></h4>
    <p><?= t('Walk to the entrance and press ENTER (or type') ?> <code>/enter</code>). <?= t('Leave anytime with ENTER at the door or') ?> <code>/leavecasino</code>.</p>

    <h4><?= t('Games — each is played at its own table (look for the signs)') ?></h4>
    <ul>
      <li><code>/slots [bet]</code> — <?= t('at a slot machine. Three Sevens = x10, any other three of a kind = x5, two Sevens = x2.') ?></li>
      <li><code>/roulette [red/black/even/odd/0-36] [bet]</code> — <?= t('at a roulette table. Color/parity pays x2 (0 loses), exact number pays x36.') ?></li>
      <li><code>/dice [bet]</code> — <?= t('at the dice area. You and the house each roll two dice; higher total wins x2, a tie returns your bet.') ?></li>
    </ul>

    <div class="note"><?= t('Gamble responsibly - the house always has the edge!') ?></div>
  </div>
</section>

<section id="religion">
  <h2>⛪ <?= t('Religion & Sins') ?> — <code>/howto religion</code></h2>
  <p class="subtitle"><?= t('Pick a faith, pray daily, confess on Sunday') ?></p>

  <div class="card">
    <h4><?= t('Choosing a religion') ?></h4>
    <p><?= t('Right after you register the server invites you to pick one with') ?> <code>/setreligion</code>. <?= t('Read what each believes with') ?> <code>/whatreligion</code>:</p>
    <ul>
      <li><strong>Ateu</strong> — <?= t('the rationalists: no supernatural, only natural law, science and reason') ?></li>
      <li><strong><?= t('The Ascendants') ?></strong> — <?= t('a modern church: humanity elevating itself through knowledge and progress') ?></li>
      <li><strong><?= t('The Holy Order') ?></strong> — <?= t('medieval tradition: sacrifice, asceticism, honour and divine law') ?></li>
      <li><strong><?= t('The Divine Blessing') ?></strong> (Santa Luz) — <?= t('a colonial church: community, honest work and harmony with nature') ?></li>
    </ul>
    <p><?= t('There are') ?> <span class="num">3</span> <?= t('churches on the map —') ?> <strong>Ascendant Spire</strong>, <strong>Holy Order Chapel</strong> <?= t('and') ?> <strong>Santa Luz Chapel</strong> — <?= t('all listed in your GPS.') ?></p>
  </div>

  <div class="card">
    <h4><?= t('The 12 sins —') ?> <code>/sinlist</code></h4>
    <p><?= t('You never tick a sin yourself. The server flags them automatically while you play, and the whole table is wiped every') ?> <strong><?= t('Monday at 00:00') ?></strong>.</p>
    <table>
      <tr><th>#</th><th><?= t('Sin') ?></th><th><?= t('How you get it') ?></th></tr>
      <tr><td class="num">1</td><td><?= t('Defying the Law') ?></td><td><?= t('An officer gives you a wanted level') ?></td></tr>
      <tr><td class="num">2</td><td><?= t('Greed for Money') ?></td><td><?= t('You start a robbery (') ?><code>/rob</code>)</td></tr>
      <tr><td class="num">3</td><td><?= t('The Vice of Gambling') ?></td><td><?= t('You place any bet at the casino') ?></td></tr>
      <tr><td class="num">4</td><td><?= t('Anti-Nature') ?></td><td><strong><?= t('Guilty by default.') ?></strong> <?= t('Clear it by planting a tree or doing one Water Hauler shift') ?></td></tr>
      <tr><td class="num">5</td><td><?= t('Trafficking Without Restraint') ?></td><td><?= t('You get paid on a') ?> <code>/smuggle</code> <?= t('run') ?></td></tr>
      <tr><td class="num">6</td><td><?= t('Bloody Revenge') ?></td><td><?= t('You kill another player') ?></td></tr>
      <tr><td class="num">7</td><td><?= t('Witness to Illegal Vehicle Modifications') ?></td><td><?= t("You're a") ?> <em><?= t('passenger') ?></em> <?= t('in a car being tuned by Loco Outlaw Customs') ?></td></tr>
      <tr><td class="num">8</td><td><?= t('Reckless Speeding') ?></td><td><?= t('A police radar catches you over the limit') ?></td></tr>
      <tr><td class="num">9</td><td><?= t('Time Served Behind Bars') ?></td><td><?= t('You get arrested, or turn yourself in with') ?> <code>/arrestme</code></td></tr>
      <tr><td class="num">10</td><td><?= t('Drink and Vice') ?></td><td><?= t('You drink at a bar or party, or use drugs') ?></td></tr>
      <tr><td class="num">11</td><td><?= t('Breaking the Fast') ?></td><td><?= t('You eat fast food on a') ?> <strong><?= t('Wednesday or Friday') ?></strong></td></tr>
      <tr><td class="num">12</td><td><?= t('Disregard for Road Law') ?></td><td><?= t('You try to drive or fly without a valid license') ?></td></tr>
    </table>
  </div>

  <div class="card">
    <h4><?= t('Praying —') ?> <code>/pray</code></h4>
    <p><?= t("Once per day, any day. Every prayer is counted for that week, and that count is what decides whether Sunday's confession pays out at all.") ?></p>

    <h4><?= t('Sunday confession') ?></h4>
    <p><?= t('On Sunday,') ?> <code>/pray</code> <?= t('also opens a panel listing all 12 sins. Click the ones you think you committed — they turn') ?> <span style="color:#6bd66b"><?= t('green') ?></span>, <?= t('click again to untick — then press') ?> <strong><?= t('ASK FORGIVENESS') ?></strong>. <?= t("You're frozen for") ?> <span class="num">5</span> <?= t('seconds plus one per confessed sin while the priest prays, then the server compares your list against what really happened.') ?></p>

    <table>
      <tr><th><?= t('How well you remembered') ?></th><th><?= t('What you get') ?></th></tr>
      <tr><td><strong><?= t('Wrong on 2+ sins') ?></strong></td><td><?= t('Forgiven anyway — health 100, tiredness 0, illness cured') ?></td></tr>
      <tr><td><strong><?= t('Wrong on exactly 1') ?></strong></td><td><?= t('The above + every personal vehicle cleaned +') ?> <span class="num">$25.000</span></td></tr>
      <tr><td><strong><?= t('All 12 correct') ?></strong></td><td><?= t('The above + a full tank in every personal vehicle +') ?> <strong><?= t('+1 day on every license') ?></strong> (<?= t('an expired one becomes valid again today') ?>) + <span class="num">$50.000</span></td></tr>
    </table>

    <div class="note"><?= t('Those rewards only unlock if you prayed at least') ?> <strong><?= t('4 times') ?></strong> <?= t('that week. The prayer bonus is paid out regardless:') ?> <strong><?= t('$5.000 per prayer') ?></strong> <?= t('that week, plus a small random top-up.') ?></div>
  </div>

  <div class="card">
    <h4><?= t('Weekly quests —') ?> <code>/quest</code></h4>
    <p><?= t('Each religion has its own 2 fixed weekly quests, tied to what it believes in. Check your progress and claim finished quests with') ?> <code>/quest</code>. <?= t('They reset every') ?> <strong><?= t('Monday at 00:00') ?></strong>, <?= t('same as the sins table.') ?></p>
    <table>
      <tr><th><?= t('Religion') ?></th><th><?= t('Quest') ?></th><th><?= t('Goal') ?></th><th><?= t('Reward') ?></th></tr>
      <tr><td rowspan="2"><strong>Ateu</strong></td><td><?= t('Financial Independence') ?></td><td><?= t('Send') ?> <code>/pay</code> <?= t('to another player once') ?></td><td class="num">$10.000</td></tr>
      <tr><td><?= t('Clean by Choice') ?></td><td><?= t("Go the whole week without defying the law (sin 1)") ?></td><td class="num">$10.000</td></tr>
      <tr><td rowspan="2"><strong><?= t('The Ascendants') ?></strong></td><td><?= t('Elevate Your Ride') ?></td><td><?= t('Install') ?> <span class="num">3</span> <?= t('tuning parts at Loco Outlaw Customs') ?></td><td class="num">$10.000</td></tr>
      <tr><td><?= t('Air Superiority') ?></td><td><?= t('Complete') ?> <span class="num">3</span> <?= t('Crop Duster Pilot runs') ?></td><td class="num">$10.000</td></tr>
      <tr><td rowspan="2"><strong><?= t('The Holy Order') ?></strong></td><td><?= t('Trial by Fire') ?></td><td><?= t('Complete') ?> <span class="num">3</span> <?= t('Fuel Carrier runs') ?></td><td class="num">$10.000</td></tr>
      <tr><td><?= t('Respect for Order') ?></td><td><?= t('Go the whole week without driving on an expired license (sin 12)') ?></td><td class="num">$10.000</td></tr>
      <tr><td rowspan="2"><strong><?= t('The Divine Blessing') ?></strong></td><td><?= t('Seeds of Blessing') ?></td><td><?= t('Plant') ?> <span class="num">3</span> <?= t('tree saplings') ?></td><td class="num">$10.000</td></tr>
      <tr><td><?= t('Waters of Life') ?></td><td><?= t('Water the plants') ?> <span class="num">2</span> <?= t('times as a Water Hauler') ?></td><td class="num">$10.000</td></tr>
    </table>
    <div class="note"><?= t("The 'Clean by Choice' and 'Respect for Order' quests aren't tracked separately — they just check that you didn't commit that sin this week, same table as") ?> <code>/sinlist</code>.</div>
  </div>
</section>

</main>

<?php include __DIR__ . '/../includes/footer.php'; ?>

</body>
</html>
