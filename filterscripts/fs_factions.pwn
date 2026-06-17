// ============================================================
//  FS_FACTIONS - Sistem Factiuni
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
#include "../include/factions.inc"

public OnFilterScriptInit()
{
    print("[FS] Factions incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Factions descarcat.");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_FACTION_MENU)
        return 1;
    return 0;
}
