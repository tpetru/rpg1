// ============================================================
//  FS_MAFIA - Sistem Mafia
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
#include "../include/factions.inc"
#include "../include/mafia.inc"

public OnFilterScriptInit()
{
    Mafia_Init();
    print("[FS] Mafia incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Mafia descarcat.");
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    Mafia_OnEnterArea(playerid, areaid);
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(!PlayerData[playerid][pLogged]) return 0;
    for(new i = 0; i < TerritoryCount; i++)
    {
        if(TerritoryData[i][terPickupID] != pickupid) continue;
        new fid = PlayerData[playerid][pFaction];
        if(fid >= FACTION_MAFIA_EU && fid <= FACTION_MAFIA_AM)
            SendMsg(playerid, COLOR_ORANGE,
                "[Teritoriu] Foloseste /capturezone pentru a cuceri aceasta zona!");
        else
            SendMsgFmt(playerid, COLOR_GREY,
                "[Teritoriu] %s | Proprietar: %s | Venit: $%d",
                TerritoryData[i][terName],
                TerritoryData[i][terOwnerFaction] == 0 ?
                    "Neutru" : Faction_GetName(TerritoryData[i][terOwnerFaction]),
                TerritoryData[i][terIncome]);
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_MAFIA_SEIF) return 1;
    return 0;
}
