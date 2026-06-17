// ============================================================
//  FS_JOBS - Sistem Joburi
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
#include "../include/jobs.inc"

public OnFilterScriptInit()
{
    print("[FS] Jobs incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Jobs descarcat.");
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    return Jobs_OnCheckpoint(playerid);
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    return Jobs_OnDialog(playerid, dialogid, response, listitem, inputtext);
}
