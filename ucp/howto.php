<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_login();
?>
<!DOCTYPE html>
<html lang="ro">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nostalgia: Los Santos UCP — How To</title>
<style>
  :root {
    --bg: #0f1115;
    --panel: #161922;
    --panel-2: #1d212c;
    --border: #2a2f3d;
    --text: #d8dce5;
    --muted: #8b93a7;
    --accent: #5b9dff;
    --accent-2: #ffcc00;
    --green: #3ecf8e;
    --red: #ff5d5d;
    --topbar-h: 90px;
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.65;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }

  header.topbar {
    display: flex; align-items: center; justify-content: space-between;
    flex-wrap: wrap; row-gap: 8px;
    padding: 14px 24px;
    background: var(--panel);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0; z-index: 100;
    min-height: var(--topbar-h);
  }
  header.topbar .brand { display: flex; align-items: center; gap: 9px; font-weight: 700; font-size: 1.1rem; color: #fff; text-decoration: none; }
  header.topbar .brand:hover { text-decoration: none; opacity: 0.9; }
  header.topbar .brand-logo { height: 34px; width: auto; border-radius: 6px; }
  header.topbar nav { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 16px; }
  header.topbar nav a { color: var(--text); font-size: 0.92rem; }
  header.topbar nav a:hover { color: var(--accent); }
  header.topbar .userbox { color: var(--muted); font-size: 0.88rem; }

  .nav-dd { position: relative; }
  .nav-dd-menu {
    display: none;
    position: absolute; top: 100%; left: 0; margin-top: 0;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: 8px;
    min-width: 200px; padding: 6px; z-index: 200;
    box-shadow: 0 10px 28px rgba(0,0,0,0.45);
  }
  .nav-dd-menu a { display: block; padding: 7px 10px; border-radius: 6px; font-size: 0.88rem; white-space: nowrap; }
  .nav-dd-menu a:hover { background: var(--panel); }
  .nav-dd:hover .nav-dd-menu, .nav-dd:focus-within .nav-dd-menu { display: block; }

  header.hero {
    padding: 40px 24px 30px;
    text-align: center;
    background: radial-gradient(ellipse at top, #1b2030 0%, #0f1115 70%);
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
    background: rgba(15,17,21,0.94);
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
  nav.toc a:hover { color: var(--accent); border-color: var(--accent); text-decoration: none; }

  main { max-width: 1400px; margin: 0 auto; padding: 36px 24px 100px; }

  section { margin-bottom: 46px; scroll-margin-top: 60px; }
  section h2 { font-size: 1.5rem; margin: 0 0 4px; color: #fff; }
  section .subtitle { color: var(--muted); margin: 0 0 16px; font-size: 0.92rem; }

  .card {
    background: var(--panel);
    border: 1px solid var(--border);
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
    border-left: 3px solid var(--accent-2);
    background: rgba(255,204,0,0.06);
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

<?php include __DIR__ . '/includes/header.php'; ?>

<header class="hero">
  <h1>📖 Ghid How To</h1>
  <p>Tot conținutul comenzii <code>/howto</code> din joc, într-un singur loc. Fiecare secțiune corespunde unui subiect <code>/howto [subiect]</code>.</p>
</header>

<nav class="toc">
  <a href="#jobs">Jobs</a>
  <a href="#factions">Factions</a>
  <a href="#vehicles">Vehicles</a>
  <a href="#business">Business</a>
  <a href="#house">House</a>
  <a href="#hotel">Hotel</a>
  <a href="#games">Games</a>
  <a href="#caravan">Caravan</a>
  <a href="#licence">Licence</a>
  <a href="#farm">Farm</a>
  <a href="#rob">Rob</a>
  <a href="#skins">Skins</a>
  <a href="#casino">Casino</a>
</nav>

<main>

<section id="jobs">
  <h2>💼 Jobs — <code>/howto job</code></h2>
  <p class="subtitle">Comanda de bază: <code>/howto job [1-8]</code> pentru un job anume</p>
  <div class="card">
    <p>Jobs let you earn money doing deliveries.</p>
    <ul>
      <li><code>/jobs</code> — list all jobs</li>
      <li><code>/getjob [id or name]</code> — take a job (at the Job Center in City Hall)</li>
      <li><code>/job</code> — start working (be in your job vehicle)</li>
      <li><code>/stopwork</code> — stop working</li>
      <li><code>/joblist</code> — see job vehicle locations (admin teleport)</li>
    </ul>
    <p>Most jobs: drive to the LOAD point, make 2 deliveries (UNLOAD), then return to load. Follow the checkpoints.</p>
  </div>

  <div class="subtopic-grid">
    <div class="card">
      <h3>1 — Glovo Delivery</h3>
      <p>Food courier. Take it with <code>/getjob 1</code>. Get in your job bike/car (see <code>/joblist</code>), then <code>/job</code> to start.</p>
      <p>Drive to the marked restaurant to load, deliver to 2 houses, then return to load.</p>
      <p><code>/getjob 1</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>2 — Cement Truck Driver</h3>
      <p>Haul cement. Take it with <code>/getjob 2</code>. Get in a cement truck, then <code>/job</code>.</p>
      <p>Load at the marked plant, unload at 2 sites, then return to load.</p>
      <p><code>/getjob 2</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>3 — Gun Delivery</h3>
      <p>Deliver weapons. Take it with <code>/getjob 3</code>. Get in the job vehicle, then <code>/job</code>.</p>
      <p>Load weapons at the marked spot, deliver to 2 drop-offs (fixed points or mafia HQs), then return to load.</p>
      <p><code>/getjob 3</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>4 — Car Transportator</h3>
      <p>Transport vehicles. Take it with <code>/getjob 4</code>. Get in the transporter, then <code>/job</code>.</p>
      <p>Load at the marked spot, unload at 2 businesses, then return to load.</p>
      <p><code>/getjob 4</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>5 — Uber</h3>
      <p>Drive players around for money. Take it with <code>/getjob 5</code>. Use <code>/fare [amount]</code> in your PERSONAL vehicle to go on duty.</p>
      <p>When a player uses <code>/service uber</code>, use <code>/accept uber</code> to take the ride. The passenger is charged over time until they get out.</p>
      <p><code>/getjob 5</code>, <code>/fare</code>, <code>/service</code>, <code>/accept</code></p>
    </div>
    <div class="card">
      <h3>6 — Emergency Logistics Driver</h3>
      <p>Deliver medical supplies. Take it with <code>/getjob 6</code>. Get in a depot vehicle (Bobcat / Burrito), then <code>/job</code>.</p>
      <p>Load at the marked depot, deliver to 2 shops, then return to load.</p>
      <p><code>/getjob 6</code>, <code>/job</code>, <code>/stopwork</code>, <code>/joblist</code></p>
    </div>
    <div class="card">
      <h3>7 — Bus Driver</h3>
      <p>Drive fixed routes. Take it with <code>/getjob 7</code>. Get in a depot bus and use <code>/bus [1-3]</code> to start a route.</p>
      <p>You earn at each checkpoint, plus $100 for every passenger that boards.</p>
      <p><code>/getjob 7</code>, <code>/bus [1-3]</code>, <code>/stopwork</code></p>
    </div>
    <div class="card">
      <h3>8 — Electrician</h3>
      <p>Repair broken appliances and devices for a fee. Take it with <code>/getjob 8</code>.</p>
      <ul>
        <li><code>/findbrokenitems</code> — checkpoint to a nearby house that needs a repair</li>
        <li><code>/fixfridge</code> / <code>/fixbed</code> — fix a house's fridge/bed (within 5 days of breaking), paid from the house's own bank ($2.000 / $1.000)</li>
        <li><code>/fixapartament</code> — fix an active apartment issue (flood/sewage/electrical), paid from the house's bank ($3.000)</li>
        <li><code>/fixphone [playerid] [amount]</code> / <code>/fixwatch [playerid] [amount]</code> — offer to fix a nearby player's broken phone/watch; they confirm with <code>/accept fixphone</code> or <code>/accept fixwatch</code></li>
      </ul>
    </div>
  </div>
</section>

<section id="factions">
  <h2>🚓 Factions — <code>/howto faction</code></h2>
  <p class="subtitle">Comanda de bază: <code>/howto faction [1-8]</code> pentru o facțiune anume</p>
  <div class="card">
    <p>Factions: Police (1), R.A.R. (2), SMURD (3), Mafias (4-7), News (8).</p>
    <p>Joining: a rank 4+ member invites you with <code>/finvite</code>; you accept with <code>/accept [id]</code> (be within 15m).</p>
    <ul>
      <li><code>/f [text]</code> — faction chat</li>
      <li><code>/fmembers</code> — list members</li>
      <li><code>/duty</code> — go on/off duty (factions 1-3, inside the HQ)</li>
    </ul>
  </div>

  <div class="subtopic-grid">
    <div class="card">
      <h3>1 — Politia Romana</h3>
      <p>Law enforcement. Go on/off duty with <code>/duty</code> (inside the HQ). Only on-duty officers have police powers.</p>
      <ul>
        <li><code>/wanted [player] [0-6] [reason]</code> — set a suspect's wanted level</li>
        <li><code>/arrest [player]</code> — jail a wanted suspect (at an arrest zone)</li>
        <li><code>/m [player]</code> — megaphone: order a driver to pull over (in a faction vehicle, within 50m)</li>
        <li><code>/radar install [limit]</code> — set up a speed radar and sanction speeders (<code>/radar remove</code>)</li>
        <li><code>/garage</code>, <code>/entrace</code> — move around the station; press H near the LSPD barrier to open it</li>
      </ul>
      <h4>Vehicle checks</h4>
      <p>Police can inspect papers and confiscate: <code>/checklicenses [player]</code>, <code>/suspendlic</code>, <code>/confiscate insurance [player]</code> (rank 2+), <code>/confiscate licence [A/B/C/D/P/H/all] [player]</code> — driving + airplane (P) &amp; helicopter (H) licenses.</p>
    </div>
    <div class="card">
      <h3>2 — Registrul Auto Roman (R.A.R.)</h3>
      <p>Vehicle registry &amp; inspections. Members run the R.A.R. HQ, where drivers renew their vehicle documents (<code>/vitp</code> inspection, <code>/vplate</code>, <code>/vInsurance</code>).</p>
      <p><code>/fine [player] [amount] [reason]</code> — fine a driver.</p>
      <h4>Checks &amp; confiscation (rank 3+, on-duty)</h4>
      <p><code>/confiscate medkit / extinctor / itp [player]</code> — take those items/documents.</p>
      <h4>Impounding</h4>
      <p>If your ITP is expired, R.A.R. can tow your car with a Towtruck and impound it (<code>/towpark</code>) — the engine won't start. Go to the car and use <code>/redeemcar</code> to pay the release fee and get it back with ITP valid until the end of the day.</p>
    </div>
    <div class="card">
      <h3>3 — SMURD</h3>
      <p>Emergency medical &amp; fire service.</p>
      <h4>Medical</h4>
      <p><code>/heal [player]</code> — heal a player who is a passenger in your ambulance (paid). Sick players come to the hospital to <code>/curedisease</code>.</p>
      <h4>Firefighting</h4>
      <p>Fires can break out anywhere on the map. On duty, take the Firetruck, drive within 25m of the fire, and hold the FIRE button (spray water) to put it out.</p>
    </div>
    <div class="card">
      <h3>4-7 — Mafias</h3>
      <p>Organized crime family. Mafias run drugs and fight over territory.</p>
      <ul>
        <li><code>/drugs transport</code> — haul weed to the vault</li>
        <li><code>/drugs craft</code> — turn weed into drugs</li>
        <li><code>/drugs get</code> / <code>use</code> — take &amp; use drugs during a war</li>
        <li><code>/seif</code> — the faction vault (rank 4+)</li>
        <li><code>/equip</code> — get weapons inside the HQ</li>
        <li><code>/smuggle</code> — run contraband by boat: drive a designated boat (plate SMG) to the loading point (10s freeze), then to 2 random collection points (5s freeze each). At loading, Police are alerted and everyone aboard gets wanted 6. Finally, switch to your faction's Sultan (driver or passenger) and deliver it to a random hotel: wanted drops to 5, the vault gets $25.000 + 500g weed, and each living crew member earns $2.000-3.000. The Police get a bounty for every smuggler they catch. One successful run per faction per day.</li>
        <li><code>/war</code> — start a turf war</li>
        <li><code>/warsurrender</code> — surrender an ongoing war (rank 4+)</li>
      </ul>
      <p>Each mafia controls its own territories.</p>
    </div>
    <div class="card">
      <h3>8 — News Reporters</h3>
      <p>The press. They inform the city via live broadcasts, live interviews and the newspaper.</p>
      <h4>Live news (rank 1+)</h4>
      <p><code>/news [text]</code> — broadcast a headline to everyone.</p>
      <h4>Live Q&amp;A / interviews (rank 3+)</h4>
      <ul>
        <li><code>/qa [player]</code> — start a live interview (the guest accepts with <code>/accept qa</code>)</li>
        <li><code>/qa list</code> — see submitted questions</li>
        <li><code>/qa ask [nr]</code> — ask one live</li>
        <li><code>/qa del [nr]</code> — remove one</li>
        <li><code>/qa end</code> — stop the Q&amp;A</li>
      </ul>
      <p>Anyone can <code>/question [text]</code> to submit; the guest replies with <code>/answer [text]</code>.</p>
      <h4>Newspaper</h4>
      <ul>
        <li><code>/newspaper create</code> — start a new edition</li>
        <li><code>/newspaper edit [1-5] [text]</code> — write up to 5 stories</li>
        <li><code>/newspaper sell</code> — put it on sale</li>
        <li><code>/newspaper open</code> — read the current newspaper</li>
      </ul>
    </div>
  </div>

  <div class="card">
    <h4>Leadership (any faction, rank 4/5)</h4>
    <ul>
      <li><code>/finvite [player]</code>, <code>/fbank</code> (rank 4+)</li>
      <li><code>/fsetrank [player] [1-5]</code>, <code>/fbankwithdraw</code> (rank 5 Lead)</li>
      <li><code>/fkick</code> (or <code>/funinvite</code>) <code>[player]</code> — remove a member (rank 5 Lead)</li>
      <li><code>/refillfactionveh</code>, <code>/respawnfactionveh</code> — refuel/respawn all faction vehicles (Lead)</li>
    </ul>
  </div>
</section>

<section id="vehicles">
  <h2>🚗 Vehicles — <code>/howto vehicle</code></h2>
  <div class="card">
    <p>Buy vehicles from dealerships. You need a matching driving license to drive one (see <a href="#licence">Licence</a>). You can own up to <span class="num">3</span> personal vehicles (slots 1-3).</p>

    <h4>Buying &amp; selling</h4>
    <ul>
      <li><code>/vbuy</code> — buy the dealership vehicle you are sitting in</li>
      <li><code>/sellveh [price]</code> — list the vehicle you're driving for sale at that price</li>
      <li><code>/sellveh 0</code> — cancel the listing</li>
      <li><code>/sellvehtostate</code> — sell it back to the state instantly (<span class="num">60%</span>)</li>
      <li><code>/vsellto [playerid]</code> — offer the vehicle you're driving directly to a nearby player</li>
    </ul>

    <h4>Info &amp; navigation</h4>
    <ul>
      <li><code>/vstats</code> — all your vehicles: documents, fuel and dirt level</li>
      <li><code>/myveh1</code> / <code>/myveh2</code> / <code>/myveh3</code> — checkpoint to the vehicle in that slot</li>
    </ul>

    <h4>Using your vehicle</h4>
    <ul>
      <li><code>/engine</code> — start/stop the engine · <code>/lock</code> — lock/unlock the doors</li>
      <li><code>/vpark</code> — save the current spot as its permanent spawn point</li>
      <li><code>/vcolor [1/2] [colorID]</code> — repaint (1 = primary, 2 = secondary)</li>
      <li><code>/changecar [engine/lights/alarm/doors/hood/boot]</code> — toggle a component of the vehicle you drive</li>
    </ul>
    <p>You can also press the horn key for lights, and the analog up/down keys for hood/boot while driving.</p>

    <h4>Fuel</h4>
    <p>Every vehicle burns fuel while the engine runs.</p>
    <ul>
      <li><code>/refuel</code> — refuel at a gas station (paid)</li>
      <li><code>/fillgascan</code> — fill your gas can at a gas station (buy the can at <code>/shop</code>)</li>
      <li><code>/fill</code> — empty a FULL gas can into the vehicle you're in - use it when you run dry far from a station</li>
    </ul>

    <h4>Documents &amp; items (all at R.A.R.)</h4>
    <ul>
      <li><code>/vinsurance</code> — insurance, <span class="num">$500</span>, valid <span class="num">5 days</span></li>
      <li><code>/vitp</code> — ITP inspection, <span class="num">$750</span>, valid <span class="num">15 days</span> (engine off, hood open, boot closed, lights on)</li>
      <li><code>/vplate</code> — number plate, <span class="num">$250</span>, no expiry</li>
      <li><code>/v install medicalkit</code> — fit a medical kit bought at /shop (<span class="num">$500</span>), valid <span class="num">7 days</span></li>
      <li><code>/v install extinctor</code> — fit an extinguisher bought at /shop (<span class="num">$500</span>), valid <span class="num">10 days</span></li>
    </ul>
    <p>A document is valid for the WHOLE day it expires on - only the next day does it count as expired.</p>

    <h4>Police &amp; R.A.R.</h4>
    <p>They can inspect your car and confiscate it or its documents. Use <code>/redeemcar</code> to buy back a vehicle that was confiscated or towed.</p>

    <h4>Dirty vehicles</h4>
    <p>Your car gets dirtier every time it respawns (<span class="num">+8-12</span> each time). At <span class="num">75</span> you're warned to wash it; above <span class="num">90</span> the engine won't start at all. Use <code>/vwash</code> at a CarWash (<span class="num">$100</span>) to clean it.</p>

    <h4>Renting (no license needed)</h4>
    <p><code>/rentcar</code> — rent a car at a rental point · <code>/rentbike</code> — rent a bicycle (<span class="num">$15</span>)</p>
  </div>
</section>

<section id="business">
  <h2>🏢 Businesses — <code>/howto business</code></h2>
  <div class="card">
    <p>A business earns <span class="num">passive income</span> into its own bank whenever players use the activity it covers - you don't have to be online. You can own only <span class="num">ONE</span> business at a time. Stand on the pickup to interact.</p>

    <h4>Buying &amp; selling</h4>
    <ul>
      <li><code>/buybiz</code> — buy the business you're standing in (sold by the server or another player)</li>
      <li><code>/biz sell [price]</code> — list it for sale at that price; money goes to your bank when someone buys it with <code>/buybiz</code></li>
      <li><code>/biz sell 0</code> — cancel the listing</li>
      <li><code>/biz sellto [playerid] [amount]</code> — offer it directly to a nearby player; they buy it with cash via <code>/accept biz [yourid]</code></li>
      <li><code>/biz selltostate</code> — sell it back to the state instantly for <span class="num">60%</span> of its value</li>
    </ul>

    <h4>Money &amp; info</h4>
    <ul>
      <li><code>/bbank</code> — show the business bank balance (stand on it)</li>
      <li><code>/biz withdraw [amount]</code> — withdraw earnings from the business bank</li>
      <li><code>/mybiz</code> — set a checkpoint to the business you own</li>
      <li><code>/mybank</code> — list all your property accounts (near a bank/ATM)</li>
      <li><code>/mybank biz deposit [amount]</code> / <code>withdraw [amount]</code> — move money in/out of the business bank (near a bank/ATM)</li>
    </ul>

    <h4>Where the income comes from</h4>
    <p>Each business is tied to an activity, and takes a cut every time someone uses it - fast-food orders (<code>/pizza</code>, <code>/burger</code>, <code>/meal</code>, <code>/desert</code>), the ATM withdrawal fee, phone &amp; SIM sales, SMS and calls, fridge shopping, appliances (fridge/bed), Glovo deliveries and exam fees. The busier the activity, the more it earns.</p>

    <h4>ANAF audits</h4>
    <p>Once a day at <span class="num">12:00</span>, a random owned business gets flagged - it earns <span class="warn">nothing</span> until cleared. You're warned on respawn if yours is hit.</p>
    <ul>
      <li>Drive a <span class="num">vehicle model 428</span> to your business and use <code>/biz getdocs</code></li>
      <li>Drive to <span class="num">ANAF</span> and use <code>/biz givedocs</code> - your business is cleared at the next payday</li>
    </ul>
  </div>
</section>

<section id="house">
  <h2>🏠 Houses — <code>/howto house</code></h2>
  <div class="card">
    <p>A house is your spawn point and storage. You can own only ONE. Stand on the pickup to interact; be at YOUR OWN house for the fridge/bed/tree/animal/SGR/trash commands.</p>

    <h4>Buy &amp; sell</h4>
    <ul>
      <li><code>/buyhouse</code> — buy the house you stand on (from server or a player)</li>
      <li><code>/house sell [price]</code> — list for sale (money to your bank when sold); <code>/house sell 0</code> cancels</li>
      <li><code>/house sellto [playerid] [amount]</code> — offer it directly to a player (cash, via /accept house)</li>
      <li><code>/house selltostate</code> — sell to the state for <span class="num">60%</span></li>
    </ul>

    <h4>Renting</h4>
    <p><code>/renthouse</code> / <code>/rentappartment</code> — rent a nearby rentable one (blocked if you own/rent already). <code>/endrent</code> to give it up.</p>

    <h4>Info</h4>
    <ul>
      <li><code>/hstats</code> — name, ID, price, type, fridge contents + break dates</li>
      <li><code>/myhouse</code> / <code>/findhouse [id]</code> — checkpoint to your house / any house</li>
      <li><code>/mybank house deposit|withdraw [amount]</code> — house bank (near a bank/ATM)</li>
    </ul>
    <p>If the house has an interior, press <span class="num">ENTER</span> at the pickup to go in/out.</p>

    <h4>Upgrades — <code>/house upgrade [frigde/bed/tree/animal]</code></h4>
    <ul>
      <li><code>frigde</code> — <span class="num">$10.000</span>, breaks after <span class="num">32 days</span></li>
      <li><code>bed</code> — <span class="num">$7.500</span>, breaks after <span class="num">29 days</span></li>
      <li><code>tree</code> — <span class="num">$20.000</span> (city or countryside house), unlocks <code>/tree plant</code></li>
      <li><code>animal [name]</code> — <span class="num">$5.000</span>: Turtle/Deer (Villa only), Cow (countryside only)</li>
    </ul>
    <p>Same command replaces a broken fridge/bed (1% to Home Furnitures).</p>

    <h4>Fridge — <code>/frigde</code></h4>
    <ul>
      <li><code>/frigde</code> — view contents</li>
      <li><code>/frigde buy [item] [qty]</code> — stock milk/banana/water/juice/beer, only <span class="num">15:00-20:00</span></li>
      <li><code>/frigde use [item]</code> — eat/drink one for HP</li>
    </ul>
    <p>Price/max/HP: Milk $100/20L/+20, Banana $50/30/+10, Water $150/25L/+25, Juice $200/20L/+15, Beer $250/50L/+10.</p>
    <p class="warn">A broken fridge loses everything inside and is unusable until replaced.</p>

    <h4>Tree — <code>/tree [plant/collect]</code></h4>
    <p>Unlocked by <code>/house upgrade tree</code> (city/countryside); <code>/tree plant</code> needs a Shovel (5s). Grows +1/payday (max 30): 12-20 = 8-11 bananas, 21-29 = 1-3, 30 = 0 + resets.</p>

    <h4>SGR/Trash</h4>
    <p>Fridge drinks leave SGR bottles, fridge food leaves trash (max 100 each, warned at 80).</p>
    <ul>
      <li><code>/sgrload</code>/<code>/trashload</code> — at your house, in an SGR van/garbage truck</li>
      <li><code>/sgrunload</code>/<code>/trashunload</code> — at the unload point; house bank gets $50/$30 each</li>
    </ul>

    <h4>Tiredness &amp; <code>/sleep</code></h4>
    <p>+2/min; 80+ costs extra HP. Home bed: free, 30s, to 0. Any hotel: $150, 45s, to 10 (see <a href="#hotel">Hotel</a>).</p>

    <h4>Cow</h4>
    <p>Gives a 50% chance/payday (while online) of 2-5L milk straight into your fridge.</p>

    <h4>Repairs</h4>
    <p>An Electrician can fix your fridge/bed in the last 5 days before they break, paid from the house bank ($2.000/$1.000), adding 15 days.</p>
  </div>
</section>

<section id="hotel">
  <h2>🏨 Hotels — <code>/howto hotel</code></h2>
  <div class="card">
    <p>A hotel is an ownable property (like a house) where <span class="num">any</span> player can pay to sleep - no bed and no ownership required. It's a passive income property: guests pay, the owner collects. You can own only ONE hotel at a time.</p>

    <h4>What you can do AT a hotel (anyone)</h4>
    <ul>
      <li><code>/sleep</code> — rent a room for <span class="num">$150</span>. You freeze for <span class="num">45 seconds</span>, then your tiredness drops to <span class="num">10</span>. It does NOT have to be your own hotel, and you don't need a bed. Just stand at the hotel pickup. Compared to sleeping at home (free, 30s, tiredness → 0), a hotel is the paid option when you're away from your house or don't own a bed.</li>
      <li><code>/buyhotel</code> — buy the hotel you're standing on, if it's for sale</li>
    </ul>

    <h4>Buying &amp; selling</h4>
    <ul>
      <li><code>/buyhotel</code> — buy the hotel whose pickup you're standing on (sold by the server or another player)</li>
      <li><code>/sellhotel [price]</code> — list your hotel for sale at that price; the money goes to your bank when someone buys it</li>
      <li><code>/sellhotel 0</code> — cancel the listing</li>
      <li><code>/sellhotelstate</code> — sell it back to the state instantly for <span class="num">60%</span> of its value</li>
    </ul>

    <h4>Renting a room long-term</h4>
    <p><code>/renthotel</code> — rent a nearby hotel an admin marked rentable (not the same as <code>/sleep</code>). Blocked if you own a house or already rent something. Rent is taken from you every PayDay, into the hotel's bank. <code>/endrent</code> — give up your current rent.</p>

    <h4>Info &amp; navigation</h4>
    <ul>
      <li><code>/htlstats</code> — name, ID, price, hotel bank balance and the sleep price</li>
      <li><code>/myhotel</code> — set a checkpoint to the hotel you own</li>
      <li><code>/findhotel [id]</code> — set a checkpoint to any hotel by its ID</li>
    </ul>

    <h4>Owner income</h4>
    <p>Every time a guest uses <code>/sleep</code> at your hotel, <span class="num">$75</span> (half the $150 they pay) goes into the hotel's bank; the other half is lost to running costs. This happens whether you are online or not.</p>
    <ul>
      <li><code>/mybank hotel withdraw [amount]</code> — take the earnings out (near a bank/ATM)</li>
      <li><code>/mybank hotel deposit [amount]</code> — put money in</li>
      <li><code>/mybank</code> — see the balance of every property you own</li>
    </ul>

    <div class="note">A hotel near a busy area earns more, because tiredness builds up on everyone (+2/minute) and players away from home need somewhere to sleep.</div>
  </div>
</section>

<section id="games">
  <h2>🎮 Mini-games &amp; Events — <code>/howto games</code></h2>
  <div class="card">
    <h4>Golf</h4>
    <p>Stroke play at the golf course.</p>
    <ul>
      <li><code>/joingolf</code> — enter (an admin opens the tournament)</li>
      <li><code>/hitball [power]</code> — swing toward the hole; aim with your camera, power sets distance</li>
      <li><code>/leavegolf</code> — quit</li>
    </ul>
    <p>Fewest strokes wins.</p>

    <h4>Basketball</h4>
    <p>At the <code>/basket</code> court (follow the map icon).</p>
    <ul>
      <li><code>/joinbasket</code> — join the lobby</li>
      <li><code>/throwball [power]</code> — shoot at your hoop</li>
      <li><code>/leavebasket</code> — quit</li>
    </ul>
    <p>Most points wins.</p>

    <h4>Race Events (BestLap)</h4>
    <p>An admin opens a race on a track (Lap1/2/3) with a set car (or random).</p>
    <ul>
      <li><code>/event join</code> — enter while sign-ups are open</li>
      <li>On start you spawn at the line; a 5s countdown runs (5..4..3..2..1..GO!), then race the checkpoints</li>
    </ul>
    <p>Your time is measured from GO to the last checkpoint. The top 3 are announced server-wide; beat the best time for that track &amp; car to set a RECORD!</p>

    <h4>Counter Strike</h4>
    <p>5v5 team deathmatch with a bomb. Several matches can run at once.</p>
    <ul>
      <li><code>/event cs join [nr]</code> — enter while an admin has sign-ups open</li>
      <li>Sign-ups close automatically at <span class="num">10 players</span> (or when an admin starts it), then everyone spawns</li>
      <li>Teams are assigned alternately as you join: T, CT, T, CT...</li>
    </ul>
    <p><strong>Rules:</strong> the match is <span class="num">10 rounds</span>; most rounds won takes it (5-5 = draw). After round 5 the teams swap sides.</p>
    <ul>
      <li><span class="t">T</span> win by planting the bomb (<code>/plant</code> at a [ Bomb ] site, 3s freeze) and letting it explode, or by killing all CT.</li>
      <li><span class="ct">CT</span> win by killing all T (only if the bomb isn't planted), or by defusing it (<code>/defuse</code>, 3s freeze).</li>
      <li>Once planted, the bomb explodes in a set number of seconds - killing every T does NOT win the round anymore, CT must defuse.</li>
    </ul>
    <p>Each round you get an AK-47 (T) or M4 (CT), a Desert Eagle and full armour. Die and you spectate your team until the next round.</p>

    <h4>Hunt The Mayor</h4>
    <p>One random player becomes the Mayor; everyone else hunts them.</p>
    <ul>
      <li><code>/event htm join</code> — enter while an admin has sign-ups open</li>
      <li>On start, the Mayor spawns at a random secret location (100 HP + 100 armour, MP5); every hunter spawns together elsewhere (50 HP, M4)</li>
    </ul>
    <p>You have <span class="num">15 minutes</span>.</p>
    <ul>
      <li>Land a hit on the Mayor (any damage) → <span class="num">$5.000</span>, once per hunter</li>
      <li>Land the kill → an extra <span class="num">$10.000</span></li>
      <li>If the Mayor survives the full 15 minutes → they earn <span class="num">$15.000</span></li>
    </ul>
  </div>
</section>

<section id="caravan">
  <h2>🚐 Caravan — <code>/howto caravan</code></h2>
  <div class="card">
    <p>A caravan is a trailer you tow behind your own car and can camp at, turning any spot into a temporary spawn point. You must <span class="num">own a caravan</span> - an admin gives you one.</p>

    <h4>Commands</h4>
    <ul>
      <li><code>/attach</code> — hook the caravan to your PERSONAL vehicle. You must be driving that vehicle and be near the caravan.</li>
      <li><code>/detach</code> — unhook it and park it where you stand. The spot is saved - the caravan reappears there after a restart.</li>
      <li><code>/findmycaravan</code> — set a checkpoint to your parked caravan</li>
      <li><code>/camp</code> — start camping. You must be driving with the caravan attached.</li>
    </ul>

    <h4>Towing</h4>
    <p>While attached, the caravan follows your car. Park on flat ground before <code>/detach</code>, otherwise it can end up tilted or stuck.</p>

    <h4>Camping — what <code>/camp</code> actually does</h4>
    <p>Your SPAWN POINT moves to the caravan's spot for <span class="num">3 hours</span> (= 3 paydays, since payday runs once an hour). Every time you die or reconnect you respawn at the camp instead of your normal spawn. When it expires, your spawn resets to normal automatically (house, faction or civilian, whatever you had).</p>

    <div class="note">This is handy for setting up far from the city - drag the caravan somewhere remote, /camp, and you stop losing time travelling back after every death.</div>
  </div>
</section>

<section id="licence">
  <h2>🪪 Licenses — <code>/howto licence</code></h2>
  <div class="card">
    <p>You need a license to drive/fly. Pass the exam and pay the fee at the exam spot.</p>
    <p><strong>Validity depends on the exam vehicle's health:</strong> finish with high HP for the FULL duration; a damaged vehicle gives a shorter one (full / damaged):</p>
    <h4>Driving licenses</h4>
    <ul>
      <li>A (<code>/examA</code>) — motorcycles — 7 / 2 days</li>
      <li>B (<code>/examB</code>) — cars — 10 / 3 days</li>
      <li>C (<code>/examC</code>) — trucks &amp; trailers — 12 / 3 days</li>
      <li>D (<code>/examD</code>) — buses — 13 / 3 days</li>
    </ul>
    <h4>Air licenses</h4>
    <ul>
      <li>P (<code>/examP</code>) — airplanes — 15 / 2 days</li>
      <li>H (<code>/examH</code>) — helicopters — 16 / 2 days</li>
    </ul>
    <p>Check yours with <code>/licenses</code>. Rentals and exam vehicles don't need a license.</p>
  </div>
</section>

<section id="farm">
  <h2>🌾 Farming — <code>/howto farm</code></h2>
  <div class="card">
    <p>Own a field and work the land through a cycle of 5 steps - <span class="num">one step per real day</span>.</p>

    <h4>Owning a farm</h4>
    <p>Stand on a for-sale field (look for the pickup + sign) and use <code>/buyfarm</code>. To resell, list it with <code>/sellfarm [price]</code> - another player buys it with /buyfarm and the money goes to your bank (<code>/sellfarm 0</code> cancels). Or sell it back to the state instantly with <code>/sellfarmtostate</code> (60%). You can own one farm.</p>

    <h4>Machines (on your own farm)</h4>
    <ul>
      <li><code>/farm buy [tractor/dozer/combina]</code> — parks a machine at the farm (Tractor $10.000, Dozer $15.000, Combine $20.000)</li>
      <li><code>/farm sell</code> — sit in a farm machine to sell that one (75% back)</li>
    </ul>

    <h4>Working (one step per day)</h4>
    <p>Drive the correct machine for the shown time WITHOUT leaving it:</p>
    <ul>
      <li><code>/farm plow</code> — Tractor, 1 min</li>
      <li><code>/farm level</code> — Dozer, 2 min</li>
      <li><code>/farm seed</code> — Tractor, 3 min</li>
      <li><code>/farm fertilize</code> — Tractor, 1 min</li>
      <li><code>/farm harvest</code> — Combine, 4 min → paid $15.000, cycle restarts</li>
    </ul>
    <p class="warn">If you leave the machine, die or disconnect, the job is cancelled and you lose that day's work (and can't retry until tomorrow).</p>

    <h4>Info</h4>
    <p><code>/farm stats</code> (on a field) and <code>/farmstats</code> (your farm) show the next step, progress and whether you can work today.</p>
  </div>
</section>

<section id="rob">
  <h2>🔫 Robbery — <code>/howto rob</code></h2>
  <div class="card">
    <p>Rob a shop or fast-food with your crew - the more people in the car, the bigger the reward.</p>

    <h4>Requirements</h4>
    <ul>
      <li>You need <span class="num">10/10 rob points</span> (shown in <code>/stats</code>). You gain 1 per payday.</li>
      <li>You must be the driver of a vehicle, parked next to a shop or fast-food.</li>
    </ul>

    <h4>Doing it</h4>
    <p>Drive up to a shop or fast-food and use <code>/rob</code>.</p>
    <ul>
      <li>Everyone in the car at that moment becomes the crew and each loses 10 rob points.</li>
      <li>The whole crew gets wanted level 6 - the police will come!</li>
      <li>Now deliver the money: a checkpoint appears at a random business. Reach it, then a second business appears. You must reach both.</li>
    </ul>

    <h4>Payout</h4>
    <p>After the 2nd business every crew member who is still alive and connected earns <span class="num">$12.000 + $2.000 per crew member + a random bonus up to $5.000</span> each. Die or disconnect and you get nothing.</p>
  </div>
</section>

<section id="skins">
  <h2>🧍 Skins &amp; Clothes — <code>/howto skins</code></h2>
  <div class="card">
    <p>Change how your character looks by buying and wearing outfits (skins).</p>

    <h4>Clothing store</h4>
    <p>Go to a store marked with the clothes icon on the map.</p>
    <ul>
      <li><code>/skins</code> — browse the catalogue and buy an outfit (<span class="num">$10.000</span> each). Buying an outfit also puts it on.</li>
      <li><code>/wardrobe</code> — switch between outfits you already own, for free.</li>
    </ul>
    <p>Outfits you buy are yours forever - you can swap between them anytime at a store.</p>

    <h4>Faction uniform</h4>
    <p>Factions have 3 uniforms by rank (rank 1/2, rank 3/4, rank 5). You wear the one for your rank automatically when you spawn on duty (faction spawn); as a civilian you wear your own outfit. Inside your faction HQ you can use <code>/changeskin</code> to switch between your uniform and civilian clothes.</p>
  </div>
</section>

<section id="casino">
  <h2>🎰 Casino — <code>/howto casino</code></h2>
  <div class="card">
    <p>Try your luck at the Casino (casino icon on the map).</p>

    <h4>Getting in</h4>
    <p>Walk to the entrance and press ENTER (or type <code>/enter</code>). Leave anytime with ENTER at the door or <code>/leavecasino</code>.</p>

    <h4>Games — each is played at its own table (look for the signs)</h4>
    <ul>
      <li><code>/slots [bet]</code> — at a slot machine. Three Sevens = x10, any other three of a kind = x5, two Sevens = x2.</li>
      <li><code>/roulette [red/black/even/odd/0-36] [bet]</code> — at a roulette table. Color/parity pays x2 (0 loses), exact number pays x36.</li>
      <li><code>/dice [bet]</code> — at the dice area. You and the house each roll two dice; higher total wins x2, a tie returns your bet.</li>
    </ul>

    <div class="note">Gamble responsibly - the house always has the edge!</div>
  </div>
</section>

</main>

<footer>Nostalgia: Los Santos UCP — generat din comanda <code>/howto</code> a gamemode-ului</footer>

</body>
</html>
