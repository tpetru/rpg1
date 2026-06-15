// ============================================================
//  ROMANIA RPG - Gamemode Principal
//  Versiune: 1.0 | Modern & Modular
// ============================================================

#include <a_samp>
#include <a_mysql>
#include <streamer>
#include <sscanf2>
#include <zcmd>

// ---- Include-uri proprii ----
#include "../includes/config.inc"
#include "../includes/db.inc"
#include "../includes/utils.inc"
#include "../includes/player.inc"
#include "../includes/vehicles.inc"
#include "../includes/houses.inc"
#include "../includes/businesses.inc"
#include "../includes/pets.inc"
#include "../includes/hunting_fishing.inc"
#include "../includes/disease.inc"
#include "../includes/newspaper.inc"
#include "../includes/tours.inc"
#include "../includes/trade.inc"
#include "../includes/president.inc"
#include "../includes/factions.inc"
#include "../includes/jobs.inc"
#include "../includes/mafia.inc"
#include "../includes/payday.inc"
#include "../includes/admin.inc"
#include "../includes/events.inc"

// ============================================================
//  MAIN
// ============================================================

main() {}

public OnGameModeInit()
{
    SetGameModeText("Romania RPG v1.0");
    ShowNameTags(1);
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_STREAMED);
    EnableStuntBonusForAll(0);
    DisableInteriorEnterExits();
    UsePlayerPedAnims();
    SetWeather(10);
    SetWorldTime(12);

    // Initializare MySQL
    DB_Init();

    // Initializare sisteme
    Houses_Init();
    Businesses_Init();
    Vehicles_Init();
    Mafia_Init();
    President_Init();
    HuntingFishing_Init();
    Tours_Init();
    Payday_Init();
    Events_Init();

    print("[Romania RPG] Gamemode incarcat cu succes!");
    return 1;
}

public OnGameModeExit()
{
    DB_Close();
    return 1;
}

public OnPlayerConnect(playerid)
{
    Player_OnConnect(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    Player_OnDisconnect(playerid, reason);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    Player_OnSpawn(playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    Player_OnDeath(playerid, killerid, reason);
    return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
    Vehicles_OnDeath(vehicleid, killerid);
    return 1;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    Vehicles_OnEnter(playerid, vehicleid, ispassenger);
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    Vehicles_OnExit(playerid, vehicleid);
    return 1;
}

public OnPlayerText(playerid, text[])
{
    return Player_OnText(playerid, text);
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Dialog_OnResponse(playerid, dialogid, response, listitem, inputtext);
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    return Pickups_OnPickup(playerid, pickupid);
}

public OnPlayerEnterCheckpoint(playerid)
{
    return Jobs_OnCheckpoint(playerid);
}

public OnPlayerLeaveCheckpoint(playerid)
{
    return 1;
}

// Streamer callbacks
public OnPlayerEnterDynamicArea(playerid, areaid)
{
    Mafia_OnEnterArea(playerid, areaid);
    HuntingFishing_OnEnterArea(playerid, areaid);
    return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
    return 1;
}
