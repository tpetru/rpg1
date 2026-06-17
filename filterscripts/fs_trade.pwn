// ============================================================
//  FS_TRADE - Sistem Schimb
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
#include "../include/houses.inc"
#include "../include/trade.inc"

public OnFilterScriptInit()
{
    print("[FS] Trade incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Trade descarcat.");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Trade_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
