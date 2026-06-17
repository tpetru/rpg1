// ============================================================
//  FS_PLAYER - Sistem Jucator
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

public OnFilterScriptInit()
{
    print("[FS] Player incarcat.");
    return 1;
}

public OnFilterScriptExit()
{
    print("[FS] Player descarcat.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    Player_OnConnect(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    Player_OnDisconnect(playerid, reason);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    Player_OnSpawn(playerid);
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    Player_OnDeath(playerid, killerid, reason);
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_LOGIN ||
       dialogid == DIALOG_REGISTER ||
       dialogid == DIALOG_REGISTER_PASS)
        return Dialog_Auth_Response(playerid, dialogid, response, listitem, inputtext);
    return 0;
}
