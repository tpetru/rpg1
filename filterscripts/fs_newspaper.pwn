// ============================================================
//  FS_NEWSPAPER - Sistem Ziare
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
#include "../include/newspaper.inc"

public OnFilterScriptInit()
{
    print("[FS] Newspaper incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Newspaper descarcat.");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Newspaper_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
