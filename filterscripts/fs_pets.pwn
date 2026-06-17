// ============================================================
//  FS_PETS - Sistem Animale de Companie
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
#include "../include/pets.inc"

public OnFilterScriptInit()
{
    print("[FS] Pets incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Pets descarcat.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    Pet_LoadForPlayer(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    Pet_SaveForPlayer(playerid);
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_PET_MENU || dialogid == DIALOG_PET_MENU + 1 || dialogid == 9995)
    {
        if(!response) return 1;
        if(dialogid == DIALOG_PET_MENU + 1)
        {
            SetPVarInt(playerid, "BuyPetType", listitem);
            Pet_Buy(playerid, listitem);
        }
        return 1;
    }
    return 0;
}
