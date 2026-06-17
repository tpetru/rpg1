// ============================================================
//  FS_HUNTING_FISHING - Sistem Vanatoare & Pescuit
// ============================================================
#define FILTERSCRIPT

#include <a_samp>
#include <a_mysql>
#include <streamer>
#include <sscanf2>
#include <zcmd>

#include "../include/config.inc"
#include "../include/db.inc"
#include "../include/utils.inc"
#include "../include/player.inc"
#include "../include/hunting_fishing.inc"

public OnFilterScriptInit()
{
    HuntingFishing_Init();
    print("[FS] HuntingFishing incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] HuntingFishing descarcat.");
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    HuntingFishing_OnEnterArea(playerid, areaid);
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(!PlayerData[playerid][pLogged]) return 0;
    for(new i = 0; i < FishCount; i++)
    {
        if(FishData[i][fhPickupID] != pickupid || !FishData[i][fhAlive]) continue;
        FishData[i][fhAlive]    = false;
        FishData[i][fhPickupID] = 0;
        PlayerFishBag[playerid]++;
        Player_AddXP(playerid, 10);
        SendMsgFmt(playerid, COLOR_SUCCESS,
            "[Pescuit] Ai prins un peste! Total: %d | /sellfish", PlayerFishBag[playerid]);
        return 1;
    }
    return 0;
}
