<?php
require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/functions.php';
ucp_require_admin();

$myLevel = ucp_current_admin_level();

// List of admin commands, mirrored from the actual code in gamemodes/bare.pwn (not just /ahelp).
// Each command: 'cmd' = full syntax with parameters, 'desc' = exactly what it does.
// Keep manually in sync whenever commands are added/changed in bare.pwn.
$ADMIN_COMMANDS = [
    1 => [
        'General' => [
            ['cmd' => '/ahelp', 'desc' => 'Shows the list of available admin commands, grouped by level (only shows the levels you have access to).'],
            ['cmd' => '/respawn [playerid]', 'desc' => 'Sets the target\'s HP to 0, forcing a respawn.'],
            ['cmd' => '/aheal [playerid]', 'desc' => 'Fully heals (100 HP) the target player.'],
            ['cmd' => '/aa [text]', 'desc' => 'Sends an OOC admin announcement to all players: "(( Admin Name: text ))".'],
            ['cmd' => '/slap [playerid]', 'desc' => 'Lifts the target 2 units vertically, in place.'],
            ['cmd' => '/setskin [playerid] [skinid]', 'desc' => 'Sets the target\'s skin (0-311), applies it immediately, and unlocks it permanently (adds it to player_skins if not already owned).'],
            ['cmd' => '/businesslist', 'desc' => 'Dialog with all businesses (ID, name, owner, price) — view only, no teleport.'],
            ['cmd' => '/showradars', 'desc' => 'Dialog with all active speed radars (installer, limit, distance). Access: level 1+ OR Police rank 4+.'],
            ['cmd' => '/removeradar [radarid]', 'desc' => 'Disables the radar with the given ID and notifies the owner if online. Access: level 1+ OR Police rank 4+.'],
            ['cmd' => '/fixcar', 'desc' => 'Fully repairs the vehicle you\'re in.'],
            ['cmd' => '/flipcar', 'desc' => 'Rights the vehicle you\'re in (lifts it 0.5 units, keeps the Z angle).'],
            ['cmd' => '/setinterior [playerid] [interiorid]', 'desc' => 'Sets the target\'s GTA interior.'],
            ['cmd' => '/setvw [playerid] [vw_id]', 'desc' => 'Sets the target\'s virtual world (alias: /setvirtualworld).'],
            ['cmd' => '/setjob [playerid] [jobid]', 'desc' => 'Sets the target\'s job (0-'.'10, 0 = no job); stops any ongoing job/Uber first.'],
            ['cmd' => '/settired [playerid] [level]', 'desc' => 'Directly sets the target\'s tiredness level (0-100).'],
            ['cmd' => '/setsick [playerid] [0/1]', 'desc' => 'Marks the target as sick (1) or cured (0).'],
        ],
    ],
    2 => [
        'General' => [
            ['cmd' => '/createfire', 'desc' => 'Creates a fire at your position (fails if the MAX_FIRES limit is reached).'],
            ['cmd' => '/healall', 'desc' => 'Fully heals all connected and logged-in players.'],
            ['cmd' => '/gotoloc [location name]', 'desc' => 'No argument: lists the existing named locations. With a name: teleports you (or your vehicle, if driving) there.'],
            ['cmd' => '/gotobiz [bizid]', 'desc' => 'Teleports you to the location of the business with the given ID.'],
            ['cmd' => '/gotohouse [houseid]', 'desc' => 'Teleports you to the location of the house with the given ID.'],
            ['cmd' => '/gotofaction [factionid]', 'desc' => 'Teleports you to the given faction\'s HQ (error if it has no HQ set).'],
            ['cmd' => '/goto [playerid]', 'desc' => 'Teleports you exactly to the target\'s position (+ interior + virtual world).'],
            ['cmd' => '/bizzlist', 'desc' => 'Dialog with all businesses, with a teleport button.'],
            ['cmd' => '/houselist', 'desc' => 'Dialog with all houses (ID, name, type, owner), with a teleport button.'],
            ['cmd' => '/farmlist', 'desc' => 'Dialog with all farms, with a teleport button.'],
            ['cmd' => '/opengolftournament', 'desc' => 'Opens golf tournament sign-ups and announces server-wide. Fails if one is already open.'],
            ['cmd' => '/startgolf', 'desc' => 'Closes sign-ups and starts the golf tournament for all signed-up players (heal, club, hole order).'],
        ],
        'Events' => [
            ['cmd' => '/cscreate [csType] [name]', 'desc' => 'Creates a Counter Strike location (1=SpawnT, 2=SpawnCT, 3=BombSite) at your position.'],
            ['cmd' => '/csdelete [csID]', 'desc' => 'Deletes the CS location with the given ID.'],
            ['cmd' => '/cslist', 'desc' => 'Dialog with all CS locations, with a teleport button.'],
            ['cmd' => '/event cs open', 'desc' => 'Opens sign-ups on the first free CS match slot (up to MAX_CS_EVENTS) and announces server-wide.'],
            ['cmd' => '/event cs start [nr]', 'desc' => 'Forcefully closes sign-ups and starts CS match [nr] (requires at least 2 signed-up players).'],
            ['cmd' => '/event cs stop [nr]', 'desc' => 'Forcefully stops CS match [nr], regardless of state.'],
            ['cmd' => '/event htm open', 'desc' => 'Opens Hunt The Mayor sign-ups server-wide. Fails if one is already open/active.'],
            ['cmd' => '/event htm start', 'desc' => 'Randomly picks a Mayor from the signed-up players, spawns everyone, and starts the 15-minute timer (requires at least 2 signed up).'],
            ['cmd' => '/event htm stop', 'desc' => 'Forcefully stops the active Hunt The Mayor event.'],
            ['cmd' => '/event race [lap1/lap2/lap3] [vehicle/random]', 'desc' => 'Opens sign-ups for a race on the given track, with the specified vehicle (or random at start). Fails if a race event is already active.'],
            ['cmd' => '/event start', 'desc' => 'Closes race sign-ups, spawns a vehicle for each signed-up player at the starting line (frozen), and starts the countdown (requires at least 1 sign-up).'],
            ['cmd' => '/event stop', 'desc' => 'Forcefully stops the current race event.'],
        ],
        'Vehicles' => [
            ['cmd' => '/getcar [vehicleid]', 'desc' => 'Brings the existing vehicle with the given ID to your position, realigning its interior/virtual world to yours.'],
            ['cmd' => '/gotocar [vehicleid]', 'desc' => 'Teleports you (or your vehicle, if you\'re the driver) to the vehicle with the given ID.'],
            ['cmd' => '/saveloc', 'desc' => 'Saves your current position, angle, interior, and virtual world to a temporary slot (not persisted to the DB).'],
            ['cmd' => '/gotosave', 'desc' => 'Teleports you back to the position saved with /saveloc (error if nothing was saved).'],
            ['cmd' => '/giveweapon [playerid] [weapon name] [ammo]', 'desc' => 'Gives the target the specified weapon with the given ammo (default 1, limited to 1-30000).'],
        ],
    ],
    3 => [
        'General' => [
            ['cmd' => '/setlic [playerid] [all/A/B/C/D/H/P] [YYYY-MM-DD]', 'desc' => 'Sets the expiration date of the target\'s license(s) (A/B/C/D driving, H helicopter, P plane, or "all" for all of them).'],
            ['cmd' => '/veh [name or model id]', 'desc' => 'Spawns a vehicle (by name or model id 400-611) next to you and puts you in it.'],
            ['cmd' => '/rac', 'desc' => 'Forces all vehicles on the server to respawn at their default position.'],
            ['cmd' => '/createdisease', 'desc' => 'Infects all players within DISEASE_RADIUS of you who aren\'t already sick.'],
            ['cmd' => '/forceunlock', 'desc' => 'Unlocks the personal vehicle you\'re in (or the nearest one, within 8m, if on foot).'],
            ['cmd' => '/gotoxyz [x] [y] [z]', 'desc' => 'Teleports you (or your vehicle) directly to the given coordinates.'],
            ['cmd' => '/changecar [engine/lights/alarm/doors/hood/boot]', 'desc' => 'Toggles the given component\'s state on the vehicle you\'re in and reports the new state.'],
            ['cmd' => '/setworldtime [0-23]', 'desc' => 'Sets the in-game world time for all players.'],
        ],
    ],
    4 => [
        'General' => [
            ['cmd' => '/forcewar [turf_id] [faction_atc] [faction_def]', 'desc' => 'Forcefully triggers a turf war between two mafias (id 4-7), ignoring the normal declaration rules.'],
            ['cmd' => '/adminuninvite [playerid]', 'desc' => 'Forcefully removes the target from their current faction (resets faction/rank, recolors, recalculates spawn); if they were the leader, frees the leader slot.'],
        ],
    ],
    5 => [
        'General' => [
            ['cmd' => '/vc loc', 'desc' => 'Sets the default spawn location of the personal vehicle you\'re in.'],
            ['cmd' => '/vc price [new price]', 'desc' => 'Sets the vehicle\'s sale price (requires level 6, stricter than the rest of /vc).'],
            ['cmd' => '/vc insurance [YYYY-MM-DD]', 'desc' => 'Sets the vehicle\'s insurance expiration date.'],
            ['cmd' => '/vc medkit [YYYY-MM-DD]', 'desc' => 'Sets the vehicle\'s medkit expiration date.'],
            ['cmd' => '/vc extinctor [YYYY-MM-DD]', 'desc' => 'Sets the vehicle\'s fire extinguisher expiration date.'],
            ['cmd' => '/vc itp [YYYY-MM-DD]', 'desc' => 'Sets the vehicle\'s inspection (ITP) expiration date.'],
            ['cmd' => '/vc forsale [price]', 'desc' => 'Puts the vehicle up for sale at the given price (0 cancels the listing).'],
            ['cmd' => '/vc ownerid [playerid|none]', 'desc' => 'Reassigns vehicle ownership to a connected player, or "none" to release it.'],
            ['cmd' => '/bc [bizid] name [name]', 'desc' => 'Renames the business with the given ID.'],
            ['cmd' => '/bc [bizid] price [new price]', 'desc' => 'Sets the business\'s sale price.'],
            ['cmd' => '/bc [bizid] loc', 'desc' => 'Moves the business location to your current position.'],
            ['cmd' => '/bc [bizid] anaf [0/1]', 'desc' => 'Manually sets/clears the business\'s ANAF (tax authority) lock.'],
            ['cmd' => '/bc [bizid] forsale [price]', 'desc' => 'Puts the business up for sale at the given price (0 cancels).'],
            ['cmd' => '/bc [bizid] ownerid [playerid|none]', 'desc' => 'Reassigns the business owner, or "none" to release it for standard sale.'],
            ['cmd' => '/bc [bizid] bank [new value]', 'desc' => 'Sets the business\'s internal bank balance.'],
            ['cmd' => '/hc [houseid] loc', 'desc' => 'Moves the house location to your current position.'],
            ['cmd' => '/hc [houseid] interior [gtaIntID]', 'desc' => 'Links the house\'s interior door to a predefined interior (from gta_interiors).'],
            ['cmd' => '/hc [houseid] price [new price]', 'desc' => 'Sets the house\'s sale price.'],
            ['cmd' => '/hc [houseid] owner [playerid|none]', 'desc' => 'Reassigns the house owner, or "none" to release it for standard sale.'],
            ['cmd' => '/hc [houseid] forsale [price]', 'desc' => 'Puts the house up for sale at the given price (0 cancels).'],
            ['cmd' => '/hc [houseid] bank [new value]', 'desc' => 'Sets the house\'s internal bank balance.'],
            ['cmd' => '/hc [houseid] type [1-4]', 'desc' => 'Sets the house type (1=Villa, 2=City House, 3=Apartment, 4=Countryside House).'],
            ['cmd' => '/hc [houseid] name [new name]', 'desc' => 'Renames the house.'],
            ['cmd' => '/hc [houseid] rentable [0/1]', 'desc' => 'Enables/disables the ability to rent the house.'],
            ['cmd' => '/hc [houseid] rentprice [price]', 'desc' => 'Sets the house\'s PayDay rent.'],
            ['cmd' => '/fc [factionid] hq', 'desc' => 'Sets the faction\'s HQ teleport point to your position.'],
            ['cmd' => '/fc [factionid] interiorloc', 'desc' => 'Sets the faction\'s interior entry point to your position.'],
            ['cmd' => '/fc [factionid] interior [interior_id]', 'desc' => 'Sets the faction\'s interior ID.'],
            ['cmd' => '/fc [factionid] vw [vw_id]', 'desc' => 'Sets the faction\'s virtual world (used together with the interior).'],
            ['cmd' => '/fc [factionid] hqicon [icon_id]', 'desc' => 'Changes the faction HQ\'s map icon.'],
            ['cmd' => '/fc [factionid] pickup [pickup_id]', 'desc' => 'Changes the faction HQ\'s pickup model.'],
            ['cmd' => '/fc [factionid] lead [playerid]', 'desc' => 'Makes the target the faction leader (rank 5), removing them from any other faction, announcing server-wide, and respawning them at the new HQ.'],
            ['cmd' => '/fc [factionid] vehloc', 'desc' => 'Sets the spawn location of the faction vehicle you\'re in (you must be driving a faction vehicle).'],
            ['cmd' => '/fc [factionid] createveh', 'desc' => 'Creates a new faction vehicle (same model as the one you\'re in) for the given faction.'],
            ['cmd' => '/fc [factionid] removelead', 'desc' => 'Removes the faction\'s current leader (online or offline), clearing the leader field.'],
            ['cmd' => '/farmc [farmid] loc', 'desc' => 'Sets the farm point to your current position.'],
            ['cmd' => '/farmc [farmid] range [radius]', 'desc' => 'Sets the farm\'s trigger radius.'],
            ['cmd' => '/farmc [farmid] price [price]', 'desc' => 'Sets the farm\'s sale price.'],
            ['cmd' => '/farmc [farmid] name [new name]', 'desc' => 'Renames the farm.'],
            ['cmd' => '/farmc [farmid] isowned [0/1]', 'desc' => 'Directly forces the farm\'s "owned" flag, clearing any existing owner.'],
            ['cmd' => '/farmc [farmid] ownerid [playerid|none]', 'desc' => 'Reassigns the farm owner, or "none" to release it for standard sale.'],
            ['cmd' => '/farmc [farmid] forsale [price]', 'desc' => 'Puts the farm up for sale at the given price (0 cancels).'],
            ['cmd' => '/farmc [farmid] bank [new value]', 'desc' => 'Sets the farm\'s internal bank balance.'],
            ['cmd' => '/hupgrade [houseid] tree', 'desc' => 'Adds a free tree to the given house (City House or Countryside only; fails if it already has one).'],
            ['cmd' => '/hupgrade [houseid] animal [name]', 'desc' => 'Adds a free named animal (from the catalog, restricted by house type) to the given house; without a name, lists the available animals.'],
            ['cmd' => '/setfactionskin [factionid] [skin r1/2] [skin r3/4] [skin r5]', 'desc' => 'Sets the faction\'s 3 uniforms (skin ID) per rank (0 = none).'],
            ['cmd' => '/payday', 'desc' => 'Manually triggers the PayDay cycle for all players.'],
            ['cmd' => '/jetpack', 'desc' => 'Gives you a jetpack.'],
            ['cmd' => '/removejetpack', 'desc' => 'Removes the jetpack from all connected players using one, reporting how many were affected.'],
        ],
    ],
    6 => [
        'Create' => [
            ['cmd' => '/hcreate [name]', 'desc' => 'Creates a new house at your position, default price $2,000,000 (fails if MAX_HOUSES is reached).'],
            ['cmd' => '/htlcreate [name]', 'desc' => 'Creates a new hotel at your position, default price $50,000 (fails if MAX_HOTELS is reached).'],
            ['cmd' => '/htlc loc [htlID]', 'desc' => 'Moves the given hotel to your current position.'],
            ['cmd' => '/htlc price [htlID] [new price]', 'desc' => 'Sets the hotel room price.'],
            ['cmd' => '/htlc name [htlID] [new name]', 'desc' => 'Renames the hotel.'],
            ['cmd' => '/htlc rentable [htlID] [0/1]', 'desc' => 'Enables/disables the ability to rent the hotel.'],
            ['cmd' => '/htlc rentprice [htlID] [price]', 'desc' => 'Sets the hotel\'s PayDay rent.'],
            ['cmd' => '/bcreate', 'desc' => 'Creates a new business ("Business") at your position, default price $3,000,000 (fails if MAX_BUSINESSES is reached).'],
            ['cmd' => '/vcreate [price] [from_biz_id]', 'desc' => 'Turns the vehicle you\'re in into a new sellable personal (showroom) vehicle, with the given price and origin business (you must be in the vehicle).'],
            ['cmd' => '/setbballspawn [hoop_id 1-8] [spawn_id 1-4]', 'desc' => 'Sets one of the 4 spawn points of the given basketball hoop, at your current position and angle.'],
            ['cmd' => '/createcaravan [playerid] [type 1-3]', 'desc' => 'Grants the target a free personal caravan of the given type (fails if they already have one, or the limit is reached).'],
            ['cmd' => '/createatm', 'desc' => 'Creates a new ATM at your position, automatically assigned to the nearest bank (fails if MAX_ATMS is reached).'],
            ['cmd' => '/deleteatm [id]', 'desc' => 'Deletes the ATM with the given ID.'],
            ['cmd' => '/moveatm [id]', 'desc' => 'Moves the given ATM to your current position and recalculates the nearest bank.'],
        ],
    ],
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NostalgiaRP UCP — Admin Commands Reference</title>
<link rel="stylesheet" href="assets/css/style.css">
<style>
  table.cmdtable td:first-child { white-space: nowrap; }
  table.cmdtable td:last-child { color: var(--muted); }
</style>
</head>
<body>

<header class="topbar">
  <div class="brand">🏙️ NostalgiaRP UCP</div>
  <nav>
    <a href="dashboard.php">Dashboard</a>
    <a href="maps.php">Map</a>
    <a href="howto.php">How To</a>
    <a href="admin.php">Admin</a>
    <a href="admincmds.php">Admin Cmds</a>
    <a href="logout.php">Logout</a>
  </nav>
  <div class="userbox"><?= ucp_escape($_SESSION['ucp_username']) ?> · admin lvl <?= $myLevel ?></div>
</header>

<main>
  <h1>Admin command reference (your level: <?= $myLevel ?>)</h1>

  <?php foreach ($ADMIN_COMMANDS as $level => $groups): ?>
    <?php if ($level > $myLevel) continue; ?>
    <div class="card">
      <h2><span class="pill pill-lvl">Level <?= $level ?></span></h2>
      <?php foreach ($groups as $groupName => $cmds): ?>
        <h3 style="margin:14px 0 6px; font-size:0.95rem; color:var(--muted); text-transform:uppercase; letter-spacing:0.4px;"><?= ucp_escape($groupName) ?></h3>
        <table class="cmdtable">
          <tr><th style="width:38%">Command</th><th>What it does</th></tr>
          <?php foreach ($cmds as $c): ?>
            <tr>
              <td><code><?= ucp_escape($c['cmd']) ?></code></td>
              <td><?= ucp_escape($c['desc']) ?></td>
            </tr>
          <?php endforeach; ?>
        </table>
      <?php endforeach; ?>
    </div>
  <?php endforeach; ?>
</main>

<footer>NostalgiaRP UCP</footer>

</body>
</html>
