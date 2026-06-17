// ============================================================
//  FS_PRESIDENT - Sistem Presedinte
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
#include "../include/president.inc"

public OnFilterScriptInit()
{
    President_Init();
    print("[FS] President incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] President descarcat.");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return President_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
