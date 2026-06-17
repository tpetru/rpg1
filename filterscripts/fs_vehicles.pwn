// ============================================================
//  FS_VEHICLES - Sistem Vehicule
// ============================================================
#define FILTERSCRIPT

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>

#include "../include/config.inc"
#include "../include/db.inc"
#include "../include/utils.inc"
#include "../include/player.inc"
#include "../include/vehicles.inc"

public OnFilterScriptInit()
{
    Vehicles_Init();
    print("[FS] Vehicles incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Vehicles descarcat.");
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

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_VEHICLE_MENU || dialogid == 9996)
    {
        // Handled inline in events.inc
        return 1;
    }
    return 0;
}
