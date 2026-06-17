// ============================================================
//  FS_EVENTS - Autosave & Chat
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
#include "../include/admin.inc"
#include "../include/events.inc"

public OnFilterScriptInit()
{
    Events_Init();
    Events_StartAutosave();
    print("[FS] Events incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    if(AutosaveTimer) KillTimer(AutosaveTimer);
    print("[FS] Events descarcat.");
    return 1;
}

public OnPlayerText(playerid, text[])
{
    return Player_OnText(playerid, text);
}
