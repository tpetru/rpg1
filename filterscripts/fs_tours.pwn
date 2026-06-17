// ============================================================
//  FS_TOURS - Sistem Tururi
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
#include "../include/tours.inc"

public OnFilterScriptInit()
{
    Tours_Init();
    print("[FS] Tours incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Tours descarcat.");
    return 1;
}

public OnPlayerEnterDynamicArea(playerid, STREAMER_TAG_AREA:areaid)
{
    Tour_OnEnterArea(playerid, areaid);
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Tour_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
